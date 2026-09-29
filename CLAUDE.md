# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

ACL Recovery Coach: a Flutter app (Riverpod, GoRouter, Hive) for patients after
ACL reconstruction. It is educational; surgeon/PT restrictions always override
it. All data is local to the device.

## Commands

```bash
flutter pub get
flutter analyze                     # must report "No issues found!"
dart format lib test                # run before analyze/commit
flutter test                        # full suite
flutter test test/plan_generator_test.dart                     # one file
flutter test test/app_flow_test.dart --plain-name "migrated"   # one test by name
flutter build web --release --no-wasm-dry-run                  # release build check
flutter run -d chrome               # or any device from `flutter devices`
```

The development machine is Windows. Run Flutter from PowerShell or Bash. For
multi-line git commit messages, write the message to a file and use
`git commit -F <file>`. A PowerShell here-string containing double quotes
breaks argument passing.

## Architecture: the adaptive cycle

The core feature is a loop that spans the whole codebase:

```text
Assessment -> RehabPlan (generated + validated) -> WorkoutLogs/feedback
           -> ReassessmentAdvisor -> new Assessment -> new RehabPlan (diffed)
```

- **Inputs** (`lib/domain/models/`): `Assessment` (clinical answers,
  `ProtocolReadiness`, `confidence`, and `TrainingProfile` with goal,
  sessions/week, minutes, and `EquipmentType`s) plus optional
  `MilestoneCheckIn`s (quick check-ins between reassessments).
- **Current status** (`domain/services/rehab_status.dart`): `RehabStatus.from`
  merges the assessment with the latest check-in (check-in values win) and
  treats measured scores of 0 as "not measured" (`null`). Use it instead of
  re-deriving `milestone?.x ?? protocol.y`. The phase itself comes from
  `evaluateRehabPhase` in `core/utils/phase_logic.dart`, and per-exercise
  unlock rules from `ExerciseCriteria.unmetReasons` in `models/exercise.dart`.
- **Plan generation** (`domain/services/plan_generator.dart`):
  1. `FocusAnalyzer` turns status into prioritized `FocusArea`s.
  2. Per-phase `_blueprints` map each `TrainingPurpose` to a priority. Goal and
     focus areas boost or remove slots.
  3. `PlanContext.select` fills each slot: the exercise must be unlocked,
     within the current phase or earlier, and match the goal. It keeps
     continuity with the previous plan, steps harder or easier when the
     progression level is at max or min, and prefers easier variants when
     symptoms or confidence are low. Missing equipment produces a same-purpose
     substitute (`substitutedFromId`).
  4. Exercises are dosed (`prescribe`) and split into Session A/B.
  5. The draft goes through `PlanValidator.validateAndRepair`: 14 checks that
     repair the draft (swap, remove, add, trim, reschedule) and produce a
     `PlanValidationReport`. The loop runs until no check reports "adjusted".
     Checks must be idempotent across passes (see the weekly-load cap).
  6. Rationale notes are built last from the validated plan.
- **Progression** (`models/session_log.dart`): `ExerciseProgressionState.record`
  holds the feedback rules (dose levels -2..+3). `PlanExercise.doseFor`
  applies level changes made since the plan was created. A `paused`
  prescription never steps up.
- **Re-testing** (`domain/services/`): `ReassessmentAdvisor` (improvement,
  ceiling, scheduled, or urgent symptoms, with snooze), `AssessmentComparison`
  and `PlanDiff` (before/after results screen), and `ProgressAnalytics`
  (period stats, adherence, streaks, trend series, insights).
- **Alternatives** (`domain/services/exercise_alternatives.dart`): candidates
  must share the exercise's `TrainingPurpose` (`related` purposes are only a
  fallback) and never exceed the current phase. Tests enforce that every
  `alternativeExerciseIds` entry shares or relates to the purpose. When the
  generator needs a substitute for missing equipment, it tries the ideal
  exercise's `alternativeExerciseIds` first, in listed order.
- **Set logging** (`domain/services/set_logging.dart`): `setMeasureFor`
  decides whether a set records reps plus weight (loadable strength
  purposes), reps only, seconds, or minutes (derived from the prescription's
  reps and hold text). `WorkoutExerciseEntry.sets` holds `SetLog`s.
  Weight is always stored in kilograms; `AppState.weightUnit` only affects
  input and display (`WeightUnit.format`, `toKg`). `AppState.lastSetsFor`
  pre-fills the next workout and drives `loadSuggestion`.

### Exercise catalog

`lib/data/exercise_catalog.dart` is a single static list. Each `_exercise`
declares `purpose`, `equipmentNeeded` (anything beyond household basics),
criteria, phase, and difficulty. Catalog order matters. Within a phase, the
first exercise for a purpose is the default pick, and later entries at the same
difficulty count as later progressions. `ExerciseCatalog.sessionFor` and
`alternativesFor` are legacy helpers kept for their tests. The app uses
`PlanGenerator` and `AlternativeFinder`.

### State, persistence, navigation

- `AppController` (`presentation/providers/app_state_provider.dart`) is the
  only writer. Every action builds a new `AppState` and calls `_save`, which
  rethrows storage errors so screens can call `showSaveError`.
- The whole `AppState` is one JSON string in the Hive box
  `acl_rehab_state_box` under key `app_state_v2`. Theme and selected tab are
  mirrored in SharedPreferences. `fromJson` methods must stay
  backward-compatible: new fields need defaults.
  `AppController._ensureDerivedState` migrates older saves by adding an
  assessment record and generating a plan. An assessment without `profile`
  gets `TrainingProfile.legacyDefault()`, which triggers the "Personalize your
  plan" prompt.
- A new assessment revision (`completeOnboarding` / `completeReassessment`)
  sets `assessmentUpdatedAt`. `activeMilestoneCheckIns` then ignores older
  check-ins.
- `appRouterProvider` (`core/navigation/app_router.dart`) creates one
  `GoRouter` for the app's lifetime. It uses `refreshListenable` for the
  onboarding redirect. Do not construct the router inside `build`, because it
  resets navigation. Retake, reassessment, and results are pushed routes.
  Tabs live in `MainShell` (an `IndexedStack`), ordered by the `AppTab` enum
  in `core/navigation/app_tabs.dart`; use `controller.selectTab(AppTab.x)`.
- `OnboardingScreen` serves three `AssessmentMode`s (initial, retake,
  reassessment). The review step previews the real generated plan.
- `SessionScreen` freezes each exercise's dose for the whole workout
  (`_doses`), so feedback changes the next session rather than the current
  one. Set drafts own `TextEditingController`s; `_clearDrafts` disposes them
  in a post-frame callback because their fields are still mounted for one
  more frame.

### UI conventions

- Screens use `ResponsivePage`/`PageHeader` (`presentation/widgets/common.dart`)
  and the question cards in `form_widgets.dart`. `MeasuredScoreCard` stores
  0 for "not measured".
- Charts (`presentation/widgets/charts.dart`) are CustomPainters. Their colors
  come from `ChartColors`: separate light and dark steps, validated for
  colorblind separation. Keep single-series charts legend-free, use small
  multiples instead of many converging lines, and never put data color on text.
- Progress bars: `semanticsValue` must be numeric in this Flutter version.
  Put readable values in `semanticsLabel`.

## Testing notes

- `test/test_helpers.dart` builds assessments and readiness presets.
- Widget flow tests (`test/app_flow_test.dart`) run the real
  `ACLRecoveryCoachApp` on an in-memory Hive box
  (`Hive.openBox(..., bytes: Uint8List(0))`, opened inside `tester.runAsync`)
  and assert against the persisted JSON. When editing labels, keep those
  finders in sync. Feedback buttons read "Too Hard", "Just Right", and
  "Too Easy".
- In the browser, the release web build does not expose Flutter's semantics
  tree to automation. Verify visually, or seed state by writing a JSON string
  into IndexedDB (`acl_rehab_state_box` > store `box` > key `app_state_v2`).

## Git

Remote: `https://github.com/AhmadBaabod/ACL-Rehab-Tracker` (default branch
`main`). Work on feature branches. The repository stores LF line endings.
