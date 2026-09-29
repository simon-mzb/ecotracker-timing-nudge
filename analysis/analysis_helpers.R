# Shared deterministic utilities for the locked SusAI analyses.
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(ggplot2)
  library(ordinal); library(lme4); library(survival)
})
options(contrasts = c("contr.treatment", "contr.poly"))
analysis_dir <- "data/derived/2026-09-24_analysis"
model_dir <- "data/derived/2026-09-24_models"
result_dir <- "outputs/results/2026-09-24"
diagnostic_dir <- "outputs/diagnostics/2026-09-24"
for (p in c(model_dir, result_dir, diagnostic_dir, "outputs/reporting"))
  dir.create(p, recursive = TRUE, showWarnings = FALSE)

# Every analysis entry point validates the immutable input snapshot.
expected_hashes <- c(
  household_profiles.csv="25e6efc7ff948fe10b93551535740745f339a4b14a1ef4ef70a0d772b857e72a",
  households.csv="2de289ac02927bacf0789b7d1863aea511cd92a8f975d293387151fabb19a882",
  nudge_responses.csv="4a1c7bc6351c4ed5cfac1ca9fac9cd987eb5c43aa2d05b58199f68a4502e1988",
  usage_logs.csv="15673f9cacb7d8d44979fa8881e299fcaa30ebdf404baf760cd4647e0a4aca98")
actual_hashes <- vapply(names(expected_hashes), function(x)
  digest::digest(file=file.path("data/raw/2026-09-24_original_data",x), algo="sha256"), "")
stopifnot(identical(actual_hashes, expected_hashes))

read_set <- function(name) read_csv(file.path(analysis_dir,paste0(name,".csv")),
  col_types=cols(household_id=col_character()), show_col_types=FALSE)
prepare_events <- function(d, calendar = TRUE) {
  stopifnot(!anyDuplicated(d$analysis_event_id),
    !anyNA(d[c("household_id","phase","window_ordered","appliance")]),
    all(d$phase %in% c("baseline","nudge")),
    all(d$window_ordered %in% c("bad","ok","great")))
  d$phase <- factor(d$phase, levels=c("baseline","nudge"))
  d$appliance <- factor(d$appliance,levels=c("dishwasher","washing_machine","phone_charging"))
  d$appliance <- droplevels(d$appliance)
  d$window_ordered <- ordered(d$window_ordered, levels=c("bad","ok","great"))
  d$household_id <- factor(d$household_id)
  d$phase01 <- as.integer(d$phase == "nudge")
  d$is_great <- as.integer(d$window_ordered == "great")
  d$is_not_bad <- as.integer(d$window_ordered != "bad")
  # DEC-028: calendar covariates are integer LOCAL dates. The stored window is a
  # function of time of day, so a covariate containing time of day leaks the
  # outcome. Offsets come from 04a (household_timezone.csv). The DEC-030
  # sensitivity set that includes rewritten households has no valid offsets and
  # is prepared with calendar = FALSE (it is never calendar-adjusted).
  if (!calendar) return(d)
  tz <- read_csv(file.path(analysis_dir,"household_timezone.csv"),
    col_types=cols(household_id=col_character()),show_col_types=FALSE)
  off <- tz$calendar_offset_hours[match(as.character(d$household_id),tz$household_id)]
  stopifnot(!anyNA(off))
  local_time <- d$event_time + off*3600
  d$local_date <- as.Date(format(local_time,"%Y-%m-%d",tz="UTC"))
  d$calendar_day <- as.integer(d$local_date - as.Date("2026-09-01"))
  d$weekday_local <- factor(as.integer(format(local_time,"%u",tz="UTC")),levels=1:7)
  # Superseded/comparison specifications, used only in 08's documented comparison.
  d$calendar_time_continuous_utc <- as.numeric(difftime(d$event_time,
    as.POSIXct("2026-09-01",tz="UTC"),units="days"))
  d$utc_date <- as.Date(d$event_time,tz="UTC")
  d$utc_date_day <- as.integer(d$utc_date - as.Date("2026-09-01"))
  d$weekday_utc <- factor(as.integer(format(d$event_time,"%u",tz="UTC")),levels=1:7)
  stopifnot(is.integer(d$calendar_day),!anyNA(d$calendar_day),!anyNA(d$weekday_local))
  d
}
# 04a creates household_timezone.csv and must not depend on it.
if(!isTRUE(getOption("susai.skip_primary_load"))) {
  primary <- prepare_events(read_set("primary_events"))
  stopifnot(nrow(primary)==802L, n_distinct(primary$household_id)==42L,
    all(table(primary$household_id,primary$phase)>0),
    identical(levels(primary$appliance),c("dishwasher","washing_machine","phone_charging")),
    identical(colnames(model.matrix(~phase+appliance,primary)),
      c("(Intercept)","phasenudge","appliancewashing_machine","appliancephone_charging")))
}

save_table <- function(d,name,diagnostic=FALSE) {
  # Public outputs must never contain household/source identifiers.
  stopifnot(!any(names(d) %in% c("household_id","source_id","analysis_event_id","decision_id")))
  write_csv(d,file.path(if(diagnostic) diagnostic_dir else result_dir,paste0(name,".csv")),na="")
  invisible(d)
}
record_session <- function(stage) {
  writeLines(c(paste("Stage:",stage),paste("UTC:",format(Sys.time(),tz="UTC",usetz=TRUE)),
    capture.output(sessionInfo())),file.path(diagnostic_dir,paste0(stage,"_session_info.txt")))
}
capture_fit <- function(expr) {
  warnings <- character()
  ans <- tryCatch(withCallingHandlers(expr, warning=function(w) {
    warnings <<- c(warnings,conditionMessage(w)); invokeRestart("muffleWarning")
  }),error=function(e)e)
  list(fit=if(inherits(ans,"error")) NULL else ans,
       warnings=unique(warnings),error=if(inherits(ans,"error")) conditionMessage(ans) else "")
}
fit_ordinal <- function(d,nAGQ=7,formula=window_ordered~phase+appliance+(1|household_id),tight=FALSE) {
  capture_fit(ordinal::clmm(formula,data=d,link="logit",Hess=TRUE,nAGQ=nAGQ,
    control=if(tight) clmm.control(method="ucminf",maxIter=200,gradTol=1e-5,
      grtol=1e-4,maxeval=1000) else clmm.control()))
}
fit_binary <- function(d,outcome) {
  capture_fit(lme4::glmer(as.formula(paste0(outcome,"~phase+appliance+(1|household_id)")),
    data=d,family=binomial,nAGQ=7,
    control=glmerControl(optimizer="bobyqa",optCtrl=list(maxfun=200000))))
}
ordinal_diagnostic <- function(obj,label) {
  f<-obj$fit
  if(is.null(f)) return(tibble(model=label,accepted=FALSE,warnings=paste(obj$warnings,collapse="; "),error=obj$error))
  ev<-eigen(f$Hessian,symmetric=TRUE,only.values=TRUE)$values
  se<-tryCatch(sqrt(diag(vcov(f))),error=function(e) rep(NA_real_,length(f$coefficients)))
  rawgrad<-max(abs(f$gradient))
  scaled<-tryCatch(max(abs(solve(chol(f$Hessian),f$gradient))),error=function(e) NA_real_)
  optcode<-f$optRes$convergence
  # ucminf reports successful small-gradient/step termination as 1/2;
  # nlminb uses 0. Do not confuse these optimiser-specific conventions.
  optsuccess<-if(f$control$method=="ucminf")optcode %in% c(1L,2L) else optcode==0L
  tibble(model=label,n=nobs(f),logLik=as.numeric(logLik(f)),
    optimiser_code=if(is.null(optcode)) NA_integer_ else optcode,
    optimiser_message=paste(f$optRes$message,collapse="; "),
    max_abs_gradient=rawgrad,max_scaled_gradient=scaled,
    hessian_min_eigenvalue=min(ev),hessian_condition=max(ev)/min(ev),
    all_finite=all(is.finite(c(f$coefficients,se))),
    accepted=length(obj$warnings)==0 && all(is.finite(c(f$coefficients,se))) &&
      min(ev)>0 && isTRUE(optsuccess),
    warnings=paste(obj$warnings,collapse="; "),error=obj$error)
}
effect_row <- function(obj,label,d,term="phasenudge",family="Ordinal CLMM") {
  f<-obj$fit
  if(is.null(f))return(tibble(analysis=label,family=family,n_events=nrow(d),n_households=n_distinct(d$household_id),
    beta=NA_real_,se=NA_real_,OR=NA_real_,lower=NA_real_,upper=NA_real_,interval="Unavailable",warnings=obj$error))
  b<-if(inherits(f,"clmm"))f$beta[term] else if(inherits(f,"merMod"))fixef(f)[term] else coef(f)[term]
  se<-sqrt(diag(vcov(f)))[term]
  tibble(analysis=label,family=family,n_events=nrow(d),n_households=n_distinct(d$household_id),
    beta=unname(b),se=unname(se),OR=unname(exp(b)),lower=unname(exp(b-1.96*se)),
    upper=unname(exp(b+1.96*se)),interval="Wald 95%",warnings=paste(obj$warnings,collapse="; "))
}
coefficient_table <- function(obj,label) {
  f<-obj$fit
  b<-if(inherits(f,"clmm"))c(f$alpha,f$beta) else fixef(f)
  se<-sqrt(diag(vcov(f)))[names(b)]
  tibble(model=label,term=names(b),beta=as.numeric(b),se=as.numeric(se),
    exp_beta=exp(b),lower=exp(b-1.96*se),upper=exp(b+1.96*se))
}
resample_households <- function(d) {
  groups<-split(d,d$household_id,drop=TRUE)
  selected<-sample(seq_along(groups),length(groups),replace=TRUE)
  out<-bind_rows(lapply(seq_along(selected),function(j){
    x<-groups[[selected[j]]];x$household_id<-as.character(j);x
  }))
  out$household_id<-factor(out$household_id)
  out
}
md_table <- function(d,digits=3) {
  d<-as.data.frame(d)
  d[]<-lapply(d,function(x) if(is.numeric(x))format(round(x,digits),trim=TRUE,scientific=FALSE) else as.character(x))
  c(paste0("| ",paste(names(d),collapse=" | ")," |"),
    paste0("| ",paste(rep("---",ncol(d)),collapse=" | ")," |"),
    apply(d,1,function(x)paste0("| ",paste(x,collapse=" | ")," |")))
}
theme_set(theme_minimal(base_size=11)+theme(panel.grid.minor=element_blank(),legend.position="bottom"))
window_colors<-c(bad="#A04A43",ok="#DBB86B",great="#267F73")
