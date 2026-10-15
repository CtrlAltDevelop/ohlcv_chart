import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../utils/plot_scaffold.dart';
import '../utils/xy_plot.dart';

/// One trained model on a scaling plot: how much it was given, and the loss it
/// reached.
@immutable
class ScalingPoint {
  /// Creates a model that reached [loss] with [scale] of whatever the x axis
  /// counts — parameters, training tokens, FLOPs.
  const ScalingPoint({
    required this.scale,
    required this.loss,
    this.label,
    this.color,
    this.data,
  });

  /// The amount of compute, data or parameters; positive.
  final double scale;

  /// The loss, or any other error measure; positive.
  final double loss;

  /// What the model is called.
  final String? label;

  /// A colour of this point's own.
  final Color? color;

  /// Anything the app wants back when this point is touched.
  final Object? data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScalingPoint &&
          other.scale == scale &&
          other.loss == loss &&
          other.label == label &&
          other.color == color &&
          other.data == data;

  @override
  int get hashCode => Object.hash(scale, loss, label, color, data);
}

/// A power law `loss = coefficient × scale ^ exponent`, fitted to points.
@immutable
class PowerLawFit {
  /// Creates a fit from its parts; see [fitPowerLaw].
  const PowerLawFit({
    required this.coefficient,
    required this.exponent,
    required this.rSquared,
    required this.logResidual,
    required this.count,
  });

  /// The loss at a scale of 1.
  final double coefficient;

  /// The slope on a log-log plot; negative when more scale lowers the loss.
  final double exponent;

  /// How much of the variation in log loss the line explains, from 0 to 1.
  final double rSquared;

  /// The standard deviation of the points' distance from the line in log10 of
  /// the loss: 0.05 is points typically within 12% of the fit.
  final double logResidual;

  /// How many points were fitted.
  final int count;

  /// The loss the fit predicts at [scale].
  double predict(double scale) =>
      coefficient * math.pow(scale, exponent).toDouble();

  /// The scale at which the fit predicts [loss]; null when the line is flat or
  /// the loss is not a positive number.
  double? scaleFor(double loss) {
    if (!loss.isFinite || loss <= 0 || exponent == 0 || coefficient <= 0) {
      return null;
    }
    final scale = math.pow(loss / coefficient, 1 / exponent).toDouble();
    return scale.isFinite && scale > 0 ? scale : null;
  }
}

/// Fits a power law to [points] by least squares on their logarithms.
///
/// A point whose scale or loss is not a positive finite number is skipped. Null
/// when fewer than two points remain, or they all share one scale.
PowerLawFit? fitPowerLaw(Iterable<ScalingPoint> points) {
  final xs = <double>[];
  final ys = <double>[];
  for (final p in points) {
    final x = log10OrNull(p.scale);
    final y = log10OrNull(p.loss);
    if (x == null || y == null) continue;
    xs.add(x);
    ys.add(y);
  }
  final n = xs.length;
  if (n < 2) return null;

  final meanX = xs.reduce((a, b) => a + b) / n;
  final meanY = ys.reduce((a, b) => a + b) / n;
  var sxx = 0.0;
  var sxy = 0.0;
  var syy = 0.0;
  for (var i = 0; i < n; i++) {
    final dx = xs[i] - meanX;
    final dy = ys[i] - meanY;
    sxx += dx * dx;
    sxy += dx * dy;
    syy += dy * dy;
  }
  if (sxx <= 0) return null;

  final slope = sxy / sxx;
  final intercept = meanY - slope * meanX;
  var residuals = 0.0;
  for (var i = 0; i < n; i++) {
    final e = ys[i] - (intercept + slope * xs[i]);
    residuals += e * e;
  }
  return PowerLawFit(
    coefficient: math.pow(10.0, intercept).toDouble(),
    exponent: slope,
    rSquared: syy <= 0 ? 1 : (1 - residuals / syy).clamp(0.0, 1.0),
    logResidual: n > 2 ? math.sqrt(residuals / (n - 2)) : 0,
    count: n,
  );
}

/// What a touch on a [ScalingLawChart] landed on.
@immutable
class ScalingTouchDetails {
  /// Creates the details of a touch on the point at [index].
  const ScalingTouchDetails({
    required this.index,
    required this.point,
    required this.predicted,
  });

  /// The point's position in the chart's points.
  final int index;

  /// The point touched.
  final ScalingPoint point;

  /// What the fit predicts at its scale; null with no fit.
  final double? predicted;

  /// How far above the fit the point sits, as a ratio: 1.1 is 10% worse than
  /// predicted. Null with no fit.
  double? get ratio {
    final p = predicted;
    return p == null || p <= 0 ? null : point.loss / p;
  }
}

/// Loss against scale on log-log axes, with the power law through them and its
/// extrapolation — a scaling-law plot.
///
/// ```dart
/// ScalingLawChart(
///   points: [
///     for (final m in runs) ScalingPoint(scale: m.flops, loss: m.loss),
///   ],
///   extrapolateTo: 1e24,
///   targetLoss: 1.8,
/// );
/// ```
///
/// The fit is drawn solid over the range of the points and dashed beyond it,
/// with a band one residual standard deviation either side. [targetLoss] marks
/// where the line is predicted to reach a loss. The chart fills the box it is
/// given, and is [defaultHeight] high in a box with no height of its own.
class ScalingLawChart extends StatelessWidget {
  /// Creates a chart of [points].
  const ScalingLawChart({
    super.key,
    required this.points,
    this.fitFrom,
    this.extrapolateTo,
    this.showFit = true,
    this.showBand = true,
    this.targetLoss,
    this.pointColor = const Color(0xFF4C86CD),
    this.fitColor = const Color(0xFFF2B01E),
    this.bandColor = const Color(0x22F2B01E),
    this.targetColor = const Color(0xFF2F9E44),
    this.dotRadius = 5,
    this.showLabels = true,
    this.labelStyle,
    this.showFitLabel = true,
    this.showAxes = true,
    this.axisWidth = 48,
    this.axisHeight = 18,
    this.tickCount = 5,
    this.scaleFormatter,
    this.lossFormatter,
    this.axisLabelStyle,
    this.xAxisTitle = 'Compute',
    this.yAxisTitle = 'Loss',
    this.axisTitleStyle,
    this.gridColor = const Color(0x22FFFFFF),
    this.onTouch,
    this.tooltipBuilder,
    this.tooltipMargin = 10,
    this.animationDuration = Duration.zero,
    this.animationCurve = Curves.easeOutCubic,
    this.animateOnMount = true,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.defaultHeight = 280,
    this.semanticLabel,
  });

  /// The models.
  final List<ScalingPoint> points;

  /// Fit only the points at or above this scale, to leave out the small models
  /// that sit off the law; null fits them all.
  final double? fitFrom;

  /// How far to carry the fit to the right, as a scale; null stops at the
  /// largest point.
  final double? extrapolateTo;

  /// Whether the fitted line is drawn.
  final bool showFit;

  /// Whether the band round the fit is drawn.
  final bool showBand;

  /// A loss to mark on the fit: where the line is predicted to reach it.
  final double? targetLoss;

  /// The colour of a point.
  final Color pointColor;

  /// The colour of the fit.
  final Color fitColor;

  /// The colour of the band.
  final Color bandColor;

  /// The colour of the target marker.
  final Color targetColor;

  /// The radius of a point.
  final double dotRadius;

  /// Whether each point's label is written beside it.
  final bool showLabels;

  /// Style of a point's label.
  final TextStyle? labelStyle;

  /// Whether the fitted law is written in the corner.
  final bool showFitLabel;

  /// Whether the two axes are drawn.
  final bool showAxes;

  /// How much room the loss axis takes.
  final double axisWidth;

  /// How much room the scale axis takes.
  final double axisHeight;

  /// About how many ticks to write on each axis.
  final int tickCount;

  /// Writes a scale; null writes it in scientific form.
  final String Function(double value)? scaleFormatter;

  /// Writes a loss; null writes at most two decimals.
  final String Function(double value)? lossFormatter;

  /// Style of an axis label.
  final TextStyle? axisLabelStyle;

  /// Written under the scale axis.
  final String? xAxisTitle;

  /// Written up the loss axis.
  final String? yAxisTitle;

  /// Style of an axis title.
  final TextStyle? axisTitleStyle;

  /// Colour of the grid ruled at each tick; null rules none.
  final Color? gridColor;

  /// Called as a touch moves over the points, and with null when it leaves.
  final ValueChanged<ScalingTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched point; null shows none.
  final Widget? Function(BuildContext context, ScalingTouchDetails details)?
  tooltipBuilder;

  /// How far the card sits from the point.
  final double tooltipMargin;

  /// How long the plot takes to draw in; zero draws it at once.
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

  /// The fit the chart draws, or null when there are too few points.
  PowerLawFit? get fit => fitPowerLaw(
    fitFrom == null
        ? points
        : [
            for (final p in points)
              if (p.scale >= fitFrom!) p,
          ],
  );

  static String _scientific(double v) {
    if (!v.isFinite || v <= 0) return '–';
    final exponent = (math.log(v) / math.ln10).floor();
    final mantissa = v / math.pow(10.0, exponent);
    final m = mantissa.toStringAsFixed(mantissa >= 9.95 ? 0 : 1);
    return m == '1.0' || m == '1' ? '1e$exponent' : '${m}e$exponent';
  }

  @override
  Widget build(BuildContext context) {
    final law = fit;
    final valid = [
      for (var i = 0; i < points.length; i++)
        if (log10OrNull(points[i].scale) != null &&
            log10OrNull(points[i].loss) != null)
          i,
    ];

    var minX = double.infinity;
    var maxX = 0.0;
    var minY = double.infinity;
    var maxY = 0.0;
    for (final i in valid) {
      minX = math.min(minX, points[i].scale);
      maxX = math.max(maxX, points[i].scale);
      minY = math.min(minY, points[i].loss);
      maxY = math.max(maxY, points[i].loss);
    }
    if (valid.isEmpty) {
      minX = 1;
      maxX = 100;
      minY = 1;
      maxY = 10;
    }
    final reach = extrapolateTo;
    if (reach != null && reach.isFinite && reach > maxX) maxX = reach;
    if (law != null && showFit) {
      for (final x in [minX, maxX]) {
        final y = law.predict(x);
        if (y.isFinite && y > 0) {
          minY = math.min(minY, y);
          maxY = math.max(maxY, y);
        }
      }
    }
    final target = targetLoss;
    if (target != null && target.isFinite && target > 0) {
      minY = math.min(minY, target);
      maxY = math.max(maxY, target);
    }
    if (minX == maxX) {
      minX /= 2;
      maxX *= 2;
    }
    if (minY == maxY) {
      minY /= 2;
      maxY *= 2;
    }
    // A little room, in the log: the extremes are not drawn on the frame.
    final xPad = math.pow(maxX / minX, 0.04).toDouble();
    final yPad = math.pow(maxY / minY, 0.1).toDouble();
    final x0 = minX / xPad, x1 = maxX * xPad;
    final y0 = minY / yPad, y1 = maxY * yPad;

    Offset? at(Rect plot, double scale, double loss) {
      final x = mapAcrossLog(scale, x0, x1, plot.left, plot.right);
      final y = mapAcrossLog(loss, y0, y1, plot.bottom, plot.top);
      if (x == null || y == null) return null;
      return Offset(x, y);
    }

    ScalingTouchDetails? hit(Offset local, Rect plot) {
      int? best;
      var closest = dotRadius + 8;
      for (final i in valid) {
        final o = at(plot, points[i].scale, points[i].loss);
        if (o == null) continue;
        final d = (o - local).distance;
        if (d <= closest) {
          closest = d;
          best = i;
        }
      }
      if (best == null) return null;
      return ScalingTouchDetails(
        index: best,
        point: points[best],
        predicted: law?.predict(points[best].scale),
      );
    }

    return PlotScaffold<ScalingTouchDetails>(
      restartKey: Object.hashAll([
        ...points,
        fitFrom,
        extrapolateTo,
        targetLoss,
      ]),
      insets: EdgeInsets.fromLTRB(
        showAxes ? axisWidth : 0,
        0,
        0,
        showAxes ? axisHeight + (xAxisTitle != null ? 14 : 0) : 0,
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
        final o = at(plot, d.point.scale, d.point.loss) ?? plot.center;
        return Rect.fromCircle(center: o, radius: dotRadius);
      },
      painter: (plot, t, text, hovered) => _ScalingPainter(
        chart: this,
        law: law,
        valid: valid,
        x0: x0,
        x1: x1,
        y0: y0,
        y1: y1,
        project: (s, l) => at(plot, s, l),
        hovered: hovered,
        plot: plot,
        animation: t,
        text: text,
        backgroundColor: backgroundColor,
      ),
    );
  }
}

class _ScalingPainter extends PlotPainter {
  _ScalingPainter({
    required this.chart,
    required this.law,
    required this.valid,
    required this.x0,
    required this.x1,
    required this.y0,
    required this.y1,
    required this.project,
    required this.hovered,
    required super.plot,
    required super.animation,
    required super.text,
    super.backgroundColor,
  });

  final ScalingLawChart chart;
  final PowerLawFit? law;
  final List<int> valid;
  final double x0, x1, y0, y1;
  final Offset? Function(double scale, double loss) project;
  final ScalingTouchDetails? hovered;

  @override
  void paintPlot(Canvas canvas, Size size) {
    paintXyAxes(
      canvas,
      text,
      plot: plot,
      minX: x0,
      maxX: x1,
      minY: y0,
      maxY: y1,
      tickCount: chart.tickCount,
      gridColor: chart.gridColor,
      showAxes: chart.showAxes,
      xFormatter: chart.scaleFormatter ?? ScalingLawChart._scientific,
      yFormatter: chart.lossFormatter,
      labelStyle: chart.axisLabelStyle,
      xTitle: chart.xAxisTitle,
      yTitle: chart.yAxisTitle,
      titleStyle: chart.axisTitleStyle,
      axisWidth: chart.axisWidth,
      axisHeight: chart.axisHeight,
      logX: true,
      logY: true,
    );

    final t = animation.clamp(0.0, 1.0);
    canvas
      ..save()
      ..clipRect(plot);
    _paintFit(canvas, t);
    _paintTarget(canvas);
    canvas.restore();
    _paintPoints(canvas, t);
    _paintFitLabel(canvas);
  }

  /// The fitted line from [from] to [to], as points a short way apart in log x.
  List<Offset> _line(double from, double to, double multiplier) {
    final fit = law;
    if (fit == null || from <= 0 || to <= from) return const [];
    const steps = 48;
    final out = <Offset>[];
    for (var i = 0; i <= steps; i++) {
      final x = from * math.pow(to / from, i / steps).toDouble();
      final o = project(x, fit.predict(x) * multiplier);
      if (o != null && o.dx.isFinite && o.dy.isFinite) out.add(o);
    }
    return out;
  }

  void _paintFit(Canvas canvas, double t) {
    final fit = law;
    if (fit == null || !chart.showFit || valid.isEmpty) return;
    var lo = double.infinity;
    var hi = 0.0;
    for (final i in valid) {
      lo = math.min(lo, chart.points[i].scale);
      hi = math.max(hi, chart.points[i].scale);
    }
    final end = chart.extrapolateTo != null && chart.extrapolateTo! > hi
        ? chart.extrapolateTo!
        : hi;
    final start = chart.fitFrom != null ? math.max(lo, chart.fitFrom!) : lo;

    if (chart.showBand && fit.logResidual > 0) {
      final up = math.pow(10.0, fit.logResidual).toDouble();
      final top = _line(start, end, up);
      final bottom = _line(start, end, 1 / up);
      if (top.length > 1 && bottom.length > 1) {
        final path = Path()..moveTo(top.first.dx, top.first.dy);
        for (final o in top.skip(1)) {
          path.lineTo(o.dx, o.dy);
        }
        for (final o in bottom.reversed) {
          path.lineTo(o.dx, o.dy);
        }
        path.close();
        canvas.drawPath(path, Paint()..color = chart.bandColor);
      }
    }

    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = chart.fitColor.withValues(alpha: t)
      ..isAntiAlias = true;
    // Solid across the data, dashed beyond it.
    final within = _line(start, hi, 1);
    if (within.length > 1) {
      final path = Path()..moveTo(within.first.dx, within.first.dy);
      for (final o in within.skip(1)) {
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, pen);
    }
    final beyond = _line(hi, end, 1);
    for (var i = 1; i < beyond.length; i += 2) {
      canvas.drawLine(beyond[i - 1], beyond[i], pen);
    }
  }

  void _paintTarget(Canvas canvas) {
    final target = chart.targetLoss;
    if (target == null || !target.isFinite || target <= 0) return;
    final left = project(x0, target);
    final right = project(x1, target);
    if (left == null || right == null) return;
    final pen = Paint()
      ..color = chart.targetColor.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(plot.left, left.dy),
      Offset(plot.right, left.dy),
      pen,
    );

    final reachAt = law?.scaleFor(target);
    if (reachAt == null) return;
    final o = project(reachAt, target);
    if (o == null || !plot.inflate(1).contains(o)) return;
    canvas.drawCircle(
      o,
      6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = chart.targetColor
        ..isAntiAlias = true,
    );
    final label = ScalingLawChart._scientific(reachAt);
    final tp = text.get(
      '$label at ${chart.lossFormatter?.call(target) ?? formatPlotNumber(target)}',
      TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: chart.targetColor,
      ),
    );
    var x = o.dx + 10;
    if (x + tp.width > plot.right) x = o.dx - 10 - tp.width;
    tp.paint(canvas, Offset(math.max(plot.left, x), o.dy - tp.height - 4));
  }

  void _paintPoints(Canvas canvas, double t) {
    for (final i in valid) {
      final p = chart.points[i];
      final o = project(p.scale, p.loss);
      if (o == null || !o.dx.isFinite || !o.dy.isFinite) continue;
      final color = p.color ?? chart.pointColor;
      canvas.drawCircle(
        o,
        chart.dotRadius * t,
        Paint()
          ..color = color
          ..isAntiAlias = true,
      );
      if (hovered?.index == i) {
        canvas.drawCircle(
          o,
          chart.dotRadius + 3,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0xCCFFFFFF)
            ..isAntiAlias = true,
        );
      }
      final name = p.label;
      if (chart.showLabels && name != null && name.isNotEmpty && t >= 1) {
        final tp = text.get(
          name,
          const TextStyle(
            fontSize: 10,
            color: Color(0xCCFFFFFF),
          ).merge(chart.labelStyle),
        );
        var x = o.dx + chart.dotRadius + 4;
        if (x + tp.width > plot.right) {
          x = o.dx - chart.dotRadius - 4 - tp.width;
        }
        tp.paint(canvas, Offset(x, o.dy + 3));
      }
    }
  }

  void _paintFitLabel(Canvas canvas) {
    final fit = law;
    if (fit == null || !chart.showFit || !chart.showFitLabel) return;
    final exponent = fit.exponent.toStringAsFixed(3);
    final tp = text.get(
      'L ∝ C^$exponent   R² ${fit.rSquared.toStringAsFixed(3)}',
      TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: chart.fitColor,
      ),
    );
    tp.paint(canvas, Offset(plot.right - tp.width - 8, plot.top + 6));
  }
}
