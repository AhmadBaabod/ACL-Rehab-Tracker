import 'dart:convert';

import 'package:acl_rehab/data/exercise_catalog.dart';
import 'package:acl_rehab/domain/models/assessment.dart';
import 'package:acl_rehab/domain/models/exercise.dart';
import 'package:acl_rehab/domain/models/rehab_plan.dart';
import 'package:acl_rehab/domain/models/session_log.dart';
import 'package:acl_rehab/domain/models/training_profile.dart';
import 'package:acl_rehab/domain/services/plan_generator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

RehabPlan planFor(
  Assessment assessment, {
  Map<String, ExerciseProgressionState> progressions = const {},
  RehabPlan? previous,
}) {
  return PlanGenerator.generate(
    PlanGenerationInput(
      assessment: assessment,
      progressions: progressions,
      previousPlan: previous,
    ),
  );
}

List<Exercise> exercisesOf(RehabPlan plan) =>
    plan.exerciseIds.map((id) => ExerciseCatalog.byId(id)!).toList();

ExerciseProgressionState level(String id, int value) {
  return ExerciseProgressionState(
    exerciseId: id,
    recommendation: ProgressionRecommendation.maintain,
    updatedAt: DateTime.now(),
    level: value,
  );
}

void main() {
  final strengthAssessment = testAssessment(
    weeks: 13,
    readiness: loadingReadiness(quad: 65, hamstring: 82, hip: 85, balance: 70),
  );

  group('Personalization from assessment answers', () {
    test('equipment decides the exercises, with same-goal substitutes', () {
      final gym = planFor(strengthAssessment.copyWith(profile: fullGym()));
      final home = planFor(
        strengthAssessment.copyWith(
          profile: const TrainingProfile(
            equipment: {EquipmentType.resistanceBand},
          ),
        ),
      );

      expect(gym.phase, RehabPhase.advancedStrength);
      expect(
        exercisesOf(gym).any(
          (item) => item.requiredEquipment.contains(EquipmentType.gymMachines),
        ),
        isTrue,
      );
      for (final exercise in exercisesOf(home)) {
        expect(
          exercise.requiredEquipment.difference({EquipmentType.resistanceBand}),
          isEmpty,
          reason: '${exercise.name} needs equipment the user does not have',
        );
      }
      final substitutes = home.allExercises.where(
        (item) => item.substitutedFromId != null,
      );
      expect(substitutes, isNotEmpty);
      for (final item in substitutes) {
        expect(
          ExerciseCatalog.byId(item.exerciseId)!.purpose,
          ExerciseCatalog.byId(item.substitutedFromId!)!.purpose,
          reason: 'a substitute must serve the same purpose',
        );
      }
    });

    test('a measured quadriceps deficit becomes a high-priority focus', () {
      final plan = planFor(strengthAssessment.copyWith(profile: fullGym()));
      final quad = plan.focusAreas.firstWhere(
        (area) => area.type == FocusAreaType.quadStrength,
      );
      expect(quad.priority, FocusPriority.high);
      expect(quad.detail, contains('65%'));
      final quadWork = exercisesOf(plan).where(
        (item) =>
            item.purpose == TrainingPurpose.quadStrength ||
            item.purpose == TrainingPurpose.singleLegStrength,
      );
      expect(quadWork.length, greaterThanOrEqualTo(2));
    });

    test('limited extension puts extension work in every session', () {
      final plan = planFor(
        testAssessment(
          weeks: 7,
          extension: false,
          readiness: loadingReadiness(),
          profile: const TrainingProfile(minutesPerSession: 20),
        ),
      );
      expect(plan.focusAreas.first.type, FocusAreaType.extension);
      for (final session in plan.sessions) {
        expect(
          session.exercises.any(
            (item) =>
                ExerciseCatalog.byId(item.exerciseId)!.purpose ==
                TrainingPurpose.kneeExtension,
          ),
          isTrue,
          reason: '${session.name} is missing extension work',
        );
      }
    });

    test('the goal controls late-stage drills', () {
      final base = testAssessment(weeks: 30, readiness: returnToSportReadiness);
      final sport = planFor(base.copyWith(profile: fullGym()));
      final daily = planFor(
        base.copyWith(profile: fullGym(goal: RecoveryGoal.dailyActivities)),
      );

      expect(sport.phase, RehabPhase.returnToSport);
      expect(
        exercisesOf(
          sport,
        ).any((item) => item.purpose == TrainingPurpose.changeOfDirection),
        isTrue,
      );
      expect(
        exercisesOf(daily).where((item) => item.isHighImpact),
        isEmpty,
        reason: 'everyday-function goals do not need running or hopping',
      );
      expect(
        daily.excluded.any((note) => note.title == 'Left out for your goal'),
        isTrue,
      );
    });

    test('symptoms select easier variations and lighter dosing', () {
      final quiet = planFor(
        testAssessment(weeks: 7, readiness: loadingReadiness()),
      );
      final sore = planFor(
        testAssessment(
          weeks: 7,
          pain: 3,
          swelling: Swelling.mild,
          readiness: loadingReadiness(),
        ),
      );
      expect(quiet.exerciseIds, contains('box-squat'));
      expect(sore.exerciseIds, contains('sit-to-stand'));
      expect(sore.exerciseIds, isNot(contains('box-squat')));
      expect(
        sore.rationale.any((note) => note.title == 'Dosed for your symptoms'),
        isTrue,
      );
    });

    test('restrictions are never violated', () {
      final plan = planFor(
        testAssessment(
          weeks: 13,
          readiness: loadingReadiness(quad: 85, balance: 85),
          restrictions: const ['No Deep Squats', 'No Open Chain Extension'],
          profile: fullGym(),
        ),
      );
      for (final exercise in exercisesOf(plan)) {
        expect(
          exercise.criteriaRequired.blockingRestrictions,
          isNot(
            anyOf(
              contains('No Deep Squats'),
              contains('No Open Chain Extension'),
            ),
          ),
          reason: '${exercise.name} is blocked by a restriction',
        );
      }
    });

    test('hamstring grafts keep hamstring work unresisted and low volume', () {
      final plan = planFor(
        testAssessment(
          weeks: 8,
          graft: GraftType.hamstring,
          readiness: loadingReadiness(),
          profile: fullGym(),
        ),
      );
      for (final item in plan.allExercises) {
        final exercise = ExerciseCatalog.byId(item.exerciseId)!;
        if (exercise.purpose != TrainingPurpose.hamstringStrength) continue;
        expect(
          exercise.criteriaRequired.minimumWeeksForHamstringGraft ?? 0,
          lessThan(12),
        );
        expect(item.prescription.sets, lessThanOrEqualTo(2));
      }
      expect(
        plan.rationale.any(
          (note) => note.title == 'Hamstring graft precautions',
        ),
        isTrue,
      );
    });

    test('instability limits the plan and raises a clinical warning', () {
      final plan = planFor(
        testAssessment(
          weeks: 20,
          instability: true,
          readiness: loadingReadiness(),
        ),
      );
      expect(plan.phase, RehabPhase.protectionAndMotion);
      final clinical = plan.validation.checks.firstWhere(
        (check) => check.id == 'clinical',
      );
      expect(clinical.status, CheckStatus.warning);
      expect(plan.focusAreas.first.type, FocusAreaType.mechanicalSymptoms);
    });
  });

  group('Plan quality validation', () {
    final personas = <String, Assessment>{
      'early protection': testAssessment(
        weeks: 2,
        graft: GraftType.hamstring,
        pain: 4,
        swelling: Swelling.moderate,
        extension: false,
        flexion: false,
        weightBearing: WeightBearing.partial,
        walking: WalkingQuality.antalgic,
      ),
      'home strengthening': testAssessment(
        weeks: 7,
        pain: 3,
        swelling: Swelling.mild,
        readiness: loadingReadiness(),
        profile: const TrainingProfile(minutesPerSession: 15),
      ),
      'gym advanced': strengthAssessment.copyWith(
        profile: fullGym(sessions: 6),
      ),
      'return to sport': testAssessment(
        weeks: 30,
        readiness: returnToSportReadiness,
        profile: fullGym(sessions: 4),
      ),
    };

    personas.forEach((name, assessment) {
      test('$name: every final exercise is unlocked, owned, and on time', () {
        final plan = planFor(assessment);
        expect(plan.validation.checks.length, 14);
        for (final exercise in exercisesOf(plan)) {
          expect(
            exercise.unlockStatus(assessment, null).isUnlocked,
            isTrue,
            reason: '${exercise.name} is locked',
          );
          expect(exercise.isAvailableWith(assessment.profile), isTrue);
          expect(exercise.phase.order, lessThanOrEqualTo(plan.phase.order));
        }
        for (final session in plan.sessions) {
          expect(
            session.estimatedMinutes,
            lessThanOrEqualTo(assessment.profile.minutesPerSession + 3),
            reason: '${session.name} is longer than the user has',
          );
          final ids = session.exercises.map((item) => item.exerciseId);
          expect(ids.toSet().length, ids.length, reason: 'duplicate exercise');
        }
        expect(plan.weeklySchedule, hasLength(7));
      });
    });

    test('an unrealistic number of strength days is capped', () {
      final plan = planFor(
        strengthAssessment.copyWith(profile: fullGym(sessions: 6)),
      );
      expect(plan.sessionsPerWeek, 4);
      expect(
        plan.weeklySchedule.where((day) => day == PlanGenerator.lightDayLabel),
        hasLength(2),
      );
      final weekly = plan.validation.checks.firstWhere(
        (check) => check.id == 'weekly',
      );
      expect(weekly.status, CheckStatus.adjusted);
    });

    test('short sessions are trimmed and the trim is reported', () {
      final plan = planFor(
        strengthAssessment.copyWith(profile: fullGym(minutes: 15, sessions: 3)),
      );
      final time = plan.validation.checks.firstWhere(
        (check) => check.id == 'time',
      );
      expect(time.status, isNot(CheckStatus.passed));
      for (final session in plan.sessions) {
        expect(session.estimatedMinutes, lessThanOrEqualTo(18));
      }
    });

    test('contradictory answers are flagged and handled cautiously', () {
      final plan = planFor(
        testAssessment(
          weeks: 7,
          weightBearing: WeightBearing.partial,
          walking: WalkingQuality.normal,
          readiness: loadingReadiness(),
        ),
      );
      final answers = plan.validation.checks.firstWhere(
        (check) => check.id == 'answers',
      );
      expect(answers.status, CheckStatus.warning);
      expect(answers.detail, contains('weight bearing'));
      // Partial weight bearing keeps loaded strengthening locked.
      expect(plan.phase, RehabPhase.protectionAndMotion);
    });
  });

  group('Adaptation between plan versions', () {
    test('an exercise at its top level moves to a harder variation', () {
      final assessment = testAssessment(
        weeks: 7,
        pain: 3,
        swelling: Swelling.mild,
        readiness: loadingReadiness(),
        profile: fullGym(),
      );
      final first = planFor(assessment);
      expect(first.exerciseIds, contains('sit-to-stand'));

      final next = planFor(
        assessment,
        previous: first,
        progressions: {
          'sit-to-stand': level(
            'sit-to-stand',
            ExerciseProgressionState.maxLevel,
          ),
        },
      );
      expect(next.exerciseIds, isNot(contains('sit-to-stand')));
      final replacement = next.allExercises.firstWhere(
        (item) => item.reason.contains('Progressed from Sit-To-Stand'),
      );
      expect(
        PlanContext.rank(ExerciseCatalog.byId(replacement.exerciseId)!),
        greaterThan(PlanContext.rank(ExerciseCatalog.byId('sit-to-stand')!)),
      );
    });

    test('at the ceiling of its phase an exercise stays until retesting', () {
      final assessment = testAssessment(
        weeks: 7,
        readiness: loadingReadiness(),
        profile: fullGym(),
      );
      final first = planFor(assessment);
      final next = planFor(
        assessment,
        previous: first,
        progressions: {
          'box-squat': level('box-squat', ExerciseProgressionState.maxLevel),
        },
      );
      // No harder quad exercise is unlocked in Phase 2, so the slot keeps
      // Box Squat and the reassessment advisor takes over from here.
      expect(next.exerciseIds, contains('box-squat'));
    });

    test('repeated "too hard" feedback moves to an easier variation', () {
      final assessment = testAssessment(
        weeks: 7,
        readiness: loadingReadiness(),
        profile: fullGym(),
      );
      final first = planFor(assessment);
      final next = planFor(
        assessment,
        previous: first,
        progressions: {
          'box-squat': level('box-squat', ExerciseProgressionState.minLevel),
        },
      );
      expect(next.exerciseIds, isNot(contains('box-squat')));
      expect(next.exerciseIds, contains('sit-to-stand'));
    });

    test('unchanged answers keep the same exercises', () {
      final assessment = strengthAssessment.copyWith(profile: fullGym());
      final first = planFor(assessment);
      final second = planFor(assessment, previous: first);
      expect(second.exerciseIds, first.exerciseIds);
    });

    test('plans survive a JSON round trip', () {
      final plan = planFor(strengthAssessment.copyWith(profile: fullGym()));
      final decoded = RehabPlan.fromJson(
        jsonDecode(jsonEncode(plan.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.exerciseIds, plan.exerciseIds);
      expect(decoded.validation.checks.length, plan.validation.checks.length);
      expect(
        decoded.focusAreas.map((area) => area.type),
        plan.focusAreas.map((area) => area.type),
      );
      expect(decoded.weeklySchedule, plan.weeklySchedule);
    });
  });
}
