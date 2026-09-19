import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

const _bounds = Rect.fromLTWH(0, 0, 200, 100);

const _slices = [
  VolatilitySlice(
    label: '7d',
    points: [
      VolatilityPoint(x: 110, volatility: 0.4),
      VolatilityPoint(x: 90, volatility: 0.5),
      VolatilityPoint(x: 100, volatility: 0.3),
    ],
  ),
  VolatilitySlice(
    label: '30d',
    dashed: true,
    points: [
      VolatilityPoint(x: 90, volatility: 0.45),
      VolatilityPoint(x: 110, volatility: 0.35),
    ],
  ),
];

VolatilityLayout _layOut() => layOutVolatility(
  _slices,
  _bounds,
  minX: 90,
  maxX: 110,
  minVol: 0.3,
  maxVol: 0.5,
);

void main() {
  group('the layout', () {
    test('readings are sorted along the bottom axis', () {
      final layout = _layOut();
      expect(layout.curves.first.readings.map((p) => p.x), [90, 100, 110]);
      expect(layout.curves.first.points.map((p) => p.dx), [0, 100, 200]);
    });

    test('volatility runs up the plot', () {
      final layout = _layOut();
      expect(layout.curves.first.points[0].dy, 0); // 50%: the top
      expect(layout.curves.first.points[1].dy, 100); // 30%: the bottom
    });

    test('readings that are not numbers are left out', () {
      final layout = layOutVolatility(
        const [
          VolatilitySlice(
            points: [
              VolatilityPoint(x: double.nan, volatility: 0.3),
              VolatilityPoint(x: 100, volatility: 0.3),
            ],
          ),
        ],
        _bounds,
        minX: 90,
        maxX: 110,
        minVol: 0.2,
        maxVol: 0.4,
      );
      expect(layout.curves.single.readings.length, 1);
    });

    test('the nearest reading on a curve is found', () {
      final layout = _layOut();
      expect(layout.curves.first.nearest(190), 2);
      expect(layout.curves.last.nearest(10), 0);
      expect(
        layOutVolatility(
          const [VolatilitySlice(points: [])],
          _bounds,
          minX: 0,
          maxX: 1,
          minVol: 0,
          maxVol: 1,
        ).curves.single.nearest(5),
        isNull,
      );
    });

    test('the range covers every reading, with room above and below', () {
      final range = volatilityRange(_slices);
      expect(range.minX, 90);
      expect(range.maxX, 110);
      expect(range.minVol, closeTo(0.276, 1e-9));
      expect(range.maxVol, closeTo(0.524, 1e-9));
    });

    test('a flat range still draws, and never goes below zero volatility', () {
      final range = volatilityRange(const [
        VolatilitySlice(points: [VolatilityPoint(x: 100, volatility: 0.005)]),
      ]);
      expect(range.minVol, 0);
      expect(range.maxVol, closeTo(0.015, 1e-9));
      expect(range.minX, 99);
      expect(volatilityRange(const []), (
        minX: 0.0,
        maxX: 1.0,
        minVol: 0.0,
        maxVol: 1.0,
      ));
    });

    test('nothing to show, or no room, lays out nothing', () {
      expect(
        layOutVolatility(
          const [],
          _bounds,
          minX: 0,
          maxX: 1,
          minVol: 0,
          maxVol: 1,
        ).isEmpty,
        isTrue,
      );
      expect(
        layOutVolatility(
          _slices,
          Rect.zero,
          minX: 0,
          maxX: 1,
          minVol: 0,
          maxVol: 1,
        ).isEmpty,
        isTrue,
      );
    });
  });

  group('the widget', () {
    testWidgets('draws, reports one reading per curve, and takes its height', (
      tester,
    ) async {
      VolatilityTouchDetails? touched;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                VolatilityCurveChart(
                  slices: _slices,
                  atTheMoney: 100,
                  xAxisTitle: 'Strike',
                  onTouch: (d) => touched = d,
                  tooltipBuilder: (context, d) =>
                      Text('card ${d.readouts.length}'),
                  semanticLabel: 'Smile',
                ),
              ],
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(VolatilityCurveChart));
      expect(size.height, 240);

      final topLeft = tester.getTopLeft(find.byType(VolatilityCurveChart));
      final gesture = await tester.startGesture(
        topLeft + Offset(size.width - 1, 60),
      );
      await tester.pump();
      expect(touched?.readouts.length, 2);
      expect(touched?.readouts.first.point.x, 110);
      expect(find.text('card 2'), findsOneWidget);

      await gesture.up();
      await tester.pump();
      expect(touched, isNull);
    });

    testWidgets('draws itself in and survives its data changing', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VolatilityCurveChart(
              slices: _slices,
              curved: false,
              animationDuration: const Duration(milliseconds: 200),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VolatilityCurveChart(
              slices: const [
                VolatilitySlice(
                  points: [VolatilityPoint(x: 1, volatility: 0.2)],
                ),
              ],
              animationDuration: const Duration(milliseconds: 200),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
