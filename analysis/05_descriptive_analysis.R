source("analysis/analysis_helpers.R")
population<-read_set("analysis_population")
all_events<-prepare_events(read_set("all_eligible_events"))
eligible<-filter(population,household_eligible)
# DEC-030: eligibility before and after the record-integrity exclusion are both shown.
# Session 6 (2026-09-29): the registry holds 501 rows, including one test account. The team
# pre-generated 500 study logins; how many were handed out was not recorded, so "issued" is not used.
# Screening (dishwasher or washing machine) precedes consent in the app (api/onboarding/consent rejects ineligible).
study<-filter(population,!is_test)
flow<-tibble(stage=c("Study logins (test account excluded)","Logged in at least once",
  "Screened out: neither dishwasher nor washing machine","Recorded consent","Eligible before record-integrity exclusion",
  "Excluded: records rewritten after collection (DEC-030)","Eligible households","Full 336-hour opportunity",
  "Administratively incomplete","Any valid event","Both phases (any opportunity)","Primary: full opportunity and both phases"),
  households=c(nrow(study),sum(study$has_first_login),sum(study$explicitly_ineligible),sum(study$has_consent),
  sum(population$household_eligible_before_integrity),
  sum(population$household_eligible_before_integrity & population$record_integrity_excluded),nrow(eligible),sum(eligible$full_14_day_opportunity),
  sum(!eligible$full_14_day_opportunity),sum(eligible$all_eligible_contributor),sum(eligible$paired_contributor_locked),sum(eligible$primary_population)))
stopifnot(nrow(population)==501L,sum(population$is_test)==1L,
  sum(study$has_consent)==sum(population$household_eligible_before_integrity))
save_table(flow,"participant_flow")
contribution<-eligible %>% mutate(pattern=case_when(
  contributes_locked_baseline & contributes_locked_nudge~"Both phases",
  contributes_locked_baseline~"Baseline only",contributes_locked_nudge~"Nudge only",TRUE~"No valid events")) %>%
  count(full_14_day_opportunity,pattern,name="households")
save_table(contribution,"contribution_patterns")
save_table(eligible %>% summarise(total=n(),one_to_two_events=sum(n_locked_events %in% 1:2),
  at_most_two_in_one_contributing_phase=sum((n_locked_baseline_events %in% 1:2)|(n_locked_nudge_events %in% 1:2)),
  no_events=sum(n_locked_events==0)),"sparse_participation")

for (nm in c("primary","all_eligible")) {
  d<-if(nm=="primary")primary else all_events
  for (variable in c("appliance","source_type","study_day","window_ordered")) {
    tab<-d %>% count(phase,.data[[variable]],name="events") %>% group_by(phase) %>%
      mutate(proportion=events/sum(events)) %>% ungroup()
    save_table(tab,paste(nm,variable,sep="_"))
  }
  save_table(d %>% count(phase,appliance,window_ordered,name="events") %>%
    group_by(phase,appliance) %>% mutate(proportion=events/sum(events)) %>% ungroup(),paste0(nm,"_appliance_windows"))
  # DEC-028: local calendar dates (household offsets from 04a).
  save_table(d %>% count(local_date,phase,name="events"),paste0(nm,"_calendar_coverage"))
  counts<-d %>% group_by(household_id,phase) %>% summarise(events=n(),active_study_days=n_distinct(study_day),.groups="drop")
  # Zero entries are counts of registrations, never zero physical appliance use.
  base_ids<-if(nm=="primary")eligible$household_id[eligible$primary_population] else eligible$household_id
  counts<-expand_grid(household_id=as.character(base_ids),phase=levels(primary$phase)) %>%
    left_join(mutate(counts,household_id=as.character(household_id),phase=as.character(phase)),by=c("household_id","phase")) %>%
    mutate(across(c(events,active_study_days),~replace_na(.x,0L)))
  save_table(counts %>% group_by(phase) %>% summarise(households=n(),
    no_registrations=sum(events==0),median_events=median(events),q1_events=quantile(events,.25),q3_events=quantile(events,.75),
    min_events=min(events),max_events=max(events),median_active_days=median(active_study_days),
    q1_active_days=quantile(active_study_days,.25),q3_active_days=quantile(active_study_days,.75),.groups="drop"),paste0(nm,"_contribution_distribution"))
  if(nm=="primary") {
    fig<-ggplot(counts,aes(factor(phase,levels=c("baseline","nudge")),events))+geom_boxplot(outlier.shape=NA,width=.4)+
      geom_point(position=position_jitter(width=.1,height=0,seed=24092405),alpha=.45,size=1.5)+
      labs(x=NULL,y="Registered uses per household",caption="Each point is one household; no-entry days are not zero physical use.")
    ggsave(file.path(result_dir,"household_contribution.pdf"),fig,width=5.8,height=3.5)
    ggsave(file.path(result_dir,"household_contribution.png"),fig,width=5.8,height=3.5,dpi=200)
  }
}
markers<-read_set("phase2_exposure_markers")
save_table(eligible %>% summarise(eligible=n(),intro_recorded=sum(!is.na(phase2_intro_seen_at)),
  intro_missing=sum(is.na(phase2_intro_seen_at)),intro_before_168h=sum(phase2_intro_hours<168,na.rm=TRUE),
  median_intro_hours=median(phase2_intro_hours,na.rm=TRUE),min_intro_hours=min(phase2_intro_hours,na.rm=TRUE),
  max_intro_hours=max(phase2_intro_hours,na.rm=TRUE)),"exposure_intro_timing")
save_table(markers %>% group_by(marker_source) %>% summarise(households=n(),before_168h=sum(marker_hours_since_login<168),
  min_hours=min(marker_hours_since_login),median_hours=median(marker_hours_since_login),max_hours=max(marker_hours_since_login),.groups="drop"),"exposure_marker_timing")
save_table(eligible %>% filter(!full_14_day_opportunity) %>% summarise(households=n(),
  min_opportunity_hours=min(administrative_hours_at_cutoff),max_opportunity_hours=max(administrative_hours_at_cutoff),
  contributing_events=sum(n_locked_events)),"incomplete_opportunity")
save_table(tibble(variable=c("phase","window_ordered","appliance","event_time","registration_time"),
  missing_primary=vapply(primary[c("phase","window_ordered","appliance","event_time","registration_time")],function(x)sum(is.na(x)),integer(1))),"primary_missingness")
audit<-read_csv("data/derived/2026-09-22_audit/exclusion_and_review_audit.csv",show_col_types=FALSE)
save_table(count(audit,severity,scope,rule_code,reason,name="flagged_rows"),"audit_rules_counts")
ea<-read_set("event_exclusion_audit")
integrity_ids<-read_csv("analysis/record_integrity_exclusions.csv",col_types=cols(.default=col_character()))$household_id
save_table(ea %>% summarise(candidate_rows=n(),record_integrity_excluded=sum(household_id %in% integrity_ids),
  fail_base_time_or_eligibility=sum(!passes_base_time_quality & !household_id %in% integrity_ids),
  base_valid_but_source_incompatible=sum(passes_base_time_quality & !source_phase_compatible),
  strict_valid_before_duplicates=sum(passes_strict_event_rules),
  strict_valid_duplicates=sum(passes_strict_event_rules & excluded_as_locked_duplicate),
  all_eligible_clean=sum(passes_locked_event_rules),clean_outside_primary=sum(passes_locked_event_rules & !primary_population),
  primary_events=sum(in_primary_events)),"event_flow")
# DEC-021 activity review flag recomputed on the clean contributors (after DEC-030);
# a flag is not an exclusion. Aggregate only.
act<-all_events %>% count(household_id,name="events")
act_q<-quantile(act$events,c(.25,.75))
save_table(tibble(contributors=nrow(act),q1=act_q[[1]],q3=act_q[[2]],threshold=act_q[[2]]+1.5*(act_q[[2]]-act_q[[1]]),
  flagged=sum(act$events>act_q[[2]]+1.5*(act_q[[2]]-act_q[[1]])),max_events=max(act$events)),"activity_iqr_flags")
de<-read_set("decision_exclusion_audit")
save_table(de %>% summarise(source_decisions=n(),eligible_rows=sum(household_eligible),
  strict_eligible_before_duplicates=sum(passes_recorded_decision_window),
  duplicate_rows=sum(excluded_as_locked_duplicate),
  strict_clean=sum(passes_locked_decision_rules),bad_decisions=sum(in_bad_window_denominator),
  early_eligible=sum(household_eligible & early_nudge_response),
  nonbad_declines_eligible=sum(household_eligible & nonbad_decline)),"decision_flow")
save_table(read_set("bad_window_decisions") %>% count(appliance,response,name="decisions"),"bad_decisions_by_appliance")

# Cluster-resampling descriptive uncertainty; same households resampled in both phases.
category_stats<-function(d,equal=FALSE) {
  grid<-d %>% count(household_id,phase,window_ordered,.drop=FALSE,name="events") %>%
    group_by(household_id,phase) %>% mutate(p=events/sum(events)) %>% ungroup()
  if(equal) grid %>% group_by(phase,window_ordered) %>% summarise(p=mean(p),.groups="drop")
  else grid %>% group_by(phase,window_ordered) %>% summarise(p=sum(events),.groups="drop") %>%
    group_by(phase) %>% mutate(p=p/sum(p)) %>% ungroup()
}
# Efficient resampling of household count arrays is exactly equivalent to row resampling.
a<-xtabs(~household_id+phase+window_ordered,primary)
set.seed(24092405); B<-5000L
calc<-function(indices,equal) {
  z<-a[indices,,,drop=FALSE]
  if(equal) z<-sweep(z,c(1,2),apply(z,c(1,2),sum),"/")
  out<-apply(z,c(2,3),sum)
  out/rowSums(out)
}
draws<-replicate(B,sample(seq_len(dim(a)[1]),dim(a)[1],replace=TRUE),simplify=FALSE)
desc<-bind_rows(lapply(c(FALSE,TRUE),function(eq){
  point<-calc(seq_len(dim(a)[1]),eq)
  boot<-sapply(draws,function(idx)as.vector(calc(idx,eq)))
  tab<-expand_grid(window_ordered=dimnames(a)[[3]],phase=dimnames(a)[[2]])
  tab$proportion<-as.vector(point)
  tab$lower<-apply(boot,1,quantile,.025);tab$upper<-apply(boot,1,quantile,.975)
  tab$weighting<-if(eq)"Equal household" else "Event weighted"
  tab
}))
save_table(desc,"category_proportions_cluster_intervals")
contrasts<-bind_rows(lapply(c(FALSE,TRUE),function(eq){
  point<-calc(seq_len(dim(a)[1]),eq)
  boot<-sapply(draws,function(idx){p<-calc(idx,eq);p["nudge",]-p["baseline",]})
  tibble(weighting=if(eq)"Equal household" else "Event weighted",window_ordered=colnames(point),
    difference=point["nudge",]-point["baseline",],lower=apply(boot,1,quantile,.025),upper=apply(boot,1,quantile,.975))
}))
save_table(contrasts,"category_contrasts_cluster_intervals")
fig<-ggplot(filter(desc,weighting=="Event weighted") %>%
    mutate(window_ordered=factor(window_ordered,levels=c("bad","ok","great"))),aes(phase,proportion,fill=window_ordered))+
  geom_col(position=position_stack(reverse=TRUE),width=.58)+scale_fill_manual(values=window_colors,breaks=c("bad","ok","great"))+
  scale_y_continuous(labels=function(x)paste0(round(100*x),"%"))+
  labs(x=NULL,y="Share of registered uses",fill="Stored window",caption=sprintf("Descriptive proportions; %d households, %s registrations.",n_distinct(primary$household_id),format(nrow(primary),big.mark=",")))
ggsave(file.path(result_dir,"registered_windows.pdf"),fig,width=5.2,height=3.5)
ggsave(file.path(result_dir,"registered_windows.png"),fig,width=5.2,height=3.5,dpi=200)
record_session("05_descriptive")
print(flow); print(desc)
