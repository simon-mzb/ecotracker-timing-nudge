# Post hoc descriptive registration patterns for the manuscript (session 6, 2026-09-29).
# Descriptive only: no model, no change to any rule or population. Counts come from the
# locked primary events and the bad-window decisions; local hour = event time (UTC) plus the
# 04a device-clock offset. The stored window label stays primary; the local hour is used only
# to place registrations on the clock (it disagrees with the stored label for a few events).
# Writes identifier-free tables used by 09 (text) and figure_patterns.py (figure).
source("analysis/analysis_helpers.R")
tz<-read_csv(file.path(analysis_dir,"household_timezone.csv"),
  col_types=cols(household_id=col_character()),show_col_types=FALSE)
d<-primary %>% mutate(household_id=as.character(household_id),
  offset=tz$device_clock_offset_hours[match(household_id,tz$household_id)])
stopifnot(!anyNA(d$offset))
lt<-d$event_time+d$offset*3600
d<-d %>% mutate(local_hour=as.integer(format(lt,"%H",tz="UTC")),
  local_dec=local_hour+as.integer(format(lt,"%M",tz="UTC"))/60+as.numeric(format(lt,"%OS6",tz="UTC"))/3600,
  local_window=case_when(local_dec>=10&local_dec<17~"great",(local_dec>=8&local_dec<10)|(local_dec>=17&local_dec<19)~"ok",TRUE~"bad"),
  retro=is_backdated,phase=as.character(phase),window=as.character(window_ordered))
n_of<-function(x)as.integer(sum(x))
late<-d$local_hour %in% 21:23
share_bad<-function(x)100*mean(x=="bad")
by<-function(ph,cond)n_of(d$phase==ph & cond)
# Per-household bad-window share and total registrations.
hh<-d %>% group_by(household_id,phase) %>% summarise(n=n(),bad=mean(window=="bad"),.groups="drop") %>%
  pivot_wider(names_from=phase,values_from=c(n,bad))
stopifnot(nrow(hh)==42L,!anyNA(hh))
nb<-sum(d$phase=="baseline");nn<-sum(d$phase=="nudge")
bb<-by("baseline",d$window=="bad");bn<-by("nudge",d$window=="bad")
# Tipping point: smallest number x of additional unregistered nudge-week bad-window uses
# that brings the raw nudge bad-window share back to the baseline share, (bn+x)/(nn+x) >= bb/nb.
tip<-ceiling((bb/nb*nn-bn)/(1-bb/nb))
stopifnot((bn+tip)/(nn+tip)>=bb/nb,(bn+tip-1)/(nn+tip-1)<bb/nb)
dec<-read_set("bad_window_decisions") %>% filter(in_bad_window_denominator)
stopifnot(nrow(dec)==106L,!anyNA(dec$suggested_wait_hours))
q<-quantile(dec$suggested_wait_hours,c(.25,.5,.75),type=7)
rows<-list(
  c("late_21_23_baseline",by("baseline",late)),c("late_21_23_nudge",by("nudge",late)),
  c("late_imm_phone_baseline",by("baseline",late&!d$retro&d$appliance=="phone_charging")),
  c("late_imm_phone_nudge",by("nudge",late&!d$retro&d$appliance=="phone_charging")),
  c("late_retro_phone_baseline",by("baseline",late&d$retro&d$appliance=="phone_charging")),
  c("late_retro_phone_nudge",by("nudge",late&d$retro&d$appliance=="phone_charging")),
  c("retro_baseline",by("baseline",d$retro)),c("retro_nudge",by("nudge",d$retro)),
  c("retro_bad_baseline",by("baseline",d$retro&d$window=="bad")),c("retro_bad_nudge",by("nudge",d$retro&d$window=="bad")),
  c("retro_bad_share_baseline",sprintf("%.1f",share_bad(d$window[d$retro&d$phase=="baseline"]))),
  c("retro_bad_share_nudge",sprintf("%.1f",share_bad(d$window[d$retro&d$phase=="nudge"]))),
  c("imm_bad_share_baseline",sprintf("%.1f",share_bad(d$window[!d$retro&d$phase=="baseline"]))),
  c("imm_bad_share_nudge",sprintf("%.1f",share_bad(d$window[!d$retro&d$phase=="nudge"]))),
  c("raw_bad_share_baseline",sprintf("%.1f",100*bb/nb)),c("raw_bad_share_nudge",sprintf("%.1f",100*bn/nn)),
  c("registrations_drop",nb-nn),c("tipping_point_bad_uses",tip),c("tipping_point_per_household",sprintf("%.1f",tip/42)),
  c("hh_bad_share_lower",n_of(hh$bad_nudge<hh$bad_baseline)),c("hh_bad_share_higher",n_of(hh$bad_nudge>hh$bad_baseline)),
  c("hh_bad_share_equal",n_of(hh$bad_nudge==hh$bad_baseline)),
  c("hh_total_fewer",n_of(hh$n_nudge<hh$n_baseline)),c("hh_total_more",n_of(hh$n_nudge>hh$n_baseline)),
  c("local_label_disagreements",n_of(d$local_window!=d$window)),
  c("dialogs",nrow(dec)),c("dialogs_phone",n_of(dec$appliance=="phone_charging")),
  c("waits_phone",n_of(dec$appliance=="phone_charging"&dec$response=="decline")),
  c("dialogs_washing",n_of(dec$appliance=="washing_machine")),c("waits_washing",n_of(dec$appliance=="washing_machine"&dec$response=="decline")),
  c("dialogs_dishwasher",n_of(dec$appliance=="dishwasher")),c("waits_dishwasher",n_of(dec$appliance=="dishwasher"&dec$response=="decline")),
  c("suggested_wait_median",sprintf("%g",q[[2]])),c("suggested_wait_q1",sprintf("%g",q[[1]])),c("suggested_wait_q3",sprintf("%g",q[[3]])),
  c("suggested_wait_min",min(dec$suggested_wait_hours)),c("suggested_wait_max",max(dec$suggested_wait_hours)))
out<-tibble(measure=vapply(rows,`[`,"",1),value=vapply(rows,`[`,"",2))
stopifnot(!anyDuplicated(out$measure))
save_table(out,"registration_patterns")
# Figure inputs: registrations by local hour and by study day (counts only).
save_table(d %>% count(phase,local_hour,source=if_else(retro,"retrospective","immediate"),window,name="events") %>%
  arrange(phase,local_hour),"registrations_by_local_hour")
save_table(d %>% count(phase,study_day,window,name="events") %>% arrange(study_day),"registrations_by_study_day")
record_session("05c_registration_patterns")
print(out,n=Inf)
cat("Registration patterns written.\n")
