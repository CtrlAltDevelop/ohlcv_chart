import 'dart:async' show StreamSink;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart' as vg;

import '../drawing/line_painting.dart';
import '../entity/horizontal_line.dart';
import '../entity/info_window_entity.dart';
import '../export.dart';
import '../utils/date_format_util.dart';
import 'base_chart_painter.dart';
import 'base_chart_renderer.dart';
import 'indicator_pane_renderer.dart';
import 'main_renderer.dart';
import 'vol_renderer.dart';

enum CrossArea { main, volume, secondary, none }

class ChartPainter extends BaseChartPainter {
  ChartPainter(
    super.chartStyle,
    this.chartColors, {
    required this.showLiveHorizontalPreview,
    required this.showLiveVerticalPreview,
    required this.currentDrawingTool,
    required this.isDrawing,
    required this.watermarkPicture,
    required this.trendLines,
    required this.horizontalLines,
    required this.verticalLines,
    required this.signals,
    required this.isTrendLine,
    required this.selectY,
    required this.sink,
    required super.candles,
    required super.scaleX,
    required super.scrollX,
    required super.isLongPress,
    required super.selectX,
    required super.xFrontPadding,
    required super.baseDimension,
    required this.verticalTextAlignment,
    required this.timeFrame,
    required this.tempTrendLine,
    required this.selectedHorizontal,
    required this.selectedVertical,
    required this.selectedTrend,
    this.drawingStyle = const DrawingStyle(),
    super.suppressCrosshair,
    super.isOnTap,
    super.isTapShowInfoDialog,
    super.overlays,
    super.panes,
    super.volHidden,
    super.isLine = false,
    this.hideGrid = false,
    this.showNowPrice = true,
    this.fixedLength = 2,
    this.dateFormatter,
  }) {
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

  final List<TrendLine> trendLines;
  final List<HorizontalLine> horizontalLines;
  final List<VerticalLine> verticalLines;
  final List<SignalEntity> signals;
  final bool isTrendLine;
  final TrendLine? tempTrendLine;
  final double selectY;
  final StreamSink<InfoWindowEntity?> sink;
  final HorizontalLine? selectedHorizontal;
  final VerticalLine? selectedVertical;
  final TrendLine? selectedTrend;
  final bool isDrawing;
  final DrawingTool currentDrawingTool;
  final bool showLiveVerticalPreview;
  final bool showLiveHorizontalPreview;

  /// Geometry and palette used for the user-drawn lines and their labels.
  final DrawingStyle drawingStyle;

  final ChartColors chartColors;
  late Paint selectPointPaint;
  late Paint selectorBorderPaint;
  late Paint nowPricePaint;
  final bool hideGrid;
  final bool showNowPrice;
  final VerticalTextAlignment verticalTextAlignment;
  final String Function(KLineEntity entity, bool isCrossLine)? dateFormatter;
  final vg.PictureInfo? watermarkPicture;
  final Duration timeFrame;
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

  @override
  void initChartRenderer() {
    mMainRenderer = MainRenderer(
      mMainRect,
      mMainMaxValue,
      mMainMinValue,
      mTopPadding,
      overlays,
      isLine,
      fixedLength,
      chartStyle,
      chartColors,
      scaleX,
      verticalTextAlignment,
      mVolRect != null || mSecondaryRectList.isNotEmpty,
    );
    if (mVolRect != null) {
      mVolRenderer = VolRenderer(
        mVolRect!,
        mVolMaxValue,
        mVolMinValue,
        mChildPadding,
        fixedLength,
        chartStyle,
        chartColors,
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
        ),
    ];
  }

  @override
  void drawBg(Canvas canvas, Size size) {
    final mBgPaint = Paint()..color = chartColors.bgColor;
    final mainRect = Rect.fromLTRB(
      0,
      0,
      mMainRect.width,
      mMainRect.height + mTopPadding,
    );
    canvas.drawRect(mainRect, mBgPaint);

    if (mVolRect != null) {
      final volRect = Rect.fromLTRB(
        0,
        mVolRect!.top - mChildPadding,
        mVolRect!.width,
        mVolRect!.bottom,
      );
      canvas.drawRect(volRect, mBgPaint);
    }

    for (int i = 0; i < mSecondaryRectList.length; ++i) {
      final mSecondaryRect = mSecondaryRectList[i].mRect;
      final secondaryRect = Rect.fromLTRB(
        0,
        mSecondaryRect.top - mChildPadding,
        mSecondaryRect.width,
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
    drawWatermarkLogo(canvas, size);
  }

  @override
  void drawGrid(Canvas canvas) {
    if (!hideGrid) {
      mMainRenderer.drawGrid(canvas, mGridRows, mGridColumns);
      mVolRenderer?.drawGrid(canvas, mGridRows, mGridColumns);
      for (final pane in mIndicatorPaneList) {
        pane.drawGrid(canvas, mGridRows, mGridColumns);
      }
    }
  }

  @override
  void drawChart(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(mTranslateX * scaleX, 0.0);
    canvas.scale(scaleX, 1.0);

    for (int i = mStartIndex; candles != null && i <= mStopIndex; i++) {
      final curPoint = candles?[i];
      if (curPoint == null) continue;
      final lastPoint = i == 0 ? curPoint : candles![i - 1];
      final curX = getX(i);
      final lastX = i == 0 ? curX : getX(i - 1);

      mMainRenderer.drawChart(lastPoint, curPoint, lastX, curX, size, canvas);
      mVolRenderer?.drawChart(lastPoint, curPoint, lastX, curX, size, canvas);
    }

    if (showCrosshair) {
      drawCrossLine(canvas, size);
    }
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

    // User-drawn lines paint in view space, once the horizontal scale is
    // restored: a stroke then keeps the thickness it was given whatever the
    // zoom level, and a drag handle stays a circle instead of an ellipse.
    drawHorizontalLines(canvas, size);
    drawVerticalLines(canvas, size);
    drawTrendLines(canvas, size);

    drawHorizontalLineTitles(canvas, size);
    drawVerticalLineTitles(canvas, size);
    drawTrendLineLabels(canvas, size);
  }

  void drawHorizontalLines(Canvas canvas, Size size) {
    final effectiveHorizontals = [...horizontalLines];
    if (selectedHorizontal != null &&
        isDrawing &&
        currentDrawingTool == DrawingTool.horizontal) {
      effectiveHorizontals.add(selectedHorizontal!);
    }

    for (final line in effectiveHorizontals) {
      final y = getMainY(line.price);
      strokeChartLine(canvas, Offset(0, y), Offset(size.width, y), line);

      if (line == selectedHorizontal) {
        final radius = drawingStyle.handleRadius;
        final top = mMainRect.top + radius;
        final bottom = math.max(top, mMainRect.bottom - radius);
        drawLineHandle(
          canvas,
          Offset(size.width / 2, y.clamp(top, bottom)),
          line,
        );
      }
    }
  }

  void drawHorizontalLineTitles(Canvas canvas, Size size) {
    for (final line in horizontalLines) {
      if (!line.showLabel) continue;

      final y = getMainY(line.price);
      final title = line.title ?? line.price.toStringAsFixed(fixedLength);
      final tp = getLabelPainter(title, line.color);
      final padding = drawingStyle.labelPadding;

      final textX = verticalTextAlignment == VerticalTextAlignment.right
          ? size.width - tp.width - padding.right - 8
          : 8.0 + padding.left;

      drawLineLabel(canvas, tp, Offset(textX, y - tp.height / 2), line.color);
    }
  }

  void drawVerticalLines(Canvas canvas, Size size) {
    final effectiveVerticals = [...verticalLines];
    if (selectedVertical != null && showLiveVerticalPreview) {
      effectiveVerticals.add(selectedVertical!);
    }

    for (final line in effectiveVerticals) {
      final index = candles!.indexWhere((e) => e.dateTime == line.time);
      if (index == -1) continue;

      final x = translateXtoX(getX(index));
      strokeChartLine(
        canvas,
        Offset(x, mTopPadding),
        Offset(x, size.height - mBottomPadding),
        line,
      );

      if (line == selectedVertical) {
        drawLineHandle(canvas, Offset(x, mMainRect.center.dy), line);
      }
    }
  }

  void drawVerticalLineTitles(Canvas canvas, Size size) {
    for (final line in verticalLines) {
      if (!line.showLabel) continue;

      final index = candles!.indexWhere((e) => e.dateTime == line.time);
      if (index == -1) continue;

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
    final effectiveTrends = [...trendLines];
    if (tempTrendLine != null) effectiveTrends.add(tempTrendLine!);

    for (final line in effectiveTrends) {
      final index1 = candles!.indexWhere((e) => e.dateTime == line.time1);
      if (index1 == -1) continue;

      final start = Offset(translateXtoX(getX(index1)), getMainY(line.price1));

      if (line.time2 == null || line.price2 == null) {
        // Still being drawn: only the anchor exists so far.
        drawLineHandle(canvas, start, line);
        continue;
      }

      final index2 = candles!.indexWhere((e) => e.dateTime == line.time2!);
      if (index2 == -1) continue;
      final end = Offset(translateXtoX(getX(index2)), getMainY(line.price2!));

      strokeChartLine(canvas, start, end, line);

      if (line == selectedTrend) {
        drawLineHandle(canvas, start, line);
        drawLineHandle(canvas, end, line);
      }
    }
  }

  void drawTrendLineLabels(Canvas canvas, Size size) {
    for (final line in trendLines) {
      if (!line.showLabel || line.time2 == null || line.price2 == null) {
        continue;
      }

      final i1 = candles!.indexWhere((e) => e.dateTime == line.time1);
      final i2 = candles!.indexWhere((e) => e.dateTime == line.time2);
      if (i1 == -1 || i2 == -1) continue;

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
    if (candles == null) return;

    final columnSpace = size.width / mGridColumns;
    final startX = getX(mStartIndex) - mPointWidth / 2;
    final stopX = getX(mStopIndex) + mPointWidth / 2;

    for (var i = 0; i <= mGridColumns; ++i) {
      final translateX = xToTranslateX(columnSpace * i);

      if (translateX >= startX && translateX <= stopX) {
        final index = indexOfTranslateX(translateX);
        if (candles?[index] == null) continue;

        final tp = getTextPainter(
          dateFormatter?.call(candles![index], false) ??
              getDate(candles![index].dateTime),
          null,
        );
        final y = size.height - (mBottomPadding - tp.height) / 2 - tp.height;
        var x = columnSpace * i - tp.width / 2;
        if (x < 0) x = 0;
        if (x > size.width - tp.width) x = size.width - tp.width;

        tp.paint(canvas, Offset(x, y));
      }
    }
  }

  double calculatePrice(double y) {
    return mMainMaxValue - (y - mMainRect.top) / mMainRenderer.scaleY;
  }

  CrossArea getCrossArea(double y) {
    if (mMainRect.contains(Offset(0, y))) return CrossArea.main;
    if (mVolRect != null && mVolRect!.contains(Offset(0, y))) {
      return CrossArea.volume;
    }
    for (final sec in mSecondaryRectList) {
      if (sec.mRect.contains(Offset(0, y))) return CrossArea.secondary;
    }
    return CrossArea.none;
  }

  IndicatorPaneRenderer? _getSecondaryRendererByY(double y) {
    for (int i = 0; i < mSecondaryRectList.length; i++) {
      if (mSecondaryRectList[i].mRect.contains(Offset(0, y)) &&
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
        value =
            mMainMaxValue - (selectY - mMainRect.top) / mMainRenderer.scaleY;
        valueText = value.toStringAsFixed(fixedLength);
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

    if (translateXtoX(getX(index)) < mWidth / 2) {
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
      x = mWidth - textWidth - 1 - 2 * w1 - w2;

      final path = Path()
        ..moveTo(x, selectY)
        ..lineTo(x + w2, selectY + r)
        ..lineTo(mWidth - 2, selectY + r)
        ..lineTo(mWidth - 2, selectY - r)
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
    } else if (mWidth - dateX < dateTp.width / 2 + w1) {
      dateX = mWidth - dateTp.width / 2 - w1;
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
      sink.add(
        InfoWindowEntity(
          point,
          kLinePreviousEntity: getItem(index - 1),
          isLeft: isLeft,
        ),
      );
    }
  }

  @override
  void drawText(Canvas canvas, KLineEntity dataO, double x) {
    // The legends read out the candle under the crosshair, or the newest one.
    var index = (candles?.length ?? 1) - 1;
    if (isLongPress || (isTapShowInfoDialog && isOnTap)) {
      index = calculateSelectedX(selectX);
    }
    final data = getItem(index);

    mMainRenderer.drawLegends(canvas, index, x);
    mVolRenderer?.drawText(canvas, data, x);
    for (final pane in mIndicatorPaneList) {
      pane.drawLegendAt(canvas, index, x);
    }
  }

  @override
  void drawMaxAndMin(Canvas canvas) {
    if (isLine) return;
    drawExtreme(canvas, mMainMinIndex, mMainLowMinValue, chartColors.minColor);
    drawExtreme(canvas, mMainMaxIndex, mMainHighMaxValue, chartColors.maxColor);
  }

  /// Labels one extreme of the visible range with a short leader line pointing
  /// back at the candle that set it.
  void drawExtreme(Canvas canvas, int index, double value, Color color) {
    const leader = 8.0;
    const gap = 3.0;

    final x = translateXtoX(getX(index));
    final y = getMainY(value);
    final tp = getTextPainter(value.toStringAsFixed(fixedLength), color);
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..isAntiAlias = true;

    // Point away from the nearer edge so the label always has room.
    final pointsRight = x < mWidth / 2;
    final textLeft = pointsRight
        ? math.min(x + leader + gap, mWidth - tp.width - 2)
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

    nowPricePaint.color = value >= open
        ? chartColors.nowPriceUpColor
        : chartColors.nowPriceDnColor;

    // Dashes run the full width so the level can be read anywhere, while the
    // stretch since the last candle stays solid.
    final lastX = translateXtoX(getX(candles!.length - 1)).clamp(0.0, mWidth);
    if (chartStyle.nowPriceDashed) {
      paintStyledLine(
        canvas,
        Offset(0, y),
        Offset(lastX, y),
        nowPricePaint,
        style: LineStyle.dashed,
        dashLength: chartStyle.nowPriceLineLength,
        dashGap: chartStyle.nowPriceLineSpan,
      );
    } else {
      canvas.drawLine(Offset(0, y), Offset(lastX, y), nowPricePaint);
    }
    canvas.drawLine(Offset(lastX, y), Offset(mWidth, y), nowPricePaint);

    String countdown = '00:00';
    if (last.dateTime != null) {
      final closeTime = last.dateTime!.add(timeFrame);
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
      '${value.toStringAsFixed(fixedLength)} ($countdown)',
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
        ? mWidth - tagWidth - 1
        : 1.0;
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

      final linePaint = Paint()
        ..color = signal.color
        ..strokeWidth = chartStyle.nowPriceLineWidth
        ..isAntiAlias = true;

      paintStyledLine(
        canvas,
        Offset(0, y),
        Offset(mWidth, y),
        linePaint,
        style: signal.useDash ? LineStyle.dashed : LineStyle.solid,
        dashLength: chartStyle.nowPriceLineLength,
        dashGap: chartStyle.nowPriceLineSpan,
      );

      final tp = getTextPainter(
        '${signal.title} ${value.toStringAsFixed(fixedLength)}',
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

  TextPainter getTextPainter(String text, Color? color, {double? fontSize}) {
    final c = color ?? chartColors.defaultTextColor;
    final style = fontSize == null
        ? getTextStyle(c)
        : getTextStyle(c).copyWith(fontSize: fontSize);
    final span = TextSpan(text: text, style: style);
    final tp = TextPainter(text: span, textDirection: TextDirection.ltr);
    tp.layout();
    return tp;
  }

  String getDate(DateTime? date) =>
      dateFormat(date ?? DateTime.now(), mFormats);

  double getMainY(double y) => mMainRenderer.getY(y);

  @override
  void drawWatermarkLogo(Canvas canvas, Size size) {
    final picture = watermarkPicture;
    if (picture == null) return;

    final area = Rect.fromLTRB(
      0,
      mTopPadding,
      mWidth,
      mTopPadding + mMainRect.height,
    );
    final logoWidth =
        math.min(area.width, area.height) * chartStyle.watermarkScale;
    final scale = logoWidth / picture.size.width;
    final logoHeight = picture.size.height * scale;

    final spot = chartStyle.watermarkAlignment.inscribe(
      Size(logoWidth, logoHeight),
      area,
    );

    canvas.save();
    canvas.saveLayer(
      spot,
      Paint()..color = chartColors.effectiveWatermarkColor,
    );
    canvas.translate(spot.left, spot.top);
    canvas.scale(scale, scale);
    canvas.drawPicture(picture.picture);
    canvas.restore();
    canvas.restore();
  }
}
