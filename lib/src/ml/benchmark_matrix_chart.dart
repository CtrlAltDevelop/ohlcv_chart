import 'package:flutter/widgets.dart';

import '../heatmap/heatmap_chart.dart';
import '../heatmap/heatmap_data.dart';

/// How well each benchmark score of each model stands, from 0 (the worst of
/// its column) to 1 (the best), where [lowerIsBetter] holds the benchmarks on
/// which a lower score wins — perplexity, error rate, latency.
///
/// A column in which every model scored alike is 0.5 throughout; a missing
/// score stays null.
List<List<double?>> benchmarkQuality(
  List<List<double?>> scores, {
  Set<int> lowerIsBetter = const {},
}) {
  if (scores.isEmpty) return const [];
  final columns = scores.map((r) => r.length).reduce((a, b) => a > b ? a : b);
  final out = List.generate(
    scores.length,
    (_) => List<double?>.filled(columns, null),
  );
  for (var c = 0; c < columns; c++) {
    var low = double.infinity;
    var high = double.negativeInfinity;
    for (final row in scores) {
      final v = c < row.length ? row[c] : null;
      if (v == null || !v.isFinite) continue;
      if (v < low) low = v;
      if (v > high) high = v;
    }
    for (var r = 0; r < scores.length; r++) {
      final v = c < scores[r].length ? scores[r][c] : null;
      if (v == null || !v.isFinite) continue;
      var q = high == low ? 0.5 : (v - low) / (high - low);
      if (lowerIsBetter.contains(c)) q = 1 - q;
      out[r][c] = q;
    }
  }
  return out;
}

/// The mean of each model's [quality] across the benchmarks it has a score for;
/// null for a model with none.
List<double?> benchmarkAverages(List<List<double?>> quality) => [
  for (final row in quality)
    () {
      var sum = 0.0;
      var n = 0;
      for (final q in row) {
        if (q == null) continue;
        sum += q;
        n++;
      }
      return n == 0 ? null : sum / n;
    }(),
];

/// The index of the best model in each benchmark, or null where no model has a
/// score. The first of equals.
List<int?> benchmarkLeaders(
  List<List<double?>> scores, {
  Set<int> lowerIsBetter = const {},
}) {
  if (scores.isEmpty) return const [];
  final columns = scores.map((r) => r.length).reduce((a, b) => a > b ? a : b);
  return [
    for (var c = 0; c < columns; c++)
      () {
        int? best;
        double? top;
        for (var r = 0; r < scores.length; r++) {
          final v = c < scores[r].length ? scores[r][c] : null;
          if (v == null || !v.isFinite) continue;
          if (top == null || (lowerIsBetter.contains(c) ? v < top : v > top)) {
            top = v;
            best = r;
          }
        }
        return best;
      }(),
  ];
}

/// What a touch on a [BenchmarkMatrixChart] landed on.
@immutable
class BenchmarkTouchDetails {
  /// Creates the details of a touch on a square.
  const BenchmarkTouchDetails({
    required this.model,
    required this.benchmark,
    required this.score,
    required this.quality,
    required this.isLeader,
    required this.isAverage,
    required this.rect,
  });

  /// The model's name.
  final String model;

  /// The benchmark's name; null on the average column.
  final String? benchmark;

  /// The raw score; null on the average column or where there is none.
  final double? score;

  /// How well it stands in its column, from 0 to 1.
  final double? quality;

  /// Whether this is the best score on its benchmark.
  final bool isLeader;

  /// Whether this is the average column.
  final bool isAverage;

  /// The square, in the chart's local pixels.
  final Rect rect;
}

/// Models against benchmarks as a heatmap: each score coloured by how it
/// stands among the models on that benchmark, the leader of each marked, and an
/// average column to rank them by.
///
/// ```dart
/// BenchmarkMatrixChart(
///   models: const ['Model A', 'Model B', 'Model C'],
///   benchmarks: const ['MMLU', 'GSM8K', 'HumanEval', 'Perplexity'],
///   scores: [
///     [86.4, 92.0, 80.5, 5.1],
///     [83.1, 88.7, 76.2, 5.6],
///     [79.9, 81.3, 71.0, 6.4],
///   ],
///   lowerIsBetter: const {3},
/// );
/// ```
///
/// Colour is relative within a benchmark, so a hard benchmark and an easy one
/// read alike; the written number is the raw score. The chart fills the box it
/// is given, and is [defaultHeight] high in a box with no height of its own.
class BenchmarkMatrixChart extends StatelessWidget {
  /// Creates a matrix of [scores], a row per model and a column per benchmark.
  const BenchmarkMatrixChart({
    super.key,
    required this.models,
    required this.benchmarks,
    required this.scores,
    this.lowerIsBetter = const {},
    this.sortByAverage = true,
    this.showAverage = true,
    this.averageLabel = 'Avg',
    this.markLeaders = true,
    this.lowColor = const Color(0xFFE03131),
    this.midColor = const Color(0xFFE8C547),
    this.highColor = const Color(0xFF2F9E44),
    this.scoreFormatter,
    this.labelStyle,
    this.axisLabelStyle,
    this.modelAxisWidth = 88,
    this.benchmarkAxisHeight = 22,
    this.spacing = 1,
    this.radius = const BorderRadius.all(Radius.circular(2)),
    this.onTouch,
    this.tooltipBuilder,
    this.animationDuration = Duration.zero,
    this.animationCurve = Curves.easeOutCubic,
    this.animateOnMount = true,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.defaultHeight = 240,
    this.semanticLabel,
  });

  /// The model names, one per row of [scores].
  final List<String> models;

  /// The benchmark names, one per column.
  final List<String> benchmarks;

  /// The scores, `scores[model][benchmark]`; null or a value that is not
  /// finite leaves a square empty.
  final List<List<double?>> scores;

  /// The indices of benchmarks where a lower score is better.
  final Set<int> lowerIsBetter;

  /// Whether the best model by average is put at the top.
  final bool sortByAverage;

  /// Whether a last column holds each model's average standing, from 0 to 100.
  final bool showAverage;

  /// What the average column is called.
  final String averageLabel;

  /// Whether the best score of each benchmark is starred.
  final bool markLeaders;

  /// The colour of the worst score on a benchmark.
  final Color lowColor;

  /// The colour half way.
  final Color midColor;

  /// The colour of the best.
  final Color highColor;

  /// Writes a score; null writes one decimal.
  final String Function(double score)? scoreFormatter;

  /// Style of the scores in the squares.
  final TextStyle? labelStyle;

  /// Style of the model and benchmark names.
  final TextStyle? axisLabelStyle;

  /// Room held for the model names.
  final double modelAxisWidth;

  /// Room held for the benchmark names.
  final double benchmarkAxisHeight;

  /// The gap between squares.
  final double spacing;

  /// The rounding of each square's corners.
  final BorderRadius radius;

  /// Called as a touch moves over the squares, and with null when it leaves.
  final ValueChanged<BenchmarkTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched square; null shows none.
  final Widget? Function(BuildContext context, BenchmarkTouchDetails details)?
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

  @override
  Widget build(BuildContext context) {
    final rowsCount = models.length < scores.length
        ? models.length
        : scores.length;
    final data = scores.take(rowsCount).toList();
    final quality = benchmarkQuality(data, lowerIsBetter: lowerIsBetter);
    final averages = benchmarkAverages(quality);
    final leaders = benchmarkLeaders(data, lowerIsBetter: lowerIsBetter);

    // The order the rows are drawn in: best average first, or as given.
    final order = [for (var i = 0; i < rowsCount; i++) i];
    if (sortByAverage) {
      order.sort((a, b) {
        final qa = averages[a] ?? -1;
        final qb = averages[b] ?? -1;
        return qb.compareTo(qa);
      });
    }

    final format = scoreFormatter ?? (v) => v.toStringAsFixed(1);
    final columns = benchmarks.length + (showAverage ? 1 : 0);

    final cells = <HeatmapCell>[
      for (var row = 0; row < order.length; row++) ...[
        for (var c = 0; c < benchmarks.length; c++)
          if (quality[order[row]][c] case final q?)
            HeatmapCell(
              x: c,
              y: row,
              value: q,
              label:
                  (markLeaders && leaders[c] == order[row] ? '★ ' : '') +
                  format(data[order[row]][c]!),
            ),
        if (showAverage)
          if (averages[order[row]] case final avg?)
            HeatmapCell(
              x: benchmarks.length,
              y: row,
              value: avg,
              label: (avg * 100).round().toString(),
            ),
      ],
    ];

    BenchmarkTouchDetails details(HeatmapTouchDetails t) {
      final model = order[t.y];
      final isAverage = t.x >= benchmarks.length;
      return BenchmarkTouchDetails(
        model: models[model],
        benchmark: isAverage ? null : benchmarks[t.x],
        score: isAverage ? null : data[model][t.x],
        quality: isAverage ? averages[model] : quality[model][t.x],
        isLeader: !isAverage && leaders[t.x] == model,
        isAverage: isAverage,
        rect: t.rect,
      );
    }

    final touch = onTouch;
    final builder = tooltipBuilder;
    return HeatmapChart(
      cells: cells,
      columns: columns,
      rows: order.length,
      scale: HeatmapGradientScale(colors: [lowColor, midColor, highColor]),
      minValue: 0,
      maxValue: 1,
      xAxis: HeatmapAxis(
        labelBuilder: (c) =>
            c < benchmarks.length ? benchmarks[c] : averageLabel,
        size: benchmarkAxisHeight,
        style: axisLabelStyle,
      ),
      yAxis: HeatmapAxis(
        labels: [for (final i in order) models[i]],
        size: modelAxisWidth,
        style: axisLabelStyle,
      ),
      spacing: spacing,
      radius: radius,
      labelBuilder: (cell) => cell.label,
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
}
