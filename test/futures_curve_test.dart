import 'dart:ui' show PointerDeviceKind;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

List<FuturesContract> _curve(List<double> prices) => [
  for (var i = 0; i < prices.length; i++)
    FuturesContract(label: 'M$i', price: prices[i]),
];

void main() {
  group('the shape', () {
    test('rising prices are contango', () {
      expect(curveShape(_curve([70, 71, 72.5])), CurveShape.contango);
    });

    test('falling prices are backwardation', () {
      expect(curveShape(_curve([75, 73, 72])), CurveShape.backwardation);
    });

    test('equal prices are flat', () {
      expect(curveShape(_curve([70, 70, 70])), CurveShape.flat);
    });

    test('a curve that rises and falls is mixed', () {
      expect(curveShape(_curve([70, 72, 71])), CurveShape.mixed);
    });

    test('fewer than two prices is unknown', () {
      expect(curveShape(_curve([70])), CurveShape.unknown);
      expect(curveShape(const []), CurveShape.unknown);
      expect(curveShape(_curve([70, double.nan])), CurveShape.unknown);
    });

    test('a step under the tolerance reads as flat', () {
      // 70.00 -> 70.02 is 0.03% of the price.
      expect(
        curveShape(_curve([70, 70.02, 72]), tolerance: 0.001),
        CurveShape.contango,
      );
      expect(
        curveShape(_curve([70, 70.02, 70.01, 72]), tolerance: 0.001),
        CurveShape.contango,
      );
      expect(
        curveShape(_curve([70, 70.02, 70.01]), tolerance: 0.001),
        CurveShape.flat,
      );
    });

    test('a missing price is skipped, not bridged as a zero', () {
      expect(curveShape(_curve([70, double.nan, 72])), CurveShape.contango);
    });
  });

  group('the slope and the spreads', () {
    test('the slope is the last price over the first', () {
      expect(curveSlope(_curve([100, 102, 105])), closeTo(0.05, 1e-9));
      expect(curveSlope(_curve([100])), isNull);
      expect(curveSlope(_curve([0, 5])), isNull);
    });

    test('a calendar spread is a price less the one before', () {
      final spreads = calendarSpreads(_curve([70, 71.5, double.nan, 73]));

      expect(spreads[0], isNull);
      expect(spreads[1], closeTo(1.5, 1e-9));
      expect(spreads[2], isNull);
      expect(spreads[3], isNull);
    });
  });

  group('the layout', () {
    const bounds = Rect.fromLTWH(0, 0, 300, 100);

    test('the same contract sits at the same place on every curve', () {
      final curves = [
        FuturesCurve(label: 'now', contracts: _curve([70, 71, 72])),
        FuturesCurve(label: 'then', contracts: _curve([68, 69, 70])),
      ];

      final dots = layOutFutures(curves, bounds, minPrice: 60, maxPrice: 80);

      expect(dots, hasLength(6));
      expect(dots[0].center.dx, dots[3].center.dx);
      expect(dots[1].center.dx, dots[4].center.dx);
      // Three slots across 300 px: the middle of each.
      expect(dots[0].center.dx, 50);
      expect(dots[2].center.dx, 250);
    });

    test('prices run up the plot', () {
      final dots = layOutFutures(
        [
          FuturesCurve(label: 'a', contracts: _curve([60, 70, 80])),
        ],
        bounds,
        minPrice: 60,
        maxPrice: 80,
      );

      expect(dots[0].center.dy, 100);
      expect(dots[1].center.dy, 50);
      expect(dots[2].center.dy, 0);
    });

    test('a contract with no price has no dot, and keeps its place', () {
      final dots = layOutFutures(
        [
          FuturesCurve(label: 'a', contracts: _curve([60, double.nan, 80])),
        ],
        bounds,
        minPrice: 60,
        maxPrice: 80,
      );

      expect(dots.map((d) => d.contractIndex), [0, 2]);
    });

    test('a shorter curve leaves the far slots empty', () {
      expect(
        futuresSlots([
          FuturesCurve(label: 'a', contracts: _curve([1, 2])),
          FuturesCurve(label: 'b', contracts: _curve([1, 2, 3, 4])),
        ]),
        4,
      );
    });

    test('nothing to lay out, or no room, lays nothing out', () {
      expect(
        layOutFutures(const [], bounds, minPrice: 0, maxPrice: 1),
        isEmpty,
      );
      expect(
        layOutFutures(
          [
            FuturesCurve(label: 'a', contracts: _curve([1, 2])),
          ],
          Rect.zero,
          minPrice: 0,
          maxPrice: 1,
        ),
        isEmpty,
      );
    });
  });

  group('the widget', () {
    Widget host(Widget chart) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 400, height: 300, child: chart)),
    );

    testWidgets('reports a contract and its spread on touch', (tester) async {
      FuturesTouchDetails? touched;
      final curve = FuturesCurve(
        label: 'now',
        contracts: _curve([70, 71.5, 73]),
      );
      await tester.pumpWidget(
        host(FuturesCurveChart(curves: [curve], onTouch: (d) => touched = d)),
      );

      final range = futuresPriceRange([curve]);
      // A 400x300 box with 48 px of price axis and 18 px of contract axis.
      const plotLeft = 48.0;
      const plotRight = 400.0;
      const plotBottom = 300.0 - 18;
      final x = plotLeft + (1 + 0.5) / 3 * (plotRight - plotLeft);
      final y =
          plotBottom -
          (71.5 - range.min) / (range.max - range.min) * plotBottom;

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      final origin = tester.getTopLeft(find.byType(FuturesCurveChart));
      await gesture.moveTo(origin + Offset(x, y));

      expect(touched?.contract.label, 'M1');
      expect(touched?.spread, closeTo(1.5, 1e-9));

      await gesture.moveTo(origin + const Offset(1, 1));
      expect(touched, isNull);
    });

    testWidgets('survives nothing to draw and a single contract', (
      tester,
    ) async {
      await tester.pumpWidget(host(const FuturesCurveChart(curves: [])));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        host(
          FuturesCurveChart(
            curves: [
              FuturesCurve(label: 'a', contracts: _curve([70])),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
