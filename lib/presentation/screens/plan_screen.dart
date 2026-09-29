import 'package:acl_rehab/core/constants/app_constants.dart';
import 'package:acl_rehab/core/navigation/app_router.dart';
import 'package:acl_rehab/core/navigation/app_tabs.dart';
import 'package:acl_rehab/core/theme/app_theme.dart';
import 'package:acl_rehab/data/exercise_catalog.dart';
import 'package:acl_rehab/domain/models/app_state.dart';
import 'package:acl_rehab/domain/models/assessment.dart';
import 'package:acl_rehab/domain/models/exercise.dart';
import 'package:acl_rehab/domain/models/rehab_plan.dart';
import 'package:acl_rehab/domain/models/training_profile.dart';
import 'package:acl_rehab/domain/services/assessment_comparison.dart';
import 'package:acl_rehab/domain/services/reassessment_advisor.dart';
import 'package:acl_rehab/presentation/providers/app_state_provider.dart';
import 'package:acl_rehab/presentation/widgets/common.dart';
import 'package:acl_rehab/presentation/widgets/exercise_sheets.dart';
import 'package:acl_rehab/presentation/widgets/section_header.dart';
import 'package:acl_rehab/presentation/widgets/training_setup_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appControllerProvider).value;
    final plan = appState?.activePlan;
    final assessment = appState?.assessment;
    if (appState == null || plan == null || assessment == null) {
      return const Scaffold(
        body: Center(child: Text('Complete your assessment to create a plan.')),
      );
    }
    final profile = assessment.profile;
    final recommendation = ReassessmentAdvisor.evaluate(appState);

    return Scaffold(
      body: ResponsivePage(
        maxWidth: 920,
        children: [
          PageHeader(
            title: 'Your Plan',
            subtitle:
                'Version ${plan.version} · ${formatDate(plan.createdAt)} · '
                '${plan.trigger.label}',
            actions: [
              OutlinedButton.icon(
                onPressed: () => showTrainingSetupSheet(context, ref),
                icon: const Icon(Icons.tune),
                label: const Text('Training setup'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (profile.isDefault) ...[
            _PersonalizeCard(onTap: () => showTrainingSetupSheet(context, ref)),
            const SizedBox(height: 12),
          ],
          _SummaryCard(plan: plan, profile: profile),
          const SizedBox(height: AppConstants.sectionGap),
          const SectionHeader(title: 'Why this plan'),
          const SizedBox(height: 10),
          _RationaleCard(notes: plan.rationale),
          if (plan.focusAreas.isNotEmpty) ...[
            const SizedBox(height: AppConstants.sectionGap),
            const SectionHeader(title: 'Focus areas'),
            const SizedBox(height: 10),
            _FocusAreas(areas: plan.focusAreas),
          ],
          const SizedBox(height: AppConstants.sectionGap),
          _ValidationCard(report: plan.validation),
          const SizedBox(height: AppConstants.sectionGap),
          SectionHeader(
            title: 'Sessions',
            action: FilledButton.icon(
              onPressed: () => ref
                  .read(appControllerProvider.notifier)
                  .selectTab(AppTab.workout),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start'),
            ),
          ),
          const SizedBox(height: 10),
          if (plan.sessions.isEmpty)
            const EmptyStateCard(
              icon: Icons.lock_outline,
              title: 'No exercises are unlocked yet',
              body:
                  'Your current answers keep every exercise locked. Review the '
                  'phase blockers on the Today tab with your clinical team.',
            ),
          for (final session in plan.sessions) ...[
            _SessionCard(session: session, appState: appState),
            const SizedBox(height: 12),
          ],
          if (plan.excluded.isNotEmpty) ...[
            const SizedBox(height: 8),
            const SectionHeader(title: 'Not in your plan yet'),
            const SizedBox(height: 10),
            _NotesCard(notes: plan.excluded, icon: Icons.lock_clock_outlined),
          ],
          const SizedBox(height: AppConstants.sectionGap),
          InfoListCard(
            title: 'How your plan progresses',
            icon: Icons.trending_up,
            color: AppTheme.teal,
            items: plan.progressionRules,
          ),
          const SizedBox(height: 12),
          _ReassessCard(recommendation: recommendation),
          if (appState.plans.length > 1) ...[
            const SizedBox(height: AppConstants.sectionGap),
            const SectionHeader(title: 'Plan history'),
            const SizedBox(height: 10),
            _HistoryCard(plans: appState.plans),
          ],
        ],
      ),
    );
  }
}

class _PersonalizeCard extends StatelessWidget {
  const _PersonalizeCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.tertiaryContainer,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(Icons.auto_awesome, color: scheme.onTertiaryContainer),
        title: Text(
          'Personalize your plan',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: scheme.onTertiaryContainer,
          ),
        ),
        subtitle: Text(
          'Tell us your goal, schedule, and equipment so exercises fit you.',
          style: TextStyle(color: scheme.onTertiaryContainer),
        ),
        trailing: Icon(Icons.chevron_right, color: scheme.onTertiaryContainer),
        onTap: onTap,
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.plan, required this.profile});

  final RehabPlan plan;
  final TrainingProfile profile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${plan.phase.shortLabel} · ${plan.phase.label}',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.flag_outlined,
                  label: profile.goalSummary,
                ),
                _InfoChip(
                  icon: Icons.calendar_view_week,
                  label: '${plan.sessionsPerWeek} days a week',
                ),
                _InfoChip(
                  icon: Icons.timer_outlined,
                  label: 'About ${plan.minutesPerSession} min',
                ),
                _InfoChip(
                  icon: Icons.home_repair_service_outlined,
                  label: equipmentSummary(profile),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Suggested week',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 560;
                return Wrap(
                  spacing: compact ? 4 : 6,
                  runSpacing: 6,
                  children: [
                    for (var i = 0; i < plan.weeklySchedule.length; i++)
                      _DayChip(
                        day: days[i],
                        label: plan.weeklySchedule[i],
                        compact: compact,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.label,
    required this.compact,
  });

  final String day;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final training =
        label.startsWith('Session') || label.startsWith('Motion &');
    final light = label.startsWith('Light') || label == 'Motion only';
    final short = training
        ? label
              .replaceFirst('Session ', '')
              .replaceFirst('Motion & Activation', 'Motion')
        : light
        ? 'Light'
        : 'Rest';

    return Semantics(
      label: '$day: $label',
      child: ExcludeSemantics(
        child: Tooltip(
          message: label,
          child: Container(
            width: compact ? 40 : 92,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: training ? scheme.primary : scheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: training ? scheme.primary : scheme.outlineVariant,
              ),
            ),
            child: Column(
              children: [
                Text(
                  day,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: training
                        ? scheme.onPrimary
                        : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  compact ? short : label.replaceFirst('Light day: ', ''),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: training ? scheme.onPrimary : scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RationaleCard extends StatelessWidget {
  const _RationaleCard({required this.notes});

  final List<PlanNote> notes;

  @override
  Widget build(BuildContext context) {
    return _NotesCard(notes: notes, icon: Icons.lightbulb_outline);
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.notes, required this.icon});

  final List<PlanNote> notes;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < notes.length; i++) ...[
              if (i > 0) const Divider(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 20, color: scheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notes[i].title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          notes[i].detail,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FocusAreas extends StatelessWidget {
  const _FocusAreas({required this.areas});

  final List<FocusArea> areas;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 640 ? 2 : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final area in areas)
              SizedBox(
                width: width,
                child: FocusAreaTile(area: area),
              ),
          ],
        );
      },
    );
  }
}

class FocusAreaTile extends StatelessWidget {
  const FocusAreaTile({required this.area, super.key});

  final FocusArea area;

  @override
  Widget build(BuildContext context) {
    final color = switch (area.priority) {
      FocusPriority.high => AppTheme.softRed,
      FocusPriority.medium => AppTheme.amber,
      FocusPriority.low => AppTheme.teal,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    area.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                StatusPill(
                  label: area.priority.label,
                  icon: area.priority == FocusPriority.high
                      ? Icons.priority_high
                      : Icons.adjust,
                  color: color,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              area.detail,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValidationCard extends StatelessWidget {
  const _ValidationCard({required this.report});

  final PlanValidationReport report;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(
            report.warnings > 0 ? Icons.rule : Icons.verified_outlined,
            color: report.warnings > 0 ? AppTheme.amber : AppTheme.teal,
          ),
          title: const Text(
            'Plan quality check',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            '${report.checks.length} checks: ${report.passed} passed'
            '${report.adjusted > 0 ? ', ${report.adjusted} adjusted' : ''}'
            '${report.warnings > 0 ? ', ${report.warnings} to review' : ''}',
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            Text(
              'Before a plan is shown, it is checked against your assessment. '
              'Problems are fixed automatically; anything that cannot be fixed '
              'is flagged here.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            for (final check in report.checks)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  switch (check.status) {
                    CheckStatus.passed => Icons.check_circle_outline,
                    CheckStatus.adjusted => Icons.auto_fix_high,
                    CheckStatus.warning => Icons.warning_amber_rounded,
                  },
                  color: switch (check.status) {
                    CheckStatus.passed => AppTheme.teal,
                    CheckStatus.adjusted => AppTheme.softBlue,
                    CheckStatus.warning => AppTheme.amber,
                  },
                ),
                title: Text(
                  check.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${switch (check.status) {
                    CheckStatus.passed => 'Passed',
                    CheckStatus.adjusted => 'Adjusted',
                    CheckStatus.warning => 'Review',
                  }}: ${check.detail}',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends ConsumerWidget {
  const _SessionCard({required this.session, required this.appState});

  final PlanSession session;
  final AppState appState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.name,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          session.focus,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    avatar: const Icon(Icons.timer_outlined, size: 16),
                    label: Text('~${session.estimatedMinutes} min'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            for (final item in session.exercises)
              _PlanExerciseTile(item: item, appState: appState),
          ],
        ),
      ),
    );
  }
}

class _PlanExerciseTile extends ConsumerWidget {
  const _PlanExerciseTile({required this.item, required this.appState});

  final PlanExercise item;
  final AppState appState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercise = ExerciseCatalog.byId(item.exerciseId);
    if (exercise == null) return const SizedBox.shrink();
    final dose = item.doseFor(appState.exerciseProgressions[exercise.id]);
    final scheme = Theme.of(context).colorScheme;
    final changed = dose.sets != item.prescription.sets;

    return ListTile(
      onTap: () => showExerciseDetailSheet(context, ref, item: item),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: CircleAvatar(
        backgroundColor: scheme.secondaryContainer,
        child: Icon(
          purposeIcon(exercise.purpose),
          color: scheme.onSecondaryContainer,
          size: 20,
        ),
      ),
      title: Text(
        exercise.name,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${dose.summary} · ${dose.frequency}'
            '${changed ? ' · ${dose.sets > item.prescription.sets ? 'progressed' : 'eased'} from your feedback' : ''}',
          ),
          if (item.substitutionReason != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Icon(Icons.swap_horiz, size: 14, color: scheme.primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.substitutionReason!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

IconData purposeIcon(TrainingPurpose purpose) {
  switch (purpose) {
    case TrainingPurpose.kneeExtension:
    case TrainingPurpose.kneeFlexion:
      return Icons.accessibility_new;
    case TrainingPurpose.quadActivation:
      return Icons.bolt;
    case TrainingPurpose.circulation:
      return Icons.water_drop_outlined;
    case TrainingPurpose.quadStrength:
    case TrainingPurpose.singleLegStrength:
    case TrainingPurpose.posteriorChain:
    case TrainingPurpose.hamstringStrength:
    case TrainingPurpose.calfStrength:
      return Icons.fitness_center;
    case TrainingPurpose.hipStability:
      return Icons.join_inner;
    case TrainingPurpose.balance:
      return Icons.self_improvement;
    case TrainingPurpose.landing:
    case TrainingPurpose.plyometric:
      return Icons.height;
    case TrainingPurpose.running:
      return Icons.directions_run;
    case TrainingPurpose.changeOfDirection:
      return Icons.alt_route;
    case TrainingPurpose.conditioning:
      return Icons.pedal_bike;
  }
}

class _ReassessCard extends StatelessWidget {
  const _ReassessCard({required this.recommendation});

  final ReassessmentRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  recommendation.isDue
                      ? Icons.event_available
                      : Icons.event_note,
                  color: recommendation.isDue ? AppTheme.teal : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    recommendation.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(recommendation.message),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: recommendation.progress,
              minHeight: 6,
              borderRadius: BorderRadius.circular(999),
              semanticsLabel: 'Progress toward next reassessment',
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: recommendation.isDue
                  ? FilledButton.icon(
                      onPressed: () => context.push(AppRoutes.reassess),
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Start reassessment'),
                    )
                  : OutlinedButton.icon(
                      onPressed: () => context.push(AppRoutes.reassess),
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Reassess now'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.plans});

  final List<RehabPlan> plans;

  @override
  Widget build(BuildContext context) {
    final recent = plans.reversed.take(6).toList();
    return Card(
      child: Column(
        children: [
          for (final plan in recent)
            () {
              final index = plans.indexOf(plan);
              final previous = index > 0 ? plans[index - 1] : null;
              final diff = PlanDiff.between(previous, plan);
              return ListTile(
                leading: CircleAvatar(child: Text('v${plan.version}')),
                title: Text(
                  '${plan.trigger.label} · ${plan.phase.shortLabel}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${formatDate(plan.createdAt)} · '
                  '${previous == null ? '${plan.exerciseIds.length} exercises' : diff.summary}',
                ),
                trailing: plan == plans.last
                    ? const StatusPill(
                        label: 'Active',
                        icon: Icons.check,
                        color: AppTheme.teal,
                      )
                    : null,
              );
            }(),
        ],
      ),
    );
  }
}
