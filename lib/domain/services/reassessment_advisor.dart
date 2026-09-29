import 'package:acl_rehab/domain/models/app_state.dart';
import 'package:acl_rehab/domain/models/session_log.dart';

enum ReassessmentReason { none, improvement, ceiling, scheduled, symptoms }

class ReassessmentRecommendation {
  const ReassessmentRecommendation({
    required this.isDue,
    required this.reason,
    required this.title,
    required this.message,
    required this.evidence,
    required this.progress,
    this.dueDate,
  });

  final bool isDue;
  final ReassessmentReason reason;
  final String title;
  final String message;

  /// The observations that triggered (or are building toward) a retest.
  final List<String> evidence;

  /// 0-1 progress toward the next retest, for a progress bar.
  final double progress;
  final DateTime? dueDate;

  bool get isUrgent => reason == ReassessmentReason.symptoms;
}

/// Decides when the user should retest so the plan can adapt. A retest is
/// recommended when progress is meaningful (sessions logged, pain low, and
/// exercises progressing), when the plan has hit its ceiling, when the
/// scheduled interval has passed, or when symptoms suggest the plan is too
/// demanding.
class ReassessmentAdvisor {
  const ReassessmentAdvisor._();

  static const minDaysBetweenTests = 10;
  static const minWorkoutsForImprovement = 4;

  static ReassessmentRecommendation evaluate(AppState state, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final plan = state.activePlan;
    final lastTest =
        state.latestAssessmentRecord?.createdAt ??
        state.assessmentUpdatedAt ??
        plan?.createdAt;
    if (plan == null || lastTest == null) {
      return const ReassessmentRecommendation(
        isDue: false,
        reason: ReassessmentReason.none,
        title: 'Complete your assessment',
        message: 'Your first assessment creates your personalized plan.',
        evidence: [],
        progress: 0,
      );
    }

    final daysSince = today.difference(lastTest).inDays;
    final dueDate = lastTest.add(Duration(days: plan.reassessAfterDays));
    final workouts =
        state.workoutLogs
            .where((log) => log.completedAt.isAfter(lastTest))
            .toList()
          ..sort((a, b) => a.completedAt.compareTo(b.completedAt));
    final recent = workouts.length <= 3
        ? workouts
        : workouts.sublist(workouts.length - 3);
    final recentPain = recent.isEmpty
        ? null
        : recent.fold<int>(0, (sum, log) => sum + log.painAfter) /
              recent.length;

    final weekAgo = today.subtract(const Duration(days: 7));
    final tooHardRecent = state.sessionLogs
        .where(
          (log) =>
              log.createdAt.isAfter(weekAgo) &&
              log.createdAt.isAfter(lastTest) &&
              log.feedback == ExerciseFeedback.tooHard,
        )
        .length;

    final planIds = plan.exerciseIds;
    final levels = [
      for (final id in planIds)
        if (state.exerciseProgressions[id] case final progression?)
          if (progression.updatedAt.isAfter(lastTest)) progression.level,
    ];
    final progressed = levels.where((level) => level >= 2).length;
    final atCeiling = levels
        .where((level) => level >= ExerciseProgressionState.maxLevel)
        .length;
    final progressTarget = planIds.isEmpty ? 2 : (planIds.length / 2).ceil();

    // Safety first: symptoms override the minimum spacing between tests.
    if ((recentPain != null && recent.length >= 2 && recentPain >= 4) ||
        tooHardRecent >= 3) {
      return ReassessmentRecommendation(
        isDue: true,
        reason: ReassessmentReason.symptoms,
        title: 'Check in on your symptoms',
        message:
            'Recent sessions suggest the plan may be too demanding. Retest your '
            'symptoms so the plan can step back, and contact your clinical team '
            'if pain or swelling keeps rising.',
        evidence: [
          if (recentPain != null && recentPain >= 4)
            'Average pain after your last ${recent.length} sessions: '
                '${recentPain.toStringAsFixed(1)}/10',
          if (tooHardRecent >= 3)
            '$tooHardRecent exercises rated "too hard" this week',
        ],
        progress: 1,
        dueDate: today,
      );
    }

    final snoozed = state.reassessmentSnoozedUntil;
    final isSnoozed = snoozed != null && today.isBefore(snoozed);
    final spacingOk = daysSince >= minDaysBetweenTests;
    final painOk = recentPain == null || recentPain <= 2;

    ReassessmentRecommendation due(
      ReassessmentReason reason,
      String title,
      String message,
      List<String> evidence,
    ) {
      return ReassessmentRecommendation(
        isDue: !isSnoozed,
        reason: reason,
        title: title,
        message: isSnoozed
            ? '$message You chose to be reminded later.'
            : message,
        evidence: evidence,
        progress: 1,
        dueDate: isSnoozed ? snoozed : today,
      );
    }

    if (spacingOk && painOk && atCeiling >= progressTarget) {
      return due(
        ReassessmentReason.ceiling,
        'Ready for a harder plan',
        'Most of your exercises have reached their top level. Retest now so '
            'your next plan can move you to harder variations.',
        ['$atCeiling of ${planIds.length} exercises at their top level'],
      );
    }
    if (spacingOk &&
        painOk &&
        workouts.length >= minWorkoutsForImprovement &&
        progressed >= progressTarget) {
      return due(
        ReassessmentReason.improvement,
        'You have improved: time to retest',
        'Your sessions show meaningful progress. A reassessment will measure '
            'your new level and update the plan to match.',
        [
          '${workouts.length} sessions completed since your last test',
          '$progressed of ${planIds.length} exercises progressed',
          if (recentPain != null)
            'Pain after recent sessions: ${recentPain.toStringAsFixed(1)}/10',
        ],
      );
    }
    if (!today.isBefore(dueDate)) {
      return due(
        ReassessmentReason.scheduled,
        'Scheduled reassessment',
        'It has been $daysSince days since your last assessment. Retesting '
            'every 2-4 weeks keeps your plan matched to your recovery.',
        [
          '${workouts.length} sessions logged since your last test',
          if (progressed > 0) '$progressed exercises progressed',
        ],
      );
    }

    final workoutProgress = (workouts.length / minWorkoutsForImprovement).clamp(
      0.0,
      1.0,
    );
    final levelProgress = (progressed / progressTarget).clamp(0.0, 1.0);
    final timeProgress = (daysSince / plan.reassessAfterDays).clamp(0.0, 1.0);
    final improvementProgress = (workoutProgress + levelProgress) / 2;
    final daysLeft = dueDate.difference(today).inDays + 1;
    return ReassessmentRecommendation(
      isDue: false,
      reason: ReassessmentReason.none,
      title: 'Next reassessment in $daysLeft ${daysLeft == 1 ? 'day' : 'days'}',
      message:
          'Or sooner if you improve: log at least $minWorkoutsForImprovement '
          'sessions and progress $progressTarget exercises with low pain.',
      evidence: [
        '${workouts.length} of $minWorkoutsForImprovement sessions logged',
        '$progressed of $progressTarget exercises progressed',
      ],
      progress: improvementProgress > timeProgress
          ? improvementProgress
          : timeProgress,
      dueDate: dueDate,
    );
  }
}
