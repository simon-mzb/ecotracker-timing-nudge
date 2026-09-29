# Reproduce the paper's statistics from the published de-identified tables.
#
# Run from the repository root:
#   Rscript reproduce/reproduce_paper.R          # everything (household bootstraps take several minutes)
#   Rscript reproduce/reproduce_paper.R --fast   # skip the two 399-replicate CLMM bootstraps
#
# Inputs:  data/*.csv (de-identified tables) and results/*.csv (the pipeline's aggregate outputs).
# Output:  reproduce/reproduction_report.csv and a printed summary. Every reproduced value is
#          compared with the value the original pipeline (analysis/) wrote to results/.
#
# Model specifications, optimiser settings and acceptance checks are copied from
# analysis/analysis_helpers.R, 06_primary_model.R, 07_secondary_models.R,
# 08_sensitivity_analyses.R, 08b_mixed_model_checks.R and 05c_registration_patterns.R.
# Deterministic quantities must match to numerical precision. Household-bootstrap
# intervals resample households in the order of their codes; because the published codes
# are random, the resampled sets differ from the original run, so these intervals agree
# only up to Monte Carlo error (reported, with a looser tolerance).
suppressPackageStartupMessages({library(dplyr);library(tidyr);library(readr);library(ordinal);library(lme4)})
options(contrasts=c("contr.treatment","contr.poly"))
fast<-"--fast" %in% commandArgs(trailingOnly=TRUE)
rd<-function(p)read_csv(p,show_col_types=FALSE)

# ---------------------------------------------------------------- data
households<-rd("data/households.csv")
events<-rd("data/events.csv")
member<-rd("data/event_set_membership.csv")
decisions<-rd("data/decisions.csv")
dmember<-rd("data/decision_set_membership.csv")

event_set<-function(s) member %>% filter(analysis_set==s) %>% select(event_code,phase) %>%
  inner_join(events %>% select(-event_phase,-registration_phase),by="event_code") %>%
  rename(household_id=household_code,window_ordered=window)
decision_set<-function(s) decisions %>% filter(decision_code %in% dmember$decision_code[dmember$analysis_set==s]) %>%
  rename(household_id=household_code)

prepare_events<-function(d,calendar=TRUE){
  stopifnot(!anyDuplicated(d$event_code),all(d$phase %in% c("baseline","nudge")),
    all(d$window_ordered %in% c("bad","ok","great")))
  d$phase<-factor(d$phase,levels=c("baseline","nudge"))
  d$appliance<-droplevels(factor(d$appliance,levels=c("dishwasher","washing_machine","phone_charging")))
  d$window_ordered<-ordered(d$window_ordered,levels=c("bad","ok","great"))
  d$household_id<-factor(d$household_id)
  d$phase01<-as.integer(d$phase=="nudge")
  d$is_great<-as.integer(d$window_ordered=="great");d$is_not_bad<-as.integer(d$window_ordered!="bad")
  if(calendar){stopifnot(!anyNA(d$calendar_day));d$weekday_local<-factor(d$weekday_local,levels=1:7)
    d$calendar_day<-as.integer(d$calendar_day)}
  d
}

# ------------------------------------------------ model helpers (from the pipeline)
capture_fit<-function(expr){warnings<-character()
  ans<-tryCatch(withCallingHandlers(expr,warning=function(w){warnings<<-c(warnings,conditionMessage(w));invokeRestart("muffleWarning")}),
    error=function(e)e)
  list(fit=if(inherits(ans,"error"))NULL else ans,warnings=unique(warnings),error=if(inherits(ans,"error"))conditionMessage(ans) else "")}
fit_ordinal<-function(d,nAGQ=7,formula=window_ordered~phase+appliance+(1|household_id),tight=FALSE)
  capture_fit(ordinal::clmm(formula,data=d,link="logit",Hess=TRUE,nAGQ=nAGQ,
    control=if(tight)clmm.control(method="ucminf",maxIter=200,gradTol=1e-5,grtol=1e-4,maxeval=1000) else clmm.control()))
fit_binary<-function(d,outcome)capture_fit(lme4::glmer(as.formula(paste0(outcome,"~phase+appliance+(1|household_id)")),
  data=d,family=binomial,nAGQ=7,control=glmerControl(optimizer="bobyqa",optCtrl=list(maxfun=200000))))
accepted<-function(obj){f<-obj$fit;if(is.null(f))return(FALSE)
  ev<-eigen(f$Hessian,symmetric=TRUE,only.values=TRUE)$values
  se<-tryCatch(sqrt(diag(vcov(f))),error=function(e)NA)
  optcode<-f$optRes$convergence
  ok<-if(f$control$method=="ucminf")optcode %in% c(1L,2L) else optcode==0L
  length(obj$warnings)==0 && all(is.finite(c(f$coefficients,se))) && min(ev)>0 && isTRUE(ok) &&
    max(abs(f$gradient))<=.001 && max(abs(solve(chol(f$Hessian),f$gradient)))<=.001}
fit_ok<-function(d,formula=window_ordered~phase+appliance+(1|household_id),nAGQ=7){
  obj<-fit_ordinal(d,nAGQ=nAGQ,formula=formula)
  if(!accepted(obj))obj<-fit_ordinal(d,nAGQ=nAGQ,formula=formula,tight=TRUE)
  stopifnot(accepted(obj));obj$fit}
wald<-function(f,term="phasenudge"){b<-if(inherits(f,"merMod"))fixef(f)[term] else if(inherits(f,"clm")|inherits(f,"clmm"))f$beta[term] else coef(f)[term]
  s<-sqrt(diag(vcov(f)))[term];c(OR=unname(exp(b)),lower=unname(exp(b-1.96*s)),upper=unname(exp(b+1.96*s)),beta=unname(b))}
resample_households<-function(d){g<-split(d,d$household_id,drop=TRUE);sel<-sample(seq_along(g),length(g),replace=TRUE)
  out<-bind_rows(lapply(seq_along(sel),function(j){x<-g[[sel[j]]];x$household_id<-as.character(j);x}))
  out$household_id<-factor(out$household_id);out}

# ------------------------------------------------ report
report<-list()
chk<-function(section,quantity,reproduced,expected,tol=1e-4,kind="deterministic"){
  report[[length(report)+1L]]<<-tibble(section=section,quantity=quantity,reproduced=as.numeric(reproduced),
    expected=as.numeric(expected),abs_diff=abs(as.numeric(reproduced)-as.numeric(expected)),tolerance=tol,kind=kind,
    match=abs(as.numeric(reproduced)-as.numeric(expected))<=tol)}
R<-function(f)rd(file.path("results",f))
sens<-R("sensitivity_effects.csv");sget<-function(a,col)sens[[col]][sens$analysis==a]

# ------------------------------------------------ descriptives (Results, Table 1)
primary<-prepare_events(event_set("primary_events"))
stopifnot(nrow(primary)==802,n_distinct(primary$household_id)==42)
tab<-primary %>% count(phase,window_ordered)
exp_rr<-R("registration_rate_ratios.csv")
for(w in c("bad","ok","great"))for(ph in c("baseline","nudge"))
  chk("Table 1",paste("events",ph,w),tab$n[tab$phase==ph & tab$window_ordered==w],exp_rr[[paste0("events_",ph)]][exp_rr$window==w],0)
chk("Results","phone-charging share (%)",100*mean(primary$appliance=="phone_charging"),66.1,.05)
chk("Results","retrospective entries",sum(primary$is_backdated),198,0)
perhh<-primary %>% count(household_id,phase) %>% group_by(phase) %>%
  summarise(med=median(n),q1=quantile(n,.25),q3=quantile(n,.75))
for(ph in c("baseline","nudge"))for(s in c("med","q1","q3"))
  chk("Results",paste("registrations per household",ph,s),perhh[[s]][perhh$phase==ph],
    c(baseline=c(med=11,q1=8.25,q3=13.75),nudge=c(med=7,q1=4.25,q3=10.75))[paste0(ph,".",s)],0)

# ------------------------------------------------ primary model (RQ1)
full<-fit_ok(primary)
null<-fit_ok(primary,window_ordered~appliance+(1|household_id))
pe<-R("primary_effect.csv")
lrt<-2*(as.numeric(logLik(full))-as.numeric(logLik(null)))
chk("RQ1","phase beta",full$beta["phasenudge"],pe$beta,1e-4)
chk("RQ1","phase OR",exp(full$beta["phasenudge"]),pe$OR,1e-4)
chk("RQ1","LR chi-square",lrt,pe$LRT,1e-3)
chk("RQ1","p value",pchisq(lrt,1,lower.tail=FALSE),pe$p,1e-6)
su<-unname(full$ST[[1]][1,1]);chk("RQ1","sigma_u",su,R("mixed_model_variance.csv")$random_intercept_sd,1e-4)
# profile likelihood CI: phase coefficient fixed as an offset, all nuisance parameters re-optimised
profile_ll<-function(b){dd<-primary;dd$phase_offset<-b*dd$phase01
  as.numeric(logLik(fit_ok(dd,window_ordered~appliance+offset(phase_offset)+(1|household_id))))}
beta<-unname(full$beta["phasenudge"]);se<-sqrt(vcov(full)["phasenudge","phasenudge"])
obj<-function(b)2*(as.numeric(logLik(full))-profile_ll(b))-qchisq(.95,1)
ci<-sapply(c(-1,1),function(dir){w<-2*se;while(obj(beta+dir*w)<0)w<-w*1.5
  uniroot(obj,sort(c(beta,beta+dir*w)),tol=1e-6)$root})
chk("RQ1","profile CI lower",exp(ci[1]),pe$lower,1e-3);chk("RQ1","profile CI upper",exp(ci[2]),pe$upper,1e-3)

# population-averaged category shares at the pooled appliance mix (08b)
weights<-prop.table(table(primary$appliance))
grid<-expand_grid(phase=levels(primary$phase),appliance=levels(primary$appliance)) %>%
  mutate(phase=factor(phase,levels=levels(primary$phase)),appliance=factor(appliance,levels=levels(primary$appliance)))
Xg<-model.matrix(~phase+appliance,grid)[,-1,drop=FALSE]
category_probs<-function(alpha,beta,sd){eta<-as.numeric(Xg[,names(beta)]%*%beta)
  cum<-sapply(alpha,function(a)sapply(eta,function(e)integrate(function(u)plogis(a-e-u)*dnorm(u,0,sd),-Inf,Inf,rel.tol=1e-10)$value))
  pr<-cbind(bad=cum[,1],ok=cum[,2]-cum[,1],great=1-cum[,2])*as.numeric(weights[as.character(grid$appliance)])
  out<-rowsum(pr,as.character(grid$phase))[levels(primary$phase),]
  c(setNames(as.vector(t(out)),paste(rep(rownames(out),each=3),colnames(out),sep="_")),
    diff_bad=out["nudge","bad"]-out["baseline","bad"],diff_great=out["nudge","great"]-out["baseline","great"])}
marg<-category_probs(full$alpha,full$beta,su);em<-R("marginal_category_probabilities.csv")
for(q in c("baseline_great","nudge_great","baseline_bad","nudge_bad","diff_great"))
  chk("RQ1",paste("population-averaged",q),marg[q],em$population_averaged[em$quantity==q],1e-5)

# ------------------------------------------------ what changed (post hoc)
cnt<-primary %>% count(household_id,phase,window_ordered,.drop=FALSE,name="events") %>%
  mutate(window=relevel(factor(as.character(window_ordered)),"great"),obs=factor(row_number()))
pm<-capture_fit(lme4::glmer(events~phase*window+(1|household_id)+(1|obs),family=poisson,data=cnt,nAGQ=1,
  control=glmerControl(optimizer="bobyqa",optCtrl=list(maxfun=200000))))
stopifnot(!is.null(pm$fit),length(pm$warnings)==0)
cf<-fixef(pm$fit);V<-vcov(pm$fit)
rr<-function(v){e<-sum(cf[v]);s<-sqrt(sum(as.matrix(V[v,v])));c(exp(e),exp(e-1.96*s),exp(e+1.96*s))}
for(w in c("great","ok","bad")){v<-if(w=="great")"phasenudge" else c("phasenudge",paste0("phasenudge:window",w))
  r<-rr(v);e<-exp_rr[exp_rr$window==w,]
  chk("Table 1",paste("rate ratio",w),r[1],e$rate_ratio,1e-3);chk("Table 1",paste("rate ratio",w,"lower"),r[2],e$lower,1e-3)
  chk("Table 1",paste("rate ratio",w,"upper"),r[3],e$upper,1e-3)}
rp<-R("registration_patterns.csv");rv<-function(m)as.numeric(rp$value[rp$measure==m])
retro<-primary$is_backdated;late<-primary$local_hour %in% 21:23;ph<-as.character(primary$phase)
w<-as.character(primary$window_ordered);phone<-primary$appliance=="phone_charging"
for(p in c("baseline","nudge")){
  chk("What changed",paste("late 21-24",p),sum(ph==p&late),rv(paste0("late_21_23_",p)),0)
  chk("What changed",paste("late immediate phone",p),sum(ph==p&late&!retro&phone),rv(paste0("late_imm_phone_",p)),0)
  chk("What changed",paste("late retrospective phone",p),sum(ph==p&late&retro&phone),rv(paste0("late_retro_phone_",p)),0)
  chk("What changed",paste("retrospective",p),sum(ph==p&retro),rv(paste0("retro_",p)),0)
  chk("What changed",paste("retrospective bad share",p),round(100*mean(w[retro&ph==p]=="bad"),1),rv(paste0("retro_bad_share_",p)),0)
  chk("What changed",paste("immediate bad share",p),round(100*mean(w[!retro&ph==p]=="bad"),1),rv(paste0("imm_bad_share_",p)),0)}
hh<-primary %>% group_by(household_id,phase) %>% summarise(bad=mean(window_ordered=="bad"),.groups="drop") %>%
  pivot_wider(names_from=phase,values_from=bad)
chk("What changed","households with lower bad share",sum(hh$nudge<hh$baseline),rv("hh_bad_share_lower"),0)
chk("What changed","households with higher bad share",sum(hh$nudge>hh$baseline),rv("hh_bad_share_higher"),0)
nb<-sum(ph=="baseline");nn<-sum(ph=="nudge");bb<-sum(ph=="baseline"&w=="bad");bn<-sum(ph=="nudge"&w=="bad")
chk("What changed","tipping point (unregistered bad uses)",ceiling((bb/nb*nn-bn)/(1-bb/nb)),rv("tipping_point_bad_uses"),0)
chk("What changed","registrations drop",nb-nn,rv("registrations_drop"),0)
waits<-decision_set("bad_window_decisions_primary_population") %>% filter(wait)
stopifnot(nrow(waits)==9)
dw<-prepare_events(bind_rows(primary %>% transmute(event_code,household_id=as.character(household_id),appliance=as.character(appliance),
    phase=as.character(phase),window_ordered=as.character(window_ordered),calendar_day,weekday_local=as.integer(as.character(weekday_local))),
  waits %>% transmute(event_code=decision_code,household_id,appliance,phase="nudge",window_ordered="bad",calendar_day,weekday_local)))
ph_chk<-R("posthoc_phase_checks.csv");pget<-function(a,col)ph_chk[[col]][ph_chk$check==a]
r<-wald(fit_ok(dw));a<-"Stated waits counted as bad-window uses"
chk("What changed","waits as bad uses OR",r["OR"],pget(a,"OR"));chk("What changed","waits as bad uses lower",r["lower"],pget(a,"lower"))
chk("What changed","waits as bad uses upper",r["upper"],pget(a,"upper"))

# ------------------------------------------------ calendar time and robustness
cal_f<-window_ordered~phase+appliance+weekday_local+calendar_day+(1|household_id)
cov<-primary %>% count(calendar_day,phase,.drop=FALSE,name="events")
overlap<-cov %>% group_by(calendar_day) %>% summarise(both=all(events>0),.groups="drop") %>% filter(both)
ov<-filter(primary,calendar_day %in% overlap$calendar_day)
chk("Calendar","overlap dates",nrow(overlap),12,0);chk("Calendar","overlap registrations",nrow(ov),514,0)
for(x in list(list(d=primary,a="Weekday and linear calendar-day adjustment"),list(d=ov,a="Calendar-overlap dates only, adjusted"))){
  r<-wald(fit_ok(x$d,cal_f));for(k in c("OR","lower","upper"))chk("Calendar",paste(x$a,k),r[k],sget(x$a,k))}
tr<-primary %>% mutate(t=as.numeric(study_day)-7.5)
ft<-fit_ok(tr,window_ordered~phase*t+appliance+(1|household_id));b<-ft$beta;V<-vcov(ft)
trend<-list("Baseline slope per study day"=c(b["t"],sqrt(V["t","t"])),
  "Nudge-phase slope per study day"=c(b["t"]+b["phasenudge:t"],sqrt(V["t","t"]+V["phasenudge:t","phasenudge:t"]+2*V["t","phasenudge:t"])),
  "Slope difference"=c(b["phasenudge:t"],sqrt(V["phasenudge:t","phasenudge:t"])),
  "Level change at phase boundary"=c(b["phasenudge"],sqrt(V["phasenudge","phasenudge"])))
et<-R("within_phase_trend.csv")
for(nm in names(trend)){e<-trend[[nm]];chk("Trend",paste(nm,"OR"),exp(e[1]),et$OR[et$term==nm])
  chk("Trend",paste(nm,"lower"),exp(e[1]-1.96*e[2]),et$lower[et$term==nm]);chk("Trend",paste(nm,"upper"),exp(e[1]+1.96*e[2]),et$upper[et$term==nm])}
binary<-list("Great versus ok/bad"=fit_binary(primary,"is_great"),"Great/ok versus bad"=fit_binary(primary,"is_not_bad"))
for(a in names(binary)){stopifnot(length(binary[[a]]$warnings)==0);r<-wald(binary[[a]]$fit)
  for(k in c("OR","lower","upper"))chk("Robustness",paste(a,k),r[k],sget(a,k))}
naive<-ordinal::clm(window_ordered~phase+appliance,data=primary,link="logit")
nt<-ordinal::nominal_test(naive);chk("Robustness","nominal test p (phase)",nt["phase","Pr(>Chi)"],R("diagnostics/proportional_odds_nominal_test.csv")$p[1],1e-4)
reg<-primary %>% mutate(region=relevel(factor(households$clock_region[match(as.character(household_id),households$household_code)]),"Germany"))
f1<-fit_ok(reg,window_ordered~phase*region+appliance+(1|household_id));f0<-fit_ok(reg,window_ordered~phase+region+appliance+(1|household_id))
chk("Robustness","region interaction p",pchisq(2*(as.numeric(logLik(f1))-as.numeric(logLik(f0))),1,lower.tail=FALSE),
  R("region_phase_effects.csv")$interaction_p[1],1e-4)
sets<-c(all_eligible_events="All eligible events (including incomplete)",exposure_marker_events="Observed Phase-2 exposure",
  high_load_events="High-load appliances only",immediate_only_events="Immediate registrations only",
  backdated_boundary_excluded_events="Exclude four phase-crossing backdates",
  backdated_registration_phase_events="Backdates assigned by registration time",
  primary_events_retain_all_duplicates="Retain duplicate-flagged events")
for(s in names(sets)){d<-prepare_events(event_set(s),calendar=FALSE);r<-wald(fit_ok(d))
  chk("Robustness",paste(sets[[s]],"n"),nrow(d),sget(sets[[s]],"n_events"),0)
  for(k in c("OR","lower","upper"))chk("Robustness",paste(sets[[s]],k),r[k],sget(sets[[s]],k))}
all_ev<-prepare_events(event_set("all_eligible_events"),calendar=FALSE)
for(x in list(list(d=filter(all_ev,full_14_day_opportunity),a="All eligible events, full opportunity only"),
  list(d=filter(all_ev,paired_contributor_locked),a="Paired contributors including incomplete"))){
  r<-wald(fit_ok(droplevels(x$d)));chk("Robustness",paste(x$a,"OR"),r["OR"],sget(x$a,"OR"))}
loo<-sapply(levels(primary$household_id),function(h)exp(fit_ok(droplevels(filter(primary,household_id!=h)))$beta["phasenudge"]))
hi<-R("household_influence_summary.csv")
chk("Robustness","leave-one-out min OR",min(loo),hi$min_OR);chk("Robustness","leave-one-out max OR",max(loo),hi$max_OR)
incl<-prepare_events(event_set("primary_events_incl_rewritten"),calendar=FALSE)
stopifnot(nrow(incl)==1001,n_distinct(incl$household_id)==63)
r<-wald(fit_ok(incl));a<-"Including households with rewritten records (DEC-030)"
for(k in c("OR","lower","upper"))chk("Robustness",paste("incl. overwritten",k),r[k],pget(a,k))

# ------------------------------------------------ RQ2: stated waits
dp<-R("decision_proportions.csv")
decision_summary<-function(d,B=10000L){counts<-d %>% group_by(household_id) %>% summarise(wait=sum(wait),decisions=n(),.groups="drop")
  set.seed(24092407);draws<-replicate(B,{x<-counts[sample(seq_len(nrow(counts)),nrow(counts),replace=TRUE),];sum(x$wait)/sum(x$decisions)})
  c(households=nrow(counts),decisions=sum(counts$decisions),waits=sum(counts$wait),proportion=sum(counts$wait)/sum(counts$decisions),
    lower=unname(quantile(draws,.025)),upper=unname(quantile(draws,.975)))}
for(x in list(list(s="bad_window_decisions",a="Main: all eligible recorded bad-window decisions"),
  list(s="bad_window_decisions_incl_rewritten",a="Including households with rewritten records (DEC-030)"))){
  r<-decision_summary(decision_set(x$s));e<-dp[dp$analysis==x$a,]
  for(k in c("households","decisions","waits"))chk("RQ2",paste(x$a,k),r[k],e[[k]],0)
  chk("RQ2",paste(x$a,"proportion"),r["proportion"],e$proportion,1e-10)
  for(k in c("lower","upper"))chk("RQ2",paste(x$a,k),r[k],e[[k]],.01,"bootstrap")}
dec<-decision_set("bad_window_decisions")
for(a in c("phone_charging","washing_machine","dishwasher")){key<-c(phone_charging="phone",washing_machine="washing",dishwasher="dishwasher")[a]
  chk("RQ2",paste("dialogs",a),sum(dec$appliance==a),rv(paste0("dialogs_",key)),0)
  chk("RQ2",paste("waits",a),sum(dec$appliance==a & dec$response=="decline"),rv(paste0("waits_",key)),0)}
q<-quantile(dec$suggested_wait_hours,c(.25,.5,.75),type=7)
chk("RQ2","suggested wait median",q[2],rv("suggested_wait_median"),0)
chk("RQ2","suggested wait Q1",q[1],rv("suggested_wait_q1"),0);chk("RQ2","suggested wait Q3",q[3],rv("suggested_wait_q3"),0)

# ------------------------------------------------ household bootstraps (399 CLMM fits each)
if(!fast){
  # As in 08: refit with the tight optimiser if the default fit is not accepted;
  # a replicate enters only if its final fit passes the basic acceptance checks.
  basic_ok<-function(obj){f<-obj$fit;if(is.null(f))return(FALSE)
    ev<-eigen(f$Hessian,symmetric=TRUE,only.values=TRUE)$values;se<-tryCatch(sqrt(diag(vcov(f))),error=function(e)NA)
    oc<-f$optRes$convergence;ok<-if(f$control$method=="ucminf")oc %in% c(1L,2L) else oc==0L
    length(obj$warnings)==0 && all(is.finite(c(f$coefficients,se))) && min(ev)>0 && isTRUE(ok)}
  boot_fit<-function(dd){f<-fit_ordinal(dd);if(!basic_ok(f))f<-fit_ordinal(dd,tight=TRUE);if(basic_ok(f))f$fit else NULL}
  set.seed(24092408);bo<-replicate(399,{f<-boot_fit(resample_households(primary))
    if(is.null(f))NA_real_ else unname(f$beta["phasenudge"])})
  sm<-R("sensitivity_matrix.csv");e<-sm[sm$analysis=="Household-bootstrap interval",]
  chk("RQ1","household-bootstrap OR lower",exp(quantile(bo,.025,na.rm=TRUE)),e$lower,.05,"bootstrap")
  chk("RQ1","household-bootstrap OR upper",exp(quantile(bo,.975,na.rm=TRUE)),e$upper,.1,"bootstrap")
  set.seed(24092710);md<-replicate(399,{f<-boot_fit(resample_households(primary))
    if(is.null(f))NA_real_ else category_probs(f$alpha,f$beta,unname(f$ST[[1]][1,1]))["diff_great"]})
  e<-em[em$quantity=="diff_great",]
  chk("RQ1","great-share difference bootstrap lower",quantile(md,.025,na.rm=TRUE),e$boot_lower,.01,"bootstrap")
  chk("RQ1","great-share difference bootstrap upper",quantile(md,.975,na.rm=TRUE),e$boot_upper,.01,"bootstrap")
}

rep<-bind_rows(report)
write_csv(rep,"reproduce/reproduction_report.csv")
cat(sprintf("\n%d quantities compared: %d match, %d differ.\n",nrow(rep),sum(rep$match),sum(!rep$match)))
if(any(!rep$match))print(as.data.frame(rep[!rep$match,]),digits=6)
cat(if(all(rep$match))"REPRODUCTION PASS\n" else "REPRODUCTION: see differences above\n")
