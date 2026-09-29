# Data: de-identified analysis tables

These tables contain the analysis events and bad-window decisions of the households that were eligible for the study. They were derived from the locked analysis sets of the pipeline (`analysis/04_finalize_analysis_sets.R`) and de-identified before publication.

## De-identification

- **Households** carry random codes (`H01`–`H79`), assigned in random order. The mapping to the app's login IDs is kept by the authors and is not published.
- **Events and decisions** carry sequential codes (`E0001`…, `D0001`…) with no link to database identifiers.
- **Time:**
  - No exact timestamps are published.
  - Each record has the study day and, except for households with rewritten records, the local hour (integer), a local calendar-day index and the local weekday.
  - These are the time variables the models use.
- **Not published:**
  - login IDs and passcodes,
  - names and contact details,
  - free text (the app collected none from participants),
  - demographic answers at household level.
  - The primary sample is described in aggregate in `results/primary_sample_description.csv`.
- **Clock region** is published only as `Germany` or `East/Southeast Asia`. It is derived from the device clock, as reported in the paper.

## Files

### `households.csv` (one row per household with at least one analysis record)

| Column | Meaning |
|---|---|
| `household_code` | Random household code |
| `clock_region` | `Germany` (device clock UTC+2) or `East/Southeast Asia` (UTC+8/+9). Empty for households with rewritten records. |
| `record_integrity_excluded` | `TRUE` for the 21 households whose stored records were overwritten by a data-processing script after collection. They are excluded from all analyses except the labelled inclusion sensitivity analysis (DEC-030). |
| `full_14_day_opportunity` | The household's 14 days (336 h) had elapsed when the data were exported. |
| `paired_contributor_locked` | At least one valid registered use in each phase. |
| `primary_population` | Member of the primary sample (42 households). |

### `events.csv` (one row per registered appliance use in any analysis set)

| Column | Meaning |
|---|---|
| `event_code` | Event code |
| `household_code` | Household code |
| `appliance` | `dishwasher`, `washing_machine`, `phone_charging` |
| `window` | App window of the use: `bad`, `ok`, `great`. It is the stored label from the device clock; for retrospective entries it follows the reported time of use. |
| `source_type` | `immediate_usage` (baseline "Start Now"), `nudge_accept` (nudge-phase registration, including "Use anyway"), `backdated_usage` (retrospective entry) |
| `is_backdated` | Retrospective entry |
| `event_phase` | Phase by time of use: `baseline` [0, 168) h, `nudge` [168, 336) h after first login |
| `registration_phase` | Phase by time of registration (differs from `event_phase` for four retrospective entries) |
| `study_day` | Day since first login, 1–14 (by time of use) |
| `local_hour` | Local hour of use on the device clock, 0–23 (empty for households with rewritten records) |
| `calendar_day` | Local calendar date as days since 1 September 2026 (empty for households with rewritten records) |
| `weekday_local` | Local weekday, 1 = Monday … 7 = Sunday (empty for households with rewritten records) |
| `full_14_day_opportunity`, `paired_contributor_locked` | Household flags, as in `households.csv` |

### `event_set_membership.csv` (which events belong to which analysis set, and with which phase)

| `analysis_set` | Events | Use in the paper |
|---|---|---|
| `primary_events` | 802 | Primary analysis (42 households) |
| `primary_events_incl_rewritten` | 1,001 | Sensitivity: including the 21 households with rewritten records |
| `all_eligible_events` | 882 | Sensitivity: all eligible households, including incomplete follow-up |
| `exposure_marker_events` | 802 | Sensitivity: the nudge phase starts at the household's earliest recorded nudge-phase introduction or nudge response (observed exposure) |
| `high_load_events` | 272 | Sensitivity: excluding phone charging |
| `immediate_only_events` | 604 | Sensitivity: immediate registrations only |
| `backdated_boundary_excluded_events` | 798 | Sensitivity: excluding four phase-crossing retrospective entries |
| `backdated_registration_phase_events` | 802 | Sensitivity: retrospective entries assigned by registration time |
| `primary_events_retain_all_duplicates` | 835 | Sensitivity: technical duplicates retained |
| `incomplete_followup_events` | 33 | Households whose 14 days had not elapsed (descriptive) |

The `phase` column gives the phase that the set uses for each event.

### `decisions.csv` (one row per recorded bad-window dialog response in any decision set)

| Column | Meaning |
|---|---|
| `decision_code`, `household_code` | Codes |
| `appliance`, `window` | Appliance, window (always `bad`) |
| `response` | `accept` ("Use anyway") or `decline` ("I'll wait") |
| `wait` | `TRUE` for "I'll wait" |
| `suggested_wait_hours` | Whole hours until the next great window, as shown in the dialog |
| `decision_phase`, `study_day`, `local_hour`, `calendar_day`, `weekday_local` | As for events |

### `decision_set_membership.csv`

| `analysis_set` | Decisions | Use |
|---|---|---|
| `bad_window_decisions` | 106 | RQ2 (35 households) |
| `bad_window_decisions_primary_population` | 104 | Decisions of the primary sample; its 9 waits enter the "waits as bad uses" check |
| `bad_window_decisions_exposure_marker` | 106 | Sensitivity (observed exposure) |
| `bad_window_decisions_incl_rewritten` | 139 | Sensitivity: including the 21 households with rewritten records |
