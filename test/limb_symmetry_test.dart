import 'package:acl_rehab/data/exercise_catalog.dart';
import 'package:acl_rehab/domain/models/app_state.dart';
import 'package:acl_rehab/domain/models/exercise.dart';
import 'package:acl_rehab/domain/models/workout_log.dart';
import 'package:acl_rehab/domain/services/limb_symmetry.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

final _now = DateTime(2026, 11, 22, 12);

WorkoutExerciseEntry _entry(
  String exerciseId,
  List<SetLog> operated,
  List<SetLog> other,
) {
  return WorkoutExerciseEntry(
    exerciseId: exerciseId,
    exerciseName: exerciseId,
    plannedSets: 3,
    completedSets: operated.length,
    sets: operated,
    otherLegSets: other,
  );
}

/// A workout [daysAgo] days before [_now] where the operated leg did
/// [operatedReps] and the other leg 10 reps of a single-leg bridge.
WorkoutLog _bridgeSession(int daysAgo, int operatedReps, {String? id}) {
  final at = _now.subtract(Duration(days: daysAgo));
  return WorkoutLog(
    id: id ?? 'w-$daysAgo',
    planId: 'p',
    planVersion: 1,
    sessionId: 'A',
    sessionName: 'Session A',
    startedAt: at,
    completedAt: at,
    entries: [
      _entry(
        'single-leg-bridge',
        [SetLog(reps: operatedReps)],
        const [SetLog(reps: 10)],
      ),
    ],
    painAfter: 1,
    effort: 5,
  );
}

void main() {
  group('Symmetry service', () {
    test('legScore uses Epley for weighted sets', () {
      expect(legScore(const [SetLog(reps: 10, weightKg: 30)]), 40.0);
      expect(legScore(const [SetLog(reps: 6), SetLog(reps: 9)]), 9.0);
      expect(legScore(const [SetLog(seconds: 30)]), 30.0);
      expect(legScore(const []), isNull);
      expect(legScore(const [SetLog(reps: 0)]), isNull);
    });

    test('entrySymmetry compares operated with other leg', () {
      final entry = _entry(
        'single-leg-leg-press',
        const [SetLog(reps: 8, weightKg: 20)],
        const [SetLog(reps: 10, weightKg: 20)],
      );
      // 20 * (1 + 8/30) = 25.33; 20 * (1 + 10/30) = 26.67 -> 95%.
      expect(entrySymmetry(entry), 95);
      expect(
        entrySymmetry(
          _entry(
            'single-leg-bridge',
            const [SetLog(reps: 8)],
            const [SetLog(reps: 10)],
          ),
        ),
        80,
      );
    });

    test('entrySymmetry is null when other leg is empty or zero', () {
      expect(
        entrySymmetry(
          _entry('single-leg-bridge', const [SetLog(reps: 8)], const []),
        ),
        isNull,
      );
      expect(
        entrySymmetry(
          _entry(
            'single-leg-bridge',
            const [SetLog(reps: 8)],
            const [SetLog(reps: 0)],
          ),
        ),
        isNull,
      );
    });

    test('entrySymmetry skips weighted versus bodyweight', () {
      expect(
        entrySymmetry(
          _entry(
            'single-leg-leg-press',
            const [SetLog(reps: 8, weightKg: 20)],
            const [SetLog(reps: 10)],
          ),
        ),
        isNull,
      );
    });

    test(
      'estimate needs two sessions and uses the median of the last three',
      () {
        final one = LimbSymmetryAnalyzer.estimates([
          _bridgeSession(1, 8),
        ], _now);
        expect(one, isEmpty);

        final logs = [
          _bridgeSession(10, 7), // 70, oldest: dropped
          _bridgeSession(6, 8), // 80
          _bridgeSession(4, 9), // 90
          _bridgeSession(2, 6), // 60
        ];
        final estimate = LimbSymmetryAnalyzer.estimates(
          logs,
          _now,
        )[SymmetryArea.hip]!;
        expect(estimate.percent, 80);
        expect(estimate.sessions, 3);
      },
    );

    test('sessions older than 28 days are ignored', () {
      final logs = [_bridgeSession(40, 8), _bridgeSession(30, 9)];
      expect(LimbSymmetryAnalyzer.estimates(logs, _now), isEmpty);
    });

    test('suggestions cap at 100 and skip calf and small differences', () {
      AppState stateWith(int recordedHip, List<WorkoutLog> logs) => AppState(
        assessment: testAssessment(
          weeks: 12,
          readiness: loadingReadiness(hip: recordedHip),
        ),
        workoutLogs: logs,
      );

      final close = stateWith(85, [_bridgeSession(2, 9), _bridgeSession(1, 9)]);
      // Estimate 90 vs recorded 85: difference 5 -> suggested.
      expect(LimbSymmetryAnalyzer.suggestions(close, _now).single.estimate, 90);

      final same = stateWith(88, [_bridgeSession(2, 9), _bridgeSession(1, 9)]);
      expect(LimbSymmetryAnalyzer.suggestions(same, _now), isEmpty);

      final strong = stateWith(70, [
        _bridgeSession(2, 11),
        _bridgeSession(1, 11),
      ]);
      final suggestion = LimbSymmetryAnalyzer.suggestions(strong, _now).single;
      expect(suggestion.area, SymmetryArea.hip);
      expect(suggestion.estimate, 100);
      expect(suggestion.recorded, 70);

      WorkoutLog calfSession(int daysAgo) {
        final at = _now.subtract(Duration(days: daysAgo));
        return WorkoutLog(
          id: 'calf-$daysAgo',
          planId: 'p',
          planVersion: 1,
          sessionId: 'A',
          sessionName: 'A',
          startedAt: at,
          completedAt: at,
          entries: [
            _entry(
              'single-leg-calf-raise',
              const [SetLog(reps: 5)],
              const [SetLog(reps: 10)],
            ),
          ],
          painAfter: 1,
          effort: 5,
        );
      }

      final calfOnly = stateWith(0, [calfSession(2), calfSession(1)]);
      expect(
        LimbSymmetryAnalyzer.estimates(calfOnly.workoutLogs, _now),
        contains(SymmetryArea.calf),
      );
      expect(LimbSymmetryAnalyzer.suggestions(calfOnly, _now), isEmpty);
    });
  });

  group('Symmetry areas', () {
    test('single-leg exercises declare their symmetry area', () {
      const expected = {
        'single-leg-leg-press': SymmetryArea.quad,
        'leg-extension-limited': SymmetryArea.quad,
        'leg-extension-full': SymmetryArea.quad,
        'seated-knee-extension-90-45': SymmetryArea.quad,
        'lateral-step-down': SymmetryArea.quad,
        'forward-step-down': SymmetryArea.quad,
        'rear-foot-elevated-split-squat': SymmetryArea.quad,
        'single-leg-squat': SymmetryArea.quad,
        'standing-hamstring-curl': SymmetryArea.hamstring,
        'hamstring-curl': SymmetryArea.hamstring,
        'banded-hamstring-curl': SymmetryArea.hamstring,
        'single-leg-bridge': SymmetryArea.hip,
        'single-leg-calf-raise': SymmetryArea.calf,
      };
      for (final entry in expected.entries) {
        final exercise = ExerciseCatalog.byId(entry.key)!;
        expect(exercise.symmetryArea, entry.value, reason: entry.key);
        expect(exercise.isUnilateral, isTrue, reason: entry.key);
      }
      final tagged = ExerciseCatalog.all
          .where((exercise) => exercise.isUnilateral)
          .map((exercise) => exercise.id)
          .toSet();
      expect(tagged, expected.keys.toSet());
      expect(ExerciseCatalog.byId('box-squat')!.symmetryArea, isNull);
      expect(SymmetryArea.calf.feedsCheckIn, isFalse);
      expect(SymmetryArea.quad.feedsCheckIn, isTrue);
    });

    test('entry JSON round-trips otherLegSets and loads old saves', () {
      const entry = WorkoutExerciseEntry(
        exerciseId: 'single-leg-bridge',
        exerciseName: 'Single-Leg Bridge',
        plannedSets: 2,
        completedSets: 1,
        sets: [SetLog(reps: 8)],
        otherLegSets: [SetLog(reps: 10)],
      );
      final restored = WorkoutExerciseEntry.fromJson(entry.toJson());
      expect(restored.sets.single.reps, 8);
      expect(restored.otherLegSets.single.reps, 10);

      final legacy = entry.toJson()..remove('otherLegSets');
      expect(WorkoutExerciseEntry.fromJson(legacy).otherLegSets, isEmpty);
    });
  });
}
