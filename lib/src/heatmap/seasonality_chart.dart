import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'heatmap_chart.dart';
import 'heatmap_data.dart';

/// One period's result, placed in time.
@immutable
class SeasonalSample {
  /// Creates a sample of [value] at [time].
  const SeasonalSample({required this.time, required this.value});

  /// When the period was.
  final DateTime time;

  /// Its result — usually a return, as a fraction: 0.012 is 1.2%.
  final double value;
}

/// Turns a price series into the return of each period over the one before.
///
/// Each return is placed at the time of the later price. [times] and [prices]
/// are paired by position; a pair after a price that is not positive is
/// skipped.
List<SeasonalSample> seasonalReturnsFromPrices(
  List<DateTime> times,
  List<double> prices,
) {
  final count = math.min(times.length, prices.length);
  return [
    for (var i = 1; i < count; i++)
      if (prices[i - 1] > 0 && prices[i].isFinite)
        SeasonalSample(time: times[i], value: prices[i] / prices[i - 1] - 1),
  ];
}

/// Which two parts of the calendar a seasonality grid crosses.
enum SeasonalityGrid {
  /// A row per year, a column per month.
  monthByYear,

  /// A row per weekday, a column per hour.
  weekdayByHour,

  /// A row per weekday, a column per month.
  weekdayByMonth,
}

/// How the samples falling in one square are made into its value.
enum SeasonalityAggregate {
  /// Returns chained together: the square's total return.
  compound,

  /// Values added up.
  sum,

  /// The average value.
  mean,

  /// The middle value.
  median,

  /// The share of values above zero, from 0 to 1.
  winRate,

  /// How many samples fell there.
  count,
}

/// Makes [values] into one number, as [aggregate] says; null when there are
/// none.
double? seasonalAggregate(List<double> values, SeasonalityAggregate aggregate) {
  if (values.isEmpty) return null;
  switch (aggregate) {
    case SeasonalityAggregate.compound:
      return values.fold<double>(1, (product, r) => product * (1 + r)) - 1;
    case SeasonalityAggregate.sum:
      return values.fold<double>(0, (sum, v) => sum + v);
    case SeasonalityAggregate.mean:
      return values.fold<double>(0, (sum, v) => sum + v) / values.length;
    case SeasonalityAggregate.median:
      final sorted = [...values]..sort();
      final middle = sorted.length ~/ 2;
      return sorted.length.isOdd
          ? sorted[middle]
          : (sorted[middle - 1] + sorted[middle]) / 2;
    case SeasonalityAggregate.winRate:
      return values.where((v) => v > 0).length / values.length;
    case SeasonalityAggregate.count:
      return values.length.toDouble();
  }
}

/// The English month names a seasonality grid uses by default.
const List<String> seasonalityMonthLabels = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// The English weekday names a seasonality grid uses by default, Monday first.
const List<String> seasonalityWeekdayLabels = [
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun', //
];

/// Samples gathered into a grid, with what each row and column add up to.
@immutable
class SeasonalityTable {
  /// Creates a table from its parts; see [seasonalityTable].
  const SeasonalityTable({
    required this.rowLabels,
    required this.columnLabels,
    required this.values,
    required this.counts,
    required this.rowSummary,
    required this.columnSummary,
  });

  /// What each row is: a year, or a weekday.
  final List<String> rowLabels;

  /// What each column is: a month, or an hour.
  final List<String> columnLabels;

  /// Each square's value, a list of rows each holding its columns; null where
  /// no sample fell.
  final List<List<double?>> values;

  /// How many samples fell in each square.
  final List<List<int>> counts;

  /// Each row's samples taken together, with the table's aggregate — a year's
  /// return, say.
  final List<double?> rowSummary;

  /// The average of each column's squares — the typical January, say.
  final List<double?> columnSummary;

  /// How many rows there are.
  int get rowCount => rowLabels.length;

  /// How many columns there are.
  int get columnCount => columnLabels.length;
}

/// Gathers [samples] into the [grid] of calendar parts, making each square's
/// samples into one value with [aggregate].
///
/// Years run from the earliest sample's to the latest's, every year between
/// included. Samples that are not finite are skipped.
SeasonalityTable seasonalityTable(
  List<SeasonalSample> samples, {
  SeasonalityGrid grid = SeasonalityGrid.monthByYear,
  SeasonalityAggregate aggregate = SeasonalityAggregate.compound,
  List<String> monthLabels = seasonalityMonthLabels,
  List<String> weekdayLabels = seasonalityWeekdayLabels,
}) {
  final valid = [
    for (final sample in samples)
      if (sample.value.isFinite) sample,
  ];

  String label(List<String> labels, int index, String fallback) =>
      index < labels.length ? labels[index] : fallback;

  final List<String> rows;
  final List<String> columns;
  final int Function(DateTime time) rowOf;
  final int Function(DateTime time) columnOf;
  switch (grid) {
    case SeasonalityGrid.monthByYear:
      var first = 0;
      var last = -1;
      if (valid.isNotEmpty) {
        first = valid.map((s) => s.time.year).reduce(math.min);
        last = valid.map((s) => s.time.year).reduce(math.max);
      }
      rows = [for (var year = first; year <= last; year++) '$year'];
      columns = [
        for (var m = 0; m < 12; m++) label(monthLabels, m, '${m + 1}'),
      ];
      rowOf = (time) => time.year - first;
      columnOf = (time) => time.month - 1;
    case SeasonalityGrid.weekdayByHour:
      rows = [for (var d = 0; d < 7; d++) label(weekdayLabels, d, '${d + 1}')];
      columns = [for (var h = 0; h < 24; h++) h.toString().padLeft(2, '0')];
      rowOf = (time) => time.weekday - 1;
      columnOf = (time) => time.hour;
    case SeasonalityGrid.weekdayByMonth:
      rows = [for (var d = 0; d < 7; d++) label(weekdayLabels, d, '${d + 1}')];
      columns = [
        for (var m = 0; m < 12; m++) label(monthLabels, m, '${m + 1}'),
      ];
      rowOf = (time) => time.weekday - 1;
      columnOf = (time) => time.month - 1;
  }

  final buckets = [
    for (var r = 0; r < rows.length; r++)
      [for (var c = 0; c < columns.length; c++) <double>[]],
  ];
  final byRow = [for (var r = 0; r < rows.length; r++) <double>[]];
  for (final sample in valid) {
    final r = rowOf(sample.time);
    final c = columnOf(sample.time);
    buckets[r][c].add(sample.value);
    byRow[r].add(sample.value);
  }

  final values = [
    for (final row in buckets)
      [for (final bucket in row) seasonalAggregate(bucket, aggregate)],
  ];

  return SeasonalityTable(
    rowLabels: rows,
    columnLabels: columns,
    values: values,
    counts: [
      for (final row in buckets) [for (final bucket in row) bucket.length],
    ],
    rowSummary: [
      for (final values in byRow) seasonalAggregate(values, aggregate),
    ],
    columnSummary: [
      for (var c = 0; c < columns.length; c++)
        seasonalAggregate([
          for (final row in values)
            if (row[c] != null) row[c]!,
        ], SeasonalityAggregate.mean),
    ],
  );
}

/// What a touch on a [SeasonalityChart] landed on.
@immutable
class SeasonalityTouchDetails {
  /// Creates the details of a touch on the square at [row] and [column].
  const SeasonalityTouchDetails({
    required this.row,
    required this.column,
    required this.rowLabel,
    required this.columnLabel,
    required this.value,
    required this.count,
    required this.isRowSummary,
    required this.isColumnSummary,
    required this.rect,
  });

  /// The row, counted from the top; the summary row is one past the last.
  final int row;

  /// The column, counted from the left; the summary column is one past the
  /// last.
  final int column;

  /// What the row is.
  final String rowLabel;

  /// What the column is.
  final String columnLabel;

  /// The value there; null where no sample fell.
  final double? value;

  /// How many samples fell there; zero for a summary.
  final int count;

  /// Whether this is the summary column, holding a whole row's value.
  final bool isRowSummary;

  /// Whether this is the summary row, holding a column's average.
  final bool isColumnSummary;

  /// The square, in the chart's local pixels.
  final Rect rect;
}

/// How results fall across the calendar: the average January, the best hour
/// of a Tuesday, each year month by month.
///
/// ```dart
/// SeasonalityChart(
///   samples: seasonalReturnsFromPrices(dailyTimes, dailyCloses),
/// );
/// ```
///
/// Squares are coloured from [lossColor] through [neutralColor] to
/// [profitColor], with zero in the middle. A summary column holds each row's
/// whole value and a summary row each column's average. The chart fills the box
/// it is given, and is [defaultHeight] high in a box with no height of its own.
class SeasonalityChart extends StatelessWidget {
  /// Creates a seasonality grid of [samples].
  const SeasonalityChart({
    super.key,
    required this.samples,
    this.grid = SeasonalityGrid.monthByYear,
    this.aggregate,
    this.monthLabels = seasonalityMonthLabels,
    this.weekdayLabels = seasonalityWeekdayLabels,
    this.profitColor = const Color(0xFF2F9E44),
    this.lossColor = const Color(0xFFE03131),
    this.neutralColor = const Color(0x22909196),
    this.limit,
    this.showRowSummary = true,
    this.rowSummaryLabel = 'Total',
    this.showColumnSummary = true,
    this.columnSummaryLabel = 'Avg',
    this.showValues = true,
    this.valueFormatter,
    this.labelStyle,
    this.axisLabelStyle,
    this.rowAxisWidth = 40,
    this.columnAxisHeight = 20,
    this.spacing = 2,
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

  /// The results to gather, each placed in time.
  final List<SeasonalSample> samples;

  /// Which parts of the calendar are crossed.
  final SeasonalityGrid grid;

  /// How a square's samples become its value; null chains returns for
  /// [SeasonalityGrid.monthByYear] and averages them otherwise.
  final SeasonalityAggregate? aggregate;

  /// The month names, January first.
  final List<String> monthLabels;

  /// The weekday names, Monday first.
  final List<String> weekdayLabels;

  /// The colour of the best squares.
  final Color profitColor;

  /// The colour of the worst.
  final Color lossColor;

  /// The colour at zero.
  final Color neutralColor;

  /// The value painted at full strength either way; null takes the largest
  /// square, so that one extreme month does not wash out the rest when set.
  final double? limit;

  /// Whether a column at the right holds each row's whole value.
  final bool showRowSummary;

  /// What that column is called.
  final String rowSummaryLabel;

  /// Whether a row at the bottom holds each column's average.
  final bool showColumnSummary;

  /// What that row is called.
  final String columnSummaryLabel;

  /// Whether values are written in the squares.
  final bool showValues;

  /// Writes a value; null writes a percentage for returns and win rates, and
  /// a whole number for counts.
  final String Function(double value)? valueFormatter;

  /// Style of the values in the squares; null picks black or white per square.
  final TextStyle? labelStyle;

  /// Style of the row and column names.
  final TextStyle? axisLabelStyle;

  /// Room held for the row names.
  final double rowAxisWidth;

  /// Room held for the column names.
  final double columnAxisHeight;

  /// The gap between squares.
  final double spacing;

  /// The rounding of each square's corners, as drawn on the screen, passed
  /// through to the heatmap underneath.
  final BorderRadius radius;

  /// Called as a touch moves over the squares, and with null when it leaves.
  final ValueChanged<SeasonalityTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched square; null shows none.
  final Widget? Function(BuildContext context, SeasonalityTouchDetails details)?
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

  /// The aggregate in use, once the default is resolved.
  SeasonalityAggregate get resolvedAggregate =>
      aggregate ??
      (grid == SeasonalityGrid.monthByYear
          ? SeasonalityAggregate.compound
          : SeasonalityAggregate.mean);

  @override
  Widget build(BuildContext context) {
    final how = resolvedAggregate;
    final table = seasonalityTable(
      samples,
      grid: grid,
      aggregate: how,
      monthLabels: monthLabels,
      weekdayLabels: weekdayLabels,
    );

    final columns = table.columnCount + (showRowSummary ? 1 : 0);
    final rows = table.rowCount + (showColumnSummary ? 1 : 0);
    final cells = <HeatmapCell>[
      for (var r = 0; r < table.rowCount; r++) ...[
        for (var c = 0; c < table.columnCount; c++)
          HeatmapCell(x: c, y: r, value: table.values[r][c]),
        if (showRowSummary)
          HeatmapCell(x: table.columnCount, y: r, value: table.rowSummary[r]),
      ],
      if (showColumnSummary)
        for (var c = 0; c < table.columnCount; c++)
          HeatmapCell(x: c, y: table.rowCount, value: table.columnSummary[c]),
    ];

    // Win rates and counts are read against their own middle, not zero.
    final double centre;
    var reach = limit;
    switch (how) {
      case SeasonalityAggregate.winRate:
        centre = 0.5;
        reach ??= 0.5;
      case SeasonalityAggregate.count:
        centre = 0;
        reach ??= _largest(cells, 0);
      default:
        centre = 0;
        reach ??= _largest(cells, 0);
    }
    if (!(reach > 0)) reach = 1;

    final scale = how == SeasonalityAggregate.count
        ? HeatmapGradientScale(colors: [neutralColor, profitColor])
        : HeatmapGradientScale(colors: [lossColor, neutralColor, profitColor]);
    final min = how == SeasonalityAggregate.count ? 0.0 : centre - reach;
    final max = centre + reach;

    final format = valueFormatter ?? _defaultFormatter(how);
    final axisStyle = axisLabelStyle;

    String labelOfColumn(int c) =>
        c < table.columnCount ? table.columnLabels[c] : rowSummaryLabel;
    String labelOfRow(int r) =>
        r < table.rowCount ? table.rowLabels[r] : columnSummaryLabel;

    SeasonalityTouchDetails details(HeatmapTouchDetails touch) =>
        SeasonalityTouchDetails(
          row: touch.y,
          column: touch.x,
          rowLabel: labelOfRow(touch.y),
          columnLabel: labelOfColumn(touch.x),
          value: touch.value,
          count: touch.y < table.rowCount && touch.x < table.columnCount
              ? table.counts[touch.y][touch.x]
              : 0,
          isRowSummary: touch.x >= table.columnCount,
          isColumnSummary: touch.y >= table.rowCount,
          rect: touch.rect,
        );

    final touch = onTouch;
    final builder = tooltipBuilder;
    return HeatmapChart(
      cells: cells,
      columns: columns,
      rows: rows,
      scale: scale,
      minValue: min,
      maxValue: max,
      xAxis: HeatmapAxis(
        labelBuilder: labelOfColumn,
        size: columnAxisHeight,
        style: axisStyle,
        interval: table.columnCount > 12 ? 3 : 1,
      ),
      yAxis: HeatmapAxis(
        labelBuilder: labelOfRow,
        size: rowAxisWidth,
        style: axisStyle,
      ),
      spacing: spacing,
      radius: radius,
      labelBuilder: showValues
          ? (cell) => cell.isEmpty ? null : format(cell.value!)
          : null,
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

  static double _largest(List<HeatmapCell> cells, double centre) {
    var largest = 0.0;
    for (final cell in cells) {
      if (cell.isEmpty) continue;
      largest = math.max(largest, (cell.value! - centre).abs());
    }
    return largest;
  }

  static String Function(double value) _defaultFormatter(
    SeasonalityAggregate aggregate,
  ) {
    if (aggregate == SeasonalityAggregate.count) {
      return (value) => value.round().toString();
    }
    if (aggregate == SeasonalityAggregate.winRate) {
      return (value) => '${(value * 100).round()}%';
    }
    return (value) {
      final percent = value * 100;
      return '${percent > 0 ? '+' : ''}'
          '${percent.toStringAsFixed(percent.abs() >= 10 ? 0 : 1)}%';
    };
  }
}
