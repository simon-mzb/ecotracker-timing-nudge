source("analysis/analysis_helpers.R")
full<-readRDS(file.path(model_dir,"primary_models.rds"))$primary_7
primary_result<-read_csv(file.path(result_dir,"primary_effect.csv"),show_col_types=FALSE)
binary<-readRDS(file.path(model_dir,"binary_models.rds"))
effects<-list(primary_result %>% select(analysis,family,n_events,n_households,beta,se,OR,lower,upper,interval,warnings))
diagnostics<-list();models<-list()
add_ordinal<-function(d,label,formula=window_ordered~phase+appliance+(1|household_id),nAGQ=7) {
  obj<-fit_ordinal(d,nAGQ=nAGQ,formula=formula)
  dg<-ordinal_diagnostic(obj,label)
  if(!dg$accepted || dg$max_abs_gradient>.001 || dg$max_scaled_gradient>.001) {
    diagnostics[[length(diagnostics)+1L]]<<-mutate(dg,attempt="initial")
    obj<-fit_ordinal(d,nAGQ=nAGQ,formula=formula,tight=TRUE)
    dg<-ordinal_diagnostic(obj,label)
  }
  effects[[length(effects)+1L]]<<-effect_row(obj,label,d)
  diagnostics[[length(diagnostics)+1L]]<<-mutate(dg,attempt="final")
  models[[label]]<<-obj
  if(!dg$accepted || dg$max_abs_gradient>.001 || dg$max_scaled_gradient>.001)
    stop(paste("Sensitivity requires numerical troubleshooting:",label))
  invisible(obj)
}
specs<-c(all_eligible_events="All eligible events (including incomplete)",
  exposure_marker_events="Observed Phase-2 exposure",high_load_events="High-load appliances only",
  immediate_only_events="Immediate registrations only",backdated_boundary_excluded_events="Exclude four phase-crossing backdates",
  backdated_registration_phase_events="Backdates assigned by registration time",
  primary_events_retain_all_duplicates="Retain duplicate-flagged events")
for(nm in names(specs))add_ordinal(prepare_events(read_set(nm)),specs[[nm]])
all_events<-prepare_events(read_set("all_eligible_events"))
add_ordinal(filter(all_events,full_14_day_opportunity),"All eligible events, full opportunity only")
add_ordinal(filter(all_events,paired_contributor_locked),"Paired contributors including incomplete")

binary_rows<-read_csv(file.path(result_dir,"binary_effects.csv"),show_col_types=FALSE)
effects[[length(effects)+1L]]<-binary_rows
conditional_info<-list()
for(outcome in c("is_great","is_not_bad")) {
  # Conditional likelihood has no phase information in constant-outcome strata.
  informative<-primary %>% group_by(household_id) %>% summarise(informative=n_distinct(.data[[outcome]])>1,.groups="drop")
  dd<-filter(primary,household_id %in% informative$household_id[informative$informative])
  label<-if(outcome=="is_great")"Household-stratified: great" else "Household-stratified: great/ok"
  obj<-capture_fit(survival::clogit(as.formula(paste0(outcome,"~phase+appliance+strata(household_id)")),data=dd,method="exact"))
  effects[[length(effects)+1L]]<-effect_row(obj,label,dd,family="Conditional logistic")
  models[[label]]<-obj
  conditional_info[[length(conditional_info)+1L]]<-tibble(analysis=label,
    informative_households=n_distinct(dd$household_id),excluded_constant_households=sum(!informative$informative),
    informative_events=nrow(dd),warnings=paste(obj$warnings,collapse="; "),error=obj$error)
}
save_table(bind_rows(conditional_info),"conditional_logistic_support",TRUE)

# DEC-028: integer LOCAL calendar date (household offsets from 04a) and local
# weekday. Never use calendar adjustment to recode windows.
# Calendar covariates must not contain time of day, which determines the outcome.
coverage<-primary %>% count(local_date,phase,.drop=FALSE,name="events")
overlap<-coverage %>% group_by(local_date) %>% summarise(both=all(events>0),.groups="drop") %>% filter(both)
M<-model.matrix(~phase+appliance+calendar_day+weekday_local,primary)
save_table(tibble(date_definition="Local date (household device-clock offsets)",
  overlap_dates=nrow(overlap),total_dates=n_distinct(coverage$local_date),
  design_columns=ncol(M),design_rank=qr(M)$rank,
  phase_calendar_correlation=cor(primary$phase01,primary$calendar_day),
  condition_number=kappa(M)),"calendar_adjustment_support",TRUE)
stopifnot(nrow(overlap)>0,qr(M)$rank==ncol(M),is.integer(primary$calendar_day))
calendar_formula<-window_ordered~phase+appliance+weekday_local+calendar_day+(1|household_id)
overlap_primary<-filter(primary,local_date %in% overlap$local_date)
add_ordinal(primary,"Weekday and linear calendar-day adjustment",formula=calendar_formula)
add_ordinal(overlap_primary,"Calendar-overlap dates only, adjusted",formula=calendar_formula)

# DEC-028 documentation: corrected specification versus the integer-UTC variant
# and the superseded continuous-time specification (which contains time of day).
# Diagnostic only; these rows do not enter the sensitivity matrix.
fit_checked<-function(d,formula) {
  obj<-fit_ordinal(d,formula=formula);dg<-ordinal_diagnostic(obj,"calendar comparison")
  if(!dg$accepted || dg$max_abs_gradient>.001 || dg$max_scaled_gradient>.001) {
    obj<-fit_ordinal(d,formula=formula,tight=TRUE);dg<-ordinal_diagnostic(obj,"calendar comparison")
  }
  list(obj=obj,dg=dg)
}
utc_overlap<-primary %>% group_by(utc_date) %>% summarise(both=n_distinct(phase)==2,.groups="drop") %>% filter(both)
calendar_specs<-list(
  list(spec="Corrected (DEC-028): integer local date + local weekday",set="Full primary",
    d=primary,f=calendar_formula),
  list(spec="Corrected (DEC-028): integer local date + local weekday",set="Overlap dates",
    d=overlap_primary,f=calendar_formula),
  list(spec="Comparison: integer UTC date + UTC weekday",set="Full primary",d=primary,
    f=window_ordered~phase+appliance+weekday_utc+utc_date_day+(1|household_id)),
  list(spec="Comparison: integer UTC date + UTC weekday",set="Overlap dates",
    d=filter(primary,utc_date %in% utc_overlap$utc_date),
    f=window_ordered~phase+appliance+weekday_utc+utc_date_day+(1|household_id)),
  list(spec="Superseded: continuous UTC time (includes time of day) + UTC weekday",set="Full primary",d=primary,
    f=window_ordered~phase+appliance+weekday_utc+calendar_time_continuous_utc+(1|household_id)),
  list(spec="Superseded: continuous UTC time (includes time of day) + UTC weekday",set="Overlap dates",
    d=filter(primary,utc_date %in% utc_overlap$utc_date),
    f=window_ordered~phase+appliance+weekday_utc+calendar_time_continuous_utc+(1|household_id)))
calendar_comparison<-bind_rows(lapply(calendar_specs,function(x){
  r<-fit_checked(x$d,x$f)
  bind_cols(tibble(specification=x$spec,event_set=x$set,
    overlap_dates=if(x$set=="Overlap dates") n_distinct(if(grepl("local",x$spec)) x$d$local_date else x$d$utc_date) else NA_integer_),
    effect_row(r$obj,x$spec,x$d) %>% select(n_events,n_households,beta,se,OR,lower,upper,interval),
    tibble(accepted=r$dg$accepted,max_abs_gradient=r$dg$max_abs_gradient))
}))
save_table(calendar_comparison,"calendar_specification_comparison",TRUE)
stopifnot(all(calendar_comparison$accepted),all(calendar_comparison$max_abs_gradient<.001))

# Random-slope sensitivity: AGQ is technically unavailable in >1 dimensions.
rs<-add_ordinal(primary,"Random phase slope (Laplace)",
  formula=window_ordered~phase+appliance+(1+phase01|household_id),nAGQ=1)
if(!is.null(rs$fit)) {
  V<-tcrossprod(rs$fit$ST[[1]])
  correlation<-V[1,2]/sqrt(V[1,1]*V[2,2])
  eig<-eigen(V,symmetric=TRUE,only.values=TRUE)$values
  rsinfo<-tibble(intercept_variance=V[1,1],slope_variance=V[2,2],correlation=correlation,
    covariance_min_eigenvalue=min(eig),near_boundary=min(eig)<1e-4 || abs(correlation)>.99,
    logLik_random_slope=as.numeric(logLik(rs$fit)),
    logLik_intercept_laplace=as.numeric(logLik(readRDS(file.path(model_dir,"primary_models.rds"))$laplace_1$fit)),
    integration="Laplace for both models; no routine chi-square test of variance components")
  save_table(rsinfo,"random_slope_diagnostics",TRUE)
}

# Exploratory appliance interaction: retain regardless of result.
interaction<-fit_ordinal(primary,formula=window_ordered~phase*appliance+(1|household_id))
idg<-ordinal_diagnostic(interaction,"Exploratory phase by appliance")
if(!idg$accepted || idg$max_abs_gradient>.001) {
  interaction<-fit_ordinal(primary,formula=window_ordered~phase*appliance+(1|household_id),tight=TRUE)
  idg<-ordinal_diagnostic(interaction,"Exploratory phase by appliance")
}
save_table(idg,"interaction_diagnostics",TRUE)
models$exploratory_interaction<-interaction
if(!is.null(interaction$fit)) {
  f<-interaction$fit;bb<-f$beta;vv<-vcov(f)[names(bb),names(bb)]
  inter<-bind_rows(lapply(levels(primary$appliance),function(a){
    contrast<-setNames(rep(0,length(bb)),names(bb));contrast["phasenudge"]<-1
    if(a!="dishwasher")contrast[paste0("phasenudge:appliance",a)]<-1
    b<-sum(contrast*bb);s<-sqrt(drop(t(contrast)%*%vv%*%contrast))
    tibble(appliance=a,beta=b,se=s,OR=exp(b),lower=exp(b-1.96*s),upper=exp(b+1.96*s))
  }))
  save_table(inter,"exploratory_appliance_phase_effects")
  save_table(tibble(LRT=2*(as.numeric(logLik(f))-as.numeric(logLik(full$fit))),df=2,
    p=pchisq(2*(as.numeric(logLik(f))-as.numeric(logLik(full$fit))),2,lower.tail=FALSE),
    role="Exploratory; no multiplicity adjustment"),"exploratory_interaction_test",TRUE)
}
saveRDS(models,file.path(model_dir,"sensitivity_models.rds"))
save_table(bind_rows(diagnostics),"sensitivity_numerical_checks",TRUE)
base_effects<-bind_rows(effects)
save_table(base_effects,"sensitivity_effects")

# Leave one complete household out, keeping all rules/covariates unchanged.
influence<-bind_rows(lapply(levels(primary$household_id),function(h){
  dd<-droplevels(filter(primary,household_id!=h))
  obj<-fit_ordinal(dd);dg<-ordinal_diagnostic(obj,"leave_one_out")
  if(!dg$accepted || dg$max_abs_gradient>.001)obj<-fit_ordinal(dd,tight=TRUE)
  dg<-ordinal_diagnostic(obj,"leave_one_out")
  bind_cols(tibble(household_id=h),effect_row(obj,"Leave one household out",dd),
    tibble(accepted=dg$accepted,gradient=dg$max_abs_gradient))
}))
write_csv(influence,file.path(model_dir,"restricted_household_influence.csv"))
stopifnot(all(influence$accepted),all(influence$gradient<.001))
save_table(influence %>% summarise(fits=n(),accepted=sum(accepted),min_OR=min(OR),max_OR=max(OR),
  min_lower=min(lower),max_lower=max(lower),min_upper=min(upper),max_upper=max(upper),
  max_abs_beta_change=max(abs(beta-primary_result$beta)),max_standardised_beta_change=max(abs(beta-primary_result$beta))/primary_result$se,
  direction_reversals=sum(sign(beta)!=sign(primary_result$beta))),"household_influence_summary")
ranked<-influence %>% arrange(beta) %>% mutate(rank=row_number()) %>% select(-household_id)
save_table(ranked,"household_influence_anonymous",TRUE)
fig<-ggplot(ranked,aes(rank,OR))+geom_ribbon(aes(ymin=lower,ymax=upper),alpha=.18,fill="#267F73")+
  geom_line(color="#267F73")+geom_hline(yintercept=c(1,primary_result$OR),linetype=c(3,2))+
  labs(x="Household omission ranked by resulting estimate",y="Conditional common odds ratio",
    caption="Line: leave-one-out estimate; ribbon: Wald 95% interval. No household identifiers shown.")
ggsave(file.path(result_dir,"household_influence.pdf"),fig,width=6.4,height=3.6)
ggsave(file.path(result_dir,"household_influence.png"),fig,width=6.4,height=3.6,dpi=200)

# Supplementary, paired cluster bootstrap fixed before result inspection.
set.seed(24092408);B<-399L
boot<-vector("list",B)
for(i in seq_len(B)) {
  dd<-resample_households(primary)
  of<-fit_ordinal(dd)
  dg<-ordinal_diagnostic(of,"bootstrap")
  if(!dg$accepted)of<-fit_ordinal(dd,tight=TRUE)
  od<-ordinal_diagnostic(of,"bootstrap")
  gf<-fit_binary(dd,"is_great");nf<-fit_binary(dd,"is_not_bad")
  getb<-function(obj,ordinal=FALSE){
    if(is.null(obj$fit))return(NA_real_)
    if(ordinal)unname(obj$fit$beta["phasenudge"]) else unname(fixef(obj$fit)["phasenudge"])
  }
  binary_ok<-function(obj) !is.null(obj$fit) && length(obj$warnings)==0 &&
    is.null(obj$fit@optinfo$conv$lme4$messages) && is.finite(getb(obj))
  boot[[i]]<-tibble(replicate=i,ordinal_beta=if(od$accepted)getb(of,TRUE) else NA_real_,
    great_beta=if(binary_ok(gf))getb(gf) else NA_real_,
    not_bad_beta=if(binary_ok(nf))getb(nf) else NA_real_,
    ordinal_warning=paste(of$warnings,collapse="; "),great_warning=paste(gf$warnings,collapse="; "),
    not_bad_warning=paste(nf$warnings,collapse="; "))
  if(i%%25==0){cat("Bootstrap",i,"of",B,"completed\n");flush.console()}
}
boot<-bind_rows(boot) %>% mutate(threshold_difference=great_beta-not_bad_beta)
save_table(boot,"household_bootstrap_draws",TRUE)
bs<-bind_rows(lapply(c("ordinal_beta","great_beta","not_bad_beta","threshold_difference"),function(nm){
  x<-boot[[nm]];tibble(statistic=nm,requested=B,accepted=sum(is.finite(x)),
    bootstrap_sd=sd(x,na.rm=TRUE),lower=quantile(x,.025,na.rm=TRUE),upper=quantile(x,.975,na.rm=TRUE),seed=24092408)
}))
save_table(bs,"household_bootstrap_summary",TRUE)
bootrow<-primary_result %>% select(analysis,family,n_events,n_households,beta,se,OR,lower,upper,interval,warnings) %>%
  mutate(analysis="Household-bootstrap interval",se=bs$bootstrap_sd[bs$statistic=="ordinal_beta"],
    lower=exp(bs$lower[bs$statistic=="ordinal_beta"]),upper=exp(bs$upper[bs$statistic=="ordinal_beta"]),
    interval="Household bootstrap percentile 95% (399)")
matrix<-bind_rows(base_effects,bootrow) %>% mutate(
  direction_relative_to_primary=if_else(sign(beta)==sign(primary_result$beta),"Same direction","Different direction"),
  magnitude_ratio_to_primary=OR/primary_result$OR,
  interval_includes_one=lower<=1 & upper>=1,
  substantive_conclusion=case_when(
    grepl("Calendar-overlap|Weekday and",analysis)~"Material attenuation: time explanations remain plausible",
    grepl("High-load",analysis)~"Positive association retained; less precise, no measured energy effect",
    grepl("Random phase",analysis)~"Interpret only if covariance and numerical diagnostics acceptable",
    sign(beta)!=sign(primary_result$beta)~"Direction changes; investigate",
    TRUE~"Direction retained; review magnitude, uncertainty and changed target"))
nh<-function(a)base_effects$n_households[base_effects$analysis==a]
ne<-function(a)base_effects$n_events[base_effects$analysis==a]
ci<-bind_rows(conditional_info)
questions<-tibble::tribble(
  ~analysis,~question,~population_or_rule_change,
  "Primary","Did registered timing differ by phase?",sprintf("%d full-opportunity paired households; locked rules",nh("Primary")),
  "All eligible events (including incomplete)","Does paired selection drive the association?",sprintf("%d contributors; allows one-phase and incomplete households",nh("All eligible events (including incomplete)")),
  "Observed Phase-2 exposure","Does documented exposure timing matter?",sprintf("%d households; earliest introduction/response marker; unequal phase lengths",nh("Observed Phase-2 exposure")),
  "High-load appliances only","Does the association persist beyond phone charging?",sprintf("Dishwasher and washing machine events in original primary population; %d contribute",nh("High-load appliances only")),
  "Immediate registrations only","Do backdated records drive the result?","Immediate registrations within original primary population",
  "Exclude four phase-crossing backdates","Do four boundary records matter?","Remove four events; preserve household population",
  "Backdates assigned by registration time","Does assigning reporting time change the result?","Reassign phase for backdated rows; preserve stored outcome",
  "Retain duplicate-flagged events","Does duplicate adjudication drive the result?",sprintf("Restore %d flagged events in fixed %d-household population",ne("Retain duplicate-flagged events")-ne("Primary"),nh("Primary")),
  "All eligible events, full opportunity only","Is administrative truncation influential?",sprintf("%d contributors with full opportunity, regardless of paired contribution",nh("All eligible events, full opportunity only")),
  "Paired contributors including incomplete","What if incomplete paired contributors are retained?",sprintf("%d paired households; %d have truncated opportunity",nh("Paired contributors including incomplete"),nh("Paired contributors including incomplete")-nh("Primary")),
  "Great versus ok/bad","Is the top-category threshold consistent?",sprintf("Binary mixed model; same %s events",format(nrow(primary),big.mark=",")),
  "Great/ok versus bad","Is moving away from bad consistent?",sprintf("Binary mixed model; same %s events",format(nrow(primary),big.mark=",")),
  "Household-stratified: great","Does within-household conditioning change the top threshold?",sprintf("Condition on outcome totals; %d informative households",ci$informative_households[ci$analysis=="Household-stratified: great"]),
  "Household-stratified: great/ok","Does within-household conditioning change the lower threshold?",sprintf("Condition on outcome totals; %d informative households",ci$informative_households[ci$analysis=="Household-stratified: great/ok"]),
  "Weekday and linear calendar-day adjustment","Could calendar time explain the phase association?","Add local weekday and linear integer local calendar date; full primary set",
  "Calendar-overlap dates only, adjusted","Does reliance on disjoint calendar dates matter?",sprintf("Restrict to %d local dates with both phases; add local weekday/calendar-date trend",nrow(overlap)),
  "Random phase slope (Laplace)","Is a common household phase slope too restrictive?","Allow correlated household phase deviations; Laplace likelihood",
  "Household-bootstrap interval","Is uncertainty sensitive to household resampling?","399 household resamples with replacement; same fitted estimand")
matrix<-left_join(matrix,questions,by="analysis")
stopifnot(!anyNA(matrix$question))
save_table(matrix,"sensitivity_matrix")
figdata<-matrix %>% filter(!grepl("Random phase|Paired contributors|full opportunity",analysis)) %>%
  mutate(analysis=factor(analysis,levels=rev(analysis)))
fig<-ggplot(figdata,aes(OR,analysis))+geom_vline(xintercept=1,linetype=3,color="grey40")+
  geom_segment(aes(x=lower,xend=upper,yend=analysis),color="#267F73",linewidth=.65)+
  geom_point(color="#174E49",size=2)+scale_x_log10()+labs(x="Odds ratio (log scale), with 95% interval",y=NULL,
    caption="Targets differ across rows. Primary: profile interval; other model intervals: Wald unless labelled bootstrap.")
ggsave(file.path(result_dir,"sensitivity_forest.pdf"),fig,width=8.6,height=5.5)
ggsave(file.path(result_dir,"sensitivity_forest.png"),fig,width=8.6,height=5.5,dpi=200)
record_session("08_sensitivity")
print(matrix,width=Inf)
