import 'dart:async';

import 'package:acl_rehab/data/repositories/app_state_repository.dart';
import 'package:acl_rehab/domain/models/app_state.dart';
import 'package:acl_rehab/domain/models/assessment.dart';
import 'package:acl_rehab/domain/models/milestone_check_in.dart';
import 'package:acl_rehab/domain/models/session_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appStateRepositoryProvider = Provider<AppStateRepository>((ref) {
  throw UnimplementedError('Repository needs to be overridden');
});

final appControllerProvider = AsyncNotifierProvider<AppController, AppState>(
  AppController.new,
);

class AppController extends AsyncNotifier<AppState> {
  late final AppStateRepository _repository;

  @override
  FutureOr<AppState> build() async {
    _repository = ref.watch(appStateRepositoryProvider);
    return _repository.load();
  }

  Future<void> completeOnboarding(Assessment assessment) async {
    final current = await _currentState();
    final updated = current.copyWith(
      assessment: assessment,
      assessmentUpdatedAt: DateTime.now(),
      onboardingCompleted: true,
      selectedIndex: 0,
    );
    await _save(updated);
  }

  Future<void> retakeInitialAssessment() async {
    final current = await _currentState();
    await _save(current.copyWith(onboardingCompleted: false, selectedIndex: 0));
  }

  Future<void> addSessionFeedback({
    required String exerciseId,
    required String exerciseName,
    required ExerciseFeedback feedback,
    int? painAfter,
    String notes = '',
  }) async {
    final current = await _currentState();
    final existingProgression =
        current.exerciseProgressions[exerciseId] ??
        ExerciseProgressionState(
          exerciseId: exerciseId,
          recommendation: ProgressionRecommendation.maintain,
          updatedAt: DateTime.now(),
        );

    final updatedProgressions = Map<String, ExerciseProgressionState>.from(
      current.exerciseProgressions,
    )..[exerciseId] = existingProgression.record(feedback);

    final updated = current.copyWith(
      sessionLogs: [
        ...current.sessionLogs,
        SessionLog(
          exerciseId: exerciseId,
          exerciseName: exerciseName,
          feedback: feedback,
          createdAt: DateTime.now(),
          recommendation: feedback.recommendation,
          painAfter: painAfter,
          notes: notes,
        ),
      ],
      exerciseProgressions: updatedProgressions,
    );
    await _save(updated);
  }

  Future<void> addMilestoneCheckIn(MilestoneCheckIn checkIn) async {
    final current = await _currentState();
    final updated = current.copyWith(
      milestoneCheckIns: [...current.milestoneCheckIns, checkIn],
    );
    await _save(updated);
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    final current = await _currentState();
    await _save(current.copyWith(themeMode: mode.name));
  }

  Future<void> updateSelectedIndex(int index) async {
    final current = await _currentState();
    await _save(current.copyWith(selectedIndex: index));
  }

  Future<AppState> _currentState() async {
    return state.value ?? await future;
  }

  Future<void> _save(AppState updated) async {
    state = AsyncValue.data(updated);
    try {
      await _repository.save(updated);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}
