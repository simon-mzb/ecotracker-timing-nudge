# EcoTracker participant-facing texts (German)

Verbatim from the app's message catalogue `messages/de.json` (keys shown in code format). `{appliance}`, `{hours}`, `{hour}` and `{day}` are placeholders filled in by the app. Login and researcher (admin) screens are omitted.

## Screening (before consent)

- `onboarding.screening.title`: Welche dieser Geräte hast du?
- `onboarding.screening.subtitle`: Diese Studie richtet sich an Haushalte mit mindestens einem großen flexiblen Gerät.
- `onboarding.screening.continue`: Weiter
- `onboarding.screening.error`: Etwas ist schiefgelaufen. Bitte versuche es erneut.

Response format: multiple selection of the three appliances (dishwasher, washing machine, phone charging). Households selecting neither a dishwasher nor a washing machine were screened out (`src/components/OnboardingFlow.tsx`).

## Screening outcome for households without a dishwasher or washing machine

- `onboarding.ineligible.title`: Danke für deine Bereitschaft teilzunehmen
- `onboarding.ineligible.body`: Leider passt diese Studie nicht zu deinem Haushalt — sie richtet sich an Haushalte mit Geschirrspüler oder Waschmaschine. Wir schätzen es sehr, dass du dir die Zeit genommen hast, eine Teilnahme in Betracht zu ziehen.

## Informed consent

- `onboarding.consent.title`: Bevor es losgeht — was wir erfassen
- `onboarding.consent.intro`: Diese App ist Teil einer Universitätsstudie zum Energieverbrauch von Haushalten. Das erfassen wir genau:
- `onboarding.consent.point1`: In den nächsten 2 Wochen speichern wir jedes Mal, wenn du bei einem Gerät auf "Jetzt starten" tippst, welches Gerät und den Zeitpunkt.
- `onboarding.consent.point2`: Im Laufe der Studie zeigen wir dir eventuell zusätzliche Informationen oder Fragen in der App — wir erklären dir immer vorher, was neu ist.
- `onboarding.consent.point4`: Deine Daten werden ausschließlich anonymisiert für die akademische Auswertung genutzt.
- `onboarding.consent.agree`: Ich habe verstanden und stimme der Teilnahme zu

## Intake questionnaire

- `onboarding.intake.title`: Ein paar kurze Fragen
- `onboarding.intake.subtitle`: Das hilft uns, deinen Haushalt besser zu verstehen. Dauert nur eine Minute.
- `onboarding.intake.householdSize`: Wie viele Personen leben in deinem Haushalt?
- `onboarding.intake.dwellingType`: In welcher Art von Wohnung lebst du?
- `onboarding.intake.dwellingHouse`: Haus
- `onboarding.intake.dwellingApartment`: Wohnung
- `onboarding.intake.dwellingOther`: Andere
- `onboarding.intake.ageBracket`: Deine Altersgruppe (optional)
- `onboarding.intake.ageBracketSkip`: Keine Angabe
- `onboarding.intake.submit`: Einrichtung abschließen

Response formats (`src/components/OnboardingFlow.tsx`, `src/app/api/onboarding/intake/route.ts`): household size, integer 1-20 (required); dwelling type, one of house / apartment / other; age bracket, one of 18-24, 25-34, 35-44, 45-54, 55-64, 65+ or prefer not to say (optional).

## Introduction screen at the start of the nudge phase

- `phase2Intro.title`: Neu in der App: Öko-Zeitpunkt-Tipps
- `phase2Intro.body1`: Ab jetzt zeigen wir dir Informationen dazu, wann es — ökologisch betrachtet — ein guter Zeitpunkt ist, Geräte wie deine Waschmaschine oder deinen Geschirrspüler zu nutzen, basierend auf der Tageszeit.
- `phase2Intro.body2`: Du entscheidest weiterhin völlig frei, wann du deine Geräte nutzt. Das sind nur zusätzliche Informationen — nichts ist verpflichtend oder eingeschränkt.
- `phase2Intro.continue`: Verstanden, weiter

## Home screen and registration

- `home.day`: Tag {day} deiner Studie
- `home.phase1Title`: Erfasse deine Gerätenutzung
- `home.phase2Title`: Deine Geräte
- `home.startNow`: Jetzt starten
- `home.logged`: Erfasst!
- `home.tapToConfirm`: Nochmal tippen zum Bestätigen
- `home.useNow`: {appliance} nutzen
- `home.confirmTitle`: Gerade nicht der beste Zeitpunkt
- `home.confirmBodyWithHours`: Etwa {hours}h zu warten könnte mehr Ökostrom für {appliance} bedeuten. Trotzdem jetzt nutzen oder warten?
- `home.confirmBodyGeneric`: Etwas zu warten könnte mehr Ökostrom für {appliance} bedeuten. Trotzdem jetzt nutzen oder warten?
- `home.useAnyway`: Trotzdem nutzen
- `home.wait`: Ich warte
- `home.praiseAfterAccept`: 🎉 Guter Zeitpunkt — das ist eine ökostromfreundliche Wahl für {appliance}.
- `home.ackAfterAcceptOk`: Notiert für {appliance} — ein akzeptabler Zeitpunkt, nicht die Tagesspitze, aber in Ordnung.
- `home.ackAfterAcceptBad`: Notiert für {appliance} — versuch es beim nächsten Mal vielleicht zu einem grüneren Zeitpunkt.
- `home.ackAfterDeclineWithHours`: Wir haben notiert, dass du auf einen besseren Zeitpunkt wartest. Bitte erfasse dieses Gerät erneut, wenn du es in {hours} Stunden nutzt.
- `home.ackAfterDeclineGeneric`: Wir haben notiert, dass du auf einen besseren Zeitpunkt wartest. Bitte erfasse dieses Gerät erneut, sobald du es tatsächlich nutzt.

## Window banners (nudge phase)

- `nudge.great`: ☀️ Gerade läuft das heutige super Zeitfenster (10:00-17:00 Uhr), wenn die Solarerzeugung normalerweise am höchsten ist. {appliance} jetzt zu nutzen ist eine super Zeit für Ökostrom.
- `nudge.ok`: 🙂 Gerade läuft ein "okay"-Zeitfenster — nicht die heutige Tagesspitze (10:00-17:00 Uhr), aber trotzdem ein akzeptabler Zeitpunkt für {appliance}.
- `nudge.bad`: 🔌 Gerade liegst du außerhalb der heutigen Tageszeitfenster, wenn das Netz normalerweise stärker auf nicht erneuerbare Quellen setzt. Etwa {hours}h bis zum nächsten super Zeitfenster zu warten könnte sauberere Elektrizität für {appliance} bedeuten.

## Green score

- `greenScore.title`: Öko-Punktestand

## Background information page ("Why timing matters")

- `info.learnMoreLink`: ℹ️ Warum der Zeitpunkt zählt
- `info.title`: Warum der Zeitpunkt zählt
- `info.body1`: Solarstromerzeugung folgt der Sonne: Sie steigt morgens an, erreicht mittags ihren Höhepunkt und lässt zum Abend hin nach. Wind und andere erneuerbare Quellen schwanken ebenfalls, aber dieser mittägliche Solar-Höhepunkt ist der Hauptgrund, warum Tagesstunden im Schnitt mehr Ökostrom liefern als Nächte oder frühe Morgenstunden.
- `info.statTitle`: Echte deutsche Netzdaten (aus der Motivation dieser Studie)
- `info.statEvening`: Waschmaschine, 18-19 Uhr
- `info.statNoon`: Waschmaschine, 12-13 Uhr
- `info.statSource`: Quelle: smard.de — tatsächlicher Ökostrom-Anteil für denselben Waschzyklus, nur zu einer anderen Uhrzeit gestartet.
- `info.body2`: Die "super"- und "okay"-Zeitfenster dieser App sind ein einfacher täglicher Zeitplan, der auf demselben Mittagshoch basiert. Möchtest du selbst echte, aktuelle Erzeugungs- und Verbrauchsdaten für Deutschland sehen? SMARD — die öffentliche Marktdatenplattform der Bundesnetzagentur — veröffentlicht sie offen.
- `info.linkText`: SMARD.de öffnen →
- `info.back`: ← Zurück

## Help dialog

- `help.buttonLabel`: Hilfe
- `help.title`: Was soll ich tun?
- `help.phase1Body`: Tippe einfach auf "Jetzt starten" bei einem Gerät, wann immer du es nutzt — Geschirrspüler, Waschmaschine oder Handy laden. Das ist alles in dieser Phase.
- `help.phase2Body`: Wir schlagen jetzt gute Zeitpunkte für deine Geräte vor, basierend auf der Tageszeit (tagsüber ist normalerweise mehr Solarstrom verfügbar). Du kannst deine Geräte weiterhin völlig frei nutzen, wann immer es dir passt — das sind nur Informationen, nichts ist verpflichtend.
- `help.close`: Verstanden

## Retrospective ("forgotten") entries

- `backdated.buttonLabel`: Vergessenen Eintrag erfassen
- `backdated.title`: Wann hast du das genutzt?
- `backdated.timeLabel`: Zeitpunkt
- `backdated.submitIdle`: Erfassen
- `backdated.submitConfirm`: Nochmal tippen zum Bestätigen
- `backdated.cancel`: Abbrechen
- `backdated.loggedConfirmation`: Erfasst!
- `backdated.retrospectiveGreat`: Das war während eines super Zeitfensters! 🎉
- `backdated.retrospectiveOk`: Das war ein akzeptabler Zeitpunkt.
- `backdated.retrospectiveBad`: Das lag außerhalb des empfohlenen Zeitfensters.
- `backdated.errorFuture`: Dieser Zeitpunkt liegt noch in der Zukunft.
- `backdated.errorTooOld`: Bitte wähle einen Zeitpunkt innerhalb der letzten 24 Stunden.
- `backdated.errorGeneric`: Etwas ist schiefgelaufen. Bitte versuche es erneut.

## Appliance names

- `appliances.dishwasher`: Geschirrspüler
- `appliances.washing_machine`: Waschmaschine
- `appliances.phone_charging`: Handy laden
- `appliances.generic`: flexible Geräte
