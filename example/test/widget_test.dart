import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart_example/main.dart';
import 'package:ohlcv_chart_example/src/controls.dart';
import 'package:ohlcv_chart_example/src/demo_state.dart';
import 'package:ohlcv_chart_example/src/market_data.dart';

/// The control panel on its own, in a box tall enough to hold all of it.
///
/// The panel is a `ListView` inside the demo, so anything below the fold does
/// not exist there; laying it out at full height is what lets a test reach every
/// control without scrolling — and without the tab view underneath it flicking
/// to another page.
Widget panel(DemoState state) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: 320,
      height: 3000,
      // The demo's own page listens to the state the same way; the panel itself
      // is stateless.
      child: AnimatedBuilder(
        animation: state,
        builder: (context, _) => Controls(state: state),
      ),
    ),
  ),
);

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
    expect(find.byType(DrawingManager), findsOneWidget);
  });

  testWidgets('the panel lists the indicators the demo starts with', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = DemoState();
    addTearDown(state.dispose);
    await tester.pumpWidget(panel(state));

    // Three moving averages over the candles and a MACD pane, out of the box.
    expect(find.widgetWithText(InputChip, 'MA(5)'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'MA(10)'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'MA(20)'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'MACD(12,26,9)'), findsOneWidget);
  });

  testWidgets('adding an indicator twice edits it instead of stacking', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = DemoState();
    addTearDown(state.dispose);
    await tester.pumpWidget(panel(state));

    // The panel has outgrown the box and the sheet can be taller than the
    // screen, so each control is scrolled into view before it is tapped.
    Future<void> tapInView(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    Future<void> addAtr() async {
      // The panel's button, not the sheet's title, which reads the same.
      await tapInView(find.text('Add indicator').first);
      await tapInView(find.widgetWithText(ChoiceChip, 'ATR'));
      await tapInView(find.widgetWithText(FilledButton, 'Add'));
    }

    await addAtr();
    expect(find.widgetWithText(InputChip, 'ATR(14)'), findsOneWidget);

    // The same settings again: one chip, not two.
    await addAtr();
    expect(find.widgetWithText(InputChip, 'ATR(14)'), findsOneWidget);
    expect(state.indicators.whereType<AtrIndicator>(), hasLength(1));
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
