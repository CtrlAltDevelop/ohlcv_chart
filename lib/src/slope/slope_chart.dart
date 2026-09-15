import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../renderer/text_painter_cache.dart';

/// One line of a [SlopeChart] — a thing measured at every period.
@immutable
class SlopeSeries {
  /// Creates a series called [label] with one value per period.
  ///
  /// A null value is a period the series was not in; its line breaks there.
  const SlopeSeries({
    required this.label,
    required this.values,
    this.color,
    this.tooltip,
  });

  /// What the series is called, written at both ends of its line.
  final String label;

  /// Its value at each period, in the chart's period order.
  final List<double?> values;

  /// What its line and dots are painted in; null takes a colour from the
  /// chart's palette by position.
  final Color? color;

  /// Shown when the series is touched; null shows its label and values.
  final String? tooltip;
}

/// What a [SlopeChart] puts on its vertical axis.
enum SlopeScale {
  /// The values themselves, on one shared scale — a slope chart.
  value,

  /// The rank at each period, 1 at the top — a bump chart.
  rank,
}

/// The ranks of [values] at one period, 1 for the largest.
///
/// Nulls stay null: a series that was not there has no rank. Ties take the
/// same rank, and the ranks after them skip, the way places in a table do.
List<int?> rankValues(List<double?> values, {bool ascending = false}) {
  final order = <int>[
    for (var i = 0; i < values.length; i++)
      if (values[i] != null && values[i]!.isFinite) i,
  ]..sort((a, b) {
      final compare = values[a]!.compareTo(values[b]!);
      return ascending ? compare : -compare;
    });
  final ranks = List<int?>.filled(values.length, null);
  var place = 0;
  for (var i = 0; i < order.length; i++) {
    if (i == 0 || values[order[i]] != values[order[i - 1]]) place = i + 1;
    ranks[order[i]] = place;
  }
  return ranks;
}

/// Where one series of a [SlopeChart] runs.
@immutable
class SlopeSeriesLayout {
  /// Creates the layout of the series at [index].
  const SlopeSeriesLayout({
    required this.index,
    required this.series,
    required this.points,
  });

  /// Which series this is, into the chart's series.
  final int index;

  /// The series itself.
  final SlopeSeries series;

  /// Where it sits at each period; null at a period it has no value for.
  final List<Offset?> points;

  /// Its first drawn point, for a label at the left; null when it has none.
  Offset? get firstPoint => points.cast<Offset?>().firstWhere(
        (point) => point != null,
        orElse: () => null,
      );

  /// Its last drawn point, for a label at the right.
  Offset? get lastPoint => points.reversed.cast<Offset?>().firstWhere(
        (point) => point != null,
        orElse: () => null,
      );
}

/// Where every series of a [SlopeChart] runs.
@immutable
class SlopeLayout {
  /// Creates a laid-out chart.
  const SlopeLayout({
    required this.size,
    required this.plotRect,
    required this.series,
    required this.columnX,
    required this.min,
    required this.max,
  });

  /// Nothing to draw.
  static const empty = SlopeLayout(
    size: Size.zero,
    plotRect: Rect.zero,
    series: [],
    columnX: [],
    min: 0,
    max: 0,
  );

  /// The box the chart was laid out in.
  final Size size;

  /// The part of it the lines run in.
  final Rect plotRect;

  /// The series, in the order they were given.
  final List<SlopeSeriesLayout> series;

  /// Where each period's column sits across the plot.
  final List<double> columnX;

  /// The value or rank at the top of the plot.
  final double min;

  /// The one at the bottom.
  final double max;

  /// Whether there is anything to draw.
  bool get isEmpty => series.isEmpty || columnX.isEmpty;

  /// The series nearest [point], within [within] pixels of its dot at the
  /// column nearest the point; null when none is.
  ///
  /// Nearest column first, then nearest line in it: picking the closest dot
  /// outright would jump to a neighbouring period whenever the finger sat
  /// between two columns.
  SlopeSeriesLayout? seriesAt(Offset point, {double within = 32}) {
    if (isEmpty) return null;
    final column = columnAt(point.dx);
    SlopeSeriesLayout? best;
    var bestDistance = within;
    for (final laid in series) {
      final at = column < laid.points.length ? laid.points[column] : null;
      if (at == null) continue;
      final distance = (at.dy - point.dy).abs();
      if (distance <= bestDistance) {
        bestDistance = distance;
        best = laid;
      }
    }
    return best;
  }

  /// The period column nearest [x].
  int columnAt(double x) {
    var best = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < columnX.length; i++) {
      final distance = (columnX[i] - x).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = i;
      }
    }
    return best;
  }
}

/// Lays out [series] over [periods] columns in [size].
///
/// With [scale] of [SlopeScale.rank] the lines are placed by their rank at
/// each period rather than their value, which is what makes a bump chart.
/// [progress] reveals the columns left to right, for a draw-in animation.
SlopeLayout layOutSlope(
  List<SlopeSeries> series, {
  required Size size,
  required int periods,
  SlopeScale scale = SlopeScale.value,
  bool ascending = false,
  double labelWidth = 72,
  double headerHeight = 0,
  double? min,
  double? max,
  EdgeInsets padding = EdgeInsets.zero,
  double progress = 1,
}) {
  if (series.isEmpty || periods <= 0) return SlopeLayout.empty;
  final box = padding.deflateRect(Offset.zero & size);
  if (box.width <= 0 || box.height <= 0) return SlopeLayout.empty;

  final labels = labelWidth <= 0 ? 0.0 : math.min(labelWidth, box.width * 0.35);
  final plot = Rect.fromLTRB(
    box.left + labels,
    box.top + math.max(0, headerHeight),
    box.right - labels,
    box.bottom,
  );
  if (plot.width <= 0 || plot.height <= 0) return SlopeLayout.empty;

  // The values actually plotted: the raw ones, or the ranks per period.
  final plotted = <List<double?>>[];
  if (scale == SlopeScale.rank) {
    final byPeriod = <List<int?>>[];
    for (var p = 0; p < periods; p++) {
      byPeriod.add(
        rankValues(
          [
            for (final one in series)
              p < one.values.length ? one.values[p] : null,
          ],
          ascending: ascending,
        ),
      );
    }
    for (var i = 0; i < series.length; i++) {
      plotted.add([for (var p = 0; p < periods; p++) byPeriod[p][i]?.toDouble()]);
    }
  } else {
    for (final one in series) {
      plotted.add([
        for (var p = 0; p < periods; p++)
          p < one.values.length && (one.values[p]?.isFinite ?? false)
              ? one.values[p]
              : null,
      ]);
    }
  }

  var low = min, high = max;
  if (low == null || high == null) {
    var lo = double.infinity, hi = double.negativeInfinity;
    for (final row in plotted) {
      for (final value in row) {
        if (value == null) continue;
        lo = math.min(lo, value);
        hi = math.max(hi, value);
      }
    }
    if (!lo.isFinite || !hi.isFinite) return SlopeLayout.empty;
    if (scale == SlopeScale.rank) {
      // Ranks are whole places, so the ends are exact: no air, rank 1 on top.
      low ??= lo;
      high ??= hi;
    } else {
      final pad = hi > lo ? (hi - lo) * 0.08 : (hi.abs() * 0.05 + 1);
      low ??= lo - pad;
      high ??= hi + pad;
    }
  }
  if (!(high > low)) high = low + 1;

  // Rank 1 and the largest value both belong at the top of the plot.
  final span = high - low;
  double yOf(double value) {
    final fraction = ((value - low!) / span).clamp(0.0, 1.0);
    return scale == SlopeScale.rank
        ? plot.top + fraction * plot.height
        : plot.bottom - fraction * plot.height;
  }

  final columns = <double>[
    for (var p = 0; p < periods; p++)
      periods == 1
          ? plot.center.dx
          : plot.left + plot.width * p / (periods - 1),
  ];

  final shown = periods == 1
      ? plot.right
      : plot.left + plot.width * progress.clamp(0.0, 1.0);
  final laid = <SlopeSeriesLayout>[];
  for (var i = 0; i < series.length; i++) {
    laid.add(
      SlopeSeriesLayout(
        index: i,
        series: series[i],
        points: [
          for (var p = 0; p < periods; p++)
            plotted[i][p] == null || columns[p] > shown + 0.001
                ? null
                : Offset(columns[p], yOf(plotted[i][p]!)),
        ],
      ),
    );
  }

  return SlopeLayout(
    size: size,
    plotRect: plot,
    series: laid,
    columnX: columns,
    min: low,
    max: high,
  );
}

/// How things moved between periods — a slope chart, or a bump chart.
///
/// Two periods and it is a slope chart: one line each, and what matters is
/// which way they lean. More periods on [SlopeScale.rank] and it is a bump
/// chart: places changing hands, which is far easier to follow than the same
/// lines crossing on a value scale.
///
/// ```dart
/// SlopeChart(
///   periodLabels: const ['Q1', 'Q2', 'Q3'],
///   scale: SlopeScale.rank,
///   series: const [
///     SlopeSeries(label: 'BTC', values: [4.2, 19.0, 11.5]),
///     SlopeSeries(label: 'ETH', values: [12.1, 8.4, 2.0]),
///     SlopeSeries(label: 'SOL', values: [9.7, 1.2, 6.3]),
///   ],
/// );
/// ```
class SlopeChart extends StatefulWidget {
  /// Creates a slope or bump chart of [series].
  const SlopeChart({
    super.key,
    required this.series,
    this.periodLabels = const [],
    this.periods,
    this.scale = SlopeScale.value,
    this.ascending = false,
    this.min,
    this.max,
    this.palette = defaultPalette,
    this.lineWidth = 2,
    this.dotRadius = 4,
    this.curved = true,
    this.labelWidth = 72,
    this.showLabels = true,
    this.labelStyle,
    this.showValues = true,
    this.valueFormatter,
    this.headerHeight = 20,
    this.headerStyle,
    this.columnColor = const Color(0x18909196),
    this.fadeUntouched = true,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.animationDuration = Duration.zero,
    this.animationCurve = Curves.easeOutCubic,
    this.animateOnMount = true,
    this.onSeriesTap,
    this.tooltipBuilder,
    this.defaultHeight = 260,
    this.semanticLabel,
  });

  /// The lines, in the order they were given.
  final List<SlopeSeries> series;

  /// What each period is called, written across the top.
  final List<String> periodLabels;

  /// How many periods there are; null takes the longest series, or the number
  /// of [periodLabels], whichever is larger.
  final int? periods;

  /// Whether the lines are placed by value or by rank.
  final SlopeScale scale;

  /// Whether rank 1 is the smallest value rather than the largest.
  final bool ascending;

  /// The value at the top of the plot; null works it out.
  final double? min;

  /// The one at the bottom; null works it out.
  final double? max;

  /// Colours handed to series that name none, in order.
  final List<Color> palette;

  /// The colours used where a series names none.
  static const defaultPalette = [
    Color(0xFF4C86CD),
    Color(0xFF2F9E44),
    Color(0xFFE8590C),
    Color(0xFF9C36B5),
    Color(0xFF0CA678),
    Color(0xFFE03131),
    Color(0xFFF59F00),
    Color(0xFF4263EB),
  ];

  /// How thick the lines are.
  final double lineWidth;

  /// How large the dot at each period is; 0 draws none.
  final double dotRadius;

  /// Whether the lines are eased between periods rather than straight.
  final bool curved;

  /// How wide the label columns either side are.
  final double labelWidth;

  /// Whether the series are labelled at both ends of their lines.
  final bool showLabels;

  /// Style of those labels.
  final TextStyle? labelStyle;

  /// Whether a series' value is written after its label at the ends.
  final bool showValues;

  /// Writes a value; null writes it with as few decimals as it needs, and a
  /// rank as `#1`.
  final String Function(double value)? valueFormatter;

  /// How much room the period labels take across the top.
  final double headerHeight;

  /// Style of the period labels.
  final TextStyle? headerStyle;

  /// The vertical line under each period.
  final Color columnColor;

  /// Whether the other lines fade while one is touched.
  final bool fadeUntouched;

  /// Space kept clear around the chart.
  final EdgeInsets padding;

  /// Painted behind the whole chart.
  final Color? backgroundColor;

  /// How long the lines take to draw in; zero draws them at once.
  final Duration animationDuration;

  /// The easing of [animationDuration].
  final Curve animationCurve;

  /// Whether the first build draws the lines in.
  final bool animateOnMount;

  /// Called with a series when it is touched, and with null when the touch
  /// leaves the lines.
  final void Function(SlopeSeries? series)? onSeriesTap;

  /// Builds the card shown over a touched series; null shows its label and
  /// the value at the period nearest the finger.
  final Widget Function(BuildContext context, SlopeSeries series, int period)?
      tooltipBuilder;

  /// How tall the chart is in a box that sets no height.
  final double defaultHeight;

  /// What a screen reader announces for the chart.
  final String? semanticLabel;

  /// How many periods the chart actually draws.
  int get resolvedPeriods {
    final given = periods;
    if (given != null) return math.max(0, given);
    var longest = periodLabels.length;
    for (final one in series) {
      longest = math.max(longest, one.values.length);
    }
    return longest;
  }

  @override
  State<SlopeChart> createState() => _SlopeChartState();
}

class _SlopeChartState extends State<SlopeChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 256);
  SlopeLayout _layout = SlopeLayout.empty;
  int? _touched;
  int _period = 0;

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
  void didUpdateWidget(SlopeChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
    if (!identical(oldWidget.series, widget.series) &&
        widget.animationDuration > Duration.zero) {
      _animation.forward(from: 0);
    }
    if (_touched != null && _touched! >= widget.series.length) _touched = null;
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  void _touch(Offset point) {
    final found = _layout.seriesAt(point);
    final period = _layout.columnAt(point.dx);
    if (found?.index == _touched && period == _period) return;
    setState(() {
      _touched = found?.index;
      _period = period;
    });
    widget.onSeriesTap?.call(found?.series);
  }

  void _clear() {
    if (_touched == null) return;
    setState(() => _touched = null);
    widget.onSeriesTap?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.animationCurve.transform(_animation.value);

    return Semantics(
      container: true,
      label: widget.semanticLabel,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width =
              constraints.hasBoundedWidth ? constraints.maxWidth : 420.0;
          final height = constraints.hasBoundedHeight &&
                  constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : widget.defaultHeight;
          _layout = layOutSlope(
            widget.series,
            size: Size(width, height),
            periods: widget.resolvedPeriods,
            scale: widget.scale,
            ascending: widget.ascending,
            labelWidth: widget.showLabels ? widget.labelWidth : 0,
            headerHeight: widget.periodLabels.isEmpty ? 0 : widget.headerHeight,
            min: widget.min,
            max: widget.max,
            padding: widget.padding,
            progress: progress,
          );

          final touched = _touched;
          return SizedBox(
            width: width,
            height: height,
            child: Listener(
              onPointerDown: (event) => _touch(event.localPosition),
              onPointerMove: (event) => _touch(event.localPosition),
              onPointerUp: (_) => _clear(),
              onPointerCancel: (_) => _clear(),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: SlopeChartPainter(
                        chart: widget,
                        layout: _layout,
                        touched: touched,
                        textCache: _text,
                      ),
                    ),
                  ),
                  if (touched != null && touched < widget.series.length)
                    _tooltip(context, touched),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tooltip(BuildContext context, int index) {
    final series = widget.series[index];
    final laid = _layout.series[index];
    final period =
        _period.clamp(0, math.max(0, laid.points.length - 1)).toInt();
    final at = laid.points[period] ?? laid.lastPoint ?? _layout.plotRect.center;
    final build = widget.tooltipBuilder;
    final value =
        period < series.values.length ? series.values[period] : null;
    final child = build != null
        ? build(context, series, period)
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xEE1B1D22),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              series.tooltip ??
                  '${series.label}  ${value == null ? '—' : _number(widget, value)}',
              style: const TextStyle(color: Color(0xFFE9ECEF), fontSize: 11),
            ),
          );
    return Positioned(
      left: math.max(0, at.dx - 20),
      top: math.max(0, at.dy - 28),
      child: IgnorePointer(child: child),
    );
  }
}

String _number(SlopeChart chart, double value) {
  final format = chart.valueFormatter;
  if (format != null) return format(value);
  if (!value.isFinite) return '';
  if (value == value.roundToDouble() && value.abs() < 1e15) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2);
}

/// Paints a [SlopeChart]: the period columns, the lines, their dots and the
/// labels at both ends.
class SlopeChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [layout].
  SlopeChartPainter({
    required this.chart,
    required this.layout,
    required this.touched,
    required this.textCache,
  });

  final SlopeChart chart;
  final SlopeLayout layout;

  /// The series under the finger, into [SlopeChart.series]; null when none is.
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
    final headerStyle = chart.headerStyle ??
        const TextStyle(color: Color(0xFF909196), fontSize: 11);

    // The period columns, and their names over them.
    final column = Paint()
      ..color = chart.columnColor
      ..strokeWidth = 1;
    for (var p = 0; p < layout.columnX.length; p++) {
      final x = layout.columnX[p];
      canvas.drawLine(
        Offset(x, layout.plotRect.top),
        Offset(x, layout.plotRect.bottom),
        column,
      );
      if (p < chart.periodLabels.length && chart.headerHeight > 0) {
        final painter = textCache.get(chart.periodLabels[p], headerStyle);
        painter.paint(
          canvas,
          Offset(
            (x - painter.width / 2)
                .clamp(0.0, math.max(0.0, size.width - painter.width)),
            math.max(0, layout.plotRect.top - painter.height - 4),
          ),
        );
      }
    }

    for (final laid in layout.series) {
      final base = laid.series.color ??
          chart.palette[laid.index % math.max(1, chart.palette.length)];
      final dimmed = touched != null && chart.fadeUntouched && touched != laid.index;
      final color = dimmed
          ? Color.lerp(base, const Color(0x00000000), 0.7) ?? base
          : base;

      final path = Path();
      var open = false;
      Offset? previous;
      for (final at in laid.points) {
        if (at == null) {
          open = false;
          previous = null;
          continue;
        }
        if (!open) {
          path.moveTo(at.dx, at.dy);
          open = true;
        } else if (chart.curved && previous != null) {
          // Horizontal control points: the line leaves and arrives level, so
          // crossings read as a swap rather than a corner.
          final midX = (previous.dx + at.dx) / 2;
          path.cubicTo(midX, previous.dy, midX, at.dy, at.dx, at.dy);
        } else {
          path.lineTo(at.dx, at.dy);
        }
        previous = at;
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = touched == laid.index
              ? chart.lineWidth + 1
              : chart.lineWidth
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );

      if (chart.dotRadius > 0) {
        for (final at in laid.points) {
          if (at == null) continue;
          canvas.drawCircle(at, chart.dotRadius, Paint()..color = color);
        }
      }

      if (chart.showLabels && chart.labelWidth > 0) {
        final style = labelStyle.copyWith(color: color);
        final first = laid.firstPoint;
        final last = laid.lastPoint;
        if (first != null) {
          final painter =
              textCache.get(_endLabel(laid, first: true), style);
          painter.paint(
            canvas,
            Offset(
              math.max(0, first.dx - chart.dotRadius - 6 - painter.width),
              first.dy - painter.height / 2,
            ),
          );
        }
        if (last != null && layout.columnX.length > 1) {
          final painter =
              textCache.get(_endLabel(laid, first: false), style);
          painter.paint(
            canvas,
            Offset(
              math.min(
                last.dx + chart.dotRadius + 6,
                math.max(0.0, size.width - painter.width),
              ),
              last.dy - painter.height / 2,
            ),
          );
        }
      }
    }
  }

  String _endLabel(SlopeSeriesLayout laid, {required bool first}) {
    final label = laid.series.label;
    if (!chart.showValues) return label;
    final values = laid.series.values;
    double? value;
    if (first) {
      for (final one in values) {
        if (one != null && one.isFinite) {
          value = one;
          break;
        }
      }
    } else {
      for (final one in values.reversed) {
        if (one != null && one.isFinite) {
          value = one;
          break;
        }
      }
    }
    if (value == null) return label;
    return '$label  ${_number(chart, value)}';
  }

  @override
  bool shouldRepaint(SlopeChartPainter old) =>
      old.chart != chart || old.layout != layout || old.touched != touched;
}
