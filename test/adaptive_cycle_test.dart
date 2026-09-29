import 'package:acl_rehab/data/exercise_catalog.dart';
import 'package:acl_rehab/domain/models/app_state.dart';
import 'package:acl_rehab/domain/models/assessment.dart';
import 'package:acl_rehab/domain/models/assessment_record.dart';
import 'package:acl_rehab/domain/models/exercise.dart';
import 'package:acl_rehab/domain/models/rehab_plan.dart';
import 'package:acl_rehab/domain/models/session_log.dart';
import 'package:acl_rehab/domain/models/training_profile.dart';
import 'package:acl_rehab/domain/models/workout_log.dart';
import 'package:acl_rehab/domain/services/assessment_comparison.dart';
import 'package:acl_rehab/domain/services/exercise_alternatives.dart';
import 'package:acl_rehab/domain/services/plan_generator.dart';
import 'package:acl_rehab/domain/services/progress_analytics.dart';
import 'package:acl_rehab/domain/services/reassessment_advisor.dart';
import 'package:acl_rehab/domain/services/rehab_status.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

ExerciseProgressionState start(String id) => ExerciseProgressionState(
  exerciseId: id,
  recommendation: ProgressionRecommendation.maintain,
  updatedAt: DateTime.now(),
);

WorkoutLog workout(
  RehabPlan plan,
  DateTime at, {
  int pain = 1,
  int effort = 5,
}) {
  final session = plan.sessions.first;
  return WorkoutLog(
    id: 'w-${at.microsecondsSinceEpoch}',
    planId: plan.id,
    planVersion: plan.version,
    sessionId: session.id,
    sessionName: session.name,
    startedAt: at.subtract(const Duration(minutes: 30)),
    completedAt: at,
    entries: [
      for (final item in session.exercises)
        WorkoutExerciseEntry(
          exerciseId: item.exerciseId,
          exerciseName: item.exerciseId,
          plannedSets: item.prescription.sets,
          completedSets: item.prescription.sets,
        ),
    ],
    painAfter: pain,
    effort: effort,
  );
}

void main() {
  group('Feedback-driven progression', () {
    test('two "just right" sessions with low pain progress one level', () {
      final once = start(
        'box-squat',
      ).record(ExerciseFeedback.justRight, painAfter: 1);
      expect(once.level, 0);
      expect(once.recommendation, ProgressionRecommendation.maintain);
      final twice = once.record(ExerciseFeedback.justRight, painAfter: 1);
      expect(twice.level, 1);
      expect(twice.recommendation, ProgressionRecommendation.progress);
    });

    test(
      '"too easy" progresses immediately, pain 3-4 holds, pain 5+ regresses',
      () {
        expect(start('a').record(ExerciseFeedback.tooEasy).level, 1);
        final held = start('a').record(ExerciseFeedback.tooEasy, painAfter: 3);
        expect(held.level, 0);
        expect(held.recommendation, ProgressionRecommendation.maintain);
        final painful = start(
          'a',
        ).record(ExerciseFeedback.justRight, painAfter: 6);
        expect(painful.level, -1);
        expect(painful.recommendation, ProgressionRecommendation.regress);
      },
    );

    test('levels are bounded', () {
      var state = start('a');
      for (var i = 0; i < 10; i++) {
        state = state.record(ExerciseFeedback.tooEasy);
      }
      expect(state.level, ExerciseProgressionState.maxLevel);
      expect(state.atCeiling, isTrue);
    });

    test('the next session dose follows feedback logged since the plan', () {
      const item = PlanExercise(
        exerciseId: 'box-squat',
        prescription: Prescription(
          sets: 3,
          reps: '8-12',
          hold: '3 sec down',
          restSeconds: 60,
          effort: 'Moderate',
          frequency: 'Each training day',
        ),
        reason: '',
        priority: 9,
      );
      final progressed = start('box-squat').record(ExerciseFeedback.tooEasy);
      expect(item.doseFor(progressed).sets, 4);
      final eased = start('box-squat').record(ExerciseFeedback.tooHard);
      expect(item.doseFor(eased).sets, 2);

      final paused = item.copyWith(
        prescription: item.prescription.copyWith(paused: true),
      );
      expect(
        paused.doseFor(progressed).sets,
        3,
        reason: 'paused doses do not step up',
      );
      expect(
        paused.doseFor(eased).sets,
        2,
        reason: 'but they can still step down',
      );
    });
  });

  group('Reassessment recommendations', () {
    final assessment = testAssessment(
      weeks: 7,
      readiness: loadingReadiness(),
      profile: fullGym(),
    );
    final testDate = DateTime.now().subtract(const Duration(days: 12));
    final plan = PlanGenerator.generate(
      PlanGenerationInput(assessment: assessment, now: testDate),
    );
    final record = AssessmentRecord(
      id: 'r1',
      createdAt: testDate,
      kind: AssessmentKind.initial,
      assessment: assessment,
      phase: plan.phase,
    );
    AppState stateWith({
      List<WorkoutLog> workouts = const [],
      Map<String, ExerciseProgressionState> progressions = const {},
      List<SessionLog> logs = const [],
      DateTime? snoozed,
    }) {
      return AppState(
        assessment: assessment,
        assessmentUpdatedAt: testDate,
        onboardingCompleted: true,
        assessmentHistory: [record],
        plans: [plan],
        workoutLogs: workouts,
        exerciseProgressions: progressions,
        sessionLogs: logs,
        reassessmentSnoozedUntil: snoozed,
      );
    }

    test('is not due right after a plan without progress', () {
      final result = ReassessmentAdvisor.evaluate(stateWith());
      expect(result.isDue, isFalse);
      expect(result.dueDate, isNotNull);
    });

    test('meaningful improvement recommends a retest', () {
      final now = DateTime.now();
      final workouts = [
        for (var i = 4; i >= 1; i--)
          workout(plan, now.subtract(Duration(days: i * 2))),
      ];
      final progressed = {
        for (final id in plan.exerciseIds) id: start(id).copyWith(level: 2),
      };
      final result = ReassessmentAdvisor.evaluate(
        stateWith(workouts: workouts, progressions: progressed),
      );
      expect(result.isDue, isTrue);
      expect(result.reason, ReassessmentReason.improvement);
      expect(result.evidence.first, contains('4 sessions'));
    });

    test(
      'rising pain triggers an urgent symptom check that ignores snooze',
      () {
        final now = DateTime.now();
        final workouts = [
          workout(plan, now.subtract(const Duration(days: 3)), pain: 5),
          workout(plan, now.subtract(const Duration(days: 1)), pain: 6),
        ];
        final result = ReassessmentAdvisor.evaluate(
          stateWith(
            workouts: workouts,
            snoozed: now.add(const Duration(days: 3)),
          ),
        );
        expect(result.isDue, isTrue);
        expect(result.isUrgent, isTrue);
      },
    );

    test('snoozing hides a non-urgent recommendation', () {
      final later = DateTime.now().add(
        Duration(days: plan.reassessAfterDays + 1),
      );
      final due = ReassessmentAdvisor.evaluate(stateWith(), now: later);
      expect(due.reason, ReassessmentReason.scheduled);
      expect(due.isDue, isTrue);
      final snoozed = ReassessmentAdvisor.evaluate(
        stateWith(snoozed: later.add(const Duration(days: 1))),
        now: later,
      );
      expect(snoozed.isDue, isFalse);
    });
  });

  group('Comparison after a reassessment', () {
    test('reports improvements, new measurements, and plan changes', () {
      final before = testAssessment(
        weeks: 7,
        pain: 3,
        swelling: Swelling.mild,
        readiness: loadingReadiness(),
        profile: fullGym(),
      );
      final after = testAssessment(
        weeks: 13,
        readiness: loadingReadiness(quad: 78, balance: 80),
        profile: fullGym(),
      );
      final oldPlan = PlanGenerator.generate(
        PlanGenerationInput(assessment: before),
      );
      final newPlan = PlanGenerator.generate(
        PlanGenerationInput(
          assessment: after,
          previousPlan: oldPlan,
          version: 2,
        ),
      );
      final comparison = AssessmentComparison.compare(
        before: RehabStatus.from(before),
        after: RehabStatus.from(after),
        previousPhase: oldPlan.phase,
        currentPhase: newPlan.phase,
        previousPlan: oldPlan,
        newPlan: newPlan,
      );

      expect(comparison.phaseDelta, greaterThan(0));
      expect(
        comparison.improvements.map((item) => item.label),
        contains('Pain'),
      );
      expect(
        comparison.newlyMeasured.map((item) => item.label),
        contains('Quadriceps symmetry'),
      );
      expect(comparison.planDiff.isEmpty, isFalse);
      expect(comparison.planDiff.swapped, isNotEmpty);
      expect(
        comparison.remainingWeaknesses.map((area) => area.type),
        contains(FocusAreaType.quadStrength),
      );
    });
  });

  group('Progress analytics', () {
    final assessment = testAssessment(weeks: 10, readiness: loadingReadiness());
    final created = DateTime.now().subtract(const Duration(days: 28));
    final plan = PlanGenerator.generate(
      PlanGenerationInput(assessment: assessment, now: created),
    );

    test('adherence waits for a full week', () {
      final fresh = PlanGenerator.generate(
        PlanGenerationInput(assessment: assessment),
      );
      final snapshot = ProgressAnalytics.compute(
        AppState(assessment: assessment, plans: [fresh]),
        ProgressPeriod.month,
      );
      expect(snapshot.adherence, isNull);
    });

    test('computes consistency, pain trend, and a verdict', () {
      final now = DateTime.now();
      final workouts = [
        for (var i = 0; i < 8; i++)
          workout(
            plan,
            created.add(Duration(days: 2 + i * 3)),
            pain: i < 4 ? 4 : 1,
          ),
      ];
      final state = AppState(
        assessment: assessment,
        onboardingCompleted: true,
        plans: [plan],
        workoutLogs: workouts,
      );
      final snapshot = ProgressAnalytics.compute(
        state,
        ProgressPeriod.month,
        now: now,
      );

      expect(snapshot.workouts, 8);
      expect(snapshot.adherence, isNotNull);
      expect(snapshot.weekly, hasLength(8));
      expect(
        snapshot.weekly.fold<int>(0, (sum, week) => sum + week.completed),
        8,
      );
      final pain = snapshot.insights.firstWhere(
        (item) => item.title.startsWith('Pain after sessions'),
      );
      expect(pain.trend, InsightTrend.improving);
      expect(snapshot.verdict, isNot(ProgressVerdict.needsAttention));
    });

    test('unmeasured symmetry values are not charted as 0%', () {
      final state = AppState(
        assessment: assessment,
        assessmentHistory: [
          AssessmentRecord(
            id: 'a',
            createdAt: created,
            kind: AssessmentKind.initial,
            assessment: assessment.copyWith(
              protocolReadiness: loadingReadiness(quad: 70),
            ),
            phase: RehabPhase.earlyStrengthening,
          ),
        ],
      );
      final snapshot = ProgressAnalytics.compute(state, ProgressPeriod.all);
      expect(snapshot.symmetrySeries.keys, ['Quadriceps']);
    });
  });

  group('Exercise alternatives', () {
    final assessment = testAssessment(
      weeks: 13,
      readiness: loadingReadiness(quad: 85, balance: 85),
      profile: const TrainingProfile(),
    );

    test('alternatives share the purpose and never exceed the phase', () {
      for (final exercise in ExerciseCatalog.all) {
        final alternatives = AlternativeFinder.find(
          exercise,
          assessment: assessment,
          milestone: null,
          currentPhase: RehabPhase.advancedStrength,
        );
        for (final option in alternatives) {
          if (option.samePurpose) {
            expect(option.exercise.purpose, exercise.purpose);
          } else {
            expect(exercise.purpose.related, contains(option.exercise.purpose));
          }
          final maxPhase =
              exercise.phase.order > RehabPhase.advancedStrength.order
              ? exercise.phase.order
              : RehabPhase.advancedStrength.order;
          expect(option.exercise.phase.order, lessThanOrEqualTo(maxPhase));
        }
      }
    });

    test('extension work is never offered as a flexion alternative', () {
      final alternatives = AlternativeFinder.find(
        ExerciseCatalog.byId('heel-prop-extension')!,
        assessment: assessment,
        milestone: null,
        currentPhase: RehabPhase.protectionAndMotion,
      );
      expect(
        alternatives.map((item) => item.exercise.id),
        contains('prone-hang'),
      );
      expect(
        alternatives.map((item) => item.exercise.id),
        isNot(contains('heel-slides')),
      );
    });

    test('missing equipment is explained and available options come first', () {
      final alternatives = AlternativeFinder.find(
        ExerciseCatalog.byId('hamstring-curl')!,
        assessment: assessment,
        milestone: null,
        currentPhase: RehabPhase.advancedStrength,
      );
      expect(alternatives.first.isAvailable, isTrue);
      expect(alternatives.first.exercise.needsNoEquipment, isTrue);
      final banded = alternatives.firstWhere(
        (item) => item.exercise.id == 'banded-hamstring-curl',
      );
      expect(banded.isAvailable, isFalse);
      expect(banded.blockers.first, contains('resistance band'));
    });

    test(
      'catalog references are valid and every exercise has a purpose group',
      () {
        final ids = ExerciseCatalog.all.map((item) => item.id).toList();
        expect(ids.toSet().length, ids.length);
        for (final exercise in ExerciseCatalog.all) {
          for (final id in exercise.alternativeExerciseIds) {
            expect(
              ExerciseCatalog.byId(id),
              isNotNull,
              reason: '$id is missing',
            );
            expect(
              ExerciseCatalog.byId(id)!.purpose == exercise.purpose ||
                  exercise.purpose.related.contains(
                    ExerciseCatalog.byId(id)!.purpose,
                  ),
              isTrue,
              reason: '${exercise.id} lists $id, which trains something else',
            );
          }
        }
        for (final purpose in TrainingPurpose.values) {
          expect(
            ExerciseCatalog.all.where((item) => item.purpose == purpose),
            isNotEmpty,
          );
        }
      },
    );
  });
}

extension on ExerciseProgressionState {
  ExerciseProgressionState copyWith({int? level}) => ExerciseProgressionState(
    exerciseId: exerciseId,
    recommendation: recommendation,
    updatedAt: updatedAt,
    timesCompleted: timesCompleted,
    level: level ?? this.level,
  );
}
