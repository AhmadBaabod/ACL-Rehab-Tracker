import 'package:acl_rehab/core/constants/app_constants.dart';
import 'package:acl_rehab/core/navigation/app_router.dart';
import 'package:acl_rehab/core/navigation/app_tabs.dart';
import 'package:acl_rehab/core/theme/app_theme.dart';
import 'package:acl_rehab/core/utils/phase_logic.dart';
import 'package:acl_rehab/data/exercise_catalog.dart';
import 'package:acl_rehab/domain/models/app_state.dart';
import 'package:acl_rehab/domain/models/assessment.dart';
import 'package:acl_rehab/domain/models/rehab_plan.dart';
import 'package:acl_rehab/domain/services/progress_analytics.dart';
import 'package:acl_rehab/domain/services/reassessment_advisor.dart';
import 'package:acl_rehab/presentation/providers/app_state_provider.dart';
import 'package:acl_rehab/presentation/screens/plan_screen.dart';
import 'package:acl_rehab/presentation/widgets/clinical_disclaimer_banner.dart';
import 'package:acl_rehab/presentation/widgets/common.dart';
import 'package:acl_rehab/presentation/widgets/metric_card.dart';
import 'package:acl_rehab/presentation/widgets/rehab_phase_timeline.dart';
import 'package:acl_rehab/presentation/widgets/section_header.dart';
import 'package:acl_rehab/presentation/widgets/training_setup_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appControllerProvider).value;
    final assessment = appState?.assessment;
    if (appState == null || assessment == null) {
      return const Scaffold(body: Center(child: Text('Assessment needed.')));
    }

    final milestone = appState.latestMilestone;
    final evaluation = evaluateRehabPhase(assessment, milestone: milestone);
    final plan = appState.activePlan;
    final recommendation = ReassessmentAdvisor.evaluate(appState);
    final month = ProgressAnalytics.compute(appState, ProgressPeriod.month);
    // The most recent pain reading from an assessment, check-in, or workout.
    final latestWorkout = appState.latestWorkout;
    final painReadings = <(DateTime, int)>[
      (appState.assessmentUpdatedAt ?? DateTime(2000), assessment.pain),
      if (milestone != null) (milestone.createdAt, milestone.pain),
      if (latestWorkout != null)
        (latestWorkout.completedAt, latestWorkout.painAfter),
    ];
    final latestPain = painReadings
        .reduce((a, b) => b.$1.isAfter(a.$1) ? b : a)
        .$2;
    final controller = ref.read(appControllerProvider.notifier);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;
          return ResponsivePage(
            maxWidth: 980,
            children: [
              PageHeader(
                title: 'Today',
                subtitle:
                    'Week ${assessment.weeksPostOp} · ${evaluation.phase.label}',
                actions: [
                  if (plan != null && plan.sessions.isNotEmpty)
                    FilledButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        controller.selectTab(AppTab.workout);
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: Text(
                        'Start ${appState.nextSession?.name ?? 'session'}',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (recommendation.isDue) ...[
                _ReassessmentBanner(
                  recommendation: recommendation,
                  onStart: () => context.push(AppRoutes.reassess),
                  onLater: () => controller.snoozeReassessment(
                    Duration(days: recommendation.isUrgent ? 1 : 3),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (assessment.profile.isDefault) ...[
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.auto_awesome),
                    title: const Text(
                      'Personalize your plan',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                      'Add your goal, schedule, and equipment so every exercise fits you.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showTrainingSetupSheet(context, ref),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (evaluation.safetyFlags.isNotEmpty) ...[
                InfoListCard(
                  title: 'Please contact your clinical team',
                  items: evaluation.safetyFlags,
                  icon: Icons.medical_information_outlined,
                  color: AppTheme.softRed,
                ),
                const SizedBox(height: 12),
              ],
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _NextSessionCard(state: appState, plan: plan),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _WeekCard(state: appState, snapshot: month),
                    ),
                  ],
                )
              else ...[
                _NextSessionCard(state: appState, plan: plan),
                const SizedBox(height: 12),
                _WeekCard(state: appState, snapshot: month),
              ],
              const SizedBox(height: 16),
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isWide ? 4 : 2,
                  mainAxisExtent: 148,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                children: [
                  MetricCard(
                    title: 'Week',
                    value: '${assessment.weeksPostOp}',
                    subtitle: 'since surgery',
                    icon: Icons.calendar_today_outlined,
                  ),
                  MetricCard(
                    title: 'Latest pain',
                    value: '$latestPain/10',
                    subtitle: latestPain <= 2
                        ? 'quiet-knee range'
                        : 'monitor response',
                    icon: Icons.show_chart,
                    color: latestPain <= 2 ? AppTheme.teal : AppTheme.amber,
                  ),
                  MetricCard(
                    title: 'Workouts',
                    value: '${appState.workoutLogs.length}',
                    subtitle: 'completed in total',
                    icon: Icons.check_circle_outline,
                    color: AppTheme.mintGreen,
                  ),
                  MetricCard(
                    title: 'Plan',
                    value: plan == null ? '-' : 'v${plan.version}',
                    subtitle: plan == null
                        ? 'not generated'
                        : '${plan.exerciseIds.length} exercises',
                    icon: Icons.assignment_outlined,
                    color: AppTheme.softBlue,
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.sectionGap),
              _PhaseCard(evaluation: evaluation),
              if (plan != null && plan.focusAreas.isNotEmpty) ...[
                const SizedBox(height: AppConstants.sectionGap),
                SectionHeader(
                  title: 'Your focus areas',
                  action: TextButton(
                    onPressed: () => controller.selectTab(AppTab.plan),
                    child: const Text('View plan'),
                  ),
                ),
                const SizedBox(height: 10),
                for (final area in plan.focusAreas.take(3)) ...[
                  FocusAreaTile(area: area),
                  const SizedBox(height: 10),
                ],
              ],
              if (!recommendation.isDue) ...[
                const SizedBox(height: 10),
                _NextTestCard(recommendation: recommendation),
              ],
              const SizedBox(height: AppConstants.sectionGap),
              const InfoListCard(
                title: 'Progress only with a quiet knee',
                icon: Icons.health_and_safety_outlined,
                color: AppTheme.softRed,
                items: [
                  'Do not advance after swelling, instability, locking, or giving way.',
                  'Surgeon and PT restrictions always override this plan.',
                  'Reassess every 2-4 weeks, or sooner when the app suggests it.',
                ],
              ),
              const SizedBox(height: 12),
              const ClinicalDisclaimerBanner(),
            ],
          );
        },
      ),
    );
  }
}

class _ReassessmentBanner extends StatelessWidget {
  const _ReassessmentBanner({
    required this.recommendation,
    required this.onStart,
    required this.onLater,
  });

  final ReassessmentRecommendation recommendation;
  final VoidCallback onStart;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final urgent = recommendation.isUrgent;
    final background = urgent
        ? scheme.errorContainer
        : scheme.tertiaryContainer;
    final foreground = urgent
        ? scheme.onErrorContainer
        : scheme.onTertiaryContainer;

    return Semantics(
      container: true,
      liveRegion: true,
      child: Card(
        color: background,
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    urgent
                        ? Icons.warning_amber_rounded
                        : Icons.celebration_outlined,
                    color: foreground,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      recommendation.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: foreground,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(recommendation.message, style: TextStyle(color: foreground)),
              if (recommendation.evidence.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final item in recommendation.evidence)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check, size: 16, color: foreground),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item,
                            style: TextStyle(color: foreground),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Start reassessment'),
                  ),
                  TextButton(
                    onPressed: onLater,
                    style: TextButton.styleFrom(foregroundColor: foreground),
                    child: const Text('Remind me later'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextSessionCard extends ConsumerWidget {
  const _NextSessionCard({required this.state, required this.plan});

  final AppState state;
  final RehabPlan? plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = state.nextSession;
    if (plan == null || session == null) {
      return EmptyStateCard(
        icon: Icons.lock_outline,
        title: 'No exercises unlocked yet',
        body:
            'Your current results keep every exercise locked. Review the phase '
            'criteria below with your clinical team, then reassess.',
        actionLabel: 'Update assessment',
        onAction: () => context.push(AppRoutes.reassess),
      );
    }
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
                          'Next: ${session.name}',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${session.focus} · about ${session.estimatedMinutes} min',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            for (final item in session.exercises)
              () {
                final exercise = ExerciseCatalog.byId(item.exerciseId);
                if (exercise == null) return const SizedBox.shrink();
                final dose = item.doseFor(
                  state.exerciseProgressions[exercise.id],
                );
                return ListTile(
                  dense: true,
                  leading: Icon(
                    purposeIcon(exercise.purpose),
                    color: scheme.primary,
                  ),
                  title: Text(
                    exercise.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(dose.summary),
                );
              }(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => ref
                      .read(appControllerProvider.notifier)
                      .selectTab(AppTab.workout),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start workout'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekCard extends ConsumerWidget {
  const _WeekCard({required this.state, required this.snapshot});

  final AppState state;
  final ProgressSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = state.activePlan?.sessionsPerWeek ?? 3;
    final done = state.workoutsThisWeek(DateTime.now());
    final adherence = snapshot.adherence;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This week',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$done',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 6),
                  child: Text('of $target sessions'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (done / target).clamp(0.0, 1.0),
              minHeight: 8,
              borderRadius: BorderRadius.circular(999),
              semanticsLabel: 'Sessions this week: $done of $target',
            ),
            const SizedBox(height: 12),
            Text(
              adherence == null
                  ? 'Consistency appears after your first week.'
                  : '${(adherence * 100).round()}% of planned sessions in the last 30 days'
                        '${snapshot.streakWeeks > 0 ? ' · ${snapshot.streakWeeks}-week streak' : ''}',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => ref
                  .read(appControllerProvider.notifier)
                  .selectTab(AppTab.progress),
              icon: const Icon(Icons.insights_outlined),
              label: const Text('View progress'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhaseCard extends StatelessWidget {
  const _PhaseCard({required this.evaluation});

  final PhaseEvaluation evaluation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current phase',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        evaluation.phase.label,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: scheme.onPrimaryContainer,
                            ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.timeline, size: 18),
                  label: Text(evaluation.phase.shortLabel),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 16),
            RehabPhaseTimeline(
              phase: evaluation.phase,
              progress: evaluation.progress,
            ),
            const SizedBox(height: 16),
            Text(
              evaluation.blockers.isEmpty
                  ? 'Phase goals'
                  : 'To reach the next phase',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 6),
            for (final item
                in (evaluation.blockers.isEmpty
                        ? evaluation.goals
                        : evaluation.blockers)
                    .take(4))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      evaluation.blockers.isEmpty
                          ? Icons.flag_outlined
                          : Icons.lock_outline,
                      size: 16,
                      color: scheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(color: scheme.onPrimaryContainer),
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

class _NextTestCard extends StatelessWidget {
  const _NextTestCard({required this.recommendation});

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
                const Icon(Icons.event_note),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    recommendation.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(recommendation.message),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: recommendation.progress,
              minHeight: 6,
              borderRadius: BorderRadius.circular(999),
              semanticsLabel: 'Progress toward next reassessment',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: [
                for (final item in recommendation.evidence)
                  Text(item, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
