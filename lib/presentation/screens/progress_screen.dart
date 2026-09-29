import 'package:acl_rehab/core/constants/app_constants.dart';
import 'package:acl_rehab/core/navigation/app_router.dart';
import 'package:acl_rehab/core/navigation/app_tabs.dart';
import 'package:acl_rehab/core/theme/app_theme.dart';
import 'package:acl_rehab/domain/models/app_state.dart';
import 'package:acl_rehab/domain/models/assessment.dart';
import 'package:acl_rehab/domain/models/assessment_record.dart';
import 'package:acl_rehab/domain/models/milestone_check_in.dart';
import 'package:acl_rehab/domain/models/session_log.dart';
import 'package:acl_rehab/domain/models/workout_log.dart';
import 'package:acl_rehab/domain/services/progress_analytics.dart';
import 'package:acl_rehab/presentation/providers/app_state_provider.dart';
import 'package:acl_rehab/presentation/widgets/charts.dart';
import 'package:acl_rehab/presentation/widgets/common.dart';
import 'package:acl_rehab/presentation/widgets/form_widgets.dart';
import 'package:acl_rehab/presentation/widgets/metric_card.dart';
import 'package:acl_rehab/presentation/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  ProgressPeriod period = ProgressPeriod.month;

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appControllerProvider).value;
    final assessment = appState?.assessment;
    if (appState == null || assessment == null) {
      return const Scaffold(
        body: Center(
          child: Text('Complete your assessment to track progress.'),
        ),
      );
    }
    final snapshot = ProgressAnalytics.compute(appState, period);

    return Scaffold(
      body: ResponsivePage(
        maxWidth: 960,
        children: [
          PageHeader(
            title: 'Progress',
            subtitle: 'Sessions, symptoms, and test results over time.',
            actions: [
              FilledButton.icon(
                onPressed: () => context.push(AppRoutes.reassess),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Reassess'),
              ),
              OutlinedButton.icon(
                onPressed: () => _showCheckInSheet(context, appState),
                icon: const Icon(Icons.add_chart),
                label: const Text('Quick check-in'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _VerdictCard(snapshot: snapshot),
          const SizedBox(height: AppConstants.sectionGap),
          SegmentedButton<ProgressPeriod>(
            showSelectedIcon: false,
            segments: [
              for (final option in ProgressPeriod.values)
                ButtonSegment(value: option, label: Text(option.label)),
            ],
            selected: {period},
            onSelectionChanged: (selection) {
              HapticFeedback.selectionClick();
              setState(() => period = selection.first);
            },
          ),
          const SizedBox(height: 12),
          _StatsGrid(snapshot: snapshot),
          const SizedBox(height: AppConstants.sectionGap),
          const SectionHeader(title: 'Consistency'),
          const SizedBox(height: 10),
          _ChartCard(
            title: 'Sessions per week',
            subtitle:
                'Last 8 weeks · target ${appState.activePlan?.sessionsPerWeek ?? 3} a week',
            child: ColumnChart(
              bars: [
                for (final week in snapshot.weekly)
                  BarDatum(
                    label: week == snapshot.weekly.last
                        ? 'This wk'
                        : shortDate(week.start),
                    value: week.completed.toDouble(),
                    detail:
                        '${week.completed} ${week.completed == 1 ? 'session' : 'sessions'}'
                        '${week.metTarget ? ' · target met' : ''}',
                  ),
              ],
              maxValue: snapshot.weekly
                  .map((week) => week.completed.toDouble())
                  .fold(1, (a, b) => a > b ? a : b),
              target: (appState.activePlan?.sessionsPerWeek ?? 3).toDouble(),
              targetLabel: 'Target',
              semanticsLabel:
                  'Sessions per week for the last 8 weeks: '
                  '${snapshot.weekly.map((week) => week.completed).join(', ')}',
            ),
          ),
          const SizedBox(height: AppConstants.sectionGap),
          const SectionHeader(title: 'Symptoms & difficulty'),
          const SizedBox(height: 10),
          _ChartCard(
            title: 'Knee pain',
            subtitle:
                'From assessments, check-ins, and after each session · target 0-2',
            child: snapshot.painSeries.isEmpty
                ? const _NoData(
                    text:
                        'Pain after each session appears here once you finish a workout.',
                  )
                : TrendLineChart(
                    points: [
                      for (final point in snapshot.painSeries)
                        ChartPoint(point.date, point.value, note: point.label),
                    ],
                    minY: 0,
                    maxY: 10,
                    target: 2,
                    targetLabel: 'Target 2',
                    formatValue: (value) => '${value.round()}/10',
                    semanticsLabel: _seriesSummary(
                      'Knee pain',
                      snapshot.painSeries,
                      '/10',
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              final effort = _ChartCard(
                title: 'Session effort',
                subtitle: 'How hard each session felt (RPE 1-10)',
                child: snapshot.effortSeries.length < 2
                    ? const _NoData(
                        text:
                            'Log at least two workouts to see an effort trend.',
                      )
                    : TrendLineChart(
                        points: [
                          for (final point in snapshot.effortSeries)
                            ChartPoint(point.date, point.value),
                        ],
                        minY: 0,
                        maxY: 10,
                        formatValue: (value) => '${value.round()}/10',
                        semanticsLabel: _seriesSummary(
                          'Session effort',
                          snapshot.effortSeries,
                          '/10',
                        ),
                      ),
              );
              final feedback = _ChartCard(
                title: 'Exercise feedback',
                subtitle:
                    '${snapshot.progressions} progressed · ${snapshot.regressions} eased',
                child: snapshot.totalFeedback == 0
                    ? const _NoData(
                        text:
                            'Rate exercises during a workout to see how difficulty is trending.',
                      )
                    : ShareBar(
                        segments: [
                          ShareSegment(
                            label: 'Just right',
                            value: snapshot
                                .feedbackCounts[ExerciseFeedback.justRight]!,
                          ),
                          ShareSegment(
                            label: 'Too hard',
                            value: snapshot
                                .feedbackCounts[ExerciseFeedback.tooHard]!,
                          ),
                          ShareSegment(
                            label: 'Too easy',
                            value: snapshot
                                .feedbackCounts[ExerciseFeedback.tooEasy]!,
                          ),
                        ],
                      ),
              );
              if (!wide) {
                return Column(
                  children: [effort, const SizedBox(height: 12), feedback],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: effort),
                  const SizedBox(width: 12),
                  Expanded(child: feedback),
                ],
              );
            },
          ),
          const SizedBox(height: AppConstants.sectionGap),
          const SectionHeader(title: 'Strength & balance tests'),
          const SizedBox(height: 10),
          if (snapshot.symmetrySeries.isEmpty)
            EmptyStateCard(
              icon: Icons.straighten,
              title: 'No measurements yet',
              body:
                  'Strength, balance, and hop symmetry measured by your PT will be '
                  'charted here. Add them at your next reassessment.',
              actionLabel: 'Start reassessment',
              onAction: () => context.push(AppRoutes.reassess),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 720
                    ? 3
                    : constraints.maxWidth >= 420
                    ? 2
                    : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * 12) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final entry in snapshot.symmetrySeries.entries)
                      SizedBox(
                        width: width,
                        child: MetricSparkTile(
                          title: '${entry.key} symmetry',
                          target: 90,
                          points: [
                            for (final point in entry.value)
                              ChartPoint(point.date, point.value),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          const SizedBox(height: AppConstants.sectionGap),
          const SectionHeader(title: 'Strength progress'),
          const SizedBox(height: 10),
          if (snapshot.loadSeries.isEmpty)
            const EmptyStateCard(
              icon: Icons.fitness_center,
              title: 'No weights logged in this period',
              body:
                  'Enter the weight for each set during a workout. The heaviest '
                  'weight per session is charted here for each exercise.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 720
                    ? 3
                    : constraints.maxWidth >= 420
                    ? 2
                    : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * 12) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final entry in snapshot.loadSeries.entries.take(6))
                      SizedBox(
                        width: width,
                        child: MetricSparkTile(
                          title: entry.key,
                          points: [
                            for (final point in entry.value)
                              ChartPoint(point.date, point.value),
                          ],
                          format: appState.weightUnit.format,
                        ),
                      ),
                  ],
                );
              },
            ),
          const SizedBox(height: AppConstants.sectionGap),
          const SectionHeader(title: 'Assessments'),
          const SizedBox(height: 10),
          _AssessmentHistory(state: appState),
          const SizedBox(height: AppConstants.sectionGap),
          const SectionHeader(title: 'Recent workouts'),
          const SizedBox(height: 10),
          if (snapshot.recentWorkouts.isEmpty)
            EmptyStateCard(
              icon: Icons.sports_gymnastics,
              title: 'No workouts in this period',
              body:
                  'Finished workouts appear here with sets, pain, and effort.',
              actionLabel: 'Go to workout',
              onAction: () => ref
                  .read(appControllerProvider.notifier)
                  .selectTab(AppTab.workout),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final log in snapshot.recentWorkouts)
                    ListTile(
                      leading: CircleAvatar(
                        child: Text('${(log.completionRate * 100).round()}%'),
                      ),
                      title: Text(
                        '${log.sessionName} · ${formatDate(log.completedAt)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${log.completedSets}/${log.plannedSets} sets · '
                        '${log.exercisesCompleted} exercises · pain ${log.painAfter}/10 · '
                        'effort ${log.effort}/10'
                        '${log.volumeKg > 0 ? ' · ${appState.weightUnit.format(log.volumeKg)}' : ''}',
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppConstants.sectionGap),
          const SectionHeader(title: 'Check-ins'),
          const SizedBox(height: 10),
          _CheckIns(state: appState),
        ],
      ),
    );
  }

  String _seriesSummary(String name, List<TrendPoint> points, String suffix) {
    if (points.isEmpty) return '$name: no data';
    final first = points.first;
    final last = points.last;
    return '$name: ${points.length} readings, from ${first.value.round()}$suffix '
        'on ${shortDate(first.date)} to ${last.value.round()}$suffix on ${shortDate(last.date)}';
  }

  Future<void> _showCheckInSheet(BuildContext context, AppState state) async {
    final checkIn = await showModalBottomSheet<MilestoneCheckIn>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _MilestoneCheckInSheet(
        assessment: state.assessment!,
        latest: state.latestMilestone,
      ),
    );
    if (checkIn == null || !context.mounted) return;

    HapticFeedback.mediumImpact();
    try {
      final update = await ref
          .read(appControllerProvider.notifier)
          .addMilestoneCheckIn(checkIn);
      if (!context.mounted) return;
      final message = update == null
          ? 'Check-in saved.'
          : update.isNewVersion
          ? 'Check-in saved. Plan updated to version ${update.plan.version}'
                '${update.phaseChanged ? ' (${update.plan.phase.label})' : ''}: '
                '${update.diff.summary}'
          : 'Check-in saved. Your plan still fits.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: 'View plan',
            onPressed: () =>
                ref.read(appControllerProvider.notifier).selectTab(AppTab.plan),
          ),
        ),
      );
    } catch (_) {
      if (context.mounted) showSaveError(context);
    }
  }
}

class _VerdictCard extends StatelessWidget {
  const _VerdictCard({required this.snapshot});

  final ProgressSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (snapshot.verdict) {
      ProgressVerdict.improving => (Icons.trending_up, AppTheme.teal),
      ProgressVerdict.steady => (Icons.trending_flat, AppTheme.softBlue),
      ProgressVerdict.needsAttention => (
        Icons.warning_amber_rounded,
        AppTheme.amber,
      ),
      ProgressVerdict.gettingStarted => (
        Icons.rocket_launch_outlined,
        scheme.primary,
      ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    snapshot.verdict.label,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (snapshot.insights.isEmpty)
              Text(
                'Complete a few workouts and a reassessment to see how you are '
                'trending. Insights compare your recent results with earlier ones.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            for (final insight in snapshot.insights)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      switch (insight.trend) {
                        InsightTrend.improving => Icons.arrow_upward,
                        InsightTrend.declining => Icons.arrow_downward,
                        InsightTrend.steady => Icons.remove,
                        InsightTrend.info => Icons.info_outline,
                      },
                      size: 18,
                      color: switch (insight.trend) {
                        InsightTrend.improving => ChartColors.goodText(context),
                        InsightTrend.declining => ChartColors.criticalText(
                          context,
                        ),
                        _ => scheme.onSurfaceVariant,
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${insight.title}. ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(text: insight.detail),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends ConsumerWidget {
  const _StatsGrid({required this.snapshot});

  final ProgressSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adherence = snapshot.adherence;
    final pain = snapshot.averagePainAfter;
    final effort = snapshot.averageEffort;
    final completion = snapshot.setCompletion;

    final unit = ref.watch(
      appControllerProvider.select(
        (value) => value.value?.weightUnit ?? WeightUnit.kg,
      ),
    );
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 148,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      children: [
        MetricCard(
          title: 'Workouts',
          value: '${snapshot.workouts}',
          subtitle: 'of ${snapshot.plannedSessions} planned',
          icon: Icons.task_alt,
          color: AppTheme.teal,
        ),
        MetricCard(
          title: 'Consistency',
          value: adherence == null ? '-' : '${(adherence * 100).round()}%',
          subtitle: adherence == null
              ? 'after your first week'
              : adherence >= 0.75
              ? 'on track'
              : 'below target',
          icon: Icons.event_available,
          color: adherence != null && adherence >= 0.75
              ? AppTheme.teal
              : AppTheme.amber,
        ),
        MetricCard(
          title: 'Streak',
          value: '${snapshot.streakWeeks} wk',
          subtitle: 'weeks meeting target',
          icon: Icons.local_fire_department_outlined,
        ),
        MetricCard(
          title: 'Pain after',
          value: pain == null ? '-' : '${pain.toStringAsFixed(1)}/10',
          subtitle: pain == null
              ? 'no sessions yet'
              : pain <= 2
              ? 'quiet-knee range'
              : 'above target',
          icon: Icons.show_chart,
          color: pain == null || pain <= 2 ? AppTheme.teal : AppTheme.amber,
        ),
        MetricCard(
          title: 'Effort',
          value: effort == null ? '-' : '${effort.toStringAsFixed(1)}/10',
          subtitle: 'average RPE',
          icon: Icons.speed,
          color: AppTheme.softBlue,
        ),
        MetricCard(
          title: 'Sets done',
          value: completion == null ? '-' : '${(completion * 100).round()}%',
          subtitle: '${snapshot.setsCompleted} of ${snapshot.setsPlanned} sets',
          icon: Icons.checklist,
          color: AppTheme.mintGreen,
        ),
        MetricCard(
          title: 'Volume',
          value: snapshot.volumeKg > 0 ? unit.format(snapshot.volumeKg) : '-',
          subtitle: 'reps x weight lifted',
          icon: Icons.fitness_center,
          color: AppTheme.softBlue,
        ),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _NoData extends StatelessWidget {
  const _NoData({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _AssessmentHistory extends StatelessWidget {
  const _AssessmentHistory({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final records = state.assessmentHistory.reversed.toList();
    if (records.isEmpty) {
      return const EmptyStateCard(
        icon: Icons.fact_check_outlined,
        title: 'No assessments saved',
        body: 'Your assessments will be listed here.',
      );
    }
    return Card(
      child: Column(
        children: [
          for (final record in records)
            ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: Text(
                '${record.kind.label} · ${record.phase.shortLabel}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${formatDate(record.createdAt)} · pain ${record.assessment.pain}/10 · '
                'week ${_weekAt(record)}',
              ),
              trailing: state.recordBefore(record) == null
                  ? null
                  : TextButton(
                      onPressed: () =>
                          context.push(AppRoutes.resultsFor(record.id)),
                      child: const Text('Compare'),
                    ),
            ),
        ],
      ),
    );
  }

  int _weekAt(AssessmentRecord record) {
    final days = record.createdAt
        .difference(record.assessment.surgeryDate)
        .inDays;
    return days <= 0 ? 0 : days ~/ 7;
  }
}

class _CheckIns extends StatelessWidget {
  const _CheckIns({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final checkIns = [...state.activeMilestoneCheckIns]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (checkIns.isEmpty) {
      return const EmptyStateCard(
        icon: Icons.add_chart,
        title: 'No check-ins since your last assessment',
        body:
            'Use Quick check-in between reassessments to log symptoms or new '
            'measurements. Your plan updates if anything changes.',
      );
    }
    return Column(
      children: [
        for (final item in checkIns)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MilestoneTile(checkIn: item),
          ),
      ],
    );
  }
}

class _MilestoneTile extends StatelessWidget {
  const _MilestoneTile({required this.checkIn});

  final MilestoneCheckIn checkIn;

  @override
  Widget build(BuildContext context) {
    String measured(int? value) =>
        value == null || value == 0 ? 'Not measured' : '$value%';
    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.fact_check_outlined),
          title: Text(
            formatDate(checkIn.createdAt),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            'Pain ${checkIn.pain}/10 · ${checkIn.swelling.label} swelling · '
            'confidence ${checkIn.confidence}/10',
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            _row('Walking', checkIn.walkingQuality.label),
            if (checkIn.weightBearing != null)
              _row('Weight bearing', checkIn.weightBearing!.label),
            _row('Running tolerance', checkIn.canRun ? 'Yes' : 'No'),
            _row(
              'Range of motion',
              '${checkIn.hasFullExtension ? 'Full extension' : 'Extension limited'}, '
                  '${checkIn.hasFunctionalFlexion ? 'functional flexion' : 'flexion limited'}',
            ),
            _row('Quad symmetry', measured(checkIn.quadStrengthSymmetry)),
            _row(
              'Hamstring symmetry',
              measured(checkIn.hamstringStrengthSymmetry),
            ),
            _row('Hip/glute symmetry', measured(checkIn.hipStrengthSymmetry)),
            _row('Hop symmetry', measured(checkIn.hopTestSymmetry)),
            _row('Balance symmetry', measured(checkIn.balanceSymmetry)),
            if (checkIn.ptClearanceForRunning != null)
              _row(
                'PT running clearance',
                checkIn.ptClearanceForRunning! ? 'Recorded' : 'Not recorded',
              ),
            if (checkIn.notes.trim().isNotEmpty)
              _row('Notes', checkIn.notes.trim()),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneCheckInSheet extends StatefulWidget {
  const _MilestoneCheckInSheet({
    required this.assessment,
    required this.latest,
  });

  final Assessment assessment;
  final MilestoneCheckIn? latest;

  @override
  State<_MilestoneCheckInSheet> createState() => _MilestoneCheckInSheetState();
}

class _MilestoneCheckInSheetState extends State<_MilestoneCheckInSheet> {
  late final readiness = widget.assessment.protocolReadiness;
  late int pain = widget.latest?.pain ?? widget.assessment.pain;
  late Swelling swelling =
      widget.latest?.swelling ?? widget.assessment.swelling;
  late WalkingQuality walkingQuality =
      widget.latest?.walkingQuality ?? widget.assessment.walkingQuality;
  late WeightBearing weightBearing =
      widget.latest?.weightBearing ?? widget.assessment.weightBearing;
  late bool canRun = widget.latest?.canRun ?? false;
  late bool hasFullExtension =
      widget.latest?.hasFullExtension ?? widget.assessment.canStraighten;
  late bool hasFunctionalFlexion =
      widget.latest?.hasFunctionalFlexion ?? widget.assessment.canBend;
  late int confidence =
      widget.latest?.confidence ?? widget.assessment.confidence;
  late int quadStrengthSymmetry =
      widget.latest?.quadStrengthSymmetry ?? readiness.quadStrengthSymmetry;
  late int hamstringStrengthSymmetry =
      widget.latest?.hamstringStrengthSymmetry ??
      readiness.hamstringStrengthSymmetry;
  late int hipStrengthSymmetry =
      widget.latest?.hipStrengthSymmetry ?? readiness.gluteStrengthSymmetry;
  late int hopTestSymmetry =
      widget.latest?.hopTestSymmetry ?? readiness.hopTestSymmetry;
  late int balanceSymmetry =
      widget.latest?.balanceSymmetry ?? readiness.balanceSymmetry;
  late int koosSportsScore =
      widget.latest?.koosSportsScore ?? readiness.koosSportsScore;
  late int ikdcScore = widget.latest?.ikdcScore ?? readiness.ikdcScore;
  late int aclRsiScore = widget.latest?.aclRsiScore ?? readiness.aclRsiScore;
  late bool painFreeLoadingActivities =
      widget.latest?.painFreeLoadingActivities ??
      readiness.painFreeLoadingActivities;
  late bool painFreeRepeatedSingleLegHops =
      widget.latest?.painFreeRepeatedSingleLegHops ??
      readiness.painFreeRepeatedSingleLegHops;
  late bool canPerformControlledSingleLegSquat =
      widget.latest?.canPerformControlledSingleLegSquat ??
      readiness.singleLegSquatTenReps;
  late bool goodLandingControl =
      widget.latest?.goodLandingControl ?? readiness.dropJumpGoodControl;
  late bool completedJogRunProgram =
      widget.latest?.completedJogRunProgram ?? readiness.completedJogRunProgram;
  late bool ptClearanceForRunning =
      widget.latest?.ptClearanceForRunning ?? readiness.ptClearedForRunning;
  late bool ptClearanceForSport = widget.latest?.ptClearanceForSport ?? false;
  late bool physicianClearanceForSport =
      widget.latest?.physicianClearanceForSport ?? readiness.mdClearedForSport;
  final notesController = TextEditingController();

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Text(
                'Quick check-in',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Log how the knee is doing between reassessments. Enter values '
                'measured or confirmed by your rehab team. Do not perform a new '
                'hop, jump, or running test just to complete this.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              QuestionSection(
                title: 'Symptoms',
                children: [
                  ScaleSliderCard(
                    title: 'Pain',
                    value: pain,
                    lowLabel: '0 = none',
                    highLabel: '10 = worst',
                    onChanged: (value) => setState(() => pain = value),
                  ),
                  ChoiceCard<Swelling>(
                    title: 'Swelling',
                    value: swelling,
                    options: Swelling.values,
                    labelOf: (value) => value.label,
                    onChanged: (value) => setState(() => swelling = value),
                  ),
                  ChoiceCard<WalkingQuality>(
                    title: 'Walking',
                    value: walkingQuality,
                    options: WalkingQuality.values,
                    labelOf: (value) => value.label,
                    onChanged: (value) =>
                        setState(() => walkingQuality = value),
                  ),
                  ChoiceCard<WeightBearing>(
                    title: 'Weight bearing',
                    value: weightBearing,
                    options: WeightBearing.values,
                    labelOf: (value) => value.label,
                    onChanged: (value) => setState(() => weightBearing = value),
                  ),
                  YesNoCard(
                    title: 'Full knee extension?',
                    value: hasFullExtension,
                    onChanged: (value) =>
                        setState(() => hasFullExtension = value),
                  ),
                  YesNoCard(
                    title: 'Functional knee flexion?',
                    value: hasFunctionalFlexion,
                    onChanged: (value) =>
                        setState(() => hasFunctionalFlexion = value),
                  ),
                  ScaleSliderCard(
                    title: 'Confidence',
                    value: confidence,
                    lowLabel: '0 = none',
                    highLabel: '10 = complete',
                    onChanged: (value) => setState(() => confidence = value),
                  ),
                ],
              ),
              QuestionSection(
                title: 'Measurements',
                subtitle: 'Leave "Not measured" unless your PT tested it.',
                children: [
                  MeasuredScoreCard(
                    title: 'Quad strength symmetry',
                    value: quadStrengthSymmetry,
                    onChanged: (value) =>
                        setState(() => quadStrengthSymmetry = value),
                  ),
                  MeasuredScoreCard(
                    title: 'Hamstring strength symmetry',
                    value: hamstringStrengthSymmetry,
                    onChanged: (value) =>
                        setState(() => hamstringStrengthSymmetry = value),
                  ),
                  MeasuredScoreCard(
                    title: 'Hip/glute strength symmetry',
                    value: hipStrengthSymmetry,
                    onChanged: (value) =>
                        setState(() => hipStrengthSymmetry = value),
                  ),
                  MeasuredScoreCard(
                    title: 'Balance symmetry',
                    value: balanceSymmetry,
                    onChanged: (value) =>
                        setState(() => balanceSymmetry = value),
                  ),
                  MeasuredScoreCard(
                    title: 'Hop test symmetry',
                    value: hopTestSymmetry,
                    onChanged: (value) =>
                        setState(() => hopTestSymmetry = value),
                  ),
                ],
              ),
              QuestionSection(
                title: 'Movement readiness',
                children: [
                  YesNoCard(
                    title: 'Pain-free loading activities?',
                    value: painFreeLoadingActivities,
                    onChanged: (value) =>
                        setState(() => painFreeLoadingActivities = value),
                  ),
                  YesNoCard(
                    title: 'PT confirmed 10 controlled single-leg squats?',
                    value: canPerformControlledSingleLegSquat,
                    onChanged: (value) => setState(
                      () => canPerformControlledSingleLegSquat = value,
                    ),
                  ),
                  YesNoCard(
                    title: 'PT confirmed controlled landing?',
                    value: goodLandingControl,
                    onChanged: (value) =>
                        setState(() => goodLandingControl = value),
                  ),
                  YesNoCard(
                    title: 'Pain-free repeated single-leg hops?',
                    value: painFreeRepeatedSingleLegHops,
                    onChanged: (value) =>
                        setState(() => painFreeRepeatedSingleLegHops = value),
                  ),
                  YesNoCard(
                    title: 'Can run without symptoms?',
                    value: canRun,
                    onChanged: (value) => setState(() => canRun = value),
                  ),
                  YesNoCard(
                    title: 'Completed a walk/jog progression?',
                    value: completedJogRunProgram,
                    onChanged: (value) =>
                        setState(() => completedJogRunProgram = value),
                  ),
                  YesNoCard(
                    title: 'PT clearance to start or progress running?',
                    value: ptClearanceForRunning,
                    onChanged: (value) =>
                        setState(() => ptClearanceForRunning = value),
                  ),
                ],
              ),
              QuestionSection(
                title: 'Return-to-sport outcomes',
                children: [
                  MeasuredScoreCard(
                    title: 'KOOS-Sports score',
                    suffix: '',
                    value: koosSportsScore,
                    onChanged: (value) =>
                        setState(() => koosSportsScore = value),
                  ),
                  MeasuredScoreCard(
                    title: 'IKDC score',
                    suffix: '',
                    value: ikdcScore,
                    onChanged: (value) => setState(() => ikdcScore = value),
                  ),
                  MeasuredScoreCard(
                    title: 'ACL-RSI score',
                    suffix: '',
                    value: aclRsiScore,
                    onChanged: (value) => setState(() => aclRsiScore = value),
                  ),
                  YesNoCard(
                    title: 'PT clearance for sport drills?',
                    value: ptClearanceForSport,
                    onChanged: (value) =>
                        setState(() => ptClearanceForSport = value),
                  ),
                  YesNoCard(
                    title: 'Physician clearance for return to sport?',
                    value: physicianClearanceForSport,
                    onChanged: (value) =>
                        setState(() => physicianClearanceForSport = value),
                  ),
                ],
              ),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'Optional notes from your check-in',
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Save check-in'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    int? optional(int value) => value > 0 ? value : null;
    Navigator.of(context).pop(
      MilestoneCheckIn(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        createdAt: DateTime.now(),
        pain: pain,
        swelling: swelling,
        walkingQuality: walkingQuality,
        canRun: canRun,
        weightBearing: weightBearing,
        hasFullExtension: hasFullExtension,
        hasFunctionalFlexion: hasFunctionalFlexion,
        confidence: confidence,
        quadStrengthSymmetry: quadStrengthSymmetry,
        hamstringStrengthSymmetry: optional(hamstringStrengthSymmetry),
        hipStrengthSymmetry: optional(hipStrengthSymmetry),
        hopTestSymmetry: hopTestSymmetry,
        balanceSymmetry: balanceSymmetry,
        koosSportsScore: optional(koosSportsScore),
        ikdcScore: optional(ikdcScore),
        aclRsiScore: optional(aclRsiScore),
        painFreeLoadingActivities: painFreeLoadingActivities,
        painFreeRepeatedSingleLegHops: painFreeRepeatedSingleLegHops,
        canPerformControlledSingleLegSquat: canPerformControlledSingleLegSquat,
        goodLandingControl: goodLandingControl,
        completedJogRunProgram: completedJogRunProgram,
        ptClearanceForRunning: ptClearanceForRunning,
        ptClearanceForSport: ptClearanceForSport,
        physicianClearanceForSport: physicianClearanceForSport,
        notes: notesController.text,
      ),
    );
  }
}
