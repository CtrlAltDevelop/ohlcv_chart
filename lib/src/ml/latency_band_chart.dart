import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../utils/plot_scaffold.dart';
import '../utils/xy_plot.dart';

/// Latency over one interval: the median and the tail percentiles.
@immutable
class LatencySample {
  /// Creates a sample at [time] with the given latencies, in one unit.
  const LatencySample({
    required this.time,
    required this.p50,
    required this.p95,
    required this.p99,
    this.data,
  });

  /// When the interval began.
  final DateTime time;

  /// The median latency.
  final double p50;

  /// The 95th percentile.
  final double p95;

  /// The 99th percentile.
  final double p99;

  /// Anything the app wants back when this sample is touched.
  final Object? data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LatencySample &&
          other.time == time &&
          other.p50 == p50 &&
          other.p95 == p95 &&
          other.p99 == p99 &&
          other.data == data;

  @override
  int get hashCode => Object.hash(time, p50, p95, p99, data);
}

/// Which percentile an SLO is set on.
enum LatencyPercentile {
  /// The median.
  p50,

  /// The 95th percentile.
  p95,

  /// The 99th percentile.
  p99,
}

double _valueOf(LatencySample s, LatencyPercentile p) => switch (p) {
  LatencyPercentile.p50 => s.p50,
  LatencyPercentile.p95 => s.p95,
  LatencyPercentile.p99 => s.p99,
};

/// The indices of the samples that broke an objective: those whose [percentile]
/// was over [slo]. A sample whose value is not finite is not a breach.
List<int> sloBreaches(
  List<LatencySample> samples,
  double slo, {
  LatencyPercentile percentile = LatencyPercentile.p95,
}) => [
  for (var i = 0; i < samples.length; i++)
    if (_valueOf(samples[i], percentile).isFinite &&
        _valueOf(samples[i], percentile) > slo)
      i,
];

/// What a touch on a [LatencyBandChart] landed on.
@immutable
class LatencyTouchDetails {
  /// Creates the details of a touch on the sample at [index].
  const LatencyTouchDetails({
    required this.index,
    required this.sample,
    required this.breached,
  });

  /// The sample's position.
  final int index;

  /// The sample.
  final LatencySample sample;

  /// Whether it broke the chart's objective.
  final bool breached;
}

/// Latency over time as bands: the median as a line, the span up to the 95th
/// percentile and on to the 99th shaded, and an objective drawn across with
/// the intervals that broke it marked.
///
/// ```dart
/// LatencyBandChart(
///   samples: [
///     for (final w in windows)
///       LatencySample(time: w.start, p50: w.p50, p95: w.p95, p99: w.p99),
///   ],
///   slo: 1200,
///   valueFormatter: (ms) => '${ms.round()} ms',
/// );
/// ```
///
/// The chart fills the box it is given, and is [defaultHeight] high in a box
/// with no height of its own.
class LatencyBandChart extends StatelessWidget {
  /// Creates a chart of [samples], in time order.
  const LatencyBandChart({
    super.key,
    required this.samples,
    this.slo,
    this.sloPercentile = LatencyPercentile.p95,
    this.logY = false,
    this.medianColor = const Color(0xFF4C86CD),
    this.p95Color = const Color(0xFF4C86CD),
    this.p99Color = const Color(0xFF4C86CD),
    this.sloColor = const Color(0xFFF2B01E),
    this.breachColor = const Color(0xFFE03131),
    this.showBreaches = true,
    this.lineWidth = 2,
    this.showLegend = true,
    this.legendStyle,
    this.showAxes = true,
    this.axisWidth = 52,
    this.axisHeight = 18,
    this.tickCount = 5,
    this.valueFormatter,
    this.timeFormatter,
    this.axisLabelStyle,
    this.yAxisTitle,
    this.axisTitleStyle,
    this.gridColor = const Color(0x22FFFFFF),
    this.crosshairColor = const Color(0x66FFFFFF),
    this.onTouch,
    this.tooltipBuilder,
    this.tooltipMargin = 12,
    this.animationDuration = Duration.zero,
    this.animationCurve = Curves.easeOutCubic,
    this.animateOnMount = true,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.defaultHeight = 260,
    this.semanticLabel,
  });

  /// The samples, in time order.
  final List<LatencySample> samples;

  /// The objective, in the samples' unit; null draws none.
  final double? slo;

  /// Which percentile the objective is set on.
  final LatencyPercentile sloPercentile;

  /// Whether the latency axis is logarithmic, for a tail that runs far above
  /// the median.
  final bool logY;

  /// The colour of the median line and the band round it.
  final Color medianColor;

  /// The colour of the 95th-percentile line.
  final Color p95Color;

  /// The colour of the 99th-percentile band.
  final Color p99Color;

  /// The colour of the objective line.
  final Color sloColor;

  /// The colour of the intervals that broke the objective.
  final Color breachColor;

  /// Whether the intervals over the objective are marked.
  final bool showBreaches;

  /// How thick the median line is.
  final double lineWidth;

  /// Whether the percentiles are named in the corner.
  final bool showLegend;

  /// Style of the legend.
  final TextStyle? legendStyle;

  /// Whether the two axes are drawn.
  final bool showAxes;

  /// How much room the latency axis takes.
  final double axisWidth;

  /// How much room the time axis takes.
  final double axisHeight;

  /// About how many ticks to write on the latency axis.
  final int tickCount;

  /// Writes a latency; null writes at most two decimals.
  final String Function(double value)? valueFormatter;

  /// Writes a time on the axis; null writes `HH:mm`, or `MMM d` over a span of
  /// days.
  final String Function(DateTime time)? timeFormatter;

  /// Style of an axis label.
  final TextStyle? axisLabelStyle;

  /// Written up the latency axis.
  final String? yAxisTitle;

  /// Style of an axis title.
  final TextStyle? axisTitleStyle;

  /// Colour of the grid ruled at each tick; null rules none.
  final Color? gridColor;

  /// The colour of the line under the pointer.
  final Color crosshairColor;

  /// Called as a touch moves along the time axis, and with null when it leaves.
  final ValueChanged<LatencyTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched sample; null shows none.
  final Widget? Function(BuildContext context, LatencyTouchDetails details)?
  tooltipBuilder;

  /// How far the card sits from the crosshair.
  final double tooltipMargin;

  /// How long the bands take to draw in; zero draws them at once.
  final Duration animationDuration;

  /// The easing of [animationDuration].
  final Curve animationCurve;

  /// Whether the first build animates.
  final bool animateOnMount;

  /// Space kept clear around the chart.
  final EdgeInsets padding;

  /// Painted behind the whole chart.
  final Color? backgroundColor;

  /// The height taken in a box that sets none.
  final double defaultHeight;

  /// What a screen reader announces for the chart.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final usable = [
      for (var i = 0; i < samples.length; i++)
        if (samples[i].p50.isFinite &&
            samples[i].p95.isFinite &&
            samples[i].p99.isFinite &&
            (!logY || samples[i].p50 > 0))
          i,
    ];
    final breaches = slo == null
        ? const <int>[]
        : sloBreaches(samples, slo!, percentile: sloPercentile);

    double? minT, maxT;
    final values = <double>[];
    for (final i in usable) {
      final ms = samples[i].time.millisecondsSinceEpoch.toDouble();
      minT = minT == null ? ms : math.min(minT, ms);
      maxT = maxT == null ? ms : math.max(maxT, ms);
      values
        ..add(samples[i].p50)
        ..add(samples[i].p95)
        ..add(samples[i].p99);
    }
    if (slo != null && slo!.isFinite && (!logY || slo! > 0)) values.add(slo!);
    var t0 = minT ?? 0;
    var t1 = maxT ?? 1;
    if (t0 == t1) t1 = t0 + 1;

    double lo;
    double hi;
    if (values.isEmpty) {
      lo = logY ? 1 : 0;
      hi = logY ? 100 : 1;
    } else if (logY) {
      lo = values.where((v) => v > 0).fold(double.infinity, math.min);
      hi = values.fold(0.0, math.max);
      if (!lo.isFinite || lo >= hi) {
        lo = hi / 10;
      }
      lo /= 1.3;
      hi *= 1.3;
    } else {
      lo = 0;
      hi = values.reduce(math.max) * 1.1;
      if (hi <= 0) hi = 1;
    }

    Offset at(Rect plot, DateTime time, double v) {
      final x = mapAcross(
        time.millisecondsSinceEpoch.toDouble(),
        t0,
        t1,
        plot.left,
        plot.right,
      );
      final y = logY
          ? mapAcrossLog(v, lo, hi, plot.bottom, plot.top) ?? double.nan
          : mapAcross(v, lo, hi, plot.bottom, plot.top);
      return Offset(x, y);
    }

    LatencyTouchDetails? hit(Offset local, Rect plot) {
      if (!plot.inflate(2).contains(local) || usable.isEmpty) return null;
      int? best;
      var closest = double.infinity;
      for (final i in usable) {
        final x = at(plot, samples[i].time, samples[i].p50).dx;
        final d = (x - local.dx).abs();
        if (d < closest) {
          closest = d;
          best = i;
        }
      }
      if (best == null) return null;
      return LatencyTouchDetails(
        index: best,
        sample: samples[best],
        breached: breaches.contains(best),
      );
    }

    final span = Duration(milliseconds: (t1 - t0).round());
    String formatTime(DateTime time) {
      if (timeFormatter != null) return timeFormatter!(time);
      String two(int n) => n.toString().padLeft(2, '0');
      if (span >= const Duration(days: 2)) {
        const months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
        ];
        return '${months[time.month - 1]} ${time.day}';
      }
      return '${two(time.hour)}:${two(time.minute)}';
    }

    return PlotScaffold<LatencyTouchDetails>(
      restartKey: Object.hashAll([...samples, slo, logY]),
      insets: EdgeInsets.fromLTRB(
        showAxes ? axisWidth : 0,
        0,
        0,
        showAxes ? axisHeight : 0,
      ),
      padding: padding,
      backgroundColor: backgroundColor,
      defaultHeight: defaultHeight,
      animationDuration: animationDuration,
      animationCurve: animationCurve,
      animateOnMount: animateOnMount,
      semanticLabel: semanticLabel,
      tooltipMargin: tooltipMargin,
      onTouch: onTouch,
      tooltipBuilder: tooltipBuilder,
      hitTest: hit,
      keyOf: (d) => d.index,
      anchorOf: (d, plot) {
        final x = at(plot, d.sample.time, d.sample.p50).dx;
        return Rect.fromLTRB(x - 1, plot.top, x + 1, plot.bottom);
      },
      painter: (plot, t, text, hovered) => _LatencyPainter(
        chart: this,
        usable: usable,
        breaches: breaches.toSet(),
        project: (time, v) => at(plot, time, v),
        timeAt: (f) =>
            DateTime.fromMillisecondsSinceEpoch((t0 + (t1 - t0) * f).round()),
        formatTime: formatTime,
        lo: lo,
        hi: hi,
        hovered: hovered?.index,
        plot: plot,
        animation: t,
        text: text,
        backgroundColor: backgroundColor,
      ),
    );
  }
}

class _LatencyPainter extends PlotPainter {
  _LatencyPainter({
    required this.chart,
    required this.usable,
    required this.breaches,
    required this.project,
    required this.timeAt,
    required this.formatTime,
    required this.lo,
    required this.hi,
    required this.hovered,
    required super.plot,
    required super.animation,
    required super.text,
    super.backgroundColor,
  });

  final LatencyBandChart chart;
  final List<int> usable;
  final Set<int> breaches;
  final Offset Function(DateTime time, double value) project;
  final DateTime Function(double fraction) timeAt;
  final String Function(DateTime time) formatTime;
  final double lo, hi;
  final int? hovered;

  @override
  void paintPlot(Canvas canvas, Size size) {
    paintXyAxes(
      canvas,
      text,
      plot: plot,
      // The time axis is labelled by hand below, from the formatter.
      minX: 0,
      maxX: 1,
      minY: lo,
      maxY: hi,
      tickCount: chart.tickCount,
      gridColor: chart.gridColor,
      showAxes: chart.showAxes,
      xLabels: const [],
      yFormatter: chart.valueFormatter,
      labelStyle: chart.axisLabelStyle,
      yTitle: chart.yAxisTitle,
      titleStyle: chart.axisTitleStyle,
      axisWidth: chart.axisWidth,
      axisHeight: chart.axisHeight,
      logY: chart.logY,
    );
    _timeAxis(canvas);

    final t = animation.clamp(0.0, 1.0);
    if (usable.isEmpty) return;
    canvas
      ..save()
      ..clipRect(
        Rect.fromLTRB(
          plot.left,
          plot.top,
          plot.left + plot.width * t + 1,
          plot.bottom,
        ),
      );

    List<Offset> line(double Function(LatencySample s) of) => [
      for (final i in usable)
        project(chart.samples[i].time, of(chart.samples[i])),
    ];
    final p50 = line((s) => s.p50);
    final p95 = line((s) => s.p95);
    final p99 = line((s) => s.p99);

    void band(List<Offset> upper, List<Offset> lower, Color color) {
      final points = [...upper, ...lower.reversed];
      if (points.length < 3 ||
          points.any((o) => !o.dx.isFinite || !o.dy.isFinite)) {
        return;
      }
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final o in points.skip(1)) {
        path.lineTo(o.dx, o.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = color);
    }

    band(p99, p95, chart.p99Color.withValues(alpha: 0.12));
    band(p95, p50, chart.p95Color.withValues(alpha: 0.22));

    void stroke(List<Offset> points, Color color, double width) {
      final clean = points
          .where((o) => o.dx.isFinite && o.dy.isFinite)
          .toList();
      if (clean.length < 2) return;
      final path = Path()..moveTo(clean.first.dx, clean.first.dy);
      for (final o in clean.skip(1)) {
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeJoin = StrokeJoin.round
          ..color = color
          ..isAntiAlias = true,
      );
    }

    stroke(p99, chart.p99Color.withValues(alpha: 0.5), 1);
    stroke(p95, chart.p95Color.withValues(alpha: 0.8), 1.2);
    stroke(p50, chart.medianColor, chart.lineWidth);
    canvas.restore();

    _paintSlo(canvas);
    _paintHover(canvas);
    _paintLegend(canvas);
  }

  void _timeAxis(Canvas canvas) {
    if (!chart.showAxes || usable.isEmpty) return;
    final style = const TextStyle(
      fontSize: 10,
      color: Color(0xFF8B95A1),
    ).merge(chart.axisLabelStyle);
    const count = 5;
    var written = -double.infinity;
    for (var i = 0; i < count; i++) {
      final f = i / (count - 1);
      final label = text.get(formatTime(timeAt(f)), style);
      final x = plot.left + plot.width * f;
      var left = x - label.width / 2;
      left = left.clamp(
        plot.left - 4,
        math.max(plot.left, plot.right - label.width),
      );
      if (left < written) continue;
      label.paint(canvas, Offset(left, plot.bottom + 3));
      written = left + label.width + 6;
    }
  }

  void _paintSlo(Canvas canvas) {
    final slo = chart.slo;
    if (slo == null || !slo.isFinite || (chart.logY && slo <= 0)) return;
    final y = project(chart.samples[usable.first].time, slo).dy;
    if (!y.isFinite || y < plot.top || y > plot.bottom) return;
    final pen = Paint()
      ..color = chart.sloColor
      ..strokeWidth = 1.2;
    for (var x = plot.left; x < plot.right; x += 9) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + 5, plot.right), y),
        pen,
      );
    }
    if (chart.showBreaches) {
      for (final i in breaches) {
        if (!usable.contains(i)) continue;
        final x = project(chart.samples[i].time, slo).dx;
        canvas.drawRect(
          Rect.fromLTWH(x - 1.5, plot.bottom - 5, 3, 5),
          Paint()..color = chart.breachColor,
        );
      }
    }
  }

  void _paintHover(Canvas canvas) {
    final i = hovered;
    if (i == null || i >= chart.samples.length) return;
    final s = chart.samples[i];
    final x = project(s.time, s.p50).dx;
    canvas.drawLine(
      Offset(x, plot.top),
      Offset(x, plot.bottom),
      Paint()
        ..color = chart.crosshairColor
        ..strokeWidth = 1,
    );
    for (final (v, color) in [
      (s.p50, chart.medianColor),
      (s.p95, chart.p95Color),
      (s.p99, chart.p99Color),
    ]) {
      final o = project(s.time, v);
      if (!o.dx.isFinite || !o.dy.isFinite) continue;
      canvas.drawCircle(
        o,
        3.5,
        Paint()
          ..color = color
          ..isAntiAlias = true,
      );
    }
  }

  void _paintLegend(Canvas canvas) {
    if (!chart.showLegend) return;
    final style = const TextStyle(
      fontSize: 10,
      color: Color(0xCCFFFFFF),
    ).merge(chart.legendStyle);
    var top = plot.top + 4;
    for (final (name, color) in [
      ('p99', chart.p99Color.withValues(alpha: 0.6)),
      ('p95', chart.p95Color.withValues(alpha: 0.85)),
      ('p50', chart.medianColor),
    ]) {
      final tp = text.get(name, style);
      final left = plot.right - 8 - tp.width;
      canvas.drawLine(
        Offset(left - 20, top + tp.height / 2),
        Offset(left - 6, top + tp.height / 2),
        Paint()
          ..color = color
          ..strokeWidth = 2,
      );
      tp.paint(canvas, Offset(left, top));
      top += tp.height + 3;
    }
  }
}
