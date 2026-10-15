import 'dart:ui' show PointerDeviceKind;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

const _strikes = [90.0, 100.0, 110.0];
const _expiries = ['1M', '3M'];
const List<List<double?>> _vols = [
  [0.34, 0.28, 0.31],
  [0.30, 0.26, null],
];

void main() {
  group('the at-the-money strike', () {
    test('is the one nearest the spot', () {
      expect(atTheMoneyIndex(_strikes, 99), 1);
      expect(atTheMoneyIndex(_strikes, 104), 1);
      expect(atTheMoneyIndex(_strikes, 106), 2);
      expect(atTheMoneyIndex(_strikes, 0), 0);
    });

    test('is none without strikes or with a spot that is not a number', () {
      expect(atTheMoneyIndex(const [], 100), isNull);
      expect(atTheMoneyIndex(_strikes, double.nan), isNull);
    });
  });

  group('the skew', () {
    test('is each strike against the at-the-money one', () {
      final skew = surfaceSkew(_vols[0], 1);

      expect(skew[0], closeTo(0.06, 1e-9));
      expect(skew[1], closeTo(0, 1e-9));
      expect(skew[2], closeTo(0.03, 1e-9));
    });

    test('is empty where either side is missing', () {
      expect(surfaceSkew(_vols[1], 2), everyElement(isNull));
      expect(surfaceSkew(_vols[0], null), everyElement(isNull));
      expect(surfaceSkew(const [null, 0.3], 1)[0], isNull);
    });
  });

  group('the widget', () {
    Widget host(Widget chart) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 400, height: 300, child: chart)),
    );

    testWidgets('draws every reading as a percentage', (tester) async {
      await tester.pumpWidget(
        host(
          const VolatilitySurfaceChart(
            strikes: _strikes,
            expiries: _expiries,
            volatilities: _vols,
          ),
        ),
      );

      expect(find.byType(HeatmapChart), findsOneWidget);
      final heatmap = tester.widget<HeatmapChart>(find.byType(HeatmapChart));
      // Five readings: the missing one leaves its square empty.
      expect(heatmap.cells, hasLength(5));
      expect(heatmap.minValue, 0.26);
      expect(heatmap.maxValue, 0.34);
    });

    testWidgets('reports the expiry, strike and skew of a touch', (
      tester,
    ) async {
      VolatilitySurfaceTouchDetails? touched;
      await tester.pumpWidget(
        host(
          VolatilitySurfaceChart(
            strikes: _strikes,
            expiries: _expiries,
            volatilities: _vols,
            spot: 100,
            onTouch: (d) => touched = d,
          ),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      final box = tester.getRect(find.byType(VolatilitySurfaceChart));
      // First square of the first row: past the 44 px expiry axis, in the top
      // row of a grid whose bottom 20 px are the strikes.
      await gesture.moveTo(box.topLeft + const Offset(60, 20));

      expect(touched, isNotNull);
      expect(touched!.expiry, '1M');
      expect(touched!.strike, 90);
      expect(touched!.volatility, 0.34);
      expect(touched!.atTheMoneyVolatility, 0.28);
      expect(touched!.skew, closeTo(0.06, 1e-9));
    });

    testWidgets('survives nothing to draw', (tester) async {
      await tester.pumpWidget(
        host(
          const VolatilitySurfaceChart(
            strikes: [],
            expiries: [],
            volatilities: [],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
