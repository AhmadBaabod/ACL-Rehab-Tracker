import 'package:acl_rehab/domain/models/assessment.dart';
import 'package:flutter/material.dart';

class RehabPhaseTimeline extends StatelessWidget {
  const RehabPhaseTimeline({
    required this.phase,
    required this.progress,
    super.key,
  });

  final RehabPhase phase;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final phases = RehabPhase.values;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          tween: Tween(begin: 0, end: progress.clamp(0, 1)),
          builder: (context, value, child) {
            return LinearProgressIndicator(
              value: value,
              minHeight: 10,
              borderRadius: BorderRadius.circular(999),
              backgroundColor: scheme.surfaceContainerHighest,
            );
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: phases.map((item) {
            final active = item == phase;
            final complete = item.order < phase.order;
            final color = active || complete ? scheme.primary : scheme.outline;

            return Container(
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: active ? scheme.primaryContainer : scheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: color.withValues(alpha: active ? 1 : 0.45),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    complete
                        ? Icons.check_circle
                        : active
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 16,
                    color: active ? scheme.onPrimaryContainer : color,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item.shortLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      color: active
                          ? scheme.onPrimaryContainer
                          : scheme.onSurface,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
