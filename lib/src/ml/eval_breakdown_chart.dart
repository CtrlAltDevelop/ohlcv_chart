import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../utils/plot_scaffold.dart';

/// How an evaluation went in one category: tasks passed, failed and skipped.
@immutable
class EvalCategory {
  /// Creates a category called [name].
  const EvalCategory({
    required this.name,
    required this.passed,
    required this.failed,
    this.skipped = 0,
    this.data,
  });

  /// What the category is called.
  final String name;

  /// How many tasks passed.
  final int passed;

  /// How many failed.
  final int failed;

  /// How many errored or were not run; counted out of the pass rate.
  final int skipped;

  /// Anything the app wants back when this category is touched.
  final Object? data;

  /// The tasks that ran: passed and failed.
  int get attempted => math.max(0, passed) + math.max(0, failed);

  /// Every task, run or not.
  int get total => attempted + math.max(0, skipped);

  /// The share of attempted tasks that passed, 0 to 1; null when none ran.
  double? get passRate =>
      attempted == 0 ? null : math.max(0, passed) / attempted;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EvalCategory &&
          other.name == name &&
          other.passed == passed &&
          other.failed == failed &&
          other.skipped == skipped &&
          other.data == data;

  @override
  int get hashCode => Object.hash(name, passed, failed, skipped, data);
}

/// The Wilson score interval for [passed] of [attempted] at the given
/// [z] — 1.96 is 95% — as (low, high). With nothing attempted it is (0, 1).
///
/// Unlike the plain proportion it stays inside 0..1 and is honest about small
/// samples: three of three passing is not 100% sure.
(double, double) wilsonInterval(int passed, int attempted, {double z = 1.96}) {
  if (attempted <= 0) return (0, 1);
  final n = attempted.toDouble();
  final p = (passed.clamp(0, attempted)) / n;
  final z2 = z * z;
  final denominator = 1 + z2 / n;
  final centre = (p + z2 / (2 * n)) / denominator;
  final margin =
      z * math.sqrt(p * (1 - p) / n + z2 / (4 * n * n)) / denominator;
  return ((centre - margin).clamp(0.0, 1.0), (centre + margin).clamp(0.0, 1.0));
}

/// The pass rate over every attempted task in [categories]; null when none ran.
double? overallPassRate(Iterable<EvalCategory> categories) {
  var passed = 0;
  var attempted = 0;
  for (final c in categories) {
    passed += math.max(0, c.passed);
    attempted += c.attempted;
  }
  return attempted == 0 ? null : passed / attempted;
}

/// [categories] ordered worst pass rate first; categories where nothing ran go
/// last. The sort is stable.
List<EvalCategory> sortedByPassRate(Iterable<EvalCategory> categories) {
  final list = categories.toList();
  final order = [for (var i = 0; i < list.length; i++) i]
    ..sort((a, b) {
      final ra = list[a].passRate;
      final rb = list[b].passRate;
      if (ra == null && rb == null) return a.compareTo(b);
      if (ra == null) return 1;
      if (rb == null) return -1;
      final c = ra.compareTo(rb);
      return c != 0 ? c : a.compareTo(b);
    });
  return [for (final i in order) list[i]];
}

/// What a touch on an [EvalBreakdownChart] landed on.
@immutable
class EvalTouchDetails {
  /// Creates the details of a touch on a category.
  const EvalTouchDetails({
    required this.index,
    required this.category,
    required this.low,
    required this.high,
  });

  /// The category's position in the order drawn.
  final int index;

  /// The category.
  final EvalCategory category;

  /// The low end of its 95% pass-rate interval.
  final double low;

  /// The high end.
  final double high;
}

/// An evaluation by category: a bar of passed, failed and skipped tasks for
/// each, with the pass rate and how many tasks stand behind it, the worst
/// category first.
///
/// ```dart
/// EvalBreakdownChart(
///   categories: const [
///     EvalCategory(name: 'Math', passed: 71, failed: 29),
///     EvalCategory(name: 'Coding', passed: 88, failed: 12, skipped: 3),
///     EvalCategory(name: 'Safety', passed: 96, failed: 4),
///   ],
///   threshold: 0.8,
/// );
/// ```
///
/// The chart fills the box it is given, and is [defaultHeight] high in a box
/// with no height of its own.
class EvalBreakdownChart extends StatelessWidget {
  /// Creates a chart of [categories].
  const EvalBreakdownChart({
    super.key,
    required this.categories,
    this.sortWorstFirst = true,
    this.threshold,
    this.showOverall = true,
    this.overallLabel = 'Overall',
    this.passedColor = const Color(0xFF2F9E44),
    this.failedColor = const Color(0xFFE03131),
    this.skippedColor = const Color(0xFF5C6570),
    this.thresholdColor = const Color(0xFFF2B01E),
    this.showCounts = true,
    this.rateFormatter,
    this.labelStyle,
    this.nameWidth = 96,
    this.rateWidth = 92,
    this.barHeight = 18,
    this.maxBarHeight = 34,
    this.rowGap = 8,
    this.barRadius = const BorderRadius.all(Radius.circular(3)),
    this.hoverColor = const Color(0x14FFFFFF),
    this.onTouch,
    this.tooltipBuilder,
    this.tooltipMargin = 10,
    this.animationDuration = Duration.zero,
    this.animationCurve = Curves.easeOutCubic,
    this.animateOnMount = true,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.defaultHeight = 260,
    this.semanticLabel,
  });

  /// The categories.
  final List<EvalCategory> categories;

  /// Whether the worst pass rate is at the top.
  final bool sortWorstFirst;

  /// A pass rate to hold the categories to, 0 to 1, drawn across every bar.
  final double? threshold;

  /// Whether the overall pass rate is written above the bars.
  final bool showOverall;

  /// What the overall figure is called.
  final String overallLabel;

  /// The colour of passed tasks.
  final Color passedColor;

  /// The colour of failed tasks.
  final Color failedColor;

  /// The colour of skipped tasks.
  final Color skippedColor;

  /// The colour of the threshold line.
  final Color thresholdColor;

  /// Whether the task count is written with the pass rate.
  final bool showCounts;

  /// Writes a pass rate, 0 to 1; null writes a percentage with one decimal.
  final String Function(double rate)? rateFormatter;

  /// Style of the names and figures.
  final TextStyle? labelStyle;

  /// Room held for the category names.
  final double nameWidth;

  /// Room held for the pass rate and count.
  final double rateWidth;

  /// How short a bar may be, when there are more categories than the box holds
  /// comfortably.
  final double barHeight;

  /// How tall a bar may be: the bars grow from [barHeight] to this to fill the
  /// box, so a few categories are not left at the top of it.
  final double maxBarHeight;

  /// The gap between bars.
  final double rowGap;

  /// The rounding of a bar's corners.
  final BorderRadius barRadius;

  /// The colour behind the row under the pointer.
  final Color hoverColor;

  /// Called as a touch moves over the rows, and with null when it leaves.
  final ValueChanged<EvalTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched row; null shows none.
  final Widget? Function(BuildContext context, EvalTouchDetails details)?
  tooltipBuilder;

  /// How far the card sits from the row.
  final double tooltipMargin;

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

  /// How tall a bar is in a plot [height] high holding [count] categories.
  double barHeightFor(double height, int count, double header) {
    if (count == 0) return barHeight;
    final room = (height - header) / count - rowGap;
    return room.clamp(barHeight, math.max(barHeight, maxBarHeight));
  }

  @override
  Widget build(BuildContext context) {
    final rows = sortWorstFirst ? sortedByPassRate(categories) : categories;
    final overall = overallPassRate(categories);
    final headerHeight = showOverall ? 26.0 : 0.0;

    Rect rowRect(int i, Rect plot) {
      final bar = barHeightFor(plot.height, rows.length, headerHeight);
      final pitch = bar + rowGap;
      return Rect.fromLTWH(
        plot.left,
        plot.top + headerHeight + i * pitch - rowGap / 2,
        plot.width,
        bar + rowGap,
      );
    }

    EvalTouchDetails? hit(Offset local, Rect plot) {
      for (var i = 0; i < rows.length; i++) {
        if (!rowRect(i, plot).contains(local)) continue;
        final c = rows[i];
        final (low, high) = wilsonInterval(c.passed, c.attempted);
        return EvalTouchDetails(index: i, category: c, low: low, high: high);
      }
      return null;
    }

    return PlotScaffold<EvalTouchDetails>(
      restartKey: Object.hashAll([...categories, sortWorstFirst]),
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
      anchorOf: (d, plot) => rowRect(d.index, plot),
      painter: (plot, t, text, hovered) => _EvalPainter(
        chart: this,
        rows: rows,
        overall: overall,
        headerHeight: headerHeight,
        hovered: hovered?.index,
        plot: plot,
        animation: t,
        text: text,
        backgroundColor: backgroundColor,
      ),
    );
  }
}

class _EvalPainter extends PlotPainter {
  _EvalPainter({
    required this.chart,
    required this.rows,
    required this.overall,
    required this.headerHeight,
    required this.hovered,
    required super.plot,
    required super.animation,
    required super.text,
    super.backgroundColor,
  });

  final EvalBreakdownChart chart;
  final List<EvalCategory> rows;
  final double? overall;
  final double headerHeight;
  final int? hovered;

  String _rate(double r) =>
      chart.rateFormatter?.call(r) ?? '${(r * 100).toStringAsFixed(1)}%';

  @override
  void paintPlot(Canvas canvas, Size size) {
    final base = const TextStyle(
      fontSize: 12,
      color: Color(0xFFD0D5DB),
    ).merge(chart.labelStyle);
    final t = animation.clamp(0.0, 1.0);

    if (chart.showOverall) {
      final value = overall == null ? '–' : _rate(overall!);
      final tp = text.get(
        '${chart.overallLabel}  $value',
        base.copyWith(
          fontWeight: FontWeight.w700,
          color: const Color(0xFFFFFFFF),
        ),
      );
      tp.paint(canvas, Offset(plot.left, plot.top + 2));
    }

    final bar = chart.barHeightFor(plot.height, rows.length, headerHeight);
    final barLeft = plot.left + chart.nameWidth;
    final barRight = math.max(barLeft, plot.right - chart.rateWidth);
    final barWidth = barRight - barLeft;
    final pitch = bar + chart.rowGap;

    // The longest category sets the scale, so every bar counts in the same unit.
    var longest = 0;
    for (final c in rows) {
      longest = math.max(longest, c.total);
    }

    for (var i = 0; i < rows.length; i++) {
      final c = rows[i];
      final top = plot.top + headerHeight + i * pitch;
      if (top + bar > plot.bottom + 1) break;

      if (hovered == i) {
        canvas.drawRect(
          Rect.fromLTRB(
            plot.left,
            top - chart.rowGap / 2,
            plot.right,
            top + bar + chart.rowGap / 2,
          ),
          Paint()..color = chart.hoverColor,
        );
      }

      final name = text.get(c.name, base);
      var shown = name;
      if (name.width > chart.nameWidth - 8) {
        shown = text.get(_fit(c.name, base, chart.nameWidth - 8), base);
      }
      shown.paint(canvas, Offset(plot.left, top + (bar - shown.height) / 2));

      if (longest > 0 && barWidth > 0) {
        final scale = barWidth / longest * t;
        var x = barLeft;
        final outline = RRect.fromRectAndRadius(
          Rect.fromLTWH(barLeft, top, c.total * scale, bar),
          chart.barRadius.topLeft,
        );
        canvas
          ..save()
          ..clipRRect(outline);
        for (final (count, color) in [
          (math.max(0, c.passed), chart.passedColor),
          (math.max(0, c.failed), chart.failedColor),
          (math.max(0, c.skipped), chart.skippedColor),
        ]) {
          if (count == 0) continue;
          final w = count * scale;
          canvas.drawRect(
            Rect.fromLTWH(x, top, w, bar),
            Paint()..color = color,
          );
          x += w;
        }
        canvas.restore();
      }

      final r = c.passRate;
      final figure = r == null ? '–' : _rate(r);
      final count = chart.showCounts ? '  n=${c.attempted}' : '';
      final tp = text.get(
        '$figure$count',
        base.copyWith(
          fontWeight: FontWeight.w600,
          color: r == null
              ? const Color(0xFF8B95A1)
              : (chart.threshold != null && r < chart.threshold!
                    ? chart.failedColor
                    : base.color),
        ),
      );
      tp.paint(canvas, Offset(barRight + 8, top + (bar - tp.height) / 2));
    }

    // The threshold: where a bar would have to reach its passed part to meet it
    // is relative to each bar, so a line is drawn on the pass-rate scale of the
    // longest bar's width.
    final th = chart.threshold;
    if (th != null && th > 0 && th <= 1 && barWidth > 0 && longest > 0) {
      // Drawn as a tick at each bar: threshold × that bar's total.
      for (var i = 0; i < rows.length; i++) {
        final c = rows[i];
        if (c.attempted == 0) continue;
        final top = plot.top + headerHeight + i * pitch;
        if (top + bar > plot.bottom + 1) break;
        final x = barLeft + c.attempted * th * (barWidth / longest) * t;
        canvas.drawLine(
          Offset(x, top - 2),
          Offset(x, top + bar + 2),
          Paint()
            ..color = chart.thresholdColor
            ..strokeWidth = 2,
        );
      }
    }
  }

  String _fit(String s, TextStyle style, double width) {
    var out = s;
    while (out.length > 1) {
      out = out.substring(0, out.length - 1);
      final tp = text.get('$out…', style);
      if (tp.width <= width) return '$out…';
    }
    return '…';
  }
}
