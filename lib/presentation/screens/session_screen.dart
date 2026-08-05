import 'package:acl_rehab/core/constants/app_constants.dart';
import 'package:acl_rehab/core/theme/app_theme.dart';
import 'package:acl_rehab/core/utils/phase_logic.dart';
import 'package:acl_rehab/data/exercise_catalog.dart';
import 'package:acl_rehab/domain/models/assessment.dart';
import 'package:acl_rehab/domain/models/exercise.dart';
import 'package:acl_rehab/domain/models/session_log.dart';
import 'package:acl_rehab/presentation/providers/app_state_provider.dart';
import 'package:acl_rehab/presentation/widgets/clinical_disclaimer_banner.dart';
import 'package:acl_rehab/presentation/widgets/exercise_visual.dart';
import 'package:acl_rehab/presentation/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({super.key});

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  int currentIndex = 0;
  final Map<String, String> _selectedAlternatives = {};

  @override
  Widget build(BuildContext context) {
    final appStateAsync = ref.watch(appControllerProvider);

    return appStateAsync.when(
      data: (appState) {
        final assessment = appState.assessment;
        if (assessment == null) {
          return const Scaffold(
            body: Center(
              child: Text('Complete onboarding before starting sessions.'),
            ),
          );
        }

        final milestone = appState.latestMilestone;
        final evaluation = evaluateRehabPhase(assessment, milestone: milestone);
        final exercises = ExerciseCatalog.sessionFor(
          assessment,
          milestone: milestone,
          phase: evaluation.phase,
        );
        if (exercises.isEmpty) {
          return Scaffold(
            body: _NoPhaseAlignedSession(
              evaluation: evaluation,
              onOpenProgress: () => ref
                  .read(appControllerProvider.notifier)
                  .updateSelectedIndex(2),
            ),
          );
        }

        final safeIndex = currentIndex.clamp(0, exercises.length - 1);
        final slotExercise = exercises[safeIndex];
        final selectedAlternative = ExerciseCatalog.byId(
          _selectedAlternatives[slotExercise.id] ?? '',
        );
        final alternatives = [
          slotExercise,
          ...ExerciseCatalog.alternativesFor(
            slotExercise,
            assessment,
            milestone: milestone,
          ),
        ];
        final exercise = alternatives.contains(selectedAlternative)
            ? selectedAlternative!
            : slotExercise;
        final unlock = exercise.unlockStatus(assessment, milestone);
        final latestLog = appState.latestLogFor(exercise.id);
        final progression = appState.exerciseProgressions[exercise.id];

        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.horizontalPadding),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
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
                                  'Session',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${safeIndex + 1} of ${exercises.length} - ${exercise.phase.label}',
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const Chip(
                            avatar: Icon(Icons.auto_awesome_outlined, size: 18),
                            label: Text('Phase-aligned'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const ClinicalDisclaimerBanner(),
                      const SizedBox(height: AppConstants.sectionGap),
                      ExerciseVisual(
                        exercise: exercise,
                        locked: !unlock.isUnlocked,
                      ),
                      const SizedBox(height: 14),
                      _ExerciseCard(
                        exercise: exercise,
                        unlock: unlock,
                        latestLog: latestLog,
                        progression: progression,
                        alternatives: alternatives,
                        onSelectAlternative: (alternative) =>
                            _chooseAlternative(slotExercise, alternative),
                        onFeedback: (feedback) =>
                            _recordFeedback(exercise, feedback),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: safeIndex == 0
                                  ? null
                                  : () {
                                      HapticFeedback.selectionClick();
                                      setState(
                                        () => currentIndex = safeIndex - 1,
                                      );
                                    },
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Previous'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: safeIndex == exercises.length - 1
                                  ? null
                                  : () {
                                      HapticFeedback.selectionClick();
                                      setState(
                                        () => currentIndex = safeIndex + 1,
                                      );
                                    },
                              icon: const Icon(Icons.arrow_forward),
                              label: const Text('Next'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppConstants.sectionGap),
                      SectionHeader(title: 'Recent Feedback'),
                      const SizedBox(height: 10),
                      if (appState.sessionLogs.isEmpty)
                        const _EmptyFeedback()
                      else
                        ...appState.sessionLogs.reversed
                            .take(5)
                            .map(
                              (log) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Card(
                                  child: ListTile(
                                    leading: const Icon(Icons.history),
                                    title: Text(
                                      log.exerciseName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${log.feedback.label} - ${log.recommendation.label}',
                                    ),
                                    trailing: Text(_shortDate(log.createdAt)),
                                  ),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) =>
          Scaffold(body: Center(child: Text('Unable to load session: $error'))),
    );
  }

  Future<void> _recordFeedback(
    Exercise exercise,
    ExerciseFeedback feedback,
  ) async {
    HapticFeedback.mediumImpact();
    await ref
        .read(appControllerProvider.notifier)
        .addSessionFeedback(
          exerciseId: exercise.id,
          exerciseName: exercise.name,
          feedback: feedback,
        );
  }

  void _chooseAlternative(Exercise slotExercise, Exercise alternative) {
    HapticFeedback.selectionClick();
    setState(() {
      if (alternative.id == slotExercise.id) {
        _selectedAlternatives.remove(slotExercise.id);
      } else {
        _selectedAlternatives[slotExercise.id] = alternative.id;
      }
    });
  }

  String _shortDate(DateTime date) => '${date.month}/${date.day}';
}

class _NoPhaseAlignedSession extends StatelessWidget {
  const _NoPhaseAlignedSession({
    required this.evaluation,
    required this.onOpenProgress,
  });

  final PhaseEvaluation evaluation;
  final VoidCallback onOpenProgress;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.horizontalPadding),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.fact_check_outlined,
                  size: 44,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No phase-aligned session yet',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${evaluation.phase.shortLabel} uses measured readiness criteria before it unlocks loading, running, or impact work.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                const ClinicalDisclaimerBanner(),
                const SizedBox(height: 18),
                if (evaluation.blockers.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current criteria to review',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 10),
                          ...evaluation.blockers.map(
                            (blocker) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(blocker)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onOpenProgress,
                    icon: const Icon(Icons.monitor_heart_outlined),
                    label: const Text('Update milestone check-in'),
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

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.unlock,
    required this.latestLog,
    required this.progression,
    required this.alternatives,
    required this.onSelectAlternative,
    required this.onFeedback,
  });

  final Exercise exercise;
  final ExerciseUnlockStatus unlock;
  final SessionLog? latestLog;
  final ExerciseProgressionState? progression;
  final List<Exercise> alternatives;
  final ValueChanged<Exercise> onSelectAlternative;
  final ValueChanged<ExerciseFeedback> onFeedback;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.category.label,
                        style: Theme.of(
                          context,
                        ).textTheme.labelLarge?.copyWith(color: scheme.primary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        exercise.name,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Chip(label: Text(exercise.difficultyLevel.label)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              exercise.description,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SpecChip(icon: Icons.repeat, label: '${exercise.sets} sets'),
                _SpecChip(
                  icon: Icons.format_list_numbered,
                  label: exercise.reps,
                ),
                _SpecChip(icon: Icons.timer_outlined, label: exercise.holdTime),
                _SpecChip(
                  icon: Icons.home_repair_service_outlined,
                  label: exercise.equipment.join(', '),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Instructions',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...exercise.instructions.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (alternatives.length > 1) ...[
              _AlternativeExercisePicker(
                currentExercise: exercise,
                alternatives: alternatives,
                onSelected: onSelectAlternative,
              ),
              const SizedBox(height: 12),
            ],
            _GuidanceBlock(
              title: 'Adaptive Progression',
              rows: [
                MapEntry('Regression', exercise.regression),
                MapEntry('Progression', exercise.progression),
                if (progression != null)
                  MapEntry('Next session', progression!.recommendation.label),
                if (latestLog != null)
                  MapEntry('Last response', latestLog!.feedback.label),
              ],
            ),
            const SizedBox(height: 12),
            _GuidanceBlock(
              title: 'Medical Notes',
              rows: [
                MapEntry('Note', exercise.medicalNotes),
                ...exercise.safetyWarnings.map(
                  (warning) => MapEntry('Safety', warning),
                ),
              ],
              accent: AppTheme.softRed,
            ),
            const SizedBox(height: 18),
            if (!unlock.isUnlocked)
              _LockedReasons(reasons: unlock.reasons)
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How did that feel?',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => onFeedback(ExerciseFeedback.tooHard),
                        icon: const Icon(Icons.trending_down),
                        label: const Text('Too Hard'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => onFeedback(ExerciseFeedback.justRight),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Just Right'),
                      ),
                      FilledButton.icon(
                        onPressed: () => onFeedback(ExerciseFeedback.tooEasy),
                        icon: const Icon(Icons.trending_up),
                        label: const Text('Too Easy'),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _AlternativeExercisePicker extends StatelessWidget {
  const _AlternativeExercisePicker({
    required this.currentExercise,
    required this.alternatives,
    required this.onSelected,
  });

  final Exercise currentExercise;
  final List<Exercise> alternatives;
  final ValueChanged<Exercise> onSelected;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _showOptions(context),
      icon: const Icon(Icons.swap_horiz),
      label: const Text('Choose alternative exercise'),
    );
  }

  Future<void> _showOptions(BuildContext context) async {
    final choice = await showModalBottomSheet<Exercise>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 520),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            children: [
              Text(
                'Alternative exercise',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                currentExercise.sessionBlock.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              ...alternatives.map(
                (exercise) => Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    onTap: () => Navigator.of(context).pop(exercise),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    leading: Icon(
                      exercise.id == currentExercise.id
                          ? Icons.check_circle
                          : Icons.swap_horiz,
                      color: exercise.id == currentExercise.id
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    title: Text(
                      exercise.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${exercise.sets} sets - ${exercise.reps}\n${exercise.equipment.join(', ')}',
                    ),
                    isThreeLine: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (choice != null) onSelected(choice);
  }
}

class _SpecChip extends StatelessWidget {
  const _SpecChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text(label));
  }
}

class _GuidanceBlock extends StatelessWidget {
  const _GuidanceBlock({required this.title, required this.rows, this.accent});

  final String title;
  final List<MapEntry<String, String>> rows;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodyMedium,
                  children: [
                    TextSpan(
                      text: '${row.key}: ',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    TextSpan(text: row.value),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedReasons extends StatelessWidget {
  const _LockedReasons({required this.reasons});

  final List<String> reasons;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.errorContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lock_outline,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Why this is locked',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...reasons.map(
            (reason) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '- ',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      reason,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
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

class _EmptyFeedback extends StatelessWidget {
  const _EmptyFeedback();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.cardPadding),
        child: Row(
          children: [
            Icon(
              Icons.feedback_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Feedback will appear here after you complete exercises.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
