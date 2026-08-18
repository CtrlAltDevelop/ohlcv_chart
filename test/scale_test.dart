import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart/src/renderer/base_chart_painter.dart';
import 'package:ohlcv_chart/src/renderer/base_dimension.dart';

import 'test_utils.dart';

/// A painter that runs the shared range calculation and draws nothing, so the
/// computed sub-chart bounds can be inspected directly.
class _ProbePainter extends BaseChartPainter {
  _ProbePainter(
    super.chartStyle, {
    required super.baseDimension,
    super.candles,
    required super.scaleX,
    required super.scrollX,
    required super.isLongPress,
    required super.selectX,
    required super.xFrontPadding,
    super.secondaryStateLi,
  });

  @override
  void initChartRenderer() {}
  @override
  void drawBg(Canvas canvas, Size size) {}
  @override
  void drawGrid(Canvas canvas) {}
  @override
  void drawChart(Canvas canvas, Size size) {}
  @override
  void drawVerticalText(Canvas canvas) {}
  @override
  void drawDate(Canvas canvas, Size size) {}
  @override
  void drawText(Canvas canvas, KLineEntity data, double x) {}
  @override
  void drawMaxAndMin(Canvas canvas) {}
  @override
  void drawNowPrice(Canvas canvas) {}
  @override
  void drawCrossLine(Canvas canvas, Size size) {}
  @override
  void drawCrossLineText(Canvas canvas, Size size) {}
  @override
  void drawSignals(Canvas canvas) {}
  @override
  void drawWatermarkLogo(Canvas canvas, Size size) {}
  @override
  void drawVerticalTimeLines(Canvas canvas, Size size) {}
}

/// Paints [data] with [secondary] enabled and returns the computed rects.
List<RenderRect> boundsFor(
  List<KLineEntity> data,
  Set<SecondaryState> secondary,
) {
  final painter = _ProbePainter(
    const ChartStyle(),
    candles: data,
    scaleX: 1,
    scrollX: 0,
    isLongPress: false,
    selectX: 0,
    xFrontPadding: 80,
    secondaryStateLi: secondary,
    baseDimension: BaseDimension(
      mBaseHeight: 360,
      volHidden: false,
      secondaryStateLi: secondary,
      mainStateLi: const {},
    ),
  );

  final recorder = PictureRecorder();
  painter.paint(Canvas(recorder), const Size(400, 600));
  recorder.endRecording().dispose();
  return painter.mSecondaryRectList;
}

/// The candles actually inside the painted window. The first candle of any
/// EMA-seeded series is exactly zero, so tests that need an all-negative
/// window must confirm it fell outside the visible range.
List<KLineEntity> visibleSlice(List<KLineEntity> data) {
  final painter = _ProbePainter(
    const ChartStyle(),
    candles: data,
    scaleX: 1,
    scrollX: 0,
    isLongPress: false,
    selectX: 0,
    xFrontPadding: 80,
    secondaryStateLi: const {SecondaryState.MACD},
    baseDimension: BaseDimension(
      mBaseHeight: 360,
      volHidden: false,
      secondaryStateLi: const {SecondaryState.MACD},
      mainStateLi: const {},
    ),
  );
  final recorder = PictureRecorder();
  painter.paint(Canvas(recorder), const Size(400, 600));
  recorder.endRecording().dispose();
  return data.sublist(painter.mStartIndex, painter.mStopIndex + 1);
}

void main() {
  group('sub-chart vertical range', () {
    test('tracks the true maximum when MACD never rises above zero', () {
      // Long enough that the zero-valued first candle scrolls out of view.
      final data = candles([for (var i = 0; i < 400; i++) 900.0 - i * 2]);
      DataUtil.calculate(data);

      final visible = visibleSlice(data);
      expect(visible.first, isNot(same(data.first)));
      final trueMax = visible
          .map((e) => math.max(e.macd!, math.max(e.dif!, e.dea!)))
          .reduce(math.max);
      expect(trueMax, lessThan(0), reason: 'the whole series is negative');

      final rect = boundsFor(data, {SecondaryState.MACD}).single;

      // Before the fix the seed (double.minPositive, ~5e-324) survived as the
      // maximum, so the range topped out at zero instead of the real peak.
      expect(rect.mMaxValue, lessThan(0));
      expect(rect.mMaxValue, closeTo(trueMax, 1e-9));
    });

    test('tracks the true maximum when CCI never rises above zero', () {
      final data = candles([for (var i = 0; i < 400; i++) 900.0 - i * 2]);
      DataUtil.calculate(data);

      final rect = boundsFor(data, {SecondaryState.CCI}).single;
      expect(rect.mMaxValue, lessThan(0));
      expect(rect.mMaxValue.isFinite, isTrue);
    });

    test('still brackets a mixed series correctly', () {
      final data = candles(rampThenFall(60));
      DataUtil.calculate(data);

      final rect = boundsFor(data, {SecondaryState.MACD}).single;
      expect(rect.mMaxValue, greaterThan(rect.mMinValue));
      expect(rect.mMaxValue.isFinite, isTrue);
      expect(rect.mMinValue.isFinite, isTrue);
    });

    test('collapses to a flat range when the indicator has no values', () {
      // Too few candles for MACD-with-values is impossible, but KDJ on a
      // one-candle list leaves later rects untouched; the seeds must not leak.
      final data = candles([100]);
      DataUtil.calculate(data);

      for (final rect in boundsFor(data, {SecondaryState.CCI})) {
        expect(rect.mMaxValue.isFinite, isTrue);
        expect(rect.mMinValue.isFinite, isTrue);
      }
    });
  });
}
