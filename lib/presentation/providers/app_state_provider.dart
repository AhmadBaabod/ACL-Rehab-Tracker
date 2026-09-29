import 'dart:async';

import 'package:acl_rehab/core/navigation/app_tabs.dart';
import 'package:acl_rehab/core/utils/phase_logic.dart';
import 'package:acl_rehab/data/exercise_catalog.dart';
import 'package:acl_rehab/data/repositories/app_state_repository.dart';
import 'package:acl_rehab/domain/models/app_state.dart';
import 'package:acl_rehab/domain/models/assessment.dart';
import 'package:acl_rehab/domain/models/assessment_record.dart';
import 'package:acl_rehab/domain/models/exercise.dart';
import 'package:acl_rehab/domain/models/milestone_check_in.dart';
import 'package:acl_rehab/domain/models/rehab_plan.dart';
import 'package:acl_rehab/domain/models/session_log.dart';
import 'package:acl_rehab/domain/models/training_profile.dart';
import 'package:acl_rehab/domain/models/workout_log.dart';
import 'package:acl_rehab/domain/services/assessment_comparison.dart';
import 'package:acl_rehab/domain/services/plan_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appStateRepositoryProvider = Provider<AppStateRepository>((ref) {
  throw UnimplementedError('Repository needs to be overridden');
});

final appControllerProvider = AsyncNotifierProvider<AppController, AppState>(
  AppController.new,
);

/// Summary of a plan regeneration, used for user feedback.
class PlanUpdate {
  const PlanUpdate({required this.plan, required this.diff, this.previous});

  final RehabPlan plan;
  final RehabPlan? previous;
  final PlanDiff diff;

  bool get phaseChanged => previous != null && previous!.phase != plan.phase;

  bool get isNewVersion => previous == null || previous!.id != plan.id;
}

class AppController extends AsyncNotifier<AppState> {
  late AppStateRepository _repository;

  @override
  FutureOr<AppState> build() async {
    _repository = ref.watch(appStateRepositoryProvider);
    final loaded = await _repository.load();
    final migrated = _ensureDerivedState(loaded);
    if (!identical(migrated, loaded)) {
      await _repository.save(migrated);
    }
    return migrated;
  }

  /// Data saved before assessment history and plans existed gets a baseline
  /// record and a generated plan, so existing users keep working.
  AppState _ensureDerivedState(AppState state) {
    final assessment = state.assessment;
    if (!state.onboardingCompleted || assessment == null) return state;
    var updated = state;
    if (updated.assessmentHistory.isEmpty) {
      updated = updated.copyWith(
        assessmentHistory: [
          _record(
            assessment,
            AssessmentKind.initial,
            updated.assessmentUpdatedAt ?? DateTime.now(),
          ),
        ],
      );
    }
    if (updated.plans.isEmpty) {
      updated = updated.copyWith(
        plans: [
          _generate(
            updated,
            assessment: assessment,
            milestone: updated.latestMilestone,
            trigger: PlanTrigger.initial,
            recordId: updated.latestAssessmentRecord?.id,
          ),
        ],
      );
    }
    return updated;
  }

  AssessmentRecord _record(
    Assessment assessment,
    AssessmentKind kind,
    DateTime createdAt,
  ) {
    return AssessmentRecord(
      id: 'assessment-${createdAt.microsecondsSinceEpoch}',
      createdAt: createdAt,
      kind: kind,
      assessment: assessment,
      phase: evaluateRehabPhase(assessment).phase,
    );
  }

  RehabPlan _generate(
    AppState state, {
    required Assessment assessment,
    required MilestoneCheckIn? milestone,
    required PlanTrigger trigger,
    required String? recordId,
    DateTime? now,
  }) {
    return PlanGenerator.generate(
      PlanGenerationInput(
        assessment: assessment,
        milestone: milestone,
        progressions: state.exerciseProgressions,
        previousPlan: state.activePlan,
        trigger: trigger,
        assessmentRecordId: recordId,
        version: state.plans.length + 1,
        now: now,
      ),
    );
  }

  /// Saves the first assessment, or a corrected one ([AssessmentKind.retake]),
  /// and generates a plan from it.
  Future<void> completeOnboarding(
    Assessment assessment, {
    AssessmentKind kind = AssessmentKind.initial,
  }) async {
    final current = await _currentState();
    final now = DateTime.now();
    final record = _record(assessment, kind, now);
    // A new assessment revision supersedes earlier check-ins.
    final plan = _generate(
      current,
      assessment: assessment,
      milestone: null,
      trigger: kind == AssessmentKind.retake
          ? PlanTrigger.retake
          : PlanTrigger.initial,
      recordId: record.id,
      now: now,
    );
    await _save(
      current.copyWith(
        assessment: assessment,
        assessmentUpdatedAt: now,
        onboardingCompleted: true,
        selectedIndex: AppTab.plan.index,
        assessmentHistory: [...current.assessmentHistory, record],
        plans: [...current.plans, plan],
        clearReassessmentSnooze: true,
      ),
    );
  }

  /// Saves a retest and adapts the plan. Returns the new record's id so the
  /// caller can show the before/after comparison.
  Future<String> completeReassessment(Assessment assessment) async {
    final current = await _currentState();
    final now = DateTime.now();
    final record = _record(assessment, AssessmentKind.reassessment, now);
    final plan = _generate(
      current,
      assessment: assessment,
      milestone: null,
      trigger: PlanTrigger.reassessment,
      recordId: record.id,
      now: now,
    );
    await _save(
      current.copyWith(
        assessment: assessment,
        assessmentUpdatedAt: now,
        assessmentHistory: [...current.assessmentHistory, record],
        plans: [...current.plans, plan],
        clearReassessmentSnooze: true,
      ),
    );
    return record.id;
  }

  /// Regenerates the plan with the current data, keeping the existing plan
  /// when nothing would change.
  Future<PlanUpdate?> _replan(AppState state, PlanTrigger trigger) async {
    final assessment = state.assessment;
    if (assessment == null) {
      await _save(state);
      return null;
    }
    final previous = state.activePlan;
    final candidate = _generate(
      state,
      assessment: assessment,
      milestone: state.latestMilestone,
      trigger: trigger,
      recordId: state.latestAssessmentRecord?.id,
    );
    final diff = PlanDiff.between(previous, candidate);
    final changed =
        previous == null ||
        !diff.isEmpty ||
        previous.phase != candidate.phase ||
        previous.sessionsPerWeek != candidate.sessionsPerWeek ||
        previous.minutesPerSession != candidate.minutesPerSession ||
        previous.goal != candidate.goal;
    if (!changed) {
      await _save(state);
      return PlanUpdate(plan: previous, previous: previous, diff: diff);
    }
    await _save(state.copyWith(plans: [...state.plans, candidate]));
    return PlanUpdate(plan: candidate, previous: previous, diff: diff);
  }

  Future<PlanUpdate?> addMilestoneCheckIn(MilestoneCheckIn checkIn) async {
    final current = await _currentState();
    return _replan(
      current.copyWith(
        milestoneCheckIns: [...current.milestoneCheckIns, checkIn],
      ),
      PlanTrigger.checkIn,
    );
  }

  /// Updates goals, schedule, or equipment and rebuilds the plan to match.
  Future<PlanUpdate?> updateTrainingProfile(TrainingProfile profile) async {
    final current = await _currentState();
    final assessment = current.assessment;
    if (assessment == null) return null;
    return _replan(
      current.copyWith(
        assessment: assessment.copyWith(
          profile: profile.copyWith(isDefault: false),
        ),
      ),
      PlanTrigger.profileChange,
    );
  }

  /// Records feedback for one exercise and returns its new progression state.
  Future<ExerciseProgressionState> addSessionFeedback({
    required String exerciseId,
    required String exerciseName,
    required ExerciseFeedback feedback,
    int? painAfter,
    String notes = '',
    String? workoutId,
    int? setsCompleted,
    int? setsPlanned,
  }) async {
    final current = await _currentState();
    final existingProgression =
        current.exerciseProgressions[exerciseId] ??
        ExerciseProgressionState(
          exerciseId: exerciseId,
          recommendation: ProgressionRecommendation.maintain,
          updatedAt: DateTime.now(),
        );
    final next = existingProgression.record(feedback, painAfter: painAfter);

    await _save(
      current.copyWith(
        sessionLogs: [
          ...current.sessionLogs,
          SessionLog(
            exerciseId: exerciseId,
            exerciseName: exerciseName,
            feedback: feedback,
            createdAt: DateTime.now(),
            recommendation: next.recommendation,
            painAfter: painAfter,
            notes: notes,
            workoutId: workoutId,
            setsCompleted: setsCompleted,
            setsPlanned: setsPlanned,
          ),
        ],
        exerciseProgressions: {
          ...current.exerciseProgressions,
          exerciseId: next,
        },
      ),
    );
    return next;
  }

  Future<void> completeWorkout(WorkoutLog log) async {
    final current = await _currentState();
    await _save(current.copyWith(workoutLogs: [...current.workoutLogs, log]));
  }

  /// Permanently uses [toExerciseId] in place of [fromExerciseId] in the
  /// active plan, dosed for the user.
  Future<void> swapPlanExercise({
    required String fromExerciseId,
    required String toExerciseId,
  }) async {
    final current = await _currentState();
    final plan = current.activePlan;
    final assessment = current.assessment;
    final from = ExerciseCatalog.byId(fromExerciseId);
    final to = ExerciseCatalog.byId(toExerciseId);
    if (plan == null || assessment == null || from == null || to == null) {
      return;
    }
    final context = PlanContext.from(
      PlanGenerationInput(
        assessment: assessment,
        milestone: current.latestMilestone,
        progressions: current.exerciseProgressions,
      ),
    );
    final focus = context.focusFor(to.purpose);
    final sessions = [
      for (final session in plan.sessions)
        session.copyWith(
          exercises: [
            for (final item in session.exercises)
              if (item.exerciseId == fromExerciseId)
                PlanExercise(
                  exerciseId: to.id,
                  prescription: context.prescribe(to, focus: focus),
                  reason:
                      'Your choice, replacing ${from.name} for the same goal '
                      '(${to.purpose.label.toLowerCase()}).',
                  priority: item.priority,
                  focus: item.focus,
                  substitutedFromId: item.substitutedFromId ?? from.id,
                  substitutionReason:
                      'You chose ${to.name} instead of ${from.name}.',
                )
              else
                item,
          ],
        ),
    ];
    final updatedSessions = [
      for (final session in sessions)
        session.copyWith(
          estimatedMinutes: PlanGenerator.sessionMinutes(session.exercises),
        ),
    ];
    await _save(
      current.copyWith(
        plans: [
          ...current.plans.take(current.plans.length - 1),
          plan.copyWith(sessions: updatedSessions),
        ],
      ),
    );
  }

  Future<void> snoozeReassessment(Duration duration) async {
    final current = await _currentState();
    await _save(
      current.copyWith(reassessmentSnoozedUntil: DateTime.now().add(duration)),
    );
  }

  Future<void> updateWeightUnit(WeightUnit unit) async {
    final current = await _currentState();
    await _save(current.copyWith(weightUnit: unit));
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    final current = await _currentState();
    await _save(current.copyWith(themeMode: mode.name));
  }

  Future<void> updateSelectedIndex(int index) async {
    final current = await _currentState();
    await _save(current.copyWith(selectedIndex: index));
  }

  Future<void> selectTab(AppTab tab) => updateSelectedIndex(tab.index);

  Future<AppState> _currentState() async {
    return state.value ?? await future;
  }

  /// Updates the in-memory state, then persists it. Storage failures are
  /// rethrown so the calling screen can tell the user the change was not
  /// saved, instead of replacing the whole app with an error screen.
  Future<void> _save(AppState updated) async {
    state = AsyncValue.data(updated);
    await _repository.save(updated);
  }
}
