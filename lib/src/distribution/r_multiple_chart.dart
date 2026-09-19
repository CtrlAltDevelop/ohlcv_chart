import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../series/series_axis.dart';
import 'histogram_chart.dart';

/// Turns each trade's profit into R — what it made as a multiple of what it
/// risked.
///
/// [pnl] and [risk] are paired by position; a pair whose risk is not a positive
/// number is skipped, since a trade with no risk defined has no R.
List<double> rMultiplesFrom(List<double> pnl, List<double> risk) => [
  for (var i = 0; i < math.min(pnl.length, risk.length); i++)
    if (pnl[i].isFinite && risk[i].isFinite && risk[i] > 0) pnl[i] / risk[i],
];

/// What a set of trade results, in R, add up to.
@immutable
class RMultipleStats {
  /// Creates statistics from their parts; see [RMultipleStats.fromResults].
  const RMultipleStats({
    required this.count,
    required this.wins,
    required this.losses,
    required this.total,
    required this.expectancy,
    required this.averageWin,
    required this.averageLoss,
    required this.largestWin,
    required this.largestLoss,
    required this.profitFactor,
    required this.standardDeviation,
  });

  /// Works the statistics out from [results], each a trade's result in R.
  ///
  /// Results that are not finite are skipped. A result of exactly zero counts
  /// as neither a win nor a loss.
  factory RMultipleStats.fromResults(Iterable<double> results) {
    var count = 0;
    var wins = 0;
    var losses = 0;
    var total = 0.0;
    var won = 0.0;
    var lost = 0.0;
    var largestWin = 0.0;
    var largestLoss = 0.0;
    var squares = 0.0;
    for (final r in results) {
      if (!r.isFinite) continue;
      count++;
      total += r;
      squares += r * r;
      if (r > 0) {
        wins++;
        won += r;
        largestWin = math.max(largestWin, r);
      } else if (r < 0) {
        losses++;
        lost += r;
        largestLoss = math.min(largestLoss, r);
      }
    }

    final mean = count == 0 ? 0.0 : total / count;
    // The sample standard deviation: the spread a strategy's future trades
    // are expected to show, not only these.
    final variance = count < 2
        ? 0.0
        : math.max(0.0, (squares - count * mean * mean) / (count - 1));

    return RMultipleStats(
      count: count,
      wins: wins,
      losses: losses,
      total: total,
      expectancy: mean,
      averageWin: wins == 0 ? 0 : won / wins,
      averageLoss: losses == 0 ? 0 : lost / losses,
      largestWin: largestWin,
      largestLoss: largestLoss,
      profitFactor: lost == 0 ? (won > 0 ? double.infinity : 0) : won / -lost,
      standardDeviation: math.sqrt(variance),
    );
  }

  /// How many results there were.
  final int count;

  /// How many made money.
  final int wins;

  /// How many lost it.
  final int losses;

  /// Every result added up.
  final double total;

  /// The average result: what a trade is worth, in R, before it is taken.
  final double expectancy;

  /// The average winning result.
  final double averageWin;

  /// The average losing result, a negative number.
  final double averageLoss;

  /// The best result.
  final double largestWin;

  /// The worst result, a negative number.
  final double largestLoss;

  /// Everything won over everything lost; infinite with no losses.
  final double profitFactor;

  /// How widely results spread around [expectancy].
  final double standardDeviation;

  /// The share of results that made money, from 0 to 1.
  double get winRate => count == 0 ? 0 : wins / count;

  /// The system quality number: expectancy over its spread, scaled by how many
  /// trades back it up. Zero with fewer than two results or no spread.
  double get sqn => standardDeviation <= 0
      ? 0
      : expectancy / standardDeviation * math.sqrt(count.toDouble());
}

/// Counts [results] into bins [binWidth] R wide whose edges fall on whole
/// multiples of it, so zero is always an edge and no bin mixes wins with
/// losses.
List<HistogramBin> rMultipleBins(
  Iterable<double> results, {
  double binWidth = 0.5,
}) {
  final values = [
    for (final r in results)
      if (r.isFinite) r,
  ];
  if (values.isEmpty || !(binWidth > 0)) return const [];

  var low = (values.reduce(math.min) / binWidth).floorToDouble() * binWidth;
  var high = (values.reduce(math.max) / binWidth).ceilToDouble() * binWidth;
  if (high <= low) high = low + binWidth;
  // A result sitting exactly on the top edge belongs in a bin that starts
  // there, not in the one below it.
  if (values.any((r) => r == high)) high += binWidth;
  return histogramBins(values, binWidth: binWidth, min: low, max: high);
}

/// One figure in the statistics row of an [RMultipleChart].
@immutable
class RMultipleStat {
  /// Creates a figure called [label] reading [value].
  const RMultipleStat(this.label, this.value, {this.color});

  /// What it is.
  final String label;

  /// What it reads.
  final String value;

  /// A colour for the value; null uses the chart's.
  final Color? color;
}

/// The figures an [RMultipleChart] shows by default.
List<RMultipleStat> defaultRMultipleStats(
  RMultipleStats stats, {
  Color? profitColor,
  Color? lossColor,
}) {
  String r(double value) =>
      '${value > 0 ? '+' : ''}${value.toStringAsFixed(2)}R';
  Color? signed(double value) => value > 0
      ? profitColor
      : value < 0
      ? lossColor
      : null;
  return [
    RMultipleStat('Trades', '${stats.count}'),
    RMultipleStat('Win rate', '${(stats.winRate * 100).toStringAsFixed(1)}%'),
    RMultipleStat('Avg win', r(stats.averageWin), color: profitColor),
    RMultipleStat('Avg loss', r(stats.averageLoss), color: lossColor),
    RMultipleStat(
      'Expectancy',
      r(stats.expectancy),
      color: signed(stats.expectancy),
    ),
    RMultipleStat(
      'Profit factor',
      stats.profitFactor.isInfinite
          ? '∞'
          : stats.profitFactor.toStringAsFixed(2),
    ),
    RMultipleStat('SQN', stats.sqn.toStringAsFixed(2)),
  ];
}

/// How a strategy's trades turned out in R, with what they are worth on
/// average — the distribution traders size positions from.
///
/// ```dart
/// RMultipleChart(results: rMultiplesFrom(pnls, risks));
/// ```
///
/// A row of statistics sits over a histogram whose bins split at zero, losses
/// in one colour and wins in another, with lines at zero and at the
/// expectancy. The chart fills the box it is given, and is [defaultHeight] high
/// in a box with no height of its own.
class RMultipleChart extends StatelessWidget {
  /// Creates a distribution of [results], each a trade's result in R.
  const RMultipleChart({
    super.key,
    required this.results,
    this.binWidth = 0.5,
    this.profitColor = const Color(0xFF2F9E44),
    this.lossColor = const Color(0xFFE03131),
    this.showStats = true,
    this.statsBuilder,
    this.statLabelStyle,
    this.statValueStyle,
    this.statSpacing = 16,
    this.statsGap = 10,
    this.showZeroLine = true,
    this.showExpectancyLine = true,
    this.referenceColor = const Color(0x99FFFFFF),
    this.barSpacing = 1,
    this.barRadius = const BorderRadius.vertical(top: Radius.circular(1)),
    this.tickCount = 5,
    this.valueFormatter,
    this.axisLabelStyle,
    this.gridColor = const Color(0x22FFFFFF),
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

  /// Each trade's result, in R.
  final List<double> results;

  /// How many R each bin spans.
  final double binWidth;

  /// The colour of bins above zero.
  final Color profitColor;

  /// The colour of bins below it.
  final Color lossColor;

  /// Whether the statistics row is shown.
  final bool showStats;

  /// Picks the figures in the statistics row; null shows
  /// [defaultRMultipleStats].
  final List<RMultipleStat> Function(RMultipleStats stats)? statsBuilder;

  /// Style of a figure's name.
  final TextStyle? statLabelStyle;

  /// Style of a figure's value.
  final TextStyle? statValueStyle;

  /// The space between figures.
  final double statSpacing;

  /// The space between the figures and the histogram.
  final double statsGap;

  /// Whether a line is drawn at zero.
  final bool showZeroLine;

  /// Whether a line is drawn at the expectancy.
  final bool showExpectancyLine;

  /// The colour of those lines.
  final Color referenceColor;

  /// How many pixels are taken off each side of a bar.
  final double barSpacing;

  /// The rounding of each bar's corners, as drawn on the screen, passed
  /// through to the histogram underneath.
  final BorderRadius barRadius;

  /// About how many ticks to write on each axis.
  final int tickCount;

  /// Writes a value on the R axis; null writes it as `1.5R`.
  final String Function(double value)? valueFormatter;

  /// Style of an axis label.
  final TextStyle? axisLabelStyle;

  /// Colour of the grid; null rules none.
  final Color? gridColor;

  /// Called as a touch moves across the bins, and with null when it leaves.
  final ValueChanged<HistogramTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched bin; null shows none.
  final Widget? Function(BuildContext context, HistogramTouchDetails details)?
  tooltipBuilder;

  /// How long the bars take to grow in; zero draws them at once.
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
    final stats = RMultipleStats.fromResults(results);
    final bins = rMultipleBins(results, binWidth: binWidth);

    final histogram = HistogramChart(
      bins: bins,
      barColor: profitColor,
      negativeColor: lossColor,
      barSpacing: barSpacing,
      barRadius: barRadius,
      tickCount: tickCount,
      valueFormatter: valueFormatter ?? _formatR,
      axisLabelStyle: axisLabelStyle,
      gridColor: gridColor,
      referenceLines: [
        if (showZeroLine && bins.isNotEmpty) 0,
        if (showExpectancyLine && stats.count > 0 && stats.expectancy != 0)
          stats.expectancy,
      ],
      referenceColor: referenceColor,
      onTouch: onTouch,
      tooltipBuilder: tooltipBuilder,
      animationDuration: animationDuration,
      animationCurve: animationCurve,
      animateOnMount: animateOnMount,
    );

    Widget chart = LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : defaultHeight;
        return Container(
          height: height,
          color: backgroundColor,
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showStats) ...[
                _StatsRow(
                  stats:
                      (statsBuilder ??
                      (s) => defaultRMultipleStats(
                        s,
                        profitColor: profitColor,
                        lossColor: lossColor,
                      ))(stats),
                  labelStyle: seriesAxisLabelStyle.merge(statLabelStyle),
                  valueStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE9ECEF),
                  ).merge(statValueStyle),
                  spacing: statSpacing,
                ),
                SizedBox(height: statsGap),
              ],
              Expanded(child: histogram),
            ],
          ),
        );
      },
    );

    final label = semanticLabel;
    if (label != null) {
      chart = Semantics(container: true, label: label, child: chart);
    }
    return chart;
  }

  static String _formatR(double value) {
    final text = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '${text}R';
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.stats,
    required this.labelStyle,
    required this.valueStyle,
    required this.spacing,
  });

  final List<RMultipleStat> stats;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: 6,
      children: [
        for (final stat in stats)
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(stat.label, style: labelStyle),
              Text(
                stat.value,
                style: stat.color == null
                    ? valueStyle
                    : valueStyle.copyWith(color: stat.color),
              ),
            ],
          ),
      ],
    );
  }
}
