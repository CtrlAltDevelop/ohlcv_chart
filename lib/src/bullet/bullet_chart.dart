import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../renderer/text_painter_cache.dart';

/// A qualitative stretch behind a [BulletRow]'s bar — poor, fair, good.
@immutable
class BulletBand {
  /// Creates a band running up to [to], painted in [color].
  const BulletBand({required this.to, required this.color, this.label});

  /// Where the band ends, in the row's values. It starts where the one before
  /// it ended, or at the row's minimum for the first.
  final double to;

  /// What it is painted in.
  final Color color;

  /// What it is called, for a legend of your own.
  final String? label;
}

/// One measure against its target — a row of a [BulletChart].
@immutable
class BulletRow {
  /// Creates a row called [label] whose measure is [value].
  const BulletRow({
    required this.label,
    required this.value,
    this.target,
    this.min = 0,
    this.max,
    this.bands = const [],
    this.color,
    this.targetColor,
    this.valueLabel,
    this.tooltip,
  });

  /// What the row is called, written to the left of the bar.
  final String label;

  /// The measure: the length of the bar.
  final double value;

  /// What the measure is compared against, marked by a tick across the bar;
  /// null marks none.
  final double? target;

  /// The value the bar starts from.
  final double min;

  /// The value the bar's track ends at; null takes the largest of [value],
  /// [target] and the bands, with a little room over it.
  final double? max;

  /// Qualitative stretches behind the bar, in order, each ending at its `to`.
  final List<BulletBand> bands;

  /// What the bar is painted in; null takes the chart's colour.
  final Color? color;

  /// What the target tick is painted in; null takes the chart's colour.
  final Color? targetColor;

  /// Written at the end of the bar; null writes the value itself.
  final String? valueLabel;

  /// Shown when the row is touched; null shows the label and value.
  final String? tooltip;

  /// The end of the row's track, whether it was given or worked out.
  double get resolvedMax {
    final given = max;
    // A given top still has to leave a range to draw in.
    if (given != null && given.isFinite) return given > min ? given : min + 1;
    var top = math.max(min, value.isFinite ? value : min);
    final goal = target;
    if (goal != null && goal.isFinite) top = math.max(top, goal);
    for (final band in bands) {
      if (band.to.isFinite) top = math.max(top, band.to);
    }
    // Room over the longest bar, so it never runs flush into the edge.
    if (top <= min) return min + 1;
    return bands.isEmpty && max == null ? top + (top - min) * 0.08 : top;
  }
}

/// Where one row of a [BulletChart] sits.
@immutable
class BulletRowLayout {
  /// Creates the layout of the row at [index].
  const BulletRowLayout({
    required this.index,
    required this.row,
    required this.labelRect,
    required this.trackRect,
    required this.barRect,
    required this.bandRects,
    required this.targetX,
  });

  /// Which row this is, into the chart's rows.
  final int index;

  /// The row itself.
  final BulletRow row;

  /// Where the row's label is written.
  final Rect labelRect;

  /// The whole track the bar runs along, bands included.
  final Rect trackRect;

  /// The measure bar, thinner than the track and centred in it.
  final Rect barRect;

  /// The bands behind the bar, in the row's order; empty when it has none.
  final List<Rect> bandRects;

  /// Where the target tick crosses the track; null when the row has no target.
  final double? targetX;

  /// Whether [point] falls in the row's band of the chart.
  bool hit(Offset point) =>
      point.dy >= trackRect.top - 2 && point.dy <= trackRect.bottom + 2;
}

/// Where every row of a [BulletChart] sits.
@immutable
class BulletLayout {
  /// Creates a laid-out chart.
  const BulletLayout({required this.size, required this.rows});

  /// Nothing to draw.
  static const empty = BulletLayout(size: Size.zero, rows: []);

  /// The box the chart was laid out in.
  final Size size;

  /// The rows, in the order they were given.
  final List<BulletRowLayout> rows;

  /// Whether there is anything to draw.
  bool get isEmpty => rows.isEmpty;

  /// The row under [point]; null when it is past the last row.
  BulletRowLayout? rowAt(Offset point) {
    for (final row in rows) {
      if (row.hit(point)) return row;
    }
    return null;
  }
}

/// Lays out [rows] in [size], each a track [rowHeight] tall with [rowGap]
/// between neighbours, after a label column [labelWidth] wide.
///
/// [progress] runs from 0 to 1 and shortens every bar for a draw-in animation;
/// the bands and targets do not move with it.
BulletLayout layOutBullet(
  List<BulletRow> rows, {
  required Size size,
  double labelWidth = 92,
  double labelGap = 8,
  double rowHeight = 22,
  double rowGap = 10,
  double barThickness = 0.45,
  EdgeInsets padding = EdgeInsets.zero,
  double valueWidth = 0,
  double progress = 1,
}) {
  if (rows.isEmpty) return BulletLayout(size: size, rows: const []);
  final box = padding.deflateRect(Offset.zero & size);
  if (box.width <= 0 || box.height <= 0) {
    return BulletLayout(size: size, rows: const []);
  }

  final labels = labelWidth <= 0 ? 0.0 : math.min(labelWidth, box.width * 0.5);
  final values = valueWidth <= 0 ? 0.0 : math.min(valueWidth, box.width * 0.3);
  final trackLeft = box.left + labels + (labels > 0 ? labelGap : 0);
  final trackWidth = math.max(0.0, box.right - values - trackLeft);
  if (trackWidth <= 0) return BulletLayout(size: size, rows: const []);

  // Rows share whatever height they are given, shrinking to fit a short box
  // rather than spilling out of it.
  final wanted = rows.length * rowHeight + (rows.length - 1) * rowGap;
  final scale = wanted > box.height && wanted > 0 ? box.height / wanted : 1.0;
  final height = rowHeight * scale;
  final gap = rowGap * scale;
  final t = progress.clamp(0.0, 1.0);

  final out = <BulletRowLayout>[];
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    final top = box.top + i * (height + gap);
    final track = Rect.fromLTWH(trackLeft, top, trackWidth, height);
    final min = row.min;
    final max = row.resolvedMax;
    final span = max - min;
    double xOf(double value) {
      if (!(span > 0) || !value.isFinite) return track.left;
      final fraction = ((value - min) / span).clamp(0.0, 1.0);
      return track.left + fraction * track.width;
    }

    final bands = <Rect>[];
    var from = min;
    for (final band in row.bands) {
      final left = xOf(math.min(from, band.to));
      final right = xOf(math.max(from, band.to));
      bands.add(Rect.fromLTRB(left, track.top, right, track.bottom));
      from = band.to;
    }

    final barHeight = height * barThickness.clamp(0.05, 1.0);
    final barTop = track.center.dy - barHeight / 2;
    final zero = xOf(min);
    final end = zero + (xOf(row.value) - zero) * t;
    final bar = Rect.fromLTRB(
      math.min(zero, end),
      barTop,
      math.max(zero, end),
      barTop + barHeight,
    );

    final goal = row.target;
    out.add(
      BulletRowLayout(
        index: i,
        row: row,
        labelRect: Rect.fromLTWH(box.left, top, labels, height),
        trackRect: track,
        barRect: bar,
        bandRects: bands,
        targetX: goal == null || !goal.isFinite ? null : xOf(goal),
      ),
    );
  }
  return BulletLayout(size: size, rows: out);
}

/// A measure against a target on a banded track — a bullet chart.
///
/// Denser than a [GaugeChart] and meant to be stacked: a column of KPIs, each
/// with what it made, what it was meant to make, and what counts as poor, fair
/// or good behind it.
///
/// ```dart
/// BulletChart(
///   rows: const [
///     BulletRow(
///       label: 'Win rate',
///       value: 58,
///       target: 55,
///       max: 100,
///       bands: [
///         BulletBand(to: 40, color: Color(0x33E03131)),
///         BulletBand(to: 55, color: Color(0x33F59F00)),
///         BulletBand(to: 100, color: Color(0x332F9E44)),
///       ],
///     ),
///   ],
/// );
/// ```
class BulletChart extends StatefulWidget {
  /// Creates a bullet chart of [rows].
  const BulletChart({
    super.key,
    required this.rows,
    this.barColor = const Color(0xFF4C86CD),
    this.targetColor = const Color(0xFFE9ECEF),
    this.trackColor = const Color(0x22909196),
    this.labelWidth = 92,
    this.labelGap = 8,
    this.rowHeight = 22,
    this.rowGap = 10,
    this.barThickness = 0.45,
    this.targetWidth = 3,
    this.rounded = true,
    this.labelStyle,
    this.showValues = true,
    this.valueStyle,
    this.valueFormatter,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.animationDuration = Duration.zero,
    this.animationCurve = Curves.easeOutCubic,
    this.animateOnMount = true,
    this.onRowTap,
    this.tooltipBuilder,
    this.semanticLabel,
  });

  /// The rows, drawn top to bottom in the order given.
  final List<BulletRow> rows;

  /// What the measure bars are painted in, where a row names no colour.
  final Color barColor;

  /// What the target ticks are painted in, where a row names no colour.
  final Color targetColor;

  /// The track under a row that has no bands.
  final Color trackColor;

  /// How wide the label column is; 0 writes no labels.
  final double labelWidth;

  /// Space between the labels and the tracks.
  final double labelGap;

  /// How tall one row's track is.
  final double rowHeight;

  /// Space between two rows.
  final double rowGap;

  /// How thick the measure bar is, as a share of the track's height.
  final double barThickness;

  /// How thick the target tick is.
  final double targetWidth;

  /// Whether the bars have rounded ends.
  final bool rounded;

  /// Style of the row labels.
  final TextStyle? labelStyle;

  /// Whether each row's value is written at the right.
  final bool showValues;

  /// Style of those values.
  final TextStyle? valueStyle;

  /// Writes a value; null writes it with as few decimals as it needs.
  final String Function(BulletRow row)? valueFormatter;

  /// Space kept clear around the rows.
  final EdgeInsets padding;

  /// Painted behind the whole chart.
  final Color? backgroundColor;

  /// How long the bars take to draw in; zero draws them at once.
  final Duration animationDuration;

  /// The easing of [animationDuration].
  final Curve animationCurve;

  /// Whether the first build draws the bars in.
  final bool animateOnMount;

  /// Called with a row when it is touched, and with null when the touch
  /// leaves the rows.
  final void Function(BulletRow? row)? onRowTap;

  /// Builds the card shown over a touched row; null shows its label and value.
  final Widget Function(BuildContext context, BulletRow row)? tooltipBuilder;

  /// What a screen reader announces for the chart.
  final String? semanticLabel;

  /// How tall the chart is in a box that sets no height.
  double get intrinsicHeight =>
      rows.isEmpty
          ? padding.vertical
          : padding.vertical +
              rows.length * rowHeight +
              (rows.length - 1) * rowGap;

  @override
  State<BulletChart> createState() => _BulletChartState();
}

class _BulletChartState extends State<BulletChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 128);
  BulletLayout _layout = BulletLayout.empty;
  int? _touched;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
      value: 1,
    )..addListener(() => setState(() {}));
    if (widget.animateOnMount && widget.animationDuration > Duration.zero) {
      _animation.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(BulletChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
    if (!identical(oldWidget.rows, widget.rows) &&
        widget.animationDuration > Duration.zero) {
      _animation.forward(from: 0);
    }
    if (_touched != null && _touched! >= widget.rows.length) _touched = null;
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  void _touch(Offset point) {
    final row = _layout.rowAt(point);
    if (row?.index == _touched) return;
    setState(() => _touched = row?.index);
    widget.onRowTap?.call(row?.row);
  }

  void _clear() {
    if (_touched == null) return;
    setState(() => _touched = null);
    widget.onRowTap?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.animationCurve.transform(_animation.value);

    return Semantics(
      container: true,
      label: widget.semanticLabel,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : 320.0;
          final height = constraints.hasBoundedHeight &&
                  constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : widget.intrinsicHeight;
          final size = Size(width, height);
          final valueWidth = widget.showValues ? 56.0 : 0.0;
          _layout = layOutBullet(
            widget.rows,
            size: size,
            labelWidth: widget.labelWidth,
            labelGap: widget.labelGap,
            rowHeight: widget.rowHeight,
            rowGap: widget.rowGap,
            barThickness: widget.barThickness,
            padding: widget.padding,
            valueWidth: valueWidth,
            progress: progress,
          );

          final touched = _touched;
          final row = touched != null && touched < widget.rows.length
              ? widget.rows[touched]
              : null;

          return SizedBox(
            width: width,
            height: height,
            // A raw listener: gesture arbitration would swallow the first
            // hundred milliseconds of a drag along the rows.
            child: Listener(
              onPointerDown: (event) => _touch(event.localPosition),
              onPointerMove: (event) => _touch(event.localPosition),
              onPointerUp: (_) => _clear(),
              onPointerCancel: (_) => _clear(),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: BulletChartPainter(
                        chart: widget,
                        layout: _layout,
                        touched: touched,
                        textCache: _text,
                      ),
                    ),
                  ),
                  if (row != null) _tooltip(context, row),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tooltip(BuildContext context, BulletRow row) {
    final build = widget.tooltipBuilder;
    final rect = _layout.rows[_touched!].trackRect;
    final child = build != null
        ? build(context, row)
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xEE1B1D22),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              row.tooltip ?? '${row.label}  ${_valueOf(widget, row)}',
              style: const TextStyle(color: Color(0xFFE9ECEF), fontSize: 11),
            ),
          );
    return Positioned(
      left: rect.left,
      top: math.max(0, rect.top - 26),
      child: IgnorePointer(child: child),
    );
  }
}

String _valueOf(BulletChart chart, BulletRow row) {
  final format = chart.valueFormatter;
  if (format != null) return format(row);
  final given = row.valueLabel;
  if (given != null) return given;
  final value = row.value;
  if (!value.isFinite) return '';
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}

/// Paints a [BulletChart]: the bands, the measure bars, the target ticks and
/// the labels.
class BulletChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [layout].
  BulletChartPainter({
    required this.chart,
    required this.layout,
    required this.touched,
    required this.textCache,
  });

  final BulletChart chart;
  final BulletLayout layout;

  /// The row under the finger, into [BulletChart.rows]; null when none is.
  final int? touched;
  final TextPainterCache textCache;

  @override
  void paint(Canvas canvas, Size size) {
    final background = chart.backgroundColor;
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
    }
    if (layout.isEmpty) return;

    final labelStyle = chart.labelStyle ??
        const TextStyle(color: Color(0xFFB4B8C0), fontSize: 11);
    final valueStyle = chart.valueStyle ??
        const TextStyle(
          color: Color(0xFFE9ECEF),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        );

    for (final row in layout.rows) {
      final radius = Radius.circular(
        chart.rounded ? row.barRect.height / 2 : 0,
      );

      // The track, or the bands over it where the row has any.
      if (row.bandRects.isEmpty) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            row.trackRect,
            Radius.circular(chart.rounded ? row.trackRect.height / 4 : 0),
          ),
          Paint()..color = chart.trackColor,
        );
      } else {
        for (var i = 0; i < row.bandRects.length; i++) {
          canvas.drawRect(
            row.bandRects[i],
            Paint()..color = row.row.bands[i].color,
          );
        }
      }

      // The measure.
      if (row.barRect.width > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(row.barRect, radius),
          Paint()..color = row.row.color ?? chart.barColor,
        );
      }

      // The target, a tick the full height of the track.
      final target = row.targetX;
      if (target != null) {
        final half = chart.targetWidth / 2;
        canvas.drawRect(
          Rect.fromLTRB(
            target - half,
            row.trackRect.top + row.trackRect.height * 0.12,
            target + half,
            row.trackRect.bottom - row.trackRect.height * 0.12,
          ),
          Paint()..color = row.row.targetColor ?? chart.targetColor,
        );
      }

      if (touched == row.index) {
        canvas.drawRect(
          row.trackRect,
          Paint()..color = const Color(0x14FFFFFF),
        );
      }

      if (row.labelRect.width > 4) {
        final painter = textCache.get(row.row.label, labelStyle);
        // Clipped rather than ellipsised: the cache paints plain lines, and a
        // long label must not run over the track beside it.
        canvas.save();
        canvas.clipRect(row.labelRect);
        painter.paint(
          canvas,
          Offset(
            row.labelRect.right - painter.width,
            row.labelRect.center.dy - painter.height / 2,
          ),
        );
        canvas.restore();
      }

      if (chart.showValues) {
        final text = _valueOf(chart, row.row);
        if (text.isNotEmpty) {
          final painter = textCache.get(text, valueStyle);
          painter.paint(
            canvas,
            Offset(
              math.min(
                row.trackRect.right + 6,
                layout.size.width - painter.width,
              ),
              row.trackRect.center.dy - painter.height / 2,
            ),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(BulletChartPainter old) =>
      old.chart != chart || old.layout != layout || old.touched != touched;
}
