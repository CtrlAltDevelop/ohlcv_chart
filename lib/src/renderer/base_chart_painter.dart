import 'dart:math';

import 'package:flutter/material.dart'
    show Color, TextStyle, Rect, Canvas, Size, CustomPainter;

import '../chart_style.dart' show ChartStyle;
import '../comparison.dart';
import '../entity/k_line_entity.dart';
import '../indicators/resolved_indicator.dart';
import '../utils/date_format_util.dart';
import 'base_dimension.dart';

export 'package:flutter/material.dart'
    show Color, TextStyle, Rect, Canvas, Size, CustomPainter;

/// BaseChartPainter
abstract class BaseChartPainter extends CustomPainter {
  /// constructor BaseChartPainter
  ///
  BaseChartPainter(
    this.chartStyle, {
    required this.scaleX,
    required this.scrollX,
    required this.isLongPress,
    required this.selectX,
    required this.xFrontPadding,
    required this.baseDimension,
    this.candles,
    this.isOnTap = false,
    this.isHovering = false,
    this.suppressCrosshair = false,
    this.overlays = const <ResolvedIndicator>[],
    this.panes = const <ResolvedIndicator>[],
    this.comparisons = const <ResolvedComparison>[],
    this.volHidden = false,
    this.isTapShowInfoDialog = false,
    this.isLine = false,
    super.repaint,
  }) {
    mItemCount = candles?.length ?? 0;
    mPointWidth = chartStyle.pointWidth;
    mTopPadding = chartStyle.topPadding + baseDimension.totalLabelHeight;
    mBottomPadding = chartStyle.bottomPadding;
    mChildPadding = chartStyle.childPadding;
    mGridRows = chartStyle.gridRows;
    mGridColumns = chartStyle.gridColumns;
    mDataLen = mItemCount * mPointWidth;
    initFormats();
  }

  static double maxScrollX = 0.0;
  List<KLineEntity>? candles; // data of chart

  /// Indicators drawn over the candles, with their values.
  List<ResolvedIndicator> overlays;

  /// Indicators drawn in their own panes, with their values.
  List<ResolvedIndicator> panes;

  /// Compared instruments drawn over the candles, lined up with them.
  List<ResolvedComparison> comparisons;

  /// Where each comparison is pinned to the main series, in the same order.
  ///
  /// Worked out once the window is known, since a rebased comparison starts
  /// from the left edge of what is on screen. Null for one with nothing to pin
  /// to, and for one drawn on its own prices.
  List<ComparisonAnchor?> comparisonAnchors = const <ComparisonAnchor?>[];

  bool volHidden;
  bool isTapShowInfoDialog;
  double scaleX = 1.0;
  double scrollX = 0.0;
  double selectX;
  bool isLongPress = false;
  bool isOnTap;

  /// Whether a mouse is resting over the chart, which shows the crosshair
  /// without asking for a press.
  bool isHovering;

  /// Hides the crosshair and its readout while the user is placing or dragging
  /// a line, so the two do not fight for the same gesture.
  bool suppressCrosshair;

  /// Whether the crosshair, its labels and the info window are showing.
  bool get showCrosshair =>
      !suppressCrosshair &&
      (isLongPress || isHovering || (isTapShowInfoDialog && isOnTap));

  /// Whether the legends read out a candle the user picked rather than the
  /// newest one.
  bool get isReadingSelection =>
      isLongPress || isHovering || (isTapShowInfoDialog && isOnTap);
  bool isLine;

  late Rect mMainLabelRect;

  /// Rectangle box of main chart
  late Rect mMainRect;

  /// Whether the rects have been worked out yet.
  ///
  /// They are laid out as the chart paints, so anything asking about the
  /// chart's geometry while it is still being built has to check first.
  bool get hasLayout => _hasLayout;
  bool _hasLayout = false;

  /// Rectangle box of the vol chart
  Rect? mVolRect;

  /// Secondary list support
  List<RenderRect> mSecondaryRectList = [];
  late double mDisplayHeight;

  /// Whether the price axis gutter is held back on the left rather than the
  /// right.
  ///
  /// Concrete so a subclass that draws no axis need not care; the chart
  /// painter overrides it from its label alignment.
  bool get priceAxisOnLeft => false;

  /// Width of the plot: the whole canvas less the price axis gutter.
  ///
  /// This is what the candles, the grid and the date axis are laid out in, so
  /// nothing is drawn under the axis labels. With no gutter it is the full
  /// canvas width, which is what it always was.
  late double mWidth;

  /// Full width of the canvas, gutter included.
  ///
  /// For what belongs against the true edge rather than inside the plot: the
  /// axis labels themselves, and the price tags that point at them.
  late double mCanvasWidth;

  /// Right edge of the plot, which the gutter takes when the labels are on the
  /// right.
  double get mPlotRight => mPlotLeft + mWidth;

  /// Width actually held back for the price axis, after clamping.
  ///
  /// What the renderers are given, so where they put the labels and where the
  /// plot stops can never disagree.
  double priceAxisGutter = 0.0;

  /// Width held back on the other side for a second axis, after clamping.
  ///
  /// Zero unless the chart was given one; see [secondaryAxisWidth].
  double secondaryAxisGutter = 0.0;

  /// How wide a gutter the second axis asks for, before clamping.
  ///
  /// Concrete so a painter that draws no second axis need not care; the chart
  /// painter overrides it from its own settings.
  double get secondaryAxisWidth => 0.0;

  /// Left edge of the plot, which the gutter takes when the labels are on the
  /// left. 0 whenever they are on the right.
  late double mPlotLeft;

  // padding
  double mTopPadding = 20.0;
  double mBottomPadding = 20.0;
  double mChildPadding = 12.0;

  // grid: rows - columns
  int mGridRows = 4;
  int mGridColumns = 4;
  int mStartIndex = 0;
  int mStopIndex = 0;
  double mMainMaxValue = -double.maxFinite;
  double mMainMinValue = double.maxFinite;
  double mVolMaxValue = -double.maxFinite;
  double mVolMinValue = double.maxFinite;
  double mTranslateX = double.minPositive;
  int mMainMaxIndex = 0;
  int mMainMinIndex = 0;
  double mMainHighMaxValue = -double.maxFinite;
  double mMainLowMinValue = double.maxFinite;
  int mItemCount = 0;
  double mDataLen = 0.0; // the data occupies the total length of the screen
  final ChartStyle chartStyle;
  late double mPointWidth;

  /// The style the renderers draw from, which is [chartStyle] unless the
  /// candles were spread to fill the plot — see [ChartStyle.fitContent].
  ///
  /// Worked out in [layout], since it takes a plot width to know whether the
  /// series fills one.
  late ChartStyle fittedStyle = chartStyle;

  // format time
  List<String> mFormats = [yyyy, '-', mm, '-', dd, ' ', HH, ':', nn];
  double xFrontPadding;

  /// base dimension
  final BaseDimension baseDimension;

  /// init format time
  void initFormats() {
    if (chartStyle.dateTimeFormat != null) {
      mFormats = chartStyle.dateTimeFormat!;
      return;
    }

    if (mItemCount < 2) {
      mFormats = [yyyy, '-', mm, '-', dd, ' ', HH, ':', nn];
      return;
    }

    final firstTime =
        candles?.firstOrNull?.dateTime?.millisecondsSinceEpoch ?? 0;
    final secondTime = ((candles?.length ?? 0) > 1
            ? candles?.elementAt(1).dateTime?.millisecondsSinceEpoch
            : null) ??
        0;
    int time = secondTime - firstTime;
    time ~/= 1000;
    // monthly line
    if (time >= 24 * 60 * 60 * 28) {
      mFormats = [yy, '-', mm];
    } else if (time >= 24 * 60 * 60) {
      // daily line
      mFormats = [yy, '-', mm, '-', dd];
    } else {
      // hour line
      mFormats = [mm, '-', dd, ' ', HH, ':', nn];
    }
  }

  /// Works out where everything goes, at [size].
  ///
  /// Kept apart from the drawing so the two layers of the chart can share one
  /// answer. The crosshair layer repaints on its own whenever the pointer
  /// moves, and the geometry it reads has not changed — recomputing it there
  /// would be work for nothing, and any drift between the two would show as a
  /// crosshair a pixel off the candle it is reading.
  void layout(Size size) {
    mDisplayHeight = size.height - mTopPadding - mBottomPadding;
    mCanvasWidth = size.width;
    // Never so wide that there is no plot left to draw in — the two gutters
    // share that half between them, so a chart with an axis on either side is
    // still mostly candles.
    final room = size.width / 2;
    priceAxisGutter = chartStyle.priceAxisWidth.clamp(0.0, room);
    secondaryAxisGutter = secondaryAxisWidth.clamp(0.0, room - priceAxisGutter);
    mWidth = size.width - priceAxisGutter - secondaryAxisGutter;
    // The second axis takes the side the first one left, so whichever of them
    // is on the left is what the plot starts after.
    mPlotLeft = priceAxisOnLeft ? priceAxisGutter : secondaryAxisGutter;
    fitContent();
    initRect(size);
    calculateValue();
    initChartRenderer();
  }

  /// How many times the chart layer has been drawn.
  ///
  /// Useful in a test or a benchmark; nothing in the chart reads it. What it is
  /// good for is showing that a pointer moving over the chart leaves this
  /// alone and only moves [overlayPaints].
  int get chartPaints => _chartPaints;
  int _chartPaints = 0;

  /// How many times the crosshair layer has been drawn.
  int get overlayPaints => _overlayPaints;
  int _overlayPaints = 0;

  /// Draws the chart itself: everything that does not follow the pointer.
  @override
  void paint(Canvas canvas, Size size) {
    _chartPaints++;
    canvas.clipRect(Rect.fromLTRB(0, 0, size.width, size.height));
    layout(size);

    canvas.save();
    canvas.scale(1, 1);
    drawBg(canvas, size);
    drawGrid(canvas);
    if (candles != null && candles!.isNotEmpty) {
      drawChart(canvas, size);
      drawVerticalText(canvas);
      drawDate(canvas, size);

      if (!marksOnOwnLayer) _drawMarks(canvas);
    }
    canvas.restore();
  }

  /// Whether [paint] leaves the now-price line, the high and low markers and
  /// the signals to [paintMarks].
  ///
  /// The chart widget draws those on a layer of their own, so the countdown on
  /// the now-price tag can tick over once a second without every candle being
  /// drawn again. Left false, [paint] draws the whole chart, as it always has.
  bool marksOnOwnLayer = false;

  /// How many times the marks layer has been drawn on its own.
  int get marksPaints => _marksPaints;
  int _marksPaints = 0;

  /// Draws the now-price line, the high and low markers and the signals.
  ///
  /// Reuses the geometry [paint] worked out, as [paintOverlay] does.
  void paintMarks(Canvas canvas, Size size) {
    _marksPaints++;
    if (!hasLayout) layout(size);
    if (candles == null || candles!.isEmpty) return;

    canvas.clipRect(Rect.fromLTRB(0, 0, size.width, size.height));
    canvas.save();
    _drawMarks(canvas);
    canvas.restore();
  }

  void _drawMarks(Canvas canvas) {
    drawNowPrice(canvas);
    drawMaxAndMin(canvas);
    drawSignals(canvas);
  }

  /// Draws what follows the pointer: the crosshair, its readouts, and the
  /// legends, which read out the candle under it.
  ///
  /// Reuses the geometry [paint] worked out. On a frame where only the pointer
  /// moved that is last frame's answer, which is the point: nothing the chart
  /// is drawn from has changed, so nothing has to be measured again.
  void paintOverlay(Canvas canvas, Size size) {
    _overlayPaints++;
    if (!hasLayout) layout(size);
    if (candles == null || candles!.isEmpty) return;

    canvas.clipRect(Rect.fromLTRB(0, 0, size.width, size.height));
    canvas.save();
    if (showCrosshair) {
      // The crosshair is measured in candle space, like the candles it picks
      // out, so it takes the same transform they are drawn in.
      canvas.save();
      canvas.translate(mPlotLeft + mTranslateX * scaleX, 0.0);
      canvas.scale(scaleX, 1.0);
      drawCrossLine(canvas, size);
      canvas.restore();
    }
    drawText(canvas, candles!.last, 5);
    if (showCrosshair) {
      drawCrossLineText(canvas, size);
    }
    canvas.restore();
  }

  /// init chart renderer
  void initChartRenderer();

  /// draw the background of chart
  void drawBg(Canvas canvas, Size size);

  /// draw the grid of chart
  void drawGrid(Canvas canvas);

  /// draw chart
  void drawChart(Canvas canvas, Size size);

  /// draw vertical text
  void drawVerticalText(Canvas canvas);

  /// draw date
  void drawDate(Canvas canvas, Size size);

  /// draw text
  void drawText(Canvas canvas, KLineEntity data, double x);

  /// draw maximum and minimum values
  void drawMaxAndMin(Canvas canvas);

  /// draw the current price
  void drawNowPrice(Canvas canvas);

  /// draw cross line
  void drawCrossLine(Canvas canvas, Size size);

  /// draw text of the cross line
  void drawCrossLineText(Canvas canvas, Size size);

  void drawSignals(Canvas canvas);

  /// Smallest the candle area may become before the panes below it give way.
  static const double minMainHeight = 60.0;

  /// init the rectangle box to draw chart
  void initRect(Size size) {
    var volHeight = baseDimension.mVolumeHeight;
    var paneHeights = baseDimension.paneHeights;
    var totalSecondaryHeight = baseDimension.totalSecondaryHeight;

    double mainHeight = mDisplayHeight - volHeight - totalSecondaryHeight;

    // In a box shorter than the panes ask for, shrink the panes instead of
    // letting the candle area collapse and the panes overlap it.
    if (mainHeight < minMainHeight) {
      final requested = volHeight + totalSecondaryHeight;
      final room = max(mDisplayHeight - minMainHeight, 0.0);
      final factor =
          requested <= 0 ? 0.0 : (room / requested).clamp(0.0, 1.0).toDouble();
      volHeight *= factor;
      paneHeights = [for (final height in paneHeights) height * factor];
      totalSecondaryHeight *= factor;
      mainHeight = max(mDisplayHeight - room, 0.0);
    }

    mMainRect = Rect.fromLTRB(
      mPlotLeft,
      mTopPadding,
      mPlotLeft + mWidth,
      mTopPadding + mainHeight,
    );
    _hasLayout = true;

    if (volHidden != true) {
      mVolRect = Rect.fromLTRB(
        mPlotLeft,
        mMainRect.bottom + mChildPadding,
        mPlotLeft + mWidth,
        mMainRect.bottom + volHeight,
      );
    }

    mSecondaryRectList.clear();
    var top = mMainRect.bottom + volHeight;
    for (int i = 0; i < panes.length; ++i) {
      final height = i < paneHeights.length
          ? paneHeights[i]
          : BaseDimension.secondaryPaneHeight;
      mSecondaryRectList.add(
        RenderRect(
          Rect.fromLTRB(
            mPlotLeft,
            top + mChildPadding,
            mPlotLeft + mWidth,
            top + height,
          ),
        ),
      );
      top += height;
    }
  }

  /// Whether the candles were spread to fill the plot on this layout.
  ///
  /// False when [ChartStyle.fitContent] is off, and when it is on but the
  /// series is long enough to fill the plot at its own spacing.
  bool contentFitted = false;

  /// Widens the candle spacing to fill the plot when the series is too short
  /// to reach the right edge on its own.
  ///
  /// The series is spread over the whole plot less [xFrontPadding], so the
  /// last candle's body ends at the right edge rather than a fraction of the
  /// way in.
  void fitContent() {
    mPointWidth = chartStyle.pointWidth;
    fittedStyle = chartStyle;
    contentFitted = false;
    if (!chartStyle.fitContent || mItemCount == 0) {
      mDataLen = mItemCount * mPointWidth;
      return;
    }

    final available = mWidth / scaleX - xFrontPadding;
    final fitted = available / mItemCount;
    if (fitted > mPointWidth) {
      final spread = fitted / mPointWidth;
      mPointWidth = fitted;
      contentFitted = true;
      fittedStyle = chartStyle.copyWith(
        pointWidth: fitted,
        candleWidth: chartStyle.candleWidth * spread,
        volWidth: chartStyle.volWidth * spread,
      );
    }
    mDataLen = mItemCount * mPointWidth;
  }

  /// calculate values
  void calculateValue() {
    if (candles == null) return;
    if (candles!.isEmpty) return;
    maxScrollX = getMinTranslateX().abs();
    setTranslateXFromScrollX(scrollX);
    mStartIndex = indexOfTranslateX(xToTranslateX(mPlotLeft));
    mStopIndex = indexOfTranslateX(xToTranslateX(mPlotLeft + mWidth));
    // Pinned before the range is measured: a rebased comparison starts from the
    // left edge of the window, so where it sits depends on the window and what
    // it contributes to the range depends on where it sits.
    comparisonAnchors = [
      for (final comparison in comparisons)
        comparisonAnchor(comparison, candles!, mStartIndex, mStopIndex),
    ];
    for (int i = mStartIndex; i <= mStopIndex; i++) {
      final item = candles![i];
      getMainMaxMinValue(item, i);
      getVolMaxMinValue(item);
    }
    calculatePaneRanges();
  }

  /// Fits each pane's scale to the values it has to draw.
  void calculatePaneRanges() {
    for (int index = 0; index < mSecondaryRectList.length; ++index) {
      if (index >= panes.length) break;
      final rect = mSecondaryRectList[index];
      final resolved = panes[index];

      final fixed = resolved.indicator.fixedRange;
      if (fixed != null) {
        rect.mMinValue = fixed.$1;
        rect.mMaxValue = fixed.$2;
        continue;
      }

      if (resolved.indicator.includeZero) {
        rect.mMaxValue = max(rect.mMaxValue, 0);
        rect.mMinValue = min(rect.mMinValue, 0);
      }
      for (int line = 0; line < resolved.series.lines.length; ++line) {
        for (int i = mStartIndex; i <= mStopIndex; i++) {
          final value = resolved.valueAt(line, i);
          if (value == null || !value.isFinite) continue;
          rect.mMaxValue = max(rect.mMaxValue, value);
          rect.mMinValue = min(rect.mMinValue, value);
        }
      }
      rect.normalize();
    }
  }

  /// compute maximum and minimum value
  void getMainMaxMinValue(KLineEntity item, int i) {
    double maxPrice = item.high;
    double minPrice = item.low;

    // An overlay may sit outside the candles it is drawn over — a long average
    // lags, a band steps outside — so the price scale has to hold it too.
    for (final overlay in overlays) {
      for (int line = 0; line < overlay.series.lines.length; ++line) {
        final value = overlay.valueAt(line, i);
        if (value == null || !value.isFinite) continue;
        maxPrice = max(maxPrice, value);
        minPrice = min(minPrice, value);
      }
    }

    // A compared instrument shares the scale, so the scale has to hold it: two
    // instruments that moved differently is the whole point of drawing them
    // together.
    for (final (ordinal, comparison) in comparisons.indexed) {
      final anchor = ordinal < comparisonAnchors.length
          ? comparisonAnchors[ordinal]
          : null;
      final price = comparisonPriceAt(comparison, i, anchor);
      if (price == null || !price.isFinite) continue;
      maxPrice = max(maxPrice, price);
      minPrice = min(minPrice, price);
    }

    mMainMaxValue = max(mMainMaxValue, maxPrice);
    mMainMinValue = min(mMainMinValue, minPrice);

    if (mMainHighMaxValue < item.high) {
      mMainHighMaxValue = item.high;
      mMainMaxIndex = i;
    }
    if (mMainLowMinValue > item.low) {
      mMainLowMinValue = item.low;
      mMainMinIndex = i;
    }

    if (isLine == true) {
      mMainMaxValue = max(mMainMaxValue, item.close);
      mMainMinValue = min(mMainMinValue, item.close);
    }
  }

  // get the maximum and minimum of the Vol value
  void getVolMaxMinValue(KLineEntity item) {
    mVolMaxValue = max(
      mVolMaxValue,
      max(item.vol, max(item.ma5Volume ?? 0, item.ma10Volume ?? 0)),
    );
    mVolMinValue = min(
      mVolMinValue,
      min(item.vol, min(item.ma5Volume ?? 0, item.ma10Volume ?? 0)),
    );
  }

  // translate x
  double xToTranslateX(double x) => -mTranslateX + (x - mPlotLeft) / scaleX;

  int indexOfTranslateX(double translateX) =>
      _indexOfTranslateX(translateX, 0, mItemCount - 1);

  /// Using binary search for the index of the current value
  int _indexOfTranslateX(double translateX, int start, int end) {
    if (end == start || end == -1) {
      return start;
    }
    if (end - start == 1) {
      final startValue = getX(start);
      final endValue = getX(end);
      return (translateX - startValue).abs() < (translateX - endValue).abs()
          ? start
          : end;
    }
    final mid = start + (end - start) ~/ 2;
    final midValue = getX(mid);
    if (translateX < midValue) {
      return _indexOfTranslateX(translateX, start, mid);
    } else if (translateX > midValue) {
      return _indexOfTranslateX(translateX, mid, end);
    } else {
      return mid;
    }
  }

  /// Get x coordinate based on index
  /// + mPointWidth / 2 to prevent the first and last K-line from displaying incorrectly
  /// @param position index value
  double getX(int position) => position * mPointWidth + mPointWidth / 2;

  KLineEntity getItem(int position) {
    return candles![position];
  }

  /// scrollX convert to TranslateX
  void setTranslateXFromScrollX(double scrollX) =>
      mTranslateX = scrollX + getMinTranslateX();

  /// get the minimum value of translation
  double getMinTranslateX() {
    // A fitted series is exactly as wide as the plot, so the half point the
    // scroll normally leaves for the last candle's centre would be scrollable
    // slack. There is nothing to scroll to; hold it at zero.
    if (contentFitted) return 0.0;
    final x = -mDataLen + mWidth / scaleX - mPointWidth / 2 - xFrontPadding;
    return x >= 0 ? 0.0 : x;
  }

  /// calculate the value of x after long pressing and convert to [index]
  int calculateSelectedX(double selectX) {
    int mSelectedIndex = indexOfTranslateX(xToTranslateX(selectX));
    if (mSelectedIndex < mStartIndex) {
      mSelectedIndex = mStartIndex;
    }
    if (mSelectedIndex > mStopIndex) {
      mSelectedIndex = mStopIndex;
    }
    return mSelectedIndex;
  }

  /// translateX is converted to X in view
  double translateXtoX(double translateX) =>
      (translateX + mTranslateX) * scaleX + mPlotLeft;

  /// define text style
  TextStyle getTextStyle(Color color) {
    return TextStyle(fontSize: 10.0, color: color);
  }

  @override
  bool shouldRepaint(BaseChartPainter oldDelegate) {
    return true;
  }
}

/// Render Rectangle
class RenderRect {
  RenderRect(this.mRect);

  Rect mRect;
  double mMaxValue = -double.maxFinite;
  double mMinValue = double.maxFinite;

  /// True once at least one value has been folded in.
  bool get hasValues => mMaxValue >= mMinValue;

  /// Collapses an untouched rect to a flat 0..0 range so painters never see
  /// the infinite seed values.
  void normalize() {
    if (!hasValues) {
      mMaxValue = 0;
      mMinValue = 0;
    }
  }
}
