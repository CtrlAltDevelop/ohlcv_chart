import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

import 'test_utils.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 400, height: 500, child: child)),
);

Widget _chart(
  List<KLineEntity>? data, {
  Set<SecondaryState> secondary = const {},
  bool showNowPrice = true,
}) {
  return _host(
    KChartWidget(
      data,
      ChartColors(),
      isTrendLine: false,
      watermarkAssetPath: 'assets/none.svg',
      timeFrame: const Duration(minutes: 15),
      showNowPrice: showNowPrice,
      mainStateLi: const {MainState.MA},
      secondaryStateLi: secondary,
    ),
  );
}

void main() {
  group('KChartWidget', () {
    testWidgets('renders a loading state for null candles', (tester) async {
      await tester.pumpWidget(_chart(null));
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders an empty candle list', (tester) async {
      await tester.pumpWidget(_chart(<KLineEntity>[]));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders candles with every sub-chart enabled', (tester) async {
      final data = candles(rampThenFall(80));
      DataUtil.calculate(data);

      await tester.pumpWidget(
        _chart(
          data,
          secondary: const {
            SecondaryState.MACD,
            SecondaryState.KDJ,
            SecondaryState.RSI,
            SecondaryState.WR,
            SecondaryState.CCI,
          },
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a sustained decline, where MACD stays negative', (
      tester,
    ) async {
      // Regression guard: the sub-chart's running maximum used to be seeded
      // with a tiny positive number, so an all-negative MACD scaled against 0.
      final data = candles([for (var i = 0; i < 60; i++) 300.0 - i * 2]);
      DataUtil.calculate(data);
      expect(data.last.macd!, lessThan(0));

      await tester.pumpWidget(
        _chart(data, secondary: const {SecondaryState.MACD}),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    // The countdown timer is internal state, so these cover the lifecycle
    // transitions rather than the tick itself: toggling in either direction
    // and unmounting mid-tick must all stay clean.
    testWidgets('toggles showNowPrice off and on without error', (
      tester,
    ) async {
      final data = candles(rampThenFall(40));
      DataUtil.calculate(data);

      await tester.pumpWidget(_chart(data));
      await tester.pump(const Duration(seconds: 2));

      await tester.pumpWidget(_chart(data, showNowPrice: false));
      await tester.pump(const Duration(seconds: 2));

      await tester.pumpWidget(_chart(data));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('survives being disposed while the timer is live', (
      tester,
    ) async {
      final data = candles(rampThenFall(40));
      DataUtil.calculate(data);

      await tester.pumpWidget(_chart(data));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(_host(const SizedBox()));
      expect(tester.takeException(), isNull);
    });
  });

  group('DepthChart', () {
    testWidgets('renders bids and asks', (tester) async {
      final bids = [
        for (var i = 0; i < 20; i++) DepthEntity(100.0 - i, (i + 1).toDouble()),
      ];
      final asks = [
        for (var i = 0; i < 20; i++) DepthEntity(101.0 + i, (i + 1).toDouble()),
      ];

      await tester.pumpWidget(_host(DepthChart(bids, asks)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders empty books', (tester) async {
      await tester.pumpWidget(
        _host(const DepthChart(<DepthEntity>[], <DepthEntity>[])),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
