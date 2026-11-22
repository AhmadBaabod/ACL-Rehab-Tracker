import 'package:acl_rehab/data/exercise_catalog.dart';
import 'package:acl_rehab/domain/models/app_state.dart';
import 'package:acl_rehab/domain/models/exercise.dart';
import 'package:acl_rehab/domain/models/workout_log.dart';
import 'package:acl_rehab/domain/services/rehab_status.dart';

/// The best set for one leg: an Epley estimate for weighted sets
/// (`kg * (1 + reps / 30)`), otherwise seconds or reps. Null when nothing
/// usable was logged.
double? legScore(List<SetLog> sets) {
  double? best;
  for (final set in sets) {
    final double score = set.isWeighted
        ? set.weightKg! * (1 + (set.reps ?? 0) / 30)
        : (set.seconds ?? set.reps ?? 0).toDouble();
    if (best == null || score > best) best = score;
  }
  return best == null || best <= 0 ? null : best;
}

/// Operated leg as a percentage of the other leg, rounded. Null when either
/// leg has no usable sets, or only one leg used external load.
int? entrySymmetry(WorkoutExerciseEntry entry) {
  final operatedWeighted = entry.sets.any((set) => set.isWeighted);
  final otherWeighted = entry.otherLegSets.any((set) => set.isWeighted);
  if (operatedWeighted != otherWeighted) return null;
  final operated = legScore(entry.sets);
  final other = legScore(entry.otherLegSets);
  if (operated == null || other == null) return null;
  return (operated / other * 100).round();
}

class SymmetryEstimate {
  const SymmetryEstimate({
    required this.area,
    required this.percent,
    required this.sessions,
  });

  final SymmetryArea area;

  /// Median symmetry across recent sessions; may exceed 100.
  final int percent;
  final int sessions;
}

class SymmetrySuggestion {
  const SymmetrySuggestion({
    required this.area,
    required this.estimate,
    this.recorded,
  });

  final SymmetryArea area;

  /// Training estimate capped at 100, ready for a check-in.
  final int estimate;

  /// The value currently recorded, or null when never measured.
  final int? recorded;
}

class LimbSymmetryAnalyzer {
  const LimbSymmetryAnalyzer._();

  static const window = Duration(days: 28);
  static const maxSessions = 3;
  static const minSessions = 2;
  static const minDifference = 5;

  static Map<SymmetryArea, SymmetryEstimate> estimates(
    List<WorkoutLog> logs,
    DateTime now,
  ) {
    final recent =
        logs
            .where((log) => !log.completedAt.isBefore(now.subtract(window)))
            .toList()
          ..sort((a, b) => b.completedAt.compareTo(a.completedAt));

    final perSession = <SymmetryArea, List<double>>{};
    for (final log in recent) {
      final values = <SymmetryArea, List<int>>{};
      for (final entry in log.entries) {
        final area = ExerciseCatalog.byId(entry.exerciseId)?.symmetryArea;
        final symmetry = entrySymmetry(entry);
        if (area == null || symmetry == null) continue;
        values.putIfAbsent(area, () => []).add(symmetry);
      }
      for (final item in values.entries) {
        final sessions = perSession.putIfAbsent(item.key, () => []);
        if (sessions.length >= maxSessions) continue;
        sessions.add(item.value.reduce((a, b) => a + b) / item.value.length);
      }
    }

    return {
      for (final item in perSession.entries)
        if (item.value.length >= minSessions)
          item.key: SymmetryEstimate(
            area: item.key,
            percent: _median(item.value).round(),
            sessions: item.value.length,
          ),
    };
  }

  /// Areas where training symmetry differs from the recorded value enough to
  /// be worth reviewing in a check-in.
  static List<SymmetrySuggestion> suggestions(AppState state, DateTime now) {
    final assessment = state.assessment;
    if (assessment == null) return const [];
    final status = RehabStatus.from(
      assessment,
      milestone: state.latestMilestone,
    );
    final recorded = {
      SymmetryArea.quad: status.quadSymmetry,
      SymmetryArea.hamstring: status.hamstringSymmetry,
      SymmetryArea.hip: status.hipSymmetry,
      SymmetryArea.balance: status.balanceSymmetry,
    };
    final result = <SymmetrySuggestion>[];
    for (final estimate in estimates(state.workoutLogs, now).values) {
      if (!estimate.area.feedsCheckIn) continue;
      final capped = estimate.percent.clamp(0, 100);
      final current = recorded[estimate.area];
      if (current != null && (capped - current).abs() < minDifference) {
        continue;
      }
      result.add(
        SymmetrySuggestion(
          area: estimate.area,
          estimate: capped,
          recorded: current,
        ),
      );
    }
    result.sort((a, b) => a.area.index.compareTo(b.area.index));
    return result;
  }

  static double _median(List<double> values) {
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
  }
}
