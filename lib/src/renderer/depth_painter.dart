import 'dart:math';

import 'package:flutter/material.dart';

import '../depth_style.dart';
import '../depth_translations.dart';
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
    this.chartTranslations,
  ) {
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
    init();
  }

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

  //Maximum commission amount
  double? mMaxVolume;
  double? mMultiple;

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
    final maxBuyVol = mBuyData!.reduce((a, b) => a.vol > b.vol ? a : b).vol;
    final maxSellVol = mSellData!.reduce((a, b) => a.vol > b.vol ? a : b).vol;
    mMaxVolume = max(maxBuyVol, maxSellVol);
    mMultiple = mMaxVolume! / mLineCount;

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
    drawBuy(canvas);
    drawSell(canvas);
    drawText(canvas);
    canvas.restore();
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
    double value;
    String str;
    for (int j = 0; j < mLineCount; j++) {
      value = mMaxVolume! - mMultiple! * j;
      str = NumberUtil.formatCompact(value, baseUnit);
      final tp = getTextPainter(str);
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
    double dx = getBuyX(index);
    double dy = getY(entity.vol);

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
    double dx = getSellX(index);
    double dy = getY(entity.vol);

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

  double getY(double volume) =>
      mDrawHeight - mDrawHeight * volume / mMaxVolume!;

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
  }) {
    pricePaint = _getTextPainter(translations.price, price);
    amountPaint = _getTextPainter(translations.amount, amount);
    pricePaint.layout();
    amountPaint.layout();
  }

  final DepthChartColors chartColors;
  final DepthChartStyle chartStyle;

  late final TextPainter annotationsPaint;
  late final TextPainter pricePaint;
  late final TextPainter amountPaint;

  ///getter
  double get width =>
      max(pricePaint.width, amountPaint.width) + 2 * chartStyle.padding;

  double get height =>
      pricePaint.height +
      amountPaint.height +
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
