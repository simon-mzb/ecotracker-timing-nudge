# EcoTracker participant-facing texts (English)

Verbatim from the app's message catalogue `messages/en.json` (keys shown in code format). `{appliance}`, `{hours}`, `{hour}` and `{day}` are placeholders filled in by the app. Login and researcher (admin) screens are omitted.

## Screening (before consent)

- `onboarding.screening.title`: Which of these do you have?
- `onboarding.screening.subtitle`: This study focuses on households with at least one major flexible appliance.
- `onboarding.screening.continue`: Continue
- `onboarding.screening.error`: Something went wrong. Please try again.

Response format: multiple selection of the three appliances (dishwasher, washing machine, phone charging). Households selecting neither a dishwasher nor a washing machine were screened out (`src/components/OnboardingFlow.tsx`).

## Screening outcome for households without a dishwasher or washing machine

- `onboarding.ineligible.title`: Thanks for your willingness to participate
- `onboarding.ineligible.body`: Unfortunately, this study isn't a fit for your household — it focuses on households with a dishwasher or washing machine. We really appreciate you taking the time to consider joining.

## Informed consent

- `onboarding.consent.title`: Before you start — what we track
- `onboarding.consent.intro`: This app is part of a university study on household energy use. Here's exactly what we record:
- `onboarding.consent.point1`: Over the next 2 weeks, every time you tap "Start Now" on an appliance, we log which appliance and the timestamp.
- `onboarding.consent.point2`: We may show you additional information or questions in the app as the study progresses — we'll always explain what's new before it appears.
- `onboarding.consent.point4`: Your data is used only for anonymized academic analysis.
- `onboarding.consent.agree`: I understand and agree to participate

## Intake questionnaire

- `onboarding.intake.title`: A few quick questions
- `onboarding.intake.subtitle`: This helps us understand your household. It only takes a minute.
- `onboarding.intake.householdSize`: How many people live in your household?
- `onboarding.intake.dwellingType`: What type of home do you live in?
- `onboarding.intake.dwellingHouse`: House
- `onboarding.intake.dwellingApartment`: Apartment
- `onboarding.intake.dwellingOther`: Other
- `onboarding.intake.ageBracket`: Your age bracket (optional)
- `onboarding.intake.ageBracketSkip`: Prefer not to say
- `onboarding.intake.submit`: Finish setup

Response formats (`src/components/OnboardingFlow.tsx`, `src/app/api/onboarding/intake/route.ts`): household size, integer 1-20 (required); dwelling type, one of house / apartment / other; age bracket, one of 18-24, 25-34, 35-44, 45-54, 55-64, 65+ or prefer not to say (optional).

## Introduction screen at the start of the nudge phase

- `phase2Intro.title`: New in the app: eco-friendly timing tips
- `phase2Intro.body1`: From now on, we'll show you information about when it's a good time — ecologically speaking — to use appliances like your washing machine or dishwasher, based on time of day.
- `phase2Intro.body2`: You're always completely free to decide when to use your appliances. This is just extra information — nothing is required, tracked as a rule, or restricted.
- `phase2Intro.continue`: Got it, continue

## Home screen and registration

- `home.day`: Day {day} of your study
- `home.phase1Title`: Log your appliance usage
- `home.phase2Title`: Your appliances
- `home.startNow`: Start Now
- `home.logged`: Logged!
- `home.tapToConfirm`: Tap again to confirm
- `home.useNow`: Use {appliance}
- `home.confirmTitle`: Not the best time right now
- `home.confirmBodyWithHours`: Waiting about {hours}h could mean more green energy for your {appliance}. Use it now anyway, or wait?
- `home.confirmBodyGeneric`: Waiting a bit could mean more green energy for your {appliance}. Use it now anyway, or wait?
- `home.useAnyway`: Use anyway
- `home.wait`: I'll wait
- `home.praiseAfterAccept`: 🎉 Nice timing — that's a green-energy-friendly choice for your {appliance}.
- `home.ackAfterAcceptOk`: Noted for your {appliance} — a decent time, not the daily peak but reasonable.
- `home.ackAfterAcceptBad`: Noted for your {appliance} — maybe try for a greener window next time.
- `home.ackAfterDeclineWithHours`: We've noted that you would wait for a better time. Please register this device again when you use it in {hours} hours.
- `home.ackAfterDeclineGeneric`: We've noted that you would wait for a better time. Please register this device again once you actually use it.

## Window banners (nudge phase)

- `nudge.great`: ☀️ It's currently in today's great window (10:00-17:00), when solar generation is typically highest. Using {appliance} now is a great time for green energy.
- `nudge.ok`: 🙂 It's currently in an "ok" window — not today's daily peak (10:00-17:00), but still a reasonable time to use {appliance}.
- `nudge.bad`: 🔌 It's currently outside today's daytime windows, when the grid typically relies more on non-renewable sources. Waiting about {hours}h, until the next great window, could mean cleaner electricity for {appliance}.

## Green score

- `greenScore.title`: Green Score

## Background information page ("Why timing matters")

- `info.learnMoreLink`: ℹ️ Why timing matters
- `info.title`: Why timing matters
- `info.body1`: Solar power generation follows the sun: it ramps up in the morning, peaks around midday, and tapers off by evening. Wind and other renewables shift too, but that midday solar peak is the single biggest reason daytime hours carry more green energy on average than nights or early mornings.
- `info.statTitle`: Real German grid data (from this study's motivation)
- `info.statEvening`: Washing machine, 6-7 PM
- `info.statNoon`: Washing machine, 12-1 PM
- `info.statSource`: Source: smard.de — actual renewable share for the same appliance cycle, just run at a different hour.
- `info.body2`: This app's "great" and "ok" windows are a simple daily schedule built on that same midday-peak pattern. Want to see live, real generation and consumption data for Germany yourself? SMARD — the German Federal Network Agency's public market data platform — publishes it openly.
- `info.linkText`: Open SMARD.de →
- `info.back`: ← Back

## Help dialog

- `help.buttonLabel`: Help
- `help.title`: What am I supposed to do?
- `help.phase1Body`: Just tap "Start Now" on an appliance whenever you use it — dishwasher, washing machine, or phone charging. That's it for this stage.
- `help.phase2Body`: We now suggest good times to use your appliances based on time of day (more solar power is typically available during the day). You're always completely free to use your devices whenever works for you — this is just information, nothing is required.
- `help.close`: Got it

## Retrospective ("forgotten") entries

- `backdated.buttonLabel`: Log a forgotten entry
- `backdated.title`: When did you use this?
- `backdated.timeLabel`: Time
- `backdated.submitIdle`: Log it
- `backdated.submitConfirm`: Tap again to confirm
- `backdated.cancel`: Cancel
- `backdated.loggedConfirmation`: Logged!
- `backdated.retrospectiveGreat`: That was during a great window! 🎉
- `backdated.retrospectiveOk`: That was an okay time.
- `backdated.retrospectiveBad`: That was outside the recommended window.
- `backdated.errorFuture`: That time hasn't happened yet.
- `backdated.errorTooOld`: Please pick a time within the last 24 hours.
- `backdated.errorGeneric`: Something went wrong. Please try again.

## Appliance names

- `appliances.dishwasher`: Dishwasher
- `appliances.washing_machine`: Washing Machine
- `appliances.phone_charging`: Phone Charging
- `appliances.generic`: flexible appliances
