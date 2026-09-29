# DEC-029: post-hoc checks of the primary CLMM, following the course lecture on
# mixed models (variance partition, naive-vs-mixed comparison, level-2 check,
# random-effect/predictor independence) plus the 2026-09-27 audit findings
# (region blocks, registration rates, declines, within-phase trend,
# population-averaged probabilities) and, since DEC-030, the single comparison
# that includes the households whose records were rewritten after collection. Everything here is post hoc and
# supplementary; none of it replaces the locked primary model or test.
source("analysis/analysis_helpers.R")
full<-readRDS(file.path(model_dir,"primary_models.rds"))$primary_7$fit
p<-read_csv(file.path(result_dir,"primary_effect.csv"),show_col_types=FALSE)
stopifnot(isTRUE(all.equal(unname(full$beta["phasenudge"]),p$beta,tolerance=1e-10)))
models<-list();numerics<-list()
fit_accepted<-function(d,formula,label,nAGQ=7) {
  obj<-fit_ordinal(d,formula=formula,nAGQ=nAGQ);dg<-ordinal_diagnostic(obj,label)
  if(!dg$accepted || dg$max_abs_gradient>.001 || dg$max_scaled_gradient>.001) {
    obj<-fit_ordinal(d,formula=formula,nAGQ=nAGQ,tight=TRUE);dg<-ordinal_diagnostic(obj,label)
  }
  numerics[[label]]<<-dg;models[[label]]<<-obj
  if(!dg$accepted || dg$max_abs_gradient>.001 || dg$max_scaled_gradient>.001)
    stop(paste("Post-hoc check requires numerical troubleshooting:",label))
  obj$fit
}
wald<-function(b,se)tibble(beta=b,se=se,OR=exp(b),lower=exp(b-1.96*se),upper=exp(b+1.96*se))
phase_row<-function(f,label,d,term="phasenudge")
  bind_cols(tibble(check=label,n_events=nrow(d),n_households=n_distinct(d$household_id)),
    wald(unname(f$beta[term]),unname(sqrt(diag(vcov(f)))[term])))
checks<-list()

# 1. Variance partition and naive (single-level) versus mixed model (lecture pp. 27-29).
s2<-as.numeric(VarCorr(full)$household_id);su<-sqrt(s2)
naive<-ordinal::clm(window_ordered~phase+appliance,data=primary,link="logit")
stopifnot(naive$convergence$code==0)
boot_sd<-read_csv(file.path(diagnostic_dir,"household_bootstrap_summary.csv"),show_col_types=FALSE) %>%
  filter(statistic=="ordinal_beta") %>% pull(bootstrap_sd)
variance<-tibble(random_intercept_variance=s2,random_intercept_sd=su,
  latent_icc=s2/(s2+pi^2/3),median_odds_ratio=exp(sqrt(2*s2)*qnorm(.75)),
  households=nlevels(primary$household_id),events=nrow(primary))
naive_vs_mixed<-bind_rows(
  bind_cols(tibble(model="Naive CLM (households ignored)",estimand="Population-averaged; events treated as independent"),
    wald(unname(naive$beta["phasenudge"]),unname(sqrt(diag(vcov(naive)))["phasenudge"]))),
  bind_cols(tibble(model="Primary CLMM (household random intercept)",estimand="Household-conditional"),
    wald(p$beta,p$se)),
  tibble(model="Primary CLMM, household-bootstrap SD (399, from 08)",estimand="Household-conditional",
    beta=p$beta,se=boot_sd))
save_table(variance,"mixed_model_variance")
save_table(naive_vs_mixed,"naive_vs_mixed_phase")

# 2. Level-2 check: QQ plot of conditional modes (lecture p. 33). Conditional
# modes are shrunk towards zero, so their spread understates sigma_u and the
# plot is only a coarse check of gross departures. Level-1 Gaussian residual
# checks do not transfer to a cumulative-link model; see 3 and 4 instead.
re<-ranef(full,condVar=TRUE)$household_id
modes<-re[,1]
qq<-tibble(sample=sort(modes),theoretical=qnorm(ppoints(length(modes))))
save_table(tibble(households=length(modes),mode_sd=sd(modes),random_intercept_sd=su,
  shrinkage_ratio=sd(modes)/su,min_mode=min(modes),max_mode=max(modes),
  skewness=mean((modes-mean(modes))^3)/sd(modes)^3),"level2_conditional_modes",TRUE)
fig<-ggplot(qq,aes(theoretical,sample))+geom_abline(intercept=0,slope=sd(modes),linetype=2,color="grey45")+
  geom_point(color="#267F73",size=1.8)+labs(x="Theoretical normal quantiles",y="Household conditional mode (logit scale)",
    caption=paste0(nlevels(primary$household_id)," households, no identifiers. Dashed: normal line with the SD of the\nconditional modes; modes are shrunk towards 0."))+theme(plot.caption=element_text(hjust=0))
ggsave(file.path(diagnostic_dir,"level2_qq_conditional_modes.pdf"),fig,width=5.2,height=4)
ggsave(file.path(diagnostic_dir,"level2_qq_conditional_modes.png"),fig,width=5.2,height=4,dpi=200)

# 3. Proportional odds: nominal test in the single-level CLM (clmm has no
# nominal effects). Complements the two binary mixed models from 07/08.
nt<-ordinal::nominal_test(naive)
save_table(tibble(term=rownames(nt),df=nt$Df,LRT=nt$LRT,p=nt[["Pr(>Chi)"]]) %>% filter(!is.na(df)),
  "proportional_odds_nominal_test",TRUE)

# 4. Calibration: observed category shares versus shares simulated from the
# fitted CLMM with NEW household intercepts u ~ N(0, sigma_u^2).
alpha<-full$alpha;beta<-full$beta
X<-model.matrix(~phase+appliance,primary)[,names(beta),drop=FALSE]
eta<-as.numeric(X%*%beta);hh<-as.integer(primary$household_id);nh<-max(hh)
cells<-interaction(primary$phase,primary$appliance,drop=TRUE,sep=" / ")
cellp<-interaction(primary$phase,drop=TRUE)
set.seed(24092709);R<-2000L
obs_score<-tapply(as.integer(primary$window_ordered),hh,mean)
sim<-replicate(R,{
  lin<-eta+rnorm(nh,0,su)[hh];U<-runif(length(lin))
  y<-1L+(U>plogis(alpha[1]-lin))+(U>plogis(alpha[2]-lin))
  c(as.vector(sapply(1:3,function(k)tapply(y==k,cells,mean))),
    as.vector(sapply(1:3,function(k)tapply(y==k,cellp,mean))),
    sd(tapply(y,hh,mean)))
})
lab<-c(paste(rep(levels(cells),3),rep(c("bad","ok","great"),each=nlevels(cells)),sep=" | "),
  paste(rep(levels(cellp),3),rep(c("bad","ok","great"),each=nlevels(cellp)),sep=" | "),
  "SD of household mean category score")
obs<-c(as.vector(sapply(levels(primary$window_ordered),function(k)tapply(primary$window_ordered==k,cells,mean))),
  as.vector(sapply(levels(primary$window_ordered),function(k)tapply(primary$window_ordered==k,cellp,mean))),
  sd(obs_score))
n_cell<-c(rep(as.vector(table(cells)),3),rep(as.vector(table(cellp)),3),nh)
calibration<-tibble(cell=lab,n=n_cell,observed=obs,simulated_mean=rowMeans(sim),
  sim_lower=apply(sim,1,quantile,.025),sim_upper=apply(sim,1,quantile,.975),
  inside_95=observed>=sim_lower & observed<=sim_upper,
  tail_probability=pmin(1,2*pmin(rowMeans(sim>=obs),rowMeans(sim<=obs))),replicates=R,seed=24092709)
save_table(calibration,"clmm_calibration_check",TRUE)

# 5. Random-intercept/predictor independence (lecture p. 31 relies on
# randomisation, which this study lacks): Mundlak within/between CLMM.
mund<-primary %>% group_by(household_id) %>% mutate(phase_mean=mean(phase01),
  washing_mean=mean(appliance=="washing_machine"),phone_mean=mean(appliance=="phone_charging")) %>% ungroup()
fm<-fit_accepted(mund,window_ordered~phase+appliance+phase_mean+washing_mean+phone_mean+(1|household_id),"Mundlak within-household")
checks[["mundlak"]]<-phase_row(fm,"Mundlak: within-household phase",mund)
ctx<-names(fm$beta)[names(fm$beta) %in% c("phase_mean","washing_mean","phone_mean")]
bctx<-fm$beta[ctx];vctx<-vcov(fm)[ctx,ctx]
save_table(tibble(contextual_terms=paste(ctx,collapse=", "),wald_chisq=drop(t(bctx)%*%solve(vctx)%*%bctx),df=length(ctx),
  p=pchisq(drop(t(bctx)%*%solve(vctx)%*%bctx),length(ctx),lower.tail=FALSE),
  phase_contextual_beta=unname(fm$beta["phase_mean"]),phase_contextual_se=unname(sqrt(vcov(fm)["phase_mean","phase_mean"]))),
  "mundlak_contextual_test",TRUE)

# 6. Region/clock blocks (04a). Stored labels follow each device clock.
tz<-read_csv(file.path(analysis_dir,"household_timezone.csv"),col_types=cols(household_id=col_character()),show_col_types=FALSE)
reg<-primary %>% mutate(region=factor(tz$region[match(as.character(household_id),tz$household_id)]))
reg$region<-relevel(reg$region,"Germany")
f1<-fit_accepted(reg,window_ordered~phase*region+appliance+(1|household_id),"Region interaction")
f0<-fit_accepted(reg,window_ordered~phase+region+appliance+(1|household_id),"Region main effects")
bb<-f1$beta;vv<-vcov(f1)[names(bb),names(bb)]
region_effects<-bind_rows(lapply(levels(reg$region),function(r){
  cvec<-setNames(rep(0,length(bb)),names(bb));cvec["phasenudge"]<-1
  if(r!="Germany")cvec[paste0("phasenudge:region",r)]<-1
  bind_cols(tibble(region=r,households=n_distinct(reg$household_id[reg$region==r]),events=sum(reg$region==r)),
    wald(sum(cvec*bb),sqrt(drop(t(cvec)%*%vv%*%cvec))))
}))
lr<-2*(as.numeric(logLik(f1))-as.numeric(logLik(f0)))
region_effects$interaction_LR<-lr;region_effects$interaction_df<-nlevels(reg$region)-1
region_effects$interaction_p<-pchisq(lr,nlevels(reg$region)-1,lower.tail=FALSE)
save_table(region_effects,"region_phase_effects")

# 7. DEC-030 sensitivity: the primary model refitted on the locked primary set
# built WITHOUT the record-integrity exclusion (04 --include-rewritten). This is
# the only analysis that uses the 21 households with rewritten records.
incl<-prepare_events(read_set("primary_events_incl_rewritten"),calendar=FALSE)
stopifnot(nrow(incl)==1001L,n_distinct(incl$household_id)==63L,all(primary$analysis_event_id %in% incl$analysis_event_id))
fi<-fit_accepted(incl,window_ordered~phase+appliance+(1|household_id),"Including households with rewritten records")
checks[["incl_rewritten"]]<-phase_row(fi,"Including households with rewritten records (DEC-030)",incl)

# 8. What is measured: registration counts by household x phase x window
# (Poisson GLMM with observation-level random effect for overdispersion).
cnt<-primary %>% count(household_id,phase,window_ordered,.drop=FALSE,name="events") %>%
  mutate(window=relevel(factor(as.character(window_ordered)),"great"),obs=factor(row_number()))
stopifnot(nrow(cnt)==42*2*3,sum(cnt$events)==nrow(primary))
pm<-capture_fit(lme4::glmer(events~phase*window+(1|household_id)+(1|obs),family=poisson,data=cnt,nAGQ=1,
  control=glmerControl(optimizer="bobyqa",optCtrl=list(maxfun=200000))))
stopifnot(!is.null(pm$fit),length(pm$warnings)==0,is.null(pm$fit@optinfo$conv$lme4$messages))
models[["Registration count model"]]<-pm
cf<-fixef(pm$fit);V<-vcov(pm$fit)
rr<-function(v){e<-sum(cf[v]);s<-sqrt(sum(as.matrix(V[v,v])));tibble(rate_ratio=exp(e),lower=exp(e-1.96*s),upper=exp(e+1.96*s))}
hh_counts<-primary %>% count(household_id,phase,window_ordered,.drop=FALSE) %>%
  tidyr::pivot_wider(names_from=phase,values_from=n)
rates<-bind_rows(
  bind_cols(tibble(window="great"),rr("phasenudge")),
  bind_cols(tibble(window="ok"),rr(c("phasenudge","phasenudge:windowok"))),
  bind_cols(tibble(window="bad"),rr(c("phasenudge","phasenudge:windowbad")))) %>%
  left_join(primary %>% count(window=as.character(window_ordered),phase) %>% tidyr::pivot_wider(names_from=phase,values_from=n,names_prefix="events_"),by="window") %>%
  left_join(hh_counts %>% group_by(window=as.character(window_ordered)) %>%
    summarise(households_fewer=sum(nudge<baseline),households_more=sum(nudge>baseline),households_equal=sum(nudge==baseline),.groups="drop"),by="window")
save_table(rates,"registration_rate_ratios")

# Stated waits counted as unregistered bad-window uses (bounding the effect of
# the confirmation dialog removing bad uses from the registered outcome).
waits<-read_set("bad_window_decisions_primary_population") %>% filter(wait)
stopifnot(nrow(waits)==9,all(waits$window=="bad"),all(waits$decision_phase=="nudge"))
cols<-c("analysis_event_id","household_id","appliance","event_time","phase","window_ordered")
dw<-prepare_events(bind_rows(read_set("primary_events")[cols],
  waits %>% transmute(analysis_event_id=decision_id,household_id,appliance,event_time=decision_time,phase="nudge",window_ordered="bad")))
fw<-fit_accepted(dw,window_ordered~phase+appliance+(1|household_id),"Waits counted as bad-window uses")
checks[["waits"]]<-phase_row(fw,"Stated waits counted as bad-window uses",dw)

# 9. Exploratory within-phase trend on integer study day (no time of day):
# t = 0 at the phase boundary; phase coefficient = level change at the boundary.
tr<-primary %>% mutate(t=as.numeric(study_day)-7.5)
stopifnot(all(tr$t[tr$phase=="baseline"]<0),all(tr$t[tr$phase=="nudge"]>0))
ft<-fit_accepted(tr,window_ordered~phase*t+appliance+(1|household_id),"Within-phase trend")
b<-ft$beta;V<-vcov(ft)
trend<-bind_rows(
  bind_cols(tibble(term="Baseline slope per study day"),wald(b["t"],sqrt(V["t","t"]))),
  bind_cols(tibble(term="Nudge-phase slope per study day"),wald(b["t"]+b["phasenudge:t"],sqrt(V["t","t"]+V["phasenudge:t","phasenudge:t"]+2*V["t","phasenudge:t"]))),
  bind_cols(tibble(term="Slope difference"),wald(b["phasenudge:t"],sqrt(V["phasenudge:t","phasenudge:t"]))),
  bind_cols(tibble(term="Level change at phase boundary"),wald(b["phasenudge"],sqrt(V["phasenudge","phasenudge"])))) %>%
  mutate(role="Exploratory; odds ratios per day or at the boundary")
save_table(trend,"within_phase_trend")

# 10. Population-averaged (marginal) category probabilities: integrate the
# CLMM over u ~ N(0, sigma_u^2), standardised to the pooled appliance mix used
# for the conditional predictions in 06. Household bootstrap for uncertainty.
weights<-prop.table(table(primary$appliance))
grid<-expand_grid(phase=levels(primary$phase),appliance=levels(primary$appliance)) %>%
  mutate(phase=factor(phase,levels=levels(primary$phase)),appliance=factor(appliance,levels=levels(primary$appliance)))
Xg<-model.matrix(~phase+appliance,grid)[,-1,drop=FALSE]
category_probs<-function(alpha,beta,sd,marginal=TRUE) {
  eta<-as.numeric(Xg[,names(beta)]%*%beta)
  cum<-sapply(alpha,function(a)sapply(eta,function(e)
    if(marginal) integrate(function(u)plogis(a-e-u)*dnorm(u,0,sd),-Inf,Inf,rel.tol=1e-10)$value else plogis(a-e)))
  pr<-cbind(bad=cum[,1],ok=cum[,2]-cum[,1],great=1-cum[,2])*as.numeric(weights[as.character(grid$appliance)])
  out<-rowsum(pr,as.character(grid$phase))[levels(primary$phase),]
  c(setNames(as.vector(t(out)),paste(rep(rownames(out),each=3),colnames(out),sep="_")),
    diff_bad=out["nudge","bad"]-out["baseline","bad"],diff_great=out["nudge","great"]-out["baseline","great"])
}
point_marg<-category_probs(full$alpha,full$beta,su)
point_cond<-category_probs(full$alpha,full$beta,su,marginal=FALSE)
cond06<-read_csv(file.path(result_dir,"conditional_category_probabilities.csv"),show_col_types=FALSE)
stopifnot(all(abs(point_cond[paste(cond06$phase,cond06$window,sep="_")]-cond06$probability)<1e-10))
set.seed(24092710);B<-as.integer(Sys.getenv("SUSAI_08B_BOOT","399"))  # env override only for smoke tests
draws<-vector("list",B)
for(i in seq_len(B)) {
  dd<-resample_households(primary)
  of<-fit_ordinal(dd);dg<-ordinal_diagnostic(of,"marginal bootstrap")
  if(!dg$accepted)of<-fit_ordinal(dd,tight=TRUE)
  ok<-ordinal_diagnostic(of,"marginal bootstrap")$accepted
  draws[[i]]<-if(ok) c(replicate=i,category_probs(of$fit$alpha,of$fit$beta,sqrt(as.numeric(VarCorr(of$fit)$household_id)))) else c(replicate=i)
  if(i%%50==0){cat("Marginal bootstrap",i,"of",B,"\n");flush.console()}
}
draws<-bind_rows(lapply(draws,function(x)as_tibble(as.list(x))))
save_table(draws,"marginal_probability_bootstrap_draws",TRUE)
marginal<-tibble(quantity=names(point_marg),population_averaged=unname(point_marg),
  conditional_u0=unname(point_cond[names(point_marg)])) %>%
  mutate(boot_lower=sapply(quantity,function(q)quantile(draws[[q]],.025,na.rm=TRUE)),
    boot_upper=sapply(quantity,function(q)quantile(draws[[q]],.975,na.rm=TRUE)),
    boot_accepted=sapply(quantity,function(q)sum(is.finite(draws[[q]]))),seed=24092710,
    interval="Household bootstrap percentile 95% (399)")
save_table(marginal,"marginal_category_probabilities")
stopifnot(all(marginal$boot_accepted>=.95*B))

checks<-bind_rows(checks) %>% mutate(interval="Wald 95%",role="Post hoc (DEC-029); does not replace primary")
save_table(checks,"posthoc_phase_checks")
save_table(bind_rows(numerics),"posthoc_numerical_checks",TRUE)
saveRDS(models,file.path(model_dir,"mixed_model_checks.rds"))
record_session("08b_mixed_model_checks")
print(variance);print(naive_vs_mixed);print(checks,width=Inf);print(region_effects,width=Inf)
print(rates,width=Inf);print(trend,width=Inf);print(marginal,width=Inf)
print(calibration %>% filter(!inside_95),width=Inf)
