source("analysis/io_utils.R")
# SusAI audited data construction
#
# Purpose:
#   Build participant flow, registered-use candidates, nudge decisions, and a
#   row-level exclusion/review audit from the original database CSVs received
#   on 2026-09-24, using the complete recovered snapshot and applying an exact
#   336-hour observation window separately to every household.
#
# Scope:
#   This script performs no phase-effect estimation and fits no outcome model.
#   Open analysis choices remain visible as flags rather than being resolved by
#   silently deleting or reassigning source rows.

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
})

source(file.path("analysis", "00_validate_raw_data.R"), local = TRUE)

raw_dir <- file.path("data", "raw", "2026-09-24_original_data")
derived_dir <- file.path("data", "derived", "2026-09-22_audit")
quality_dir <- file.path("outputs", "data_quality")

dir.create(derived_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(quality_dir, recursive = TRUE, showWarnings = FALSE)

# The complete recovered export finished at 2026-09-24 02:08:50 CEST. This is
# the latest defensible snapshot cutoff. It governs whether a household had the
# opportunity to complete 336 hours; event inclusion still uses each
# household's individual [first_login, first_login + 336 hours) interval.
administrative_cutoff_utc <- as.POSIXct("2026-09-24 00:08:50", tz = "UTC")

hours_between <- function(later, earlier) {
  as.numeric(difftime(later, earlier, units = "hours"))
}

phase_from_hours <- function(x) {
  case_when(
    is.na(x) ~ NA_character_,
    x < 0 ~ "before_login",
    x < 168 ~ "baseline",
    x < 336 ~ "nudge",
    TRUE ~ "after_study"
  )
}

households <- read_csv(
  file.path(raw_dir, "households.csv"),
  col_types = cols(
    id = col_character(),
    passcode_hash = col_character(),
    first_login_at = col_datetime(),
    phase_override = col_character(),
    ineligible_at = col_datetime(),
    consented_at = col_datetime(),
    phase2_intro_seen_at = col_datetime(),
    is_test = col_logical(),
    green_score = col_integer(),
    day_override = col_integer(),
    created_at = col_datetime()
  )
) %>%
  select(-passcode_hash) %>%
  mutate(
    phase2_intro_seen_at_raw = phase2_intro_seen_at,
    phase2_intro_seen_at = if_else(
      !is.na(phase2_intro_seen_at) &
        phase2_intro_seen_at <= administrative_cutoff_utc,
      phase2_intro_seen_at,
      as.POSIXct(NA, tz = "UTC")
    )
  )

profiles <- read_csv(
  file.path(raw_dir, "household_profiles.csv"),
  col_types = cols(
    household_id = col_character(),
    owns_dishwasher = col_logical(),
    owns_washing_machine = col_logical(),
    owns_phone_charging_habit = col_logical(),
    household_size = col_integer(),
    dwelling_type = col_character(),
    age_bracket = col_character(),
    created_at = col_datetime()
  )
)

usage <- read_csv(
  file.path(raw_dir, "usage_logs.csv"),
  col_types = cols(
    id = col_character(),
    household_id = col_character(),
    appliance = col_character(),
    started_at = col_datetime(),
    window_at_use = col_character(),
    is_backdated = col_logical(),
    created_at = col_datetime()
  )
)

nudge <- read_csv(
  file.path(raw_dir, "nudge_responses.csv"),
  col_types = cols(
    id = col_character(),
    household_id = col_character(),
    appliance = col_character(),
    window = col_character(),
    response = col_character(),
    suggested_wait_hours = col_integer(),
    created_at = col_datetime()
  )
)

household_base <- households %>%
  left_join(profiles, by = c("id" = "household_id"), suffix = c("", "_profile")) %>%
  transmute(
    household_id = id,
    is_test,
    has_consent = !is.na(consented_at),
    explicitly_ineligible = !is.na(ineligible_at),
    has_first_login = !is.na(first_login_at),
    account_created_at = created_at,
    first_login_at,
    consented_at,
    ineligible_at,
    phase2_intro_seen_at,
    phase2_intro_seen_at_raw,
    phase2_intro_after_cutoff =
      !is.na(phase2_intro_seen_at_raw) &
      phase2_intro_seen_at_raw > administrative_cutoff_utc,
    phase2_intro_hours = hours_between(phase2_intro_seen_at, first_login_at),
    phase_override,
    day_override,
    has_phase_override = !is.na(phase_override),
    has_day_override = !is.na(day_override),
    original_source_recovered_for_rounded_batch = id %in% REDACTED_IDS,  # [redacted for the public repository: original household IDs are not published]
    has_profile = !is.na(created_at_profile),
    owns_dishwasher,
    owns_washing_machine,
    owns_phone_charging_habit,
    administrative_hours_at_cutoff =
      hours_between(administrative_cutoff_utc, first_login_at),
    full_14_day_opportunity =
      !is.na(first_login_at) &
      first_login_at + 336 * 60 * 60 <= administrative_cutoff_utc,
    household_eligible =
      !is_test & !is.na(consented_at) & is.na(ineligible_at) & !is.na(first_login_at)
  )

household_lookup <- household_base %>%
  select(
    household_id, household_eligible, first_login_at,
    consented_at, phase2_intro_seen_at,
    full_14_day_opportunity, has_phase_override, has_day_override
  )

usage_events <- usage %>%
  transmute(
    analysis_event_id = paste0("usage_logs:", id),
    source_table = "usage_logs",
    source_id = id,
    household_id,
    appliance,
    # SAP: immediate actions use registration time; backdated actions use
    # reported use time. Both fields coincide for every immediate source row
    # in this snapshot (verified before inspecting the phase effect).
    event_time = if_else(is_backdated, started_at, created_at),
    registration_time = created_at,
    window_ordered = window_at_use,
    source_type = if_else(is_backdated, "backdated_usage", "immediate_usage"),
    is_backdated,
    source_response = NA_character_
  )

nudge_accept_events <- nudge %>%
  filter(response == "accept") %>%
  transmute(
    analysis_event_id = paste0("nudge_responses:", id),
    source_table = "nudge_responses",
    source_id = id,
    household_id,
    appliance,
    event_time = created_at,
    registration_time = created_at,
    window_ordered = window,
    source_type = "nudge_accept",
    is_backdated = FALSE,
    source_response = response
  )

registered_use_candidates <- bind_rows(usage_events, nudge_accept_events) %>%
  left_join(household_lookup, by = "household_id") %>%
  mutate(
    event_hours_since_login = hours_between(event_time, first_login_at),
    registration_hours_since_login = hours_between(registration_time, first_login_at),
    event_phase = phase_from_hours(event_hours_since_login),
    registration_phase = phase_from_hours(registration_hours_since_login),
    study_day = if_else(
      event_hours_since_login >= 0 & event_hours_since_login < 336,
      floor(event_hours_since_login / 24) + 1,
      NA_real_
    ),
    lookback_hours = if_else(
      is_backdated,
      hours_between(registration_time, event_time),
      NA_real_
    ),
    event_inside_14_days =
      event_hours_since_login >= 0 & event_hours_since_login < 336,
    registration_inside_14_days =
      registration_hours_since_login >= 0 & registration_hours_since_login < 336,
    within_administrative_cutoff =
      !is.na(registration_time) & registration_time <= administrative_cutoff_utc,
    source_phase_compatible = case_when(
      source_type == "immediate_usage" ~ event_phase == "baseline",
      source_type == "nudge_accept" ~ event_phase == "nudge",
      source_type == "backdated_usage" ~ event_phase %in% c("baseline", "nudge"),
      TRUE ~ FALSE
    ),
    backdated_crosses_168h =
      source_type == "backdated_usage" &
      event_phase != registration_phase &
      event_phase %in% c("baseline", "nudge") &
      registration_phase %in% c("baseline", "nudge"),
    backdated_over_24h =
      source_type == "backdated_usage" & !is.na(lookback_hours) & lookback_hours > 24,
    backdated_over_2m_future =
      source_type == "backdated_usage" & !is.na(lookback_hours) & lookback_hours < -(2 / 60),
    passes_base_time_quality =
      household_eligible &
      !is.na(event_time) & !is.na(registration_time) &
      within_administrative_cutoff &
      event_inside_14_days & registration_inside_14_days &
      !backdated_over_24h & !backdated_over_2m_future,
    passes_confirmed_event_rules =
      passes_base_time_quality & source_phase_compatible,
    # Backward-compatible column name for the now-locked strict rule: phase is
    # assigned from started_at/event_time.
    passes_proposed_event_time_rule = passes_confirmed_event_rules
  )

# Compare only temporally plausible candidates against the preceding record
# with the same complete stream key. Grouping by stored window avoids missing
# A-B-A duplicate patterns because a different label was interleaved, while
# filtering first prevents an already-invalid row from hiding a repeat.
same_stream_flags <- registered_use_candidates %>%
  filter(passes_base_time_quality) %>%
  arrange(household_id, event_time, registration_time, analysis_event_id) %>%
  group_by(household_id, appliance, source_type, window_ordered) %>%
  transmute(
    analysis_event_id,
    prior_same_stream_event_id = lag(analysis_event_id),
    prior_same_stream_window = lag(window_ordered),
    seconds_since_prior_same_stream = as.numeric(
      difftime(event_time, lag(event_time), units = "secs")
    ),
    same_window_as_prior_same_stream = TRUE,
    near_repeat_within_5_seconds =
      !is.na(seconds_since_prior_same_stream) & seconds_since_prior_same_stream <= 5,
    near_repeat_within_2_minutes =
      !is.na(seconds_since_prior_same_stream) & seconds_since_prior_same_stream <= 120
  ) %>%
  ungroup() %>%
  select(
    analysis_event_id, prior_same_stream_event_id,
    prior_same_stream_window, seconds_since_prior_same_stream,
    same_window_as_prior_same_stream, near_repeat_within_5_seconds,
    near_repeat_within_2_minutes
  )

registered_use_candidates <- registered_use_candidates %>%
  left_join(same_stream_flags, by = "analysis_event_id") %>%
  mutate(
    same_window_as_prior_same_stream =
      replace_na(same_window_as_prior_same_stream, FALSE),
    near_repeat_within_5_seconds =
      replace_na(near_repeat_within_5_seconds, FALSE),
    near_repeat_within_2_minutes =
      replace_na(near_repeat_within_2_minutes, FALSE)
  ) %>%
  group_by(
    source_table, household_id, appliance, event_time, registration_time,
    window_ordered, source_type, source_response
  ) %>%
  mutate(
    exact_content_group_size = n(),
    exact_content_duplicate = n() > 1
  ) %>%
  ungroup()

# Duplicate candidates are review pairs, not deletions. A broad two-hour event
# distance is retained so the team can choose a narrower deterministic rule
# before any confirmatory analysis. The table also reports tighter thresholds.
immediate_candidates <- registered_use_candidates %>%
  filter(source_type %in% c("immediate_usage", "nudge_accept")) %>%
  select(
    household_id, appliance,
    immediate_event_id = analysis_event_id,
    immediate_source_type = source_type,
    immediate_event_time = event_time,
    immediate_window = window_ordered,
    immediate_household_eligible = household_eligible,
    immediate_passes_proposed_rules = passes_proposed_event_time_rule
  )

backdated_candidates <- registered_use_candidates %>%
  filter(source_type == "backdated_usage") %>%
  select(
    household_id, appliance,
    backdated_event_id = analysis_event_id,
    backdated_event_time = event_time,
    backdated_registration_time = registration_time,
    backdated_window = window_ordered,
    backdated_household_eligible = household_eligible,
    backdated_passes_proposed_rules = passes_proposed_event_time_rule
  )

possible_duplicate_pairs <- inner_join(
  immediate_candidates,
  backdated_candidates,
  by = c("household_id", "appliance"),
  relationship = "many-to-many"
) %>%
  mutate(
    event_gap_minutes = abs(as.numeric(
      difftime(backdated_event_time, immediate_event_time, units = "mins")
    )),
    backdated_registered_after_immediate =
      backdated_registration_time >= immediate_event_time,
    registration_delay_hours = hours_between(
      backdated_registration_time,
      immediate_event_time
    ),
    same_window = backdated_window == immediate_window,
    within_5_minutes = event_gap_minutes <= 5,
    within_15_minutes = event_gap_minutes <= 15,
    within_30_minutes = event_gap_minutes <= 30,
    within_60_minutes = event_gap_minutes <= 60,
    review_pair = event_gap_minutes <= 120
  ) %>%
  filter(review_pair) %>%
  arrange(event_gap_minutes, household_id, appliance)

duplicate_flag_ids <- unique(c(
  possible_duplicate_pairs$immediate_event_id,
  possible_duplicate_pairs$backdated_event_id
))

registered_use_candidates <- registered_use_candidates %>%
  mutate(possible_immediate_backdated_duplicate = analysis_event_id %in% duplicate_flag_ids)

nudge_decisions <- nudge %>%
  left_join(household_lookup, by = "household_id") %>%
  transmute(
    decision_id = paste0("nudge_responses:", id),
    source_id = id,
    household_id,
    appliance,
    window,
    response,
    wait = response == "decline",
    suggested_wait_hours,
    decision_time = created_at,
    first_login_at,
    consented_at,
    phase2_intro_seen_at,
    decision_hours_since_login = hours_between(created_at, first_login_at),
    decision_phase = phase_from_hours(decision_hours_since_login),
    household_eligible,
    full_14_day_opportunity,
    within_administrative_cutoff =
      !is.na(created_at) & created_at <= administrative_cutoff_utc,
    decision_before_consent =
      !is.na(consented_at) & created_at < consented_at,
    decision_without_recorded_phase2_intro = is.na(phase2_intro_seen_at),
    decision_before_recorded_phase2_intro =
      !is.na(phase2_intro_seen_at) & created_at < phase2_intro_seen_at,
    early_nudge_response =
      !is.na(decision_hours_since_login) &
      decision_hours_since_login >= 0 & decision_hours_since_login < 168,
    nonbad_decline = response == "decline" & window != "bad",
    bad_missing_wait_hours = window == "bad" & is.na(suggested_wait_hours),
    nonbad_has_wait_hours = window != "bad" & !is.na(suggested_wait_hours),
    suggested_wait_outside_implemented_range =
      window == "bad" & !is.na(suggested_wait_hours) &
      !(suggested_wait_hours %in% 3:15),
    passes_base_decision_quality =
      household_eligible & within_administrative_cutoff &
      decision_hours_since_login >= 0 & decision_hours_since_login < 336,
    passes_recorded_decision_window =
      passes_base_decision_quality & decision_phase == "nudge",
    eligible_bad_window_decision_candidate =
      passes_base_decision_quality & decision_phase == "nudge" & window == "bad"
  )

# As above, compare plausible decisions within the complete key so neither an
# interleaved response nor an already-invalid row can hide a repeated submit.
decision_repeat_flags <- nudge_decisions %>%
  filter(passes_base_decision_quality) %>%
  arrange(household_id, appliance, decision_time, decision_id) %>%
  group_by(household_id, appliance, window, response) %>%
  transmute(
    decision_id,
    prior_decision_id = lag(decision_id),
    prior_decision_window = lag(window),
    prior_decision_response = lag(response),
    seconds_since_prior_decision = as.numeric(
      difftime(decision_time, lag(decision_time), units = "secs")
    ),
    same_as_prior_decision = TRUE,
    repeated_decision_within_5_seconds =
      !is.na(seconds_since_prior_decision) &
      seconds_since_prior_decision <= 5 & same_as_prior_decision,
    repeated_decision_within_2_minutes =
      !is.na(seconds_since_prior_decision) &
      seconds_since_prior_decision <= 120 & same_as_prior_decision
  ) %>%
  ungroup() %>%
  select(
    decision_id, prior_decision_id, prior_decision_window,
    prior_decision_response, seconds_since_prior_decision,
    same_as_prior_decision, repeated_decision_within_5_seconds,
    repeated_decision_within_2_minutes
  )

nudge_decisions <- nudge_decisions %>%
  left_join(decision_repeat_flags, by = "decision_id") %>%
  mutate(
    same_as_prior_decision = replace_na(same_as_prior_decision, FALSE),
    repeated_decision_within_5_seconds =
      replace_na(repeated_decision_within_5_seconds, FALSE),
    repeated_decision_within_2_minutes =
      replace_na(repeated_decision_within_2_minutes, FALSE)
  ) %>%
  group_by(household_id, appliance, window, response, decision_time) %>%
  mutate(
    exact_decision_content_group_size = n(),
    exact_decision_content_duplicate = n() > 1
  ) %>%
  ungroup() %>%
  arrange(household_id, decision_time, decision_id)

event_contributions <- registered_use_candidates %>%
  filter(passes_proposed_event_time_rule) %>%
  count(household_id, event_phase, name = "n_events") %>%
  pivot_wider(
    names_from = event_phase,
    values_from = n_events,
    values_fill = 0,
    names_prefix = "valid_events_"
  )

for (needed in c("valid_events_baseline", "valid_events_nudge")) {
  if (!needed %in% names(event_contributions)) event_contributions[[needed]] <- 0L
}

source_counts <- registered_use_candidates %>%
  count(household_id, source_type, name = "n_source_rows") %>%
  pivot_wider(
    names_from = source_type,
    values_from = n_source_rows,
    values_fill = 0,
    names_prefix = "source_rows_"
  )

participant_flow <- household_base %>%
  left_join(event_contributions, by = "household_id") %>%
  left_join(source_counts, by = "household_id") %>%
  mutate(
    across(starts_with("valid_events_"), ~ replace_na(.x, 0L)),
    across(starts_with("source_rows_"), ~ replace_na(.x, 0L)),
    contributes_baseline = valid_events_baseline > 0,
    contributes_nudge = valid_events_nudge > 0,
    paired_contributor = contributes_baseline & contributes_nudge,
    primary_population_candidate =
      household_eligible & full_14_day_opportunity & paired_contributor,
    administrative_incomplete =
      household_eligible & !full_14_day_opportunity
  ) %>%
  arrange(household_id)

registered_use_candidates <- registered_use_candidates %>%
  left_join(
    participant_flow %>%
      select(
        household_id, paired_contributor, primary_population_candidate
      ),
    by = "household_id"
  ) %>%
  mutate(
    event_in_primary_population_candidate =
      passes_proposed_event_time_rule & primary_population_candidate
  )

make_audit_rows <- function(data, condition, source_table, source_id, household_id,
                            scope, severity, rule_code, reason) {
  condition_value <- eval(substitute(condition), data, parent.frame())
  data[which(!is.na(condition_value) & condition_value), , drop = FALSE] %>%
    transmute(
      source_table = {{ source_table }},
      source_id = {{ source_id }},
      household_id = {{ household_id }},
      scope = scope,
      severity = severity,
      rule_code = rule_code,
      reason = reason
    )
}

household_audit <- bind_rows(
  make_audit_rows(participant_flow, is_test, "households", household_id, household_id,
                  "household", "exclude", "H_TEST_ACCOUNT", "Test account."),
  make_audit_rows(participant_flow, !has_consent, "households", household_id, household_id,
                  "household", "exclude", "H_NO_CONSENT", "No recorded consent."),
  make_audit_rows(participant_flow, explicitly_ineligible, "households", household_id, household_id,
                  "household", "exclude", "H_EXPLICITLY_INELIGIBLE", "Account marked ineligible."),
  make_audit_rows(participant_flow, !has_first_login, "households", household_id, household_id,
                  "household", "exclude", "H_MISSING_FIRST_LOGIN", "No first-login timestamp."),
  make_audit_rows(participant_flow, administrative_incomplete, "households", household_id, household_id,
                  "primary_population", "exclude", "H_ADMIN_INCOMPLETE",
                  "Fewer than 336 hours elapsed by the recovered snapshot cutoff."),
  make_audit_rows(participant_flow, phase2_intro_after_cutoff,
                  "households", household_id, household_id,
                  "household", "review", "H_PHASE2_INTRO_AFTER_CUTOFF",
                  "Phase-2 introduction was first recorded after the recovered snapshot cutoff and is right-censored in derived analysis fields."),
  make_audit_rows(participant_flow, household_eligible & has_phase_override, "households", household_id, household_id,
                  "household", "review", "H_PHASE_OVERRIDE", "Eligible account has a phase override."),
  make_audit_rows(participant_flow, household_eligible & has_day_override, "households", household_id, household_id,
                  "household", "review", "H_DAY_OVERRIDE", "Eligible account has a study-day override.")
)

event_audit <- bind_rows(
  make_audit_rows(registered_use_candidates, !household_eligible, source_table, source_id, household_id,
                  "registered_use", "exclude", "E_INELIGIBLE_HOUSEHOLD", "Source row belongs to an ineligible household."),
  make_audit_rows(registered_use_candidates, is.na(event_time), source_table, source_id, household_id,
                  "registered_use", "exclude", "E_MISSING_EVENT_TIME", "Event time is missing."),
  make_audit_rows(registered_use_candidates, is.na(registration_time), source_table, source_id, household_id,
                  "registered_use", "exclude", "E_MISSING_REGISTRATION_TIME", "Registration time is missing."),
  make_audit_rows(registered_use_candidates, !within_administrative_cutoff,
                  source_table, source_id, household_id,
                  "registered_use", "exclude", "E_AFTER_ADMINISTRATIVE_CUTOFF",
                  "Registration occurred after the recovered snapshot cutoff."),
  make_audit_rows(registered_use_candidates, event_hours_since_login < 0, source_table, source_id, household_id,
                  "registered_use", "exclude", "E_EVENT_BEFORE_LOGIN", "Event time is before first login."),
  make_audit_rows(registered_use_candidates, registration_hours_since_login < 0, source_table, source_id, household_id,
                  "registered_use", "exclude", "E_REGISTRATION_BEFORE_LOGIN", "Registration time is before first login."),
  make_audit_rows(registered_use_candidates, event_hours_since_login >= 336, source_table, source_id, household_id,
                  "registered_use", "exclude", "E_EVENT_AT_OR_AFTER_336H", "Event time is at or after 336 hours."),
  make_audit_rows(registered_use_candidates, registration_hours_since_login >= 336, source_table, source_id, household_id,
                  "registered_use", "exclude", "E_REGISTRATION_AT_OR_AFTER_336H", "Registration time is at or after 336 hours."),
  make_audit_rows(registered_use_candidates, source_type == "nudge_accept" & event_phase == "baseline",
                  source_table, source_id, household_id, "registered_use", "exclude",
                  "E_EARLY_NUDGE_ACCEPT", "Nudge accept occurs before the strict 168-hour boundary."),
  make_audit_rows(registered_use_candidates, source_type == "immediate_usage" & event_phase == "nudge",
                  source_table, source_id, household_id, "registered_use", "exclude",
                  "E_IMMEDIATE_USAGE_IN_NUDGE_PHASE", "Immediate usage-log row occurs in the strict nudge phase."),
  make_audit_rows(registered_use_candidates, backdated_over_24h, source_table, source_id, household_id,
                  "registered_use", "exclude", "E_BACKDATED_OVER_24H", "Backdated lookback exceeds the implemented 24-hour limit."),
  make_audit_rows(registered_use_candidates, backdated_over_2m_future, source_table, source_id, household_id,
                  "registered_use", "exclude", "E_BACKDATED_OVER_2M_FUTURE", "Reported event is more than two minutes after registration."),
  make_audit_rows(registered_use_candidates, backdated_crosses_168h, source_table, source_id, household_id,
                  "registered_use", "review", "R_BACKDATED_CROSSES_168H", "Event and registration timestamps fall on opposite sides of 168 hours."),
  make_audit_rows(registered_use_candidates, exact_content_duplicate, source_table, source_id, household_id,
                  "registered_use", "review", "R_EXACT_CONTENT_DUPLICATE", "Rows share all event content apart from source identifier."),
  make_audit_rows(registered_use_candidates, near_repeat_within_5_seconds, source_table, source_id, household_id,
                  "registered_use", "review", "R_NEAR_REPEAT_5_SECONDS", "Same household, appliance, and source type repeated within five seconds."),
  make_audit_rows(registered_use_candidates, near_repeat_within_2_minutes & !near_repeat_within_5_seconds,
                  source_table, source_id, household_id, "registered_use", "review",
                  "R_NEAR_REPEAT_2_MINUTES", "Same household, appliance, and source type repeated within two minutes."),
  make_audit_rows(registered_use_candidates, possible_immediate_backdated_duplicate,
                  source_table, source_id, household_id, "registered_use", "review",
                  "R_IMMEDIATE_BACKDATED_PAIR_2H", "Immediate and backdated rows for the same household/appliance are within two hours.")
)

decision_audit <- bind_rows(
  make_audit_rows(nudge_decisions, !household_eligible, "nudge_responses", source_id, household_id,
                  "nudge_decision", "exclude", "D_INELIGIBLE_HOUSEHOLD", "Decision belongs to an ineligible household."),
  make_audit_rows(nudge_decisions, !within_administrative_cutoff,
                  "nudge_responses", source_id, household_id,
                  "nudge_decision", "exclude", "D_AFTER_ADMINISTRATIVE_CUTOFF",
                  "Decision occurred after the recovered snapshot cutoff."),
  make_audit_rows(nudge_decisions, early_nudge_response, "nudge_responses", source_id, household_id,
                  "nudge_decision", "exclude", "D_EARLY_NUDGE_RESPONSE", "Nudge response occurs before the strict 168-hour boundary."),
  make_audit_rows(nudge_decisions, decision_hours_since_login < 0, "nudge_responses", source_id, household_id,
                  "nudge_decision", "exclude", "D_RESPONSE_BEFORE_LOGIN", "Nudge response occurs before first login."),
  make_audit_rows(nudge_decisions, decision_hours_since_login >= 336, "nudge_responses", source_id, household_id,
                  "nudge_decision", "exclude", "D_RESPONSE_AT_OR_AFTER_336H", "Nudge response occurs at or after 336 hours."),
  make_audit_rows(nudge_decisions, decision_before_consent,
                  "nudge_responses", source_id, household_id,
                  "nudge_decision", "review", "R_DECISION_BEFORE_CONSENT",
                  "Nudge response is recorded before consent."),
  make_audit_rows(nudge_decisions,
                  household_eligible & within_administrative_cutoff &
                    decision_phase == "nudge" &
                    decision_without_recorded_phase2_intro,
                  "nudge_responses", source_id, household_id,
                  "nudge_decision", "review", "R_STRICT_NUDGE_WITHOUT_INTRO",
                  "Strict nudge-phase decision has no recorded Phase-2 introduction."),
  make_audit_rows(nudge_decisions,
                  household_eligible & within_administrative_cutoff &
                    decision_phase == "nudge" &
                    decision_before_recorded_phase2_intro,
                  "nudge_responses", source_id, household_id,
                  "nudge_decision", "review", "R_STRICT_NUDGE_BEFORE_INTRO",
                  "Strict nudge-phase decision precedes the recorded Phase-2 introduction."),
  make_audit_rows(nudge_decisions, nonbad_decline, "nudge_responses", source_id, household_id,
                  "nudge_decision", "review", "R_NONBAD_DECLINE", "Decline is stored in an ok or great window, which the current interface does not expose."),
  make_audit_rows(nudge_decisions, bad_missing_wait_hours, "nudge_responses", source_id, household_id,
                  "nudge_decision", "review", "R_BAD_MISSING_WAIT_HOURS", "Bad-window response has no suggested wait duration."),
  make_audit_rows(nudge_decisions, nonbad_has_wait_hours, "nudge_responses", source_id, household_id,
                  "nudge_decision", "review", "R_NONBAD_HAS_WAIT_HOURS", "Non-bad response has a suggested wait duration."),
  make_audit_rows(nudge_decisions, suggested_wait_outside_implemented_range,
                  "nudge_responses", source_id, household_id, "nudge_decision", "review",
                  "R_WAIT_HOURS_OUTSIDE_RANGE", "Suggested wait is outside the implemented bad-window range of 3 to 15 hours."),
  make_audit_rows(nudge_decisions, exact_decision_content_duplicate,
                  "nudge_responses", source_id, household_id, "nudge_decision", "review",
                  "R_EXACT_DECISION_CONTENT_DUPLICATE", "Rows share all recorded decision content apart from source identifier."),
  make_audit_rows(nudge_decisions, repeated_decision_within_5_seconds,
                  "nudge_responses", source_id, household_id, "nudge_decision", "review",
                  "R_REPEATED_DECISION_5_SECONDS", "Same household/appliance/window/response repeats within five seconds."),
  make_audit_rows(nudge_decisions,
                  repeated_decision_within_2_minutes & !repeated_decision_within_5_seconds,
                  "nudge_responses", source_id, household_id, "nudge_decision", "review",
                  "R_REPEATED_DECISION_2_MINUTES", "Same household/appliance/window/response repeats within two minutes.")
)

exclusion_and_review_audit <- bind_rows(
  household_audit,
  event_audit,
  decision_audit
) %>%
  arrange(severity, scope, rule_code, source_table, source_id)

participant_flow_summary <- tibble::tribble(
  ~flow_step, ~n_households,
  "Issued study accounts", nrow(participant_flow),
  "Recorded consent", sum(participant_flow$has_consent),
  "Not test, consented, not ineligible, and logged in", sum(participant_flow$household_eligible),
  "Eligible with full 14-day opportunity at snapshot cutoff", sum(participant_flow$household_eligible & participant_flow$full_14_day_opportunity),
  "Eligible but incomplete at snapshot cutoff", sum(participant_flow$administrative_incomplete),
  "Eligible contributing at least one candidate registered use", sum(participant_flow$household_eligible & (participant_flow$contributes_baseline | participant_flow$contributes_nudge)),
  "Eligible contributing candidate uses in both phases", sum(participant_flow$household_eligible & participant_flow$paired_contributor),
  "Proposed primary-population candidate", sum(participant_flow$primary_population_candidate)
)

usage_inventory <- registered_use_candidates %>%
  mutate(
    inclusion_status = if_else(
      passes_proposed_event_time_rule,
      "passes_proposed_rules",
      "excluded_by_current_rules"
    )
  ) %>%
  count(inclusion_status, event_phase, source_type, appliance, window_ordered, name = "n_rows") %>%
  arrange(inclusion_status, event_phase, source_type, appliance, window_ordered)

nudge_decision_inventory <- nudge_decisions %>%
  count(
    eligibility = if_else(household_eligible, "eligible_household", "ineligible_household"),
    decision_phase, window, response,
    name = "n_rows"
  ) %>%
  arrange(eligibility, decision_phase, window, response)

quality_findings <- exclusion_and_review_audit %>%
  count(severity, scope, rule_code, reason, name = "n_flagged_rows") %>%
  arrange(severity, scope, rule_code)

backdated_time_audit <- registered_use_candidates %>%
  filter(source_type == "backdated_usage") %>%
  select(
    analysis_event_id, source_id, household_id, appliance,
    event_time, registration_time, lookback_hours,
    event_hours_since_login, registration_hours_since_login,
    event_phase, registration_phase, backdated_crosses_168h,
    backdated_over_24h, backdated_over_2m_future,
    passes_proposed_event_time_rule
  ) %>%
  arrange(household_id, event_time)

stopifnot(
  nrow(participant_flow) == nrow(households),
  nrow(nudge_decisions) == nrow(nudge),
  nrow(registered_use_candidates) == nrow(usage) + sum(nudge$response == "accept"),
  all(participant_flow$household_id %in% households$id),
  all(registered_use_candidates$source_id %in% c(usage$id, nudge$id))
)

write_csv_precise(participant_flow, file.path(derived_dir, "participant_flow.csv"), na = "")
write_csv_precise(registered_use_candidates, file.path(derived_dir, "registered_use_candidates.csv"), na = "")
write_csv_precise(nudge_decisions, file.path(derived_dir, "nudge_decisions.csv"), na = "")
write_csv_precise(exclusion_and_review_audit, file.path(derived_dir, "exclusion_and_review_audit.csv"), na = "")
write_csv_precise(possible_duplicate_pairs, file.path(derived_dir, "possible_duplicate_pairs.csv"), na = "")
write_csv_precise(backdated_time_audit, file.path(derived_dir, "backdated_time_audit.csv"), na = "")

write_csv_precise(participant_flow_summary, file.path(quality_dir, "participant_flow_summary.csv"), na = "")
write_csv_precise(usage_inventory, file.path(quality_dir, "usage_inventory.csv"), na = "")
write_csv_precise(nudge_decision_inventory, file.path(quality_dir, "nudge_decision_inventory.csv"), na = "")
write_csv_precise(quality_findings, file.path(quality_dir, "quality_findings.csv"), na = "")

metadata <- c(
  paste0("generated_at_utc=", format(Sys.time(), tz = "UTC", usetz = TRUE)),
  paste0("raw_snapshot=", raw_dir),
  paste0("administrative_cutoff_status=recovered_export_completion_mtime"),
  paste0("administrative_cutoff_utc=", format(administrative_cutoff_utc, tz = "UTC", usetz = TRUE)),
  paste0("administrative_cutoff_local=2026-09-24 02:08:50 Europe/Berlin"),
  paste0("r_version=", R.version.string),
  "confirmatory_models_fitted=false"
)
writeLines(metadata, file.path(quality_dir, "run_metadata.txt"))

cat("\nAudited construction completed.\n")
cat("Derived row-level tables:", derived_dir, "\n")
cat("Aggregate quality outputs:", quality_dir, "\n\n")
print(participant_flow_summary, n = Inf)
cat("\nQuality flags by rule\n")
print(quality_findings, n = Inf)
