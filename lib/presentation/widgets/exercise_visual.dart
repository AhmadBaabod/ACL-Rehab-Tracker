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

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 180),
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
            right: 20,
            top: 18,
            child: Icon(
              locked ? Icons.lock_outline : icon,
              size: 96,
              color:
                  (locked ? scheme.onSurfaceVariant : scheme.onPrimaryContainer)
                      .withValues(alpha: 0.16),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  locked ? Icons.lock_outline : icon,
                  size: 36,
                  color: locked
                      ? scheme.onSurfaceVariant
                      : scheme.onPrimaryContainer,
                ),
                const SizedBox(height: 18),
                Text(
                  exercise.imagePlaceholder,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: locked
                        ? scheme.onSurfaceVariant
                        : scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  exercise.videoPlaceholder,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: locked
                        ? scheme.onSurfaceVariant
                        : scheme.onPrimaryContainer.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
