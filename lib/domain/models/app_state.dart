import 'package:acl_rehab/domain/models/assessment.dart';
import 'package:acl_rehab/domain/models/milestone_check_in.dart';
import 'package:acl_rehab/domain/models/session_log.dart';

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
  });

  final Assessment? assessment;
  final DateTime? assessmentUpdatedAt;
  final bool onboardingCompleted;
  final int selectedIndex;
  final String themeMode;
  final List<SessionLog> sessionLogs;
  final Map<String, ExerciseProgressionState> exerciseProgressions;
  final List<MilestoneCheckIn> milestoneCheckIns;

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
    };
  }

  factory AppState.fromJson(Map<String, dynamic> data) {
    final assessmentData = data['assessment'];
    final rawProgressions =
        data['exerciseProgressions'] as Map<dynamic, dynamic>? ?? const {};

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
    );
  }
}
