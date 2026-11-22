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
    this.workoutId,
    this.setsCompleted,
    this.setsPlanned,
  });

  final String exerciseId;
  final String exerciseName;
  final ExerciseFeedback feedback;
  final DateTime createdAt;
  final ProgressionRecommendation recommendation;
  final int? painAfter;
  final String notes;
  final String? workoutId;
  final int? setsCompleted;
  final int? setsPlanned;

  Map<String, dynamic> toJson() {
    return {
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'feedback': feedback.name,
      'createdAt': createdAt.toIso8601String(),
      'recommendation': recommendation.name,
      'painAfter': painAfter,
      'notes': notes,
      'workoutId': workoutId,
      'setsCompleted': setsCompleted,
      'setsPlanned': setsPlanned,
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
      workoutId: data['workoutId'] as String?,
      setsCompleted: data['setsCompleted'] as int?,
      setsPlanned: data['setsPlanned'] as int?,
    );
  }
}

/// Per-exercise dose level driven by session feedback.
///
/// Level 0 is the plan's starting dose. Each level adds (or removes) one set
/// and unlocks the exercise's progression (or regression) cue. At the maximum
/// level the plan generator moves the slot to a harder variation.
class ExerciseProgressionState {
  const ExerciseProgressionState({
    required this.exerciseId,
    required this.recommendation,
    required this.updatedAt,
    this.timesCompleted = 0,
    this.level = 0,
    this.consecutiveGood = 0,
  });

  static const minLevel = -2;
  static const maxLevel = 3;

  /// Pain after exercise at or above this value triggers a regression.
  static const regressPain = 5;

  /// Pain after exercise above this value holds the current dose.
  static const holdPain = 2;

  final String exerciseId;
  final ProgressionRecommendation recommendation;
  final DateTime updatedAt;
  final int timesCompleted;
  final int level;
  final int consecutiveGood;

  bool get atCeiling => level >= maxLevel;

  bool get atFloor => level <= minLevel;

  ExerciseProgressionState record(ExerciseFeedback feedback, {int? painAfter}) {
    final pain = painAfter ?? 0;
    var nextLevel = level;
    var nextGood = 0;
    ProgressionRecommendation nextRecommendation;

    if (feedback == ExerciseFeedback.tooHard || pain >= regressPain) {
      nextLevel = level - 1;
      nextRecommendation = ProgressionRecommendation.regress;
    } else if (pain > holdPain) {
      nextRecommendation = ProgressionRecommendation.maintain;
    } else if (feedback == ExerciseFeedback.tooEasy) {
      nextLevel = level + 1;
      nextRecommendation = ProgressionRecommendation.progress;
    } else {
      nextGood = consecutiveGood + 1;
      if (nextGood >= 2) {
        nextLevel = level + 1;
        nextGood = 0;
        nextRecommendation = ProgressionRecommendation.progress;
      } else {
        nextRecommendation = ProgressionRecommendation.maintain;
      }
    }

    return ExerciseProgressionState(
      exerciseId: exerciseId,
      recommendation: nextRecommendation,
      updatedAt: DateTime.now(),
      timesCompleted: timesCompleted + 1,
      level: nextLevel.clamp(minLevel, maxLevel),
      consecutiveGood: nextGood,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exerciseId': exerciseId,
      'recommendation': recommendation.name,
      'updatedAt': updatedAt.toIso8601String(),
      'timesCompleted': timesCompleted,
      'level': level,
      'consecutiveGood': consecutiveGood,
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
      level: ((data['level'] as int?) ?? 0).clamp(minLevel, maxLevel),
      consecutiveGood: data['consecutiveGood'] as int? ?? 0,
    );
  }
}
