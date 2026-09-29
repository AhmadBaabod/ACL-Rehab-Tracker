import 'package:acl_rehab/domain/models/session_log.dart';

enum WeightUnit { kg, lb }

extension WeightUnitX on WeightUnit {
  static const _poundsPerKg = 2.20462;

  String get label => name;

  double fromKg(double kg) => this == WeightUnit.kg ? kg : kg * _poundsPerKg;

  double toKg(double value) =>
      this == WeightUnit.kg ? value : value / _poundsPerKg;

  /// Typical plate increment in this unit.
  double get increment => this == WeightUnit.kg ? 2.5 : 5;

  String format(double kg) {
    final value = fromKg(kg);
    final rounded = (value * 10).round() / 10;
    final text = rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(1);
    return '$text $label';
  }
}

/// One completed set. Rep-based sets record [reps] and optionally
/// [weightKg]; timed sets record [seconds].
class SetLog {
  const SetLog({this.reps, this.weightKg, this.seconds});

  final int? reps;

  /// External load in kilograms; null or 0 means bodyweight.
  final double? weightKg;
  final int? seconds;

  bool get isWeighted => (weightKg ?? 0) > 0;

  double get volumeKg => (reps ?? 0) * (weightKg ?? 0);

  Map<String, dynamic> toJson() => {
    'reps': reps,
    'weightKg': weightKg,
    'seconds': seconds,
  };

  factory SetLog.fromJson(Map<String, dynamic> data) {
    return SetLog(
      reps: data['reps'] as int?,
      weightKg: (data['weightKg'] as num?)?.toDouble(),
      seconds: data['seconds'] as int?,
    );
  }
}

class WorkoutExerciseEntry {
  const WorkoutExerciseEntry({
    required this.exerciseId,
    required this.exerciseName,
    required this.plannedSets,
    required this.completedSets,
    this.feedback,
    this.substitutedFromId,
    this.sets = const [],
  });

  final String exerciseId;
  final String exerciseName;
  final int plannedSets;
  final int completedSets;

  /// Reps, weight, or time for each completed set.
  final List<SetLog> sets;
  final ExerciseFeedback? feedback;

  /// Set when the user swapped in an alternative for this workout.
  final String? substitutedFromId;

  bool get isCompleted => completedSets >= plannedSets && plannedSets > 0;

  double get volumeKg => sets.fold(0, (sum, set) => sum + set.volumeKg);

  /// Heaviest load lifted in this entry, if any set was weighted.
  double? get topWeightKg {
    final weighted = sets.where((set) => set.isWeighted);
    if (weighted.isEmpty) return null;
    return weighted.map((set) => set.weightKg!).reduce((a, b) => a > b ? a : b);
  }

  Map<String, dynamic> toJson() {
    return {
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'plannedSets': plannedSets,
      'completedSets': completedSets,
      'feedback': feedback?.name,
      'substitutedFromId': substitutedFromId,
      'sets': sets.map((set) => set.toJson()).toList(),
    };
  }

  factory WorkoutExerciseEntry.fromJson(Map<String, dynamic> data) {
    ExerciseFeedback? feedback;
    for (final item in ExerciseFeedback.values) {
      if (item.name == data['feedback']) feedback = item;
    }
    return WorkoutExerciseEntry(
      exerciseId: data['exerciseId'] as String? ?? '',
      exerciseName: data['exerciseName'] as String? ?? 'Exercise',
      plannedSets: data['plannedSets'] as int? ?? 0,
      completedSets: data['completedSets'] as int? ?? 0,
      feedback: feedback,
      substitutedFromId: data['substitutedFromId'] as String?,
      sets: (data['sets'] as List<dynamic>? ?? const [])
          .map(
            (item) => SetLog.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }
}

class WorkoutLog {
  const WorkoutLog({
    required this.id,
    required this.planId,
    required this.planVersion,
    required this.sessionId,
    required this.sessionName,
    required this.startedAt,
    required this.completedAt,
    required this.entries,
    required this.painAfter,
    required this.effort,
    this.notes = '',
  });

  final String id;
  final String planId;
  final int planVersion;
  final String sessionId;
  final String sessionName;
  final DateTime startedAt;
  final DateTime completedAt;
  final List<WorkoutExerciseEntry> entries;

  /// Knee pain after the workout, 0-10.
  final int painAfter;

  /// Overall session effort (RPE), 1-10.
  final int effort;
  final String notes;

  int get plannedSets =>
      entries.fold(0, (total, entry) => total + entry.plannedSets);

  int get completedSets =>
      entries.fold(0, (total, entry) => total + entry.completedSets);

  int get exercisesCompleted =>
      entries.where((entry) => entry.completedSets > 0).length;

  double get volumeKg => entries.fold(0, (sum, entry) => sum + entry.volumeKg);

  double get completionRate =>
      plannedSets == 0 ? 0 : (completedSets / plannedSets).clamp(0.0, 1.0);

  Duration get duration => completedAt.difference(startedAt);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'planId': planId,
      'planVersion': planVersion,
      'sessionId': sessionId,
      'sessionName': sessionName,
      'startedAt': startedAt.toIso8601String(),
      'completedAt': completedAt.toIso8601String(),
      'entries': entries.map((entry) => entry.toJson()).toList(),
      'painAfter': painAfter,
      'effort': effort,
      'notes': notes,
    };
  }

  factory WorkoutLog.fromJson(Map<String, dynamic> data) {
    final completedAt =
        DateTime.tryParse(data['completedAt'] as String? ?? '') ??
        DateTime.now();
    return WorkoutLog(
      id:
          data['id'] as String? ??
          completedAt.microsecondsSinceEpoch.toString(),
      planId: data['planId'] as String? ?? '',
      planVersion: data['planVersion'] as int? ?? 1,
      sessionId: data['sessionId'] as String? ?? 'A',
      sessionName: data['sessionName'] as String? ?? 'Session',
      startedAt:
          DateTime.tryParse(data['startedAt'] as String? ?? '') ?? completedAt,
      completedAt: completedAt,
      entries: (data['entries'] as List<dynamic>? ?? const [])
          .map(
            (item) => WorkoutExerciseEntry.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      painAfter: data['painAfter'] as int? ?? 0,
      effort: data['effort'] as int? ?? 5,
      notes: data['notes'] as String? ?? '',
    );
  }
}
