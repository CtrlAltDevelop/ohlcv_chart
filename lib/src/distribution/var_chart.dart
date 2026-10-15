import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../series/series_axis.dart';
import 'histogram_chart.dart';
import 'r_multiple_chart.dart' show RMultipleStat;

/// How much a set of returns can be expected to lose: value at risk and
/// expected shortfall, worked out from the history itself.
@immutable
class ValueAtRisk {
  /// Creates a result from its parts; see [ValueAtRisk.fromReturns].
  const ValueAtRisk({
    required this.confidence,
    required this.valueAtRisk,
    required this.expectedShortfall,
    required this.mean,
    required this.standardDeviation,
    required this.worst,
    required this.count,
  });

  /// Works the figures out from [returns], by the historical method.
  ///
  /// [confidence] is the share of outcomes the figure should not be worse than:
  /// at 0.95, [valueAtRisk] is the return that only one in twenty was worse
  /// than. Returns that are not finite are skipped. With nothing to measure
  /// every figure is zero.
  factory ValueAtRisk.fromReturns(
    Iterable<double> returns, {
    double confidence = 0.95,
  }) {
    final sorted = [
      for (final value in returns)
        if (value.isFinite) value,
    ]..sort();
    final level = confidence.isFinite ? confidence.clamp(0.0, 1.0) : 0.95;
    if (sorted.isEmpty) {
      return ValueAtRisk(
        confidence: level,
        valueAtRisk: 0,
        expectedShortfall: 0,
        mean: 0,
        standardDeviation: 0,
        worst: 0,
        count: 0,
      );
    }

    // The return a (1 - confidence) share of outcomes fall at or below, read
    // off the sorted history by linear interpolation.
    final at = (1 - level) * (sorted.length - 1);
    final low = at.floor();
    final high = at.ceil();
    final threshold = low == high
        ? sorted[low]
        : sorted[low] + (sorted[high] - sorted[low]) * (at - low);

    var tailSum = 0.0;
    var tailCount = 0;
    var sum = 0.0;
    for (final value in sorted) {
      sum += value;
      if (value <= threshold) {
        tailSum += value;
        tailCount++;
      }
    }
    final mean = sum / sorted.length;
    var squares = 0.0;
    for (final value in sorted) {
      squares += (value - mean) * (value - mean);
    }
    final deviation = sorted.length > 1
        ? math.sqrt(squares / (sorted.length - 1))
        : 0.0;

    return ValueAtRisk(
      confidence: level,
      valueAtRisk: threshold,
      // The tail always holds at least the worst outcome.
      expectedShortfall: tailCount == 0 ? sorted.first : tailSum / tailCount,
      mean: mean,
      standardDeviation: deviation,
      worst: sorted.first,
      count: sorted.length,
    );
  }

  /// The share of outcomes [valueAtRisk] is not worse than.
  final double confidence;

  /// The return that only `1 - confidence` of outcomes were worse than. Zero or
  /// less for a history with any losses.
  final double valueAtRisk;

  /// The average of the outcomes at or beyond [valueAtRisk]: what a bad day
  /// costs once it has gone past the threshold. Also called CVaR.
  final double expectedShortfall;

  /// The average return.
  final double mean;

  /// How widely the returns spread around [mean].
  final double standardDeviation;

  /// The single worst return.
  final double worst;

  /// How many returns there were.
  final int count;
}

/// Counts [returns] into bins, those in the loss tail — at or beyond
/// [valueAtRisk] — carrying [tailColor] so a histogram shows where the risk is.
///
/// A bin counts as tail when its middle is at or beyond the threshold.
List<HistogramBin> varBins(
  Iterable<double> returns, {
  required double valueAtRisk,
  required Color tailColor,
  int? binCount,
  double? binWidth,
}) {
  final bins = histogramBins(returns, binCount: binCount, binWidth: binWidth);
  return [
    for (final bin in bins)
      bin.center <= valueAtRisk
          ? HistogramBin(
              from: bin.from,
              to: bin.to,
              count: bin.count,
              color: tailColor,
            )
          : bin,
  ];
}

/// The shape of a set of returns, with the loss tail picked out and the value
/// at risk and expected shortfall marked.
///
/// ```dart
/// VarChart(returns: dailyReturns, confidence: 0.99);
/// ```
///
/// A row of figures sits over a histogram. The bars in the loss tail take
/// [tailColor], and lines mark the value at risk and the expected shortfall.
/// Returns are fractions: -0.03 is a 3% loss. The chart fills the box it is
/// given, and is [defaultHeight] high in a box with no height of its own.
class VarChart extends StatelessWidget {
  /// Creates a chart of [returns].
  const VarChart({
    super.key,
    required this.returns,
    this.confidence = 0.95,
    this.binCount,
    this.binWidth,
    this.barColor = const Color(0xFF4C86CD),
    this.tailColor = const Color(0xFFE03131),
    this.showStats = true,
    this.statsBuilder,
    this.statLabelStyle,
    this.statValueStyle,
    this.statSpacing = 16,
    this.statsGap = 10,
    this.showVarLine = true,
    this.showShortfallLine = true,
    this.showMeanLine = false,
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

  /// The returns, as fractions: -0.03 is a 3% loss.
  final List<double> returns;

  /// The share of outcomes the value at risk is not worse than.
  final double confidence;

  /// How many bins; null takes the square root of the number of returns.
  final int? binCount;

  /// How wide each bin is; wins over [binCount].
  final double? binWidth;

  /// The colour of the bars outside the tail.
  final Color barColor;

  /// The colour of the bars in the loss tail.
  final Color tailColor;

  /// Whether the row of figures is shown.
  final bool showStats;

  /// Builds the figures; null shows the defaults.
  final List<RMultipleStat> Function(ValueAtRisk risk)? statsBuilder;

  /// Style of a figure's name.
  final TextStyle? statLabelStyle;

  /// Style of a figure's value.
  final TextStyle? statValueStyle;

  /// The space between figures.
  final double statSpacing;

  /// The space between the figures and the histogram.
  final double statsGap;

  /// Whether a line marks the value at risk.
  final bool showVarLine;

  /// Whether a line marks the expected shortfall.
  final bool showShortfallLine;

  /// Whether a line marks the mean.
  final bool showMeanLine;

  /// The colour of those lines.
  final Color referenceColor;

  /// How many pixels are taken off each side of a bar.
  final double barSpacing;

  /// The rounding of each bar's corners.
  final BorderRadius barRadius;

  /// About how many ticks to write on each axis.
  final int tickCount;

  /// Writes a return on the bottom axis; null writes a percentage.
  final String Function(double value)? valueFormatter;

  /// Style of an axis label.
  final TextStyle? axisLabelStyle;

  /// Colour of the grid ruled at each tick; null rules none.
  final Color? gridColor;

  /// Called as a touch moves over the bars, and with null when it leaves.
  final ValueChanged<HistogramTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched bar; null shows none.
  final Widget? Function(BuildContext context, HistogramTouchDetails details)?
  tooltipBuilder;

  /// How long the bars take to grow in; zero draws them at once.
  final Duration animationDuration;

  /// The easing of [animationDuration].
  final Curve animationCurve;

  /// Whether the first build grows in.
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
    final risk = ValueAtRisk.fromReturns(returns, confidence: confidence);
    final bins = varBins(
      returns,
      valueAtRisk: risk.valueAtRisk,
      tailColor: tailColor,
      binCount: binCount,
      binWidth: binWidth,
    );
    final format = valueFormatter ?? _percent;

    final histogram = HistogramChart(
      bins: bins,
      barColor: barColor,
      barSpacing: barSpacing,
      barRadius: barRadius,
      tickCount: tickCount,
      valueFormatter: format,
      axisLabelStyle: axisLabelStyle,
      gridColor: gridColor,
      referenceLines: [
        if (risk.count > 0) ...[
          if (showVarLine) risk.valueAtRisk,
          if (showShortfallLine) risk.expectedShortfall,
          if (showMeanLine) risk.mean,
        ],
      ],
      referenceColor: referenceColor,
      onTouch: onTouch,
      tooltipBuilder: tooltipBuilder,
      animationDuration: animationDuration,
      animationCurve: animationCurve,
      animateOnMount: animateOnMount,
    );

    final figures = (statsBuilder ?? (r) => defaultVarStats(r, format))(risk);

    Widget chart = LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : defaultHeight;
        // A box too short for the figures and a histogram under them shows
        // only the histogram, rather than overflowing.
        final room = height - padding.vertical;
        return Container(
          height: height,
          color: backgroundColor,
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showStats && room >= 120) ...[
                ConstrainedBox(
                  // Never more than part of the box, so a wrapped row cannot starve
                  // the histogram; what does not fit is clipped.
                  constraints: BoxConstraints(maxHeight: room * 0.4),
                  child: ClipRect(
                    child: _FiguresRow(
                      figures: figures,
                      labelStyle: seriesAxisLabelStyle.merge(statLabelStyle),
                      valueStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE9ECEF),
                      ).merge(statValueStyle),
                      spacing: statSpacing,
                    ),
                  ),
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

  static String _percent(double value) {
    final percent = value * 100;
    final text = percent == percent.roundToDouble()
        ? percent.toStringAsFixed(0)
        : percent.toStringAsFixed(1);
    return '$text%';
  }
}

/// The figures a [VarChart] shows by default.
List<RMultipleStat> defaultVarStats(
  ValueAtRisk risk,
  String Function(double value) format,
) {
  final level = '${(risk.confidence * 100).toStringAsFixed(0)}%';
  return [
    RMultipleStat('Returns', '${risk.count}'),
    RMultipleStat('VaR $level', format(risk.valueAtRisk)),
    RMultipleStat('CVaR $level', format(risk.expectedShortfall)),
    RMultipleStat('Mean', format(risk.mean)),
    RMultipleStat('Std dev', format(risk.standardDeviation)),
    RMultipleStat('Worst', format(risk.worst)),
  ];
}

class _FiguresRow extends StatelessWidget {
  const _FiguresRow({
    required this.figures,
    required this.labelStyle,
    required this.valueStyle,
    required this.spacing,
  });

  final List<RMultipleStat> figures;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: 6,
      children: [
        for (final figure in figures)
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(figure.label, style: labelStyle),
              Text(
                figure.value,
                style: figure.color == null
                    ? valueStyle
                    : valueStyle.copyWith(color: figure.color),
              ),
            ],
          ),
      ],
    );
  }
}
