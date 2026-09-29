import 'package:acl_rehab/domain/models/app_state.dart';
import 'package:acl_rehab/domain/models/assessment.dart';
import 'package:acl_rehab/domain/models/session_log.dart';
import 'package:acl_rehab/domain/models/workout_log.dart';
import 'package:acl_rehab/domain/services/rehab_status.dart';

enum ProgressPeriod { week, month, quarter, all }

enum InsightTrend { improving, steady, declining, info }

enum ProgressVerdict { gettingStarted, improving, steady, needsAttention }

extension ProgressPeriodX on ProgressPeriod {
  String get label {
    switch (this) {
      case ProgressPeriod.week:
        return '7 days';
      case ProgressPeriod.month:
        return '30 days';
      case ProgressPeriod.quarter:
        return '90 days';
      case ProgressPeriod.all:
        return 'All time';
    }
  }

  int? get days {
    switch (this) {
      case ProgressPeriod.week:
        return 7;
      case ProgressPeriod.month:
        return 30;
      case ProgressPeriod.quarter:
        return 90;
      case ProgressPeriod.all:
        return null;
    }
  }
}

extension ProgressVerdictX on ProgressVerdict {
  String get label {
    switch (this) {
      case ProgressVerdict.gettingStarted:
        return 'Getting started';
      case ProgressVerdict.improving:
        return 'You are improving';
      case ProgressVerdict.steady:
        return 'Holding steady';
      case ProgressVerdict.needsAttention:
        return 'Needs attention';
    }
  }
}

class TrendPoint {
  const TrendPoint(this.date, this.value, {this.label});

  final DateTime date;
  final double value;
  final String? label;
}

class WeekBucket {
  const WeekBucket({
    required this.start,
    required this.completed,
    required this.target,
  });

  final DateTime start;
  final int completed;
  final int target;

  bool get metTarget => completed >= target;
}

class ProgressInsight {
  const ProgressInsight({
    required this.trend,
    required this.title,
    required this.detail,
  });

  final InsightTrend trend;
  final String title;
  final String detail;
}

class ProgressSnapshot {
  const ProgressSnapshot({
    required this.period,
    required this.workouts,
    required this.plannedSessions,
    required this.adherence,
    required this.streakWeeks,
    required this.exercisesCompleted,
    required this.setsCompleted,
    required this.setsPlanned,
    required this.averagePainAfter,
    required this.averageEffort,
    required this.feedbackCounts,
    required this.progressions,
    required this.regressions,
    required this.weekly,
    required this.painSeries,
    required this.effortSeries,
    required this.symmetrySeries,
    required this.insights,
    required this.verdict,
    required this.recentWorkouts,
    this.volumeKg = 0,
    this.loadSeries = const {},
  });

  final ProgressPeriod period;
  final int workouts;
  final int plannedSessions;

  /// Completed / planned sessions, or null before any plan existed.
  final double? adherence;
  final int streakWeeks;
  final int exercisesCompleted;
  final int setsCompleted;
  final int setsPlanned;
  final double? averagePainAfter;
  final double? averageEffort;
  final Map<ExerciseFeedback, int> feedbackCounts;
  final int progressions;
  final int regressions;
  final List<WeekBucket> weekly;
  final List<TrendPoint> painSeries;
  final List<TrendPoint> effortSeries;

  /// Symmetry measurements (quad, hamstring, hip, balance, hop) over time.
  final Map<String, List<TrendPoint>> symmetrySeries;
  final List<ProgressInsight> insights;
  final ProgressVerdict verdict;
  final List<WorkoutLog> recentWorkouts;

  /// Total reps x weight lifted in the period, in kilograms.
  final double volumeKg;

  /// Heaviest weight (kg) per workout, by exercise name, most recently
  /// trained exercises first.
  final Map<String, List<TrendPoint>> loadSeries;

  ProgressSnapshot withInsights(
    List<ProgressInsight> insights,
    ProgressVerdict verdict,
  ) {
    return ProgressSnapshot(
      period: period,
      workouts: workouts,
      plannedSessions: plannedSessions,
      adherence: adherence,
      streakWeeks: streakWeeks,
      exercisesCompleted: exercisesCompleted,
      setsCompleted: setsCompleted,
      setsPlanned: setsPlanned,
      averagePainAfter: averagePainAfter,
      averageEffort: averageEffort,
      feedbackCounts: feedbackCounts,
      progressions: progressions,
      regressions: regressions,
      weekly: weekly,
      painSeries: painSeries,
      effortSeries: effortSeries,
      symmetrySeries: symmetrySeries,
      insights: insights,
      verdict: verdict,
      recentWorkouts: recentWorkouts,
      volumeKg: volumeKg,
      loadSeries: loadSeries,
    );
  }

  double? get setCompletion =>
      setsPlanned == 0 ? null : (setsCompleted / setsPlanned).clamp(0.0, 1.0);

  int get totalFeedback =>
      feedbackCounts.values.fold(0, (sum, value) => sum + value);
}

class ProgressAnalytics {
  const ProgressAnalytics._();

  static DateTime weekStart(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  static ProgressSnapshot compute(
    AppState state,
    ProgressPeriod period, {
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final days = period.days;
    // The program starts at the first assessment (or plan, for data saved
    // before assessment history existed).
    final starts = [
      if (state.assessmentHistory.isNotEmpty)
        state.assessmentHistory.first.createdAt,
      if (state.plans.isNotEmpty) state.plans.first.createdAt,
    ];
    final firstPlanAt = starts.isEmpty
        ? null
        : starts.reduce((a, b) => a.isBefore(b) ? a : b);
    var from = days == null
        ? (firstPlanAt ?? today)
        : today.subtract(Duration(days: days));
    if (firstPlanAt != null && from.isBefore(firstPlanAt)) from = firstPlanAt;

    bool inPeriod(DateTime date) => days == null
        ? true
        : date.isAfter(today.subtract(Duration(days: days)));

    final workouts =
        state.workoutLogs.where((log) => inPeriod(log.completedAt)).toList()
          ..sort((a, b) => a.completedAt.compareTo(b.completedAt));
    final logs = state.sessionLogs.where((log) => inPeriod(log.createdAt));

    final target = state.activePlan?.sessionsPerWeek ?? 3;
    final elapsedDays = today.difference(from).inHours / 24;
    // Adherence is only meaningful once a full week of the plan has passed.
    final fullWeek =
        firstPlanAt != null && today.difference(firstPlanAt).inDays >= 7;
    final plannedSessions = firstPlanAt == null
        ? 0
        : fullWeek
        ? ((elapsedDays / 7) * target).round().clamp(1, 1000)
        : target;
    final adherence = fullWeek
        ? (workouts.length / plannedSessions).clamp(0.0, 1.0)
        : null;

    final feedbackCounts = {
      for (final feedback in ExerciseFeedback.values) feedback: 0,
    };
    var progressions = 0;
    var regressions = 0;
    for (final log in logs) {
      feedbackCounts[log.feedback] = feedbackCounts[log.feedback]! + 1;
      if (log.recommendation == ProgressionRecommendation.progress) {
        progressions++;
      }
      if (log.recommendation == ProgressionRecommendation.regress) {
        regressions++;
      }
    }

    final weekly = _weekly(state, today, target);
    final painSeries = _painSeries(state, inPeriod);
    final effortSeries = [
      for (final log in workouts)
        TrendPoint(log.completedAt, log.effort.toDouble()),
    ];
    final symmetrySeries = _symmetrySeries(state);

    double? average(Iterable<int> values) =>
        values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length;

    final snapshot = ProgressSnapshot(
      period: period,
      workouts: workouts.length,
      plannedSessions: plannedSessions,
      adherence: adherence,
      streakWeeks: _streak(weekly),
      exercisesCompleted: workouts.fold(
        0,
        (sum, log) => sum + log.exercisesCompleted,
      ),
      setsCompleted: workouts.fold(0, (sum, log) => sum + log.completedSets),
      setsPlanned: workouts.fold(0, (sum, log) => sum + log.plannedSets),
      averagePainAfter: average(workouts.map((log) => log.painAfter)),
      averageEffort: average(workouts.map((log) => log.effort)),
      feedbackCounts: feedbackCounts,
      progressions: progressions,
      regressions: regressions,
      weekly: weekly,
      painSeries: painSeries,
      effortSeries: effortSeries,
      symmetrySeries: symmetrySeries,
      insights: const [],
      verdict: ProgressVerdict.gettingStarted,
      recentWorkouts: workouts.reversed.take(5).toList(),
      volumeKg: workouts.fold(0, (sum, log) => sum + log.volumeKg),
      loadSeries: _loadSeries(workouts),
    );
    final insights = _insights(state, snapshot, workouts);
    return snapshot.withInsights(insights, _verdict(insights, snapshot));
  }

  static Map<String, List<TrendPoint>> _loadSeries(List<WorkoutLog> workouts) {
    final series = <String, List<TrendPoint>>{};
    final lastSeen = <String, DateTime>{};
    for (final log in workouts) {
      for (final entry in log.entries) {
        final top = entry.topWeightKg;
        if (top == null) continue;
        series
            .putIfAbsent(entry.exerciseName, () => [])
            .add(TrendPoint(log.completedAt, top));
        lastSeen[entry.exerciseName] = log.completedAt;
      }
    }
    final names = series.keys.toList()
      ..sort((a, b) => lastSeen[b]!.compareTo(lastSeen[a]!));
    return {for (final name in names) name: series[name]!};
  }

  static List<WeekBucket> _weekly(AppState state, DateTime today, int target) {
    final thisWeek = weekStart(today);
    return [
      for (var i = 7; i >= 0; i--)
        () {
          final start = thisWeek.subtract(Duration(days: 7 * i));
          final end = start.add(const Duration(days: 7));
          return WeekBucket(
            start: start,
            completed: state.workoutLogs
                .where(
                  (log) =>
                      !log.completedAt.isBefore(start) &&
                      log.completedAt.isBefore(end),
                )
                .length,
            target: target,
          );
        }(),
    ];
  }

  /// Consecutive weeks meeting the session target, counting the current
  /// week only once it has been met.
  static int _streak(List<WeekBucket> weekly) {
    var streak = 0;
    for (var i = weekly.length - 1; i >= 0; i--) {
      final bucket = weekly[i];
      if (bucket.metTarget) {
        streak++;
      } else if (i != weekly.length - 1) {
        break;
      }
    }
    return streak;
  }

  static List<TrendPoint> _painSeries(
    AppState state,
    bool Function(DateTime) inPeriod,
  ) {
    final points = <TrendPoint>[
      for (final record in state.assessmentHistory)
        if (inPeriod(record.createdAt))
          TrendPoint(
            record.createdAt,
            record.assessment.pain.toDouble(),
            label: 'Assessment',
          ),
      for (final checkIn in state.milestoneCheckIns)
        if (inPeriod(checkIn.createdAt))
          TrendPoint(
            checkIn.createdAt,
            checkIn.pain.toDouble(),
            label: 'Check-in',
          ),
      for (final log in state.workoutLogs)
        if (inPeriod(log.completedAt))
          TrendPoint(
            log.completedAt,
            log.painAfter.toDouble(),
            label: 'After session',
          ),
    ]..sort((a, b) => a.date.compareTo(b.date));
    return points;
  }

  static const symmetryMetrics = [
    'Quadriceps',
    'Hamstring',
    'Hip',
    'Balance',
    'Hop',
  ];

  static Map<String, List<TrendPoint>> _symmetrySeries(AppState state) {
    final series = {
      for (final metric in symmetryMetrics) metric: <TrendPoint>[],
    };
    void addStatus(DateTime date, RehabStatus status) {
      final values = {
        'Quadriceps': status.quadSymmetry,
        'Hamstring': status.hamstringSymmetry,
        'Hip': status.hipSymmetry,
        'Balance': status.balanceSymmetry,
        'Hop': status.hopSymmetry,
      };
      values.forEach((metric, value) {
        if (value != null) {
          series[metric]!.add(TrendPoint(date, value.toDouble()));
        }
      });
    }

    for (final record in state.assessmentHistory) {
      addStatus(record.createdAt, RehabStatus.from(record.assessment));
    }
    for (final checkIn in state.milestoneCheckIns) {
      final base = _assessmentAt(state, checkIn.createdAt);
      if (base != null) {
        addStatus(
          checkIn.createdAt,
          RehabStatus.from(base, milestone: checkIn),
        );
      }
    }
    for (final points in series.values) {
      points.sort((a, b) => a.date.compareTo(b.date));
    }
    series.removeWhere((_, points) => points.isEmpty);
    return series;
  }

  static Assessment? _assessmentAt(AppState state, DateTime date) {
    Assessment? result;
    for (final record in state.assessmentHistory) {
      if (!record.createdAt.isAfter(date)) result = record.assessment;
    }
    return result ?? state.assessment;
  }

  static List<ProgressInsight> _insights(
    AppState state,
    ProgressSnapshot snapshot,
    List<WorkoutLog> workouts,
  ) {
    final insights = <ProgressInsight>[];

    if (workouts.length >= 4) {
      final half = workouts.length ~/ 2;
      double avg(Iterable<WorkoutLog> items) =>
          items.fold<int>(0, (sum, log) => sum + log.painAfter) / items.length;
      final early = avg(workouts.take(half));
      final late = avg(workouts.skip(half));
      final delta = late - early;
      insights.add(
        ProgressInsight(
          trend: delta <= -1
              ? InsightTrend.improving
              : delta >= 1
              ? InsightTrend.declining
              : InsightTrend.steady,
          title: delta <= -1
              ? 'Pain after sessions is dropping'
              : delta >= 1
              ? 'Pain after sessions is rising'
              : 'Pain after sessions is stable',
          detail:
              'Average ${early.toStringAsFixed(1)}/10 earlier vs '
              '${late.toStringAsFixed(1)}/10 recently.',
        ),
      );
    } else if (state.assessmentHistory.length >= 2) {
      final first = state.assessmentHistory.first.assessment.pain;
      final last = state.assessmentHistory.last.assessment.pain;
      if (first != last) {
        insights.add(
          ProgressInsight(
            trend: last < first
                ? InsightTrend.improving
                : InsightTrend.declining,
            title: last < first ? 'Pain is lower' : 'Pain is higher',
            detail: 'From $first/10 at your first assessment to $last/10 now.',
          ),
        );
      }
    }

    final adherence = snapshot.adherence;
    if (adherence != null && snapshot.plannedSessions >= 2) {
      final percent = (adherence * 100).round();
      insights.add(
        ProgressInsight(
          trend: adherence >= 0.75
              ? InsightTrend.improving
              : adherence >= 0.5
              ? InsightTrend.steady
              : InsightTrend.declining,
          title: adherence >= 0.75
              ? 'Consistent training'
              : adherence >= 0.5
              ? 'Some sessions missed'
              : 'Consistency is low',
          detail:
              '${snapshot.workouts} of ${snapshot.plannedSessions} planned '
              'sessions ($percent%) in the last ${snapshot.period.label.toLowerCase()}.',
        ),
      );
    }

    if (snapshot.progressions + snapshot.regressions > 0) {
      final net = snapshot.progressions - snapshot.regressions;
      insights.add(
        ProgressInsight(
          trend: net > 0
              ? InsightTrend.improving
              : net < 0
              ? InsightTrend.declining
              : InsightTrend.steady,
          title: net > 0
              ? 'Exercises are getting easier'
              : net < 0
              ? 'Some exercises feel too hard'
              : 'Difficulty is holding',
          detail:
              '${snapshot.progressions} progressions and '
              '${snapshot.regressions} step-backs from your feedback.',
        ),
      );
    }

    for (final entry in snapshot.symmetrySeries.entries) {
      final points = entry.value;
      if (points.length < 2) continue;
      final delta = points.last.value - points.first.value;
      if (delta.abs() < 3) continue;
      insights.add(
        ProgressInsight(
          trend: delta > 0 ? InsightTrend.improving : InsightTrend.declining,
          title:
              '${entry.key} symmetry ${delta > 0 ? 'up' : 'down'} '
              '${delta.abs().round()}%',
          detail:
              'From ${points.first.value.round()}% to ${points.last.value.round()}% '
              '(target 90%).',
        ),
      );
    }

    final heavier = snapshot.loadSeries.entries
        .where(
          (entry) =>
              entry.value.length >= 2 &&
              entry.value.last.value > entry.value.first.value,
        )
        .map((entry) => entry.key)
        .toList();
    if (heavier.isNotEmpty) {
      insights.add(
        ProgressInsight(
          trend: InsightTrend.improving,
          title: 'Lifting heavier',
          detail:
              'Top weight went up on ${heavier.take(3).join(', ')}'
              '${heavier.length > 3 ? ' and ${heavier.length - 3} more' : ''}.',
        ),
      );
    }

    if (state.assessmentHistory.length >= 2) {
      final first = state.assessmentHistory.first.phase;
      final last = state.assessmentHistory.last.phase;
      if (last.order > first.order) {
        insights.add(
          ProgressInsight(
            trend: InsightTrend.improving,
            title: 'Moved up to ${last.shortLabel}',
            detail:
                'From ${first.label} to ${last.label} since your first assessment.',
          ),
        );
      } else if (last.order < first.order) {
        insights.add(
          ProgressInsight(
            trend: InsightTrend.declining,
            title: 'Phase stepped back to ${last.shortLabel}',
            detail:
                'Symptoms or criteria changed since your first assessment. '
                'Review with your clinical team.',
          ),
        );
      }
    }
    return insights;
  }

  static ProgressVerdict _verdict(
    List<ProgressInsight> insights,
    ProgressSnapshot snapshot,
  ) {
    if (insights.isEmpty) return ProgressVerdict.gettingStarted;
    final up = insights.where((item) => item.trend == InsightTrend.improving);
    final down = insights.where((item) => item.trend == InsightTrend.declining);
    if (down.length > up.length) return ProgressVerdict.needsAttention;
    if (up.isNotEmpty && up.length >= down.length + 1) {
      return ProgressVerdict.improving;
    }
    if (snapshot.workouts < 2 && up.isEmpty) {
      return ProgressVerdict.gettingStarted;
    }
    return ProgressVerdict.steady;
  }
}
