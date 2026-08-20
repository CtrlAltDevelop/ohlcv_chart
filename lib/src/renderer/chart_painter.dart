import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart' as vg;

import '../drawing/line_painting.dart';
import '../entity/horizontal_line.dart';
import '../entity/info_window_entity.dart';
import '../export.dart';
import '../utils/date_format_util.dart';
import '../utils/number_util.dart';
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
    required this.watermarkPicture,
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
    required this.timeFrame,
    required this.draftLine,
    required this.selectedLine,
    this.drawingStyle = const DrawingStyle(),
    this.chartTranslations = const ChartTranslations(),
    this.showOhlcLegend = false,
    this.priceAxisScale = PriceAxisScale.linear,
    this.chartType = ChartType.candles,
    this.baselinePrice,
    this.timeZoneOffset = Duration.zero,
    this.highlightedPane,
    super.isHovering,
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

  final List<SignalEntity> signals;
  final bool isTrendLine;
  final double selectY;

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

  /// The drawing the editing toolbar is open on, which is the only one that
  /// shows its drag handles.
  final ChartLine? selectedLine;

  /// Geometry and palette used for the user-drawn lines and their labels.
  final DrawingStyle drawingStyle;

  /// Labels used by the OHLC legend.
  final ChartTranslations chartTranslations;

  /// Whether the candle's own values are read out above the chart.
  final bool showOhlcLegend;

  /// How the candle area spaces and reads out its price axis.
  final PriceAxisScale priceAxisScale;

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

  /// The oldest close in view, which is what a baseline chart falls back to.
  double? get _oldestCloseInView {
    final data = candles;
    if (data == null || data.isEmpty) return null;
    return data[mStartIndex.clamp(0, data.length - 1)].close;
  }

  /// The close a percentage axis measures against: the oldest candle in view.
  double? get _percentBase {
    if (priceAxisScale != PriceAxisScale.percentage) return null;
    final data = candles;
    if (data == null || data.isEmpty) return null;
    return data[mStartIndex.clamp(0, data.length - 1)].close;
  }

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
      priceScale: priceAxisScale,
      // A percentage axis measures from the oldest candle in view, so panning
      // moves the zero line along with the window.
      percentBase: _percentBase,
      chartType: chartType,
      baselinePrice: baselinePrice ?? _oldestCloseInView,
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

    drawSessionDividers(canvas, size);
    drawPaneHighlight(canvas);

    // User-drawn lines paint in view space, once the horizontal scale is
    // restored: a stroke then keeps the thickness it was given whatever the
    // zoom level, and a drag handle stays a circle instead of an ellipse.
    drawRectangles(canvas, size);
    drawEllipses(canvas, size);
    drawTriangles(canvas, size);
    drawChannels(canvas, size);
    drawFibRetracements(canvas, size);
    drawPositions(canvas, size);
    drawMeasures(canvas, size);
    drawHorizontalLines(canvas, size);
    drawVerticalLines(canvas, size);
    drawTrendLines(canvas, size);
    drawFreehands(canvas, size);
    drawTextAnnotations(canvas, size);

    drawHorizontalLineTitles(canvas, size);
    drawVerticalLineTitles(canvas, size);
    drawTrendLineLabels(canvas, size);
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
    final index = candles!.indexWhere((e) => e.dateTime == time);
    if (index == -1) return null;
    return Offset(translateXtoX(getX(index)), getMainY(price));
  }

  void drawHorizontalLines(Canvas canvas, Size size) {
    for (final line in _withDraft(horizontalLines)) {
      final y = getMainY(line.price);
      // A ray starts at its own candle; a plain level spans the whole chart.
      final startX = horizontalRayStartX(line) ?? 0.0;
      if (startX > size.width) continue;
      strokeChartLine(canvas, Offset(startX, y), Offset(size.width, y), line);

      if (line == selectedLine) {
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
    final index = candles!.indexWhere((e) => e.dateTime == start);
    if (index == -1) return null;
    return translateXtoX(getX(index));
  }

  void drawHorizontalLineTitles(Canvas canvas, Size size) {
    for (final line in horizontalLines) {
      if (!line.showLabel || line.hidden) continue;

      final y = getMainY(line.price);
      final title = line.title ?? line.price.toStringAsFixed(fixedLength);
      final tp = getLabelPainter(title, line.color);
      final padding = drawingStyle.labelPadding;

      final rayStart = horizontalRayStartX(line);
      final textX = rayStart != null
          ? rayStart + padding.left + 8
          : verticalTextAlignment == VerticalTextAlignment.right
          ? size.width - tp.width - padding.right - 8
          : 8.0 + padding.left;

      drawLineLabel(canvas, tp, Offset(textX, y - tp.height / 2), line.color);
    }
  }

  void drawVerticalLines(Canvas canvas, Size size) {
    for (final line in _withDraft(verticalLines)) {
      final index = candles!.indexWhere((e) => e.dateTime == line.time);
      if (index == -1) continue;

      final x = translateXtoX(getX(index));
      strokeChartLine(
        canvas,
        Offset(x, mTopPadding),
        Offset(x, size.height - mBottomPadding),
        line,
      );

      if (line == selectedLine) {
        drawLineHandle(canvas, Offset(x, mMainRect.center.dy), line);
      }
    }
  }

  void drawVerticalLineTitles(Canvas canvas, Size size) {
    for (final line in verticalLines) {
      if (!line.showLabel || line.hidden) continue;

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

      if (line == selectedLine) {
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

      if (box == selectedLine) {
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

      if (fib == selectedLine) {
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

  /// The index of the candle at [time], or null when it is not in the data.
  int? _indexOf(DateTime? time) {
    if (time == null) return null;
    final index = candles!.indexWhere((e) => e.dateTime == time);
    return index == -1 ? null : index;
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

      if (oval == selectedLine) {
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

      if (triangle == selectedLine) {
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
        if (channel == selectedLine) {
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

      if (channel == selectedLine) {
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

      if (position == selectedLine) {
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

      if (measure == selectedLine) {
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

      if (stroke == selectedLine) {
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

      if (note == selectedLine) drawLineHandle(canvas, at, note);
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

  /// The price at [y] in the candle area, whatever the axis is spaced by.
  double calculatePrice(double y) => mMainRenderer.getValue(y);

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
          text: '$label ${value.toStringAsFixed(fixedLength)}  ',
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
      dateFormat((date ?? DateTime.now()).add(timeZoneOffset), mFormats);

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
