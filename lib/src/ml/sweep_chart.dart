import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';

import '../heatmap/heatmap_chart.dart';
import '../heatmap/heatmap_data.dart';

/// One trial of a hyperparameter sweep: two settings and the score they got.
@immutable
class SweepTrial {
  /// Creates a trial that scored [score] with [x] on the bottom axis and [y]
  /// on the side axis — a learning rate and a batch size, say.
  const SweepTrial({
    required this.x,
    required this.y,
    required this.score,
    this.data,
  });

  /// The setting along the bottom axis.
  final double x;

  /// The setting up the side axis.
  final double y;

  /// The result: a validation loss, an accuracy.
  final double score;

  /// Anything the app wants back when this trial is touched.
  final Object? data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SweepTrial &&
          other.x == x &&
          other.y == y &&
          other.score == score &&
          other.data == data;

  @override
  int get hashCode => Object.hash(x, y, score, data);
}

/// A sweep's trials gathered into a grid: the distinct settings of each axis
/// and the score of each combination.
@immutable
class SweepGrid {
  /// Creates a grid from its parts; see [sweepGrid].
  const SweepGrid({
    required this.xs,
    required this.ys,
    required this.scores,
    required this.counts,
    required this.bestX,
    required this.bestY,
  });

  /// The distinct values of the bottom setting, ascending.
  final List<double> xs;

  /// The distinct values of the side setting, ascending.
  final List<double> ys;

  /// The score at each combination, `scores[yIndex][xIndex]`: the mean where a
  /// combination was tried more than once, null where it was not tried.
  final List<List<double?>> scores;

  /// How many trials fell on each combination.
  final List<List<int>> counts;

  /// The column of the best score, or null with no score.
  final int? bestX;

  /// The row of the best score.
  final int? bestY;

  /// The best score.
  double? get best =>
      bestX == null || bestY == null ? null : scores[bestY!][bestX!];

  /// The mean score of each column — what a setting is worth whatever the other
  /// is — null where the column holds none.
  List<double?> get columnMeans => [
    for (var x = 0; x < xs.length; x++)
      _mean([for (final row in scores) row[x]]),
  ];

  /// The mean score of each row.
  List<double?> get rowMeans => [for (final row in scores) _mean(row)];

  static double? _mean(List<double?> values) {
    var sum = 0.0;
    var n = 0;
    for (final v in values) {
      if (v == null) continue;
      sum += v;
      n++;
    }
    return n == 0 ? null : sum / n;
  }
}

/// Gathers [trials] into a [SweepGrid].
///
/// A trial whose settings or score are not finite is skipped. [lowerIsBetter]
/// says which end of the scores is the best.
SweepGrid sweepGrid(Iterable<SweepTrial> trials, {bool lowerIsBetter = true}) {
  final valid = [
    for (final t in trials)
      if (t.x.isFinite && t.y.isFinite && t.score.isFinite) t,
  ];
  final xs = ({for (final t in valid) t.x}.toList())..sort();
  final ys = ({for (final t in valid) t.y}.toList())..sort();
  final sums = [for (final _ in ys) List<double>.filled(xs.length, 0)];
  final counts = [for (final _ in ys) List<int>.filled(xs.length, 0)];
  for (final t in valid) {
    final xi = xs.indexOf(t.x);
    final yi = ys.indexOf(t.y);
    sums[yi][xi] += t.score;
    counts[yi][xi]++;
  }
  final scores = [
    for (var y = 0; y < ys.length; y++)
      [
        for (var x = 0; x < xs.length; x++)
          counts[y][x] == 0 ? null : sums[y][x] / counts[y][x],
      ],
  ];

  int? bestX;
  int? bestY;
  double? top;
  for (var y = 0; y < ys.length; y++) {
    for (var x = 0; x < xs.length; x++) {
      final v = scores[y][x];
      if (v == null) continue;
      if (top == null || (lowerIsBetter ? v < top : v > top)) {
        top = v;
        bestX = x;
        bestY = y;
      }
    }
  }
  return SweepGrid(
    xs: xs,
    ys: ys,
    scores: scores,
    counts: counts,
    bestX: bestX,
    bestY: bestY,
  );
}

/// What a touch on a [SweepChart] landed on.
@immutable
class SweepTouchDetails {
  /// Creates the details of a touch on a square.
  const SweepTouchDetails({
    required this.xIndex,
    required this.yIndex,
    required this.x,
    required this.y,
    required this.score,
    required this.count,
    required this.isBest,
    required this.isMarginal,
    required this.rect,
  });

  /// The column, counted from the left; the mean column is one past the last.
  final int xIndex;

  /// The row, counted from the top; the mean row is one past the last.
  final int yIndex;

  /// The bottom setting there; null in the mean column.
  final double? x;

  /// The side setting there; null in the mean row.
  final double? y;

  /// The score, or the mean for a marginal; null where nothing was tried.
  final double? score;

  /// How many trials fell there; zero for a marginal.
  final int count;

  /// Whether this is the best combination.
  final bool isBest;

  /// Whether this is a mean rather than a combination.
  final bool isMarginal;

  /// The square, in the chart's local pixels.
  final Rect rect;
}

/// A hyperparameter sweep as a grid of scores, the best combination starred.
///
/// ```dart
/// SweepChart(
///   trials: [
///     for (final r in runs)
///       SweepTrial(x: r.learningRate, y: r.batchSize, score: r.valLoss),
///   ],
///   xFormatter: (v) => v.toStringAsExponential(0),
///   xAxisLabel: 'learning rate',
///   yAxisLabel: 'batch size',
/// );
/// ```
///
/// Squares run from [goodColor] to [badColor] by how well they did. A last
/// column and row hold the mean of each setting — what it is worth whatever the
/// other is. The chart fills the box it is given, and is [defaultHeight] high
/// in a box with no height of its own.
class SweepChart extends StatelessWidget {
  /// Creates a grid of [trials].
  const SweepChart({
    super.key,
    required this.trials,
    this.lowerIsBetter = true,
    this.goodColor = const Color(0xFF2F9E44),
    this.midColor = const Color(0xFFE8C547),
    this.badColor = const Color(0xFFE03131),
    this.showMarginals = true,
    this.marginalLabel = 'mean',
    this.showValues = true,
    this.scoreFormatter,
    this.xFormatter,
    this.yFormatter,
    this.xAxisLabel,
    this.yAxisLabel,
    this.labelStyle,
    this.axisLabelStyle,
    this.yAxisWidth = 56,
    this.xAxisHeight = 20,
    this.spacing = 1,
    this.radius = const BorderRadius.all(Radius.circular(2)),
    this.onTouch,
    this.tooltipBuilder,
    this.animationDuration = Duration.zero,
    this.animationCurve = Curves.easeOutCubic,
    this.animateOnMount = true,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.defaultHeight = 260,
    this.semanticLabel,
  });

  /// The trials; ones that share both settings are averaged.
  final List<SweepTrial> trials;

  /// Whether a lower score is better — a loss — or a higher one.
  final bool lowerIsBetter;

  /// The colour of the best scores.
  final Color goodColor;

  /// The colour half way.
  final Color midColor;

  /// The colour of the worst.
  final Color badColor;

  /// Whether a last column and row hold the mean of each setting.
  final bool showMarginals;

  /// What the marginals are called on the axes.
  final String marginalLabel;

  /// Whether each score is written in its square.
  final bool showValues;

  /// Writes a score; null writes at most three significant digits.
  final String Function(double score)? scoreFormatter;

  /// Writes a bottom setting; null writes it compactly.
  final String Function(double value)? xFormatter;

  /// Writes a side setting; null writes it compactly.
  final String Function(double value)? yFormatter;

  /// Names the bottom setting, written in the axis's corner label.
  final String? xAxisLabel;

  /// Names the side setting.
  final String? yAxisLabel;

  /// Style of the scores in the squares.
  final TextStyle? labelStyle;

  /// Style of the setting names.
  final TextStyle? axisLabelStyle;

  /// Room held for the side settings.
  final double yAxisWidth;

  /// Room held for the bottom settings.
  final double xAxisHeight;

  /// The gap between squares.
  final double spacing;

  /// The rounding of each square's corners.
  final BorderRadius radius;

  /// Called as a touch moves over the squares, and with null when it leaves.
  final ValueChanged<SweepTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched square; null shows none.
  final Widget? Function(BuildContext context, SweepTouchDetails details)?
  tooltipBuilder;

  /// How long the squares take to fade in; zero draws them at once.
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

  /// Writes a setting compactly: `0.0003` as `3e-4`, `128` as `128`.
  static String formatSetting(double value) {
    if (value == 0) return '0';
    final abs = value.abs();
    if (abs >= 1e4 || abs < 1e-2) {
      final text = value.toStringAsExponential(0);
      return text.replaceFirst('e+', 'e');
    }
    final rounded = double.parse(value.toStringAsFixed(3));
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toString();
  }

  static String _score(double v) {
    if (v == 0) return '0';
    final digits = v.abs() >= 100
        ? 0
        : v.abs() >= 10
        ? 1
        : v.abs() >= 1
        ? 2
        : 3;
    return v.toStringAsFixed(digits);
  }

  @override
  Widget build(BuildContext context) {
    final grid = sweepGrid(trials, lowerIsBetter: lowerIsBetter);
    final format = scoreFormatter ?? _score;
    final columns = grid.xs.length + (showMarginals ? 1 : 0);
    final rows = grid.ys.length + (showMarginals ? 1 : 0);
    final bestRow = grid.bestY;
    final bestCol = grid.bestX;

    final cells = <HeatmapCell>[
      for (var y = 0; y < grid.ys.length; y++)
        for (var x = 0; x < grid.xs.length; x++)
          if (grid.scores[y][x] case final v?)
            HeatmapCell(
              x: x,
              y: y,
              value: v,
              label: x == bestCol && y == bestRow
                  ? '★ ${format(v)}'
                  : format(v),
            ),
      if (showMarginals) ...[
        for (var y = 0; y < grid.ys.length; y++)
          if (grid.rowMeans[y] case final v?)
            HeatmapCell(x: grid.xs.length, y: y, value: v, label: format(v)),
        for (var x = 0; x < grid.xs.length; x++)
          if (grid.columnMeans[x] case final v?)
            HeatmapCell(x: x, y: grid.ys.length, value: v, label: format(v)),
      ],
    ];

    var low = double.infinity;
    var high = double.negativeInfinity;
    for (final c in cells) {
      if (c.isEmpty) continue;
      low = math.min(low, c.value!);
      high = math.max(high, c.value!);
    }
    if (!low.isFinite) {
      low = 0;
      high = 1;
    }

    final scale = HeatmapGradientScale(
      colors: lowerIsBetter
          ? [goodColor, midColor, badColor]
          : [badColor, midColor, goodColor],
    );

    String xLabel(int c) => c < grid.xs.length
        ? (xFormatter ?? formatSetting)(grid.xs[c])
        : marginalLabel;
    String yLabel(int r) => r < grid.ys.length
        ? (yFormatter ?? formatSetting)(grid.ys[r])
        : marginalLabel;

    SweepTouchDetails details(HeatmapTouchDetails t) {
      final inX = t.x < grid.xs.length;
      final inY = t.y < grid.ys.length;
      return SweepTouchDetails(
        xIndex: t.x,
        yIndex: t.y,
        x: inX ? grid.xs[t.x] : null,
        y: inY ? grid.ys[t.y] : null,
        score: t.value,
        count: inX && inY ? grid.counts[t.y][t.x] : 0,
        isBest: inX && inY && t.x == bestCol && t.y == bestRow,
        isMarginal: !inX || !inY,
        rect: t.rect,
      );
    }

    final touch = onTouch;
    final builder = tooltipBuilder;
    return HeatmapChart(
      cells: cells,
      columns: columns,
      rows: rows,
      scale: scale,
      minValue: low,
      maxValue: high,
      xAxis: HeatmapAxis(
        labelBuilder: xLabel,
        size: xAxisHeight,
        style: axisLabelStyle,
      ),
      yAxis: HeatmapAxis(
        labelBuilder: yLabel,
        size: yAxisWidth,
        style: axisLabelStyle,
      ),
      spacing: spacing,
      radius: radius,
      labelBuilder: showValues ? (cell) => cell.label : null,
      labelStyle: labelStyle,
      onTouch: touch == null
          ? null
          : (t) => touch(t == null ? null : details(t)),
      tooltipBuilder: builder == null
          ? null
          : (context, t) => builder(context, details(t)),
      animationDuration: animationDuration,
      animationCurve: animationCurve,
      animateOnMount: animateOnMount,
      padding: padding,
      backgroundColor: backgroundColor,
      defaultHeight: defaultHeight,
      semanticLabel: semanticLabel,
    );
  }

  /// Whether [a] and [b] are the same trials, for a parent deciding to rebuild.
  static bool sameTrials(List<SweepTrial> a, List<SweepTrial> b) =>
      listEquals(a, b);
}
