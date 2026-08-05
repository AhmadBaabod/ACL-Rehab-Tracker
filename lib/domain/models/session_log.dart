enum ExerciseFeedback { tooEasy, justRight, tooHard }

enum ProgressionRecommendation { regress, maintain, progress }

extension ExerciseFeedbackX on ExerciseFeedback {
  String get label {
    switch (this) {
      case ExerciseFeedback.tooEasy:
        return 'Too Easy';
      case ExerciseFeedback.justRight:
        return 'Just Right';
      case ExerciseFeedback.tooHard:
        return 'Too Hard';
    }
  }

  ProgressionRecommendation get recommendation {
    switch (this) {
      case ExerciseFeedback.tooEasy:
        return ProgressionRecommendation.progress;
      case ExerciseFeedback.justRight:
        return ProgressionRecommendation.maintain;
      case ExerciseFeedback.tooHard:
        return ProgressionRecommendation.regress;
    }
  }
}

extension ProgressionRecommendationX on ProgressionRecommendation {
  String get label {
    switch (this) {
      case ProgressionRecommendation.regress:
        return 'Regression recommended';
      case ProgressionRecommendation.maintain:
        return 'Keep current level';
      case ProgressionRecommendation.progress:
        return 'Progression recommended';
    }
  }
}

class SessionLog {
  const SessionLog({
    required this.exerciseId,
    required this.exerciseName,
    required this.feedback,
    required this.createdAt,
    required this.recommendation,
    this.painAfter,
    this.notes = '',
  });

  final String exerciseId;
  final String exerciseName;
  final ExerciseFeedback feedback;
  final DateTime createdAt;
  final ProgressionRecommendation recommendation;
  final int? painAfter;
  final String notes;

  Map<String, dynamic> toJson() {
    return {
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'feedback': feedback.name,
      'createdAt': createdAt.toIso8601String(),
      'recommendation': recommendation.name,
      'painAfter': painAfter,
      'notes': notes,
    };
  }

  factory SessionLog.fromJson(Map<String, dynamic> data) {
    final rawFeedback =
        data['feedback'] as String? ?? ExerciseFeedback.justRight.name;
    final feedback = ExerciseFeedback.values.firstWhere(
      (item) => item.name == rawFeedback || item.label == rawFeedback,
      orElse: () => ExerciseFeedback.justRight,
    );

    return SessionLog(
      exerciseId: data['exerciseId'] as String? ?? '',
      exerciseName: data['exerciseName'] as String? ?? 'Exercise',
      feedback: feedback,
      createdAt:
          DateTime.tryParse(data['createdAt'] as String? ?? '') ??
          DateTime.now(),
      recommendation: ProgressionRecommendation.values.firstWhere(
        (item) => item.name == data['recommendation'],
        orElse: () => feedback.recommendation,
      ),
      painAfter: data['painAfter'] as int?,
      notes: data['notes'] as String? ?? '',
    );
  }
}

class ExerciseProgressionState {
  const ExerciseProgressionState({
    required this.exerciseId,
    required this.recommendation,
    required this.updatedAt,
    this.timesCompleted = 0,
  });

  final String exerciseId;
  final ProgressionRecommendation recommendation;
  final DateTime updatedAt;
  final int timesCompleted;

  ExerciseProgressionState record(ExerciseFeedback feedback) {
    return ExerciseProgressionState(
      exerciseId: exerciseId,
      recommendation: feedback.recommendation,
      updatedAt: DateTime.now(),
      timesCompleted: timesCompleted + 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exerciseId': exerciseId,
      'recommendation': recommendation.name,
      'updatedAt': updatedAt.toIso8601String(),
      'timesCompleted': timesCompleted,
    };
  }

  factory ExerciseProgressionState.fromJson(Map<String, dynamic> data) {
    return ExerciseProgressionState(
      exerciseId: data['exerciseId'] as String? ?? '',
      recommendation: ProgressionRecommendation.values.firstWhere(
        (item) => item.name == data['recommendation'],
        orElse: () => ProgressionRecommendation.maintain,
      ),
      updatedAt:
          DateTime.tryParse(data['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      timesCompleted: data['timesCompleted'] as int? ?? 0,
    );
  }
}
