import 'dart:convert';

import 'package:acl_rehab/data/exercise_catalog.dart';
import 'package:acl_rehab/domain/models/app_state.dart';
import 'package:acl_rehab/domain/models/exercise.dart';
import 'package:acl_rehab/domain/models/rehab_plan.dart';
import 'package:acl_rehab/domain/models/training_profile.dart';
import 'package:acl_rehab/domain/models/workout_log.dart';
import 'package:acl_rehab/domain/services/plan_generator.dart';
import 'package:acl_rehab/domain/services/progress_analytics.dart';
import 'package:acl_rehab/domain/services/set_logging.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

Prescription dose(String reps, {String hold = 'None', int sets = 3}) {
  return Prescription(
    sets: sets,
    reps: reps,
    hold: hold,
    restSeconds: 60,
    effort: '',
    frequency: '',
  );
}

WorkoutLog logWith(DateTime at, String exercise, List<SetLog> sets) {
  return WorkoutLog(
    id: 'w-${at.microsecondsSinceEpoch}',
    planId: 'p',
    planVersion: 1,
    sessionId: 'A',
    sessionName: 'Session A',
    startedAt: at,
    completedAt: at,
    entries: [
      WorkoutExerciseEntry(
        exerciseId: exercise,
        exerciseName: ExerciseCatalog.byId(exercise)!.name,
        plannedSets: 3,
        completedSets: sets.length,
        sets: sets,
      ),
    ],
    painAfter: 1,
    effort: 6,
  );
}

void main() {
  group('Set logging', () {
    test('each exercise asks for the right measure', () {
      Exercise byId(String id) => ExerciseCatalog.byId(id)!;
      SetMeasure measure(String id) {
        final exercise = byId(id);
        return setMeasureFor(
          exercise,
          dose(exercise.reps, hold: exercise.holdTime, sets: exercise.sets),
        );
      }

      expect(measure('leg-extension-limited'), SetMeasure.repsAndWeight);
      expect(measure('goblet-box-squat'), SetMeasure.repsAndWeight);
      expect(measure('single-leg-stance'), SetMeasure.reps);
      expect(measure('wall-sit'), SetMeasure.seconds);
      expect(measure('heel-prop-extension'), SetMeasure.minutes);
      expect(measure('stationary-bike'), SetMeasure.minutes);
      expect(measure('perturbation-balance'), SetMeasure.seconds);
    });

    test('targets come from the prescription', () {
      expect(numberRange('8-12 each side'), (low: 8, high: 12));
      expect(numberRange('10'), (low: 10, high: 10));
      expect(targetValue(SetMeasure.reps, dose('6-8')), 6);
      expect(
        targetValue(SetMeasure.seconds, dose('1 hold', hold: '20-45 sec')),
        20,
      );
    });

    test('summaries and unit conversion', () {
      final sets = [
        const SetLog(reps: 10, weightKg: 20),
        const SetLog(reps: 10, weightKg: 20),
      ];
      expect(summarizeSets(sets, WeightUnit.kg), '2 x 10 @ 20 kg');
      expect(summarizeSets(sets, WeightUnit.lb), '2 x 10 @ 44.1 lb');
      expect(
        summarizeSets(const [
          SetLog(seconds: 30),
          SetLog(seconds: 30),
        ], WeightUnit.kg),
        '2 x 30 s',
      );
      expect(
        WeightUnit.lb.toKg(WeightUnit.lb.fromKg(32.5)),
        closeTo(32.5, 1e-9),
      );
    });

    test('hitting the top of the range suggests more weight', () {
      final prescription = dose('8-12');
      final atTop = [
        for (var i = 0; i < 3; i++) const SetLog(reps: 12, weightKg: 20),
      ];
      expect(
        loadSuggestion(atTop, prescription, WeightUnit.kg),
        contains('22.5 kg'),
      );
      final belowTop = [...atTop.take(2), const SetLog(reps: 9, weightKg: 20)];
      expect(loadSuggestion(belowTop, prescription, WeightUnit.kg), isNull);
    });

    test('set logs survive a JSON round trip and count volume', () {
      final log = logWith(DateTime(2026, 9, 1), 'leg-extension-limited', const [
        SetLog(reps: 12, weightKg: 15),
        SetLog(reps: 10, weightKg: 17.5),
      ]);
      final decoded = WorkoutLog.fromJson(
        jsonDecode(jsonEncode(log.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.entries.single.sets.map((set) => set.weightKg), [
        15,
        17.5,
      ]);
      expect(decoded.volumeKg, 12 * 15 + 10 * 17.5);
      expect(decoded.entries.single.topWeightKg, 17.5);
    });

    test('older workouts without set data still load', () {
      final entry = WorkoutExerciseEntry.fromJson({
        'exerciseId': 'bridge',
        'exerciseName': 'Bridge',
        'plannedSets': 3,
        'completedSets': 3,
      });
      expect(entry.sets, isEmpty);
      expect(entry.volumeKg, 0);
    });
  });

  group('Strength progress', () {
    test('last sets and load trends come from logged workouts', () {
      final first = DateTime.now().subtract(const Duration(days: 10));
      final state = AppState(
        workoutLogs: [
          logWith(first, 'leg-extension-limited', const [
            SetLog(reps: 12, weightKg: 15),
          ]),
          logWith(
            first.add(const Duration(days: 5)),
            'leg-extension-limited',
            const [SetLog(reps: 12, weightKg: 20)],
          ),
        ],
      );
      expect(state.lastSetsFor('leg-extension-limited').single.weightKg, 20);

      final snapshot = ProgressAnalytics.compute(state, ProgressPeriod.month);
      final series =
          snapshot.loadSeries['Leg Extension Machine (90-45 Degrees)']!;
      expect(series.map((point) => point.value), [15, 20]);
      expect(snapshot.volumeKg, 12 * 15 + 12 * 20);
      expect(
        snapshot.insights.map((insight) => insight.title),
        contains('Lifting heavier'),
      );
    });
  });

  group('Leg extension in personalized plans', () {
    final quadDeficit = loadingReadiness(
      quad: 65,
      hamstring: 85,
      hip: 88,
      balance: 85,
    );

    test('gym users with a quad deficit get the machine leg extension', () {
      final early = PlanGenerator.generate(
        PlanGenerationInput(
          assessment: testAssessment(
            weeks: 7,
            readiness: quadDeficit,
            profile: fullGym(minutes: 60),
          ),
        ),
      );
      expect(early.exerciseIds, contains('leg-extension-limited'));

      final later = PlanGenerator.generate(
        PlanGenerationInput(
          assessment: testAssessment(
            weeks: 13,
            readiness: quadDeficit,
            profile: fullGym(minutes: 60),
          ),
        ),
      );
      expect(later.exerciseIds, contains('leg-extension-full'));
    });

    test('without machines the seated knee extension is the substitute', () {
      final plan = PlanGenerator.generate(
        PlanGenerationInput(
          assessment: testAssessment(
            weeks: 7,
            readiness: quadDeficit,
            profile: const TrainingProfile(minutesPerSession: 60),
          ),
        ),
      );
      final substitute = plan.allExercises.firstWhere(
        (item) => item.substitutedFromId == 'leg-extension-limited',
      );
      expect(substitute.exerciseId, 'seated-knee-extension-90-45');
    });

    test(
      'a "No Open Chain Extension" restriction blocks every leg extension',
      () {
        final plan = PlanGenerator.generate(
          PlanGenerationInput(
            assessment: testAssessment(
              weeks: 13,
              readiness: quadDeficit,
              restrictions: const ['No Open Chain Extension'],
              profile: fullGym(minutes: 60),
            ),
          ),
        );
        expect(
          plan.exerciseIds.where(
            (id) =>
                id.contains('knee-extension') || id.contains('leg-extension'),
          ),
          isEmpty,
        );
      },
    );

    test('full-range leg extension waits until about week 12', () {
      final extension = ExerciseCatalog.byId('leg-extension-full')!;
      final early = testAssessment(
        weeks: 8,
        readiness: quadDeficit,
        profile: fullGym(),
      );
      expect(extension.unlockStatus(early, null).isUnlocked, isFalse);
      expect(extension.requiredEquipment, {EquipmentType.gymMachines});
    });
  });
}
