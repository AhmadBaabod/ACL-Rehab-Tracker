import 'package:acl_rehab/domain/models/exercise.dart';
import 'package:flutter/material.dart';

class ExerciseVisual extends StatelessWidget {
  const ExerciseVisual({
    required this.exercise,
    required this.locked,
    super.key,
  });

  final Exercise exercise;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = switch (exercise.category) {
      ExerciseCategory.mobility => Icons.accessibility_new,
      ExerciseCategory.strength => Icons.fitness_center,
      ExerciseCategory.balanceProprioception => Icons.self_improvement,
      ExerciseCategory.neuromuscularControl => Icons.psychology_alt_outlined,
      ExerciseCategory.changeOfDirection => Icons.alt_route,
      ExerciseCategory.returnToSport => Icons.sports_soccer,
    };
    final foreground = locked
        ? scheme.onSurfaceVariant
        : scheme.onPrimaryContainer;

    return ExcludeSemantics(
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 120),
        decoration: BoxDecoration(
          color: locked
              ? scheme.surfaceContainerHighest
              : scheme.primaryContainer.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Stack(
          children: [
            Positioned(
              right: 16,
              top: 12,
              child: Icon(
                locked ? Icons.lock_outline : icon,
                size: 88,
                color: foreground.withValues(alpha: 0.14),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    locked ? Icons.lock_outline : icon,
                    size: 32,
                    color: foreground,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    exercise.purpose.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: foreground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Works ${exercise.targetMuscles.join(', ').toLowerCase()}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: foreground.withValues(alpha: 0.82),
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
