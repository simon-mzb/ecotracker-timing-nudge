# SusAI Statistical Analysis Plan

Version: 1.0  
Date: 2026-09-24  
Status: locked before descriptive phase-by-outcome tables and before any confirmatory outcome model was fitted. Later deviations must be dated in `_project/DECISIONS.md` and reported.

## 1. Purpose

This plan defines the analysis before the primary phase comparison is estimated. It separates what the application recorded from simulated environmental potential and from claims in earlier paper drafts. The six-page paper will contain a concise version; this plan, the R code, exclusion audit, and decision log provide the complete record.

## 2. Implemented design

The study is a single-sequence, within-household before-and-after study.

- Baseline condition: first seven days after first login.
- Nudge condition: following seven days.
- Intended observation window: 14 days per household.
- Condition order: baseline first, nudge second for every household.
- Random assignment: none.
- Intervention: fixed time-window information, confirmation friction in bad windows, and green-score feedback.
- Time windows: fixed clock-based categories, not live grid-carbon data.
- Usage measurement: participant registration in the app, not physical device telemetry.
- Recording mechanics differ by phase: Phase-1 feedback resets after two seconds, whereas a Phase-2 response replaces the appliance card until page reload or remount. This can affect registration independently of physical behaviour.

The application does not stop accepting records after day 14. The analysis therefore imposes the intended 14-day window explicitly.

## 3. Research questions

### Primary

Among eligible households contributing registered appliance-use events in both phases, are registered uses more likely to fall in a more favourable fixed time window during the nudge phase than during baseline?

### Secondary

1. In bad-window intervention encounters, how often do participants select “I'll wait” rather than “Use anyway”?
2. Is the stated wait decision associated with suggested waiting time or appliance type?
3. Does the phase difference vary descriptively or exploratorily by appliance?
4. How sensitive is the primary conclusion to outcome dichotomisation, backdated registrations, sample restrictions, and influential households?

### Environmental potential

What energy or emissions shift might be possible under explicit external assumptions? This is a separate simulation and is not an observed outcome.

## 4. Primary estimand and language

The primary estimand is the event-weighted, household-conditional phase association in the odds of a registered use being in a higher ordered window category during the nudge phase versus baseline, adjusted for appliance type and household-level clustering.

More active households contribute more event-level information. The estimand is not an equal-household average, a direct measure of use frequency, verified rescheduling, an energy-weighted effect, verified physical use, or measured electricity/emissions.

Supported wording:

> Registered uses were more or less likely to occur in favourable windows during the nudge phase than during baseline.

If supported, it is acceptable to add:

> The observed phase difference is consistent with the intended effect of the nudge package.

Do not claim that the study isolates a causal nudge effect. Phase is perfectly ordered in time, no concurrent or randomised control condition exists, and the intervention combines several components.

## 5. Units and variables

### Observation unit

One row in the primary analytical table represents one registered appliance-use event.

### Clustering unit

Repeated events are clustered within household. Household is represented by a random intercept in the primary model.

### Primary outcome Y

`window_ordered`, with levels `bad < ok < great`. This is an ordinal outcome. Equal numerical distances between categories are not assumed.

### Main explanatory variable X

`phase`, coded `baseline = 0` and `nudge = 1`.

### Prespecified covariate

`appliance`, with levels `dishwasher`, `washing_machine`, and `phone_charging`.

All three implemented appliances remain in the primary analysis. A high-load sensitivity analysis excludes phone charging. Removing phone charging only after seeing its result would be an outcome-dependent decision.

### Grouping variable

`household_id`, used internally only. It must not appear in public outputs.

## 6. Source-event reconstruction

### Baseline registered uses

Valid baseline uses arise from `usage_logs` as immediate or backdated registrations.

### Nudge-phase registered uses

Valid nudge-phase uses arise from:

- `nudge_responses.response == "accept"`, representing immediate use or “Use anyway”; or
- a valid backdated record in `usage_logs`.

### Non-use decisions

`nudge_responses.response == "decline"` represents a stated decision not to use immediately. It is not a registered-use event and is not placed in the primary outcome table.

No identifier links a decline decision to a later use. Later use after waiting cannot be verified at the individual-event level.

### Event time

- Immediate use or nudge response: event time is `created_at`.
- Backdated registered use: reported use time is `started_at`.
- `created_at` remains available to verify that registration occurred inside the intended study window and technical lookback allowance.

Both reported use time and registration time must fall inside the intended observation window for the primary analysis. Boundary cases remain in an audit table and are assessed in sensitivity analyses.

The API allows backdating by at most 24 hours and tolerates a reported time up to two minutes in the future. Missing timestamps and larger discrepancies are excluded. Four valid records cross the baseline-to-nudge boundary between `started_at` and `created_at`. The primary reconstruction assigns these records by `started_at`, representing reported use time. Prespecified sensitivities (a) exclude all four and (b) assign backdated records by registration time.

### Stored window classifications

The primary outcome uses the stored `window` or `window_at_use` label. The API generated this label from a browser-supplied local hour, but the database does not retain that hour or the participant timezone. UTC timestamps cannot independently reconstruct every participant's local classification. Validation may flag plausible inconsistencies under documented timezone assumptions but must not silently overwrite stored labels.

## 7. Time origin, phase, and cutoff

The time origin is `households.first_login_at`.

- Baseline: `0 <= event time - first login < 168 hours`.
- Nudge: `168 <= event time - first login < 336 hours`.
- Outside study: event time before first login or at/after 336 hours.

The 336-hour upper bound is exclusive. The authoritative original database files were recovered on 2026-09-24. Per the team's clarified rule, analysis uses the complete recovered export through its completion at 2026-09-24 02:08:50 Europe/Berlin (`00:08:50 UTC`) and restricts every household independently to its first 336 hours. This retains later source rows only when they fall inside that household's intended two-week period. At the snapshot cutoff, 84 of 87 eligible households had a fully elapsed 336-hour opportunity and three were administratively incomplete. Administratively incomplete households are excluded from the primary paired-contributor population and retained in a clearly labelled sensitivity population observed only up to the snapshot.

Seven eligible nudge-response records in the cutoff-defined original data occur before the 168-hour boundary even though the current code would reject them. The original timestamps confirm that these are genuine records rather than rounding artifacts. The strict protocol boundary remains primary, so the six early accepts do not enter the primary event table and the seven responses do not enter the main decision denominator. The prespecified exposure-marker sensitivity defines Phase 2 from the earliest recorded Phase-2 introduction or nudge response per household, because a nudge response itself proves exposure and two strict-window responses precede the stored introduction timestamp.

Four eligible non-test `decline` responses occur in `ok` or `great` although the current interface exposes the decline choice only in `bad`. These records require the same deployment-history review and are excluded from the bad-window decision model unless an earlier interface version justifies a different interpretation.

## 8. Analysis populations

### Eligibility population

Households must:

- not be marked as test accounts;
- have recorded consent;
- not be marked ineligible; and
- have a non-missing first-login timestamp.

Known replacement accounts must be resolved before analysis so one real household is not represented twice.

### Primary paired-contributor population

Eligible households with:

- a fully elapsed 14-day opportunity by final export; and
- at least one valid registered-use event in each phase.

This targets households that continued contributing into both phases, but it conditions on post-baseline engagement and is not representative of all recruited households. A random intercept does not by itself make the coefficient a purely within-household estimator when event counts differ. The plan therefore includes an all-eligible-events sensitivity and a household-stratified binary sensitivity.

No minimum number of daily entries is imposed. A day without an event cannot be distinguished as no appliance use, forgotten registration, or disengagement.

### Sensitivity populations

1. All eligible households contributing at least one valid event in either phase.
2. An observed-exposure reconstruction in which the earliest recorded Phase-2 introduction or nudge response marks the start of Phase 2; source type must remain compatible with the resulting phase.
3. High-load appliances only: dishwasher and washing machine.
4. Immediate registrations only, excluding backdated uses.
5. All eligible households observed up to the administrative cutoff, including the three with less than 336 hours of opportunity; this analysis is explicitly treated as unequally followed and sensitivity-only.

## 9. Data quality and exclusions

Exclusions are rule-based and never selected because they improve the result.

### Prespecified exclusions

- test account;
- no consent;
- explicitly ineligible account;
- missing first-login timestamp;
- event before first login;
- event or registration at/after 336 hours;
- invalid foreign key or duplicate primary identifier;
- value outside implemented appliance, response, or window categories;
- confirmed technical duplicate representing the same user action.

### Locked duplicate rule

Keep the earliest row and exclude a later row when either of the following holds:

1. same household, appliance, source type, and stored window, with no more than five seconds between consecutive plausible records; for decision rows, response must also match; or
2. an immediate record and a subsequently registered backdated record have the same household, appliance, and stored window and their reported event times are no more than five minutes apart; retain the immediate row and exclude the backdated row.

The first rule identified 27 registered-use targets and 17 decision targets. The second identified eight unique backdated targets from ten matching pairs. The event rules target 35 unique rows in total. A retain-all duplicate sensitivity is mandatory. Broader two-minute or two-hour screens remain review flags and are not exclusions.

### Review flags, not automatic exclusions

- nudge response before 168 hours (excluded under the strict source/phase rule but retained for the exposure-marker sensitivity);
- possible immediate/backdated double registration outside the locked narrow rule;
- activity after a replacement account was issued;
- non-bad-window `decline` response;
- backdated record crossing the phase boundary;
- highly active household.

### IQR rule

The 1.5-IQR rule will not delete records automatically. The primary outcome and phase are categorical, and high event counts may represent real engagement. Event-count distributions and household influence will be inspected. Influential-household restrictions are sensitivity analyses, not primary cleaning.

Every excluded source row must appear in an exclusion audit with source table, source identifier, rule code, and human-readable reason.

## 9a. Planning history

This is a retrospective analysis plan prepared after data collection began and after an initial uncleaned aggregate phase-by-window cross-tab was inspected. It is not a prospective preregistration. The primary ordinal outcome and mixed-model architecture are justified by the implemented interface, schema, and course lecture rather than selected through formal model-result comparison. All later changes must be logged.

## 10. Descriptive analysis

Before inferential models, report:

- participant flow from issued accounts to eligible and analysed households;
- event counts by phase, appliance, source type, and window;
- households and events contributing to each phase;
- event-count distribution per household;
- immediate versus backdated registrations;
- study-day and calendar-date coverage;
- phase-2 introduction timing;
- stated wait/use-anyway decisions in bad windows;
- missingness and protocol deviations.

Plots must display household-level variation where practical and must not treat event rows as independent participants.

## 11. Primary model

Fit a cumulative-link mixed model with a logit link:

```r
ordinal::clmm(
  window_ordered ~ phase + appliance + (1 | household_id),
  data = primary_events,
  link = "logit",
  Hess = TRUE,
  nAGQ = 7
)
```

The primary phase test is a likelihood-ratio comparison with the otherwise identical model omitting phase. Report the phase coefficient, conditional common odds ratio, profile-likelihood 95% confidence interval where computationally available, category thresholds, random-intercept variance, and convergence information. A Wald interval is reported only if profiling fails and is labelled accordingly.

Numerical acceptance requires no convergence warning, finite coefficients and standard errors, and a positive-definite Hessian. Compare `nAGQ = 7` with the Laplace approximation `nAGQ = 1`; an absolute phase-coefficient difference greater than 0.10, a relative standard-error difference greater than 10%, or a sign change triggers further numerical investigation.

Model-based probabilities for `bad`, `ok`, and `great` are calculated for both phases using the same pooled appliance distribution and a household random intercept of zero. These are conditional predictions for a typical modelled household, not population-marginal probabilities. They carry the main substantive interpretation because they are easier to understand than conditional odds ratios.

### Proportional-odds check

Compare the phase pattern across two prespecified binary splits:

- `great` versus `ok/bad`;
- `great/ok` versus `bad`.

The CLMM remains the one planned primary model. Both threshold-specific binary estimates are always reported as sensitivity results. Same-sign coefficients do not prove proportional odds, and different p-values do not refute it. Inspect phase and appliance patterns across both thresholds. If the common-odds representation is clearly inadequate, qualify the primary common odds ratio and emphasise threshold-specific associations without promoting a new confirmatory result after inspection.

If the CLMM cannot be estimated despite documented numerical checks, the fixed computational fallback is a binary logistic mixed model for `great` versus `ok/bad`, selected because only `great` is actively rewarded. Computational failure and use of the fallback are reported as a deviation.

## 12. Secondary models

### Binary registered-use models

Fit logistic random-intercept models for both binary splits, for example:

```r
lme4::glmer(
  is_great ~ phase + appliance + (1 | household_id),
  family = binomial,
  data = primary_events
)
```

### Bad-window decisions

The main secondary output is the event-weighted proportion selecting “I'll wait” among duplicate-cleaned bad-window decisions from all eligible households in the strict nudge window, with uncertainty obtained by resampling households. A primary-population-only estimate and an equal-household descriptive average are sensitivities. The denominator does not include passive nudge views, abandoned dialogs, unrecorded impressions, early responses, or non-bad-window declines.

An adjusted model is exploratory:

Among bad-window nudge encounters only:

```r
lme4::glmer(
  wait ~ suggested_wait_hours + appliance + (1 | household_id),
  family = binomial,
  data = bad_window_decisions
)
```

`wait = 1` corresponds to database `decline`; `wait = 0` corresponds to database `accept`. This model concerns stated immediate decisions, not verified later use. `suggested_wait_hours` is a deterministic function of clock time under the fixed schedule, so its coefficient cannot distinguish delay aversion from time-of-day routines and is interpreted only as an association.

If decisions or contributing households are too sparse, report descriptive proportions and appropriate uncertainty instead of forcing an unstable multivariable model.

### Appliance heterogeneity

The `phase * appliance` interaction is secondary and exploratory unless confirmed as a prespecified hypothesis before the primary model is run. Report appliance-specific confidence intervals and acknowledge lower precision.

## 13. Sensitivity analyses

1. Paired-contributor population versus all eligible events.
2. Ordinal model versus both binary outcome splits.
3. All appliances versus high-load appliances only.
4. All valid registrations versus immediate registrations only.
5. Alternative treatment of backdated phase-boundary records.
6. Strict 168-hour boundary versus an implementation-informed rule for early nudge records.
7. Weekday and parsimonious calendar-time adjustment if staggered starts provide overlap.
8. Leave-one-household-out estimates or equivalent household-influence analysis.
9. Random phase slope by household only if estimable and convergent.
10. Household-stratified conditional logistic models for each binary threshold to isolate within-household phase contrasts among informative households.
11. Household-weighted descriptive category proportions so highly active households do not determine the descriptive contrast by event count alone.
12. Retaining all rows flagged by the locked duplicate rule.

Judge sensitivity by direction, magnitude, and uncertainty, not only whether a p-value crosses 0.05.

## 14. Missingness and incomplete contribution

Mixed models can use unequal numbers of observed events. They do not solve informative missingness.

- Do not impute unregistered appliance uses.
- Do not treat a no-entry day as zero use.
- Do not automatically remove a household because it stopped entering events.
- Report phase-specific disengagement and contribution patterns.
- Compare the primary paired analysis with the broader eligible-event analysis.

Interpretation is conditional on registered events and participating households. It does not estimate all physical appliance uses.

## 15. Multiplicity and reporting

- Designate one primary phase coefficient in advance.
- Use two-sided 95% confidence intervals.
- Use `alpha = 0.05` for the primary test if a threshold is required.
- Label secondary and exploratory analyses.
- Do not present unplanned p-values as independent confirmatory tests.
- Report effect sizes and uncertainty regardless of significance.

## 16. Power and precision

The existing Monte Carlo notebook simulates continuous `GreenEnergyPct`, which was not measured. Its reported 80% power at 40 households does not establish power for the ordinal primary outcome.

Because data collection has occurred, observed post-hoc power will not interpret the result. Emphasise estimates and confidence intervals. If the course requires a design-stage power statement, describe the notebook as a prior planning exercise with its assumptions or replace it with an ordinal simulation clearly separated from the observed result.

## 17. Environmental simulation

Any energy or emissions estimate is separate from behavioural analysis. State appliance energy per use, counterfactual timing, grid-intensity source, and mapping from fixed windows to energy conditions. Label results as simulated potential, not observed savings.

## 18. Reproducibility

- Archive raw exports in dated directories with SHA-256 checksums.
- Create all derived data, tables, figures, and model results with R scripts.
- Allow no manual spreadsheet edits in the analytical pipeline.
- Record random seeds for simulations.
- Record R and package versions with `sessionInfo()` and a lockfile.
- Render the final report from source.
- Date and explain every deviation from this plan in the decision log.

## 19. Reporting location

### Methods

Report design, sample rules, event reconstruction, outcomes, predictors, cutoffs, missing-data handling, models, software, and sensitivity strategy.

### Results

Report participant flow, actual exclusions by reason, descriptive data, model estimates, confidence intervals, diagnostics, and sensitivity results.

### Local audit documentation

Retain the full data dictionary, source-to-derived mapping, exclusion audit, decision log, diagnostics, and session information even when they do not fit in the short paper.
