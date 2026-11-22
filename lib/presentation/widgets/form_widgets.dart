import 'package:acl_rehab/core/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

TextStyle? _titleStyle(BuildContext context) => Theme.of(
  context,
).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800);

TextStyle? _hintStyle(BuildContext context) => Theme.of(context)
    .textTheme
    .bodySmall
    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

/// A labeled group of questions inside an assessment step.
class QuestionSection extends StatelessWidget {
  const QuestionSection({
    required this.title,
    required this.children,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 0.2,
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: _hintStyle(context)),
          ],
          const SizedBox(height: 10),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: children[i]),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class YesNoCard extends StatelessWidget {
  const YesNoCard({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SwitchListTile.adaptive(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.cardPadding,
          vertical: 4,
        ),
        title: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: subtitle == null ? null : Text(subtitle!),
        value: value,
        onChanged: (next) {
          HapticFeedback.selectionClick();
          onChanged(next);
        },
      ),
    );
  }
}

class ChoiceCard<T> extends StatelessWidget {
  const ChoiceCard({
    required this.title,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
    this.subtitle,
    this.helpOf,
    super.key,
  });

  final String title;
  final String? subtitle;
  final T value;
  final List<T> options;
  final String Function(T option) labelOf;

  /// Optional explanation of the selected option, shown under the chips.
  final String Function(T option)? helpOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final help = helpOf?.call(value);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: _titleStyle(context)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: _hintStyle(context)),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in options)
                  ChoiceChip(
                    label: Text(labelOf(option)),
                    selected: value == option,
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      onChanged(option);
                    },
                  ),
              ],
            ),
            if (help != null && help.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(help, style: _hintStyle(context)),
            ],
          ],
        ),
      ),
    );
  }
}

/// A 0-N rating with anchor labels at each end.
class ScaleSliderCard extends StatelessWidget {
  const ScaleSliderCard({
    required this.title,
    required this.value,
    required this.onChanged,
    this.max = 10,
    this.subtitle,
    this.lowLabel,
    this.highLabel,
    super.key,
  });

  final String title;
  final String? subtitle;
  final int value;
  final int max;
  final String? lowLabel;
  final String? highLabel;
  final ValueChanged<int> onChanged;

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
                Expanded(child: Text(title, style: _titleStyle(context))),
                Text('$value/$max', style: _titleStyle(context)),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: _hintStyle(context)),
            ],
            Slider(
              value: value.toDouble(),
              max: max.toDouble(),
              divisions: max,
              label: '$value',
              semanticFormatterCallback: (next) =>
                  '$title ${next.round()} of $max',
              onChanged: (next) => onChanged(next.round()),
            ),
            if (lowLabel != null || highLabel != null)
              Row(
                children: [
                  Expanded(
                    child: Text(lowLabel ?? '', style: _hintStyle(context)),
                  ),
                  Text(highLabel ?? '', style: _hintStyle(context)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// A measured score (for example strength symmetry) that can be marked as
/// "not measured" instead of forcing a misleading 0.
class MeasuredScoreCard extends StatelessWidget {
  const MeasuredScoreCard({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.suffix = '%',
    this.defaultValue = 70,
    super.key,
  });

  final String title;
  final String? subtitle;

  /// 0 means "not measured".
  final int value;
  final String suffix;
  final int defaultValue;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final measured = value > 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.cardPadding,
          8,
          AppConstants.cardPadding,
          AppConstants.cardPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: _titleStyle(context))),
                Text(
                  measured ? '$value$suffix' : 'Not measured',
                  style: measured ? _titleStyle(context) : _hintStyle(context),
                ),
                const SizedBox(width: 4),
                Switch.adaptive(
                  value: measured,
                  onChanged: (next) {
                    HapticFeedback.selectionClick();
                    onChanged(next ? defaultValue : 0);
                  },
                ),
              ],
            ),
            if (subtitle != null) Text(subtitle!, style: _hintStyle(context)),
            if (measured)
              Slider(
                value: value.clamp(1, 100).toDouble(),
                min: 1,
                max: 100,
                divisions: 99,
                label: '$value$suffix',
                semanticFormatterCallback: (next) =>
                    '$title ${next.round()}$suffix',
                onChanged: (next) => onChanged(next.round()),
              ),
          ],
        ),
      ),
    );
  }
}
