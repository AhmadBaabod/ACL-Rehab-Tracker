import 'package:acl_rehab/data/exercise_catalog.dart';
import 'package:acl_rehab/domain/models/exercise.dart';
import 'package:acl_rehab/domain/models/workout_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
