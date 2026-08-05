import 'package:acl_rehab/core/constants/app_constants.dart';
import 'package:acl_rehab/core/theme/app_theme.dart';
import 'package:acl_rehab/core/utils/phase_logic.dart';
import 'package:acl_rehab/data/exercise_catalog.dart';
import 'package:acl_rehab/domain/models/assessment.dart';
import 'package:acl_rehab/domain/models/exercise.dart';
import 'package:acl_rehab/domain/models/session_log.dart';
import 'package:acl_rehab/presentation/providers/app_state_provider.dart';
import 'package:acl_rehab/presentation/widgets/clinical_disclaimer_banner.dart';
import 'package:acl_rehab/presentation/widgets/metric_card.dart';
import 'package:acl_rehab/presentation/widgets/rehab_phase_timeline.dart';
import 'package:acl_rehab/presentation/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appStateAsync = ref.watch(appControllerProvider);

    return appStateAsync.when(
      data: (appState) {
        final assessment = appState.assessment;
        if (assessment == null) {
          return const Scaffold(
            body: Center(child: Text('Assessment needed.')),
          );
        }

        final latestMilestone = appState.latestMilestone;
        final evaluation = evaluateRehabPhase(
          assessment,
          milestone: latestMilestone,
        );
        final todayExercises = ExerciseCatalog.sessionFor(
          assessment,
          milestone: latestMilestone,
          phase: evaluation.phase,
        );
        final latestPain = latestMilestone?.pain ?? assessment.pain;
        final completedSessions = appState.sessionLogs.length;
        final progressions = appState.exerciseProgressions.values
            .where(
              (item) =>
                  item.recommendation == ProgressionRecommendation.progress,
            )
            .length;
        final regressions = appState.exerciseProgressions.values
            .where(
              (item) =>
                  item.recommendation == ProgressionRecommendation.regress,
            )
            .length;

        return Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 720;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppConstants.horizontalPadding),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Header(
                            week: assessment.weeksPostOp,
                            phase: evaluation.phase,
                            onStartSession: () async {
                              HapticFeedback.mediumImpact();
                              await ref
                                  .read(appControllerProvider.notifier)
                                  .updateSelectedIndex(1);
                            },
                          ),
                          const SizedBox(height: 18),
                          const ClinicalDisclaimerBanner(),
                          const SizedBox(height: AppConstants.sectionGap),
                          Card(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Current Phase',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleMedium,
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              evaluation.phase.label,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headlineSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      _PhaseBadge(phase: evaluation.phase),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  RehabPhaseTimeline(
                                    phase: evaluation.phase,
                                    progress: evaluation.progress,
                                  ),
                                  if (evaluation.blockers.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    _CriteriaList(
                                      title: 'Current progression blockers',
                                      items: evaluation.blockers
                                          .take(3)
                                          .toList(),
                                      icon: Icons.lock_outline,
                                      color: AppTheme.amber,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          GridView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: isWide ? 4 : 2,
                                  mainAxisExtent: 150,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                ),
                            children: [
                              MetricCard(
                                title: 'Week',
                                value: '${assessment.weeksPostOp}',
                                subtitle: 'post-op',
                                icon: Icons.calendar_today_outlined,
                              ),
                              MetricCard(
                                title: 'Pain',
                                value: '$latestPain/10',
                                subtitle: latestPain <= 2
                                    ? 'quiet knee target'
                                    : 'monitor response',
                                icon: Icons.show_chart,
                                color: latestPain <= 2
                                    ? AppTheme.teal
                                    : AppTheme.amber,
                              ),
                              MetricCard(
                                title: 'Sessions',
                                value: '$completedSessions',
                                subtitle: 'completed exercises',
                                icon: Icons.check_circle_outline,
                                color: AppTheme.mintGreen,
                              ),
                              MetricCard(
                                title: 'Adaptation',
                                value: '+$progressions / -$regressions',
                                subtitle: 'progressions / regressions',
                                icon: Icons.tune,
                                color: AppTheme.teal,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppConstants.sectionGap),
                          SectionHeader(
                            title: 'Today\'s Session',
                            action: FilledButton.icon(
                              onPressed: () async {
                                HapticFeedback.mediumImpact();
                                await ref
                                    .read(appControllerProvider.notifier)
                                    .updateSelectedIndex(1);
                              },
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Start'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (todayExercises.isEmpty)
                            _EmptyCard(
                              icon: Icons.lock_outline,
                              title: 'No exercise is unlocked yet',
                              body:
                                  'Review pain, swelling, range of motion, and clinical restrictions before progressing.',
                            )
                          else
                            Column(
                              children: todayExercises
                                  .map(
                                    (exercise) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: Card(
                                        child: ListTile(
                                          minVerticalPadding: 14,
                                          leading: CircleAvatar(
                                            backgroundColor: Theme.of(
                                              context,
                                            ).colorScheme.secondaryContainer,
                                            child: Icon(
                                              Icons.sports_gymnastics,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSecondaryContainer,
                                            ),
                                          ),
                                          title: Text(
                                            exercise.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          subtitle: Text(
                                            '${exercise.sets} sets - ${exercise.reps} reps - ${exercise.category.label}',
                                          ),
                                          trailing: const Icon(
                                            Icons.chevron_right,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          const SizedBox(height: AppConstants.sectionGap),
                          SectionHeader(title: 'Goals'),
                          const SizedBox(height: 10),
                          _CriteriaList(
                            title: 'Focus for this phase',
                            items: evaluation.goals,
                            icon: Icons.flag_outlined,
                            color: AppTheme.softBlue,
                          ),
                          const SizedBox(height: AppConstants.sectionGap),
                          SectionHeader(title: 'Progress Timeline'),
                          const SizedBox(height: 10),
                          _TimelineCard(assessment: assessment),
                          const SizedBox(height: AppConstants.sectionGap),
                          SectionHeader(title: 'Upcoming Milestones'),
                          const SizedBox(height: 10),
                          _MilestoneCard(
                            latestCheckInDate: latestMilestone?.createdAt,
                            quad: latestMilestone?.quadStrengthSymmetry,
                            hop: latestMilestone?.hopTestSymmetry,
                            balance: latestMilestone?.balanceSymmetry,
                          ),
                          const SizedBox(height: AppConstants.sectionGap),
                          SectionHeader(title: 'Quick Notes'),
                          const SizedBox(height: 10),
                          _NotesCard(
                            notes: assessment.notes,
                            graftType: assessment.graftType,
                          ),
                          const SizedBox(height: AppConstants.sectionGap),
                          SectionHeader(title: 'Safety Reminder'),
                          const SizedBox(height: 10),
                          _CriteriaList(
                            title: 'Progress only with a quiet knee',
                            items: const [
                              'Do not advance after swelling, instability, locking, or giving way.',
                              'Treat PT and surgeon restrictions as exercise unlock rules.',
                              'Use milestone check-ins every 2-4 weeks to reassess phase.',
                            ],
                            icon: Icons.health_and_safety_outlined,
                            color: AppTheme.softRed,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('Unable to load dashboard: $error')),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.week,
    required this.phase,
    required this.onStartSession,
  });

  final int week;
  final RehabPhase phase;
  final VoidCallback onStartSession;

  @override
  Widget build(BuildContext context) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ACL Recovery Coach',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          'Week $week - ${phase.label}',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final button = FilledButton.icon(
          onPressed: onStartSession,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start Session'),
        );

        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: button),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: title),
            const SizedBox(width: 12),
            button,
          ],
        );
      },
    );
  }
}

class _PhaseBadge extends StatelessWidget {
  const _PhaseBadge({required this.phase});

  final RehabPhase phase;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.timeline, size: 18),
      label: Text(phase.shortLabel),
      labelStyle: const TextStyle(fontWeight: FontWeight.w800),
    );
  }
}

class _CriteriaList extends StatelessWidget {
  const _CriteriaList({
    required this.title,
    required this.items,
    required this.icon,
    required this.color,
  });

  final String title;
  final List<String> items;
  final IconData icon;
  final Color color;

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
                Icon(icon, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('- '),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.assessment});

  final Assessment assessment;

  @override
  Widget build(BuildContext context) {
    final items = [
      MapEntry('Surgery', _formatDate(assessment.surgeryDate)),
      MapEntry('Current week', '${assessment.weeksPostOp} weeks'),
      MapEntry('Next reassessment', '2-4 weeks'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.cardPadding),
        child: Column(
          children: items
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 10,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(item.key)),
                      Text(
                        item.value,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({
    required this.latestCheckInDate,
    required this.quad,
    required this.hop,
    required this.balance,
  });

  final DateTime? latestCheckInDate;
  final int? quad;
  final int? hop;
  final int? balance;

  @override
  Widget build(BuildContext context) {
    final daysSince = latestCheckInDate == null
        ? null
        : DateTime.now().difference(latestCheckInDate!).inDays;
    final dueText = daysSince == null
        ? 'Milestone check-in due now'
        : daysSince >= 14
        ? 'Milestone check-in due'
        : 'Next check-in in ${14 - daysSince} days';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.fact_check_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    dueText,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _milestoneRow(context, 'Quad strength', quad),
            _milestoneRow(context, 'Hop symmetry', hop),
            _milestoneRow(context, 'Balance symmetry', balance),
          ],
        ),
      ),
    );
  }

  Widget _milestoneRow(BuildContext context, String label, int? value) {
    final display = value == null ? 'Not recorded' : '$value%';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(display, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.notes, required this.graftType});

  final String notes;
  final GraftType graftType;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              graftType.educationTitle,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(graftType.educationPoints.first),
            if (notes.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Clinical notes',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(notes.trim()),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.cardPadding),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
