import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Data-viz colors, validated for colorblind separation in both modes.
/// Light and dark are separate steps of the same hues, not an inversion.
class ChartColors {
  const ChartColors._();

  static const _lightSeries = [
    Color(0xFF2A78D6),
    Color(0xFFEB6834),
    Color(0xFF1BAF7A),
  ];
  static const _darkSeries = [
    Color(0xFF3987E5),
    Color(0xFFD95926),
    Color(0xFF199E70),
  ];

  static bool _dark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Categorical slot 1-3, always assigned in this order.
  static Color series(BuildContext context, int slot) {
    final list = _dark(context) ? _darkSeries : _lightSeries;
    return list[(slot - 1).clamp(0, list.length - 1)];
  }

  static Color grid(BuildContext context) =>
      _dark(context) ? const Color(0xFF2C2C2A) : const Color(0xFFE1E0D9);

  static Color baseline(BuildContext context) =>
      _dark(context) ? const Color(0xFF383835) : const Color(0xFFC3C2B7);

  static Color muted(BuildContext context) => const Color(0xFF898781);

  static Color goodText(BuildContext context) =>
      _dark(context) ? const Color(0xFF0CA30C) : const Color(0xFF006300);

  static Color criticalText(BuildContext context) => const Color(0xFFD03B3B);
}

class ChartPoint {
  const ChartPoint(this.date, this.value, {this.note});

  final DateTime date;
  final double value;
  final String? note;
}

String shortDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}

/// A single-series line over time with an optional target reference line,
/// tap/hover inspection, and a text readout for the selected point.
class TrendLineChart extends StatefulWidget {
  const TrendLineChart({
    required this.points,
    required this.minY,
    required this.maxY,
    required this.formatValue,
    this.target,
    this.targetLabel,
    this.height = 150,
    this.semanticsLabel,
    super.key,
  });

  final List<ChartPoint> points;
  final double minY;
  final double maxY;
  final double? target;
  final String? targetLabel;
  final String Function(double value) formatValue;
  final double height;
  final String? semanticsLabel;

  @override
  State<TrendLineChart> createState() => _TrendLineChartState();
}

class _TrendLineChartState extends State<TrendLineChart> {
  int? _selected;

  static const _leftPad = 30.0;
  static const _rightPad = 12.0;

  List<double> _xs(double width) {
    final points = widget.points;
    if (points.length == 1) return [(_leftPad + width - _rightPad) / 2];
    final first = points.first.date.millisecondsSinceEpoch.toDouble();
    final last = points.last.date.millisecondsSinceEpoch.toDouble();
    final span = last - first;
    final plotWidth = width - _leftPad - _rightPad;
    return [
      for (var i = 0; i < points.length; i++)
        _leftPad +
            (span <= 0
                ? plotWidth * i / (points.length - 1)
                : plotWidth *
                      (points[i].date.millisecondsSinceEpoch - first) /
                      span),
    ];
  }

  void _select(Offset position, double width) {
    final xs = _xs(width);
    var best = 0;
    for (var i = 1; i < xs.length; i++) {
      if ((xs[i] - position.dx).abs() < (xs[best] - position.dx).abs()) {
        best = i;
      }
    }
    if (best != _selected) setState(() => _selected = best);
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    if (points.isEmpty) return const SizedBox.shrink();
    final shown = points[_selected ?? points.length - 1];
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: widget.semanticsLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: widget.formatValue(shown.value),
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text:
                        '  ${shortDate(shown.date)}'
                        '${shown.note == null ? '' : ' · ${shown.note}'}'
                        '${_selected == null ? ' (latest)' : ''}',
                    style: textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          ExcludeSemantics(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return MouseRegion(
                  onHover: (event) => _select(event.localPosition, width),
                  onExit: (_) => setState(() => _selected = null),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) =>
                        _select(details.localPosition, width),
                    onHorizontalDragUpdate: (details) =>
                        _select(details.localPosition, width),
                    child: CustomPaint(
                      size: Size(width, widget.height),
                      painter: _LinePainter(
                        points: points,
                        xs: _xs(width),
                        minY: widget.minY,
                        maxY: widget.maxY,
                        target: widget.target,
                        targetLabel: widget.targetLabel,
                        selected: _selected,
                        formatValue: widget.formatValue,
                        line: ChartColors.series(context, 1),
                        surface:
                            Theme.of(context).cardTheme.color ??
                            Theme.of(context).colorScheme.surface,
                        grid: ChartColors.grid(context),
                        baseline: ChartColors.baseline(context),
                        muted: ChartColors.muted(context),
                        ink: Theme.of(context).colorScheme.onSurface,
                        leftPad: _leftPad,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.points,
    required this.xs,
    required this.minY,
    required this.maxY,
    required this.target,
    required this.targetLabel,
    required this.selected,
    required this.formatValue,
    required this.line,
    required this.surface,
    required this.grid,
    required this.baseline,
    required this.muted,
    required this.ink,
    required this.leftPad,
  });

  final List<ChartPoint> points;
  final List<double> xs;
  final double minY;
  final double maxY;
  final double? target;
  final String? targetLabel;
  final int? selected;
  final String Function(double value) formatValue;
  final Color line;
  final Color surface;
  final Color grid;
  final Color baseline;
  final Color muted;
  final Color ink;
  final double leftPad;

  static const _top = 8.0;
  static const _bottom = 20.0;

  double _y(double value, Size size) {
    final range = maxY - minY;
    final t = range == 0 ? 0.5 : (value - minY) / range;
    return _top + (size.height - _top - _bottom) * (1 - t.clamp(0.0, 1.0));
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at, {
    Color? color,
    TextAlign align = TextAlign.left,
    double size = 10,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color ?? muted, fontSize: size),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (align) {
      TextAlign.right => at.dx - painter.width,
      TextAlign.center => at.dx - painter.width / 2,
      _ => at.dx,
    };
    painter.paint(canvas, Offset(dx, at.dy - painter.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final hairline = Paint()
      ..color = grid
      ..strokeWidth = 1;
    final right = size.width - 12;

    // Recessive gridlines at min, middle, and max, with tick labels.
    for (final value in [minY, (minY + maxY) / 2, maxY]) {
      final y = _y(value, size);
      canvas.drawLine(Offset(leftPad, y), Offset(right, y), hairline);
      _text(
        canvas,
        formatValue(value),
        Offset(leftPad - 6, y),
        align: TextAlign.right,
      );
    }
    canvas.drawLine(
      Offset(leftPad, _y(minY, size)),
      Offset(right, _y(minY, size)),
      Paint()
        ..color = baseline
        ..strokeWidth = 1,
    );

    final goal = target;
    if (goal != null) {
      final y = _y(goal, size);
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(right, y),
        Paint()
          ..color = muted
          ..strokeWidth = 1,
      );
      // Left-aligned so it never collides with the end-of-line label.
      if (targetLabel != null) {
        _text(canvas, targetLabel!, Offset(leftPad + 4, y - 8));
      }
    }

    final offsets = [
      for (var i = 0; i < points.length; i++)
        Offset(xs[i], _y(points[i].value, size)),
    ];

    if (offsets.length > 1) {
      final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (final offset in offsets.skip(1)) {
        path.lineTo(offset.dx, offset.dy);
      }
      final area = Path.from(path)
        ..lineTo(offsets.last.dx, _y(minY, size))
        ..lineTo(offsets.first.dx, _y(minY, size))
        ..close();
      canvas.drawPath(area, Paint()..color = line.withValues(alpha: 0.10));
      canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }

    final chosen = selected;
    if (chosen != null) {
      canvas.drawLine(
        Offset(offsets[chosen].dx, _top),
        Offset(offsets[chosen].dx, _y(minY, size)),
        Paint()
          ..color = baseline
          ..strokeWidth = 1,
      );
    }

    // Markers: every point when sparse, otherwise the latest and selected.
    for (var i = 0; i < offsets.length; i++) {
      final emphasized = i == chosen || i == offsets.length - 1;
      if (offsets.length > 14 && !emphasized) continue;
      canvas.drawCircle(
        offsets[i],
        emphasized ? 6 : 5,
        Paint()..color = surface,
      );
      canvas.drawCircle(
        offsets[i],
        emphasized ? 4.5 : 3.5,
        Paint()..color = line,
      );
    }

    // Direct label only at the end of the line.
    final last = offsets.last;
    _text(
      canvas,
      formatValue(points.last.value),
      Offset(math.min(last.dx + 8, right - 16), last.dy - 12),
      color: ink,
      size: 11,
    );

    _text(
      canvas,
      shortDate(points.first.date),
      Offset(xs.first, size.height - 6),
    );
    if (points.length > 1) {
      _text(
        canvas,
        shortDate(points.last.date),
        Offset(xs.last, size.height - 6),
        align: TextAlign.right,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.points != points ||
      old.selected != selected ||
      old.line != line ||
      old.xs.length != xs.length;
}

class BarDatum {
  const BarDatum({required this.label, required this.value, this.detail});

  final String label;
  final double value;
  final String? detail;
}

/// Single-series columns with an optional target line. Only the latest bar
/// is labeled; tap or hover a bar to read the others.
class ColumnChart extends StatefulWidget {
  const ColumnChart({
    required this.bars,
    required this.maxValue,
    this.target,
    this.targetLabel,
    this.height = 150,
    this.semanticsLabel,
    super.key,
  });

  final List<BarDatum> bars;
  final double maxValue;
  final double? target;
  final String? targetLabel;
  final double height;
  final String? semanticsLabel;

  @override
  State<ColumnChart> createState() => _ColumnChartState();
}

class _ColumnChartState extends State<ColumnChart> {
  int? _selected;

  void _select(Offset position, double width) {
    if (widget.bars.isEmpty) return;
    final slot = width / widget.bars.length;
    final index = (position.dx / slot).floor().clamp(0, widget.bars.length - 1);
    if (index != _selected) setState(() => _selected = index);
  }

  @override
  Widget build(BuildContext context) {
    final bars = widget.bars;
    if (bars.isEmpty) return const SizedBox.shrink();
    final shown = bars[_selected ?? bars.length - 1];
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: widget.semanticsLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: shown.detail ?? shown.value.round().toString(),
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text: '  ${shown.label}',
                    style: textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          ExcludeSemantics(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return MouseRegion(
                  onHover: (event) => _select(event.localPosition, width),
                  onExit: (_) => setState(() => _selected = null),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) =>
                        _select(details.localPosition, width),
                    child: CustomPaint(
                      size: Size(width, widget.height),
                      painter: _ColumnPainter(
                        bars: bars,
                        maxValue: widget.maxValue,
                        target: widget.target,
                        targetLabel: widget.targetLabel,
                        selected: _selected,
                        fill: ChartColors.series(context, 1),
                        grid: ChartColors.grid(context),
                        baseline: ChartColors.baseline(context),
                        muted: ChartColors.muted(context),
                        ink: Theme.of(context).colorScheme.onSurface,
                        selectedWash: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ColumnPainter extends CustomPainter {
  _ColumnPainter({
    required this.bars,
    required this.maxValue,
    required this.target,
    required this.targetLabel,
    required this.selected,
    required this.fill,
    required this.grid,
    required this.baseline,
    required this.muted,
    required this.ink,
    required this.selectedWash,
  });

  final List<BarDatum> bars;
  final double maxValue;
  final double? target;
  final String? targetLabel;
  final int? selected;
  final Color fill;
  final Color grid;
  final Color baseline;
  final Color muted;
  final Color ink;
  final Color selectedWash;

  static const _top = 14.0;
  static const _bottom = 20.0;

  void _text(Canvas canvas, String text, Offset center, {Color? color}) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color ?? muted, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plotHeight = size.height - _top - _bottom;
    final baseY = _top + plotHeight;
    final slot = size.width / bars.length;
    final barWidth = math.min(24.0, slot * 0.6);
    final top = math.max(maxValue, target ?? 0);

    double y(double value) =>
        baseY - plotHeight * (top == 0 ? 0 : (value / top).clamp(0.0, 1.0));

    canvas.drawLine(
      Offset(0, _top),
      Offset(size.width, _top),
      Paint()
        ..color = grid
        ..strokeWidth = 1,
    );

    for (var i = 0; i < bars.length; i++) {
      final center = slot * i + slot / 2;
      if (i == selected) {
        canvas.drawRect(
          Rect.fromLTRB(slot * i, _top, slot * (i + 1), baseY),
          Paint()..color = selectedWash,
        );
      }
      final barTop = y(bars[i].value);
      if (bars[i].value > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTRB(
              center - barWidth / 2,
              barTop,
              center + barWidth / 2,
              baseY,
            ),
            topLeft: const Radius.circular(4),
            topRight: const Radius.circular(4),
          ),
          Paint()..color = fill,
        );
      }
      final isLast = i == bars.length - 1;
      if (isLast || i == selected) {
        _text(
          canvas,
          bars[i].value.round().toString(),
          Offset(center, barTop - 8),
          color: ink,
        );
      }
      // Every other label so dates never collide; the latest is always shown.
      if (isLast || (bars.length - 1 - i).isEven) {
        _text(canvas, bars[i].label, Offset(center, size.height - 7));
      }
    }

    canvas.drawLine(
      Offset(0, baseY),
      Offset(size.width, baseY),
      Paint()
        ..color = baseline
        ..strokeWidth = 1,
    );

    final goal = target;
    if (goal != null && goal > 0) {
      final goalY = y(goal);
      canvas.drawLine(
        Offset(0, goalY),
        Offset(size.width, goalY),
        Paint()
          ..color = muted
          ..strokeWidth = 1,
      );
      if (targetLabel != null) {
        final painter = TextPainter(
          text: TextSpan(
            text: targetLabel,
            style: TextStyle(color: muted, fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(
          canvas,
          Offset(size.width - painter.width, goalY - painter.height - 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ColumnPainter old) =>
      old.bars != bars || old.selected != selected || old.fill != fill;
}

class ShareSegment {
  const ShareSegment({required this.label, required this.value});

  final String label;
  final int value;
}

/// A part-to-whole bar (at most three segments) with a labeled legend. Counts
/// are always visible in the legend, so color never carries meaning alone.
class ShareBar extends StatelessWidget {
  const ShareBar({required this.segments, super.key});

  final List<ShareSegment> segments;

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<int>(0, (sum, item) => sum + item.value);
    final surface =
        Theme.of(context).cardTheme.color ??
        Theme.of(context).colorScheme.surface;
    final visible = segments.where((item) => item.value > 0).toList();

    return Semantics(
      label: segments.map((item) => '${item.label}: ${item.value}').join(', '),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 16,
                child: total == 0
                    ? Container(color: ChartColors.grid(context))
                    : Row(
                        children: [
                          for (var i = 0; i < visible.length; i++) ...[
                            if (i > 0) Container(width: 2, color: surface),
                            Expanded(
                              flex: visible[i].value,
                              child: Container(
                                color: ChartColors.series(
                                  context,
                                  segments.indexOf(visible[i]) + 1,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                for (var i = 0; i < segments.length; i++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: ChartColors.series(context, i + 1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${segments[i].label} ${segments[i].value}',
                        style: Theme.of(context).textTheme.bodySmall,
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

/// A compact single-metric trend for small multiples (one chart per metric
/// instead of many converging lines on one plot). With a [target], the scale
/// is fixed at 40-100 for symmetry percentages; without one it fits the data.
class MetricSparkTile extends StatelessWidget {
  const MetricSparkTile({
    required this.title,
    required this.points,
    this.target,
    this.format,
    this.suffix = '%',
    super.key,
  });

  final String title;
  final List<ChartPoint> points;
  final double? target;
  final String suffix;

  /// Formats a value (and the change) for display; defaults to a rounded
  /// number with [suffix].
  final String Function(double value)? format;

  String _format(double value) =>
      format?.call(value) ?? '${value.round()}$suffix';

  @override
  Widget build(BuildContext context) {
    final latest = points.last.value;
    final delta = points.length > 1 ? latest - points.first.value : null;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final goal = target;
    final changed = delta != null && delta.abs() >= 0.05;
    final up = (delta ?? 0) > 0;

    return Semantics(
      label:
          '$title: ${_format(latest)}'
          '${changed ? ', ${up ? 'up' : 'down'} ${_format(delta.abs())} since ${shortDate(points.first.date)}' : ''}'
          '${goal == null ? '' : ', target ${_format(goal)}'}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.6),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      _format(latest),
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (changed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            up ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 14,
                            color: up
                                ? ChartColors.goodText(context)
                                : ChartColors.criticalText(context),
                          ),
                          Text(
                            _format(delta.abs()),
                            style: textTheme.labelMedium?.copyWith(
                              color: up
                                  ? ChartColors.goodText(context)
                                  : ChartColors.criticalText(context),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                width: double.infinity,
                child: CustomPaint(
                  painter: _SparkPainter(
                    points: points,
                    target: goal,
                    line: ChartColors.series(context, 1),
                    surface:
                        Theme.of(context).cardTheme.color ?? scheme.surface,
                    targetColor: ChartColors.muted(context),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                goal == null
                    ? '${points.length} ${points.length == 1 ? 'session' : 'sessions'} since ${shortDate(points.first.date)}'
                    : latest >= goal
                    ? 'At target (${_format(goal)})'
                    : 'Target ${_format(goal)}',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({
    required this.points,
    required this.target,
    required this.line,
    required this.surface,
    required this.targetColor,
  });

  final List<ChartPoint> points;
  final double? target;
  final Color line;
  final Color surface;
  final Color targetColor;

  @override
  void paint(Canvas canvas, Size size) {
    var minY = 40.0;
    var maxY = 100.0;
    if (target == null) {
      final values = points.map((point) => point.value);
      minY = values.reduce(math.min);
      maxY = values.reduce(math.max);
      final pad = maxY == minY
          ? math.max(1.0, maxY * 0.1)
          : (maxY - minY) * 0.15;
      minY -= pad;
      maxY += pad;
    }
    double y(double value) =>
        size.height -
        size.height * ((value - minY) / (maxY - minY)).clamp(0.0, 1.0);
    final goal = target;
    if (goal != null) {
      final targetY = y(goal);
      canvas.drawLine(
        Offset(0, targetY),
        Offset(size.width, targetY),
        Paint()
          ..color = targetColor
          ..strokeWidth = 1,
      );
    }
    final count = points.length;
    final offsets = [
      for (var i = 0; i < count; i++)
        Offset(
          count == 1 ? size.width - 6 : 4 + (size.width - 10) * i / (count - 1),
          y(points[i].value),
        ),
    ];
    if (offsets.length > 1) {
      final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (final offset in offsets.skip(1)) {
        path.lineTo(offset.dx, offset.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.drawCircle(offsets.last, 6, Paint()..color = surface);
    canvas.drawCircle(offsets.last, 4, Paint()..color = line);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.points != points || old.line != line || old.target != target;
}
