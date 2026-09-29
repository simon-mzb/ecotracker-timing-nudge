source("analysis/analysis_helpers.R")
d<-primary
# Locked formula and defaults are attempted first, without outcome-driven selection.
full<-fit_ordinal(d)
null<-fit_ordinal(d,formula=window_ordered~appliance+(1|household_id))
laplace<-fit_ordinal(d,nAGQ=1)
quad15<-fit_ordinal(d,nAGQ=15)
fits<-list(primary_7=full,null_7=null,laplace_1=laplace,quadrature_15=quad15)
diagnostics<-bind_rows(lapply(names(fits),function(nm)ordinal_diagnostic(fits[[nm]],nm)))
save_table(diagnostics,"primary_initial_numerical_checks",TRUE)
saveRDS(fits,file.path(model_dir,"primary_initial_models.rds"))
needs_refinement<-!diagnostics$accepted | diagnostics$max_abs_gradient>.001 | diagnostics$max_scaled_gradient>.001
if(any(needs_refinement)) {
  for(nm in diagnostics$model[needs_refinement]) {
    fits[[nm]]<-fit_ordinal(d,nAGQ=if(nm=="laplace_1")1 else if(nm=="quadrature_15")15 else 7,
      formula=if(nm=="null_7")window_ordered~appliance+(1|household_id) else window_ordered~phase+appliance+(1|household_id),tight=TRUE)
  }
  diagnostics<-bind_rows(lapply(names(fits),function(nm)ordinal_diagnostic(fits[[nm]],nm)))
  full<-fits$primary_7;null<-fits$null_7;laplace<-fits$laplace_1;quad15<-fits$quadrature_15
}
save_table(diagnostics,"primary_numerical_checks",TRUE)
saveRDS(fits,file.path(model_dir,"primary_models.rds"))
if(!all(diagnostics$accepted))stop("Primary numerical acceptance failed; inspect documented fits before troubleshooting.")
if(any(diagnostics$max_abs_gradient>.001 | diagnostics$max_scaled_gradient>.001))
  stop("Primary gradient check requires investigation.")
f<-full$fit; n<-null$fit
stopifnot(nobs(f)==802,nobs(n)==802,identical(rownames(f$model),rownames(n$model)),
  identical(names(f$beta),c("phasenudge","appliancewashing_machine","appliancephone_charging")),
  identical(names(f$alpha),c("bad|ok","ok|great")))
beta<-unname(f$beta["phasenudge"]);se<-sqrt(vcov(f)["phasenudge","phasenudge"])
lbeta<-unname(laplace$fit$beta["phasenudge"])
lse<-sqrt(vcov(laplace$fit)["phasenudge","phasenudge"])
quadcheck<-tibble(coefficient_7=beta,coefficient_1=lbeta,absolute_difference=abs(beta-lbeta),
  se_7=se,se_1=lse,relative_se_difference=abs(lse-se)/se,sign_change=sign(beta)!=sign(lbeta),
  triggers_investigation=abs(beta-lbeta)>.10 || abs(lse-se)/se>.10 || sign(beta)!=sign(lbeta),
  coefficient_15=unname(quad15$fit$beta["phasenudge"]))
save_table(quadcheck,"quadrature_comparison",TRUE)
if(quadcheck$triggers_investigation) stop("Locked quadrature trigger: investigation required.")
lrt<-2*(as.numeric(logLik(f))-as.numeric(logLik(n)))
stopifnot(lrt>=0,attr(logLik(f),"df")-attr(logLik(n),"df")==1)

# Genuine profile likelihood: fix phase coefficient as an offset and reoptimise
# every nuisance parameter, including the household SD, with identical AGQ.
profile_evaluations<-list()
profile_ll<-function(b) {
  dd<-d; dd$phase_offset<-b*dd$phase01
  obj<-fit_ordinal(dd,formula=window_ordered~appliance+offset(phase_offset)+(1|household_id))
  check<-ordinal_diagnostic(obj,paste0("phase_fixed_",format(b,digits=12)))
  if(!check$accepted || check$max_abs_gradient>.001) {
    profile_evaluations[[length(profile_evaluations)+1L]]<<-mutate(check,fixed_phase_beta=b,attempt="initial")
    obj<-fit_ordinal(dd,formula=window_ordered~appliance+offset(phase_offset)+(1|household_id),tight=TRUE)
    check<-ordinal_diagnostic(obj,paste0("phase_fixed_",format(b,digits=12)))
  }
  profile_evaluations[[length(profile_evaluations)+1L]]<<-mutate(check,fixed_phase_beta=b)
  if(!check$accepted || check$max_abs_gradient>.001) stop("Constrained profile optimisation failed acceptance.")
  as.numeric(logLik(obj$fit))
}
profile_result<-tryCatch({
  llhat<-profile_ll(beta); llzero<-profile_ll(0)
  stopifnot(abs(llhat-as.numeric(logLik(f)))<1e-4,
            abs(llzero-as.numeric(logLik(n)))<1e-4)
  objective<-function(b) 2*(as.numeric(logLik(f))-profile_ll(b))-qchisq(.95,1)
  roots<-sapply(c(-1,1),function(direction){
    width<-2*se
    while(objective(beta+direction*width)<0) {
      width<-width*1.5
      if(width>20)stop("Profile did not bracket a finite endpoint.")
    }
    uniroot(objective,sort(c(beta,beta+direction*width)),tol=1e-6)$root
  })
  list(ci=roots,method="Profile likelihood 95%",error="",llhat=llhat,llzero=llzero)
},error=function(e)list(ci=beta+c(-1,1)*1.96*se,method="Wald 95% (profiling failed)",error=conditionMessage(e)))
save_table(bind_rows(profile_evaluations),"profile_likelihood_evaluations",TRUE)
saveRDS(profile_result,file.path(model_dir,"primary_profile.rds"))
result<-effect_row(full,"Primary",d) %>% mutate(lower=exp(profile_result$ci[1]),upper=exp(profile_result$ci[2]),
  interval=profile_result$method,LRT=lrt,df=1,p=pchisq(lrt,1,lower.tail=FALSE),
  wald_lower=exp(beta-1.96*se),wald_upper=exp(beta+1.96*se),
  random_intercept_variance=unname(f$ST[[1]][1,1]^2),profile_error=profile_result$error)
save_table(result,"primary_effect")
save_table(coefficient_table(full,"Primary"),"primary_coefficients")

# Conditional category probabilities at household random intercept zero,
# using the SAME pooled appliance weights in both phases.
weights<-prop.table(table(d$appliance))
new<-expand_grid(phase=levels(d$phase),appliance=levels(d$appliance)) %>%
  mutate(phase=factor(phase,levels=levels(d$phase)),appliance=factor(appliance,levels=levels(d$appliance)))
X<-model.matrix(~phase+appliance,new)[,-1,drop=FALSE]
eta<-as.numeric(X %*% f$beta)
cumulative<-sapply(f$alpha,function(a)plogis(a-eta))
prob<-cbind(bad=cumulative[,1],ok=cumulative[,2]-cumulative[,1],great=1-cumulative[,2])
stopifnot(all(abs(rowSums(prob)-1)<1e-12),all(prob>=0))
pred<-bind_cols(new,as.data.frame(prob)) %>% pivot_longer(c(bad,ok,great),names_to="window",values_to="probability") %>%
  mutate(appliance_weight=as.numeric(weights[as.character(appliance)])) %>%
  group_by(phase,window) %>% summarise(probability=sum(probability*appliance_weight),.groups="drop")
save_table(pred,"conditional_category_probabilities")
save_table(tibble(appliance=names(weights),pooled_weight=as.numeric(weights)),"prediction_appliance_weights")
writeLines(c("Factor coding: baseline reference; nudge contrast = 1; dishwasher reference.",
  "Outcome ordering: bad < ok < great.",
  "logit P(Y <= k | b) = alpha_k - (beta_phase*nudge + beta_appliance + b).",
  "exp(beta_phase) is the conditional odds ratio of being ABOVE either cut point.",
  "Predictions set b=0 and standardise to the pooled primary-event appliance mix.",
  "They are not population-marginal probabilities, empirical rates or energy effects."),
  file.path(diagnostic_dir,"factor_coding_and_prediction_definition.txt"))
record_session("06_primary")
print(result,width=Inf);print(diagnostics,width=Inf);print(pred)
