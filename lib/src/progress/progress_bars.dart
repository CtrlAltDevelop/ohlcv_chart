import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';

import '../renderer/text_painter_cache.dart';

/// The shape of a [ProgressBars] track and its fill.
enum ProgressShape {
  /// One bar with fully round ends.
  pill,

  /// One bar with square-ish ends and a small corner radius.
  block,

  /// A row of separate cells, filled from the left, the last one partly.
  segmented,
}

/// One thing's progress — a row of a [ProgressBars].
@immutable
class ProgressItem {
  /// Creates a row called [label] that has reached [value] of [total].
  const ProgressItem({
    required this.label,
    required this.value,
    this.total = 100,
    this.target,
    this.color,
    this.valueLabel,
  });

  /// What the row is called, written above the bar at the left.
  final String label;

  /// How far it has got, in the same units as [total].
  final double value;

  /// What full is. A [value] past it fills the bar and no more.
  final double total;

  /// A mark across the bar for where it should be by now, in the same units as
  /// [total]; null marks none.
  final double? target;

  /// What the fill is painted in; null takes the chart's colour.
  final Color? color;

  /// Written above the bar at the right; null writes the share done, as a
  /// whole per cent.
  final String? valueLabel;

  /// How much of the bar is filled, from 0 to 1.
  double get fraction => _share(value);

  /// Where the target sits along the bar, from 0 to 1; null when there is none.
  double? get targetFraction {
    final goal = target;
    return goal == null || !goal.isFinite ? null : _share(goal);
  }

  double _share(double of) {
    if (!of.isFinite || !total.isFinite || total <= 0) return 0;
    return (of / total).clamp(0.0, 1.0);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProgressItem &&
          other.label == label &&
          other.value == value &&
          other.total == total &&
          other.target == target &&
          other.color == color &&
          other.valueLabel == valueLabel;

  @override
  int get hashCode =>
      Object.hash(label, value, total, target, color, valueLabel);
}

/// Where one row of a [ProgressBars] sits.
@immutable
class ProgressRowLayout {
  /// Creates the layout of the row at [index].
  const ProgressRowLayout({
    required this.index,
    required this.item,
    required this.rowRect,
    required this.headerRect,
    required this.trackRect,
    required this.fillRect,
    required this.targetX,
  });

  /// Which row this is, into the chart's items.
  final int index;

  /// The row itself.
  final ProgressItem item;

  /// The whole row: its header and its bar.
  final Rect rowRect;

  /// Where the label and the value are written.
  final Rect headerRect;

  /// The bar at its full length.
  final Rect trackRect;

  /// The part of the bar that is done, from the track's left edge.
  final Rect fillRect;

  /// Where the target mark crosses the bar; null when the row has no target.
  final double? targetX;

  /// Whether [point] falls in the row, or the half of the gap under it.
  bool hit(Offset point) =>
      point.dy >= rowRect.top && point.dy <= rowRect.bottom + _hitSlack;

  static const _hitSlack = 6.0;
}

/// Where every row of a [ProgressBars] sits.
@immutable
class ProgressLayout {
  /// Creates a laid-out chart.
  const ProgressLayout({required this.size, required this.rows});

  /// Nothing to draw.
  static const empty = ProgressLayout(size: Size.zero, rows: []);

  /// The box the chart was laid out in.
  final Size size;

  /// The rows, in the order they were given.
  final List<ProgressRowLayout> rows;

  /// Whether there is anything to draw.
  bool get isEmpty => rows.isEmpty;

  /// The row under [point]; null when it is past the last row.
  ProgressRowLayout? rowAt(Offset point) {
    for (final row in rows) {
      if (row.hit(point)) return row;
    }
    return null;
  }
}

/// Lays out [items] in [size]: a header line of [headerHeight], [headerGap],
/// then a bar [barHeight] tall, with [rowGap] between rows.
///
/// [progress] runs from 0 to 1 and shortens every fill for a draw-in
/// animation; the targets do not move with it.
ProgressLayout layOutProgress(
  List<ProgressItem> items, {
  required Size size,
  double barHeight = 10,
  double headerHeight = 18,
  double headerGap = 6,
  double rowGap = 16,
  EdgeInsets padding = EdgeInsets.zero,
  double progress = 1,
}) {
  if (items.isEmpty) return ProgressLayout(size: size, rows: const []);
  final box = padding.deflateRect(Offset.zero & size);
  if (box.width <= 0 || box.height <= 0) {
    return ProgressLayout(size: size, rows: const []);
  }

  // Rows share whatever height they are given, shrinking to fit a short box
  // rather than spilling out of it.
  final natural = headerHeight + headerGap + barHeight;
  final wanted = items.length * natural + (items.length - 1) * rowGap;
  final scale = wanted > box.height && wanted > 0 ? box.height / wanted : 1.0;
  final header = headerHeight * scale;
  final gap = headerGap * scale;
  final bar = barHeight * scale;
  final between = rowGap * scale;
  final t = progress.clamp(0.0, 1.0);

  final rows = <ProgressRowLayout>[];
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    final top = box.top + i * (header + gap + bar + between);
    final track = Rect.fromLTWH(box.left, top + header + gap, box.width, bar);
    final goal = item.targetFraction;
    rows.add(
      ProgressRowLayout(
        index: i,
        item: item,
        rowRect: Rect.fromLTWH(box.left, top, box.width, header + gap + bar),
        headerRect: Rect.fromLTWH(box.left, top, box.width, header),
        trackRect: track,
        fillRect: Rect.fromLTWH(
          track.left,
          track.top,
          track.width * item.fraction * t,
          track.height,
        ),
        targetX: goal == null ? null : track.left + goal * track.width,
      ),
    );
  }
  return ProgressLayout(size: size, rows: rows);
}

/// Bars that fill to how far each thing has got — progress bars.
///
/// A column of them reads as a checklist of goals: a label and a figure above
/// each bar, the bar itself pill-shaped, blocky or cut into cells, and an
/// optional mark for where it should be by now.
///
/// ```dart
/// ProgressBars(
///   items: const [
///     ProgressItem(label: 'Monthly profit', value: 72, target: 60),
///     ProgressItem(label: 'Drawdown budget', value: 31, total: 100),
///   ],
///   shape: ProgressShape.segmented,
/// );
/// ```
class ProgressBars extends StatefulWidget {
  /// Creates progress bars for [items].
  const ProgressBars({
    super.key,
    required this.items,
    this.shape = ProgressShape.pill,
    this.segments = 10,
    this.segmentGap = 3,
    this.color = const Color(0xFF4C86CD),
    this.trackColor = const Color(0x22909196),
    this.targetColor = const Color(0xFFE9ECEF),
    this.barHeight = 10,
    this.headerHeight = 18,
    this.headerGap = 6,
    this.rowGap = 16,
    this.showValues = true,
    this.labelStyle,
    this.valueStyle,
    this.valueFormatter,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.animationDuration = Duration.zero,
    this.animationCurve = Curves.easeOutCubic,
    this.animateOnMount = true,
    this.onItemTap,
    this.semanticLabel,
  });

  /// The rows, drawn top to bottom in the order given.
  final List<ProgressItem> items;

  /// The shape of the bars.
  final ProgressShape shape;

  /// How many cells a [ProgressShape.segmented] bar is cut into.
  final int segments;

  /// Space between those cells.
  final double segmentGap;

  /// What the fills are painted in, where a row names no colour.
  final Color color;

  /// The bar behind a fill.
  final Color trackColor;

  /// What the target marks are painted in.
  final Color targetColor;

  /// How tall a bar is.
  final double barHeight;

  /// How tall the line of label and value above a bar is.
  final double headerHeight;

  /// Space between that line and its bar.
  final double headerGap;

  /// Space between two rows.
  final double rowGap;

  /// Whether each row's figure is written at the right of its header.
  final bool showValues;

  /// Style of the row labels.
  final TextStyle? labelStyle;

  /// Style of the figures.
  final TextStyle? valueStyle;

  /// Writes a row's figure; null writes the share done as a whole per cent.
  final String Function(ProgressItem item)? valueFormatter;

  /// Space kept clear around the rows.
  final EdgeInsets padding;

  /// Painted behind the whole chart.
  final Color? backgroundColor;

  /// How long the fills take to draw in; zero draws them at once.
  final Duration animationDuration;

  /// The easing of [animationDuration].
  final Curve animationCurve;

  /// Whether the first build draws the fills in.
  final bool animateOnMount;

  /// Called with a row when it is touched, and with null when the touch
  /// leaves the rows.
  final void Function(ProgressItem? item)? onItemTap;

  /// What a screen reader announces for the chart.
  final String? semanticLabel;

  /// How tall the chart is in a box that sets no height.
  double get intrinsicHeight => items.isEmpty
      ? padding.vertical
      : padding.vertical +
            items.length * (headerHeight + headerGap + barHeight) +
            (items.length - 1) * rowGap;

  @override
  State<ProgressBars> createState() => _ProgressBarsState();
}

class _ProgressBarsState extends State<ProgressBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 128);
  ProgressLayout _layout = ProgressLayout.empty;
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
  void didUpdateWidget(ProgressBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
    if (!listEquals(oldWidget.items, widget.items) &&
        widget.animationDuration > Duration.zero) {
      _animation.forward(from: 0);
    }
    if (_touched != null && _touched! >= widget.items.length) _touched = null;
  }

  @override
  void dispose() {
    _text.dispose();
    _animation.dispose();
    super.dispose();
  }

  void _touch(Offset point) {
    final row = _layout.rowAt(point);
    if (row?.index == _touched) return;
    setState(() => _touched = row?.index);
    widget.onItemTap?.call(row?.item);
  }

  void _clear() {
    if (_touched == null) return;
    setState(() => _touched = null);
    widget.onItemTap?.call(null);
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
          final height =
              constraints.hasBoundedHeight && constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : widget.intrinsicHeight;
          _layout = layOutProgress(
            widget.items,
            size: Size(width, height),
            barHeight: widget.barHeight,
            headerHeight: widget.headerHeight,
            headerGap: widget.headerGap,
            rowGap: widget.rowGap,
            padding: widget.padding,
            progress: progress,
          );

          return SizedBox(
            width: width,
            height: height,
            // A raw listener: gesture arbitration would swallow the first
            // hundred milliseconds of a drag down the rows.
            child: Listener(
              onPointerDown: (event) => _touch(event.localPosition),
              onPointerMove: (event) => _touch(event.localPosition),
              onPointerUp: (_) => _clear(),
              onPointerCancel: (_) => _clear(),
              child: CustomPaint(
                size: Size(width, height),
                painter: ProgressBarsPainter(
                  chart: widget,
                  layout: _layout,
                  touched: _touched,
                  textCache: _text,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

String _valueOf(ProgressBars chart, ProgressItem item) {
  final format = chart.valueFormatter;
  if (format != null) return format(item);
  return item.valueLabel ?? '${(item.fraction * 100).round()}%';
}

/// Paints a [ProgressBars]: the labels, the tracks, the fills and the targets.
class ProgressBarsPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [layout].
  ProgressBarsPainter({
    required this.chart,
    required this.layout,
    required this.touched,
    required this.textCache,
  });

  final ProgressBars chart;
  final ProgressLayout layout;

  /// The row under the finger, into [ProgressBars.items]; null when none is.
  final int? touched;
  final TextPainterCache textCache;

  /// The outline of a track, whole or cut into cells.
  Path _trackPath(Rect rect) {
    final radius = chart.shape == ProgressShape.pill
        ? rect.height / 2
        : math.min(3.0, rect.height / 2);
    if (chart.shape != ProgressShape.segmented) {
      return Path()
        ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    }
    // Never so many cells that one is narrower than a pixel.
    final gap = chart.segmentGap;
    final count = chart.segments
        .clamp(1, math.max(1, ((rect.width + gap) / (1 + gap)).floor()))
        .toInt();
    final width = (rect.width - gap * (count - 1)) / count;
    final path = Path();
    for (var i = 0; i < count; i++) {
      final left = rect.left + i * (width + gap);
      path.addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, rect.top, width, rect.height),
          Radius.circular(radius),
        ),
      );
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final background = chart.backgroundColor;
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
    }
    if (layout.isEmpty) return;

    final labelStyle =
        chart.labelStyle ??
        const TextStyle(color: Color(0xFFB4B8C0), fontSize: 12);
    final valueStyle =
        chart.valueStyle ??
        const TextStyle(
          color: Color(0xFFE9ECEF),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        );

    for (final row in layout.rows) {
      if (touched == row.index) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            row.rowRect.inflate(4),
            const Radius.circular(6),
          ),
          Paint()..color = const Color(0x14FFFFFF),
        );
      }

      // The header: the figure at the right, the label in what is left.
      var labelRight = row.headerRect.right;
      if (chart.showValues) {
        final text = _valueOf(chart, row.item);
        if (text.isNotEmpty) {
          final painter = textCache.get(text, valueStyle);
          painter.paint(
            canvas,
            Offset(
              row.headerRect.right - painter.width,
              row.headerRect.center.dy - painter.height / 2,
            ),
          );
          labelRight -= painter.width + 8;
        }
      }
      if (labelRight - row.headerRect.left > 4) {
        final painter = textCache.get(row.item.label, labelStyle);
        // Clipped rather than ellipsised: the cache paints plain lines, and a
        // long label must not run under the figure beside it.
        canvas
          ..save()
          ..clipRect(
            Rect.fromLTRB(
              row.headerRect.left,
              row.headerRect.top,
              labelRight,
              row.headerRect.bottom,
            ),
          );
        painter.paint(
          canvas,
          Offset(
            row.headerRect.left,
            row.headerRect.center.dy - painter.height / 2,
          ),
        );
        canvas.restore();
      }

      // The track, then the fill clipped to it so a short fill keeps the
      // track's rounded left end and a cell is filled part way.
      final track = _trackPath(row.trackRect);
      canvas.drawPath(
        track,
        Paint()
          ..color = chart.trackColor
          ..isAntiAlias = true,
      );
      if (row.fillRect.width > 0) {
        canvas
          ..save()
          ..clipPath(track);
        final fill = Paint()
          ..color = row.item.color ?? chart.color
          ..isAntiAlias = true;
        if (chart.shape == ProgressShape.segmented) {
          canvas.drawRect(row.fillRect, fill);
        } else {
          final radius = chart.shape == ProgressShape.pill
              ? row.fillRect.height / 2
              : math.min(3.0, row.fillRect.height / 2);
          canvas.drawRRect(
            RRect.fromRectAndRadius(row.fillRect, Radius.circular(radius)),
            fill,
          );
        }
        canvas.restore();
      }

      // The target: a rounded tick standing a little proud of the bar.
      final target = row.targetX;
      if (target != null) {
        final over = row.trackRect.height * 0.35;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              target - 1,
              row.trackRect.top - over,
              target + 1,
              row.trackRect.bottom + over,
            ),
            const Radius.circular(1),
          ),
          Paint()..color = chart.targetColor,
        );
      }
    }
  }

  @override
  bool shouldRepaint(ProgressBarsPainter old) =>
      old.chart != chart || old.layout != layout || old.touched != touched;
}
