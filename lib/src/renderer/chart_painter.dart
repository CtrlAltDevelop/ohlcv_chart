import 'dart:async' show StreamSink;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart' as vg;

import '../entity/horizontal_line.dart';
import '../entity/info_window_entity.dart';
import '../export.dart';
import '../utils/date_format_util.dart';
import 'base_chart_painter.dart';
import 'base_chart_renderer.dart';
import 'main_renderer.dart';
import 'secondary_renderer.dart';
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
    super.isOnTap,
    super.isTapShowInfoDialog,
    super.mainStateLi,
    super.volHidden,
    super.secondaryStateLi,
    super.isLine = false,
    this.hideGrid = false,
    this.showNowPrice = true,
    this.fixedLength = 2,
    this.maDayList = const [5, 10, 20],
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
  List<int> maDayList;

  late BaseChartRenderer<dynamic> mMainRenderer;
  BaseChartRenderer<dynamic>? mVolRenderer;
  Set<BaseChartRenderer<dynamic>> mSecondaryRendererList = {};

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
      mainStateLi.toList(),
      isLine,
      fixedLength,
      chartStyle,
      chartColors,
      scaleX,
      verticalTextAlignment,
      maDayList,
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
    mSecondaryRendererList.clear();
    for (int i = 0; i < mSecondaryRectList.length; ++i) {
      mSecondaryRendererList.add(
        SecondaryRenderer(
          mSecondaryRectList[i].mRect,
          mSecondaryRectList[i].mMaxValue,
          mSecondaryRectList[i].mMinValue,
          mChildPadding,
          secondaryStateLi.elementAt(i),
          fixedLength,
          chartStyle,
          chartColors,
        ),
      );
    }
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
      for (final element in mSecondaryRendererList) {
        element.drawGrid(canvas, mGridRows, mGridColumns);
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
      for (final element in mSecondaryRendererList) {
        element.drawChart(lastPoint, curPoint, lastX, curX, size, canvas);
      }
    }

    if ((isLongPress == true || (isTapShowInfoDialog && isOnTap)) &&
        !isTrendLine) {
      drawCrossLine(canvas, size);
    }

    drawHorizontalLines(canvas, size);
    drawVerticalLines(canvas, size);
    drawTrendLines(canvas, size);
    canvas.restore();

    drawTrendLineLabels(canvas, size);
    drawHorizontalLineTitles(canvas, size);
    drawVerticalLineTitles(canvas, size);
  }

  void drawHorizontalLines(Canvas canvas, Size size) {
    final effectiveHorizontals = [...horizontalLines];
    if (selectedHorizontal != null &&
        isDrawing &&
        currentDrawingTool == DrawingTool.horizontal) {
      effectiveHorizontals.add(selectedHorizontal!);
    }

    for (final line in effectiveHorizontals) {
      final paint = Paint()
        ..color = line.color
        ..strokeWidth = line.thickness
        ..isAntiAlias = true;

      final y = getMainY(line.price);

      final start = Offset(-mTranslateX, y);
      final end = Offset(-mTranslateX + mWidth / scaleX, y);

      if (line.isDashed) {
        drawDashedLine(canvas, start, end, paint);
      } else {
        canvas.drawLine(start, end, paint);
      }

      if (line == selectedHorizontal) {
        final visibleLeft = -mTranslateX;
        final visibleRight = -mTranslateX + mWidth / scaleX;
        final handleX = visibleLeft + (visibleRight - visibleLeft) / 2;
        final handleY = y.clamp(mMainRect.top + 20, mMainRect.bottom - 20);
        canvas.drawCircle(
          Offset(handleX, handleY),
          10,
          Paint()
            ..color = line.color
            ..style = PaintingStyle.fill,
        );
      }
    }
  }

  void drawHorizontalLineTitles(Canvas canvas, Size size) {
    for (final line in horizontalLines) {
      if (!line.showLabel) continue;

      final y = getMainY(line.price);
      final title = line.title ?? line.price.toStringAsFixed(fixedLength);
      final tp = getTextPainter(title, line.color);

      final offsetX = verticalTextAlignment == VerticalTextAlignment.right
          ? size.width - tp.width - 8 - kLabelPaddingH * 2
          : 8.0;

      final top = y - tp.height / 2;

      final rect = RRect.fromLTRBR(
        offsetX - kLabelPaddingH,
        top - kLabelPaddingV,
        offsetX + tp.width + kLabelPaddingH * 2,
        top + tp.height + kLabelPaddingV * 2,
        const Radius.circular(kLabelCornerRadius),
      );

      // Background - neutral semi-transparent
      canvas.drawRRect(
        rect,
        Paint()
          ..color = chartColors.defaultTextColor.withAlpha(kLabelBgOpacity),
      );

      // Border - line color
      canvas.drawRRect(
        rect,
        Paint()
          ..color = line.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = kLabelBorderWidth,
      );

      tp.paint(canvas, Offset(offsetX, top));
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

      final paint = Paint()
        ..color = line.color
        ..strokeWidth = line.thickness
        ..isAntiAlias = true;

      final x = getX(index);
      final start = Offset(x, mTopPadding);
      final end = Offset(x, size.height - mBottomPadding);

      if (line.isDashed) {
        drawDashedLine(canvas, start, end, paint);
      } else {
        canvas.drawLine(start, end, paint);
      }

      // ── Label ───────────────────────────────────────────────────────────────
      final title = line.title ?? getDate(line.time);
      final tp = getTextPainter(title, line.color);

      final dateX = translateXtoX(x);

      // Bottom position - you can adjust this value
      const double bottomY = 8.0;

      final rect = RRect.fromLTRBR(
        dateX - tp.width / 2 - kLabelPaddingH,
        bottomY,
        dateX + tp.width / 2 + kLabelPaddingH * 2,
        bottomY + tp.height + kLabelPaddingV * 2,
        const Radius.circular(kLabelCornerRadius),
      );

      // Background - same as horizontal & trend
      canvas.drawRRect(
        rect,
        Paint()
          ..color = chartColors.defaultTextColor.withAlpha(kLabelBgOpacity),
      );

      // Border - same as others
      canvas.drawRRect(
        rect,
        Paint()
          ..color = line.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = kLabelBorderWidth,
      );

      // Text centered
      tp.paint(canvas, Offset(dateX - tp.width / 2, bottomY + kLabelPaddingV));

      // Selection handle
      if (line == selectedVertical) {
        final visibleTop = mMainRect.top;
        final visibleBottom = mMainRect.bottom;
        final handleY = visibleTop + (visibleBottom - visibleTop) / 2;
        canvas.drawCircle(
          Offset(x, handleY),
          10,
          Paint()
            ..color = line.color
            ..style = PaintingStyle.fill,
        );
      }
    }
  }

  void drawTrendLines(Canvas canvas, Size size) {
    final effectiveTrends = [...trendLines];
    if (tempTrendLine != null) effectiveTrends.add(tempTrendLine!);

    for (final line in effectiveTrends) {
      final index1 = candles!.indexWhere((e) => e.dateTime == line.time1);
      if (index1 == -1) continue;

      final x1 = getX(index1);
      final y1 = getMainY(line.price1);

      if (line.time2 == null || line.price2 == null) {
        canvas.drawCircle(
          Offset(x1, y1),
          10,
          Paint()
            ..color = line.color
            ..style = PaintingStyle.fill,
        );
        continue;
      }

      final index2 = candles!.indexWhere((e) => e.dateTime == line.time2!);
      if (index2 == -1) continue;
      final x2 = getX(index2);
      final y2 = getMainY(line.price2!);

      final paint = Paint()
        ..color = line.color
        ..strokeWidth = line.thickness
        ..isAntiAlias = true;

      final start = Offset(x1, y1);
      final end = Offset(x2, y2);

      if (line.isDashed) {
        drawDashedLine(canvas, start, end, paint);
      } else {
        canvas.drawLine(start, end, paint);
      }

      if (line == selectedTrend) {
        canvas.drawCircle(
          Offset(x1, y1),
          10,
          Paint()
            ..color = line.color
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          Offset(x2, y2),
          10,
          Paint()
            ..color = line.color
            ..style = PaintingStyle.fill,
        );
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

      final tp1 = getTextPainter(label1, line.color);
      final tp2 = getTextPainter(label2, line.color);

      // Point 1 Label (left side or above)
      double label1X = x1 - tp1.width - 10;
      final label1Y = y1 - tp1.height / 2;
      if (label1X < 10) label1X = x1 + 10; // flip to right if too left

      _drawLabel(canvas, label1X, label1Y, tp1, line.color);

      // Point 2 Label (right side or below)
      double label2X = x2 + 10;
      final label2Y = y2 - tp2.height / 2;
      if (label2X + tp2.width > size.width - 10) label2X = x2 - tp2.width - 10;

      _drawLabel(canvas, label2X, label2Y, tp2, line.color);
    }
  }

  void _drawLabel(
    Canvas canvas,
    double x,
    double y,
    TextPainter tp,
    Color lineColor,
  ) {
    final rect = RRect.fromLTRBR(
      x - kLabelPaddingH,
      y - kLabelPaddingV,
      x + tp.width + kLabelPaddingH * 2,
      y + tp.height + kLabelPaddingV * 2,
      const Radius.circular(kLabelCornerRadius),
    );

    // Background - same neutral style
    canvas.drawRRect(
      rect,
      Paint()..color = chartColors.defaultTextColor.withAlpha(kLabelBgOpacity),
    );

    // Border - line color
    canvas.drawRRect(
      rect,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = kLabelBorderWidth,
    );

    tp.paint(canvas, Offset(x, y));
  }

  void drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    double dashLength = 6,
    double gapLength = 4,
  }) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    double distance = math.sqrt(dx * dx + dy * dy);
    if (distance == 0) return;

    final dashX = dx / distance * dashLength;
    final dashY = dy / distance * dashLength;
    final gapX = dx / distance * gapLength;
    final gapY = dy / distance * gapLength;

    double x = start.dx;
    double y = start.dy;
    bool draw = true;

    while (distance > 0) {
      if (draw) {
        canvas.drawLine(Offset(x, y), Offset(x + dashX, y + dashY), paint);
      }
      x += draw ? dashX + gapX : gapX;
      y += draw ? dashY + gapY : gapY;
      distance -= draw ? dashLength + gapLength : gapLength;
      draw = !draw;
    }
  }

  @override
  void drawVerticalText(Canvas canvas) {
    final textStyle = getTextStyle(chartColors.defaultTextColor);
    if (!hideGrid) {
      mMainRenderer.drawVerticalText(canvas, textStyle, mGridRows);
    }
    mVolRenderer?.drawVerticalText(canvas, textStyle, mGridRows);
    for (final element in mSecondaryRendererList) {
      element.drawVerticalText(canvas, textStyle, mGridRows);
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

  BaseChartRenderer<dynamic>? _getSecondaryRendererByY(double y) {
    for (int i = 0; i < mSecondaryRectList.length; i++) {
      if (mSecondaryRectList[i].mRect.contains(Offset(0, y))) {
        return mSecondaryRendererList.elementAt(i);
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
        valueText = '${renderer.name}: ${value.toStringAsFixed(2)}';
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
    KLineEntity data = dataO;
    if (isLongPress || (isTapShowInfoDialog && isOnTap)) {
      final index = calculateSelectedX(selectX);
      data = getItem(index);
    }
    mMainRenderer.drawText(canvas, data, x);
    mVolRenderer?.drawText(canvas, data, x);
    for (final element in mSecondaryRendererList) {
      element.drawText(canvas, data, x);
    }
  }

  @override
  void drawMaxAndMin(Canvas canvas) {
    if (isLine) return;

    double x = translateXtoX(getX(mMainMinIndex));
    double y = getMainY(mMainLowMinValue);
    if (x < mWidth / 2) {
      final tp = getTextPainter(
        '── ${mMainLowMinValue.toStringAsFixed(fixedLength)}',
        chartColors.minColor,
      );
      tp.paint(canvas, Offset(x, y - tp.height / 2));
    } else {
      final tp = getTextPainter(
        '${mMainLowMinValue.toStringAsFixed(fixedLength)} ──',
        chartColors.minColor,
      );
      tp.paint(canvas, Offset(x - tp.width, y - tp.height / 2));
    }

    x = translateXtoX(getX(mMainMaxIndex));
    y = getMainY(mMainHighMaxValue);
    if (x < mWidth / 2) {
      final tp = getTextPainter(
        '── ${mMainHighMaxValue.toStringAsFixed(fixedLength)}',
        chartColors.maxColor,
      );
      tp.paint(canvas, Offset(x, y - tp.height / 2));
    } else {
      final tp = getTextPainter(
        '${mMainHighMaxValue.toStringAsFixed(fixedLength)} ──',
        chartColors.maxColor,
      );
      tp.paint(canvas, Offset(x - tp.width, y - tp.height / 2));
    }
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
        ? chartColors.maxColor
        : chartColors.minColor;

    final lastIndex = candles!.length - 1;
    final lastX = translateXtoX(getX(lastIndex));
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
    final offsetX = mWidth - tp.width - 4;
    final top = y - tp.height / 2;

    canvas.drawRRect(
      RRect.fromLTRBR(
        offsetX,
        top,
        offsetX + tp.width + 4,
        top + tp.height,
        const Radius.circular(2),
      ),
      nowPricePaint,
    );
    tp.paint(canvas, Offset(offsetX + 2, top));
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

      double startX = 0;
      final max = math.max(mWidth, -mTranslateX + mWidth / scaleX);
      double space = chartStyle.nowPriceLineLength;
      if (signal.useDash) space += chartStyle.nowPriceLineSpan;

      while (startX < max) {
        canvas.drawLine(
          Offset(startX, y),
          Offset(startX + chartStyle.nowPriceLineLength, y),
          linePaint,
        );
        startX += space;
      }

      final tp = getTextPainter(
        '${signal.title}: ${value.toStringAsFixed(fixedLength)}',
        chartColors.nowPriceTextColor,
      );

      final offsetX = verticalTextAlignment == VerticalTextAlignment.left
          ? mWidth - tp.width - 4
          : 0.0;
      final top = y - tp.height / 2;

      final bgPaint = Paint()..color = signal.color;
      canvas.drawRRect(
        RRect.fromLTRBR(
          offsetX,
          top,
          offsetX + tp.width + 4,
          top + tp.height,
          const Radius.circular(2),
        ),
        bgPaint,
      );
      tp.paint(canvas, Offset(offsetX + 2, top));
    }
  }

  @override
  void drawCrossLine(Canvas canvas, Size size) {
    final index = calculateSelectedX(selectX);
    final point = getItem(index);
    const double dashWidth = 6.0;
    const double dashSpace = 4.0;

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

  TextPainter getTextPainter(String text, Color? color) {
    final c = color ?? chartColors.defaultTextColor;
    final span = TextSpan(text: text, style: getTextStyle(c));
    final tp = TextPainter(text: span, textDirection: TextDirection.ltr);
    tp.layout();
    return tp;
  }

  String getDate(DateTime? date) =>
      dateFormat(date ?? DateTime.now(), mFormats);

  double getMainY(double y) => mMainRenderer.getY(y);

  @override
  void drawWatermarkLogo(Canvas canvas, Size size) {
    if (watermarkPicture == null) return;

    final logoSize = math.min(size.width, size.height) * 0.4;
    final imgSize = watermarkPicture!.size;
    final scale = logoSize / imgSize.width;

    final logoWidth = imgSize.width * scale;
    final logoHeight = imgSize.height * scale;

    const topLeft = Offset(40, 270);
    final paint = Paint()..color = const Color.fromRGBO(255, 255, 255, 0.08);

    canvas.save();
    canvas.saveLayer(
      Rect.fromLTWH(topLeft.dx, topLeft.dy, logoWidth, logoHeight),
      paint,
    );
    canvas.translate(topLeft.dx, topLeft.dy);
    canvas.scale(scale, scale);
    canvas.drawPicture(watermarkPicture!.picture);
    canvas.restore();
    canvas.restore();
  }

  @override
  void drawVerticalTimeLines(Canvas canvas, Size size) {
    for (final line in verticalLines) {
      final index = candles!.indexWhere((e) => e.dateTime == line.time);
      if (index == -1) continue;

      final x = getX(index);
      if (x < -mTranslateX || x > -mTranslateX + mWidth / scaleX) continue;

      final paint = Paint()
        ..color = line.color.withAlpha(200)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;

      final start = Offset(x, mTopPadding);
      final end = Offset(x, size.height - mBottomPadding);

      canvas.drawLine(start, end, paint);
    }
  }

  void drawVerticalLineTitles(Canvas canvas, Size size) {
    for (final line in verticalLines) {
      if (!line.showLabel) continue;

      final index = candles!.indexWhere((e) => e.dateTime == line.time);
      if (index == -1) continue;

      final x = getX(index);
      if (x < -mTranslateX || x > -mTranslateX + mWidth / scaleX) continue;

      final dateTp = getTextPainter(
        line.title ?? getDate(line.time),
        line.color, // text color = line color
      );

      final dateX = translateXtoX(getX(index));

      // ── Modern unified label style ────────────────────────────────────────
      const double bottomY = 8.0; // slightly above bottom edge
      const double paddingH = 8.0;
      const double paddingV = 4.0;
      const double cornerRadius = 5.0;
      const double borderWidth = 1.4;

      final rect = RRect.fromLTRBR(
        dateX - dateTp.width / 2 - paddingH,
        bottomY,
        dateX + dateTp.width / 2 + paddingH * 2,
        bottomY + dateTp.height + paddingV * 2,
        const Radius.circular(cornerRadius),
      );

      // 1. Background - neutral semi-transparent (same as others)
      canvas.drawRRect(
        rect,
        Paint()..color = chartColors.defaultTextColor.withAlpha(200),
      );

      // 2. Border - line color (same thickness as other labels)
      canvas.drawRRect(
        rect,
        Paint()
          ..color = line.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth,
      );

      // 3. Text centered
      dateTp.paint(
        canvas,
        Offset(dateX - dateTp.width / 2, bottomY + paddingV),
      );
    }
  }
}
