import 'dart:math';

import 'package:flutter/material.dart'
    show Color, TextStyle, Rect, Canvas, Size, CustomPainter;

import '../chart_style.dart' show ChartStyle;
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
    this.volHidden = false,
    this.isTapShowInfoDialog = false,
    this.isLine = false,
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

  /// Rectangle box of the vol chart
  Rect? mVolRect;

  /// Secondary list support
  List<RenderRect> mSecondaryRectList = [];
  late double mDisplayHeight;
  late double mWidth;

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
    final secondTime =
        ((candles?.length ?? 0) > 1
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

  /// paint chart
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Rect.fromLTRB(0, 0, size.width, size.height));
    mDisplayHeight = size.height - mTopPadding - mBottomPadding;
    mWidth = size.width;
    initRect(size);
    calculateValue();
    initChartRenderer();

    canvas.save();
    canvas.scale(1, 1);
    drawBg(canvas, size);
    drawGrid(canvas);
    if (candles != null && candles!.isNotEmpty) {
      drawChart(canvas, size);
      drawVerticalText(canvas);
      drawDate(canvas, size);

      drawText(canvas, candles!.last, 5);
      drawNowPrice(canvas);
      drawMaxAndMin(canvas);
      drawSignals(canvas);
      if (showCrosshair) {
        drawCrossLineText(canvas, size);
      }
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

  void drawWatermarkLogo(Canvas canvas, Size size);

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
      final factor = requested <= 0
          ? 0.0
          : (room / requested).clamp(0.0, 1.0).toDouble();
      volHeight *= factor;
      paneHeights = [for (final height in paneHeights) height * factor];
      totalSecondaryHeight *= factor;
      mainHeight = max(mDisplayHeight - room, 0.0);
    }

    mMainRect = Rect.fromLTRB(0, mTopPadding, mWidth, mTopPadding + mainHeight);

    if (volHidden != true) {
      mVolRect = Rect.fromLTRB(
        0,
        mMainRect.bottom + mChildPadding,
        mWidth,
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
        RenderRect(Rect.fromLTRB(0, top + mChildPadding, mWidth, top + height)),
      );
      top += height;
    }
  }

  /// calculate values
  void calculateValue() {
    if (candles == null) return;
    if (candles!.isEmpty) return;
    maxScrollX = getMinTranslateX().abs();
    setTranslateXFromScrollX(scrollX);
    mStartIndex = indexOfTranslateX(xToTranslateX(0));
    mStopIndex = indexOfTranslateX(xToTranslateX(mWidth));
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
  double xToTranslateX(double x) => -mTranslateX + x / scaleX;

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
      (translateX + mTranslateX) * scaleX;

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
