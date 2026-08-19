import 'dart:math';

import 'package:flutter/material.dart';

import '../depth_mode.dart';
import '../depth_style.dart';
import '../depth_translations.dart';
import '../entity/depth_book.dart';
import '../entity/depth_entity.dart';
import '../extension/canvas_extension.dart';
import '../utils/number_util.dart';

class DepthChartPainter extends CustomPainter {
  DepthChartPainter(
    this.mBuyData,
    this.mSellData,
    this.pressOffset,
    this.isLongPress,
    this.baseUnit,
    this.quoteUnit,
    this.chartColors,
    this.chartStyle,
    this.offset,
    this.chartTranslations, {
    this.mode = DepthChartMode.cumulative,
    this.scale = DepthScale.linear,
    double? zoom,
  }) {
    mBuyLinePaint ??= Paint()
      ..isAntiAlias = true
      ..color = chartColors.upColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = chartStyle.lineWidth;
    mSellLinePaint ??= Paint()
      ..isAntiAlias = true
      ..color = chartColors.dnColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = chartStyle.lineWidth;

    mBuyPathPaint ??= Paint()
      ..isAntiAlias = true
      ..color = chartColors.upFillPathColor;
    mSellPathPaint ??= Paint()
      ..isAntiAlias = true
      ..color = chartColors.dnFillPathColor;
    mBarrierPathPaint ??= Paint()
      ..isAntiAlias = true
      ..color = chartColors.barrierColor;
    crossPaint = Paint()
      ..isAntiAlias = true
      ..strokeWidth = chartStyle.crossWidth
      ..color = chartColors.crossColor;

    mBuyPath ??= Path();
    mSellPath ??= Path();
    book = DepthBook.fromCurves(
      mBuyData ?? const <DepthEntity>[],
      mSellData ?? const <DepthEntity>[],
      zoom: zoom,
    );
    if (zoom != null && zoom > 0 && !book.isEmpty) {
      // Zooming keeps only the levels near the mid, so the curves are redrawn
      // from what survived rather than from the whole book.
      mBuyData = [
        for (final level in book.bids)
          DepthEntity(level.price, level.cumulative),
      ];
      mSellData = [
        for (final level in book.asks)
          DepthEntity(level.price, level.cumulative),
      ];
    }
    mBarPaint = Paint()..isAntiAlias = true;
    init();
  }

  /// Paints the per-rung bars, recoloured per side as they are drawn.
  late final Paint mBarPaint;

  //Buy//Sell
  List<DepthEntity>? mBuyData;
  List<DepthEntity>? mSellData;
  Offset? pressOffset;
  bool isLongPress;
  int baseUnit;
  int quoteUnit;
  DepthChartColors chartColors;
  DepthChartStyle chartStyle;

  double mPaddingBottom = 10;
  double mWidth = 0.0;
  double mDrawHeight = 0.0;
  double mDrawWidth = 0.0;
  double? mBuyPointWidth;
  double? mSellPointWidth;

  Offset offset;
  DepthChartTranslations chartTranslations;

  /// Which picture of the book is drawn; see [DepthChartMode].
  final DepthChartMode mode;

  /// How volume is spaced up the vertical axis.
  final DepthScale scale;

  /// The book behind the curves: each rung's own size and the total out to it.
  late final DepthBook book;

  /// Whether the running-total curves are drawn.
  bool get _drawsCurve =>
      mode == DepthChartMode.cumulative || mode == DepthChartMode.combined;

  /// Whether the per-rung bars are drawn.
  bool get _drawsBars =>
      mode == DepthChartMode.histogram || mode == DepthChartMode.combined;

  //Maximum commission amount
  double? mMaxVolume;

  int mLineCount = 6;

  Path? mBuyPath;
  Path? mSellPath;

  Paint? mBuyLinePaint;
  Paint? mSellLinePaint;
  Paint? mBuyPathPaint;
  Paint? mSellPathPaint;
  Paint? mBarrierPathPaint;
  Paint? selectPaint;
  Paint? selectBorderPaint;
  Paint? crossPaint;

  void init() {
    if (mBuyData == null ||
        mSellData == null ||
        mBuyData!.isEmpty ||
        mSellData!.isEmpty) {
      return;
    }
    // A histogram is scaled to the biggest single rung; anything showing the
    // running total is scaled to the deepest total.
    mMaxVolume = _drawsCurve ? book.maxCumulative : book.maxSize;
    if (mMaxVolume == null || mMaxVolume! <= 0) {
      final maxBuyVol = mBuyData!.reduce((a, b) => a.vol > b.vol ? a : b).vol;
      final maxSellVol = mSellData!.reduce((a, b) => a.vol > b.vol ? a : b).vol;
      mMaxVolume = max(maxBuyVol, maxSellVol);
    }

    selectPaint = Paint()
      ..isAntiAlias = true
      ..color = chartColors.selectFillColor;
    selectBorderPaint = Paint()
      ..isAntiAlias = true
      ..color = chartColors.selectBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = chartStyle.strokeWidth;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (mBuyData == null ||
        mSellData == null ||
        mBuyData!.isEmpty ||
        mSellData!.isEmpty) {
      return;
    }
    mWidth = size.width;
    mDrawWidth = mWidth / 2;
    mDrawHeight = size.height - mPaddingBottom;
    canvas.save();
    if (_drawsBars) drawBars(canvas);
    if (_drawsCurve) {
      drawBuy(canvas);
      drawSell(canvas);
    }
    drawText(canvas);
    canvas.restore();
  }

  /// Draws one bar per price level, each the size resting on that rung.
  ///
  /// The bars sit on the same halves as the curves — bids left, asks right —
  /// and are drawn under them, so a combined chart reads as walls beneath the
  /// running total.
  void drawBars(Canvas canvas) {
    void side(List<DepthLevel> levels, double left, Color color) {
      if (levels.isEmpty) return;
      final slot = mDrawWidth / levels.length;
      // Leave a hairline between bars, but never draw one thinner than a pixel.
      final width = max(1.0, slot * chartStyle.barWidthFactor);

      mBarPaint.color = color;
      for (var i = 0; i < levels.length; i++) {
        final centre = left + slot * (i + 0.5);
        final top = getY(levels[i].size);
        if (top >= mDrawHeight) continue;
        canvas.drawRect(
          Rect.fromLTRB(
            centre - width / 2,
            top,
            centre + width / 2,
            mDrawHeight,
          ),
          mBarPaint,
        );
      }
    }

    // Under a curve the bars step back to the fill colours, so the stroke of
    // the running total stays the thing the eye follows.
    final isCombined = mode == DepthChartMode.combined;
    side(
      book.bids,
      0,
      isCombined ? chartColors.upFillPathColor : chartColors.upColor,
    );
    side(
      book.asks,
      mDrawWidth,
      isCombined ? chartColors.dnFillPathColor : chartColors.dnColor,
    );
  }

  void drawBuy(Canvas canvas) {
    mBuyPointWidth =
        mDrawWidth / (mBuyData!.length - 1 == 0 ? 1 : mBuyData!.length - 1);
    mBuyPath!.reset();
    mBuyPath!.reset();
    double x;
    double y;
    for (int i = 0; i < mBuyData!.length; i++) {
      if (i == 0) {
        mBuyPath!.moveTo(0, getY(mBuyData![0].vol));
      }
      x = mBuyPointWidth! * i;
      y = getY(mBuyData![i].vol);
      if (i >= 1) {
        canvas.drawLine(
          Offset(mBuyPointWidth! * (i - 1), getY(mBuyData![i - 1].vol)),
          Offset(x, y),
          mBuyLinePaint!,
        );
      }
      if (i != mBuyData!.length - 1) {
        mBuyPath!.quadraticBezierTo(
          x,
          y,
          mBuyPointWidth! * (i + 1),
          getY(mBuyData![i + 1].vol),
        );
      } else {
        if (i == 0) {
          mBuyPath!.lineTo(mDrawWidth, y);
          mBuyPath!.lineTo(mDrawWidth, mDrawHeight);
          mBuyPath!.lineTo(0, mDrawHeight);
        } else {
          mBuyPath!.quadraticBezierTo(x, y, x, mDrawHeight);
          mBuyPath!.quadraticBezierTo(x, mDrawHeight, 0, mDrawHeight);
        }
        mBuyPath!.close();
      }
    }
    canvas.drawPath(mBuyPath!, mBuyPathPaint!);
  }

  void drawSell(Canvas canvas) {
    mSellPointWidth =
        mDrawWidth / (mSellData!.length - 1 == 0 ? 1 : mSellData!.length - 1);
    mSellPath!.reset();
    double x;
    double y;
    for (int i = 0; i < mSellData!.length; i++) {
      if (i == 0) {
        mSellPath!.moveTo(mDrawWidth, getY(mSellData![0].vol));
      }
      x = (mSellPointWidth! * i) + mDrawWidth;
      y = getY(mSellData![i].vol);
      if (i >= 1) {
        canvas.drawLine(
          Offset(
            (mSellPointWidth! * (i - 1)) + mDrawWidth,
            getY(mSellData![i - 1].vol),
          ),
          Offset(x, y),
          mSellLinePaint!,
        );
      }
      if (i != mSellData!.length - 1) {
        mSellPath!.quadraticBezierTo(
          x,
          y,
          (mSellPointWidth! * (i + 1)) + mDrawWidth,
          getY(mSellData![i + 1].vol),
        );
      } else {
        if (i == 0) {
          mSellPath!.lineTo(mWidth, y);
          mSellPath!.lineTo(mWidth, mDrawHeight);
          mSellPath!.lineTo(mDrawWidth, mDrawHeight);
        } else {
          mSellPath!.quadraticBezierTo(mWidth, y, x, mDrawHeight);
          mSellPath!.quadraticBezierTo(x, mDrawHeight, mDrawWidth, mDrawHeight);
        }
        mSellPath!.close();
      }
    }
    canvas.drawPath(mSellPath!, mSellPathPaint!);
  }

  // int? mLastPosition;

  void drawText(Canvas canvas) {
    for (int j = 0; j < mLineCount; j++) {
      final tp = getTextPainter(_axisLabel(j));
      tp.layout();
      tp.paint(
        canvas,
        Offset(mWidth - tp.width, mDrawHeight / mLineCount * j + tp.height / 2),
      );
    }

    final startText =
        NumberUtil.formatFixed(mBuyData!.first.price, quoteUnit) ?? '';
    final startTP = getTextPainter(startText);
    startTP.layout();
    startTP.paint(canvas, Offset(0, getBottomTextY(startTP.height)));

    final centerPrice = (mBuyData!.last.price + mSellData!.first.price) / 2;

    final center = NumberUtil.formatFixed(centerPrice, quoteUnit) ?? '';
    final centerTP = getTextPainter(center);
    centerTP.layout();
    centerTP.paint(
      canvas,
      Offset(mDrawWidth - centerTP.width / 2, getBottomTextY(centerTP.height)),
    );

    final endText =
        NumberUtil.formatFixed(mSellData!.last.price, quoteUnit) ?? '';
    final endTP = getTextPainter(endText);
    endTP.layout();
    endTP.paint(
      canvas,
      Offset(mWidth - endTP.width, getBottomTextY(endTP.height)),
    );

    final leftHalfText =
        NumberUtil.formatFixed(
          (mBuyData!.first.price + centerPrice) / 2,
          quoteUnit,
        ) ??
        '';
    final leftHalfTP = getTextPainter(leftHalfText);
    leftHalfTP.layout();
    leftHalfTP.paint(
      canvas,
      Offset(
        (mDrawWidth - leftHalfTP.width) / 2,
        getBottomTextY(leftHalfTP.height),
      ),
    );

    final rightHalfText =
        NumberUtil.formatFixed(
          (mSellData!.last.price + centerPrice) / 2,
          quoteUnit,
        ) ??
        '';
    final rightHalfTP = getTextPainter(rightHalfText);
    rightHalfTP.layout();
    rightHalfTP.paint(
      canvas,
      Offset(
        (mDrawWidth + mWidth - rightHalfTP.width) / 2,
        getBottomTextY(rightHalfTP.height),
      ),
    );

    if (isLongPress == true) {
      if (pressOffset!.dx <= mDrawWidth) {
        final index = _indexOfTranslateX(
          pressOffset!.dx,
          0,
          mBuyData!.length - 1,
          getBuyX,
        );
        drawLeftSelectView(canvas, index); // buy

        final indexRight = mBuyData!.length - index - 1;
        if (indexRight < mSellData!.length) {
          drawRightSelectView(canvas, indexRight);
        }
      } else {
        final index = _indexOfTranslateX(
          pressOffset!.dx,
          0,
          mSellData!.length - 1,
          getSellX,
        );
        drawRightSelectView(canvas, index); // sell
        final indexLeft = mBuyData!.length - index - 1;
        if (indexLeft >= 0 && indexLeft < mBuyData!.length) {
          drawLeftSelectView(canvas, indexLeft);
        }
      }
    }
  }

  void drawLeftSelectView(Canvas canvas, int index) {
    final entity = mBuyData![index];
    final level = index < book.bids.length ? book.bids[index] : null;
    double dx = getBuyX(index);
    double dy = getY(_plotted(level, entity));

    canvas.drawRect(Rect.fromLTRB(0, 0, dx, mDrawHeight), mBarrierPathPaint!);

    /// draw cross line
    canvas.drawDashLine(
      Offset(dx, 0),
      Offset(dx, mDrawHeight),
      crossPaint ?? Paint(),
    );

    /// draw dot
    canvas.drawCircle(
      Offset(dx, dy),
      chartStyle.dotRadius * .6,
      mBuyLinePaint!..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(dx, dy),
      chartStyle.dotRadius,
      mBuyLinePaint!..style = PaintingStyle.stroke,
    );

    ///draw popup info
    ///
    final popupPainter = PopupPainter(
      translations: chartTranslations,
      chartColors: chartColors,
      chartStyle: chartStyle,
      price: NumberUtil.format(entity.price, quoteUnit) ?? '',
      amount: NumberUtil.formatCompact(entity.vol, baseUnit),
      size: level == null
          ? null
          : NumberUtil.formatCompact(level.size, baseUnit),
    );

    dx = dx < mWidth * 0.25
        ? dx + offset.dx
        : dx - offset.dx - popupPainter.width;
    dy = (dy - popupPainter.height / 2).clamp(
      offset.dy,
      mDrawHeight - popupPainter.height - offset.dy,
    );

    final rect = Rect.fromLTWH(dx, dy, popupPainter.width, popupPainter.height);
    final boxRect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(chartStyle.radius),
    );

    canvas.drawRRect(boxRect, selectPaint!);
    canvas.drawRRect(boxRect, selectBorderPaint!);
    popupPainter.paint(canvas, rect.topLeft);
  }

  void drawRightSelectView(Canvas canvas, int index) {
    final entity = mSellData![index];
    final level = index < book.asks.length ? book.asks[index] : null;
    double dx = getSellX(index);
    double dy = getY(_plotted(level, entity));

    /// draw overlay barrier model
    canvas.drawRect(
      Rect.fromLTRB(dx, 0, mWidth, mDrawHeight),
      mBarrierPathPaint!,
    );

    /// draw cross line
    canvas.drawDashLine(
      Offset(dx, 0),
      Offset(dx, mDrawHeight),
      crossPaint ?? Paint(),
    );

    /// draw dot
    canvas.drawCircle(
      Offset(dx, dy),
      chartStyle.dotRadius * .6,
      mSellLinePaint!..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(dx, dy),
      chartStyle.dotRadius,
      mSellLinePaint!..style = PaintingStyle.stroke,
    );

    ///draw popup info
    ///
    final popupPainter = PopupPainter(
      translations: chartTranslations,
      chartColors: chartColors,
      chartStyle: chartStyle,
      price: NumberUtil.format(entity.price, quoteUnit) ?? '',
      amount: NumberUtil.formatCompact(entity.vol, baseUnit),
      size: level == null
          ? null
          : NumberUtil.formatCompact(level.size, baseUnit),
    );

    dx = dx < mWidth * 0.75
        ? dx + offset.dx
        : dx - offset.dx - popupPainter.width;
    // dx = dx + offset.dx;
    // dy = dy < mDrawHeight / 2
    //   ? dy + offset.dy
    //   : dy - offset.dy - popupPainter.height;
    dy = (dy - popupPainter.height / 2).clamp(
      offset.dy,
      mDrawHeight - popupPainter.height - offset.dy,
    );

    final rect = Rect.fromLTWH(dx, dy, popupPainter.width, popupPainter.height);
    final boxRect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(chartStyle.radius),
    );

    canvas.drawRRect(boxRect, selectPaint!);
    canvas.drawRRect(boxRect, selectBorderPaint!);
    popupPainter.paint(canvas, rect.topLeft);
  }

  ///Binary search for current value: index
  int _indexOfTranslateX(
    double translateX,
    int start,
    int end,
    double Function(int value) getX,
  ) {
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
      return _indexOfTranslateX(translateX, start, mid, getX);
    } else if (translateX > midValue) {
      return _indexOfTranslateX(translateX, mid, end, getX);
    } else {
      return mid;
    }
  }

  /// The value the readout's dot sits on: whatever this mode draws.
  double _plotted(DepthLevel? level, DepthEntity entity) =>
      _drawsCurve || level == null ? entity.vol : level.size;

  double getBuyX(int position) => position * mBuyPointWidth!;

  double getSellX(int position) => position * mSellPointWidth! + mDrawWidth;

  TextPainter getTextPainter(String text) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(color: chartColors.defaultTextColor, fontSize: 10),
    ),
    textDirection: TextDirection.ltr,
  );

  double getBottomTextY(double textHeight) =>
      (mPaddingBottom - textHeight) / 2 + mDrawHeight;

  /// Where [volume] sits on the vertical axis, through the chosen [scale].
  double getY(double volume) {
    final ceiling = _spaced(mMaxVolume ?? 0);
    if (ceiling <= 0) return mDrawHeight;
    return mDrawHeight - mDrawHeight * (_spaced(volume) / ceiling);
  }

  /// Spaces a volume up the axis: as it is, or logarithmically.
  ///
  /// Percentages are laid out exactly like plain volumes — only their labels
  /// differ — so they share the linear spacing.
  double _spaced(double volume) => switch (scale) {
    DepthScale.log => log(1 + max(0, volume)),
    _ => volume,
  };

  /// The volume that sits [fraction] of the way up the axis.
  double _volumeAt(double fraction) => switch (scale) {
    DepthScale.log => exp(_spaced(mMaxVolume ?? 0) * fraction) - 1,
    _ => (mMaxVolume ?? 0) * fraction,
  };

  /// The axis label for the gridline [line] rows down from the top.
  String _axisLabel(int line) {
    final fraction = 1 - line / mLineCount;
    if (scale == DepthScale.percent) {
      return '${(fraction * 100).round()}%';
    }
    return NumberUtil.formatCompact(_volumeAt(fraction), baseUnit);
  }

  @override
  bool shouldRepaint(DepthChartPainter oldDelegate) {
    //    return oldDelegate.mBuyData != mBuyData ||
    //        oldDelegate.mSellData != mSellData ||
    //        oldDelegate.isLongPress != isLongPress ||
    //        oldDelegate.pressOffset != pressOffset;
    return true;
  }
}

class PopupPainter {
  PopupPainter({
    required DepthChartTranslations translations,
    required this.chartColors,
    required this.chartStyle,
    required String price,
    required String amount,
    String? size,
  }) {
    pricePaint = _getTextPainter(translations.price, price);
    amountPaint = _getTextPainter(translations.amount, amount);
    sizePaint = size == null ? null : _getTextPainter(translations.size, size);
    pricePaint.layout();
    amountPaint.layout();
    sizePaint?.layout();
  }

  final DepthChartColors chartColors;
  final DepthChartStyle chartStyle;

  late final TextPainter annotationsPaint;
  late final TextPainter pricePaint;
  late final TextPainter amountPaint;

  /// The size resting on the rung under the finger, where there is one.
  late final TextPainter? sizePaint;

  ///getter
  double get width =>
      max(max(pricePaint.width, amountPaint.width), sizePaint?.width ?? 0) +
      2 * chartStyle.padding;

  double get height =>
      pricePaint.height +
      amountPaint.height +
      (sizePaint == null ? 0 : sizePaint!.height + chartStyle.space) +
      chartStyle.space +
      2 * chartStyle.padding;

  void paint(Canvas canvas, Offset offset) {
    pricePaint.paint(
      canvas,
      offset + Offset(chartStyle.padding, chartStyle.padding),
    );
    amountPaint.paint(
      canvas,
      offset +
          Offset(
            chartStyle.padding,
            pricePaint.height + chartStyle.space + chartStyle.padding,
          ),
    );
    sizePaint?.paint(
      canvas,
      offset +
          Offset(
            chartStyle.padding,
            pricePaint.height +
                amountPaint.height +
                chartStyle.space * 2 +
                chartStyle.padding,
          ),
    );
  }

  TextPainter _getTextPainter(String label, String content) {
    return TextPainter(
      text: TextSpan(
        text: '$label $content',
        style: TextStyle(color: chartColors.annotationColor, fontSize: 9),
      ),
      textAlign: TextAlign.start,
      textDirection: TextDirection.ltr,
    );
  }
}
