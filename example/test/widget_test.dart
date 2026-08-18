import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart_example/main.dart';
import 'package:ohlcv_chart_example/market_data.dart';

void main() {
  testWidgets('the chart page builds with its default indicators', (
    tester,
  ) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pump();

    expect(find.byType(KChartWidget), findsOneWidget);
    // MA on the main chart and MACD below it are selected out of the box.
    expect(find.widgetWithText(FilterChip, 'MA'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'MACD'), findsOneWidget);
  });

  testWidgets('the app bar action swaps in the depth chart', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pump();

    await tester.tap(find.byTooltip('Show depth'));
    await tester.pump();

    expect(find.byType(DepthChart), findsOneWidget);
    expect(find.byType(KChartWidget), findsNothing);
  });

  test('generated candles carry their calculated indicators', () {
    final candles = MarketData.candles(count: 120);

    expect(candles, hasLength(120));
    // DataUtil.calculate fills these in; without it the chart draws nothing.
    expect(candles.last.maValueList, isNotNull);
    expect(candles.last.macd, isNotNull);
  });
}
