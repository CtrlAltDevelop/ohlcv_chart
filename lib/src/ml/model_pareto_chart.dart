import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../treemap/treemap_data.dart' show treemapPalette;
import '../utils/plot_scaffold.dart';
import '../utils/xy_plot.dart';

/// One model on a cost against quality plot.
@immutable
class ModelPoint {
  /// Creates a model [name] that costs [cost] and scores [score].
  const ModelPoint({
    required this.name,
    required this.cost,
    required this.score,
    this.size,
    this.group,
    this.color,
    this.data,
  });

  /// What the model is called.
  final String name;

  /// What it costs: a price per million tokens, a latency, a number of
  /// parameters. Lower is better, and positive on a logarithmic axis.
  final double cost;

  /// How good it is: a benchmark score, an Elo rating. Higher is better.
  final double score;

  /// What the bubble's area shows — the context window, the parameter count;
  /// null draws every model the same size.
  final double? size;

  /// Which family or provider it belongs to; models of a group share a colour.
  final String? group;

  /// A colour of this model's own, over its group's.
  final Color? color;

  /// Anything the app wants back when this model is touched.
  final Object? data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelPoint &&
          other.name == name &&
          other.cost == cost &&
          other.score == score &&
          other.size == size &&
          other.group == group &&
          other.color == color &&
          other.data == data;

  @override
  int get hashCode => Object.hash(name, cost, score, size, group, color, data);
}

/// The indices of the models on the Pareto frontier: those no other model
/// beats by being both cheaper and better. By rising cost.
///
/// A model whose cost or score is not finite is never on it. Of two with the
/// same cost only the higher score is; of two with the same score only the
/// cheaper.
List<int> paretoIndices(List<ModelPoint> models) {
  final order =
      [
        for (var i = 0; i < models.length; i++)
          if (models[i].cost.isFinite && models[i].score.isFinite) i,
      ]..sort((a, b) {
        final byCost = models[a].cost.compareTo(models[b].cost);
        if (byCost != 0) return byCost;
        return models[b].score.compareTo(models[a].score);
      });
  final frontier = <int>[];
  var best = double.negativeInfinity;
  for (final i in order) {
    if (models[i].score > best) {
      frontier.add(i);
      best = models[i].score;
    }
  }
  return frontier;
}

/// What a touch on a [ModelParetoChart] landed on.
@immutable
class ModelTouchDetails {
  /// Creates the details of a touch on the model at [index].
  const ModelTouchDetails({
    required this.index,
    required this.model,
    required this.onFrontier,
    required this.beatenBy,
  });

  /// The model's position in the chart's models.
  final int index;

  /// The model touched.
  final ModelPoint model;

  /// Whether nothing is both cheaper and better.
  final bool onFrontier;

  /// The best frontier model that costs no more and scores at least as well —
  /// what the same money buys instead; null for a model on the frontier.
  final ModelPoint? beatenBy;
}

/// Models by what they cost and how good they are, with the Pareto frontier
/// traced through the ones nothing beats.
///
/// ```dart
/// ModelParetoChart(
///   models: const [
///     ModelPoint(name: 'Large', cost: 15, score: 88, size: 200000, group: 'A'),
///     ModelPoint(name: 'Small', cost: 0.25, score: 71, size: 128000, group: 'A'),
///     ModelPoint(name: 'Open 70B', cost: 0.9, score: 79, group: 'B'),
///   ],
///   costFormatter: (v) => '\$$v',
/// );
/// ```
///
/// Cost is on a logarithmic axis by default, since prices span decades. A model
/// on the frontier is the cheapest way to get its score; the others are drawn
/// faintly. The chart fills the box it is given, and is [defaultHeight] high in
/// a box with no height of its own.
class ModelParetoChart extends StatelessWidget {
  /// Creates a chart of [models].
  const ModelParetoChart({
    super.key,
    required this.models,
    this.logCost = true,
    this.minRadius = 6,
    this.maxRadius = 20,
    this.palette = treemapPalette,
    this.showFrontier = true,
    this.frontierColor = const Color(0x99FFFFFF),
    this.dimOpacity = 0.35,
    this.labelAll = false,
    this.labelStyle,
    this.showLegend = true,
    this.legendStyle,
    this.showAxes = true,
    this.axisWidth = 44,
    this.axisHeight = 18,
    this.tickCount = 5,
    this.costFormatter,
    this.scoreFormatter,
    this.axisLabelStyle,
    this.xAxisTitle = 'Cost',
    this.yAxisTitle = 'Score',
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
    this.defaultHeight = 300,
    this.semanticLabel,
  });

  /// The models.
  final List<ModelPoint> models;

  /// Whether cost is on a logarithmic axis. Models that cost nothing or less
  /// are not drawn on one.
  final bool logCost;

  /// The radius of the smallest bubble.
  final double minRadius;

  /// The radius of the largest.
  final double maxRadius;

  /// Colours taken in turn by groups.
  final List<Color> palette;

  /// Whether the frontier is traced.
  final bool showFrontier;

  /// The colour of the frontier line.
  final Color frontierColor;

  /// How opaque a model off the frontier is drawn.
  final double dimOpacity;

  /// Whether every model is named, not only those on the frontier.
  final bool labelAll;

  /// Style of a model's name.
  final TextStyle? labelStyle;

  /// Whether the groups are listed in the corner.
  final bool showLegend;

  /// Style of the legend.
  final TextStyle? legendStyle;

  /// Whether the two axes are drawn.
  final bool showAxes;

  /// How much room the score axis takes.
  final double axisWidth;

  /// How much room the cost axis takes.
  final double axisHeight;

  /// About how many ticks to write on each axis.
  final int tickCount;

  /// Writes a cost; null writes at most two decimals.
  final String Function(double value)? costFormatter;

  /// Writes a score; null writes at most two decimals.
  final String Function(double value)? scoreFormatter;

  /// Style of an axis label.
  final TextStyle? axisLabelStyle;

  /// Written under the cost axis.
  final String? xAxisTitle;

  /// Written up the score axis.
  final String? yAxisTitle;

  /// Style of an axis title.
  final TextStyle? axisTitleStyle;

  /// Colour of the grid ruled at each tick; null rules none.
  final Color? gridColor;

  /// Called as a touch moves over the models, and with null when it leaves.
  final ValueChanged<ModelTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched model; null shows none.
  final Widget? Function(BuildContext context, ModelTouchDetails details)?
  tooltipBuilder;

  /// How far the card sits from the bubble.
  final double tooltipMargin;

  /// How long the bubbles take to grow in; zero draws them at once.
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
    // The models that can be placed: finite, and positive cost on a log axis.
    final drawn = [
      for (var i = 0; i < models.length; i++)
        if (models[i].cost.isFinite &&
            models[i].score.isFinite &&
            (!logCost || models[i].cost > 0))
          i,
    ];
    final frontier = paretoIndices([for (final i in drawn) models[i]]);
    final onFrontier = {for (final f in frontier) drawn[f]};

    var minCost = double.infinity;
    var maxCost = double.negativeInfinity;
    var minScore = double.infinity;
    var maxScore = double.negativeInfinity;
    var largest = 0.0;
    for (final i in drawn) {
      final m = models[i];
      minCost = math.min(minCost, m.cost);
      maxCost = math.max(maxCost, m.cost);
      minScore = math.min(minScore, m.score);
      maxScore = math.max(maxScore, m.score);
      if (m.size != null && m.size!.isFinite) {
        largest = math.max(largest, m.size!);
      }
    }
    if (drawn.isEmpty) {
      minCost = logCost ? 0.1 : 0;
      maxCost = logCost ? 10 : 1;
      minScore = 0;
      maxScore = 100;
    }
    if (minCost == maxCost) {
      if (logCost) {
        minCost /= 2;
        maxCost *= 2;
      } else {
        minCost -= 1;
        maxCost += 1;
      }
    }
    final scoreRange = paddedRange([minScore, maxScore], pad: 0.12);
    double x0 = minCost, x1 = maxCost;
    if (logCost) {
      final pad = math.pow(maxCost / minCost, 0.1).toDouble();
      x0 = minCost / pad;
      x1 = maxCost * pad;
    } else {
      final r = paddedRange([minCost, maxCost], pad: 0.08);
      x0 = r.min;
      x1 = r.max;
    }

    final groups = <String>[];
    for (final m in models) {
      final g = m.group;
      if (g != null && !groups.contains(g)) groups.add(g);
    }
    Color colorOf(ModelPoint m) {
      if (m.color != null) return m.color!;
      final g = m.group;
      if (g == null || palette.isEmpty) return const Color(0xFF4C86CD);
      return palette[groups.indexOf(g) % palette.length];
    }

    double radiusOf(ModelPoint m) {
      final s = m.size;
      if (s == null || !s.isFinite || s <= 0 || largest <= 0) return minRadius;
      final share = (s / largest).clamp(0.0, 1.0);
      return minRadius + (maxRadius - minRadius) * math.sqrt(share);
    }

    Offset? at(Rect plot, ModelPoint m) {
      final x = logCost
          ? mapAcrossLog(m.cost, x0, x1, plot.left, plot.right)
          : mapAcross(m.cost, x0, x1, plot.left, plot.right);
      if (x == null) return null;
      final y = mapAcross(
        m.score,
        scoreRange.min,
        scoreRange.max,
        plot.bottom,
        plot.top,
      );
      return Offset(x, y);
    }

    ModelTouchDetails details(int index) {
      final model = models[index];
      ModelPoint? beaten;
      if (!onFrontier.contains(index)) {
        // The best frontier model that is no dearer: what the same money buys.
        for (final f in frontier) {
          final m = models[drawn[f]];
          if (m.cost <= model.cost && m.score >= model.score) {
            if (beaten == null || m.score > beaten.score) beaten = m;
          }
        }
      }
      return ModelTouchDetails(
        index: index,
        model: model,
        onFrontier: onFrontier.contains(index),
        beatenBy: beaten,
      );
    }

    ModelTouchDetails? hit(Offset local, Rect plot) {
      int? best;
      var closest = double.infinity;
      for (final i in drawn) {
        final o = at(plot, models[i]);
        if (o == null) continue;
        final d = (o - local).distance;
        if (d <= radiusOf(models[i]) + 4 && d < closest) {
          closest = d;
          best = i;
        }
      }
      return best == null ? null : details(best);
    }

    return PlotScaffold<ModelTouchDetails>(
      restartKey: Object.hashAll([...models, logCost]),
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
        final o = at(plot, d.model) ?? plot.center;
        return Rect.fromCircle(center: o, radius: radiusOf(d.model));
      },
      painter: (plot, t, text, hovered) => _ParetoPainter(
        chart: this,
        drawn: drawn,
        frontier: [for (final f in frontier) drawn[f]],
        groups: groups,
        x0: x0,
        x1: x1,
        y0: scoreRange.min,
        y1: scoreRange.max,
        place: (m) => at(plot, m),
        radiusOf: radiusOf,
        colorOf: colorOf,
        hovered: hovered?.index,
        plot: plot,
        animation: t,
        text: text,
        backgroundColor: backgroundColor,
      ),
    );
  }
}

class _ParetoPainter extends PlotPainter {
  _ParetoPainter({
    required this.chart,
    required this.drawn,
    required this.frontier,
    required this.groups,
    required this.x0,
    required this.x1,
    required this.y0,
    required this.y1,
    required this.place,
    required this.radiusOf,
    required this.colorOf,
    required this.hovered,
    required super.plot,
    required super.animation,
    required super.text,
    super.backgroundColor,
  });

  final ModelParetoChart chart;
  final List<int> drawn;
  final List<int> frontier;
  final List<String> groups;
  final double x0, x1, y0, y1;
  final Offset? Function(ModelPoint m) place;
  final double Function(ModelPoint m) radiusOf;
  final Color Function(ModelPoint m) colorOf;
  final int? hovered;

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
      xFormatter: chart.costFormatter,
      yFormatter: chart.scoreFormatter,
      labelStyle: chart.axisLabelStyle,
      xTitle: chart.xAxisTitle,
      yTitle: chart.yAxisTitle,
      titleStyle: chart.axisTitleStyle,
      axisWidth: 44,
      axisHeight: chart.axisHeight,
      logX: chart.logCost,
    );

    final t = animation.clamp(0.0, 1.0);
    final onFrontier = frontier.toSet();

    if (chart.showFrontier && frontier.length > 1) {
      final path = Path();
      var first = true;
      for (final i in frontier) {
        final o = place(chart.models[i]);
        if (o == null) continue;
        if (first) {
          path.moveTo(o.dx, o.dy);
          first = false;
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeJoin = StrokeJoin.round
          ..color = chart.frontierColor.withValues(
            alpha: chart.frontierColor.a * t,
          )
          ..isAntiAlias = true,
      );
    }

    // Largest first, so a small model is never hidden under a large one.
    final order = [...drawn]
      ..sort(
        (a, b) =>
            radiusOf(chart.models[b]).compareTo(radiusOf(chart.models[a])),
      );
    for (final i in order) {
      final m = chart.models[i];
      final o = place(m);
      if (o == null || !o.dx.isFinite || !o.dy.isFinite) continue;
      final color = colorOf(m);
      final strong = onFrontier.contains(i) || hovered == i;
      final alpha = strong ? 0.85 : chart.dimOpacity.clamp(0.0, 1.0);
      final r = radiusOf(m) * t;
      canvas
        ..drawCircle(
          o,
          r,
          Paint()
            ..color = color.withValues(alpha: alpha)
            ..isAntiAlias = true,
        )
        ..drawCircle(
          o,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = hovered == i ? 2 : 1
            ..color = hovered == i ? const Color(0xFFFFFFFF) : color
            ..isAntiAlias = true,
        );
    }

    if (t >= 1) {
      for (final i in order.reversed) {
        final named = chart.labelAll || onFrontier.contains(i) || hovered == i;
        if (named) _label(canvas, chart.models[i]);
      }
    }
    _legend(canvas);
  }

  void _label(Canvas canvas, ModelPoint m) {
    final o = place(m);
    if (o == null) return;
    final tp = text.get(
      m.name,
      const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: Color(0xDDFFFFFF),
      ).merge(chart.labelStyle),
    );
    var x = o.dx + radiusOf(m) + 4;
    if (x + tp.width > plot.right) x = o.dx - radiusOf(m) - 4 - tp.width;
    tp.paint(canvas, Offset(math.max(plot.left, x), o.dy - tp.height / 2));
  }

  void _legend(Canvas canvas) {
    if (!chart.showLegend || groups.length < 2) return;
    final style = const TextStyle(
      fontSize: 10,
      color: Color(0xCCFFFFFF),
    ).merge(chart.legendStyle);
    var top = plot.top + 4;
    for (var g = 0; g < groups.length; g++) {
      final tp = text.get(groups[g], style);
      final left = plot.right - 8 - tp.width;
      final color = chart.palette.isEmpty
          ? const Color(0xFF4C86CD)
          : chart.palette[g % chart.palette.length];
      canvas.drawCircle(
        Offset(left - 8, top + tp.height / 2),
        4,
        Paint()
          ..color = color
          ..isAntiAlias = true,
      );
      tp.paint(canvas, Offset(left, top));
      top += tp.height + 3;
    }
  }
}
