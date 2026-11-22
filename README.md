# ACL Recovery Coach

ACL Recovery Coach is a Flutter mobile companion for people recovering after
anterior cruciate ligament (ACL) reconstruction. It helps patients record
their current rehabilitation status, follow a criteria-based exercise plan,
and track progress over time.

> This app supports—but does not replace—the guidance of your surgeon or
> physical therapist.

## Clinical Scope

The app is educational and supportive. It does not diagnose injuries, prescribe
treatment, clear a patient for sport, or replace a clinician's judgment.

Exercise progression considers symptoms, range of motion, walking quality,
weight bearing, documented restrictions, graft considerations, measured
strength and symmetry, landing control, running tolerance, and clinician
clearance. Calendar time is context, not the sole progression rule.

Clinical gates and exercise sequencing are modeled around public ACL
rehabilitation guidance, including:

- [Mass General Brigham ACL reconstruction rehabilitation protocol](https://www.massgeneral.org/assets/mgh/pdf/orthopaedics/sports-medicine/physical-therapy/rehabilitation-protocol-for-acl.pdf)
- [Ohio State ACL reconstruction clinical practice guideline](https://hrs.osu.edu/-/media/files/wexnermedical/patient-care/healthcare-services/sports-medicine/education/medical-professionals/knee-ankle-and-foot/acl_reconstruction.pdf)
- [Aspetar ACLR clinical guideline](https://www.aspetar.com/en/professionals/aspetar-clinical-guidelines/recommendations-on-rehabilitation-after-aclr)
- [University of Delaware ACL rehabilitation guideline](https://bpb-us-w2.wpmucdn.com/sites.udel.edu/dist/c/3448/files/2016/01/UDPT-ACL-Rehab-Guideline-REVISED.pdf)

Protocols vary by surgeon, graft, concomitant procedures, and patient factors.
Surgeon and physical therapist restrictions always take priority.

## Features

### Adaptive cycle

```text
Assessment -> Personalized plan -> Logged sessions -> Reassessment -> Updated plan
```

- **Assessment** covers surgery date, graft, symptoms, range of motion,
  walking, warning signs, confidence, protocol readiness (with "not measured"
  handled explicitly), restrictions, and a training setup: goal, training days,
  session length, and available equipment.
- **Personalized plan.** Answers are analyzed into prioritized focus areas
  (for example "Close the quadriceps gap: 65%, target 80%"). The plan picks
  exercises for the criteria-based phase, the focus areas, the goal, and the
  equipment, then doses them (sets, reps, holds, rest, effort, frequency),
  splits them into Session A/B to fit the session length, and lays out a
  weekly schedule. Every plan explains itself ("Why this plan") and lists what
  is not included yet and why.
- **Plan quality check.** Before a plan is shown, 14 checks verify it against
  the assessment: unlock criteria and restrictions, graft precautions,
  equipment, goal alignment, difficulty, duplicates, coverage of every focus
  area, balance (knee-, hip-dominant, and control work), symptom-appropriate
  progression, session length, realistic weekly load, answer consistency, and
  clinical flags. Problems are repaired automatically (swap, trim, add, or
  reschedule) and the report shows what passed, what was adjusted, and what
  needs review.
- **Feedback-driven dosing.** "Too easy", "Just right", and "Too hard" (plus
  an optional pain rating) move each exercise between dose levels. Two
  "Just right" sessions with low pain progress it; pain of 5/10 or "Too hard"
  steps it back. At the top level, the next plan moves to a harder variation.
- **Reassessment.** The app recommends a retest when progress is meaningful
  (sessions logged, exercises progressed, low pain), when the plan reaches its
  ceiling, on schedule, or urgently when symptoms rise. The retest compares
  new and previous results, shows improvements, declines, remaining
  weaknesses, and exactly how the plan changed.
- **Quick check-ins** log symptoms or measurements between reassessments and
  rebuild the plan only when something changes.

### Exercises and alternatives

- 76 exercises across five phases, each tagged with a training purpose (for
  example knee extension range, quadriceps strength, core stability, landing
  mechanics) and the equipment it needs beyond household basics. They include
  machine leg extensions (90-45 degrees first, full range from about week 12,
  both blocked by a "No Open Chain Extension" restriction), hip thrusts,
  Nordic hamstring curls, barbell squats and trap bar deadlifts, core work,
  low box jumps, and late-stage agility and deceleration drills.
- Alternatives always share the exercise's purpose, stay within the current
  phase and unlock criteria, and are labeled easier, similar, or harder, with
  the reason they fit and what blocks unavailable options. They can be used for
  one workout or saved to the plan.

### Progress tracking

- Workouts log every set: reps and weight for strength exercises (in kg or
  lb, set on the About tab), reps for control drills, and seconds or minutes
  for holds and continuous work. Fields are pre-filled from the last session,
  and the app suggests adding weight once every set reaches the top of the
  rep range. Per-exercise feedback, pain after, effort, and notes are
  recorded too.
- The Progress tab summarizes 7-day, 30-day, 90-day, or all-time periods:
  consistency against the plan, streaks, average pain and effort, set
  completion, volume lifted, weekly sessions, pain and effort trends,
  exercise feedback mix, the heaviest weight per session for each exercise,
  strength, balance, and hop symmetry over time, assessment history with
  comparisons, and plain-language insights ("You are improving").

### Also

- Clinical disclaimer, phase blockers, graft education, light/dark mode,
  Android dynamic color, responsive layouts (bottom navigation on phones,
  navigation rail on wide screens), and data migration from earlier versions.

## Technology

| Area | Implementation |
| --- | --- |
| Framework | Flutter and Dart |
| Design | Material 3, adaptive layouts, light/dark mode, Dynamic Color |
| State management | Riverpod |
| Navigation | GoRouter |
| Durable local data | Hive (`Hive Flutter`) |
| Lightweight settings | Shared Preferences |
| Quality checks | `flutter_lints`, Flutter unit and widget tests |

## Architecture

The project follows a layered, feature-oriented structure. Presentation code
does not directly own persistence, and phase/exercise rules remain in domain
models and utilities.

```text
lib/
  core/
    constants/       Shared layout and application constants
    navigation/      GoRouter setup
    theme/           Material 3 themes and color system
    utils/           Criteria-based phase evaluation
  data/
    repositories/    Hive and Shared Preferences persistence
    exercise_catalog.dart
  domain/
    models/          Assessment, training profile, plan, workout, history,
                     milestone, exercise, and app state models
    services/        Plan generator and validator, focus analysis, progress
                     analytics, reassessment advisor, comparisons, alternatives
  presentation/
    providers/       Riverpod controller and dependency injection
    screens/         Assessment, today, plan, workout, progress, results, about
    widgets/         Charts, forms, exercise sheets, and shared components
```

## Getting Started

### Prerequisites

- Flutter SDK compatible with the Dart constraint in `pubspec.yaml`
- An Android emulator/device, iOS simulator/device, desktop target, or browser
  configured for Flutter development

### Run locally

```bash
flutter pub get
flutter run
```

To target a specific device, first list available devices:

```bash
flutter devices
flutter run -d <device-id>
```

## Quality Checks

Run static analysis and the test suite before merging changes:

```bash
flutter analyze
flutter test
```

The tests cover phase assignment, assessment revisions, plan personalization
(equipment, goals, deficits, symptoms, restrictions, graft precautions),
plan validation and repair, progression rules, reassessment triggers,
comparisons, progress analytics, exercise alternatives, catalog integrity,
data migration, and a full widget-driven flow from assessment through
workout, progress, and reassessment.

## Data and Privacy

The app currently stores its state on-device only:

- Hive stores the serialized application state: assessment history, plan
  versions, workouts, check-ins, session feedback, and exercise progression.
- Shared Preferences stores lightweight settings such as theme mode and the
  selected navigation tab.

No authentication, cloud sync, analytics, wearable connection, or remote data
transfer is implemented in the current version. Removing the app or clearing
app storage may remove locally stored rehabilitation data.

## Rehabilitation Workflow

1. Complete the assessment using current and clinician-confirmed information,
   including your goal, schedule, and equipment.
2. Review your plan: phase, focus areas, the reasoning, and the quality check.
3. Train with the Workout tab. Mark sets, rate each exercise, and finish the
   workout with pain and effort so doses can adapt.
4. Follow your progress on the Progress tab.
5. Reassess when the app suggests it (typically every 2-4 weeks, sooner when
   you improve or symptoms rise). Review the comparison and your updated plan.
6. Use "Correct Initial Assessment" (About tab) only to fix surgery details,
   graft type, or restrictions that were entered wrongly.

Never perform a new hop, jump, landing, or running test solely to fill out the
app. Use results supplied or approved by your rehabilitation team.

## Future Integrations

The layers are intentionally separated so the app can later add authentication,
cloud synchronization, therapist portals, notifications, wearable data, Apple
Health/Google Fit, multilingual content, PDF reports, and telehealth without
rewriting the clinical workflow.
