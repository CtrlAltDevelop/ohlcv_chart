import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart/src/components/popup_info_view.dart';
import 'package:ohlcv_chart/src/renderer/chart_painter.dart';

import 'test_utils.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 400, height: 500, child: child)),
);

Widget _chart(
  List<KLineEntity>? data, {
  List<Indicator>? indicators,
  bool showNowPrice = true,
}) {
  return _host(
    KChartWidget(
      data,
      ChartColors(),
      isTrendLine: false,
      timeFrame: const Duration(minutes: 15),
      showNowPrice: showNowPrice,
      indicators: indicators ?? [MaIndicator()],
    ),
  );
}

/// One instance of every catalog entry drawn in [placement], at its defaults.
List<Indicator> _catalogInstances(IndicatorPlacement placement) => [
  for (final type in indicatorCatalog)
    if (type.placement == placement) type.create(),
];

/// The chart's painter, to inspect what it was actually handed to draw.
ChartPainter _painterOf(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((paint) => paint.painter)
    .whereType<ChartPainter>()
    .single;

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
        _chart(data, indicators: _catalogInstances(IndicatorPlacement.pane)),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders every main-chart overlay at once', (tester) async {
      final data = candles(rampThenFall(80));
      DataUtil.calculate(data);

      await tester.pumpWidget(
        _chart(data, indicators: _catalogInstances(IndicatorPlacement.overlay)),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders each indicator on its own, over few candles', (
      tester,
    ) async {
      // Short histories leave the newer indicators still warming up, which is
      // where a painter that assumes a value tends to fall over.
      final data = candles(rampThenFall(6));
      DataUtil.calculate(data);

      for (final type in indicatorCatalog) {
        await tester.pumpWidget(_chart(data, indicators: [type.create()]));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: type.name);
      }
    });

    testWidgets('renders a sustained decline, where MACD stays negative', (
      tester,
    ) async {
      // Regression guard: the sub-chart's running maximum used to be seeded
      // with a tiny positive number, so an all-negative MACD scaled against 0.
      final data = candles([for (var i = 0; i < 60; i++) 300.0 - i * 2]);
      DataUtil.calculate(data);
      expect(data.last.macd!, lessThan(0));

      await tester.pumpWidget(_chart(data, indicators: [MacdIndicator()]));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('picks up indicators added to the list it was given', (
      tester,
    ) async {
      final data = candles(rampThenFall(40));
      DataUtil.calculate(data);
      final indicators = <Indicator>[MaIndicator(period: 5)];

      await tester.pumpWidget(_chart(data, indicators: indicators));
      await tester.pump();
      expect(_painterOf(tester).panes, isEmpty);
      expect(
        _painterOf(tester).overlays.single.colorFor(0, ChartColors()),
        isNot(Colors.pink),
      );

      // The list is mutated in place, as an app's own state would be.
      indicators.add(AtrIndicator(period: 8));
      await tester.pumpWidget(_chart(data, indicators: indicators));
      await tester.pump();
      expect(_painterOf(tester).panes.single.indicator.label, 'ATR(8)');

      // Recolouring replaces the instance without changing the settings.
      indicators.upsert(MaIndicator(period: 5, color: Colors.pink));
      await tester.pumpWidget(_chart(data, indicators: indicators));
      await tester.pump();
      expect(
        _painterOf(tester).overlays.single.colorFor(0, ChartColors()),
        Colors.pink,
      );
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

  group('DepthEntity curves', () {
    test('bids accumulate from the best bid down to the deepest', () {
      final curve = DepthEntity.bids([
        DepthEntity(100, 1),
        DepthEntity(98, 2),
        DepthEntity(99, 3),
      ]);

      // Ascending by price, with the deepest cumulative total at the left.
      expect(curve.map((e) => e.price), [98, 99, 100]);
      expect(curve.map((e) => e.vol), [6, 4, 1]);
    });

    test('asks accumulate from the best ask up', () {
      final curve = DepthEntity.asks([
        DepthEntity(102, 3),
        DepthEntity(101, 2),
        DepthEntity(103, 1),
      ]);

      expect(curve.map((e) => e.price), [101, 102, 103]);
      expect(curve.map((e) => e.vol), [2, 5, 6]);
    });
  });

  group('long-press readout', () {
    /// Labels long enough to overflow the card if its rows did not shrink.
    const wordy = ChartTranslations(
      date: 'Datum und Uhrzeit',
      changeLive: 'Veränderung live in Prozent',
      vol: 'Gehandeltes Volumen',
    );

    testWidgets('stays inside its card while the press is held', (
      tester,
    ) async {
      final data = candles(rampThenFall(60));
      DataUtil.calculate(data);

      await tester.pumpWidget(
        _host(
          KChartWidget(
            data,
            ChartColors(),
            isTrendLine: false,
            timeFrame: const Duration(minutes: 15),
            showNowPrice: false,
            timeFormat: TimeFormat.YEAR_MONTH_DAY_WITH_HOUR,
            chartTranslations: wordy,
          ),
        ),
      );

      // Hold rather than long-press: the readout only shows while the finger
      // is down, which is when it used to overflow.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(KChartWidget)),
      );
      addTearDown(() async => gesture.up());
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await tester.pump();
      await tester.pump();

      expect(find.text('Datum und Uhrzeit'), findsOne);
      expect(
        tester.getSize(find.text('Datum und Uhrzeit')).width,
        lessThan(240),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('sizes itself between its minimum and maximum width', (
      tester,
    ) async {
      Future<double> widthOf({required double min, required double max}) async {
        await tester.pumpWidget(
          _host(
            Align(
              alignment: Alignment.topLeft,
              child: PopupInfoView(
                entity: candle(12345.6789, minute: 3),
                width: min,
                maxWidth: max,
                chartColors: ChartColors(),
                chartTranslations: const ChartTranslations(),
                materialInfoDialog: true,
                timeFormat: TimeFormat.YEAR_MONTH_DAY_WITH_HOUR,
                fixedLength: 2,
                livePrice: 12400,
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        return tester.getSize(find.byType(PopupInfoView)).width;
      }

      // Content wider than the maximum is ellipsised, not overflowed.
      expect(await widthOf(min: 132, max: 240), 240);

      // Given room, the card hugs its content instead of filling the maximum.
      final roomy = await widthOf(min: 132, max: 400);
      expect(roomy, greaterThan(240));
      expect(roomy, lessThan(400));

      // The minimum still wins when the content is narrower than it.
      expect(await widthOf(min: 380, max: 400), 380);

      // A maximum below the minimum still lays out.
      expect(await widthOf(min: 200, max: 120), 120);
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
