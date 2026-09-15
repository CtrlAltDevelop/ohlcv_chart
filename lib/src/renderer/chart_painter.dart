import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../drawing/line_painting.dart';
import '../drawing/shape_geometry.dart';
import '../entity/horizontal_line.dart';
import '../entity/info_window_entity.dart';
import '../export.dart';
import '../utils/date_format_util.dart';
import '../utils/number_util.dart';
import 'base_chart_painter.dart';
import 'candle_index.dart';
import 'text_painter_cache.dart';
import 'base_chart_renderer.dart';
import 'indicator_pane_renderer.dart';
import 'main_renderer.dart';
import 'vol_renderer.dart';

enum CrossArea { main, volume, secondary, none }

class ChartPainter extends BaseChartPainter {
  ChartPainter(
    super.chartStyle,
    this.chartColors, {
    required this.drawings,
    required this.signals,
    required this.isTrendLine,
    required this.selectY,
    required this.emitInfoWindow,
    required super.candles,
    required super.scaleX,
    required super.scrollX,
    required super.isLongPress,
    required super.selectX,
    required super.xFrontPadding,
    required super.baseDimension,
    required this.verticalTextAlignment,
    this.timeFrame,
    required this.draftLine,
    required this.selectedLine,
    this.selectedLines = const [],
    this.drawingStyle = const DrawingStyle(),
    this.chartTranslations = const ChartTranslations(),
    this.showOhlcLegend = false,
    this.priceAxisScale = PriceAxisScale.linear,
    this.secondaryPriceAxisScale,
    this.priceZoom = 1.0,
    this.pricePan = 0.0,
    CandleIndex? candleIndex,
    TextPainterCache? textCache,
    this.chartType = ChartType.candles,
    this.baselinePrice,
    this.session,
    this.candleColor,
    this.invertPriceAxis = false,
    this.showAverageClose = false,
    this.showHighLowOnAxis = false,
    this.timeZoneOffset = Duration.zero,
    this.highlightedPane,
    super.isHovering,
    super.suppressCrosshair,
    super.isOnTap,
    this.fixedPriceMin,
    this.fixedPriceMax,
    super.isTapShowInfoDialog,
    super.overlays,
    super.panes,
    super.comparisons,
    this.events = const <ResolvedEvent>[],
    this.orders = const <ChartOrder>[],
    this.openPositions = const <ChartPosition>[],
    super.volHidden,
    super.isLine = false,
    this.hideGrid = false,
    this.showNowPrice = true,
    this.fixedLength = 2,
    this.dateFormatter,
    this.priceFormatter,
    super.repaint,
  }) : candleIndex = candleIndex ?? CandleIndex(),
       textCache = textCache ?? TextPainterCache() {
    selectPointPaint = Paint()
      ..isAntiAlias = true
      ..strokeWidth = 0.5
      ..color = chartColors.selectFillColor.withAlpha(200);
    selectorBorderPaint = Paint()
      ..isAntiAlias = true
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke
      ..color = chartColors.selectBorderColor;
    nowPricePaint = Paint()
      ..strokeWidth = chartStyle.nowPriceLineWidth
      ..isAntiAlias = true;
  }

  /// Events marked under the candles, lined up with them.
  final List<ResolvedEvent> events;

  /// The regular session, in the zone the chart is showing.
  ///
  /// Null leaves every candle drawn the same; set it and the ones outside the
  /// session are washed.
  final TradingSession? session;

  /// A colour of your own for the bar at an index, or null for the usual one.
  final Color? Function(CandleEntity candle, int index)? candleColor;

  /// Whether the price axis runs the other way, with higher prices lower down.
  final bool invertPriceAxis;

  /// Whether the average close over the window is drawn as a level.
  final bool showAverageClose;

  /// Whether the window's high and low are tagged on the price axis.
  final bool showHighLowOnAxis;

  /// Working orders drawn across the candles.
  ///
  /// One being dragged is already at the price the pointer is holding it at, so
  /// the line follows the finger before the host has said anything.
  final List<ChartOrder> orders;

  /// Open positions drawn across the candles.
  ///
  /// Named apart from [positions], which is the drawing tool for a *planned*
  /// trade; these are what the account actually holds.
  final List<ChartPosition> openPositions;

  /// Every drawing on the chart, in the order they were placed.
  final List<ChartLine> drawings;

  /// The drawings of one kind, in the order they were placed.
  List<T> _of<T extends ChartLine>() => drawings.whereType<T>().toList();

  late final List<TrendLine> trendLines = _of();
  late final List<HorizontalLine> horizontalLines = _of();
  late final List<VerticalLine> verticalLines = _of();
  late final List<RectangleDrawing> rectangles = _of();
  late final List<FibRetracement> fibRetracements = _of();
  late final List<MeasureDrawing> measures = _of();
  late final List<EllipseDrawing> ellipses = _of();
  late final List<TriangleDrawing> triangles = _of();
  late final List<ParallelChannel> channels = _of();
  late final List<PositionDrawing> positions = _of();
  late final List<TextAnnotation> texts = _of();
  late final List<FreehandDrawing> freehands = _of();
  late final List<PitchforkDrawing> pitchforks = _of();
  late final List<GannFan> gannFans = _of();
  late final List<GannBox> gannBoxes = _of();
  late final List<FibExtension> fibExtensions = _of();
  late final List<FibFan> fibFans = _of();
  late final List<FibTimeZones> fibTimeZones = _of();
  late final List<RegressionChannel> regressions = _of();
  late final List<XabcdDrawing> xabcds = _of();
  late final List<PriceRangeDrawing> priceRanges = _of();
  late final List<DateRangeDrawing> dateRanges = _of();
  late final List<CalloutDrawing> callouts = _of();
  late final List<PathDrawing> paths = _of();
  late final List<FlagDrawing> flags = _of();

  final List<SignalEntity> signals;
  final bool isTrendLine;
  double selectY;

  /// Turns a drawing's timestamp back into a candle index.
  ///
  /// Handed in by the chart, which keeps one for its life, so the lookup is
  /// built once rather than walked per anchor per frame. A painter built
  /// without one — a test, or a one-off render — gets its own.
  final CandleIndex candleIndex;

  /// Holds the chart's labels laid out between frames.
  ///
  /// Handed in by the chart for the same reason as [candleIndex]: a painter is
  /// built afresh every frame, so a cache it owned itself would never be hit.
  final TextPainterCache textCache;

  /// How many labels this chart has had to lay out.
  ///
  /// Useful in a test or a benchmark; nothing in the chart reads it.
  int get textLayouts => textCache.layouts;

  /// Reports the candle under the crosshair, for the info dialog.
  ///
  /// A plain callback rather than a sink so the chart can drop a report that
  /// says nothing new: painting happens far more often than the crosshair
  /// actually moves, and a repeat would rebuild the dialog, which would paint
  /// again, for ever.
  final ValueChanged<InfoWindowEntity?> emitInfoWindow;

  /// The drawing being placed right now, painted on top of the saved ones.
  ///
  /// It is not in any of the lists above until the user finishes it.
  final ChartLine? draftLine;

  /// The drawing the editing toolbar is open on.
  final ChartLine? selectedLine;

  /// Every drawing the user has selected, [selectedLine] among them.
  ///
  /// All of them show their drag handles, so a selection of several reads as
  /// one thing that can be moved or restyled together.
  final List<ChartLine> selectedLines;

  /// Whether [line] is one of the selected drawings.
  bool isSelected(ChartLine? line) =>
      line != null &&
      (identical(line, selectedLine) ||
          selectedLines.any((candidate) => identical(candidate, line)));

  /// Geometry and palette used for the user-drawn lines and their labels.
  final DrawingStyle drawingStyle;

  /// Labels used by the OHLC legend.
  final ChartTranslations chartTranslations;

  /// Whether the candle's own values are read out above the chart.
  final bool showOhlcLegend;

  /// How the candle area spaces and reads out its price axis.
  final PriceAxisScale priceAxisScale;

  /// A second axis on the other side, or null for one axis; see
  /// [KChartWidget.secondaryPriceAxisScale].
  final PriceAxisScale? secondaryPriceAxisScale;

  @override
  double get secondaryAxisWidth => secondaryPriceAxisScale == null
      ? 0.0
      : chartStyle.secondaryPriceAxisWidth;

  /// How far the price axis is stretched away from the window it would fit.
  ///
  /// 1 is the auto-fitted range — exactly the highs and lows in view. Above 1
  /// the same prices take more room, so the candles are taller; below 1 the
  /// window opens out and the candles flatten. The middle of the range stays
  /// put, so stretching pulls both ends in evenly.
  final double priceZoom;

  /// How far the price axis is shifted, as a fraction of the range in view.
  ///
  /// Positive moves the window up — the candles slide down the chart. Zero
  /// leaves the auto-fitted window where it is.
  final double pricePan;

  /// The range to hold the price axis at, rather than scaling it from the fit
  /// to whatever candles are in the window.
  ///
  /// Both ends are needed for the lock to take; either one left null and the
  /// axis is scaled from the window as it always has been. Only the scale is
  /// held: [mMainMaxValue] and [mMainMinValue] stay the window's honest fit, so
  /// the high and low markers still point at the candles that set them and the
  /// chart can be handed back its own scale at any time.
  final double? fixedPriceMin;

  /// The upper end of [fixedPriceMin]'s range.
  final double? fixedPriceMax;

  /// What the candle area draws for each candle.
  final ChartType chartType;

  /// The level a [ChartType.baseline] chart is washed towards, or null to take
  /// the oldest close in view.
  final double? baselinePrice;

  /// Shifted onto every candle's time before it is shown.
  final Duration timeZoneOffset;

  /// The pane being dragged to a new place in the stack, if any.
  final int? highlightedPane;

  final ChartColors chartColors;
  late Paint selectPointPaint;
  late Paint selectorBorderPaint;
  late Paint nowPricePaint;
  final bool hideGrid;
  final bool showNowPrice;
  final VerticalTextAlignment verticalTextAlignment;

  @override
  bool get priceAxisOnLeft =>
      verticalTextAlignment == VerticalTextAlignment.left;
  final String Function(KLineEntity entity, bool isCrossLine)? dateFormatter;

  /// Writes the prices the axis and its readouts show; see
  /// [KChartWidget.priceFormatter].
  final String Function(double price)? priceFormatter;

  /// Duration of one candle; null draws the current-price tag without a
  /// countdown.
  final Duration? timeFrame;
  int fixedLength;

  late MainRenderer mMainRenderer;
  BaseChartRenderer<dynamic>? mVolRenderer;

  /// One renderer per indicator pane, in the order the panes are stacked.
  List<IndicatorPaneRenderer> mIndicatorPaneList = [];

  static const kLabelBgOpacity = 220;
  static const kLabelBorderWidth = 1.4;
  static const kLabelCornerRadius = 5.0;
  static const kLabelPaddingH = 8.0;
  static const kLabelPaddingV = 4.0;

  /// The oldest close in view, which is what a baseline chart falls back to.
  double? get _oldestCloseInView {
    final data = candles;
    if (data == null || data.isEmpty) return null;
    return data[mStartIndex.clamp(0, data.length - 1)].close;
  }

  /// The close a percentage axis measures against: the oldest candle in view.
  double? get _percentBase {
    // Both readouts measure from the same place: a percentage says how far the
    // market has moved from it, an index says the same thing with it at 100.
    bool measuresAMove(PriceAxisScale? scale) =>
        scale == PriceAxisScale.percentage ||
        scale == PriceAxisScale.indexedTo100;

    if (!measuresAMove(priceAxisScale) &&
        !measuresAMove(secondaryPriceAxisScale)) {
      return null;
    }
    final data = candles;
    if (data == null || data.isEmpty) return null;
    return data[mStartIndex.clamp(0, data.length - 1)].close;
  }

  /// The price range to draw, once the manual scale has been applied.
  ///
  /// Worked out in the same space the axis is spaced in — prices for a linear
  /// axis, their logarithms for a logarithmic one — so a stretched log axis
  /// stays a log axis.
  (double, double) _scaledMainRange() {
    // A locked axis is scaled from the range it is held at rather than from the
    // window's fit, which is what keeps it still while the chart scrolls: the
    // candles move and the scale under them does not.
    final lockedMin = fixedPriceMin;
    final lockedMax = fixedPriceMax;
    final locked =
        lockedMin != null &&
        lockedMax != null &&
        lockedMin.isFinite &&
        lockedMax.isFinite &&
        lockedMax > lockedMin;
    final fitMax = locked ? lockedMax : mMainMaxValue;
    final fitMin = locked ? lockedMin : mMainMinValue;

    if (priceZoom == 1 && pricePan == 0) return (fitMax, fitMin);
    if (!fitMax.isFinite || !fitMin.isFinite) return (fitMax, fitMin);

    final logarithmic =
        priceAxisScale == PriceAxisScale.logarithmic && fitMin > 0;
    double toAxis(double price) =>
        logarithmic ? math.log(price) / math.ln10 : price;
    double toPrice(double value) =>
        logarithmic ? math.pow(10, value).toDouble() : value;

    final top = toAxis(fitMax);
    final bottom = toAxis(fitMin);
    final span = top - bottom;
    if (span <= 0) return (fitMax, fitMin);

    final middle = (top + bottom) / 2 + span * pricePan;
    final half = span / 2 / priceZoom;
    return (toPrice(middle + half), toPrice(middle - half));
  }

  @override
  void initChartRenderer() {
    final (mainMax, mainMin) = _scaledMainRange();
    mMainRenderer = MainRenderer(
      mMainRect,
      mainMax,
      mainMin,
      mTopPadding,
      overlays,
      isLine,
      fixedLength,
      fittedStyle,
      chartColors,
      scaleX,
      verticalTextAlignment,
      mVolRect != null || mSecondaryRectList.isNotEmpty,
      comparisons: comparisons,
      comparisonAnchors: comparisonAnchors,
      priceScale: priceAxisScale,
      // A percentage axis measures from the oldest candle in view, so panning
      // moves the zero line along with the window.
      percentBase: _percentBase,
      chartType: chartType,
      baselinePrice: baselinePrice ?? _oldestCloseInView,
      inverted: invertPriceAxis,
      averageClose: showAverageClose ? _averageCloseInView : null,
      candleColor: candleColor,
      priceFormatter: priceFormatter,
      secondaryScale: secondaryPriceAxisScale,
      secondaryGutter: secondaryAxisGutter,
      priceAxisGutter: priceAxisGutter,
      priceAxisGutterOnLeft: priceAxisOnLeft,
    );
    if (mVolRect != null) {
      mVolRenderer = VolRenderer(
        mVolRect!,
        mVolMaxValue,
        mVolMinValue,
        mChildPadding,
        fixedLength,
        fittedStyle,
        chartColors,
        priceAxisGutter: priceAxisGutter,
        priceAxisGutterOnLeft: priceAxisOnLeft,
      );
    }
    mIndicatorPaneList = [
      for (int i = 0; i < mSecondaryRectList.length && i < panes.length; ++i)
        IndicatorPaneRenderer(
          mSecondaryRectList[i].mRect,
          mSecondaryRectList[i].mMaxValue,
          mSecondaryRectList[i].mMinValue,
          mChildPadding,
          fixedLength,
          chartStyle,
          chartColors,
          panes[i],
          percentBase: _paneBase(panes[i]),
          priceAxisGutter: priceAxisGutter,
          priceAxisGutterOnLeft: priceAxisOnLeft,
        ),
    ];
  }

  /// The mean close over the visible window, or null when there is none.
  double? get _averageCloseInView {
    final data = candles;
    if (data == null || data.isEmpty) return null;

    var sum = 0.0;
    var count = 0;
    for (var i = mStartIndex; i <= mStopIndex; i++) {
      if (i < 0 || i >= data.length) continue;
      sum += data[i].close;
      count++;
    }
    return count == 0 ? null : sum / count;
  }

  /// The value a percentage pane measures against: the first one in view.
  ///
  /// Null for a pane on any other scale, and for a window holding no value to
  /// measure from — a pane whose indicator has not warmed up yet.
  double? _paneBase(ResolvedIndicator pane) {
    if (pane.indicator.scale != IndicatorScale.percentage) return null;
    for (var i = mStartIndex; i <= mStopIndex; i++) {
      final value = pane.valueAt(0, i);
      if (value != null && value.isFinite && value != 0) return value;
    }
    return null;
  }

  @override
  void drawBg(Canvas canvas, Size size) {
    final mBgPaint = Paint()..color = chartColors.bgColor;
    // Every band is filled across the whole canvas, gutters included: an axis
    // gutter is part of the chart, and a label drawn in one needs the chart's
    // own background behind it rather than whatever is under the widget.
    final mainRect = Rect.fromLTRB(
      0,
      0,
      mCanvasWidth,
      mMainRect.height + mTopPadding,
    );
    canvas.drawRect(mainRect, mBgPaint);

    if (mVolRect != null) {
      final volRect = Rect.fromLTRB(
        0,
        mVolRect!.top - mChildPadding,
        mCanvasWidth,
        mVolRect!.bottom,
      );
      canvas.drawRect(volRect, mBgPaint);
    }

    for (int i = 0; i < mSecondaryRectList.length; ++i) {
      final mSecondaryRect = mSecondaryRectList[i].mRect;
      final secondaryRect = Rect.fromLTRB(
        0,
        mSecondaryRect.top - mChildPadding,
        mCanvasWidth,
        mSecondaryRect.bottom,
      );
      canvas.drawRect(secondaryRect, mBgPaint);
    }
    final dateRect = Rect.fromLTRB(
      0,
      size.height - mBottomPadding,
      size.width,
      size.height,
    );
    canvas.drawRect(dateRect, mBgPaint);
  }

  @override
  void drawGrid(Canvas canvas) {
    if (!hideGrid) {
      // Every pane rules itself on the same columns, so they line up down the
      // stack and each one meets its own date label at the bottom.
      final columnXs = [
        for (final index in dateTickIndices()) translateXtoX(getX(index)),
      ];
      mMainRenderer.drawGrid(
        canvas,
        mGridRows,
        mGridColumns,
        columnXs: columnXs,
      );
      mVolRenderer?.drawGrid(
        canvas,
        mGridRows,
        mGridColumns,
        columnXs: columnXs,
      );
      for (final pane in mIndicatorPaneList) {
        pane.drawGrid(canvas, mGridRows, mGridColumns, columnXs: columnXs);
      }
    }
  }

  /// The candles the date axis marks.
  ///
  /// A step is chosen from the span on screen — five minutes, an hour, a day —
  /// and a candle is marked wherever it crosses one, so the labels read
  /// `06:00, 12:00, 18:00` rather than whatever times happen to fall on evenly
  /// spaced pixels.
  List<int> dateTickIndices() {
    final data = candles;
    if (data == null || data.isEmpty) return const [];

    final start = mStartIndex.clamp(0, data.length - 1);
    final stop = mStopIndex.clamp(0, data.length - 1);
    if (stop <= start) return const [];

    final first = displayTime(data[start].dateTime);
    final last = displayTime(data[stop].dateTime);
    if (first == null || last == null) return const [];

    final step = niceTimeStep(last.difference(first), target: mGridColumns);

    final indices = <int>[];
    int? previousBucket;
    for (var i = start; i <= stop; i++) {
      final time = displayTime(data[i].dateTime);
      if (time == null) continue;
      final bucket = timeBucket(time, step);
      if (bucket == previousBucket) continue;
      // The first candle in view is where the window happens to start, not a
      // boundary the market crossed, so it is not marked.
      if (previousBucket != null) indices.add(i);
      previousBucket = bucket;
    }
    return indices;
  }

  /// The step the date axis is currently using, or null when there is nothing
  /// on screen to measure.
  Duration? dateTickStep() {
    final data = candles;
    if (data == null || data.isEmpty) return null;
    final start = mStartIndex.clamp(0, data.length - 1);
    final stop = mStopIndex.clamp(0, data.length - 1);
    if (stop <= start) return null;
    final first = displayTime(data[start].dateTime);
    final last = displayTime(data[stop].dateTime);
    if (first == null || last == null) return null;
    return niceTimeStep(last.difference(first), target: mGridColumns);
  }

  @override
  void drawChart(Canvas canvas, Size size) {
    // Behind the candles, and in the chart's own coordinates rather than the
    // scrolled and scaled ones the candles are drawn in: a profile is read
    // against the price axis, not against time.
    drawExtendedHours(canvas, size);
    mMainRenderer.drawProfiles(canvas);

    canvas.save();
    // Clipped to the plot so nothing runs under the price axis gutter, then
    // moved into candle space -- which starts at the plot's left edge, not the
    // canvas's.
    canvas.clipRect(Rect.fromLTRB(mPlotLeft, 0, mPlotRight, size.height));
    canvas.translate(mPlotLeft + mTranslateX * scaleX, 0.0);
    canvas.scale(scaleX, 1.0);

    for (int i = mStartIndex; candles != null && i <= mStopIndex; i++) {
      final curPoint = candles?[i];
      if (curPoint == null) continue;
      final lastPoint = i == 0 ? curPoint : candles![i - 1];
      final curX = getX(i);
      final lastX = i == 0 ? curX : getX(i - 1);

      mMainRenderer.drawChart(
        lastPoint,
        curPoint,
        lastX,
        curX,
        size,
        canvas,
        index: i,
      );
      mVolRenderer?.drawChart(
        lastPoint,
        curPoint,
        lastX,
        curX,
        size,
        canvas,
        index: i,
      );
    }

    // The renderers collect their series across the window rather than drawing
    // a piece per candle, so the strokes and washes go down here, in the same
    // transform the pieces were measured in.
    mMainRenderer.flushSeries(canvas);
    mVolRenderer?.flushSeries(canvas);

    canvas.restore();

    // Indicators paint in view space too, from their precomputed values, so a
    // line keeps its width however far the chart is zoomed.
    final data = candles;
    if (data != null && data.isNotEmpty) {
      double xOf(int index) => translateXtoX(getX(index));
      mMainRenderer.drawOverlays(
        canvas,
        data,
        start: mStartIndex,
        stop: mStopIndex,
        xOf: xOf,
      );
      // Over the indicators: a compared instrument is a second reading of the
      // same window, not another line about this one.
      mMainRenderer.drawComparisons(
        canvas,
        start: mStartIndex,
        stop: mStopIndex,
        xOf: xOf,
      );
      for (final pane in mIndicatorPaneList) {
        pane.drawSeries(
          canvas,
          data,
          start: mStartIndex,
          stop: mStopIndex,
          xOf: xOf,
        );
      }
    }

    drawSessionDividers(canvas, size);
    drawEventMarks(canvas);
    drawPaneHighlight(canvas);

    // User-drawn lines paint in view space, once the horizontal scale is
    // restored: a stroke then keeps the thickness it was given whatever the
    // zoom level, and a drag handle stays a circle instead of an ellipse.
    drawRectangles(canvas, size);
    drawEllipses(canvas, size);
    drawTriangles(canvas, size);
    drawGannBoxes(canvas, size);
    drawChannels(canvas, size);
    drawRegressions(canvas, size);
    drawPitchforks(canvas, size);
    drawFibRetracements(canvas, size);
    drawFibExtensions(canvas, size);
    drawFibFans(canvas, size);
    drawGannFans(canvas, size);
    drawFibTimeZones(canvas, size);
    drawXabcds(canvas, size);
    drawPaths(canvas, size);
    drawPositions(canvas, size);
    drawMeasures(canvas, size);
    drawPriceRanges(canvas, size);
    drawDateRanges(canvas, size);
    drawHorizontalLines(canvas, size);
    drawVerticalLines(canvas, size);
    drawTrendLines(canvas, size);
    drawFreehands(canvas, size);
    drawTextAnnotations(canvas, size);
    drawCallouts(canvas, size);
    drawFlags(canvas, size);

    mMainRenderer.drawAverageClose(canvas, size);
    drawTradingLines(canvas, size);

    drawHorizontalLineTitles(canvas, size);
    drawVerticalLineTitles(canvas, size);
    drawTrendLineLabels(canvas, size);
  }

  /// Draws the open positions and the working orders across the candles.
  ///
  /// Over the drawings, because these are what the account actually holds and a
  /// line drawn by hand must not hide one.
  void drawTradingLines(Canvas canvas, Size size) {
    final trading = chartStyle.trading;

    for (final position in openPositions) {
      final color = position.color ?? chartColors.tradeColor(position.side);
      _strokeTradingLine(
        canvas,
        size,
        position.entryPrice,
        color,
        trading.positionStyle,
      );
      drawPriceTag(
        canvas,
        getTextPainter(position.tagText, chartColors.nowPriceTextColor),
        clampToMain(getMainY(position.entryPrice)),
        color,
      );
    }

    for (final order in orders) {
      final color = order.color ?? chartColors.tradeColor(order.side);
      _strokeTradingLine(canvas, size, order.price, color, trading.orderStyle);
      drawPriceTag(
        canvas,
        getTextPainter(order.tagText, chartColors.nowPriceTextColor),
        clampToMain(getMainY(order.price)),
        color,
      );
    }
  }

  /// One trading line at [price], clipped to the candle area.
  void _strokeTradingLine(
    Canvas canvas,
    Size size,
    double price,
    Color color,
    LineStyle style,
  ) {
    final y = getMainY(price);
    // A line at a price the window does not reach would be drawn over another
    // pane, so it is left out rather than drawn in the wrong place.
    if (!withinMain(y)) return;

    final trading = chartStyle.trading;
    paintStyledLine(
      canvas,
      Offset(mPlotLeft, y),
      Offset(mPlotRight, y),
      Paint()
        ..color = color
        ..strokeWidth = trading.lineWidth
        ..isAntiAlias = true,
      style: style,
      dashLength: trading.dashLength,
      dashGap: trading.dashGap,
    );
  }

  /// The order whose line is within reach of [pos], or null when none is.
  ///
  /// Only a draggable one: a line that cannot be moved is not worth grabbing.
  /// The nearest is taken, so two orders close together each answer for their
  /// own half of the gap.
  ChartOrder? orderAt(Offset pos) {
    if (orders.isEmpty || !mMainRect.contains(pos)) return null;

    final tolerance = chartStyle.trading.grabTolerance;
    ChartOrder? nearest;
    var closest = double.infinity;
    for (final order in orders) {
      if (!order.draggable) continue;
      final distance = (pos.dy - getMainY(order.price)).abs();
      if (distance < tolerance && distance < closest) {
        closest = distance;
        nearest = order;
      }
    }
    return nearest;
  }

  /// The position whose line is within reach of [pos], or null when none is.
  ChartPosition? positionAt(Offset pos) {
    if (openPositions.isEmpty || !mMainRect.contains(pos)) return null;

    final tolerance = chartStyle.trading.grabTolerance;
    for (final position in openPositions) {
      if ((pos.dy - getMainY(position.entryPrice)).abs() < tolerance) {
        return position;
      }
    }
    return null;
  }

  /// Marks each event under the candle it happened on.
  ///
  /// A small badge just below the candle area, so it says when something
  /// happened without covering the price it happened at. Marks that would land
  /// on top of each other are drawn anyway — a busy week is worth seeing as a
  /// cluster — but one off the side of the chart is skipped.
  void drawEventMarks(Canvas canvas) {
    final radius = chartStyle.eventMarkRadius;
    if (events.isEmpty || radius <= 0) return;

    final y = mMainRect.bottom - radius - chartStyle.eventMarkGap;
    for (final mark in events) {
      final x = translateXtoX(getX(mark.index));
      if (x < mPlotLeft - radius || x > mPlotRight + radius) continue;

      final color =
          mark.event.color ?? chartColors.eventColor(mark.event.kind.name);
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..isAntiAlias = true
          ..color = color,
      );

      // A stalk up to the candles, so the badge reads as belonging to one bar
      // rather than floating below the lot.
      canvas.drawLine(
        Offset(x, y - radius),
        Offset(x, mMainRect.bottom),
        Paint()
          ..isAntiAlias = true
          ..strokeWidth = 1
          ..color = color.withValues(alpha: color.a * 0.6),
      );

      final icon = mark.event.icon;
      if (icon != null) {
        final tp = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(
              fontSize: radius * 1.5,
              fontFamily: icon.fontFamily,
              package: icon.fontPackage,
              color: chartColors.nowPriceTextColor,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
        continue;
      }

      final tp = getTextPainter(
        mark.event.badgeText,
        chartColors.nowPriceTextColor,
        fontSize: radius * 1.1,
      );
      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
    }
  }

  /// The event whose badge is under [pos], or null when none is.
  ///
  /// The newest first, so the one drawn on top of a cluster is the one a tap
  /// picks up.
  ChartEvent? eventAt(Offset pos) {
    final radius = chartStyle.eventMarkRadius;
    if (events.isEmpty || radius <= 0) return null;

    final y = mMainRect.bottom - radius - chartStyle.eventMarkGap;
    for (final mark in events.reversed) {
      final x = translateXtoX(getX(mark.index));
      if ((pos - Offset(x, y)).distance <= radius) return mark.event;
    }
    return null;
  }

  /// Washes the pane the user is dragging to a new place in the stack.
  void drawPaneHighlight(Canvas canvas) {
    final index = highlightedPane;
    if (index == null || index < 0 || index >= mSecondaryRectList.length) {
      return;
    }

    final rect = mSecondaryRectList[index].mRect;
    final area = Rect.fromLTRB(
      rect.left,
      rect.top - mChildPadding,
      rect.right,
      rect.bottom,
    );
    canvas.drawRect(
      area,
      Paint()..color = drawingStyle.accentColor.withValues(alpha: .12),
    );
    canvas.drawRect(
      area,
      Paint()
        ..color = drawingStyle.accentColor.withValues(alpha: .7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  /// Washes the stretches of chart outside the regular session.
  ///
  /// Read in the time zone the chart is showing, so the pre-market and
  /// after-hours bands land where the trader sees them rather than where UTC
  /// does. Neighbouring candles outside the session are washed as one band, so
  /// a long overnight is one rectangle rather than a hundred.
  void drawExtendedHours(Canvas canvas, Size size) {
    final hours = session;
    final data = candles;
    if (hours == null || data == null || data.isEmpty) return;

    final paint = Paint()
      ..color = chartColors.effectiveExtendedHoursColor
      ..isAntiAlias = true;
    final bottom = size.height - mBottomPadding;
    final half = mPointWidth / 2 * scaleX;

    double? bandFrom;
    double? bandTo;

    void flush() {
      if (bandFrom == null || bandTo == null) return;
      canvas.drawRect(
        Rect.fromLTRB(bandFrom!, mMainRect.top, bandTo!, bottom),
        paint,
      );
      bandFrom = null;
      bandTo = null;
    }

    for (var i = mStartIndex; i <= mStopIndex && i < data.length; i++) {
      final time = displayTime(data[i].dateTime);
      if (time == null || hours.contains(time)) {
        flush();
        continue;
      }

      final centre = translateXtoX(getX(i));
      final left = centre - half;
      final right = centre + half;
      if (bandFrom == null) {
        bandFrom = left;
        bandTo = right;
      } else {
        bandTo = right;
      }
    }
    flush();
  }

  /// Marks the first candle of each day with a vertical line.
  ///
  /// Read in the time zone the chart is showing, so a session boundary lands
  /// where the trader sees the day turning over rather than where UTC does.
  void drawSessionDividers(Canvas canvas, Size size) {
    if (!chartStyle.showSessionDividers) return;
    final data = candles;
    if (data == null || data.isEmpty) return;

    final paint = Paint()
      ..color = chartColors.effectiveSessionDividerColor
      ..strokeWidth = chartStyle.gridStrokeWidth
      ..isAntiAlias = true;

    final from = math.max(mStartIndex, 1);
    for (var i = from; i <= mStopIndex && i < data.length; i++) {
      final today = displayTime(data[i].dateTime);
      final yesterday = displayTime(data[i - 1].dateTime);
      if (today == null || yesterday == null) continue;
      if (today.day == yesterday.day && today.month == yesterday.month) {
        continue;
      }

      final x = translateXtoX(getX(i));
      canvas.drawLine(
        Offset(x, mMainRect.top),
        Offset(x, size.height - mBottomPadding),
        paint,
      );
    }
  }

  /// [time] in the zone the chart is showing.
  DateTime? displayTime(DateTime? time) => time?.add(timeZoneOffset);

  /// The saved drawings of one kind, plus the one being placed when it is of
  /// that kind, so a draft paints exactly like the finished article.
  ///
  /// Drawings hidden from the drawing manager are left out.
  List<T> _withDraft<T extends ChartLine>(List<T> saved) {
    final visible = [
      for (final line in saved)
        if (!line.hidden) line,
    ];
    final draft = draftLine;
    return draft is T ? [...visible, draft] : visible;
  }

  /// Where on the canvas an anchor sits, or null when its candle is not in the
  /// data at all.
  Offset? _anchor(DateTime? time, double? price) {
    if (time == null || price == null) return null;
    final index = candleIndex.indexOf(candles!, time);
    if (index == null) return null;
    return Offset(translateXtoX(getX(index)), getMainY(price));
  }

  void drawHorizontalLines(Canvas canvas, Size size) {
    for (final line in _withDraft(horizontalLines)) {
      final y = getMainY(line.price);
      // Drawn at a price the axis does not reach it would land over another
      // pane, or off the canvas entirely, so it is left out rather than drawn
      // somewhere it does not mean. Its label still marks the edge.
      if (!withinMain(y)) continue;
      // A ray starts at its own candle; a plain level spans the whole chart.
      final startX = horizontalRayStartX(line) ?? 0.0;
      if (startX > size.width) continue;
      strokeChartLine(canvas, Offset(startX, y), Offset(size.width, y), line);

      if (isSelected(line)) {
        final radius = drawingStyle.handleRadius;
        final top = mMainRect.top + radius;
        final bottom = math.max(top, mMainRect.bottom - radius);
        final handleX = line.isRay ? startX : size.width / 2;
        drawLineHandle(canvas, Offset(handleX, y.clamp(top, bottom)), line);
      }
    }
  }

  /// Where a horizontal ray begins on the canvas, or null when [line] spans the
  /// whole chart.
  double? horizontalRayStartX(HorizontalLine line) {
    final start = line.startTime;
    if (start == null) return null;
    final index = candleIndex.indexOf(candles!, start);
    if (index == null) return null;
    return translateXtoX(getX(index));
  }

  void drawHorizontalLineTitles(Canvas canvas, Size size) {
    for (final line in horizontalLines) {
      if (!line.showLabel || line.hidden) continue;

      final y = getMainY(line.price);
      final title = line.title ?? line.price.toStringAsFixed(fixedLength);
      // Off the axis, the label is held at the edge the price is beyond and
      // carries which way it went, so a level outside a locked range can still
      // be found rather than silently disappearing.
      final labelY = clampToMain(y);
      final tp = getLabelPainter(
        withinMain(y) ? title : '$title ${y < mMainRect.top ? '▲' : '▼'}',
        line.color,
      );
      final padding = drawingStyle.labelPadding;

      final rayStart = horizontalRayStartX(line);
      final textX = rayStart != null
          ? rayStart + padding.left + 8
          : verticalTextAlignment == VerticalTextAlignment.right
          ? size.width - tp.width - padding.right - 8
          : 8.0 + padding.left;

      drawLineLabel(
        canvas,
        tp,
        Offset(textX, labelY - tp.height / 2),
        line.color,
      );
    }
  }

  void drawVerticalLines(Canvas canvas, Size size) {
    for (final line in _withDraft(verticalLines)) {
      final index = candleIndex.indexOf(candles!, line.time);
      if (index == null) continue;

      final x = translateXtoX(getX(index));
      strokeChartLine(
        canvas,
        Offset(x, mTopPadding),
        Offset(x, size.height - mBottomPadding),
        line,
      );

      if (isSelected(line)) {
        drawLineHandle(canvas, Offset(x, mMainRect.center.dy), line);
      }
    }
  }

  void drawVerticalLineTitles(Canvas canvas, Size size) {
    for (final line in verticalLines) {
      if (!line.showLabel || line.hidden) continue;

      final index = candleIndex.indexOf(candles!, line.time);
      if (index == null) continue;

      final x = getX(index);
      if (x < -mTranslateX || x > -mTranslateX + mWidth / scaleX) continue;

      final tp = getLabelPainter(line.title ?? getDate(line.time), line.color);
      final dateX = translateXtoX(x);

      drawLineLabel(
        canvas,
        tp,
        Offset(dateX - tp.width / 2, 8.0 + drawingStyle.labelPadding.top),
        line.color,
      );
    }
  }

  void drawTrendLines(Canvas canvas, Size size) {
    for (final line in _withDraft(trendLines)) {
      final start = _anchor(line.time1, line.price1);
      if (start == null) continue;

      if (!line.isComplete) {
        // Still being placed: only the first anchor exists so far.
        drawLineHandle(canvas, start, line);
        continue;
      }

      final end = _anchor(line.time2, line.price2);
      if (end == null) continue;

      // A ray or an extended line is the same stroke, run out to the edge of
      // the chart in one or both directions.
      final from = line.extend == LineExtension.both
          ? extendPoint(end, start, size)
          : start;
      final to = line.extend == LineExtension.none
          ? end
          : extendPoint(start, end, size);
      strokeChartLine(canvas, from, to, line);

      if (line.arrow) drawArrowHead(canvas, start, end, line);

      if (isSelected(line)) {
        drawLineHandle(canvas, start, line);
        drawLineHandle(canvas, end, line);
      }
    }
  }

  /// Runs the ray [from] → [towards] out to the far edge of [size].
  Offset extendPoint(Offset from, Offset towards, Size size) {
    final direction = towards - from;
    if (direction.distance == 0) return towards;

    // Far enough to leave the canvas from any starting point, whatever the
    // slope; the canvas clips the rest.
    final reach = size.width + size.height + direction.distance;
    return from + direction / direction.distance * reach;
  }

  /// Paints the arrowhead of an arrow line at [end].
  void drawArrowHead(Canvas canvas, Offset start, Offset end, ChartLine line) {
    final direction = end - start;
    if (direction.distance == 0) return;

    final unit = direction / direction.distance;
    final length = drawingStyle.arrowHeadLength;
    final spread = length * 0.45;
    final base = end - unit * length;
    final side = Offset(-unit.dy, unit.dx) * spread;

    canvas.drawPath(
      Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(base.dx + side.dx, base.dy + side.dy)
        ..lineTo(base.dx - side.dx, base.dy - side.dy)
        ..close(),
      Paint()
        ..color = line.color
        ..isAntiAlias = true,
    );
  }

  void drawRectangles(Canvas canvas, Size size) {
    for (final box in _withDraft(rectangles)) {
      final corner1 = _anchor(box.time1, box.price1);
      if (corner1 == null) continue;

      if (!box.isComplete) {
        drawLineHandle(canvas, corner1, box);
        continue;
      }

      final corner2 = _anchor(box.time2, box.price2);
      if (corner2 == null) continue;
      final rect = Rect.fromPoints(corner1, corner2);

      canvas.drawRect(rect, Paint()..color = box.fillColor);
      for (final (a, b) in [
        (rect.topLeft, rect.topRight),
        (rect.topRight, rect.bottomRight),
        (rect.bottomRight, rect.bottomLeft),
        (rect.bottomLeft, rect.topLeft),
      ]) {
        strokeChartLine(canvas, a, b, box);
      }

      if (box.showLabel) drawRectangleLabel(canvas, rect, box);

      if (isSelected(box)) {
        drawLineHandle(canvas, corner1, box);
        drawLineHandle(canvas, corner2, box);
      }
    }
  }

  /// Names a box with its label, or with the range it covers.
  void drawRectangleLabel(Canvas canvas, Rect rect, RectangleDrawing box) {
    final high = math.max(box.price1, box.price2!);
    final low = math.min(box.price1, box.price2!);
    final text =
        box.label ??
        '${high.toStringAsFixed(fixedLength)} – '
            '${low.toStringAsFixed(fixedLength)}';

    final tp = getLabelPainter(text, box.color);
    final padding = drawingStyle.labelPadding;
    drawLineLabel(
      canvas,
      tp,
      Offset(rect.left + padding.left, rect.top + padding.top + 2),
      box.color,
    );
  }

  void drawFibRetracements(Canvas canvas, Size size) {
    for (final fib in _withDraft(fibRetracements)) {
      final start = _anchor(fib.time1, fib.price1);
      if (start == null) continue;

      if (!fib.isComplete) {
        drawLineHandle(canvas, start, fib);
        continue;
      }

      final end = _anchor(fib.time2, fib.price2);
      if (end == null) continue;

      final left = math.min(start.dx, end.dx);
      // Levels run to the right edge, the way a retracement is read: the
      // levels matter for what happens after the move, not during it.
      final right = size.width;

      final levels = [...fib.levels]..sort();
      if (fib.fillLevels) {
        drawFibBands(canvas, fib, levels, left, right);
      }

      final rows = <({double y, double ratio, double price})>[];
      for (final ratio in levels) {
        final price = fib.priceAt(ratio);
        if (price == null) continue;
        final y = getMainY(price);
        strokeChartLine(canvas, Offset(left, y), Offset(right, y), fib);
        rows.add((y: y, ratio: ratio, price: price));
      }

      if (fib.showLabel) drawFibLabels(canvas, fib, rows, left);

      if (isSelected(fib)) {
        drawLineHandle(canvas, start, fib);
        drawLineHandle(canvas, end, fib);
      }
    }
  }

  /// Names each level, top down, at the left end of the lines.
  ///
  /// A label that would land on the one above it is dropped: levels bunch up
  /// whenever the swing is small or the chart is zoomed out, and a legible few
  /// beat a pile of numbers on top of each other.
  void drawFibLabels(
    Canvas canvas,
    FibRetracement fib,
    List<({double y, double ratio, double price})> rows,
    double left,
  ) {
    final x = left + drawingStyle.labelPadding.left;
    double? lastTop;

    for (final row in [...rows]..sort((a, b) => a.y.compareTo(b.y))) {
      final tp = getLabelPainter(
        '${(row.ratio * 100).toStringAsFixed(1)}%  '
        '${row.price.toStringAsFixed(fixedLength)}',
        fib.color,
      );
      final top = row.y - tp.height / 2;
      if (lastTop != null && top < lastTop + tp.height) continue;

      drawLineLabel(canvas, tp, Offset(x, top), fib.color);
      lastTop = top;
    }
  }

  /// Washes the bands between neighbouring retracement levels.
  void drawFibBands(
    Canvas canvas,
    FibRetracement fib,
    List<double> levels,
    double left,
    double right,
  ) {
    final fill = Paint()
      ..color = fib.color.withValues(
        alpha: fib.color.a * drawingStyle.fibFillOpacity,
      );

    for (var i = 0; i < levels.length - 1; i++) {
      final from = fib.priceAt(levels[i]);
      final to = fib.priceAt(levels[i + 1]);
      if (from == null || to == null) continue;
      // Every other band is washed, so neighbouring levels stay apart.
      if (i.isOdd) continue;
      canvas.drawRect(
        Rect.fromLTRB(left, getMainY(from), right, getMainY(to)),
        fill,
      );
    }
  }

  void drawTrendLineLabels(Canvas canvas, Size size) {
    for (final line in trendLines) {
      if (line.hidden ||
          !line.showLabel ||
          line.time2 == null ||
          line.price2 == null) {
        continue;
      }

      final i1 = candleIndex.indexOf(candles!, line.time1);
      final i2 = candleIndex.indexOf(candles!, line.time2);
      if (i1 == null || i2 == null) continue;

      final x1 = translateXtoX(getX(i1));
      final y1 = getMainY(line.price1);
      final x2 = translateXtoX(getX(i2));
      final y2 = getMainY(line.price2!);

      final label1 =
          line.label1 ??
          '${line.price1.toStringAsFixed(fixedLength)}\n${getDate(line.time1)}';
      final label2 =
          line.label2 ??
          '${line.price2!.toStringAsFixed(fixedLength)}\n${getDate(line.time2)}';

      final tp1 = getLabelPainter(label1, line.color);
      final tp2 = getLabelPainter(label2, line.color);

      // Point 1 sits to the left of its anchor, flipping right when there is
      // no room; point 2 does the opposite.
      var label1X = x1 - tp1.width - 10;
      if (label1X < 10) label1X = x1 + 10;
      drawLineLabel(
        canvas,
        tp1,
        Offset(label1X, y1 - tp1.height / 2),
        line.color,
      );

      var label2X = x2 + 10;
      if (label2X + tp2.width > size.width - 10) label2X = x2 - tp2.width - 10;
      drawLineLabel(
        canvas,
        tp2,
        Offset(label2X, y2 - tp2.height / 2),
        line.color,
      );
    }
  }

  /// The index of the candle at [time], or null when it is not in the data.
  int? _indexOf(DateTime? time) {
    if (time == null) return null;
    return candleIndex.indexOf(candles!, time);
  }

  void drawEllipses(Canvas canvas, Size size) {
    for (final oval in _withDraft(ellipses)) {
      final corner1 = _anchor(oval.time1, oval.price1);
      if (corner1 == null) continue;

      if (!oval.isComplete) {
        drawLineHandle(canvas, corner1, oval);
        continue;
      }

      final corner2 = _anchor(oval.time2, oval.price2);
      if (corner2 == null) continue;
      final rect = Rect.fromPoints(corner1, corner2);

      canvas.drawOval(rect, Paint()..color = oval.fillColor);
      canvas.drawOval(
        rect,
        Paint()
          ..color = oval.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = oval.thickness
          ..isAntiAlias = true,
      );

      if (oval.showLabel && oval.label != null) {
        final tp = getLabelPainter(oval.label!, oval.color);
        drawLineLabel(
          canvas,
          tp,
          Offset(rect.center.dx - tp.width / 2, rect.top - tp.height - 6),
          oval.color,
        );
      }

      if (isSelected(oval)) {
        drawLineHandle(canvas, corner1, oval);
        drawLineHandle(canvas, corner2, oval);
      }
    }
  }

  void drawTriangles(Canvas canvas, Size size) {
    for (final triangle in _withDraft(triangles)) {
      final a = _anchor(triangle.time1, triangle.price1);
      if (a == null) continue;
      final b = _anchor(triangle.time2, triangle.price2);

      // Still being placed: show what there is of it so far.
      if (b == null) {
        drawLineHandle(canvas, a, triangle);
        continue;
      }
      final c = _anchor(triangle.time3, triangle.price3);
      if (c == null) {
        strokeChartLine(canvas, a, b, triangle);
        drawLineHandle(canvas, a, triangle);
        drawLineHandle(canvas, b, triangle);
        continue;
      }

      canvas.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..lineTo(c.dx, c.dy)
          ..close(),
        Paint()..color = triangle.fillColor,
      );
      for (final (from, to) in [(a, b), (b, c), (c, a)]) {
        strokeChartLine(canvas, from, to, triangle);
      }

      if (triangle.showLabel && triangle.label != null) {
        final tp = getLabelPainter(triangle.label!, triangle.color);
        drawLineLabel(canvas, tp, a + const Offset(8, -8), triangle.color);
      }

      if (isSelected(triangle)) {
        for (final corner in [a, b, c]) {
          drawLineHandle(canvas, corner, triangle);
        }
      }
    }
  }

  void drawChannels(Canvas canvas, Size size) {
    for (final channel in _withDraft(channels)) {
      final start = _anchor(channel.time1, channel.price1);
      if (start == null) continue;

      final end = _anchor(channel.time2, channel.price2);
      if (end == null) {
        drawLineHandle(canvas, start, channel);
        continue;
      }

      // The base line, run to the right edge when the channel is extended.
      final baseTo = channel.extend ? extendPoint(start, end, size) : end;
      strokeChartLine(canvas, start, baseTo, channel);

      final offset = channel.offset;
      if (offset == null) {
        // Only the base line has landed; the parallel comes with the next tap.
        if (isSelected(channel)) {
          drawLineHandle(canvas, start, channel);
          drawLineHandle(canvas, end, channel);
        }
        continue;
      }

      final parallelStart = Offset(start.dx, getMainY(channel.price1 + offset));
      final parallelEndPrice = (channel.price2 ?? channel.price1) + offset;
      final parallelEnd = Offset(end.dx, getMainY(parallelEndPrice));
      final parallelTo = channel.extend
          ? extendPoint(parallelStart, parallelEnd, size)
          : parallelEnd;

      canvas.drawPath(
        Path()
          ..moveTo(start.dx, start.dy)
          ..lineTo(baseTo.dx, baseTo.dy)
          ..lineTo(parallelTo.dx, parallelTo.dy)
          ..lineTo(parallelStart.dx, parallelStart.dy)
          ..close(),
        Paint()
          ..color = channel.color.withValues(
            alpha: channel.color.a * channel.fillOpacity.clamp(0.0, 1.0),
          ),
      );
      strokeChartLine(canvas, parallelStart, parallelTo, channel);

      if (isSelected(channel)) {
        drawLineHandle(canvas, start, channel);
        drawLineHandle(canvas, end, channel);
        drawLineHandle(canvas, parallelEnd, channel);
      }
    }
  }

  void drawPositions(Canvas canvas, Size size) {
    for (final position in _withDraft(positions)) {
      final entry = _anchor(position.time1, position.price1);
      if (entry == null) continue;

      final target = _anchor(position.time2, position.price2);
      if (target == null) {
        drawLineHandle(canvas, entry, position);
        continue;
      }

      final left = math.min(entry.dx, target.dx);
      final right = math.max(entry.dx, target.dx);
      final entryY = entry.dy;

      // The reward band runs from the entry to the target.
      _fillBand(
        canvas,
        left,
        right,
        entryY,
        target.dy,
        position.profitColor,
        position.fillOpacity,
      );

      final stopPrice = position.stopPrice;
      if (stopPrice != null) {
        _fillBand(
          canvas,
          left,
          right,
          entryY,
          getMainY(stopPrice),
          position.lossColor,
          position.fillOpacity,
        );
      }

      // The entry itself, and the two levels that bound the plan.
      strokeChartLine(
        canvas,
        Offset(left, entryY),
        Offset(right, entryY),
        position,
      );

      if (position.showLabel) drawPositionLabel(canvas, position, left, right);

      if (isSelected(position)) {
        drawLineHandle(canvas, entry, position);
        drawLineHandle(canvas, target, position);
        if (stopPrice != null) {
          drawLineHandle(canvas, Offset(right, getMainY(stopPrice)), position);
        }
      }
    }
  }

  /// Washes the band between two prices, across the span the position covers.
  void _fillBand(
    Canvas canvas,
    double left,
    double right,
    double fromY,
    double toY,
    Color color,
    double opacity,
  ) {
    canvas.drawRect(
      Rect.fromLTRB(left, math.min(fromY, toY), right, math.max(fromY, toY)),
      Paint()..color = color.withValues(alpha: opacity.clamp(0.0, 1.0)),
    );
  }

  /// Names a position with its entry, its levels and its reward against its
  /// risk — the number the plan is judged on.
  void drawPositionLabel(
    Canvas canvas,
    PositionDrawing position,
    double left,
    double right,
  ) {
    final ratio = position.riskReward;
    final parts = <String>[
      position.isLong ? 'Long' : 'Short',
      position.entryPrice.toStringAsFixed(fixedLength),
      if (ratio != null) 'R:R ${ratio.toStringAsFixed(2)}',
    ];
    final tp = getLabelPainter(parts.join('  '), position.color);
    final color = position.isLong ? position.profitColor : position.lossColor;
    drawLineLabel(
      canvas,
      tp,
      Offset(
        left + drawingStyle.labelPadding.left,
        getMainY(position.price1) - tp.height - 6,
      ),
      color,
    );
  }

  void drawMeasures(Canvas canvas, Size size) {
    for (final measure in _withDraft(measures)) {
      final start = _anchor(measure.time1, measure.price1);
      if (start == null) continue;

      if (!measure.isComplete) {
        drawLineHandle(canvas, start, measure);
        continue;
      }

      final end = _anchor(measure.time2, measure.price2);
      if (end == null) continue;
      final rect = Rect.fromPoints(start, end);

      final band = measure.isUp
          ? chartColors.nowPriceUpColor
          : chartColors.nowPriceDnColor;
      canvas.drawRect(
        rect,
        Paint()
          ..color = band.withValues(alpha: measure.fillOpacity.clamp(0.0, 1.0)),
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = band
          ..style = PaintingStyle.stroke
          ..strokeWidth = measure.thickness,
      );

      // An arrow down the middle, pointing the way the move went.
      final mid = Offset(rect.center.dx, start.dy);
      final tip = Offset(rect.center.dx, end.dy);
      strokeChartLine(canvas, mid, tip, measure);
      drawArrowHead(canvas, mid, tip, measure);

      if (measure.showLabel) drawMeasureLabel(canvas, measure, rect, band);

      if (isSelected(measure)) {
        drawLineHandle(canvas, start, measure);
        drawLineHandle(canvas, end, measure);
      }
    }
  }

  /// Reads a measurement out: the move in price and percent, how many candles
  /// it covers and how long it lasted.
  void drawMeasureLabel(
    Canvas canvas,
    MeasureDrawing measure,
    Rect rect,
    Color color,
  ) {
    final move = measure.priceMove ?? 0;
    final ratio = measure.ratio;
    final from = _indexOf(measure.time1);
    final to = _indexOf(measure.time2);
    final bars = from == null || to == null ? null : (to - from).abs();
    final span = measure.span;

    final text = [
      '${move >= 0 ? '+' : ''}${move.toStringAsFixed(fixedLength)}',
      if (ratio != null)
        '(${ratio >= 0 ? '+' : ''}${(ratio * 100).toStringAsFixed(2)}%)',
      if (bars != null) '$bars bars',
      if (span != null && span > Duration.zero) formatSpan(span),
    ].join('  ');

    final tp = getLabelPainter(text, color);
    final top = measure.isUp ? rect.top - tp.height - 8 : rect.bottom + 8;
    drawLineLabel(
      canvas,
      tp,
      Offset(rect.center.dx - tp.width / 2, top),
      color,
    );
  }

  /// A duration in the coarsest unit that still says something: `3d 4h`,
  /// `2h 15m`, `45m`.
  String formatSpan(Duration span) {
    if (span.inDays > 0) {
      final hours = span.inHours % 24;
      return hours == 0 ? '${span.inDays}d' : '${span.inDays}d ${hours}h';
    }
    if (span.inHours > 0) {
      final minutes = span.inMinutes % 60;
      return minutes == 0 ? '${span.inHours}h' : '${span.inHours}h ${minutes}m';
    }
    if (span.inMinutes > 0) return '${span.inMinutes}m';
    return '${span.inSeconds}s';
  }

  // ── Fans, forks, boxes and brackets ──────────────────────────────────────

  /// Runs a ray from [from] through [towards] to the edge of the chart.
  ///
  /// The fans all work this way: the second anchor sets a direction, not an
  /// end, so what is drawn leaves the canvas rather than stopping.
  void _strokeRay(
    Canvas canvas,
    Offset from,
    Offset towards,
    ChartLine line,
    Size size,
  ) {
    if (from == towards) return;
    strokeChartLine(canvas, from, extendPoint(from, towards, size), line);
  }

  /// Names a ray or a rule, at [at], in the line's own colour.
  void _strokeTag(Canvas canvas, String text, Offset at, ChartLine line) {
    final tp = getLabelPainter(text, line.color);
    drawLineLabel(canvas, tp, at, line.color);
  }

  void drawGannFans(Canvas canvas, Size size) {
    for (final fan in _withDraft(gannFans)) {
      final pivot = _anchor(fan.time1, fan.price1);
      if (pivot == null) continue;

      final oneByOne = _anchor(fan.time2, fan.price2);
      if (oneByOne == null) {
        drawLineHandle(canvas, pivot, fan);
        continue;
      }

      for (final ratio in fan.ratios) {
        final through = gannRayThrough(pivot, oneByOne, ratio);
        _strokeRay(canvas, pivot, through, fan, size);
        if (!fan.showLabel) continue;

        // The label sits a little way along the ray, where the fan has opened
        // out enough for the names not to pile up on the pivot.
        final along = pivot + (through - pivot) * 0.9;
        _strokeTag(canvas, GannFan.labelFor(ratio), along, fan);
      }

      if (isSelected(fan)) {
        drawLineHandle(canvas, pivot, fan);
        drawLineHandle(canvas, oneByOne, fan);
      }
    }
  }

  void drawGannBoxes(Canvas canvas, Size size) {
    for (final box in _withDraft(gannBoxes)) {
      final corner1 = _anchor(box.time1, box.price1);
      if (corner1 == null) continue;

      final corner2 = _anchor(box.time2, box.price2);
      if (corner2 == null) {
        drawLineHandle(canvas, corner1, box);
        continue;
      }

      final rect = Rect.fromPoints(corner1, corner2);
      canvas.drawRect(
        rect,
        Paint()
          ..color = box.color.withValues(
            alpha: box.color.a * box.fillOpacity.clamp(0.0, 1.0),
          ),
      );

      final rules = gannBoxRules(rect, box.ratios);
      for (final y in rules.horizontals) {
        strokeChartLine(
          canvas,
          Offset(rect.left, y),
          Offset(rect.right, y),
          box,
        );
      }
      for (final x in rules.verticals) {
        strokeChartLine(
          canvas,
          Offset(x, rect.top),
          Offset(x, rect.bottom),
          box,
        );
      }
      if (box.showDiagonals) {
        strokeChartLine(canvas, rect.topLeft, rect.bottomRight, box);
        strokeChartLine(canvas, rect.bottomLeft, rect.topRight, box);
      }

      if (box.showLabel) {
        for (final (index, ratio) in box.ratios.indexed) {
          final y = rules.horizontals[index];
          _strokeTag(
            canvas,
            '${(ratio * 100).toStringAsFixed(0)}%',
            Offset(rect.left + drawingStyle.labelPadding.left, y),
            box,
          );
        }
      }

      if (isSelected(box)) {
        drawLineHandle(canvas, corner1, box);
        drawLineHandle(canvas, corner2, box);
      }
    }
  }

  void drawFibFans(Canvas canvas, Size size) {
    for (final fan in _withDraft(fibFans)) {
      final start = _anchor(fan.time1, fan.price1);
      if (start == null) continue;

      final end = _anchor(fan.time2, fan.price2);
      if (end == null) {
        drawLineHandle(canvas, start, fan);
        continue;
      }

      for (final level in fan.levels) {
        final through = fibFanRayThrough(start, end, level);
        _strokeRay(canvas, start, through, fan, size);
        if (!fan.showLabel) continue;
        _strokeTag(
          canvas,
          '${(level * 100).toStringAsFixed(1)}%',
          through,
          fan,
        );
      }

      if (isSelected(fan)) {
        drawLineHandle(canvas, start, fan);
        drawLineHandle(canvas, end, fan);
      }
    }
  }

  void drawFibTimeZones(Canvas canvas, Size size) {
    for (final zones in _withDraft(fibTimeZones)) {
      final start = _anchor(zones.time1, zones.price1);
      if (start == null) continue;

      final end = _anchor(zones.time2, zones.price2);
      if (end == null) {
        drawLineHandle(canvas, start, zones);
        continue;
      }

      for (final level in zones.levels) {
        final x = fibTimeZoneX(start, end, level);
        // Off the canvas, so the rest of the run is too — the levels only
        // grow.
        if (x < 0 || x > size.width) continue;
        strokeChartLine(
          canvas,
          Offset(x, mMainRect.top),
          Offset(x, mMainRect.bottom),
          zones,
        );
        if (!zones.showLabel) continue;
        _strokeTag(
          canvas,
          level.toStringAsFixed(0),
          Offset(x + drawingStyle.labelPadding.left, mMainRect.top + 4),
          zones,
        );
      }

      if (isSelected(zones)) {
        drawLineHandle(canvas, start, zones);
        drawLineHandle(canvas, end, zones);
      }
    }
  }

  void drawFibExtensions(Canvas canvas, Size size) {
    for (final extension in _withDraft(fibExtensions)) {
      final start = _anchor(extension.time1, extension.price1);
      if (start == null) continue;

      final end = _anchor(extension.time2, extension.price2);
      if (end == null) {
        drawLineHandle(canvas, start, extension);
        continue;
      }

      // The impulse and the retracement, so the shape reads as the move it was
      // taken from rather than as a set of loose levels.
      strokeChartLine(canvas, start, end, extension);

      final from = _anchor(extension.time3, extension.price3);
      if (from == null) {
        if (isSelected(extension)) {
          drawLineHandle(canvas, start, extension);
          drawLineHandle(canvas, end, extension);
        }
        continue;
      }
      strokeChartLine(canvas, end, from, extension);

      final left = from.dx;
      for (final ratio in extension.levels) {
        final price = extension.priceAt(ratio);
        if (price == null) continue;
        final y = getMainY(price);
        strokeChartLine(
          canvas,
          Offset(left, y),
          Offset(size.width, y),
          extension,
        );
        if (!extension.showLabel) continue;
        _strokeTag(
          canvas,
          '${(ratio * 100).toStringAsFixed(1)}%  '
          '${price.toStringAsFixed(fixedLength)}',
          Offset(left + drawingStyle.labelPadding.left, y),
          extension,
        );
      }

      if (isSelected(extension)) {
        drawLineHandle(canvas, start, extension);
        drawLineHandle(canvas, end, extension);
        drawLineHandle(canvas, from, extension);
      }
    }
  }

  void drawPitchforks(Canvas canvas, Size size) {
    for (final fork in _withDraft(pitchforks)) {
      final p1 = _anchor(fork.time1, fork.price1);
      if (p1 == null) continue;

      final p2 = _anchor(fork.time2, fork.price2);
      if (p2 == null) {
        drawLineHandle(canvas, p1, fork);
        continue;
      }
      final p3 = _anchor(fork.time3, fork.price3);
      if (p3 == null) {
        // The swing so far, waiting for the third point that turns it into a
        // fork.
        strokeChartLine(canvas, p1, p2, fork);
        if (isSelected(fork)) {
          drawLineHandle(canvas, p1, fork);
          drawLineHandle(canvas, p2, fork);
        }
        continue;
      }

      final geometry = pitchforkGeometry(p1, p2, p3, fork.kind, fork.levels);
      final run = geometry.median - geometry.handle;

      // The bar joining the two swings, which is what the tines are measured
      // from.
      strokeChartLine(canvas, p2, p3, fork);

      final outermost = fork.levels.isEmpty
          ? null
          : fork.levels.reduce(math.max);
      for (final tine in geometry.tines) {
        for (final start in [tine.upper, tine.lower]) {
          final from = tine.level == 0 ? geometry.handle : start;
          final to = from + run;
          if (from == to) continue;
          _strokeRay(canvas, from, to, fork, size);
          // The median is one line, not two, so the pair is drawn once.
          if (tine.level == 0) break;
        }

        if (outermost != null && tine.level == outermost) {
          canvas.drawPath(
            Path()
              ..moveTo(tine.upper.dx, tine.upper.dy)
              ..lineTo(
                extendPoint(tine.upper, tine.upper + run, size).dx,
                extendPoint(tine.upper, tine.upper + run, size).dy,
              )
              ..lineTo(
                extendPoint(tine.lower, tine.lower + run, size).dx,
                extendPoint(tine.lower, tine.lower + run, size).dy,
              )
              ..lineTo(tine.lower.dx, tine.lower.dy)
              ..close(),
            Paint()
              ..color = fork.color.withValues(
                alpha: fork.color.a * fork.fillOpacity.clamp(0.0, 1.0),
              ),
          );
        }
      }

      if (fork.showLabel) {
        _strokeTag(canvas, _forkName(fork.kind), geometry.handle, fork);
      }

      if (isSelected(fork)) {
        for (final corner in [p1, p2, p3]) {
          drawLineHandle(canvas, corner, fork);
        }
      }
    }
  }

  /// What a pitchfork of [kind] is called, for its label.
  String _forkName(PitchforkKind kind) => switch (kind) {
    PitchforkKind.andrews => 'Andrews',
    PitchforkKind.schiff => 'Schiff',
    PitchforkKind.modifiedSchiff => 'Mod. Schiff',
  };

  void drawRegressions(Canvas canvas, Size size) {
    for (final regression in _withDraft(regressions)) {
      final start = _anchor(regression.time1, regression.price1);
      if (start == null) continue;

      final end = _anchor(regression.time2, regression.price2);
      if (end == null) {
        drawLineHandle(canvas, start, regression);
        continue;
      }

      final from = _indexOf(regression.time1);
      final to = _indexOf(regression.time2);
      final fit = from == null || to == null
          ? null
          : fitRegression(candles!, from, to);
      if (fit == null) {
        // Too little to fit, so the anchors are all there is to show.
        strokeChartLine(canvas, start, end, regression);
        if (isSelected(regression)) {
          drawLineHandle(canvas, start, regression);
          drawLineHandle(canvas, end, regression);
        }
        continue;
      }

      final left = math.min(start.dx, end.dx);
      final right = math.max(start.dx, end.dx);
      Offset at(double side, double multiple) => Offset(
        side,
        getMainY(
          (side == left ? fit.startPrice : fit.endPrice) +
              multiple * fit.deviation,
        ),
      );

      final spread = regression.showBands ? regression.deviations : 0.0;
      final fitFrom = at(left, 0);
      final fitTo = at(right, 0);
      final fitEnd = regression.extend
          ? extendPoint(fitFrom, fitTo, size)
          : fitTo;

      if (spread != 0) {
        final upperFrom = at(left, spread);
        final upperTo = at(right, spread);
        final lowerFrom = at(left, -spread);
        final lowerTo = at(right, -spread);
        final upperEnd = regression.extend
            ? extendPoint(upperFrom, upperTo, size)
            : upperTo;
        final lowerEnd = regression.extend
            ? extendPoint(lowerFrom, lowerTo, size)
            : lowerTo;

        canvas.drawPath(
          Path()
            ..moveTo(upperFrom.dx, upperFrom.dy)
            ..lineTo(upperEnd.dx, upperEnd.dy)
            ..lineTo(lowerEnd.dx, lowerEnd.dy)
            ..lineTo(lowerFrom.dx, lowerFrom.dy)
            ..close(),
          Paint()
            ..color = regression.color.withValues(
              alpha:
                  regression.color.a * regression.fillOpacity.clamp(0.0, 1.0),
            ),
        );
        strokeChartLine(canvas, upperFrom, upperEnd, regression);
        strokeChartLine(canvas, lowerFrom, lowerEnd, regression);
      }
      strokeChartLine(canvas, fitFrom, fitEnd, regression);

      if (regression.showLabel) {
        final slope = fit.endPrice - fit.startPrice;
        _strokeTag(
          canvas,
          '${slope >= 0 ? '+' : ''}${slope.toStringAsFixed(fixedLength)}  '
          '±${fit.deviation.toStringAsFixed(fixedLength)}',
          fitFrom,
          regression,
        );
      }

      if (isSelected(regression)) {
        drawLineHandle(canvas, start, regression);
        drawLineHandle(canvas, end, regression);
      }
    }
  }

  void drawPriceRanges(Canvas canvas, Size size) {
    for (final range in _withDraft(priceRanges)) {
      final start = _anchor(range.time1, range.price1);
      if (start == null) continue;

      final end = _anchor(range.time2, range.price2);
      if (end == null) {
        drawLineHandle(canvas, start, range);
        continue;
      }

      final rect = Rect.fromPoints(start, end);
      final band = range.isUp
          ? chartColors.nowPriceUpColor
          : chartColors.nowPriceDnColor;
      canvas.drawRect(
        rect,
        Paint()
          ..color = band.withValues(alpha: range.fillOpacity.clamp(0.0, 1.0)),
      );

      // The two levels and an arrow between them: price only, no time.
      strokeChartLine(
        canvas,
        Offset(rect.left, rect.top),
        Offset(rect.right, rect.top),
        range,
      );
      strokeChartLine(
        canvas,
        Offset(rect.left, rect.bottom),
        Offset(rect.right, rect.bottom),
        range,
      );
      final tail = Offset(rect.center.dx, start.dy);
      final tip = Offset(rect.center.dx, end.dy);
      strokeChartLine(canvas, tail, tip, range);
      drawArrowHead(canvas, tail, tip, range);

      if (range.showLabel) {
        final move = range.priceMove ?? 0;
        final ratio = range.ratio;
        final text = [
          '${move >= 0 ? '+' : ''}${move.toStringAsFixed(fixedLength)}',
          if (ratio != null)
            '(${ratio >= 0 ? '+' : ''}${(ratio * 100).toStringAsFixed(2)}%)',
        ].join('  ');
        final tp = getLabelPainter(text, band);
        drawLineLabel(
          canvas,
          tp,
          Offset(rect.center.dx + 8, rect.center.dy - tp.height / 2),
          band,
        );
      }

      if (isSelected(range)) {
        drawLineHandle(canvas, start, range);
        drawLineHandle(canvas, end, range);
      }
    }
  }

  void drawDateRanges(Canvas canvas, Size size) {
    for (final range in _withDraft(dateRanges)) {
      final start = _anchor(range.time1, range.price1);
      if (start == null) continue;

      final end = _anchor(range.time2, range.price2);
      if (end == null) {
        drawLineHandle(canvas, start, range);
        continue;
      }

      final rect = Rect.fromPoints(start, end);
      canvas.drawRect(
        rect,
        Paint()
          ..color = range.color.withValues(
            alpha: range.color.a * range.fillOpacity.clamp(0.0, 1.0),
          ),
      );

      // The two edges and an arrow across: time only, no price.
      strokeChartLine(
        canvas,
        Offset(rect.left, rect.top),
        Offset(rect.left, rect.bottom),
        range,
      );
      strokeChartLine(
        canvas,
        Offset(rect.right, rect.top),
        Offset(rect.right, rect.bottom),
        range,
      );
      final tail = Offset(rect.left, rect.center.dy);
      final tip = Offset(rect.right, rect.center.dy);
      strokeChartLine(canvas, tail, tip, range);
      drawArrowHead(canvas, tail, tip, range);

      if (range.showLabel) {
        final from = _indexOf(range.time1);
        final to = _indexOf(range.time2);
        final bars = from == null || to == null ? null : (to - from).abs();
        final span = range.span;
        final text = [
          if (bars != null) '$bars bars',
          if (span != null && span > Duration.zero) formatSpan(span),
        ].join('  ');
        if (text.isNotEmpty) {
          final tp = getLabelPainter(text, range.color);
          drawLineLabel(
            canvas,
            tp,
            Offset(rect.center.dx - tp.width / 2, rect.center.dy + 8),
            range.color,
          );
        }
      }

      if (isSelected(range)) {
        drawLineHandle(canvas, start, range);
        drawLineHandle(canvas, end, range);
      }
    }
  }

  void drawCallouts(Canvas canvas, Size size) {
    for (final callout in _withDraft(callouts)) {
      final at = _anchor(callout.time1, callout.price1);
      if (at == null) continue;

      final box = _anchor(callout.time2, callout.price2);
      if (box == null) {
        drawLineHandle(canvas, at, callout);
        continue;
      }

      // The tail first, so the box paints over where it meets it.
      strokeChartLine(canvas, at, box, callout);

      final text = callout.text;
      final tp = getLabelPainter(
        text == null || text.isEmpty ? '…' : text,
        callout.color,
      );
      final padding = drawingStyle.labelPadding;
      final rect = RRect.fromLTRBR(
        box.dx - padding.left,
        box.dy - tp.height / 2 - padding.top,
        box.dx + tp.width + padding.right,
        box.dy + tp.height / 2 + padding.bottom,
        Radius.circular(drawingStyle.labelCornerRadius),
      );

      canvas.drawRRect(
        rect,
        Paint()
          ..color = chartColors.bgColor.withValues(
            alpha: callout.fillOpacity.clamp(0.0, 1.0),
          ),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = callout.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = callout.thickness,
      );
      tp.paint(canvas, Offset(box.dx, box.dy - tp.height / 2));

      if (isSelected(callout)) {
        drawLineHandle(canvas, at, callout);
        drawLineHandle(canvas, box, callout);
      }
    }
  }

  void drawFlags(Canvas canvas, Size size) {
    for (final flag in _withDraft(flags)) {
      final foot = _anchor(flag.time, flag.price);
      if (foot == null) continue;

      final top = foot.translate(0, -flag.staffHeight);
      strokeChartLine(canvas, foot, top, flag);

      // A pennant, hanging off the top of the staff towards the newer candles.
      final width = flag.staffHeight * 0.6;
      final height = flag.staffHeight * 0.45;
      canvas.drawPath(
        Path()
          ..moveTo(top.dx, top.dy)
          ..lineTo(top.dx + width, top.dy + height / 2)
          ..lineTo(top.dx, top.dy + height)
          ..close(),
        Paint()
          ..color = flag.color
          ..isAntiAlias = true,
      );

      final text = flag.text;
      if (flag.showLabel && text != null && text.isNotEmpty) {
        final tp = getLabelPainter(text, flag.color);
        drawLineLabel(
          canvas,
          tp,
          Offset(top.dx + width + 6, top.dy),
          flag.color,
        );
      }

      if (isSelected(flag)) drawLineHandle(canvas, foot, flag);
    }
  }

  void drawXabcds(Canvas canvas, Size size) {
    for (final pattern in _withDraft(xabcds)) {
      final points = [
        for (final point in pattern.points) _anchor(point.time, point.price),
      ];
      if (points.isEmpty || points.first == null) continue;

      // The two triangles the pattern is read as: X-A-B and B-C-D.
      for (final corners in [
        [0, 1, 2],
        [2, 3, 4],
      ]) {
        if (corners.any((i) => i >= points.length || points[i] == null)) {
          continue;
        }
        final path = Path()
          ..moveTo(points[corners[0]]!.dx, points[corners[0]]!.dy);
        for (final corner in corners.skip(1)) {
          path.lineTo(points[corner]!.dx, points[corner]!.dy);
        }
        canvas.drawPath(
          path..close(),
          Paint()
            ..color = pattern.color.withValues(
              alpha: pattern.color.a * pattern.fillOpacity.clamp(0.0, 1.0),
            ),
        );
      }

      for (var i = 1; i < points.length; i++) {
        final from = points[i - 1];
        final to = points[i];
        if (from == null || to == null) continue;
        strokeChartLine(canvas, from, to, pattern);

        if (!pattern.showLabel) continue;
        final ratio = pattern.retracementAt(i);
        if (ratio == null) continue;
        final middle = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
        _strokeTag(canvas, ratio.toStringAsFixed(3), middle, pattern);
      }

      if (pattern.showLabel) {
        for (var i = 0; i < points.length; i++) {
          final at = points[i];
          if (at == null || i >= XabcdDrawing.pointNames.length) continue;
          _strokeTag(
            canvas,
            XabcdDrawing.pointNames[i],
            at.translate(4, -18),
            pattern,
          );
        }
      }

      if (isSelected(pattern)) {
        for (final at in points) {
          if (at != null) drawLineHandle(canvas, at, pattern);
        }
      }
    }
  }

  void drawPaths(Canvas canvas, Size size) {
    for (final line in _withDraft(paths)) {
      final points = [
        for (final point in line.points)
          if (_anchor(point.time, point.price) case final v?) v,
      ];
      if (points.isEmpty) continue;
      if (points.length == 1) {
        drawLineHandle(canvas, points.first, line);
        continue;
      }

      if (line.closed && points.length > 2) {
        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (final at in points.skip(1)) {
          path.lineTo(at.dx, at.dy);
        }
        canvas.drawPath(
          path..close(),
          Paint()
            ..color = line.color.withValues(
              alpha: line.color.a * line.fillOpacity.clamp(0.0, 1.0),
            ),
        );
      }

      for (var i = 1; i < points.length; i++) {
        strokeChartLine(canvas, points[i - 1], points[i], line);
      }
      if (line.closed && points.length > 2) {
        strokeChartLine(canvas, points.last, points.first, line);
      }
      if (line.arrow) {
        drawArrowHead(canvas, points[points.length - 2], points.last, line);
      }

      if (isSelected(line)) {
        for (final at in points) {
          drawLineHandle(canvas, at, line);
        }
      }
    }
  }

  void drawFreehands(Canvas canvas, Size size) {
    for (final stroke in _withDraft(freehands)) {
      if (stroke.points.isEmpty) continue;

      final path = Path();
      var started = false;
      for (final point in stroke.points) {
        final at = _anchor(point.time, point.price);
        if (at == null) continue;
        if (started) {
          path.lineTo(at.dx, at.dy);
        } else {
          path.moveTo(at.dx, at.dy);
          started = true;
        }
      }
      if (!started) continue;

      canvas.drawPath(
        path,
        Paint()
          ..color = stroke.color
          ..strokeWidth = stroke.thickness
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke
          ..isAntiAlias = true,
      );

      if (isSelected(stroke)) {
        final first = stroke.points.first;
        final at = _anchor(first.time, first.price);
        if (at != null) drawLineHandle(canvas, at, stroke);
      }
    }
  }

  void drawTextAnnotations(Canvas canvas, Size size) {
    for (final note in _withDraft(texts)) {
      final at = _anchor(note.time, note.price);
      if (at == null) continue;

      final text = note.text;
      if (text == null || text.isEmpty) {
        // An empty note still shows where it is, so it can be found and typed
        // into rather than lost.
        drawLineHandle(canvas, at, note);
        continue;
      }

      final tp = getLabelPainter(text, note.color);
      const leader = 14.0;
      final anchor = note.pointer ? at + const Offset(0, -leader) : at;
      if (note.pointer) {
        strokeChartLine(canvas, at, anchor, note);
      }

      drawLineLabel(
        canvas,
        tp,
        Offset(anchor.dx - tp.width / 2, anchor.dy - tp.height),
        note.color,
      );

      if (isSelected(note)) drawLineHandle(canvas, at, note);
    }
  }

  /// Strokes [line] between two points, honouring its colour, thickness and
  /// [LineStyle].
  void strokeChartLine(
    Canvas canvas,
    Offset start,
    Offset end,
    ChartLine line,
  ) {
    final paint = Paint()
      ..color = line.color
      ..strokeWidth = line.thickness
      ..isAntiAlias = true;

    paintStyledLine(
      canvas,
      start,
      end,
      paint,
      style: line.style,
      dashLength: drawingStyle.dashLength,
      dashGap: drawingStyle.dashGap,
      dotGap: drawingStyle.dotGap,
    );
  }

  /// Paints the round grab handle shown on a selected line.
  void drawLineHandle(Canvas canvas, Offset center, ChartLine line) {
    final radius = drawingStyle.handleRadius;
    if (radius <= 0) return;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = line.color
        ..isAntiAlias = true,
    );

    if (drawingStyle.handleBorderWidth > 0) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = line.locked
              ? drawingStyle.handleBorderColor.withValues(alpha: .5)
              : drawingStyle.handleBorderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = drawingStyle.handleBorderWidth
          ..isAntiAlias = true,
      );
    }
  }

  /// Lays out one of a line's labels at [drawingStyle]'s text size.
  TextPainter getLabelPainter(String text, Color color) =>
      getTextPainter(text, color, fontSize: drawingStyle.labelTextSize);

  /// Paints a line's label: a filled, outlined pill with [tp] inside it.
  ///
  /// [textOffset] is where the text itself starts; the pill is grown around it
  /// by `DrawingStyle.labelPadding`.
  void drawLineLabel(
    Canvas canvas,
    TextPainter tp,
    Offset textOffset,
    Color borderColor,
  ) {
    final padding = drawingStyle.labelPadding;
    final rect = RRect.fromLTRBR(
      textOffset.dx - padding.left,
      textOffset.dy - padding.top,
      textOffset.dx + tp.width + padding.right,
      textOffset.dy + tp.height + padding.bottom,
      Radius.circular(drawingStyle.labelCornerRadius),
    );

    canvas.drawRRect(
      rect,
      Paint()
        ..color =
            (drawingStyle.labelBackgroundColor ?? chartColors.defaultTextColor)
                .withAlpha(drawingStyle.labelBackgroundAlpha.clamp(0, 255)),
    );

    if (drawingStyle.labelBorderWidth > 0) {
      canvas.drawRRect(
        rect,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = drawingStyle.labelBorderWidth,
      );
    }

    tp.paint(canvas, textOffset);
  }

  @override
  void drawVerticalText(Canvas canvas) {
    final textStyle = getTextStyle(chartColors.defaultTextColor);
    if (!hideGrid) {
      mMainRenderer.drawVerticalText(canvas, textStyle, mGridRows);
    }
    mVolRenderer?.drawVerticalText(canvas, textStyle, mGridRows);
    for (final pane in mIndicatorPaneList) {
      pane.drawVerticalText(canvas, textStyle, mGridRows);
    }
  }

  @override
  void drawDate(Canvas canvas, Size size) {
    final data = candles;
    if (data == null) return;

    final step = dateTickStep();
    // Below a day, the axis reads as a run of clock times with the date
    // promoted where the day turns over — which is how a trader tells one
    // session from the next.
    final promoteDates =
        step != null &&
        step < const Duration(days: 1) &&
        dateFormatter == null &&
        chartStyle.dateTimeFormat == null;

    DateTime? previousTick;
    double? previousRight;

    for (final index in dateTickIndices()) {
      final candle = data[index];
      final time = displayTime(candle.dateTime);

      final String label;
      if (!promoteDates || time == null) {
        label = dateFormatter?.call(candle, false) ?? getDate(candle.dateTime);
      } else {
        label = startsNewDay(time, previousTick)
            ? dateFormat(time, const [mm, '-', dd])
            : dateFormat(time, const [HH, ':', nn]);
      }
      previousTick = time;

      final tp = getTextPainter(label, null);
      final y = size.height - (mBottomPadding - tp.height) / 2 - tp.height;
      var x = translateXtoX(getX(index)) - tp.width / 2;
      x = x.clamp(mPlotLeft, math.max(mPlotLeft, mPlotRight - tp.width));

      // Two labels crowding into each other read as one long number, so the
      // later one gives way.
      if (previousRight != null && x < previousRight + 4) continue;
      previousRight = x + tp.width;

      tp.paint(canvas, Offset(x, y));
    }
  }

  /// The price at [y] in the candle area, whatever the axis is spaced by.
  double calculatePrice(double y) => mMainRenderer.getValue(y);

  CrossArea getCrossArea(double y) {
    if (mMainRect.contains(Offset(mPlotLeft, y))) return CrossArea.main;
    if (mVolRect != null && mVolRect!.contains(Offset(mPlotLeft, y))) {
      return CrossArea.volume;
    }
    for (final sec in mSecondaryRectList) {
      if (sec.mRect.contains(Offset(mPlotLeft, y))) return CrossArea.secondary;
    }
    return CrossArea.none;
  }

  IndicatorPaneRenderer? _getSecondaryRendererByY(double y) {
    for (int i = 0; i < mSecondaryRectList.length; i++) {
      if (mSecondaryRectList[i].mRect.contains(Offset(mPlotLeft, y)) &&
          i < mIndicatorPaneList.length) {
        return mIndicatorPaneList[i];
      }
    }
    return null;
  }

  @override
  void drawCrossLineText(Canvas canvas, Size size) {
    final index = calculateSelectedX(selectX);
    final point = getItem(index);
    final area = getCrossArea(selectY);

    if (area == CrossArea.none) return;

    String valueText;
    double value;

    switch (area) {
      case CrossArea.main:
        value = mMainRenderer.getValue(selectY);
        valueText = mMainRenderer.formatAxis(value);
      case CrossArea.volume:
        value = mVolRenderer!.getValue(selectY);
        valueText = 'VOL: ${value.toStringAsFixed(0)}';
      case CrossArea.secondary:
        final renderer = _getSecondaryRendererByY(selectY);
        if (renderer == null) return;
        value = renderer.getValue(selectY);
        valueText = '${renderer.name}: ${renderer.formatValue(value)}';
      default:
        return;
    }

    final livePrice = candles?.last.close;
    String? liveChangeText;

    if (area == CrossArea.main && livePrice != null && livePrice > 0) {
      final change = value - livePrice;
      final changePercent = (change / value) * 100;
      final isUp = change > 0;
      liveChangeText = isUp
          ? '+${change.toStringAsFixed(fixedLength)} (${changePercent.toStringAsFixed(2)}%)'
          : '${change.toStringAsFixed(fixedLength)} (${changePercent.toStringAsFixed(2)}%)';
    }

    final priceTp = getTextPainter(valueText, chartColors.crossTextColor);
    TextPainter? changeTp;
    if (liveChangeText != null) {
      final changeColor = livePrice! >= value
          ? chartColors.nowPriceDnColor
          : chartColors.nowPriceUpColor;
      changeTp = getTextPainter(liveChangeText, changeColor);
    }

    final totalHeight = changeTp != null
        ? priceTp.height + changeTp.height + 4
        : priceTp.height;
    final textWidth = math.max(priceTp.width, changeTp?.width ?? 0);

    const w1 = 6;
    const w2 = 4;
    final r = totalHeight / 2 + w2;

    double x;
    bool isLeft;

    if (translateXtoX(getX(index)) < mPlotLeft + mWidth / 2) {
      isLeft = false;
      x = 1;

      final path = Path()
        ..moveTo(x, selectY - r)
        ..lineTo(x, selectY + r)
        ..lineTo(textWidth + 2 * w1, selectY + r)
        ..lineTo(textWidth + 2 * w1 + w2, selectY)
        ..lineTo(textWidth + 2 * w1, selectY - r)
        ..close();

      canvas.drawPath(path, selectPointPaint);
      canvas.drawPath(path, selectorBorderPaint);

      priceTp.paint(canvas, Offset(x + w1, selectY - totalHeight / 2));
      if (changeTp != null) {
        changeTp.paint(
          canvas,
          Offset(x + w1, selectY - totalHeight / 2 + priceTp.height + 2),
        );
      }
    } else {
      isLeft = true;
      x = mPlotRight - textWidth - 1 - 2 * w1 - w2;

      final path = Path()
        ..moveTo(x, selectY)
        ..lineTo(x + w2, selectY + r)
        ..lineTo(mPlotRight - 2, selectY + r)
        ..lineTo(mPlotRight - 2, selectY - r)
        ..lineTo(x + w2, selectY - r)
        ..close();

      canvas.drawPath(path, selectPointPaint);
      canvas.drawPath(path, selectorBorderPaint);

      priceTp.paint(canvas, Offset(x + w1 + w2, selectY - totalHeight / 2));
      if (changeTp != null) {
        changeTp.paint(
          canvas,
          Offset(x + w1 + w2, selectY - totalHeight / 2 + priceTp.height + 2),
        );
      }
    }

    final dateTp = getTextPainter(
      dateFormatter?.call(point, true) ?? getDate(point.dateTime),
      chartColors.crossTextColor,
    );

    double dateX = translateXtoX(getX(index));
    final bottomY = size.height - mBottomPadding;

    if (dateX < dateTp.width / 2 + w1) {
      dateX = dateTp.width / 2 + w1;
    } else if (mPlotRight - dateX < dateTp.width / 2 + w1) {
      dateX = mPlotRight - dateTp.width / 2 - w1;
    }

    canvas.drawRect(
      Rect.fromLTRB(
        dateX - dateTp.width / 2 - w1,
        bottomY,
        dateX + dateTp.width / 2 + w1,
        bottomY + dateTp.height + 4,
      ),
      selectPointPaint,
    );
    canvas.drawRect(
      Rect.fromLTRB(
        dateX - dateTp.width / 2 - w1,
        bottomY,
        dateX + dateTp.width / 2 + w1,
        bottomY + dateTp.height + 4,
      ),
      selectorBorderPaint,
    );

    dateTp.paint(canvas, Offset(dateX - dateTp.width / 2, bottomY + 2));

    if (area == CrossArea.main) {
      emitInfoWindow(
        InfoWindowEntity(
          point,
          // The oldest candle has nothing before it to compare against.
          kLinePreviousEntity: index > 0 ? getItem(index - 1) : point,
          isLeft: isLeft,
        ),
      );
    }
  }

  @override
  void drawText(Canvas canvas, KLineEntity dataO, double x) {
    // The legends read out the candle under the crosshair, or the newest one.
    var index = (candles?.length ?? 1) - 1;
    if (isReadingSelection) {
      index = calculateSelectedX(selectX);
    }
    final data = getItem(index);

    var startRow = 0;
    if (showOhlcLegend) {
      drawOhlcLegend(canvas, data, x);
      startRow = 1;
    }

    mMainRenderer.drawLegends(canvas, index, x, startRow: startRow);
    mVolRenderer?.drawText(canvas, data, x);
    for (final pane in mIndicatorPaneList) {
      pane.drawLegendAt(canvas, index, x);
    }
  }

  /// Reads the candle out above the chart, the way a terminal's header does:
  /// its date, its open, high, low and close, the move over it, and its volume.
  ///
  /// Sits on the first legend row, so the indicator legends move down one and
  /// nothing lands on top of anything else.
  void drawOhlcLegend(Canvas canvas, KLineEntity data, double x) {
    final labels = chartTranslations;
    final neutral = chartColors.defaultTextColor;
    final change = data.close - data.open;
    final moveColor = change >= 0
        ? chartColors.nowPriceUpColor
        : chartColors.nowPriceDnColor;
    final percent = data.open == 0 ? 0.0 : change / data.open * 100;

    final spans = <InlineSpan>[
      TextSpan(
        text: '${dateFormatter?.call(data, false) ?? getDate(data.dateTime)}  ',
        style: getTextStyle(neutral),
      ),
      for (final (label, value) in [
        (labels.open, data.open),
        (labels.high, data.high),
        (labels.low, data.low),
        (labels.close, data.close),
      ])
        TextSpan(
          text: '$label ${mMainRenderer.formatPrice(value)}  ',
          style: getTextStyle(moveColor),
        ),
      TextSpan(
        text:
            '${change >= 0 ? '+' : ''}${change.toStringAsFixed(fixedLength)} '
            '(${percent.toStringAsFixed(2)}%)  ',
        style: getTextStyle(moveColor),
      ),
      TextSpan(
        text: '${labels.vol} ${NumberUtil.formatCompact(data.vol)}',
        style: getTextStyle(neutral),
      ),
    ];

    final tp = TextPainter(
      text: TextSpan(children: spans),
      textDirection: TextDirection.ltr,
    )..layout();

    mMainRenderer.paintLegend(
      canvas,
      tp,
      Offset(x, mMainRect.top - mTopPadding),
    );
  }

  @override
  void drawMaxAndMin(Canvas canvas) {
    if (showHighLowOnAxis) drawHighLowTags(canvas);
    if (isLine) return;
    drawExtreme(canvas, mMainMinIndex, mMainLowMinValue, chartColors.minColor);
    drawExtreme(canvas, mMainMaxIndex, mMainHighMaxValue, chartColors.maxColor);
  }

  /// Tags the window's high and low on the price axis.
  ///
  /// The leader lines mark which candle set each extreme; these say what to read
  /// them off the axis as, which is what a trader reaching for a level wants.
  /// Drawn whatever the chart type, since a line chart has extremes too.
  void drawHighLowTags(Canvas canvas) {
    final data = candles;
    if (data == null || data.isEmpty) return;

    for (final (value, color) in [
      (mMainHighMaxValue, chartColors.maxColor),
      (mMainLowMinValue, chartColors.minColor),
    ]) {
      if (!value.isFinite) continue;
      final y = getMainY(value);
      if (y < mMainRect.top || y > mMainRect.bottom) continue;
      drawPriceTag(
        canvas,
        getTextPainter(
          mMainRenderer.formatAxis(value),
          chartColors.nowPriceTextColor,
        ),
        y,
        color,
      );
    }
  }

  /// Labels one extreme of the visible range with a short leader line pointing
  /// back at the candle that set it.
  void drawExtreme(Canvas canvas, int index, double value, Color color) {
    const leader = 8.0;
    const gap = 3.0;

    final x = translateXtoX(getX(index));
    final y = getMainY(value);
    final tp = getTextPainter(mMainRenderer.formatPrice(value), color);
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..isAntiAlias = true;

    // Point away from the nearer edge so the label always has room.
    final pointsRight = x < mPlotLeft + mWidth / 2;
    final textLeft = pointsRight
        ? math.min(x + leader + gap, mPlotRight - tp.width - 2)
        : math.max(x - leader - gap - tp.width, 2.0);

    canvas.drawLine(
      Offset(pointsRight ? x : x - leader, y),
      Offset(pointsRight ? x + leader : x, y),
      linePaint,
    );
    tp.paint(canvas, Offset(textLeft, y - tp.height / 2));
  }

  @override
  void drawNowPrice(Canvas canvas) {
    if (!showNowPrice || candles == null || candles!.isEmpty) return;

    final last = candles!.last;
    final value = last.close;
    final open = last.open;
    double y = getMainY(value);

    if (y > getMainY(mMainLowMinValue)) y = getMainY(mMainLowMinValue);
    if (y < getMainY(mMainHighMaxValue)) y = getMainY(mMainHighMaxValue);
    // Those are the window's extremes, which a locked axis need not cover: a
    // tick past the range it is held at would be drawn outside the pane.
    y = clampToMain(y);

    nowPricePaint.color = value >= open
        ? chartColors.nowPriceUpColor
        : chartColors.nowPriceDnColor;

    // Dashes run the full width so the level can be read anywhere, while the
    // stretch since the last candle stays solid.
    final lastX = translateXtoX(getX(candles!.length - 1))
        .clamp(mPlotLeft, mPlotRight);
    if (chartStyle.nowPriceDashed) {
      paintStyledLine(
        canvas,
        Offset(mPlotLeft, y),
        Offset(lastX, y),
        nowPricePaint,
        style: LineStyle.dashed,
        dashLength: chartStyle.nowPriceLineLength,
        dashGap: chartStyle.nowPriceLineSpan,
      );
    } else {
      canvas.drawLine(Offset(mPlotLeft, y), Offset(lastX, y), nowPricePaint);
    }
    canvas.drawLine(Offset(lastX, y), Offset(mPlotRight, y), nowPricePaint);

    final frame = timeFrame;
    if (frame == null) {
      final tp = getTextPainter(
        mMainRenderer.formatAxis(value),
        chartColors.nowPriceTextColor,
      );
      drawPriceTag(canvas, tp, y, nowPricePaint.color);
      return;
    }

    String countdown = '00:00';
    if (last.dateTime != null) {
      final closeTime = last.dateTime!.add(frame);
      final now = DateTime.now().toUtc();
      final remaining = closeTime.difference(now);
      if (!remaining.isNegative) {
        final days = remaining.inDays;
        final hours = remaining.inHours % 24;
        final minutes = remaining.inMinutes % 60;
        final seconds = remaining.inSeconds % 60;
        if (days > 0) {
          countdown =
              '$days days, ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        } else if (hours > 0) {
          countdown =
              '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        } else {
          countdown =
              '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        }
      }
    }

    final tp = getTextPainter(
      '${mMainRenderer.formatAxis(value)} ($countdown)',
      chartColors.nowPriceTextColor,
    );
    drawPriceTag(canvas, tp, y, nowPricePaint.color);
  }

  /// Paints a price tag against the edge opposite the axis labels, so the two
  /// never sit on top of each other.
  void drawPriceTag(Canvas canvas, TextPainter tp, double y, Color color) {
    const padding = 4.0;
    final tagWidth = tp.width + padding * 2;
    final left = verticalTextAlignment == VerticalTextAlignment.left
        ? mPlotRight - tagWidth - 1
        : mPlotLeft + 1.0;
    final top = y - tp.height / 2 - padding / 2;

    canvas.drawRRect(
      RRect.fromLTRBR(
        left,
        top,
        left + tagWidth,
        top + tp.height + padding,
        Radius.circular(chartStyle.labelCornerRadius),
      ),
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
    tp.paint(canvas, Offset(left + padding, top + padding / 2));
  }

  @override
  void drawSignals(Canvas canvas) {
    if (signals.isEmpty) return;
    for (final signal in signals) {
      final value = signal.price;
      double y = getMainY(value);

      if (y > getMainY(mMainLowMinValue)) y = getMainY(mMainLowMinValue);
      if (y < getMainY(mMainHighMaxValue)) y = getMainY(mMainHighMaxValue);
      y = clampToMain(y);

      final linePaint = Paint()
        ..color = signal.color
        ..strokeWidth = chartStyle.nowPriceLineWidth
        ..isAntiAlias = true;

      paintStyledLine(
        canvas,
        Offset(mPlotLeft, y),
        Offset(mPlotRight, y),
        linePaint,
        style: signal.useDash ? LineStyle.dashed : LineStyle.solid,
        dashLength: chartStyle.nowPriceLineLength,
        dashGap: chartStyle.nowPriceLineSpan,
      );

      final tp = getTextPainter(
        '${signal.title} ${mMainRenderer.formatAxis(value)}',
        chartColors.nowPriceTextColor,
      );
      drawPriceTag(canvas, tp, y, signal.color);
    }
  }

  @override
  void drawCrossLine(Canvas canvas, Size size) {
    final index = calculateSelectedX(selectX);
    final point = getItem(index);
    final double dashWidth = chartStyle.crossDashLength;
    final double dashSpace = chartStyle.crossDashGap;

    final paintY = Paint()
      ..color = chartColors.vCrossColor
      ..strokeWidth = chartStyle.vCrossWidth
      ..isAntiAlias = true;
    final x = getX(index);

    double currentY = mTopPadding;
    final endY = size.height - mBottomPadding;
    while (currentY < endY) {
      final double segmentEnd = (currentY + dashWidth).clamp(currentY, endY);
      canvas.drawLine(Offset(x, currentY), Offset(x, segmentEnd), paintY);
      currentY += dashWidth + dashSpace;
    }

    final paintX = Paint()
      ..color = chartColors.hCrossColor
      ..strokeWidth = chartStyle.hCrossWidth
      ..isAntiAlias = true;

    final endX = -mTranslateX + mWidth / scaleX;
    double currentX = -mTranslateX;
    while (currentX < endX) {
      final double segmentEnd = (currentX + dashWidth).clamp(currentX, endX);
      canvas.drawLine(
        Offset(currentX, selectY),
        Offset(segmentEnd, selectY),
        paintX,
      );
      currentX += dashWidth + dashSpace;
    }

    if (scaleX >= 1) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, getMainY(point.close)),
          height: 2.0 * scaleX,
          width: 2.0,
        ),
        paintX,
      );
    } else {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, getMainY(point.close)),
          height: 2.0,
          width: 2.0 / scaleX,
        ),
        paintX,
      );
    }

    final circlePaint = Paint()
      ..color = chartColors.hCrossColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(Offset(x, selectY), 2.0, circlePaint);
  }

  /// A painter for [text], laid out and ready to paint.
  ///
  /// Shared through [textCache] — paint it wherever it belongs, but do not
  /// mutate it.
  TextPainter getTextPainter(String text, Color? color, {double? fontSize}) {
    final c = color ?? chartColors.defaultTextColor;
    final style = fontSize == null
        ? getTextStyle(c)
        : getTextStyle(c).copyWith(fontSize: fontSize);
    return textCache.get(text, style);
  }

  String getDate(DateTime? date) =>
      dateFormat((date ?? DateTime.now()).add(timeZoneOffset), mFormats);

  double getMainY(double y) => mMainRenderer.getY(y);

  /// Whether [y] falls inside the candle area.
  ///
  /// A price the axis does not reach lands outside it, which a locked axis
  /// makes ordinary: the range is held where it was, so a tick beyond it has
  /// nowhere of its own to be drawn.
  bool withinMain(double y) => y >= mMainRect.top && y <= mMainRect.bottom;

  /// Pins [y] to the candle area, for a label that has to stay findable even
  /// when the price it points at is off the top or the bottom of the axis.
  double clampToMain(double y) => y.clamp(mMainRect.top, mMainRect.bottom);
}

/// Draws the crosshair, its readouts and the legends, over the chart.
///
/// A layer of its own so that moving the pointer does not repaint the candles.
/// Everything here changes as the pointer moves and nothing else does, so it
/// sits in its own [RepaintBoundary] and is driven by its own `repaint`
/// listenable — the chart underneath is left alone.
///
/// Deliberately not a [ChartPainter]: the chart is found by its painter's type
/// in several places, and two of them in one tree would make which one is found
/// depend on the order they happen to be visited in.
class ChartOverlayPainter extends CustomPainter {
  ChartOverlayPainter(this.chart, {super.repaint});

  /// The chart this draws over, and shares its geometry with.
  final ChartPainter chart;

  @override
  void paint(Canvas canvas, Size size) => chart.paintOverlay(canvas, size);

  @override
  bool shouldRepaint(ChartOverlayPainter oldDelegate) =>
      !identical(oldDelegate.chart, chart);
}

/// Draws the now-price line, the high and low markers and the signals, over
/// the candles.
///
/// A layer of its own so the countdown on the now-price tag can tick over
/// without the candles being drawn again: it is driven by its own `repaint`
/// listenable, and the chart underneath is left alone.
class ChartMarksPainter extends CustomPainter {
  ChartMarksPainter(this.chart, {super.repaint});

  /// The chart this draws over, and shares its geometry with.
  final ChartPainter chart;

  @override
  void paint(Canvas canvas, Size size) => chart.paintMarks(canvas, size);

  @override
  bool shouldRepaint(ChartMarksPainter oldDelegate) =>
      !identical(oldDelegate.chart, chart);
}
