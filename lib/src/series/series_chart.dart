import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import '../renderer/text_painter_cache.dart';
import 'series_axis.dart';
import 'series_chart_painter.dart';
import 'series_data.dart';
import 'series_scale.dart';
import 'series_touch.dart';

/// A chart of plain values: lines, areas and bars over a numeric x axis.
///
/// Where `KChartWidget` reads candles against time, this reads any numbers
/// against any numbers — a balance per day, a count per month, a return per
/// trade — which is what a dashboard, a wallet or a report draws.
///
/// ```dart
/// SeriesChart(
///   series: [
///     LineSeries.values(
///       balances,
///       color: purple,
///       curve: LineCurve.monotone,
///       fill: SeriesFill.fade(purple),
///     ),
///   ],
///   xAxis: SeriesXAxis(labels: dayNames),
///   yAxis: SeriesYAxis(formatter: formatUsd),
///   touch: const SeriesTouch(trigger: SeriesTouchTrigger.longPress),
/// );
/// ```
///
/// The chart fills the box it is given. In a box with no height of its own —
/// a `Column` without an `Expanded`, a scroll view — it is [defaultHeight]
/// high.
class SeriesChart extends StatefulWidget {
  /// Creates a chart of [series].
  const SeriesChart({
    super.key,
    required this.series,
    this.xAxis = const SeriesXAxis(),
    this.yAxis = const SeriesYAxis(),
    this.grid = const SeriesGrid(),
    this.border,
    this.minX,
    this.maxX,
    this.xPadding,
    this.minY,
    this.maxY,
    this.includeZero = false,
    this.yPadding = 0.1,
    this.niceYRange = true,
    this.referenceLines = const [],
    this.bands = const [],
    this.betweenFills = const [],
    this.orientation = SeriesOrientation.vertical,
    this.touch = const SeriesTouch(),
    this.controller,
    this.onTouch,
    this.animationDuration = Duration.zero,
    this.animationCurve = Curves.easeOutCubic,
    this.animateOnMount = true,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.clipToPlot = true,
    this.defaultHeight = 200,
    this.semanticLabel,
  });

  /// What to draw, bottom layer first.
  final List<PlotSeries> series;

  /// The horizontal axis; [SeriesXAxis.hidden] for none.
  final SeriesXAxis xAxis;

  /// The value axis; [SeriesYAxis.hidden] for none.
  final SeriesYAxis yAxis;

  /// Lines ruled at the axis ticks; [SeriesGrid.none] for none.
  final SeriesGrid grid;

  /// A line around the plot; null draws none.
  final BorderSide? border;

  /// The x at the plot's left edge; null fits the data.
  ///
  /// With [maxX] this shows a window of a longer series — the values outside
  /// are clipped away, and the value range fits what is left.
  final double? minX;

  /// The x at the plot's right edge; null fits the data.
  final double? maxX;

  /// Room either side of the fitted x range, in x units; null leaves half a
  /// unit when there are bars, so the end bars are whole, and none otherwise.
  final double? xPadding;

  /// The value at the plot's bottom edge; null fits the data.
  final double? minY;

  /// The value at the plot's top edge; null fits the data.
  final double? maxY;

  /// Whether the fitted value range always reaches zero.
  final bool includeZero;

  /// Room above and below the fitted values, as a share of their range.
  final double yPadding;

  /// Whether a fitted value range is widened to a round tick at either end.
  final bool niceYRange;

  /// Fixed levels, such as a zero line.
  final List<SeriesReferenceLine> referenceLines;

  /// Shaded stretches of the plot.
  final List<SeriesBand> bands;

  /// Areas filled between two of the [series], painted under them.
  final List<SeriesBetweenFill> betweenFills;

  /// Which way the chart is turned; [SeriesOrientation.horizontal] lays the x
  /// axis down the side and grows the bars rightwards.
  final SeriesOrientation orientation;

  /// How the chart answers touch and hover; null makes it ignore both.
  final SeriesTouch? touch;

  /// Shows the crosshair from code, or shares it with other charts.
  final SeriesChartController? controller;

  /// Called after the crosshair moves to another x, and with null when it
  /// goes.
  final ValueChanged<SeriesTouchDetails?>? onTouch;

  /// How long new values take to move into place; zero snaps.
  ///
  /// With the same number of points as before, each value moves from where it
  /// was. Otherwise — and on the first build, when [animateOnMount] is set —
  /// the values grow out of each series' baseline.
  final Duration animationDuration;

  /// The easing of [animationDuration].
  final Curve animationCurve;

  /// Whether the first build grows in, when [animationDuration] is not zero.
  final bool animateOnMount;

  /// Space kept clear around the chart, axes included.
  final EdgeInsets padding;

  /// Painted behind the whole chart; null leaves it transparent.
  final Color? backgroundColor;

  /// Whether the series are cut off at the plot's edges, or only at the
  /// chart's.
  final bool clipToPlot;

  /// The height taken in a box that sets none.
  final double defaultHeight;

  /// What a screen reader announces for the chart.
  final String? semanticLabel;

  @override
  State<SeriesChart> createState() => _SeriesChartState();
}

class _SeriesChartState extends State<SeriesChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 128);

  /// Where the running animation started from; null when nothing is moving.
  List<List<double?>>? _fromValues;
  SeriesViewport? _fromViewport;

  /// What the last frame drew, which a new animation starts from.
  List<List<double?>>? _drawnValues;
  SeriesViewport? _drawnViewport;

  SeriesGeometry? _geometry;
  double? _localX;
  int? _localSeries;
  int? _localPoint;
  double? _reportedX;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
      value: 1,
    )
      ..addListener(_onTick)
      ..addStatusListener(_onStatus);
    widget.controller?.addListener(_onController);
    if (widget.animateOnMount && widget.animationDuration > Duration.zero) {
      _growIn();
    }
  }

  @override
  void didUpdateWidget(SeriesChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onController);
      widget.controller?.addListener(_onController);
    }
    _animation.duration = widget.animationDuration;

    if (_sameValues(oldWidget.series, widget.series)) return;
    if (widget.animationDuration <= Duration.zero) {
      _fromValues = null;
      _fromViewport = null;
      return;
    }
    final drawn = _drawnValues;
    if (drawn != null && _sameShape(drawn, widget.series)) {
      _fromValues = drawn;
      _fromViewport = _drawnViewport;
      _animation.forward(from: 0);
    } else {
      _growIn();
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onController);
    _animation.dispose();
    super.dispose();
  }

  void _onTick() => setState(() {});

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() {
        _fromValues = null;
        _fromViewport = null;
      });
    }
  }

  void _onController() => setState(() {});

  void _growIn() {
    final target = _targetValues(widget.series);
    final viewport = _fit(target);
    _fromValues = [
      for (var i = 0; i < widget.series.length; i++)
        [
          for (final v in target[i])
            v == null
                ? null
                : widget.series[i].baseline.clamp(viewport.minY, viewport.maxY),
        ],
    ];
    _fromViewport = null;
    _animation.forward(from: 0);
  }

  static List<List<double?>> _targetValues(List<PlotSeries> series) => [
        for (final s in series)
          [for (final p in s.points) p.isGap ? null : p.y],
      ];

  static bool _sameValues(List<PlotSeries> a, List<PlotSeries> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final pa = a[i].points;
      final pb = b[i].points;
      if (identical(pa, pb)) continue;
      if (pa.length != pb.length) return false;
      for (var j = 0; j < pa.length; j++) {
        if (pa[j] != pb[j]) return false;
      }
    }
    return true;
  }

  static bool _sameShape(List<List<double?>> values, List<PlotSeries> series) {
    if (values.length != series.length) return false;
    for (var i = 0; i < series.length; i++) {
      if (values[i].length != series[i].points.length) return false;
    }
    return true;
  }

  SeriesViewport _fit(List<List<double?>> values) => fitSeriesViewport(
        series: widget.series,
        values: values,
        xAxis: widget.xAxis,
        yAxis: widget.yAxis,
        referenceLines: widget.referenceLines,
        minX: widget.minX,
        maxX: widget.maxX,
        xPadding: widget.xPadding,
        minY: widget.minY,
        maxY: widget.maxY,
        includeZero: widget.includeZero,
        yPadding: widget.yPadding,
        niceYRange: widget.niceYRange,
      );

  // ── Touch ───────────────────────────────────────────────────────────────

  double? get _touchX {
    final controller = widget.controller;
    return controller != null ? controller.x : _localX;
  }

  int? get _touchSeries {
    final controller = widget.controller;
    return controller != null ? controller.seriesIndex : _localSeries;
  }

  int? get _touchPoint {
    final controller = widget.controller;
    return controller != null ? controller.pointIndex : _localPoint;
  }

  void _showAt(Offset local) {
    final geometry = _geometry;
    if (geometry == null) return;
    final touch = widget.touch;
    if (touch != null && touch.snap == SeriesTouchSnap.nearestPoint) {
      final hit = _nearestPoint(geometry, local, touch.threshold);
      if (hit == null) return;
      final (x, seriesIndex, pointIndex) = hit;
      final controller = widget.controller;
      if (controller != null) {
        controller.show(x, seriesIndex: seriesIndex, pointIndex: pointIndex);
      } else if (_localX != x ||
          _localSeries != seriesIndex ||
          _localPoint != pointIndex) {
        setState(() {
          _localX = x;
          _localSeries = seriesIndex;
          _localPoint = pointIndex;
        });
      }
      return;
    }
    final x = _snap(geometry, geometry.pxToXAt(local));
    if (x == null) return;
    final controller = widget.controller;
    if (controller != null) {
      controller.show(x);
    } else if (_localX != x || _localSeries != null) {
      setState(() {
        _localX = x;
        _localSeries = null;
        _localPoint = null;
      });
    }
  }

  void _toggleAt(Offset local) {
    final geometry = _geometry;
    if (geometry == null) return;
    final x = _snap(geometry, geometry.pxToXAt(local));
    if (x != null && x == _touchX) {
      _release();
    } else {
      _showAt(local);
    }
  }

  void _release() {
    final controller = widget.controller;
    if (controller != null) {
      controller.clear();
    } else if (_localX != null) {
      setState(() {
        _localX = null;
        _localSeries = null;
        _localPoint = null;
      });
    }
  }

  /// The point nearest [local], and its series, within [threshold] pixels.
  (double, int, int)? _nearestPoint(
    SeriesGeometry geometry,
    Offset local,
    double threshold,
  ) {
    final viewport = geometry.viewport;
    (double, int, int)? best;
    var bestDistance = threshold * threshold;
    for (var i = 0; i < widget.series.length; i++) {
      final s = widget.series[i];
      if (!s.showInTooltip) continue;
      final row = _drawnValues != null && i < _drawnValues!.length
          ? _drawnValues![i]
          : const <double?>[];
      for (var j = 0; j < s.points.length; j++) {
        final point = s.points[j];
        if (point.isGap || point.x < viewport.minX || point.x > viewport.maxX) {
          continue;
        }
        final y = j < row.length ? row[j] : point.y;
        if (y == null || !y.isFinite) continue;
        final at = geometry.point(point.x, y);
        final distance = (at - local).distanceSquared;
        if (distance <= bestDistance) {
          bestDistance = distance;
          best = (point.x, i, j);
        }
      }
    }
    return best;
  }

  /// The x of the point nearest [wanted], among those in view.
  double? _snap(SeriesGeometry geometry, double wanted) {
    final viewport = geometry.viewport;
    double? best;
    var bestDistance = double.infinity;
    for (final s in widget.series) {
      final index = _nearest(s.points, wanted);
      if (index < 0) continue;
      for (final j in [index - 1, index, index + 1]) {
        if (j < 0 || j >= s.points.length) continue;
        final p = s.points[j];
        if (p.isGap || p.x < viewport.minX || p.x > viewport.maxX) continue;
        final distance = (p.x - wanted).abs();
        if (distance < bestDistance) {
          bestDistance = distance;
          best = p.x;
        }
      }
    }
    return best;
  }

  /// The index of the point with x nearest [x], in points sorted by x.
  static int _nearest(List<SeriesPoint> points, double x) {
    if (points.isEmpty) return -1;
    var low = 0;
    var high = points.length - 1;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (points[mid].x < x) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    if (low > 0 && (x - points[low - 1].x).abs() <= (points[low].x - x).abs()) {
      return low - 1;
    }
    return low;
  }

  static int _indexAt(List<SeriesPoint> points, double x) {
    final index = _nearest(points, x);
    if (index < 0) return -1;
    return (points[index].x - x).abs() <= 1e-9 ? index : -1;
  }

  SeriesTouchDetails _detailsAt(
    SeriesGeometry geometry,
    List<List<double?>> values,
    double x, {
    int? onlySeries,
    int? onlyPoint,
  }) {
    final touched = <SeriesTouchValue>[];
    for (var i = 0; i < widget.series.length; i++) {
      if (onlySeries != null && i != onlySeries) continue;
      final s = widget.series[i];
      if (!s.showInTooltip) continue;
      final j = onlyPoint ?? _indexAt(s.points, x);
      if (j < 0 || j >= s.points.length) continue;
      final point = s.points[j];
      final row = i < values.length ? values[i] : const <double?>[];
      final drawn = j < row.length ? row[j] : null;
      if (point.isGap || drawn == null) continue;
      touched.add(
        SeriesTouchValue(
          seriesIndex: i,
          series: s,
          pointIndex: j,
          point: point,
          position: geometry.point(point.x, drawn),
          color: switch (s) {
            final BarSeries bars => bars.barColorAt(j, point),
            final ScatterSeries dots =>
              dots.dotAt(j, point)?.color ?? s.colorAt(point.y!),
            LineSeries() => s.colorAt(point.y!),
          },
        ),
      );
    }
    // The tooltip hangs off the furthest value along the value axis, so it
    // never sits on top of what was touched.
    final Offset anchor;
    if (geometry.isHorizontal) {
      final right = touched.isEmpty
          ? geometry.plot.left
          : touched.map((v) => v.position.dx).reduce(math.max);
      anchor = Offset(right, geometry.xToPx(x));
    } else {
      final top = touched.isEmpty
          ? geometry.plot.top
          : touched.map((v) => v.position.dy).reduce(math.min);
      anchor = Offset(geometry.xToPx(x), top);
    }
    return SeriesTouchDetails(
      x: x,
      values: touched,
      position: anchor,
      plotRect: geometry.plot,
    );
  }

  void _report(SeriesTouchDetails? details) {
    final x = details?.x;
    if (x == _reportedX) return;
    _reportedX = x;
    final onTouch = widget.onTouch;
    if (onTouch == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) onTouch(details);
    });
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final target = _targetValues(widget.series);
    final from = _fromValues;
    final t =
        from == null ? 1.0 : widget.animationCurve.transform(_animation.value);
    final values = from == null || !_sameShape(from, widget.series)
        ? target
        : [
            for (var i = 0; i < target.length; i++)
              [
                for (var j = 0; j < target[i].length; j++)
                  _lerpValue(from[i][j], target[i][j], t),
              ],
          ];
    final targetViewport = _fit(target);
    final fromViewport = _fromViewport;
    final viewport = from != null && fromViewport != null
        ? SeriesViewport.lerp(fromViewport, targetViewport, t)
        : targetViewport;
    _drawnValues = values;
    _drawnViewport = viewport;

    Widget chart = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.maybeSizeOf(context)?.width ?? 300;
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : widget.defaultHeight;
        final size = Size(width, height);
        final geometry = SeriesGeometry.layout(
          size: size,
          padding: widget.padding,
          xAxis: widget.xAxis,
          yAxis: widget.yAxis,
          viewport: viewport,
          orientation: widget.orientation,
        );
        _geometry = geometry;

        final touch = widget.touch;
        final x = _touchX;
        final details = x == null
            ? null
            : _detailsAt(
                geometry,
                values,
                x,
                onlySeries: _touchSeries,
                onlyPoint: _touchPoint,
              );
        _report(details);

        final tooltip = touch?.tooltip;
        final tooltipChild = details == null || tooltip == null
            ? null
            : (tooltip.builder != null
                ? tooltip.builder!(context, details)
                : _defaultTooltip(tooltip, details, viewport));

        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: SeriesChartPainter(
                    geometry: geometry,
                    series: widget.series,
                    values: values,
                    xAxis: widget.xAxis,
                    yAxis: widget.yAxis,
                    grid: widget.grid,
                    border: widget.border,
                    referenceLines: widget.referenceLines,
                    bands: widget.bands,
                    betweenFills: widget.betweenFills,
                    backgroundColor: widget.backgroundColor,
                    clipToPlot: widget.clipToPlot,
                    textCache: _text,
                  ),
                  foregroundPainter: details == null || touch == null
                      ? null
                      : SeriesOverlayPainter(
                          geometry: geometry,
                          details: details,
                          touch: touch,
                        ),
                ),
              ),
              if (tooltipChild != null && details != null && tooltip != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomSingleChildLayout(
                      delegate: _TooltipLayout(
                        anchor: details.position,
                        plot: geometry.plot,
                        placement: tooltip.placement,
                        margin: tooltip.margin,
                      ),
                      child: tooltipChild,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );

    chart = _withGestures(chart);
    final label = widget.semanticLabel;
    return label == null
        ? chart
        : Semantics(container: true, label: label, child: chart);
  }

  static double? _lerpValue(double? from, double? to, double t) {
    if (to == null) return null;
    if (from == null) return to;
    return lerpDouble(from, to, t);
  }

  Widget _withGestures(Widget child) {
    final touch = widget.touch;
    if (touch == null) return child;
    // A horizontal chart is read by dragging down it, an upright one across.
    final dragsDown = widget.orientation == SeriesOrientation.horizontal;

    Widget result = switch (touch.trigger) {
      SeriesTouchTrigger.press => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _showAt(d.localPosition),
          onTapUp: (_) => _release(),
          onTapCancel: _release,
          onHorizontalDragStart: (d) => _showAt(d.localPosition),
          onHorizontalDragUpdate: (d) => _showAt(d.localPosition),
          onHorizontalDragEnd: (_) => _release(),
          onHorizontalDragCancel: _release,
          onVerticalDragStart:
              dragsDown ? (d) => _showAt(d.localPosition) : null,
          onVerticalDragUpdate:
              dragsDown ? (d) => _showAt(d.localPosition) : null,
          onVerticalDragEnd: dragsDown ? (_) => _release() : null,
          onVerticalDragCancel: dragsDown ? _release : null,
          child: child,
        ),
      SeriesTouchTrigger.longPress => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPressStart: (d) => _showAt(d.localPosition),
          onLongPressMoveUpdate: (d) => _showAt(d.localPosition),
          onLongPressEnd: (_) => _release(),
          onLongPressCancel: _release,
          child: child,
        ),
      SeriesTouchTrigger.tap => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => _toggleAt(d.localPosition),
          onHorizontalDragStart: (d) => _showAt(d.localPosition),
          onHorizontalDragUpdate: (d) => _showAt(d.localPosition),
          onVerticalDragStart:
              dragsDown ? (d) => _showAt(d.localPosition) : null,
          onVerticalDragUpdate:
              dragsDown ? (d) => _showAt(d.localPosition) : null,
          child: child,
        ),
      SeriesTouchTrigger.none => child,
    };

    if (touch.hover) {
      result = MouseRegion(
        onHover: (e) => _showAt(e.localPosition),
        onExit: (_) => _release(),
        child: result,
      );
    }
    return result;
  }

  Widget _defaultTooltip(
    SeriesTooltip tooltip,
    SeriesTouchDetails details,
    SeriesViewport viewport,
  ) {
    const base = TextStyle(
      fontSize: 12,
      color: Color(0xFFFFFFFF),
      decoration: TextDecoration.none,
      fontWeight: FontWeight.normal,
    );
    final valueStyle = base.merge(tooltip.valueStyle);
    final titleStyle = base
        .copyWith(fontSize: 10, color: const Color(0xB3FFFFFF))
        .merge(tooltip.titleStyle);
    final titleOf = tooltip.title;
    final title = titleOf != null
        ? titleOf(details)
        : widget.xAxis.labelFor(details.x, step: viewport.xStep);

    final rows = <Widget>[
      for (final value in details.values)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: value.color,
                shape: BoxShape.circle,
              ),
            ),
            Text(_tooltipText(tooltip, value), maxLines: 1, style: valueStyle),
          ],
        ),
    ];
    if (rows.isEmpty && (title == null || title.isEmpty)) {
      return const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tooltip.backgroundColor,
        borderRadius: BorderRadius.circular(tooltip.borderRadius),
        border: tooltip.borderColor == null
            ? null
            : Border.all(color: tooltip.borderColor!),
        boxShadow: tooltip.shadows,
      ),
      child: Padding(
        padding: tooltip.padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null && title.isNotEmpty)
              Text(title, maxLines: 1, style: titleStyle),
            ...rows,
          ],
        ),
      ),
    );
  }

  String _tooltipText(SeriesTooltip tooltip, SeriesTouchValue value) {
    final formatter = tooltip.valueFormatter;
    final axisFormatter = widget.yAxis.formatter;
    final text = formatter != null
        ? formatter(value)
        : axisFormatter != null
            ? axisFormatter(value.value)
            : _plainNumber(value.value);
    final label = value.series.label;
    return tooltip.showSeriesLabels && label != null && label.isNotEmpty
        ? '$label: $text'
        : text;
  }

  static String _plainNumber(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    var text = value.toStringAsFixed(2);
    while (text.endsWith('0')) {
      text = text.substring(0, text.length - 1);
    }
    return text.endsWith('.') ? text.substring(0, text.length - 1) : text;
  }
}

/// Places the tooltip beside or above the touched point, kept inside the chart.
class _TooltipLayout extends SingleChildLayoutDelegate {
  _TooltipLayout({
    required this.anchor,
    required this.plot,
    required this.placement,
    required this.margin,
  });

  final Offset anchor;
  final Rect plot;
  final SeriesTooltipPlacement placement;
  final double margin;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest);

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final maxLeft = math.max(0.0, size.width - childSize.width);
    final maxTop = math.max(0.0, size.height - childSize.height);
    switch (placement) {
      case SeriesTooltipPlacement.beside:
        var left = anchor.dx + margin;
        if (left + childSize.width > size.width) {
          left = anchor.dx - margin - childSize.width;
        }
        return Offset(
          left.clamp(0.0, maxLeft),
          (plot.top + 4).clamp(0.0, maxTop),
        );
      case SeriesTooltipPlacement.above:
        var top = anchor.dy - margin - childSize.height;
        if (top < 0) top = anchor.dy + margin;
        return Offset(
          (anchor.dx - childSize.width / 2).clamp(0.0, maxLeft),
          top.clamp(0.0, maxTop),
        );
    }
  }

  @override
  bool shouldRelayout(_TooltipLayout oldDelegate) =>
      oldDelegate.anchor != anchor ||
      oldDelegate.plot != plot ||
      oldDelegate.placement != placement ||
      oldDelegate.margin != margin;
}
