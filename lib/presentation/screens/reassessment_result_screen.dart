import 'package:acl_rehab/core/constants/app_constants.dart';
import 'package:acl_rehab/core/navigation/app_router.dart';
import 'package:acl_rehab/core/navigation/app_tabs.dart';
import 'package:acl_rehab/core/theme/app_theme.dart';
import 'package:acl_rehab/core/utils/phase_logic.dart';
import 'package:acl_rehab/domain/models/app_state.dart';
import 'package:acl_rehab/domain/models/assessment.dart';
import 'package:acl_rehab/domain/models/rehab_plan.dart';
import 'package:acl_rehab/domain/services/assessment_comparison.dart';
import 'package:acl_rehab/domain/services/rehab_status.dart';
import 'package:acl_rehab/presentation/providers/app_state_provider.dart';
import 'package:acl_rehab/presentation/screens/plan_screen.dart';
import 'package:acl_rehab/presentation/widgets/charts.dart';
import 'package:acl_rehab/presentation/widgets/common.dart';
import 'package:acl_rehab/presentation/widgets/rehab_phase_timeline.dart';
import 'package:acl_rehab/presentation/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Compares an assessment with the one before it and shows how the plan
/// adapted: improvements, remaining weaknesses, and exercise changes.
class ReassessmentResultScreen extends ConsumerWidget {
  const ReassessmentResultScreen({required this.recordId, super.key});

  final String recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider).value;
    final record = state?.recordById(recordId);
    final previous = record == null ? null : state!.recordBefore(record);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reassessment results'),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => _close(context),
        ),
      ),
      body: state == null || record == null
          ? const Center(child: Text('This assessment could not be found.'))
          : previous == null
          ? const ResponsivePage(
              maxWidth: 760,
              children: [
                EmptyStateCard(
                  icon: Icons.info_outline,
                  title: 'Nothing to compare yet',
                  body:
                      'This is your first assessment. Complete a reassessment '
                      'later to see what has changed.',
                ),
              ],
            )
          : _Results(
              state: state,
              comparison: _compare(state, record.id, previous.id),
              recordDate: record.createdAt,
              previousDate: previous.createdAt,
            ),
    );
  }

  AssessmentComparison _compare(
    AppState state,
    String recordId,
    String previousId,
  ) {
    final record = state.recordById(recordId)!;
    final previous = state.recordById(previousId)!;
    // "Before" is the last known status: the previous assessment plus any
    // check-in logged before this reassessment.
    final checkIn = state.latestCheckInBefore(
      record.createdAt,
      since: previous.createdAt,
    );
    final newPlan = state.planForRecord(record.id) ?? state.activePlan!;
    final newIndex = state.plans.indexWhere((plan) => plan.id == newPlan.id);
    final previousPlan = newIndex > 0 ? state.plans[newIndex - 1] : null;
    return AssessmentComparison.compare(
      before: RehabStatus.from(previous.assessment, milestone: checkIn),
      after: RehabStatus.from(record.assessment),
      previousPhase: evaluateRehabPhase(
        previous.assessment,
        milestone: checkIn,
      ).phase,
      currentPhase: record.phase,
      previousPlan: previousPlan,
      newPlan: newPlan,
    );
  }

  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.dashboard);
    }
  }
}

class _Results extends ConsumerWidget {
  const _Results({
    required this.state,
    required this.comparison,
    required this.recordDate,
    required this.previousDate,
  });

  final AppState state;
  final AssessmentComparison comparison;
  final DateTime recordDate;
  final DateTime previousDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final improvements = comparison.improvements;
    final declines = comparison.declines;
    final newlyMeasured = comparison.newlyMeasured;
    final diff = comparison.planDiff;
    final phaseDelta = comparison.phaseDelta;

    return ResponsivePage(
      maxWidth: 860,
      children: [
        Text(
          '${formatDate(previousDate)} -> ${formatDate(recordDate)}',
          style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Card(
          color: scheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      phaseDelta > 0
                          ? Icons.trending_up
                          : phaseDelta < 0
                          ? Icons.trending_down
                          : Icons.trending_flat,
                      color: scheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        phaseDelta > 0
                            ? 'You moved up to ${comparison.currentPhase.shortLabel}'
                            : phaseDelta < 0
                            ? 'Stepped back to ${comparison.currentPhase.shortLabel}'
                            : 'Staying in ${comparison.currentPhase.shortLabel}',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  phaseDelta == 0
                      ? '${comparison.currentPhase.label}. Your plan was re-dosed for your new results.'
                      : 'From ${comparison.previousPhase.label} to ${comparison.currentPhase.label}.',
                  style: TextStyle(color: scheme.onPrimaryContainer),
                ),
                const SizedBox(height: 14),
                RehabPhaseTimeline(
                  phase: comparison.currentPhase,
                  progress: (comparison.currentPhase.order + 1) / 5,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusPill(
                      label: '${improvements.length} improved',
                      icon: Icons.arrow_upward,
                      color: AppTheme.teal,
                    ),
                    StatusPill(
                      label: '${declines.length} declined',
                      icon: Icons.arrow_downward,
                      color: AppTheme.softRed,
                    ),
                    StatusPill(
                      label:
                          '${comparison.remainingWeaknesses.length} to work on',
                      icon: Icons.flag_outlined,
                      color: AppTheme.amber,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppConstants.sectionGap),
        const SectionHeader(title: 'What improved'),
        const SizedBox(height: 10),
        if (improvements.isEmpty)
          const EmptyStateCard(
            icon: Icons.hourglass_empty,
            title: 'No measurable change yet',
            body:
                'That is normal between some tests. Consistent sessions usually '
                'show up in the next reassessment.',
          )
        else
          _MetricList(items: improvements, improved: true),
        if (declines.isNotEmpty) ...[
          const SizedBox(height: AppConstants.sectionGap),
          const SectionHeader(title: 'What got worse'),
          const SizedBox(height: 10),
          _MetricList(items: declines, improved: false),
          const SizedBox(height: 8),
          Text(
            'Your plan has been adjusted for these results. If symptoms keep '
            'worsening, contact your clinical team.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
        if (newlyMeasured.isNotEmpty) ...[
          const SizedBox(height: AppConstants.sectionGap),
          const SectionHeader(title: 'Newly measured'),
          const SizedBox(height: 10),
          _MetricList(items: newlyMeasured, improved: null),
        ],
        const SizedBox(height: AppConstants.sectionGap),
        const SectionHeader(title: 'Still working on'),
        const SizedBox(height: 10),
        if (comparison.remainingWeaknesses.isEmpty)
          const EmptyStateCard(
            icon: Icons.celebration_outlined,
            title: 'No weaknesses flagged',
            body: 'Your plan now focuses on the next phase goals.',
          )
        else
          for (final area in comparison.remainingWeaknesses) ...[
            FocusAreaTile(area: area),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: AppConstants.sectionGap),
        const SectionHeader(title: 'How your plan changed'),
        const SizedBox(height: 10),
        _PlanChanges(diff: diff, plan: state.activePlan),
        const SizedBox(height: AppConstants.sectionGap),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () async {
                await ref
                    .read(appControllerProvider.notifier)
                    .selectTab(AppTab.plan);
                if (context.mounted) context.go(AppRoutes.dashboard);
              },
              icon: const Icon(Icons.assignment_outlined),
              label: const Text('View updated plan'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                await ref
                    .read(appControllerProvider.notifier)
                    .selectTab(AppTab.workout);
                if (context.mounted) context.go(AppRoutes.dashboard);
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start a workout'),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricList extends StatelessWidget {
  const _MetricList({required this.items, required this.improved});

  final List<MetricChange> items;

  /// Null for neutral rows such as newly measured values.
  final bool? improved;

  @override
  Widget build(BuildContext context) {
    final icon = switch (improved) {
      true => Icons.arrow_upward,
      false => Icons.arrow_downward,
      null => Icons.fiber_new_outlined,
    };
    final color = switch (improved) {
      true => ChartColors.goodText(context),
      false => ChartColors.criticalText(context),
      null => Theme.of(context).colorScheme.primary,
    };
    return Card(
      child: Column(
        children: [
          for (final item in items)
            ListTile(
              leading: Icon(icon, color: color),
              title: Text(
                item.label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              trailing: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${item.before}  ->  ',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextSpan(
                      text: item.after,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlanChanges extends StatelessWidget {
  const _PlanChanges({required this.diff, required this.plan});

  final PlanDiff diff;
  final RehabPlan? plan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (diff.isEmpty) {
      return EmptyStateCard(
        icon: Icons.check_circle_outline,
        title: 'Same exercises, same doses',
        body: plan == null
            ? 'Your plan is unchanged.'
            : 'Your results did not call for exercise changes. Keep logging '
                  'feedback so doses keep adapting.',
      );
    }
    Widget row(IconData icon, Color color, String title, String? detail) {
      return ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: detail == null ? null : Text(detail),
      );
    }

    return Card(
      child: Column(
        children: [
          for (final change in diff.swapped)
            row(
              Icons.swap_horiz,
              AppTheme.softBlue,
              change.title,
              change.detail,
            ),
          for (final change in diff.doseChanges)
            row(Icons.tune, AppTheme.teal, change.title, change.detail),
          for (final name in diff.added)
            row(Icons.add_circle_outline, AppTheme.teal, name, 'Added'),
          for (final name in diff.removed)
            row(
              Icons.remove_circle_outline,
              scheme.onSurfaceVariant,
              name,
              'Removed',
            ),
        ],
      ),
    );
  }
}
