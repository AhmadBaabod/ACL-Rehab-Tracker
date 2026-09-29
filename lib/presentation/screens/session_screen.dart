import 'dart:async';

import 'package:acl_rehab/core/constants/app_constants.dart';
import 'package:acl_rehab/core/navigation/app_router.dart';
import 'package:acl_rehab/core/navigation/app_tabs.dart';
import 'package:acl_rehab/core/theme/app_theme.dart';
import 'package:acl_rehab/core/utils/phase_logic.dart';
import 'package:acl_rehab/data/exercise_catalog.dart';
import 'package:acl_rehab/domain/models/app_state.dart';
import 'package:acl_rehab/domain/models/assessment.dart';
import 'package:acl_rehab/domain/models/exercise.dart';
import 'package:acl_rehab/domain/models/rehab_plan.dart';
import 'package:acl_rehab/domain/models/session_log.dart';
import 'package:acl_rehab/domain/models/workout_log.dart';
import 'package:acl_rehab/domain/services/plan_generator.dart';
import 'package:acl_rehab/domain/services/reassessment_advisor.dart';
import 'package:acl_rehab/presentation/providers/app_state_provider.dart';
import 'package:acl_rehab/presentation/widgets/common.dart';
import 'package:acl_rehab/presentation/widgets/exercise_sheets.dart';
import 'package:acl_rehab/presentation/widgets/exercise_visual.dart';
import 'package:acl_rehab/presentation/widgets/form_widgets.dart';
import 'package:acl_rehab/presentation/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({super.key});

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

/// Quick pain options after an exercise, mapped to a representative score.
enum _PainBand { low, moderate, high }

extension on _PainBand {
  String get label => switch (this) {
    _PainBand.low => '0-2',
    _PainBand.moderate => '3-4',
    _PainBand.high => '5+',
  };

  int get score => switch (this) {
    _PainBand.low => 1,
    _PainBand.moderate => 3,
    _PainBand.high => 6,
  };
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  String? _sessionId;
  String? _planId;
  String? _workoutId;
  DateTime? _startedAt;
  int _index = 0;
  bool _saving = false;
  final Map<String, int> _setsDone = {};
  final Map<String, ExerciseFeedback> _feedback = {};
  final Map<String, _PainBand> _pain = {};
  final Map<String, String> _todaySwaps = {};
  final Map<String, String> _messages = {};
  Timer? _restTimer;
  int _restRemaining = 0;

  bool get _started => _workoutId != null;

  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
  }

  void _reset() {
    _restTimer?.cancel();
    _workoutId = null;
    _startedAt = null;
    _index = 0;
    _sessionId = null;
    _setsDone.clear();
    _feedback.clear();
    _pain.clear();
    _todaySwaps.clear();
    _messages.clear();
    _restRemaining = 0;
  }

  void _ensureStarted() {
    if (_started) return;
    final now = DateTime.now();
    _workoutId = 'workout-${now.microsecondsSinceEpoch}';
    _startedAt = now;
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appControllerProvider).value;
    final plan = appState?.activePlan;
    final assessment = appState?.assessment;
    if (appState == null || assessment == null) {
      return const Scaffold(
        body: Center(
          child: Text('Complete your assessment to start sessions.'),
        ),
      );
    }
    if (plan == null || plan.sessions.isEmpty) {
      return Scaffold(
        body: _NoSession(
          evaluation: evaluateRehabPhase(
            assessment,
            milestone: appState.latestMilestone,
          ),
        ),
      );
    }

    // A new plan version starts a fresh workout.
    if (_planId != plan.id) {
      if (_planId != null) _reset();
      _planId = plan.id;
    }
    final session =
        plan.sessionById(_sessionId ?? '') ??
        appState.nextSession ??
        plan.sessions.first;
    final items = session.exercises;
    final index = _index.clamp(0, items.length - 1);
    final slot = items[index];
    final exercise =
        ExerciseCatalog.byId(_todaySwaps[slot.exerciseId] ?? slot.exerciseId) ??
        ExerciseCatalog.byId(slot.exerciseId)!;
    final dose = _doseFor(appState, slot, exercise);
    final plannedSets = {
      for (final item in items)
        item.exerciseId: _doseFor(
          appState,
          item,
          ExerciseCatalog.byId(
                _todaySwaps[item.exerciseId] ?? item.exerciseId,
              ) ??
              ExerciseCatalog.byId(item.exerciseId)!,
        ).sets,
    };
    final totalSets = plannedSets.values.fold<int>(0, (a, b) => a + b);
    final doneSets = items.fold<int>(
      0,
      (sum, item) =>
          sum +
          (_setsDone[item.exerciseId] ?? 0).clamp(
            0,
            plannedSets[item.exerciseId]!,
          ),
    );

    return Scaffold(
      body: ResponsivePage(
        maxWidth: 820,
        children: [
          PageHeader(
            title: 'Workout',
            subtitle:
                '${session.name} · ${session.focus} · about ${session.estimatedMinutes} min',
          ),
          if (plan.sessions.length > 1) ...[
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: [
                for (final option in plan.sessions)
                  ButtonSegment(
                    value: option.id,
                    label: Text(option.name),
                    icon: option.id == appState.nextSession?.id
                        ? const Icon(Icons.star_outline, size: 18)
                        : null,
                  ),
              ],
              selected: {session.id},
              onSelectionChanged: (selection) =>
                  _switchSession(selection.first, session.id),
            ),
          ],
          const SizedBox(height: 16),
          _ProgressStrip(
            items: items,
            current: index,
            setsDone: _setsDone,
            plannedSets: plannedSets,
            doneSets: doneSets,
            totalSets: totalSets,
            onSelect: (value) => setState(() => _index = value),
          ),
          const SizedBox(height: 16),
          ExerciseVisual(exercise: exercise, locked: false),
          const SizedBox(height: 12),
          _WorkoutExerciseCard(
            exercise: exercise,
            slot: slot,
            dose: dose,
            swappedToday: _todaySwaps.containsKey(slot.exerciseId),
            setsDone: _setsDone[slot.exerciseId] ?? 0,
            feedback: _feedback[slot.exerciseId],
            pain: _pain[slot.exerciseId],
            message: _messages[slot.exerciseId],
            restRemaining: _restRemaining,
            onToggleSet: (setNumber) => _toggleSet(slot, setNumber),
            onStartRest: () => _startRest(dose.restSeconds),
            onPain: (band) => setState(() => _pain[slot.exerciseId] = band),
            onFeedback: (feedback) =>
                _recordFeedback(slot, exercise, feedback, dose),
            onSwap: () => _swap(appState, slot, exercise),
            onUndoSwap: () =>
                setState(() => _todaySwaps.remove(slot.exerciseId)),
            onDetails: () => showExerciseDetailSheet(context, ref, item: slot),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: index == 0
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          setState(() => _index = index - 1);
                        },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Previous'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: index == items.length - 1
                    ? FilledButton.icon(
                        onPressed: _saving
                            ? null
                            : () =>
                                  _finish(appState, plan, session, plannedSets),
                        icon: const Icon(Icons.flag_outlined),
                        label: const Text('Finish workout'),
                      )
                    : FilledButton.icon(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() => _index = index + 1);
                        },
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Next exercise'),
                      ),
              ),
            ],
          ),
          if (index != items.length - 1 && _started) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _saving
                    ? null
                    : () => _finish(appState, plan, session, plannedSets),
                child: const Text('Finish workout early'),
              ),
            ),
          ],
          const SizedBox(height: AppConstants.sectionGap),
          const SectionHeader(title: 'Recent sessions'),
          const SizedBox(height: 10),
          if (appState.workoutLogs.isEmpty)
            const EmptyStateCard(
              icon: Icons.history,
              title: 'No sessions logged yet',
              body:
                  'Mark sets as you go and tap Finish workout. Your sessions build '
                  'the progress charts and decide when your plan progresses.',
            )
          else
            Card(
              child: Column(
                children: [
                  for (final log in appState.workoutLogs.reversed.take(4))
                    ListTile(
                      leading: const Icon(Icons.check_circle_outline),
                      title: Text(
                        log.sessionName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${log.completedSets}/${log.plannedSets} sets · pain '
                        '${log.painAfter}/10 · effort ${log.effort}/10',
                      ),
                      trailing: Text(formatDate(log.completedAt)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Prescription _doseFor(AppState state, PlanExercise slot, Exercise exercise) {
    if (exercise.id == slot.exerciseId) {
      return slot.doseFor(state.exerciseProgressions[exercise.id]);
    }
    // A today-only swap is dosed for the user like any plan exercise.
    final context = PlanContext.from(
      PlanGenerationInput(
        assessment: state.assessment!,
        milestone: state.latestMilestone,
        progressions: state.exerciseProgressions,
      ),
    );
    return context.prescribe(
      exercise,
      focus: context.focusFor(exercise.purpose),
    );
  }

  Future<void> _switchSession(String id, String currentId) async {
    if (id == currentId) return;
    if (_started) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Switch session?'),
          content: const Text('Sets marked in this workout will be cleared.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Switch'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }
    setState(() {
      _reset();
      _sessionId = id;
    });
  }

  void _toggleSet(PlanExercise slot, int setNumber) {
    HapticFeedback.selectionClick();
    setState(() {
      _ensureStarted();
      final done = _setsDone[slot.exerciseId] ?? 0;
      _setsDone[slot.exerciseId] = done >= setNumber
          ? setNumber - 1
          : setNumber;
    });
  }

  void _startRest(int seconds) {
    if (seconds <= 0) return;
    _restTimer?.cancel();
    setState(() => _restRemaining = seconds);
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _restRemaining--);
      if (_restRemaining <= 0) {
        timer.cancel();
        HapticFeedback.heavyImpact();
      }
    });
  }

  Future<void> _recordFeedback(
    PlanExercise slot,
    Exercise exercise,
    ExerciseFeedback feedback,
    Prescription dose,
  ) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _ensureStarted();
      _feedback[slot.exerciseId] = feedback;
    });
    final controller = ref.read(appControllerProvider.notifier);
    final previous = ref
        .read(appControllerProvider)
        .value
        ?.exerciseProgressions[exercise.id];
    try {
      final next = await controller.addSessionFeedback(
        exerciseId: exercise.id,
        exerciseName: exercise.name,
        feedback: feedback,
        painAfter: _pain[slot.exerciseId]?.score,
        workoutId: _workoutId,
        setsCompleted: _setsDone[slot.exerciseId] ?? 0,
        setsPlanned: dose.sets,
      );
      if (!mounted) return;
      final nextSets = exercise.id == slot.exerciseId
          ? slot.doseFor(next).sets
          : dose.sets;
      setState(() {
        _messages[slot.exerciseId] = _feedbackMessage(
          exercise,
          next,
          previousLevel: previous?.level ?? 0,
          nextSets: nextSets,
          continuous: dose.sets <= 1,
        );
      });
    } catch (_) {
      if (mounted) showSaveError(context);
    }
  }

  String _feedbackMessage(
    Exercise exercise,
    ExerciseProgressionState next, {
    required int previousLevel,
    required int nextSets,
    required bool continuous,
  }) {
    final dose = continuous ? '' : ' Next time: $nextSets sets.';
    switch (next.recommendation) {
      case ProgressionRecommendation.progress:
        if (next.atCeiling && previousLevel == next.level) {
          return 'Top level reached. Your next plan update will move you to a harder variation.';
        }
        return 'Progressing.$dose Then: ${exercise.progression}';
      case ProgressionRecommendation.regress:
        return 'Stepping back.$dose Try: ${exercise.regression}';
      case ProgressionRecommendation.maintain:
        if (next.consecutiveGood == 1) {
          return 'Holding this dose. One more "Just right" session with low pain and it progresses.';
        }
        return 'Holding this dose while pain settles.';
    }
  }

  Future<void> _swap(
    AppState state,
    PlanExercise slot,
    Exercise current,
  ) async {
    final original = ExerciseCatalog.byId(slot.exerciseId)!;
    final choice = await showAlternativesSheet(
      context,
      exercise: original,
      state: state,
      allowTemporary: true,
    );
    if (choice == null || !mounted) return;
    if (!choice.permanent) {
      setState(() => _todaySwaps[slot.exerciseId] = choice.exercise.id);
      return;
    }
    try {
      await ref
          .read(appControllerProvider.notifier)
          .swapPlanExercise(
            fromExerciseId: slot.exerciseId,
            toExerciseId: choice.exercise.id,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${choice.exercise.name} is now in your plan.')),
      );
    } catch (_) {
      if (mounted) showSaveError(context);
    }
  }

  Future<void> _finish(
    AppState state,
    RehabPlan plan,
    PlanSession session,
    Map<String, int> plannedSets,
  ) async {
    final done = _setsDone.values.fold<int>(0, (a, b) => a + b);
    final total = plannedSets.values.fold<int>(0, (a, b) => a + b);
    final result = await showModalBottomSheet<_FinishResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _FinishSheet(setsDone: done, setsPlanned: total),
    );
    if (result == null || !mounted) return;

    _ensureStarted();
    final log = WorkoutLog(
      id: _workoutId!,
      planId: plan.id,
      planVersion: plan.version,
      sessionId: session.id,
      sessionName: session.name,
      startedAt: _startedAt!,
      completedAt: DateTime.now(),
      entries: [
        for (final item in session.exercises)
          () {
            final swapped = _todaySwaps[item.exerciseId];
            final exercise = ExerciseCatalog.byId(swapped ?? item.exerciseId);
            return WorkoutExerciseEntry(
              exerciseId: swapped ?? item.exerciseId,
              exerciseName: exercise?.name ?? item.exerciseId,
              plannedSets:
                  plannedSets[item.exerciseId] ?? item.prescription.sets,
              completedSets: (_setsDone[item.exerciseId] ?? 0).clamp(
                0,
                plannedSets[item.exerciseId] ?? item.prescription.sets,
              ),
              feedback: _feedback[item.exerciseId],
              substitutedFromId: swapped == null ? null : item.exerciseId,
            );
          }(),
      ],
      painAfter: result.pain,
      effort: result.effort,
      notes: result.notes,
    );

    setState(() => _saving = true);
    try {
      await ref.read(appControllerProvider.notifier).completeWorkout(log);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        showSaveError(context);
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _reset();
    });
    final updated = ref.read(appControllerProvider).value;
    if (updated == null) return;
    await _showCompletion(updated, log);
  }

  Future<void> _showCompletion(AppState state, WorkoutLog log) async {
    final recommendation = ReassessmentAdvisor.evaluate(state);
    final next = state.nextSession;
    final target = state.activePlan?.sessionsPerWeek ?? 3;
    final thisWeek = state.workoutsThisWeek(DateTime.now());
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.emoji_events_outlined, color: AppTheme.teal),
        title: const Text('Workout saved'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${log.completedSets} of ${log.plannedSets} sets · pain '
              '${log.painAfter}/10 · effort ${log.effort}/10',
            ),
            const SizedBox(height: 8),
            Text('$thisWeek of $target sessions done this week.'),
            if (next != null) Text('Next up: ${next.name}.'),
            if (log.painAfter >= 5) ...[
              const SizedBox(height: 8),
              const Text(
                'Pain was high after this session. Rest, ice, and elevate; the '
                'next session will be dosed down if it stays high.',
              ),
            ],
            if (recommendation.isDue) ...[
              const SizedBox(height: 12),
              Text(
                recommendation.title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(recommendation.message),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('progress'),
            child: const Text('View progress'),
          ),
          if (recommendation.isDue)
            FilledButton(
              onPressed: () => Navigator.of(context).pop('reassess'),
              child: const Text('Reassess now'),
            )
          else
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'progress') {
      await ref.read(appControllerProvider.notifier).selectTab(AppTab.progress);
    } else if (action == 'reassess') {
      if (mounted) context.push(AppRoutes.reassess);
    }
  }
}

class _FinishResult {
  const _FinishResult({
    required this.pain,
    required this.effort,
    required this.notes,
  });

  final int pain;
  final int effort;
  final String notes;
}

class _FinishSheet extends StatefulWidget {
  const _FinishSheet({required this.setsDone, required this.setsPlanned});

  final int setsDone;
  final int setsPlanned;

  @override
  State<_FinishSheet> createState() => _FinishSheetState();
}

class _FinishSheetState extends State<_FinishSheet> {
  int pain = 2;
  int effort = 5;
  final notes = TextEditingController();

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Text(
                'Finish workout',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.setsDone == 0
                    ? 'No sets are marked done. You can still log how the knee feels.'
                    : '${widget.setsDone} of ${widget.setsPlanned} sets completed.',
              ),
              const SizedBox(height: 12),
              ScaleSliderCard(
                title: 'Knee pain now',
                value: pain,
                lowLabel: '0 = none',
                highLabel: '10 = worst',
                onChanged: (value) => setState(() => pain = value),
              ),
              const SizedBox(height: 10),
              ScaleSliderCard(
                title: 'How hard was the session?',
                subtitle: 'Overall effort (RPE).',
                value: effort,
                lowLabel: '1 = very easy',
                highLabel: '10 = maximal',
                onChanged: (value) =>
                    setState(() => effort = value.clamp(1, 10)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notes,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Anything your PT should know',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(
                  _FinishResult(
                    pain: pain,
                    effort: effort.clamp(1, 10),
                    notes: notes.text.trim(),
                  ),
                ),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Save workout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressStrip extends StatelessWidget {
  const _ProgressStrip({
    required this.items,
    required this.current,
    required this.setsDone,
    required this.plannedSets,
    required this.doneSets,
    required this.totalSets,
    required this.onSelect,
  });

  final List<PlanExercise> items;
  final int current;
  final Map<String, int> setsDone;
  final Map<String, int> plannedSets;
  final int doneSets;
  final int totalSets;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Exercise ${current + 1} of ${items.length}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text('$doneSets / $totalSets sets'),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: totalSets == 0 ? 0 : doneSets / totalSets,
              minHeight: 8,
              borderRadius: BorderRadius.circular(999),
              semanticsLabel: 'Workout progress: $doneSets of $totalSets sets',
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: () {
                        final id = items[i].exerciseId;
                        final complete =
                            (setsDone[id] ?? 0) >= (plannedSets[id] ?? 1);
                        return ChoiceChip(
                          selected: i == current,
                          avatar: complete
                              ? Icon(
                                  Icons.check_circle,
                                  size: 18,
                                  color: scheme.primary,
                                )
                              : null,
                          label: Text(
                            ExerciseCatalog.byId(id)?.name ?? id,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onSelected: (_) => onSelect(i),
                        );
                      }(),
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

class _WorkoutExerciseCard extends StatelessWidget {
  const _WorkoutExerciseCard({
    required this.exercise,
    required this.slot,
    required this.dose,
    required this.swappedToday,
    required this.setsDone,
    required this.feedback,
    required this.pain,
    required this.message,
    required this.restRemaining,
    required this.onToggleSet,
    required this.onStartRest,
    required this.onPain,
    required this.onFeedback,
    required this.onSwap,
    required this.onUndoSwap,
    required this.onDetails,
  });

  final Exercise exercise;
  final PlanExercise slot;
  final Prescription dose;
  final bool swappedToday;
  final int setsDone;
  final ExerciseFeedback? feedback;
  final _PainBand? pain;
  final String? message;
  final int restRemaining;
  final ValueChanged<int> onToggleSet;
  final VoidCallback onStartRest;
  final ValueChanged<_PainBand> onPain;
  final ValueChanged<ExerciseFeedback> onFeedback;
  final VoidCallback onSwap;
  final VoidCallback onUndoSwap;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
                  child: Text(
                    exercise.name,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Exercise details',
                  onPressed: onDetails,
                  icon: const Icon(Icons.info_outline),
                ),
              ],
            ),
            Text(exercise.description, style: textTheme.bodyLarge),
            if (swappedToday) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.swap_horiz, size: 16, color: scheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Swapped in for today. Your plan is unchanged.',
                      style: textTheme.bodySmall,
                    ),
                  ),
                  TextButton(onPressed: onUndoSwap, child: const Text('Undo')),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 16,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(slot.reason, style: textTheme.bodySmall),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(
                  Icons.repeat,
                  '${dose.sets} ${dose.sets == 1 ? 'set' : 'sets'}',
                ),
                _chip(Icons.format_list_numbered, dose.reps),
                if (dose.hold != 'None') _chip(Icons.timer_outlined, dose.hold),
              ],
            ),
            const SizedBox(height: 8),
            _cue(context, Icons.speed, 'Effort', dose.effort),
            const SizedBox(height: 16),
            Text(
              'Sets',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var i = 1; i <= dose.sets; i++)
                  FilterChip(
                    label: Text('Set $i'),
                    selected: setsDone >= i,
                    onSelected: (_) => onToggleSet(i),
                  ),
                if (dose.restSeconds > 0)
                  ActionChip(
                    avatar: const Icon(Icons.hourglass_bottom, size: 18),
                    label: Text(
                      restRemaining > 0
                          ? 'Rest ${restRemaining ~/ 60}:${(restRemaining % 60).toString().padLeft(2, '0')}'
                          : 'Rest ${dose.restSeconds}s',
                    ),
                    onPressed: onStartRest,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Instructions',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            for (final step in exercise.instructions)
              Padding(
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
                    Expanded(child: Text(step)),
                  ],
                ),
              ),
            if (dose.level >= 2 && !dose.paused)
              _cue(
                context,
                Icons.north_east,
                'Ready to progress',
                exercise.progression,
              ),
            if (dose.level <= -1)
              _cue(
                context,
                Icons.south_east,
                'Easier option',
                exercise.regression,
              ),
            _cue(
              context,
              Icons.health_and_safety_outlined,
              'Safety',
              exercise.safetyWarnings.join(' '),
              color: AppTheme.softRed,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onSwap,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Swap exercise'),
            ),
            const Divider(height: 32),
            Text(
              'How did it feel?',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Knee pain', style: textTheme.bodyMedium),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final band in _PainBand.values)
                        ChoiceChip(
                          label: Text(band.label),
                          selected: pain == band,
                          onSelected: (_) => onPain(band),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _feedbackButton(ExerciseFeedback.tooHard, Icons.trending_down),
                _feedbackButton(
                  ExerciseFeedback.justRight,
                  Icons.check_circle_outline,
                ),
                _feedbackButton(ExerciseFeedback.tooEasy, Icons.trending_up),
              ],
            ),
            if (message != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    message!,
                    style: TextStyle(color: scheme.onSecondaryContainer),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Chip(avatar: Icon(icon, size: 18), label: Text(label));
  }

  Widget _feedbackButton(ExerciseFeedback value, IconData icon) {
    final selected = feedback == value;
    return selected
        ? FilledButton.icon(
            onPressed: () => onFeedback(value),
            icon: Icon(icon),
            label: Text(value.label),
          )
        : OutlinedButton.icon(
            onPressed: () => onFeedback(value),
            icon: Icon(icon),
            label: Text(value.label),
          );
  }

  Widget _cue(
    BuildContext context,
    IconData icon,
    String title,
    String body, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: color ?? Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: body),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoSession extends ConsumerWidget {
  const _NoSession({required this.evaluation});

  final PhaseEvaluation evaluation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ResponsivePage(
      maxWidth: 620,
      children: [
        Icon(
          Icons.fact_check_outlined,
          size: 44,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'No exercises unlocked yet',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          '${evaluation.phase.shortLabel} uses readiness criteria before it '
          'unlocks loading, running, or impact work.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        if (evaluation.safetyFlags.isNotEmpty) ...[
          InfoListCard(
            title: 'Please contact your clinical team',
            items: evaluation.safetyFlags,
            icon: Icons.medical_information_outlined,
            color: AppTheme.softRed,
          ),
          const SizedBox(height: 12),
        ],
        if (evaluation.blockers.isNotEmpty)
          InfoListCard(
            title: 'Criteria to review',
            items: evaluation.blockers,
            icon: Icons.info_outline,
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => context.push(AppRoutes.reassess),
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Update my assessment'),
          ),
        ),
      ],
    );
  }
}
