import 'package:acl_rehab/core/constants/app_constants.dart';
import 'package:acl_rehab/domain/models/training_profile.dart';
import 'package:acl_rehab/presentation/providers/app_state_provider.dart';
import 'package:acl_rehab/presentation/widgets/common.dart';
import 'package:acl_rehab/presentation/widgets/form_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Goal, schedule, and equipment questions that personalize the plan.
class TrainingSetupFields extends StatelessWidget {
  const TrainingSetupFields({
    required this.profile,
    required this.onChanged,
    this.sportController,
    super.key,
  });

  final TrainingProfile profile;
  final ValueChanged<TrainingProfile> onChanged;
  final TextEditingController? sportController;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        QuestionSection(
          title: 'Your goal',
          subtitle:
              'Late-stage drills are chosen for what you want to get back to.',
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: RadioGroup<RecoveryGoal>(
                  groupValue: profile.goal,
                  onChanged: (goal) {
                    if (goal == null) return;
                    HapticFeedback.selectionClick();
                    onChanged(profile.copyWith(goal: goal));
                  },
                  child: Column(
                    children: [
                      for (final goal in RecoveryGoal.values)
                        RadioListTile<RecoveryGoal>(
                          value: goal,
                          title: Text(
                            goal.label,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(goal.description),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (profile.goal == RecoveryGoal.returnToSport &&
                sportController != null)
              TextField(
                controller: sportController,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Sport (optional)',
                  hintText: 'For example soccer, basketball, skiing',
                ),
                onChanged: (value) => onChanged(profile.copyWith(sport: value)),
              ),
          ],
        ),
        QuestionSection(
          title: 'Your schedule',
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Training days per week',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          '${profile.sessionsPerWeek}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    Slider(
                      value: profile.sessionsPerWeek.toDouble(),
                      min: TrainingProfile.minSessionsPerWeek.toDouble(),
                      max: TrainingProfile.maxSessionsPerWeek.toDouble(),
                      divisions:
                          TrainingProfile.maxSessionsPerWeek -
                          TrainingProfile.minSessionsPerWeek,
                      label: '${profile.sessionsPerWeek} days',
                      semanticFormatterCallback: (value) =>
                          '${value.round()} training days per week',
                      onChanged: (value) => onChanged(
                        profile.copyWith(sessionsPerWeek: value.round()),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Minutes per session',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final minutes
                            in TrainingProfile.sessionLengthOptions)
                          ChoiceChip(
                            label: Text('$minutes min'),
                            selected: profile.minutesPerSession == minutes,
                            onSelected: (_) {
                              HapticFeedback.selectionClick();
                              onChanged(
                                profile.copyWith(minutesPerSession: minutes),
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        QuestionSection(
          title: 'Equipment you can use',
          subtitle:
              'A towel, chair, stairs, wall, and floor space are assumed. '
              'Exercises that need anything else are swapped for same-goal options.',
          children: [
            Card(
              child: Column(
                children: [
                  for (final item in EquipmentType.values)
                    CheckboxListTile.adaptive(
                      value: profile.has(item),
                      title: Text(
                        item.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        item.description,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      onChanged: (checked) {
                        HapticFeedback.selectionClick();
                        final next = {...profile.equipment};
                        checked == true ? next.add(item) : next.remove(item);
                        onChanged(profile.copyWith(equipment: next));
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Edits goals, schedule, and equipment, then rebuilds the plan.
Future<void> showTrainingSetupSheet(BuildContext context, WidgetRef ref) async {
  final assessment = ref.read(appControllerProvider).value?.assessment;
  if (assessment == null) return;
  final result = await showModalBottomSheet<TrainingProfile>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _TrainingSetupSheet(initial: assessment.profile),
  );
  if (result == null || !context.mounted) return;

  try {
    final update = await ref
        .read(appControllerProvider.notifier)
        .updateTrainingProfile(result);
    if (!context.mounted || update == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          update.isNewVersion
              ? 'Plan updated to version ${update.plan.version}: ${update.diff.summary}'
              : 'Setup saved. Your plan already fits it.',
        ),
      ),
    );
  } catch (error) {
    if (context.mounted) showSaveError(context);
  }
}

class _TrainingSetupSheet extends StatefulWidget {
  const _TrainingSetupSheet({required this.initial});

  final TrainingProfile initial;

  @override
  State<_TrainingSetupSheet> createState() => _TrainingSetupSheetState();
}

class _TrainingSetupSheetState extends State<_TrainingSetupSheet> {
  late TrainingProfile profile = widget.initial;
  late final sportController = TextEditingController(
    text: widget.initial.sport,
  );

  @override
  void dispose() {
    sportController.dispose();
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
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Text(
                'Training setup',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Changes rebuild your plan right away. Your progress and '
                'exercise levels are kept.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              TrainingSetupFields(
                profile: profile,
                sportController: sportController,
                onChanged: (next) => setState(() => profile = next),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(profile),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Save and update plan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
