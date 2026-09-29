import 'package:acl_rehab/core/theme/app_theme.dart';
import 'package:acl_rehab/data/exercise_catalog.dart';
import 'package:acl_rehab/domain/models/app_state.dart';
import 'package:acl_rehab/domain/models/exercise.dart';
import 'package:acl_rehab/domain/models/rehab_plan.dart';
import 'package:acl_rehab/domain/models/training_profile.dart';
import 'package:acl_rehab/domain/services/exercise_alternatives.dart';
import 'package:acl_rehab/core/utils/phase_logic.dart';
import 'package:acl_rehab/presentation/providers/app_state_provider.dart';
import 'package:acl_rehab/presentation/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The user's pick from the alternatives sheet.
class AlternativeChoice {
  const AlternativeChoice({required this.exercise, required this.permanent});

  final Exercise exercise;

  /// True to change the plan; false to swap for the current workout only.
  final bool permanent;
}

Color relationColor(AlternativeRelation relation) {
  switch (relation) {
    case AlternativeRelation.easier:
      return AppTheme.teal;
    case AlternativeRelation.similar:
      return AppTheme.softBlue;
    case AlternativeRelation.harder:
      return AppTheme.amber;
  }
}

IconData relationIcon(AlternativeRelation relation) {
  switch (relation) {
    case AlternativeRelation.easier:
      return Icons.south_east;
    case AlternativeRelation.similar:
      return Icons.swap_horiz;
    case AlternativeRelation.harder:
      return Icons.north_east;
  }
}

/// Shows same-goal alternatives for [exercise]. When [allowTemporary] is
/// true, each option can be used for today only or saved to the plan.
Future<AlternativeChoice?> showAlternativesSheet(
  BuildContext context, {
  required Exercise exercise,
  required AppState state,
  bool allowTemporary = false,
}) {
  final assessment = state.assessment!;
  final milestone = state.latestMilestone;
  final phase = evaluateRehabPhase(assessment, milestone: milestone).phase;
  final alternatives = AlternativeFinder.find(
    exercise,
    assessment: assessment,
    milestone: milestone,
    currentPhase: phase,
    limit: 8,
  );
  final planIds = state.activePlan?.exerciseIds ?? const <String>{};

  return showModalBottomSheet<AlternativeChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) {
      final available = alternatives.where((item) => item.isAvailable).toList();
      final unavailable = alternatives
          .where((item) => !item.isAvailable)
          .toList();
      final textTheme = Theme.of(context).textTheme;
      final scheme = Theme.of(context).colorScheme;

      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          maxWidth: 720,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(
              'Alternatives to ${exercise.name}',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Each option trains the same goal '
              '(${exercise.purpose.label.toLowerCase()}) and fits your current '
              'criteria and restrictions.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            if (available.isEmpty)
              const EmptyStateCard(
                icon: Icons.search_off,
                title: 'No other option fits right now',
                body:
                    'Every alternative is locked by your current criteria or needs '
                    'equipment you have not listed. Keep the current exercise or '
                    'update your equipment in Training setup.',
              ),
            for (final option in available)
              _AlternativeTile(
                option: option,
                inPlan: planIds.contains(option.exercise.id),
                allowTemporary: allowTemporary,
              ),
            if (unavailable.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Not available yet',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              for (final option in unavailable)
                _AlternativeTile(
                  option: option,
                  inPlan: false,
                  allowTemporary: false,
                ),
            ],
          ],
        ),
      );
    },
  );
}

class _AlternativeTile extends StatelessWidget {
  const _AlternativeTile({
    required this.option,
    required this.inPlan,
    required this.allowTemporary,
  });

  final ExerciseAlternative option;
  final bool inPlan;
  final bool allowTemporary;

  @override
  Widget build(BuildContext context) {
    final exercise = option.exercise;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final muted = !option.isAvailable;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Opacity(
          opacity: muted ? 0.72 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      exercise.name,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  StatusPill(
                    label: option.relation.label,
                    icon: relationIcon(option.relation),
                    color: relationColor(option.relation),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${exercise.sets} x ${exercise.reps} · ${exercise.equipment.join(', ')}',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              for (final reason in option.reasons)
                _Line(icon: Icons.check, text: reason, color: AppTheme.teal),
              for (final blocker in option.blockers)
                _Line(
                  icon: Icons.lock_outline,
                  text: blocker,
                  color: scheme.error,
                ),
              if (inPlan)
                const _Line(
                  icon: Icons.info_outline,
                  text: 'Already in your plan',
                  color: AppTheme.softBlue,
                ),
              if (option.isAvailable && !inPlan) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (allowTemporary)
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(
                          AlternativeChoice(
                            exercise: exercise,
                            permanent: false,
                          ),
                        ),
                        child: const Text('Use today'),
                      ),
                    FilledButton.tonal(
                      onPressed: () => Navigator.of(context).pop(
                        AlternativeChoice(exercise: exercise, permanent: true),
                      ),
                      child: Text(
                        allowTemporary ? 'Always use' : 'Use in my plan',
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

/// Full details for a plan exercise, with access to alternatives.
Future<void> showExerciseDetailSheet(
  BuildContext context,
  WidgetRef ref, {
  required PlanExercise item,
}) async {
  final exercise = ExerciseCatalog.byId(item.exerciseId);
  final state = ref.read(appControllerProvider).value;
  if (exercise == null || state == null) return;
  final dose = item.doseFor(state.exerciseProgressions[exercise.id]);

  final swap = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        maxWidth: 720,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          ExerciseDetailBody(exercise: exercise, item: item, dose: dose),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.swap_horiz),
            label: const Text('See alternatives'),
          ),
        ],
      ),
    ),
  );
  if (swap != true || !context.mounted) return;

  final choice = await showAlternativesSheet(
    context,
    exercise: exercise,
    state: state,
  );
  if (choice == null || !context.mounted) return;
  try {
    await ref
        .read(appControllerProvider.notifier)
        .swapPlanExercise(
          fromExerciseId: exercise.id,
          toExerciseId: choice.exercise.id,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${choice.exercise.name} replaces ${exercise.name} in your plan.',
        ),
      ),
    );
  } catch (_) {
    if (context.mounted) showSaveError(context);
  }
}

/// Exercise description, dose, reasoning, instructions, and safety.
class ExerciseDetailBody extends StatelessWidget {
  const ExerciseDetailBody({
    required this.exercise,
    this.item,
    this.dose,
    super.key,
  });

  final Exercise exercise;
  final PlanExercise? item;
  final Prescription? dose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final prescription = dose ?? item?.prescription;
    final substitutedFrom = item?.substitutedFromId == null
        ? null
        : ExerciseCatalog.byId(item!.substitutedFromId!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          exercise.purpose.label,
          style: textTheme.labelLarge?.copyWith(color: scheme.primary),
        ),
        const SizedBox(height: 4),
        Text(
          exercise.name,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(exercise.description, style: textTheme.bodyLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (prescription != null) ...[
              _Spec(icon: Icons.repeat, label: '${prescription.sets} sets'),
              _Spec(icon: Icons.format_list_numbered, label: prescription.reps),
              if (prescription.hold != 'None')
                _Spec(icon: Icons.timer_outlined, label: prescription.hold),
              if (prescription.restSeconds > 0)
                _Spec(
                  icon: Icons.hourglass_bottom,
                  label: '${prescription.restSeconds}s rest',
                ),
            ],
            _Spec(
              icon: Icons.signal_cellular_alt,
              label: exercise.difficultyLevel.label,
            ),
            _Spec(
              icon: Icons.home_repair_service_outlined,
              label: exercise.equipment.join(', '),
            ),
          ],
        ),
        if (prescription != null) ...[
          const SizedBox(height: 12),
          _Guidance(
            icon: Icons.speed,
            title: 'Effort',
            body: prescription.effort,
          ),
          _Guidance(
            icon: Icons.event_repeat,
            title: 'How often',
            body: prescription.frequency,
          ),
        ],
        if (item != null)
          _Guidance(
            icon: Icons.lightbulb_outline,
            title: 'Why it is in your plan',
            body: item!.reason,
          ),
        if (item?.substitutionReason != null)
          _Guidance(
            icon: Icons.swap_horiz,
            title: substitutedFrom == null
                ? 'Substitution'
                : 'Replaces ${substitutedFrom.name}',
            body: item!.substitutionReason!,
          ),
        const SizedBox(height: 8),
        Text(
          'Instructions',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < exercise.instructions.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    '${i + 1}',
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(exercise.instructions[i])),
              ],
            ),
          ),
        const SizedBox(height: 4),
        _Guidance(
          icon: Icons.south_east,
          title: 'Make it easier',
          body: exercise.regression,
        ),
        _Guidance(
          icon: Icons.north_east,
          title: 'Make it harder',
          body: exercise.progression,
        ),
        _Guidance(
          icon: Icons.medical_information_outlined,
          title: 'Clinical note',
          body: exercise.medicalNotes,
        ),
        for (final warning in exercise.safetyWarnings)
          _Guidance(
            icon: Icons.health_and_safety_outlined,
            title: 'Safety',
            body: warning,
            color: AppTheme.softRed,
          ),
      ],
    );
  }
}

class _Spec extends StatelessWidget {
  const _Spec({required this.icon, required this.label});

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

class _Guidance extends StatelessWidget {
  const _Guidance({
    required this.icon,
    required this.title,
    required this.body,
    this.color,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 10),
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

/// Short equipment summary for a profile, kept to one line.
String equipmentSummary(TrainingProfile profile) {
  final items = profile.equipment;
  if (items.isEmpty) return 'Household basics';
  if (items.length == EquipmentType.values.length) return 'Full equipment';
  final labels = [
    for (final type in EquipmentType.values)
      if (items.contains(type)) type.label,
  ];
  if (labels.length <= 2) return labels.join(', ');
  return '${labels.take(2).join(', ')} +${labels.length - 2} more';
}
