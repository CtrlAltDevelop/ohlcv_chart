import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart_example/main.dart';
import 'package:ohlcv_chart_example/src/market_data.dart';

void main() {
  testWidgets('the chart page builds with its default indicators', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ExampleApp());
    await tester.pump();

    expect(find.byType(KChartWidget), findsOneWidget);
    // Three moving averages over the candles and a MACD pane, out of the box.
    expect(find.widgetWithText(InputChip, 'MA(5)'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'MA(10)'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'MA(20)'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'MACD(12,26,9)'), findsOneWidget);
  });

  testWidgets('adding an indicator twice edits it instead of stacking', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ExampleApp());
    await tester.pump();

    Future<void> addAtr() async {
      await tester.tap(find.text('Add indicator'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'ATR'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
    }

    await addAtr();
    expect(find.widgetWithText(InputChip, 'ATR(14)'), findsOneWidget);

    // The same settings again: one chip, not two.
    await addAtr();
    expect(find.widgetWithText(InputChip, 'ATR(14)'), findsOneWidget);
  });

  testWidgets('the depth tab swaps in the depth chart', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ExampleApp());
    await tester.pump();

    await tester.tap(find.text('Depth'));
    await tester.pumpAndSettle();

    expect(find.byType(DepthChart), findsOneWidget);
  });

  test('generated candles carry their calculated indicators', () {
    final candles = MarketData.candles(count: 120);

    expect(candles, hasLength(120));
    // DataUtil.calculate fills these in; without it the chart draws nothing.
    expect(candles.last.maValueList, isNotNull);
    expect(candles.last.macd, isNotNull);
  });

  test('older pages are prepended in chronological order', () {
    final candles = MarketData.candles(count: 60);
    final extended = MarketData.olderThan(candles, count: 20);

    expect(extended, hasLength(80));
    expect(extended.first.dateTime!.isBefore(candles.first.dateTime!), isTrue);
  });
}
