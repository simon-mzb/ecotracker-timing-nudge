# EcoTracker: a moment-of-use timing nudge for household appliances

This repository accompanies the paper *When the Nudge Is Also the Meter: A Field Study of a Moment-of-Use Timing Nudge for Household Appliances* (Seminar AI and Sustainability, University of Regensburg, 2026). It contains:
- the code,
- the aggregate outputs,
- the de-identified event and decision tables,
- the study materials.

**The study in brief:**
- **App:** EcoTracker is a mobile web app. Households registered when they started a dishwasher, washing machine or phone charger.
- **Design:** each household first had a seven-day baseline with logging only. For the next seven days the app then showed:
  - the current window of a fixed daily schedule (great 10:00–17:00; ok 8:00–10:00 and 17:00–19:00; bad otherwise),
  - a dialog offering "Use anyway" or "I'll wait" in bad windows,
  - a green score.
- **Sample:** the primary analysis covers 42 households and 802 registered uses.
- **Methods:** the paper describes design, sample and analysis in full.

## Contents

| Folder | Content |
|---|---|
| `data/` | De-identified analysis tables: households, registered uses, bad-window decisions and analysis-set membership. Codebook in `data/README.md`. |
| `reproduce/` | `reproduce_paper.R` recomputes the paper's statistics from `data/` and compares each value with `results/`. |
| `results/` | Aggregate outputs of the original pipeline (CSV) and the figures (`results/figures/`) |
| `analysis/` | The pipeline scripts as run on the raw export, with original IDs redacted (see `analysis/README.md`) |
| `app/` | Source code of the EcoTracker web app (source snapshot) |
| `materials/` | Consent text, intake questionnaire and all participant-facing app texts (EN/DE), app screenshots, statistical analysis plan v1.0 |
| `renv.lock` | R package versions (R 4.6.1) |

## Reproducing the results

With R 4.6.1:

```r
install.packages("renv")
renv::restore()   # installs the package versions in renv.lock
```

Then, from the repository root:

```bash
Rscript reproduce/reproduce_paper.R          # about 3 minutes, includes two 399-replicate household bootstraps
Rscript reproduce/reproduce_paper.R --fast   # about 20 seconds, skips those bootstraps
```

**What the script does:**
- It recomputes the Results of the paper:
  - Table 1 and the rate ratios,
  - the primary model with likelihood-ratio test and profile-likelihood interval,
  - population-averaged shares,
  - the registration patterns,
  - calendar adjustment, within-phase trend, binary models, nominal test and region interaction,
  - all population and rule sensitivity analyses, leave-one-household-out,
  - the inclusion of the households with overwritten records,
  - RQ2 with the dialog breakdown.
- It writes `reproduce/reproduction_report.csv`, one row per quantity, with the reproduced value, the pipeline value and whether they agree.

**Result:** all 142 compared quantities agree.
- Deterministic estimates match the pipeline values to within 1e-5. The phone-charging share is the one exception: it is compared with its rounded value in the paper, 66.1%.
- Household-bootstrap intervals agree only up to Monte Carlo error. Bootstraps resample households in the order of their codes, and the published codes are random, so the resampled sets differ from the original run. The full run gave:

| Interval | Paper (original run) | Published tables |
|---|---|---|
| Primary OR, household bootstrap | [1.28, 2.61] | [1.29, 2.53] |
| Great-share difference (points) | [4.7, 17.5] | [4.5, 17.0] |
| RQ2 waiting proportion | [3.2%, 15.5%] | [3.2%, 15.3%] |

## Privacy

- Participants agreed that their data would be used for anonymised academic analysis.
- **Not published:**
  - the raw database export,
  - login IDs and passcodes,
  - names and contact details,
  - timestamps,
  - household-level demographic answers.
- **Published:** households carry random codes, and time is given only as study day, local hour, local calendar day and weekday.
- Details are in `data/README.md`.

## Deviations and post hoc analyses

- **Analysis plan:** it was written after data collection and after a crude phase-by-window count table had been seen, but before any model was fitted (`materials/statistical_analysis_plan_v1.0.md`).
- **Excluded households:** 21 households are excluded because their stored records were overwritten by a data-processing script after collection. Their inclusion is reported as a sensitivity analysis.
- **Post hoc analyses:** the registration-count decomposition, the registration patterns, the nominal test, the region comparison, the "waits as bad uses" check and the within-phase trend are all post hoc, and the paper labels them as such.

## App

- `app/` holds the source code of EcoTracker, a Next.js web app with a PostgreSQL database accessed through Drizzle.
- It is a snapshot whose files are dated 22 August 2026. The households of the primary sample started between 28 August and 9 September 2026.
- The snapshot has no version history.

Details:
- **Configuration:** the database URL, session secret and researcher passcode are read from environment variables. No credentials are included.
- **Test account:** the seed script creates one test account, which is the only account that sees the debug controls.
- **Participant-facing texts:** they are in `app/messages/`. A readable version is in `materials/`.
- **Implementation of the design:** window schedule in `app/src/lib/schedule.ts`, phase logic in `app/src/lib/phase.ts`, green score in `app/src/lib/green-score.ts`.

## License

- Code (`analysis/`, `reproduce/`, `app/`): MIT, see `LICENSE`.
- Data, results and study materials (`data/`, `results/`, `materials/`): CC BY 4.0, see `LICENSE-DATA`.
