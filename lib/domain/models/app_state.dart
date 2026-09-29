import 'package:acl_rehab/domain/models/assessment.dart';
import 'package:acl_rehab/domain/models/assessment_record.dart';
import 'package:acl_rehab/domain/models/milestone_check_in.dart';
import 'package:acl_rehab/domain/models/rehab_plan.dart';
import 'package:acl_rehab/domain/models/session_log.dart';
import 'package:acl_rehab/domain/models/workout_log.dart';

class AppState {
  const AppState({
    this.assessment,
    this.assessmentUpdatedAt,
    this.onboardingCompleted = false,
    this.selectedIndex = 0,
    this.themeMode = 'system',
    this.sessionLogs = const [],
    this.exerciseProgressions = const {},
    this.milestoneCheckIns = const [],
    this.assessmentHistory = const [],
    this.plans = const [],
    this.workoutLogs = const [],
    this.reassessmentSnoozedUntil,
  });

  final Assessment? assessment;
  final DateTime? assessmentUpdatedAt;
  final bool onboardingCompleted;
  final int selectedIndex;
  final String themeMode;
  final List<SessionLog> sessionLogs;
  final Map<String, ExerciseProgressionState> exerciseProgressions;
  final List<MilestoneCheckIn> milestoneCheckIns;

  /// Every saved assessment revision, oldest first.
  final List<AssessmentRecord> assessmentHistory;

  /// Every generated plan, oldest first. The last one is active.
  final List<RehabPlan> plans;

  /// Completed workouts, oldest first.
  final List<WorkoutLog> workoutLogs;
  final DateTime? reassessmentSnoozedUntil;

  RehabPlan? get activePlan => plans.isEmpty ? null : plans.last;

  RehabPlan? get previousPlan =>
      plans.length < 2 ? null : plans[plans.length - 2];

  AssessmentRecord? get latestAssessmentRecord =>
      assessmentHistory.isEmpty ? null : assessmentHistory.last;

  AssessmentRecord? recordById(String? id) {
    if (id == null) return null;
    for (final record in assessmentHistory) {
      if (record.id == id) return record;
    }
    return null;
  }

  /// The record saved immediately before [record], if any.
  AssessmentRecord? recordBefore(AssessmentRecord record) {
    final index = assessmentHistory.indexWhere((item) => item.id == record.id);
    return index <= 0 ? null : assessmentHistory[index - 1];
  }

  RehabPlan? planForRecord(String recordId) {
    for (final plan in plans.reversed) {
      if (plan.assessmentRecordId == recordId) return plan;
    }
    return null;
  }

  /// The latest check-in recorded before [time], used to reconstruct the
  /// status that a reassessment is compared against.
  MilestoneCheckIn? latestCheckInBefore(DateTime time, {DateTime? since}) {
    final candidates = milestoneCheckIns.where(
      (item) =>
          item.createdAt.isBefore(time) &&
          (since == null || !item.createdAt.isBefore(since)),
    );
    if (candidates.isEmpty) return null;
    return candidates.reduce(
      (a, b) => a.createdAt.isAfter(b.createdAt) ? a : b,
    );
  }

  /// The session to do next, rotating A -> B -> A through the active plan.
  PlanSession? get nextSession {
    final plan = activePlan;
    if (plan == null || plan.sessions.isEmpty) return null;
    final logs = workoutLogs.where((log) => log.planId == plan.id).toList();
    if (logs.isEmpty) return plan.sessions.first;
    final last = logs.reduce(
      (a, b) => a.completedAt.isAfter(b.completedAt) ? a : b,
    );
    final index = plan.sessions.indexWhere(
      (session) => session.id == last.sessionId,
    );
    return plan.sessions[(index + 1) % plan.sessions.length];
  }

  /// Workouts completed since Monday of the current week.
  int workoutsThisWeek(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return workoutLogs.where((log) => !log.completedAt.isBefore(monday)).length;
  }

  WorkoutLog? get latestWorkout => workoutLogs.isEmpty
      ? null
      : workoutLogs.reduce(
          (a, b) => a.completedAt.isAfter(b.completedAt) ? a : b,
        );

  List<MilestoneCheckIn> get activeMilestoneCheckIns {
    final updatedAt = assessmentUpdatedAt;
    if (updatedAt == null) {
      return milestoneCheckIns;
    }

    return milestoneCheckIns
        .where(
          (checkIn) =>
              checkIn.createdAt.isAtSameMomentAs(updatedAt) ||
              checkIn.createdAt.isAfter(updatedAt),
        )
        .toList();
  }

  MilestoneCheckIn? get latestMilestone {
    final activeCheckIns = activeMilestoneCheckIns;
    if (activeCheckIns.isEmpty) {
      return null;
    }
    final ordered = [...activeCheckIns]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return ordered.first;
  }

  SessionLog? latestLogFor(String exerciseId) {
    final logs =
        sessionLogs.where((log) => log.exerciseId == exerciseId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return logs.isEmpty ? null : logs.first;
  }

  AppState copyWith({
    Assessment? assessment,
    DateTime? assessmentUpdatedAt,
    bool? onboardingCompleted,
    int? selectedIndex,
    String? themeMode,
    List<SessionLog>? sessionLogs,
    Map<String, ExerciseProgressionState>? exerciseProgressions,
    List<MilestoneCheckIn>? milestoneCheckIns,
    List<AssessmentRecord>? assessmentHistory,
    List<RehabPlan>? plans,
    List<WorkoutLog>? workoutLogs,
    DateTime? reassessmentSnoozedUntil,
    bool clearReassessmentSnooze = false,
  }) {
    return AppState(
      assessment: assessment ?? this.assessment,
      assessmentUpdatedAt: assessmentUpdatedAt ?? this.assessmentUpdatedAt,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      themeMode: themeMode ?? this.themeMode,
      sessionLogs: sessionLogs ?? this.sessionLogs,
      exerciseProgressions: exerciseProgressions ?? this.exerciseProgressions,
      milestoneCheckIns: milestoneCheckIns ?? this.milestoneCheckIns,
      assessmentHistory: assessmentHistory ?? this.assessmentHistory,
      plans: plans ?? this.plans,
      workoutLogs: workoutLogs ?? this.workoutLogs,
      reassessmentSnoozedUntil: clearReassessmentSnooze
          ? null
          : reassessmentSnoozedUntil ?? this.reassessmentSnoozedUntil,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'assessment': assessment?.toJson(),
      'assessmentUpdatedAt': assessmentUpdatedAt?.toIso8601String(),
      'onboardingCompleted': onboardingCompleted,
      'selectedIndex': selectedIndex,
      'themeMode': themeMode,
      'sessionLogs': sessionLogs.map((item) => item.toJson()).toList(),
      'exerciseProgressions': exerciseProgressions.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'milestoneCheckIns': milestoneCheckIns
          .map((item) => item.toJson())
          .toList(),
      'assessmentHistory': assessmentHistory
          .map((item) => item.toJson())
          .toList(),
      'plans': plans.map((item) => item.toJson()).toList(),
      'workoutLogs': workoutLogs.map((item) => item.toJson()).toList(),
      'reassessmentSnoozedUntil': reassessmentSnoozedUntil?.toIso8601String(),
    };
  }

  factory AppState.fromJson(Map<String, dynamic> data) {
    final assessmentData = data['assessment'];
    final rawProgressions =
        data['exerciseProgressions'] as Map<dynamic, dynamic>? ?? const {};
    List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) {
      return (data[key] as List<dynamic>? ?? const [])
          .map((item) => parse(Map<String, dynamic>.from(item as Map)))
          .toList();
    }

    return AppState(
      assessment: assessmentData == null
          ? null
          : Assessment.fromJson(
              Map<String, dynamic>.from(assessmentData as Map),
            ),
      assessmentUpdatedAt: DateTime.tryParse(
        data['assessmentUpdatedAt'] as String? ?? '',
      ),
      onboardingCompleted: data['onboardingCompleted'] as bool? ?? false,
      selectedIndex: data['selectedIndex'] as int? ?? 0,
      themeMode: data['themeMode'] as String? ?? 'system',
      sessionLogs: (data['sessionLogs'] as List<dynamic>? ?? const [])
          .map(
            (item) =>
                SessionLog.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      exerciseProgressions: rawProgressions.map(
        (key, value) => MapEntry(
          key.toString(),
          ExerciseProgressionState.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        ),
      ),
      milestoneCheckIns:
          (data['milestoneCheckIns'] as List<dynamic>? ?? const [])
              .map(
                (item) => MilestoneCheckIn.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList(),
      assessmentHistory: list('assessmentHistory', AssessmentRecord.fromJson),
      plans: list('plans', RehabPlan.fromJson),
      workoutLogs: list('workoutLogs', WorkoutLog.fromJson),
      reassessmentSnoozedUntil: DateTime.tryParse(
        data['reassessmentSnoozedUntil'] as String? ?? '',
      ),
    );
  }
}
