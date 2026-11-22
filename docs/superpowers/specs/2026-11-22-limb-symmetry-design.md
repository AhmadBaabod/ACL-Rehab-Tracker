# Training limb symmetry: design

## Intent

Patients do single-leg exercises in almost every session, but phase
progression only sees symmetry numbers entered in an assessment or check-in.
Logging both legs during training lets the app estimate symmetry from real
sessions and offer it as a check-in update, so the phase can move forward as
the patient gets stronger without separate testing.

## Goals

- For single-leg exercises, log each set for the operated leg and the other leg.
- Show limb symmetry (operated / other x 100) per exercise and per area.
- After enough sessions, suggest updating the check-in with training symmetry.
  One tap opens the check-in sheet prefilled; saving it re-plans as today.

## Non-goals

- No automatic phase change (user chose "suggest, I confirm").
- No hop-distance logging. Hop symmetry stays assessment/check-in only.
- No left/right knee field; legs are "Operated" and "Other".

## Anti-goals

- A single badly logged set must not produce a suggestion.
- Clearance, pain, swelling, and other phase gates are unchanged.

## Approaches considered

- **A. Suggest, you confirm (chosen).** Training symmetry is offered as
  prefilled check-in values; the user reviews and saves.
- B. Automatic phase update after stable symmetry over about 3 sessions.
  Rejected: training sets are rougher than clinical tests, and a mis-logged
  set could advance the phase.

## Design

- **Catalog:** `Exercise.symmetryArea` (nullable `SymmetryArea`: quad,
  hamstring, hip, calf, balance). Non-null means the exercise is done one leg
  at a time and is logged per leg. Initial set:
  - quad: single-leg leg press, both leg extension machines and the seated
    knee extension (instructions say one leg at a time), lateral and forward
    step-down, rear-foot elevated split squat, single-leg squat to box
  - hamstring: standing, seated, and banded hamstring curls
  - hip: single-leg bridge
  - calf: single-leg calf raise (shown, not fed to check-in)
  - balance: single-leg stance with reach (timed)
- **Data:** `WorkoutExerciseEntry.otherLegSets` (`List<SetLog>`, default
  empty). `sets` stays the operated leg, so progression, `lastSetsFor`, and
  load suggestions keep working unchanged. Old saves load with no other-leg
  data.
- **Score per leg:** best set. Weighted: Epley estimate
  `kg x (1 + reps / 30)`; bodyweight: reps; timed: seconds. Symmetry =
  operated / other x 100, shown uncapped and capped at 100 for check-ins.
- **Area estimate (`LimbSymmetryAnalyzer`):** for each area, take the
  per-session symmetry from the last 3 sessions within 28 days that logged
  both legs, and use their median. Needs at least 2 sessions.
- **Suggestion:** shown on the finish screen of a workout and on the Progress
  tab when an estimate for quad, hamstring, hip, or balance differs from the
  current recorded value by 5 or more points. "Review check-in" opens the
  check-in sheet prefilled with the latest values plus the training estimates,
  and labels which values came from training.
- **Session UI:** single-leg exercises show two input lines per set,
  "Operated" and "Other", with a tip: use the same weight on both legs and
  stop when form slips; the app compares what each leg can do. Each line
  shows that leg's symmetry once both are filled.

## Left to the builder

Widget layout details, wording polish, and test structure.
