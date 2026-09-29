# Analysis pipeline (as run)

These are the scripts that produced every number, table and figure in the paper, published so that the analysis rules can be read and checked. They start from the raw database export, which is **not** published, so they do not run from this repository. To recompute the paper's statistics from the published tables, use `reproduce/reproduce_paper.R` (see the main README).

## Redactions

Original household IDs are not published. Three places in the scripts contained ID literals, and each is marked `[redacted for the public repository …]`:
- `01_build_audit_tables.R`, one line;
- `04_finalize_analysis_sets.R`, one integrity check;
- `04a_household_timezones.R`, the assignment of device-clock offsets to recruitment blocks.

In `05_descriptive_analysis.R`, one comment line that named the ID range and a team member was shortened. One flow label was shortened to "Study logins (test account excluded)", both in that script and in `results/participant_flow.csv`. Nothing else was changed.

Not published:
- internal data-provenance diagnostics (raw-export comparison, data-quality and outlier investigations, timestamp-precision check);
- the reporting and validation scripts that render the manuscript and internal documentation;
- the local script that exported the de-identified tables.

## Order and purpose

| Step | Script | Purpose |
|---|---|---|
| 0 | `00_validate_raw_data.R` | Checksums and structural checks of the raw export |
| 1 | `01_build_audit_tables.R` | Reconstruct source events and decisions; apply audit rules |
| 2 | `04_finalize_analysis_sets.R` | Locked analysis sets and populations (`--include-rewritten` builds the sensitivity sets that keep the 21 households with rewritten records) |
| 3 | `04a_household_timezones.R` | Device-clock offsets; check that stored window labels follow each device clock |
| 4 | `05_descriptive_analysis.R` | Participant flow and descriptives |
| 5 | `05b_sample_description.R` | Aggregate description of the primary sample |
| 6 | `05c_registration_patterns.R` | Post hoc registration patterns (local hour, retrospective entries, dialogs) |
| 7 | `06_primary_model.R` | Primary cumulative-logit mixed model, likelihood-ratio test, profile-likelihood CI |
| 8 | `07_secondary_models.R` | Binary models; RQ2 waiting proportion with household bootstrap |
| 9 | `08_sensitivity_analyses.R` | Prespecified sensitivity analyses, calendar adjustment, leave-one-household-out, household bootstrap |
| 10 | `08b_mixed_model_checks.R` | Post hoc checks: variance partition, nominal test, region interaction, registration-count model, waits as bad uses, within-phase trend, population-averaged probabilities |
| – | `analysis_helpers.R`, `io_utils.R` | Shared model and I/O functions |
| – | `figure_system.py`, `figure_patterns.py`, `figure_results.py` | Figures 1, 2 and 3 of the paper. The docstrings of the last two still carry their earlier figure numbers. |

## Decision references in the code

The scripts refer to entries of the project's decision log:

| Entry | Title |
|---|---|
| DEC-021 | Activity outliers and ownership checks |
| DEC-028 | Calendar covariate without time of day; local dates (2026-09-27) |
| DEC-029 | Post-hoc mixed-model checks and registration decomposition (2026-09-27) |
| DEC-030 | Exclude households whose records were rewritten after collection (2026-09-28) |

The locked statistical analysis plan is `materials/statistical_analysis_plan_v1.0.md`.
