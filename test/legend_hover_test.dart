import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart/src/renderer/chart_painter.dart';

import 'test_utils.dart';

Widget _chart({
  bool crosshairOnHover = true,
  bool showOhlcLegend = false,
  bool isTapShowInfoDialog = false,
  ChartTranslations translations = const ChartTranslations(),
  List<Indicator> indicators = const [],
}) {
  final data = candles(rampThenFall(60));
  DataUtil.calculate(data);

  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 500,
        height: 600,
        child: KChartWidget(
          data,
          ChartColors(),
          isTrendLine: false,
          timeFrame: const Duration(minutes: 15),
          showNowPrice: false,
          crosshairOnHover: crosshairOnHover,
          showOhlcLegend: showOhlcLegend,
          isTapShowInfoDialog: isTapShowInfoDialog,
          chartTranslations: translations,
          indicators: indicators,
        ),
      ),
    ),
  );
}

/// Moves a mouse to [position] over the chart and leaves it there.
Future<TestGesture> _hover(WidgetTester tester, Offset position) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await mouse.moveTo(position);
  await tester.pumpAndSettle();
  return mouse;
}

/// The painter the chart last built, for asserting on what it would draw.
ChartPainter _painterOf(WidgetTester tester) {
  final dynamic state = tester.state(find.byType(KChartWidget));
  // ignore: avoid_dynamic_calls
  return state.painter as ChartPainter;
}

void main() {
  group('hover crosshair', () {
    testWidgets('a resting mouse shows the crosshair', (tester) async {
      await tester.pumpWidget(_chart());
      await _hover(tester, const Offset(250, 200));

      expect(_painterOf(tester).showCrosshair, isTrue);
    });

    testWidgets('leaving the chart puts the crosshair away', (tester) async {
      await tester.pumpWidget(_chart());
      final mouse = await _hover(tester, const Offset(250, 200));

      await mouse.moveTo(const Offset(250, 595));
      await tester.pumpAndSettle();

      expect(_painterOf(tester).showCrosshair, isFalse);
    });

    testWidgets('hovering can be turned off', (tester) async {
      await tester.pumpWidget(_chart(crosshairOnHover: false));
      await _hover(tester, const Offset(250, 200));

      expect(_painterOf(tester).showCrosshair, isFalse);
    });

    testWidgets('hovering never opens the info dialog', (tester) async {
      await tester.pumpWidget(_chart());
      await _hover(tester, const Offset(250, 200));

      expect(find.textContaining('Open'), findsNothing);
    });

    testWidgets('hovering the oldest candle does not throw', (tester) async {
      await tester.pumpWidget(_chart());
      await _hover(tester, const Offset(1, 200));

      expect(tester.takeException(), isNull);
    });
  });

  group('OHLC legend', () {
    testWidgets('renders without blowing up, on its own row', (tester) async {
      await tester.pumpWidget(
        _chart(showOhlcLegend: true, indicators: [MaIndicator(period: 5)]),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('follows the crosshair', (tester) async {
      await tester.pumpWidget(_chart(showOhlcLegend: true));
      await _hover(tester, const Offset(120, 200));

      expect(tester.takeException(), isNull);
    });

    testWidgets('is off by default', (tester) async {
      await tester.pumpWidget(_chart());
      expect(tester.takeException(), isNull);
    });
  });
}
