import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart/src/renderer/chart_painter.dart';

import 'test_utils.dart';

ChartPainter _painterOf(WidgetTester tester) {
  final dynamic state = tester.state(find.byType(KChartWidget));
  // ignore: avoid_dynamic_calls
  return state.painter as ChartPainter;
}

/// A chart too short to fill its box at the default spacing.
Widget _chart({required bool fitContent, int count = 10}) {
  final data = candles(rampThenFall(count));
  DataUtil.calculate(data);

  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 220,
        child: KChartWidget(
          data,
          ChartColors(),
          isTrendLine: false,
          timeFrame: const Duration(minutes: 5),
          xFrontPadding: 0,
          volHidden: true,
          showNowPrice: false,
          chartStyle: ChartStyle(fitContent: fitContent),
        ),
      ),
    ),
  );
}

void main() {
  group('ChartStyle.fitContent', () {
    testWidgets('off, a short series keeps the fixed spacing', (tester) async {
      await tester.pumpWidget(_chart(fitContent: false));

      expect(_painterOf(tester).mPointWidth, const ChartStyle().pointWidth);
    });

    testWidgets('on, a short series spreads across the plot', (tester) async {
      await tester.pumpWidget(_chart(fitContent: true));
      final painter = _painterOf(tester);

      expect(painter.mPointWidth, closeTo(40, 0.001));
      // The last candle's body ends at the right edge rather than a tenth of
      // the way in, which is what the bunching complaint was about.
      final lastX = painter.translateXtoX(painter.getX(9));
      expect(lastX, closeTo(400 - painter.mPointWidth / 2, 0.001));
    });

    testWidgets('on, the candles widen with the spacing', (tester) async {
      await tester.pumpWidget(_chart(fitContent: true));
      final painter = _painterOf(tester);

      const style = ChartStyle();
      final spread = painter.mPointWidth / style.pointWidth;
      expect(
        painter.fittedStyle.candleWidth,
        closeTo(style.candleWidth * spread, 0.001),
      );
    });

    testWidgets('on, a series that already fills the plot is left alone', (
      tester,
    ) async {
      await tester.pumpWidget(_chart(fitContent: true, count: 200));

      expect(_painterOf(tester).mPointWidth, const ChartStyle().pointWidth);
    });
  });
}
