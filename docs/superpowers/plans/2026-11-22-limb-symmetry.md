# Training Limb Symmetry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Log both legs on single-leg exercises, estimate limb symmetry from training, and offer it as a prefilled check-in the user confirms.

**Architecture:** Catalog exercises carry a nullable `SymmetryArea`. Workout entries keep the operated leg in `sets` and add `otherLegSets`. A pure service (`limb_symmetry.dart`) scores legs, computes per-area estimates and suggestions. The session screen logs both legs; the completion dialog and Progress tab surface suggestions that open the existing check-in sheet prefilled.

**Tech Stack:** Flutter, Riverpod, Hive (JSON in one box), flutter_test.

**Spec:** `docs/superpowers/specs/2026-11-22-limb-symmetry-design.md`

## Global Constraints

- No automatic phase change; only a prefilled check-in that the user saves.
- Legs are labelled "Operated" and "Other"; no left/right field.
- `WorkoutExerciseEntry.sets` stays the operated leg; `fromJson` must accept saves without `otherLegSets`.
- Estimate = median of per-session symmetry from the last 3 sessions within 28 days; needs at least 2 sessions.
- Suggest only for quad, hamstring, hip, balance, when the estimate differs from the current recorded value by 5 or more points (or no value is recorded).
- Check-in values are capped at 100.
- `flutter analyze` must report "No issues found!"; run `dart format lib test` first.

## Review Focus

- Other leg logged as 0 or left empty: no symmetry, no crash (no division by zero).
- One leg weighted and the other bodyweight in the same entry: not comparable, skip that entry.
- Operated leg stronger than the other (over 100%): shown as is in the session, capped at 100 for check-in.
- Exercise swapped for today: symmetry uses the swapped exercise's area; swapping to a bilateral exercise logs one leg only.
- Old saves and old entries with no `otherLegSets` load and are ignored by the analyzer.

---

### Task 1: Symmetry area on exercises and other-leg data

**Files:**
- Modify: `lib/domain/models/exercise.dart` (enum, label, field)
- Modify: `lib/data/exercise_catalog.dart` (helper param, tagging, leg extension instructions)
- Modify: `lib/domain/models/workout_log.dart` (`otherLegSets`)
- Test: `test/limb_symmetry_test.dart`

**Interfaces:**
- Produces: `enum SymmetryArea { quad, hamstring, hip, calf, balance }` with `String get label` ('Quad', 'Hamstring', 'Hip', 'Calf', 'Balance') and `bool get feedsCheckIn` (false only for calf); `Exercise.symmetryArea` (`SymmetryArea?`, default null) and `bool get isUnilateral`; `_exercise(..., SymmetryArea? symmetryArea)`; `WorkoutExerciseEntry.otherLegSets` (`List<SetLog>`, default const [], JSON key `otherLegSets`).

- [ ] **Step 1: Write failing tests** `single-leg exercises declare their symmetry area` (expects: `single-leg-leg-press`, `leg-extension-limited`, `leg-extension-full`, `seated-knee-extension-90-45`, `lateral-step-down`, `forward-step-down`, `rear-foot-elevated-split-squat`, `single-leg-squat` -> quad; `standing-hamstring-curl`, `hamstring-curl`, `banded-hamstring-curl` -> hamstring; `single-leg-bridge` -> hip; `single-leg-calf-raise` -> calf; `single-leg-stance` -> balance; `box-squat` -> null), and `entry JSON round-trips otherLegSets and loads old saves without it`.
- [ ] **Step 2:** `flutter test test/limb_symmetry_test.dart` fails to compile.
- [ ] **Step 3:** Implement the interfaces. Leg extension machine and seated knee extension instructions gain "Work one leg at a time."
- [ ] **Step 4:** Tests pass; `flutter test test/exercise_catalog_test.dart` still passes.
- [ ] **Step 5:** Commit "Tag single-leg exercises and store other-leg sets".

### Task 2: Symmetry service

**Files:**
- Create: `lib/domain/services/limb_symmetry.dart`
- Test: `test/limb_symmetry_test.dart`

**Interfaces:**
- Consumes: Task 1.
- Produces:
  - `double? legScore(List<SetLog> sets)`: best set; weighted -> `kg * (1 + reps / 30)`; bodyweight -> reps; timed -> seconds; null when empty or best is 0.
  - `int? entrySymmetry(WorkoutExerciseEntry entry)`: rounded `operated / other * 100`; null when either score is null, or one leg has weighted sets and the other has none.
  - `class SymmetryEstimate { SymmetryArea area; int percent; int sessions; }`
  - `class SymmetrySuggestion { SymmetryArea area; int estimate /* capped 100 */; int? recorded; }`
  - `LimbSymmetryAnalyzer.estimates(List<WorkoutLog> logs, DateTime now) -> Map<SymmetryArea, SymmetryEstimate>`: per session, the area's value is the mean of its entries' symmetries; use the 3 most recent sessions within 28 days; median; omit areas with under 2 sessions.
  - `LimbSymmetryAnalyzer.suggestions(AppState state, DateTime now) -> List<SymmetrySuggestion>`: recorded values from `RehabStatus.from(assessment, milestone: state.latestMilestone)` (quad/hamstring/hip/balance); include an area when `feedsCheckIn` and recorded is null or differs from the capped estimate by >= 5.

- [ ] **Step 1: Write failing tests:** `legScore uses Epley for weighted sets` (`[SetLog(reps: 10, weightKg: 30)]` -> 40.0); `entrySymmetry compares operated with other leg` (operated 8x20kg, other 10x20kg -> 87); `entrySymmetry is null when other leg is empty or zero`; `entrySymmetry skips weighted versus bodyweight`; `estimate needs two sessions and uses the median of the last three` (sessions 70, 80, 90, 60 newest last -> 80; one session -> no estimate); `sessions older than 28 days are ignored`; `suggestions cap at 100 and skip calf and small differences` (recorded quad 85, estimate 88 -> none; estimate 104 -> 100).
- [ ] **Step 2:** Run, see failures.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Tests pass.
- [ ] **Step 5:** Commit "Estimate limb symmetry from training".

### Task 3: Log both legs in the session screen

**Files:**
- Modify: `lib/presentation/screens/session_screen.dart`
- Test: `test/app_flow_test.dart`

**Interfaces:**
- Consumes: Tasks 1-2 (`Exercise.isUnilateral`, `entrySymmetry`).
- Produces: `_SetDraft` gains `otherValue` and `otherWeight` controllers (disposed with it); `_setLogs` returns operated sets; a new `_otherLegLogs` returns other-leg sets; `WorkoutExerciseEntry.otherLegSets` is filled for unilateral exercises.

- [ ] **Step 1: Write failing widget test** `single-leg exercise logs both legs and shows symmetry`: seed a state whose plan holds `single-leg-bridge` (hip), enter operated 8 and other 10 reps for set 1, complete, finish workout; assert persisted entry has `sets[0].reps == 8`, `otherLegSets[0].reps == 10`, and the text `80% symmetry` appeared on the set.
- [ ] **Step 2:** Run, see failure.
- [ ] **Step 3:** Implement: unilateral exercises render two labelled rows per set ("Operated", "Other") sharing one complete button; validation requires both values; other-leg drafts prefill from the last logged `otherLegSets`; a one-line tip above the sets: "Use the same weight on both legs and stop when form slips. The app compares what each leg can do."
- [ ] **Step 4:** `flutter test test/app_flow_test.dart` passes.
- [ ] **Step 5:** Commit "Log operated and other leg on single-leg exercises".

### Task 4: Suggest a prefilled check-in

**Files:**
- Modify: `lib/presentation/screens/progress_screen.dart` (public sheet opener, prefill, card)
- Modify: `lib/presentation/screens/session_screen.dart` (completion dialog)
- Test: `test/app_flow_test.dart`

**Interfaces:**
- Consumes: Task 2 `LimbSymmetryAnalyzer.suggestions`.
- Produces: top-level `Future<void> showCheckInSheet(BuildContext context, WidgetRef ref, AppState state, {List<SymmetrySuggestion> suggestions = const []})` (moved from `_showCheckInSheet`); `_MilestoneCheckInSheet` takes `suggestions`, initializes matching symmetry fields from `estimate`, and shows "From training: Quad 88%, Hip 92%. Review before saving."

- [ ] **Step 1: Write failing widget test** `training symmetry suggests a prefilled check-in`: seed two workouts with `single-leg-bridge` entries at 80% and 90%, open Progress; find "Training symmetry"; tap "Review check-in"; tap "Save check-in"; assert latest persisted check-in `hipStrengthSymmetry == 85`.
- [ ] **Step 2:** Run, see failure.
- [ ] **Step 3:** Implement: Progress card lists each suggestion ("Hip 85% from training (recorded 70%)") with a "Review check-in" button; the workout-saved dialog shows the same line and a "Review check-in" action that calls `showCheckInSheet`.
- [ ] **Step 4:** Full `flutter test` passes; `dart format lib test`; `flutter analyze` reports no issues.
- [ ] **Step 5:** Update `CLAUDE.md` (Set logging bullet: `otherLegSets`, `limb_symmetry.dart`, suggest-only rule) and commit "Suggest check-in updates from training symmetry".
