source("analysis/io_utils.R")
# SusAI locked analysis-set construction
#
# Purpose:
#   Apply the rule decisions locked in Statistical Analysis Plan version 1.0
#   and create restricted, model-ready event and decision tables.
#
# Scope:
#   This script constructs and validates analysis sets. It deliberately does
#   not tabulate phase outcomes, estimate a phase effect, or fit a model.

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
})

audit_dir <- file.path("data", "derived", "2026-09-22_audit")
analysis_dir <- file.path("data", "derived", "2026-09-24_analysis")
output_dir <- file.path("outputs", "analysis_ready")

dir.create(analysis_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

required_files <- file.path(
  audit_dir,
  c(
    "participant_flow.csv",
    "registered_use_candidates.csv",
    "nudge_decisions.csv"
  )
)

if (!all(file.exists(required_files))) {
  stop("Missing audit inputs. Run analysis/01_build_audit_tables.R first.")
}

participant_flow <- read_csv(required_files[[1]], show_col_types = FALSE)
events <- read_csv(required_files[[2]], show_col_types = FALSE)
decisions <- read_csv(required_files[[3]], show_col_types = FALSE)

hours_between <- function(later, earlier) {
  as.numeric(difftime(later, earlier, units = "hours"))
}

# DEC-030: record-integrity exclusion. Households whose stored records were
# bulk-rewritten after collection (versioned list with reason code; evidence in
# analysis/record_integrity_exclusions.md) are not eligible for any analysis
# population. `--include-rewritten` rebuilds only the labelled sensitivity sets
# that keep them, using exactly the same rules.
include_rewritten <- "--include-rewritten" %in% commandArgs(trailingOnly = TRUE)
integrity_list <- read_csv(
  file.path("analysis", "record_integrity_exclusions.csv"),
  col_types = cols(.default = col_character())
)
stopifnot(
  identical(unique(integrity_list$list_version), "1.0"),
  all(integrity_list$reason_code == "records_rewritten_after_collection"),
  identical(sort(integrity_list$household_id), REDACTED_IDS),  # [redacted for the public repository: original household IDs are not published]
  all(integrity_list$household_id %in% participant_flow$household_id[participant_flow$household_eligible])
)
integrity_excluded_ids <- if (include_rewritten) character(0) else integrity_list$household_id

participant_flow <- participant_flow %>%
  mutate(
    household_eligible_before_integrity = household_eligible,
    record_integrity_excluded = household_id %in% integrity_list$household_id,
    household_eligible = household_eligible & !(household_id %in% integrity_excluded_ids)
  )
events <- events %>%
  mutate(
    household_eligible = household_eligible & !(household_id %in% integrity_excluded_ids),
    passes_proposed_event_time_rule = passes_proposed_event_time_rule & household_eligible
  )
decisions <- decisions %>%
  mutate(
    household_eligible = household_eligible & !(household_id %in% integrity_excluded_ids),
    passes_base_decision_quality = passes_base_decision_quality & household_eligible,
    passes_recorded_decision_window = passes_recorded_decision_window & household_eligible,
    eligible_bad_window_decision_candidate =
      eligible_bad_window_decision_candidate & household_eligible
  )

# Base time-quality eligibility is deliberately separated from source/phase
# compatibility. This allows the observed-exposure sensitivity to recover
# genuine early nudge rows without weakening the strict primary definition.
events <- events %>%
  mutate(
    passes_base_time_quality =
      household_eligible &
      !is.na(event_time) & !is.na(registration_time) &
      within_administrative_cutoff &
      event_inside_14_days & registration_inside_14_days &
      !backdated_over_24h & !backdated_over_2m_future,
    passes_strict_event_rules = passes_proposed_event_time_rule
  )

# Locked duplicate rule, part 1: within-stream resubmits. The candidate script
# compares within household/appliance/source/window, so the flagged row is the
# later row in a matching chain with a gap of no more than five seconds.
same_stream_duplicate_ids <- events %>%
  filter(
    passes_base_time_quality,
    near_repeat_within_5_seconds,
    same_window_as_prior_same_stream
  ) %>%
  pull(analysis_event_id) %>%
  unique()

# Locked duplicate rule, part 2: a later registered backdated row is removed
# when an immediate row for the same household and appliance describes a use
# within five minutes, has the same stored window, and precedes the backdated
# registration. The immediate row is retained. We derive this from the base
# time-quality set so the same rule also governs exposure-marker sensitivity.
immediate_for_duplicate_check <- events %>%
  filter(
    passes_base_time_quality,
    source_type %in% c("immediate_usage", "nudge_accept")
  ) %>%
  select(
    household_id, appliance,
    immediate_event_id = analysis_event_id,
    immediate_event_time = event_time,
    immediate_window = window_ordered
  )

backdated_for_duplicate_check <- events %>%
  filter(passes_base_time_quality, source_type == "backdated_usage") %>%
  select(
    household_id, appliance,
    backdated_event_id = analysis_event_id,
    backdated_event_time = event_time,
    backdated_registration_time = registration_time,
    backdated_window = window_ordered
  )

locked_cross_source_pairs <- inner_join(
  immediate_for_duplicate_check,
  backdated_for_duplicate_check,
  by = c("household_id", "appliance"),
  relationship = "many-to-many"
) %>%
  mutate(
    event_gap_minutes = abs(as.numeric(difftime(
      backdated_event_time, immediate_event_time, units = "mins"
    ))),
    same_window = immediate_window == backdated_window,
    backdated_registered_after_immediate =
      backdated_registration_time >= immediate_event_time
  ) %>%
  filter(
    event_gap_minutes <= 5,
    same_window,
    backdated_registered_after_immediate
  ) %>%
  arrange(household_id, appliance, backdated_event_time, immediate_event_time)

cross_source_duplicate_ids <- locked_cross_source_pairs %>%
  pull(backdated_event_id) %>%
  unique()

events <- events %>%
  mutate(
    duplicate_same_stream_5s =
      analysis_event_id %in% same_stream_duplicate_ids,
    duplicate_immediate_backdated_5m =
      analysis_event_id %in% cross_source_duplicate_ids,
    excluded_as_locked_duplicate =
      duplicate_same_stream_5s | duplicate_immediate_backdated_5m,
    duplicate_rule_code = case_when(
      duplicate_same_stream_5s & duplicate_immediate_backdated_5m ~
        "DUP_SAME_STREAM_5S_AND_IMMEDIATE_BACKDATED_5M",
      duplicate_same_stream_5s ~ "DUP_SAME_STREAM_5S",
      duplicate_immediate_backdated_5m ~ "DUP_IMMEDIATE_BACKDATED_5M",
      TRUE ~ NA_character_
    ),
    passes_locked_event_rules =
      passes_strict_event_rules & !excluded_as_locked_duplicate
  )

# Population membership is recomputed after duplicate adjudication. It is not
# inherited from the provisional candidate table.
clean_contributions <- events %>%
  filter(passes_locked_event_rules) %>%
  group_by(household_id) %>%
  summarise(
    n_locked_events = n(),
    n_locked_baseline_events = sum(event_phase == "baseline"),
    n_locked_nudge_events = sum(event_phase == "nudge"),
    contributes_locked_baseline = n_locked_baseline_events > 0,
    contributes_locked_nudge = n_locked_nudge_events > 0,
    paired_contributor_locked =
      contributes_locked_baseline & contributes_locked_nudge,
    .groups = "drop"
  )

analysis_population <- participant_flow %>%
  left_join(clean_contributions, by = "household_id") %>%
  mutate(
    n_locked_events = replace_na(n_locked_events, 0L),
    n_locked_baseline_events = replace_na(n_locked_baseline_events, 0L),
    n_locked_nudge_events = replace_na(n_locked_nudge_events, 0L),
    contributes_locked_baseline = replace_na(contributes_locked_baseline, FALSE),
    contributes_locked_nudge = replace_na(contributes_locked_nudge, FALSE),
    paired_contributor_locked = replace_na(paired_contributor_locked, FALSE),
    all_eligible_contributor = household_eligible & n_locked_events > 0,
    primary_population =
      household_eligible & full_14_day_opportunity & paired_contributor_locked
  ) %>%
  arrange(household_id)

primary_household_ids <- analysis_population %>%
  filter(primary_population) %>%
  pull(household_id)

events <- events %>%
  left_join(
    analysis_population %>%
      select(
        household_id, all_eligible_contributor,
        paired_contributor_locked, primary_population
      ),
    by = "household_id"
  ) %>%
  mutate(
    phase = event_phase,
    in_primary_events = passes_locked_event_rules & primary_population
  )

primary_events <- events %>%
  filter(in_primary_events) %>%
  arrange(household_id, event_time, registration_time, analysis_event_id)

# Duplicate sensitivity holds the primary household set fixed and restores all
# otherwise valid strict-window rows.
primary_events_retain_all_duplicates <- events %>%
  filter(
    household_id %in% primary_household_ids,
    passes_strict_event_rules
  ) %>%
  arrange(household_id, event_time, registration_time, analysis_event_id)

all_eligible_events <- events %>%
  filter(household_eligible, passes_locked_event_rules) %>%
  arrange(household_id, event_time, registration_time, analysis_event_id)

high_load_events <- primary_events %>%
  filter(appliance %in% c("dishwasher", "washing_machine"))

immediate_only_events <- primary_events %>%
  filter(source_type %in% c("immediate_usage", "nudge_accept"))

backdated_boundary_excluded_events <- primary_events %>%
  filter(!backdated_crosses_168h)

backdated_registration_phase_events <- primary_events %>%
  mutate(
    phase = if_else(
      source_type == "backdated_usage",
      registration_phase,
      event_phase
    ),
    phase_assignment = if_else(
      source_type == "backdated_usage",
      "registration_time",
      "event_time"
    )
  )

incomplete_followup_events <- all_eligible_events %>%
  filter(!full_14_day_opportunity)

# Observed Phase-2 exposure marker: earliest recorded introduction or nudge
# response within the household's intended 336-hour period. Nudge activity is
# included because some valid responses precede the stored introduction time.
phase2_markers <- bind_rows(
  participant_flow %>%
    filter(
      household_eligible,
      !is.na(phase2_intro_seen_at),
      phase2_intro_hours >= 0,
      phase2_intro_hours < 336
    ) %>%
    transmute(
      household_id,
      marker_time = phase2_intro_seen_at,
      marker_source = "phase2_intro"
    ),
  decisions %>%
    filter(
      household_eligible,
      within_administrative_cutoff,
      decision_hours_since_login >= 0,
      decision_hours_since_login < 336
    ) %>%
    transmute(
      household_id,
      marker_time = decision_time,
      marker_source = "nudge_response"
    )
) %>%
  arrange(household_id, marker_time, marker_source) %>%
  group_by(household_id) %>%
  slice_head(n = 1) %>%
  ungroup() %>%
  left_join(
    participant_flow %>% select(household_id, first_login_at),
    by = "household_id"
  ) %>%
  mutate(marker_hours_since_login = hours_between(marker_time, first_login_at)) %>%
  select(-first_login_at)

exposure_event_candidates <- events %>%
  left_join(phase2_markers, by = "household_id") %>%
  mutate(
    exposure_phase = case_when(
      is.na(marker_time) ~ NA_character_,
      event_time < marker_time ~ "baseline",
      event_time >= marker_time ~ "nudge",
      TRUE ~ NA_character_
    ),
    exposure_source_compatible = case_when(
      source_type == "immediate_usage" ~ exposure_phase == "baseline",
      source_type == "nudge_accept" ~ exposure_phase == "nudge",
      source_type == "backdated_usage" ~
        exposure_phase %in% c("baseline", "nudge"),
      TRUE ~ FALSE
    ),
    passes_exposure_marker_rules =
      passes_base_time_quality &
      !is.na(marker_time) &
      exposure_source_compatible &
      !excluded_as_locked_duplicate
  )

exposure_contributions <- exposure_event_candidates %>%
  filter(passes_exposure_marker_rules) %>%
  group_by(household_id) %>%
  summarise(
    exposure_baseline = any(exposure_phase == "baseline"),
    exposure_nudge = any(exposure_phase == "nudge"),
    .groups = "drop"
  )

exposure_population <- analysis_population %>%
  select(household_id, household_eligible, full_14_day_opportunity) %>%
  left_join(exposure_contributions, by = "household_id") %>%
  mutate(
    exposure_baseline = replace_na(exposure_baseline, FALSE),
    exposure_nudge = replace_na(exposure_nudge, FALSE),
    exposure_primary_population =
      household_eligible & full_14_day_opportunity &
      exposure_baseline & exposure_nudge
  )

exposure_marker_events <- exposure_event_candidates %>%
  left_join(
    exposure_population %>%
      select(household_id, exposure_primary_population),
    by = "household_id"
  ) %>%
  filter(passes_exposure_marker_rules, exposure_primary_population) %>%
  mutate(
    strict_phase = event_phase,
    phase = exposure_phase,
    phase_assignment = "earliest_phase2_intro_or_nudge_response"
  ) %>%
  arrange(household_id, event_time, registration_time, analysis_event_id)

# Decision duplicates are adjudicated independently because declines do not
# enter the event table. The main descriptive denominator contains every
# eligible, strict-window, recorded bad-window decision, with households as
# the bootstrap cluster. A primary-population-only table is supplied as a
# sensitivity analysis.
decision_duplicate_ids <- decisions %>%
  filter(
    household_eligible,
    within_administrative_cutoff,
    decision_hours_since_login >= 0,
    decision_hours_since_login < 336,
    repeated_decision_within_5_seconds
  ) %>%
  pull(decision_id) %>%
  unique()

decision_adjudication <- decisions %>%
  left_join(
    analysis_population %>% select(household_id, primary_population),
    by = "household_id"
  ) %>%
  left_join(phase2_markers, by = "household_id") %>%
  mutate(
    excluded_as_locked_duplicate = decision_id %in% decision_duplicate_ids,
    passes_locked_decision_rules =
      passes_recorded_decision_window & !excluded_as_locked_duplicate,
    in_bad_window_denominator =
      passes_locked_decision_rules & window == "bad",
    in_primary_population_bad_window_denominator =
      in_bad_window_denominator & primary_population,
    in_exposure_marker_bad_window_denominator =
      household_eligible & within_administrative_cutoff &
      decision_hours_since_login >= 0 & decision_hours_since_login < 336 &
      !is.na(marker_time) & decision_time >= marker_time &
      window == "bad" & !excluded_as_locked_duplicate
  )

bad_window_decisions <- decision_adjudication %>%
  filter(in_bad_window_denominator) %>%
  arrange(household_id, decision_time, decision_id)

bad_window_decisions_primary_population <- decision_adjudication %>%
  filter(in_primary_population_bad_window_denominator) %>%
  arrange(household_id, decision_time, decision_id)

bad_window_decisions_exposure_marker <- decision_adjudication %>%
  filter(in_exposure_marker_bad_window_denominator) %>%
  arrange(household_id, decision_time, decision_id)

event_exclusion_audit <- events %>%
  select(
    analysis_event_id, source_table, source_id, household_id,
    passes_base_time_quality, source_phase_compatible,
    passes_strict_event_rules, duplicate_same_stream_5s,
    duplicate_immediate_backdated_5m, excluded_as_locked_duplicate,
    duplicate_rule_code, passes_locked_event_rules, primary_population,
    in_primary_events
  ) %>%
  arrange(household_id, analysis_event_id)

locked_duplicate_pairs <- locked_cross_source_pairs %>%
  mutate(
    exclusion_target = backdated_event_id,
    rule_code = "DUP_IMMEDIATE_BACKDATED_5M"
  )

# DEC-030 sensitivity mode: write only the two sets that include the rewritten
# households, check that they reproduce the pre-DEC-030 locked sets, and stop.
if (include_rewritten) {
  stopifnot(
    nrow(primary_events) == 1001L, length(primary_household_ids) == 63L,
    nrow(bad_window_decisions) == 139L, sum(bad_window_decisions$wait) == 20L,
    sum(analysis_population$household_eligible) == 87
  )
  write_csv_precise(primary_events, file.path(analysis_dir, "primary_events_incl_rewritten.csv"), na = "")
  write_csv_precise(bad_window_decisions, file.path(analysis_dir, "bad_window_decisions_incl_rewritten.csv"), na = "")
  cat("DEC-030 sensitivity sets including the rewritten households written (63 households, 1,001 events; 139 bad-window decisions).\n")
  quit(save = "no", status = 0)
}

# Validation is intentionally strict. These checks guard the analysis contract
# without inspecting the phase-by-outcome relationship. Counts after DEC-030.
stopifnot(
  !any(primary_events$household_id %in% integrity_list$household_id),
  !any(all_eligible_events$household_id %in% integrity_list$household_id),
  !any(bad_window_decisions$household_id %in% integrity_list$household_id),
  sum(analysis_population$record_integrity_excluded) == 21,
  nrow(primary_events) == 802L,
  nrow(analysis_population) == nrow(participant_flow),
  n_distinct(primary_events$analysis_event_id) == nrow(primary_events),
  n_distinct(all_eligible_events$analysis_event_id) == nrow(all_eligible_events),
  n_distinct(bad_window_decisions$decision_id) == nrow(bad_window_decisions),
  all(primary_events$household_eligible),
  all(primary_events$full_14_day_opportunity),
  all(primary_events$passes_strict_event_rules),
  !any(primary_events$excluded_as_locked_duplicate),
  all(primary_events$event_hours_since_login >= 0),
  all(primary_events$event_hours_since_login < 336),
  all(primary_events$registration_hours_since_login >= 0),
  all(primary_events$registration_hours_since_login < 336),
  all(primary_events$phase %in% c("baseline", "nudge")),
  all(primary_events$window_ordered %in% c("bad", "ok", "great")),
  all(primary_events$appliance %in%
        c("dishwasher", "washing_machine", "phone_charging")),
  all(primary_household_ids %in% primary_events$household_id),
  all(
    primary_household_ids %in%
      (primary_events %>% filter(phase == "baseline") %>% pull(household_id))
  ),
  all(
    primary_household_ids %in%
      (primary_events %>% filter(phase == "nudge") %>% pull(household_id))
  ),
  all(bad_window_decisions$window == "bad"),
  all(bad_window_decisions$decision_phase == "nudge"),
  !any(bad_window_decisions$excluded_as_locked_duplicate),
  all(exposure_marker_events$exposure_source_compatible),
  !any(exposure_marker_events$excluded_as_locked_duplicate),
  sum(analysis_population$household_eligible_before_integrity) == 87,
  sum(analysis_population$household_eligible) == 66,
  sum(analysis_population$full_14_day_opportunity &
        analysis_population$household_eligible) == 63,
  length(primary_household_ids) == 42
)

write_csv_precise(analysis_population, file.path(analysis_dir, "analysis_population.csv"), na = "")
write_csv_precise(event_exclusion_audit, file.path(analysis_dir, "event_exclusion_audit.csv"), na = "")
write_csv_precise(decision_adjudication, file.path(analysis_dir, "decision_exclusion_audit.csv"), na = "")
write_csv_precise(locked_duplicate_pairs, file.path(analysis_dir, "locked_duplicate_pairs.csv"), na = "")
write_csv_precise(phase2_markers, file.path(analysis_dir, "phase2_exposure_markers.csv"), na = "")
write_csv_precise(primary_events, file.path(analysis_dir, "primary_events.csv"), na = "")
write_csv_precise(
  primary_events_retain_all_duplicates,
  file.path(analysis_dir, "primary_events_retain_all_duplicates.csv"),
  na = ""
)
write_csv_precise(all_eligible_events, file.path(analysis_dir, "all_eligible_events.csv"), na = "")
write_csv_precise(high_load_events, file.path(analysis_dir, "high_load_events.csv"), na = "")
write_csv_precise(immediate_only_events, file.path(analysis_dir, "immediate_only_events.csv"), na = "")
write_csv_precise(
  backdated_boundary_excluded_events,
  file.path(analysis_dir, "backdated_boundary_excluded_events.csv"),
  na = ""
)
write_csv_precise(
  backdated_registration_phase_events,
  file.path(analysis_dir, "backdated_registration_phase_events.csv"),
  na = ""
)
write_csv_precise(
  exposure_marker_events,
  file.path(analysis_dir, "exposure_marker_events.csv"),
  na = ""
)
write_csv_precise(
  incomplete_followup_events,
  file.path(analysis_dir, "incomplete_followup_events.csv"),
  na = ""
)
write_csv_precise(bad_window_decisions, file.path(analysis_dir, "bad_window_decisions.csv"), na = "")
write_csv_precise(
  bad_window_decisions_primary_population,
  file.path(analysis_dir, "bad_window_decisions_primary_population.csv"),
  na = ""
)
write_csv_precise(
  bad_window_decisions_exposure_marker,
  file.path(analysis_dir, "bad_window_decisions_exposure_marker.csv"),
  na = ""
)

analysis_set_manifest <- tibble::tribble(
  ~analysis_set, ~n_households, ~n_rows, ~role,
  "primary_events", n_distinct(primary_events$household_id), nrow(primary_events),
  "Primary strict-boundary, duplicate-cleaned event set",
  "primary_events_retain_all_duplicates",
  n_distinct(primary_events_retain_all_duplicates$household_id),
  nrow(primary_events_retain_all_duplicates),
  "Duplicate-retention sensitivity in the fixed primary household set",
  "all_eligible_events", n_distinct(all_eligible_events$household_id),
  nrow(all_eligible_events), "Broader eligible-event sensitivity",
  "high_load_events", n_distinct(high_load_events$household_id),
  nrow(high_load_events), "Dishwasher and washing-machine sensitivity",
  "immediate_only_events", n_distinct(immediate_only_events$household_id),
  nrow(immediate_only_events), "Immediate-registration sensitivity",
  "backdated_boundary_excluded_events",
  n_distinct(backdated_boundary_excluded_events$household_id),
  nrow(backdated_boundary_excluded_events),
  "Sensitivity excluding backdated rows that cross 168 hours",
  "backdated_registration_phase_events",
  n_distinct(backdated_registration_phase_events$household_id),
  nrow(backdated_registration_phase_events),
  "Sensitivity assigning backdated phase from registration time",
  "exposure_marker_events", n_distinct(exposure_marker_events$household_id),
  nrow(exposure_marker_events),
  "Sensitivity using earliest introduction or nudge response as Phase-2 marker",
  "incomplete_followup_events", n_distinct(incomplete_followup_events$household_id),
  nrow(incomplete_followup_events),
  "Events from eligible households without a full 336-hour opportunity",
  "bad_window_decisions", n_distinct(bad_window_decisions$household_id),
  nrow(bad_window_decisions),
  "Main recorded bad-window decision denominator",
  "bad_window_decisions_primary_population",
  n_distinct(bad_window_decisions_primary_population$household_id),
  nrow(bad_window_decisions_primary_population),
  "Decision sensitivity restricted to primary households",
  "bad_window_decisions_exposure_marker",
  n_distinct(bad_window_decisions_exposure_marker$household_id),
  nrow(bad_window_decisions_exposure_marker),
  "Decision sensitivity using observed Phase-2 exposure"
)

write_csv_precise(
  analysis_set_manifest,
  file.path(output_dir, "analysis_set_manifest.csv"),
  na = ""
)

validation_report <- c(
  "# SusAI Analysis-Set Validation",
  "",
  "Statistical Analysis Plan version 1.0 analysis sets were constructed without fitting or inspecting a phase-effect model.",
  "",
  paste0("- Eligible households before the DEC-030 record-integrity exclusion: ", sum(analysis_population$household_eligible_before_integrity), "; excluded because records were rewritten after collection: ", sum(analysis_population$record_integrity_excluded), "."),
  paste0("- Eligible households: ", sum(analysis_population$household_eligible), "."),
  paste0("- Full-opportunity eligible households: ", sum(analysis_population$household_eligible & analysis_population$full_14_day_opportunity), "."),
  paste0("- Locked primary households: ", length(primary_household_ids), "."),
  paste0("- Locked primary event rows: ", nrow(primary_events), "."),
  paste0("- Same-stream five-second duplicate targets: ", length(same_stream_duplicate_ids), "."),
  paste0("- Unique immediate/backdated duplicate targets: ", length(cross_source_duplicate_ids), "."),
  paste0("- Total unique event rows excluded as duplicates: ", sum(events$excluded_as_locked_duplicate), "."),
  paste0("- Repeated decision rows excluded: ", length(decision_duplicate_ids), "."),
  paste0("- Main recorded bad-window decisions: ", nrow(bad_window_decisions), " across ", n_distinct(bad_window_decisions$household_id), " households."),
  paste0("- Exposure-marker primary households: ", n_distinct(exposure_marker_events$household_id), "."),
  "",
  "All validation assertions passed: unique row identifiers, intended time bounds, allowed categories, complete two-phase contribution in the primary household set, and absence of locked duplicates in primary tables.",
  "No phase-by-window table, effect estimate, confidence interval, hypothesis test, or fitted outcome model was generated."
)

writeLines(validation_report, file.path(output_dir, "validation_report.md"))

metadata <- c(
  paste0("generated_at_utc=", format(Sys.time(), tz = "UTC", usetz = TRUE)),
  "sap_version=1.0",
  "raw_snapshot=data/raw/2026-09-24_original_data",
  "record_integrity_exclusions=analysis/record_integrity_exclusions.csv v1.0 (DEC-030)",
  "snapshot_cutoff_utc=2026-09-24 00:08:50 UTC",
  "household_window=[first_login,first_login+336h)",
  paste0("r_version=", R.version.string),
  "confirmatory_models_fitted=false"
)
writeLines(metadata, file.path(output_dir, "run_metadata.txt"))
writeLines(
  capture.output(sessionInfo()),
  file.path(output_dir, "session_info.txt")
)

cat("\nLocked analysis-set construction completed.\n")
print(analysis_set_manifest, n = Inf)
cat("\nNo outcome model was fitted.\n")
