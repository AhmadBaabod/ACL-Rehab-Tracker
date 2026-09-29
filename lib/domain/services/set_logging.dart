import 'package:acl_rehab/domain/models/exercise.dart';
import 'package:acl_rehab/domain/models/rehab_plan.dart';
import 'package:acl_rehab/domain/models/workout_log.dart';

/// What the user records for each set of an exercise.
enum SetMeasure { repsAndWeight, reps, seconds, minutes }

extension SetMeasureX on SetMeasure {
  bool get tracksWeight => this == SetMeasure.repsAndWeight;

  bool get isTimed => this == SetMeasure.seconds || this == SetMeasure.minutes;

  String get fieldLabel {
    switch (this) {
      case SetMeasure.repsAndWeight:
      case SetMeasure.reps:
        return 'Reps';
      case SetMeasure.seconds:
        return 'Seconds';
      case SetMeasure.minutes:
        return 'Minutes';
    }
  }
}

/// Purposes where external load is a meaningful way to progress.
const _loadablePurposes = {
  TrainingPurpose.quadStrength,
  TrainingPurpose.singleLegStrength,
  TrainingPurpose.posteriorChain,
  TrainingPurpose.hamstringStrength,
  TrainingPurpose.calfStrength,
};

SetMeasure setMeasureFor(Exercise exercise, Prescription dose) {
  final reps = dose.reps.toLowerCase();
  final hold = dose.hold.toLowerCase();
  final timed =
      reps.contains('hold') ||
      reps.contains('continuous') ||
      reps.contains('interval') ||
      reps.contains('bout');
  if (timed) {
    return hold.contains('min') ? SetMeasure.minutes : SetMeasure.seconds;
  }
  if (_loadablePurposes.contains(exercise.purpose)) {
    return SetMeasure.repsAndWeight;
  }
  return SetMeasure.reps;
}

/// The first number range in a reps or hold text, for example "8-12 each
/// side" -> (8, 12) or "20-45 sec" -> (20, 45).
({int low, int high})? numberRange(String text) {
  final match = RegExp(r'(\d+)(?:\s*-\s*(\d+))?').firstMatch(text);
  if (match == null) return null;
  final low = int.parse(match.group(1)!);
  final high = int.tryParse(match.group(2) ?? '') ?? low;
  return (low: low, high: high);
}

/// The starting value for a new set: reps for rep-based sets, otherwise the
/// target duration in the measure's unit.
int? targetValue(SetMeasure measure, Prescription dose) {
  switch (measure) {
    case SetMeasure.repsAndWeight:
    case SetMeasure.reps:
      return numberRange(dose.reps)?.low;
    case SetMeasure.seconds:
    case SetMeasure.minutes:
      return numberRange(dose.hold)?.low;
  }
}

/// Short summary such as "3 x 10 @ 20 kg", "3 x 10", or "2 x 30 s".
String? summarizeSets(List<SetLog> sets, WeightUnit unit) {
  if (sets.isEmpty) return null;
  if (sets.every((set) => set.seconds != null)) {
    final values = sets.map((set) => set.seconds!).toSet();
    final value = values.length == 1
        ? _duration(values.first)
        : sets.map((set) => _duration(set.seconds!)).join(', ');
    return values.length == 1 ? '${sets.length} x $value' : value;
  }
  final reps = sets.map((set) => set.reps ?? 0).toList();
  final sameReps = reps.toSet().length == 1;
  final repsText = sameReps
      ? '${sets.length} x ${reps.first}'
      : reps.join(', ');
  final weights = sets
      .where((set) => set.isWeighted)
      .map((set) => set.weightKg!)
      .toSet();
  if (weights.isEmpty) return repsText;
  final top = weights.reduce((a, b) => a > b ? a : b);
  return '$repsText @ ${weights.length == 1 ? '' : 'up to '}${unit.format(top)}';
}

String _duration(int seconds) {
  if (seconds >= 60 && seconds % 60 == 0) return '${seconds ~/ 60} min';
  return '$seconds s';
}

/// Suggests more load when every set of a weighted exercise reached the top
/// of its rep range last time.
String? loadSuggestion(
  List<SetLog> lastSets,
  Prescription dose,
  WeightUnit unit,
) {
  final range = numberRange(dose.reps);
  if (range == null || lastSets.isEmpty) return null;
  final allAtTop = lastSets.every((set) => (set.reps ?? 0) >= range.high);
  if (!allAtTop) return null;
  final top = lastSets
      .map((set) => set.weightKg ?? 0)
      .reduce((a, b) => a > b ? a : b);
  if (top <= 0) {
    return 'You reached ${range.high} reps on every set last time. Add a '
        'light weight or use the harder variation.';
  }
  final next = unit.toKg(unit.fromKg(top) + unit.increment);
  return 'You reached ${range.high} reps on every set last time. Try '
      '${unit.format(next)} if the knee stayed quiet.';
}
