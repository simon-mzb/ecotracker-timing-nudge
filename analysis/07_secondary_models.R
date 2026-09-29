source("analysis/analysis_helpers.R")
binary<-list(great=fit_binary(primary,"is_great"),not_bad=fit_binary(primary,"is_not_bad"))
saveRDS(binary,file.path(model_dir,"binary_models.rds"))
save_table(bind_rows(effect_row(binary$great,"Great versus ok/bad",primary,family="Binary GLMM"),
  effect_row(binary$not_bad,"Great/ok versus bad",primary,family="Binary GLMM")),"binary_effects")
save_table(bind_rows(coefficient_table(binary$great,"Great versus ok/bad"),
  coefficient_table(binary$not_bad,"Great/ok versus bad")),"binary_coefficients")
binary_diag<-function(obj,label) {
  f<-obj$fit
  if(is.null(f))return(tibble(model=label,accepted=FALSE,error=obj$error))
  ev<-eigen(f@optinfo$derivs$Hessian,symmetric=TRUE,only.values=TRUE)$values
  messages<-paste(f@optinfo$conv$lme4$messages,collapse="; ")
  tibble(model=label,accepted=length(obj$warnings)==0 && messages=="" && min(ev)>0,
    singular=isSingular(f),variance=as.numeric(VarCorr(f)[[1]][1,1]),
    hessian_min_eigenvalue=min(ev),max_abs_gradient=max(abs(f@optinfo$derivs$gradient)),
    convergence_messages=messages,warnings=paste(obj$warnings,collapse="; "),error=obj$error)
}
save_table(bind_rows(binary_diag(binary$great,"Great versus ok/bad"),
  binary_diag(binary$not_bad,"Great/ok versus bad")),"binary_diagnostics",TRUE)

set.seed(24092407);B<-10000L
decision_summary<-function(d,label,equal=FALSE) {
  counts<-d %>% group_by(household_id) %>% summarise(wait=sum(wait),decisions=n(),.groups="drop")
  statistic<-function(x)if(equal)mean(x$wait/x$decisions) else sum(x$wait)/sum(x$decisions)
  draws<-replicate(B,statistic(counts[sample(seq_len(nrow(counts)),nrow(counts),replace=TRUE),]))
  tibble(analysis=label,households=nrow(counts),decisions=sum(counts$decisions),waits=sum(counts$wait),
    proportion=statistic(counts),lower=quantile(draws,.025),upper=quantile(draws,.975),
    method="Household bootstrap percentile 95%",replicates=B,seed=24092407)
}
main<-read_set("bad_window_decisions")
stopifnot(nrow(main)==106,n_distinct(main$household_id)==35,all(main$window=="bad"))
incl_rewritten<-read_set("bad_window_decisions_incl_rewritten")  # DEC-030 sensitivity only
stopifnot(nrow(incl_rewritten)==139,n_distinct(incl_rewritten$household_id)==51)
retained<-read_set("decision_exclusion_audit") %>% filter(passes_recorded_decision_window,window=="bad")
decisions<-bind_rows(
  decision_summary(main,"Main: all eligible recorded bad-window decisions"),
  decision_summary(read_set("bad_window_decisions_primary_population"),"Primary-population decisions"),
  decision_summary(main,"Equal-household mean wait proportion",TRUE),
  decision_summary(read_set("bad_window_decisions_exposure_marker"),"Observed-exposure decisions"),
  decision_summary(retained,"Retain duplicate-flagged decisions"),
  decision_summary(incl_rewritten,"Including households with rewritten records (DEC-030)"))
save_table(decisions,"decision_proportions")
save_table(main %>% group_by(appliance) %>% summarise(households=n_distinct(household_id),
  decisions=n(),waits=sum(wait),proportion=mean(wait),.groups="drop"),"decision_appliance_descriptives")
save_table(main %>% group_by(suggested_wait_hours) %>% summarise(decisions=n(),waits=sum(wait),
  households=n_distinct(household_id),.groups="drop"),"decision_wait_duration_descriptives")

# Exploratory feasibility checks are minimum screens, not guarantees of stability.
complete<-main %>% filter(!is.na(suggested_wait_hours),!is.na(appliance)) %>%
  mutate(appliance=factor(appliance,levels=c("dishwasher","washing_machine","phone_charging")),household_id=factor(household_id))
cells<-complete %>% count(appliance,wait,.drop=FALSE)
feasible<-sum(complete$wait)>=10 && sum(!complete$wait)>=10 &&
  n_distinct(complete$household_id[complete$wait])>=5 && all(cells$n>0)
status<-paste("Exploratory model not fitted: insufficient outcome/household support or empty appliance-response cells.")
if(feasible) {
  waitfit<-capture_fit(glmer(wait~suggested_wait_hours+appliance+(1|household_id),data=complete,
    family=binomial,nAGQ=7,control=glmerControl(optimizer="bobyqa",optCtrl=list(maxfun=200000))))
  saveRDS(waitfit,file.path(model_dir,"exploratory_wait_model.rds"))
  wd<-binary_diag(waitfit,"Exploratory waiting model")
  save_table(wd,"exploratory_wait_diagnostics",TRUE)
  if(!is.null(waitfit$fit)) {
    save_table(coefficient_table(waitfit,"Exploratory waiting model"),"exploratory_wait_coefficients",TRUE)
    status<-if(wd$accepted && !wd$singular) "Exploratory fit accepted; delay is confounded with clock time, not a causal delay effect." else
      "Exploratory fit attempted but not accepted as stable (boundary/singularity or numerical issues); prioritise descriptive results."
  } else status<-paste("Exploratory model failed:",waitfit$error)
}
writeLines(c(status,paste("Complete decisions:",nrow(complete)),paste("Households with at least one wait:",n_distinct(complete$household_id[complete$wait])),
  "No nudge impressions or abandoned dialogues are observed; decline is an intention, not verified rescheduling."),file.path(diagnostic_dir,"exploratory_wait_status.txt"))
record_session("07_secondary")
print(decisions,width=Inf);cat(status,"\n")
