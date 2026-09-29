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
import 'package:acl_rehab/domain/services/set_logging.dart';
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

/// Editable values for one set during a workout.
class _SetDraft {
  _SetDraft({required String value, required String weight})
    : value = TextEditingController(text: value),
      weight = TextEditingController(text: weight);

  /// Reps, seconds, or minutes, depending on the exercise.
  final TextEditingController value;
  final TextEditingController weight;
  bool done = false;

  void dispose() {
    value.dispose();
    weight.dispose();
  }
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  String? _sessionId;
  String? _planId;
  String? _workoutId;
  DateTime? _startedAt;
  int _index = 0;
  bool _saving = false;

  /// Doses are fixed for the whole workout so feedback changes the next one.
  final Map<String, Prescription> _doses = {};
  final Map<String, List<_SetDraft>> _drafts = {};
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
    for (final draft in _drafts.values.expand((drafts) => drafts)) {
      draft.dispose();
    }
    super.dispose();
  }

  /// Drops the set drafts for one slot, or all of them. Their text fields are
  /// still mounted until the next frame, so controllers are disposed after it.
  void _clearDrafts([String? slotId]) {
    final keys = slotId == null ? [..._drafts.keys] : [slotId];
    final retired = <_SetDraft>[];
    for (final key in keys) {
      retired.addAll(_drafts.remove(key) ?? const <_SetDraft>[]);
      _doses.remove(key);
    }
    if (slotId == null) _doses.clear();
    if (retired.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final draft in retired) {
        draft.dispose();
      }
    });
  }

  void _reset() {
    _restTimer?.cancel();
    _workoutId = null;
    _startedAt = null;
    _index = 0;
    _sessionId = null;
    _clearDrafts();
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
    final exercise = _activeExercise(slot);
    final dose = _dose(appState, slot);
    final measure = setMeasureFor(exercise, dose);
    final drafts = _draftsFor(appState, slot);
    final lastSets = appState.lastSetsFor(exercise.id);
    final plannedSets = {
      for (final item in items) item.exerciseId: _dose(appState, item).sets,
    };
    final setsDone = {
      for (final item in items) item.exerciseId: _doneCount(item.exerciseId),
    };
    final totalSets = plannedSets.values.fold<int>(0, (a, b) => a + b);
    final doneSets = setsDone.values.fold<int>(0, (a, b) => a + b);

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
            setsDone: setsDone,
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
            measure: measure,
            drafts: drafts,
            unit: appState.weightUnit,
            lastTime: summarizeSets(lastSets, appState.weightUnit),
            suggestion: measure.tracksWeight
                ? loadSuggestion(lastSets, dose, appState.weightUnit)
                : null,
            feedback: _feedback[slot.exerciseId],
            pain: _pain[slot.exerciseId],
            message: _messages[slot.exerciseId],
            restRemaining: _restRemaining,
            onCompleteSet: (setIndex) => _completeSet(appState, slot, setIndex),
            onStartRest: () => _startRest(dose.restSeconds),
            onPain: (band) => setState(() => _pain[slot.exerciseId] = band),
            onFeedback: (feedback) =>
                _recordFeedback(slot, exercise, feedback, dose),
            onSwap: () => _swap(appState, slot, exercise),
            onUndoSwap: () => setState(() {
              _todaySwaps.remove(slot.exerciseId);
              _clearDrafts(slot.exerciseId);
            }),
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
                  'Log reps and weight for each set, then tap Finish workout. '
                  'Your sessions build the progress charts and decide when '
                  'your plan progresses.',
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
                        '${log.painAfter}/10 · effort ${log.effort}/10'
                        '${log.volumeKg > 0 ? ' · ${appState.weightUnit.format(log.volumeKg)} lifted' : ''}',
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

  Exercise _activeExercise(PlanExercise slot) {
    return ExerciseCatalog.byId(
          _todaySwaps[slot.exerciseId] ?? slot.exerciseId,
        ) ??
        ExerciseCatalog.byId(slot.exerciseId)!;
  }

  Prescription _dose(AppState state, PlanExercise slot) {
    return _doses.putIfAbsent(
      slot.exerciseId,
      () => _doseFor(state, slot, _activeExercise(slot)),
    );
  }

  int _doneCount(String slotId) =>
      _drafts[slotId]?.where((draft) => draft.done).length ?? 0;

  /// Set rows, pre-filled from the last time this exercise was logged.
  List<_SetDraft> _draftsFor(AppState state, PlanExercise slot) {
    final existing = _drafts[slot.exerciseId];
    if (existing != null) return existing;
    final exercise = _activeExercise(slot);
    final dose = _dose(state, slot);
    final measure = setMeasureFor(exercise, dose);
    final last = state.lastSetsFor(exercise.id);
    final target = targetValue(measure, dose);
    final unit = state.weightUnit;

    SetLog? previous(int index) =>
        last.isEmpty ? null : last[index.clamp(0, last.length - 1)];

    String valueFor(int index) {
      final set = previous(index);
      final logged = switch (measure) {
        SetMeasure.repsAndWeight || SetMeasure.reps => set?.reps,
        SetMeasure.seconds => set?.seconds,
        SetMeasure.minutes => set?.seconds == null ? null : set!.seconds! ~/ 60,
      };
      return '${logged ?? target ?? ''}';
    }

    String weightFor(int index) {
      final kg = previous(index)?.weightKg ?? 0;
      if (!measure.tracksWeight || kg <= 0) return '';
      return unit.format(kg).split(' ').first;
    }

    return _drafts[slot.exerciseId] = [
      for (var i = 0; i < dose.sets; i++)
        _SetDraft(value: valueFor(i), weight: weightFor(i)),
    ];
  }

  void _completeSet(AppState state, PlanExercise slot, int index) {
    final drafts = _draftsFor(state, slot);
    final draft = drafts[index];
    if (draft.done) {
      setState(() => draft.done = false);
      return;
    }
    final dose = _dose(state, slot);
    final measure = setMeasureFor(_activeExercise(slot), dose);
    final value = int.tryParse(draft.value.text.trim());
    final max = measure == SetMeasure.seconds ? 3600 : 300;
    if (value == null || value <= 0 || value > max) {
      _showMessage(
        'Enter the ${measure.fieldLabel.toLowerCase()} for set ${index + 1}.',
      );
      return;
    }
    if (measure.tracksWeight && draft.weight.text.trim().isNotEmpty) {
      final weight = double.tryParse(
        draft.weight.text.trim().replaceAll(',', '.'),
      );
      if (weight == null || weight < 0 || weight > 1000) {
        _showMessage('Enter a valid weight for set ${index + 1}.');
        return;
      }
    }
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    setState(() {
      _ensureStarted();
      draft.done = true;
    });
    if (index < drafts.length - 1) _startRest(dose.restSeconds);
  }

  /// Completed sets for [slot], converted for storage.
  List<SetLog> _setLogs(AppState state, PlanExercise slot) {
    final drafts = _drafts[slot.exerciseId] ?? const <_SetDraft>[];
    final measure = setMeasureFor(_activeExercise(slot), _dose(state, slot));
    final unit = state.weightUnit;
    SetLog toLog(_SetDraft draft) {
      final value = int.tryParse(draft.value.text.trim()) ?? 0;
      final weight = double.tryParse(
        draft.weight.text.trim().replaceAll(',', '.'),
      );
      return switch (measure) {
        SetMeasure.repsAndWeight => SetLog(
          reps: value,
          weightKg: weight == null || weight <= 0 ? null : unit.toKg(weight),
        ),
        SetMeasure.reps => SetLog(reps: value),
        SetMeasure.seconds => SetLog(seconds: value),
        SetMeasure.minutes => SetLog(seconds: value * 60),
      };
    }

    return [
      for (final draft in drafts.where((draft) => draft.done)) toLog(draft),
    ];
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
        setsCompleted: _doneCount(slot.exerciseId),
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
      setState(() {
        _todaySwaps[slot.exerciseId] = choice.exercise.id;
        _clearDrafts(slot.exerciseId);
      });
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
    final setLogs = {
      for (final item in session.exercises)
        item.exerciseId: _setLogs(state, item),
    };
    final done = setLogs.values.fold<int>(0, (sum, sets) => sum + sets.length);
    final total = plannedSets.values.fold<int>(0, (a, b) => a + b);
    final volumeKg = setLogs.values
        .expand((sets) => sets)
        .fold<double>(0, (sum, set) => sum + set.volumeKg);
    final result = await showModalBottomSheet<_FinishResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _FinishSheet(
        setsDone: done,
        setsPlanned: total,
        volume: volumeKg > 0 ? state.weightUnit.format(volumeKg) : null,
      ),
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
              completedSets: setLogs[item.exerciseId]!.length,
              feedback: _feedback[item.exerciseId],
              substitutedFromId: swapped == null ? null : item.exerciseId,
              sets: setLogs[item.exerciseId]!,
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
  const _FinishSheet({
    required this.setsDone,
    required this.setsPlanned,
    this.volume,
  });

  final int setsDone;

  /// Total load lifted (reps x weight), when any weight was logged.
  final String? volume;
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
                    : '${widget.setsDone} of ${widget.setsPlanned} sets completed'
                          '${widget.volume == null ? '.' : ' · ${widget.volume} lifted.'}',
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
    required this.measure,
    required this.drafts,
    required this.unit,
    required this.lastTime,
    required this.suggestion,
    required this.feedback,
    required this.pain,
    required this.message,
    required this.restRemaining,
    required this.onCompleteSet,
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
  final SetMeasure measure;
  final List<_SetDraft> drafts;
  final WeightUnit unit;

  /// Summary of the last logged performance, such as "3 x 10 @ 20 kg".
  final String? lastTime;
  final String? suggestion;
  final ExerciseFeedback? feedback;
  final _PainBand? pain;
  final String? message;
  final int restRemaining;
  final ValueChanged<int> onCompleteSet;
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Log each set',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
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
            if (lastTime != null) ...[
              const SizedBox(height: 4),
              Text(
                'Last time: $lastTime',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (suggestion != null) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.trending_up, size: 16, color: AppTheme.teal),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(suggestion!, style: textTheme.bodySmall),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            for (var i = 0; i < drafts.length; i++)
              _SetRow(
                number: i + 1,
                draft: drafts[i],
                measure: measure,
                unit: unit,
                onComplete: () => onCompleteSet(i),
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

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.number,
    required this.draft,
    required this.measure,
    required this.unit,
    required this.onComplete,
  });

  final int number;
  final _SetDraft draft;
  final SetMeasure measure;
  final WeightUnit unit;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = draft.done;
    InputDecoration decoration(String label, {String? hint}) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              'Set $number',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: done ? scheme.primary : null,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: draft.value,
              enabled: !done,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: decoration(measure.fieldLabel),
            ),
          ),
          if (measure.tracksWeight) ...[
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: draft.weight,
                enabled: !done,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*[.,]?\d{0,2}'),
                  ),
                ],
                decoration: decoration(unit.label, hint: 'Bodyweight'),
                onSubmitted: (_) => onComplete(),
              ),
            ),
          ],
          const SizedBox(width: 8),
          done
              ? IconButton.filled(
                  tooltip: 'Undo set $number',
                  onPressed: onComplete,
                  icon: const Icon(Icons.check),
                )
              : IconButton.outlined(
                  tooltip: 'Complete set $number',
                  onPressed: onComplete,
                  icon: const Icon(Icons.check),
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
