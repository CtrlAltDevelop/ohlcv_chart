import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

const _bounds = Rect.fromLTWH(0, 0, 300, 208);

final _points = [
  EquityPoint(time: DateTime(2024), equity: 100),
  EquityPoint(time: DateTime(2024, 1, 2), equity: 200),
  EquityPoint(time: DateTime(2024, 1, 3), equity: 100),
  EquityPoint(time: DateTime(2024, 1, 4), equity: 150),
];

void main() {
  group('the maths', () {
    test('drawdown is the fall from the high so far', () {
      expect(equityDrawdowns(_points), [0, 0, -0.5, -0.25]);
    });

    test('a curve that only rises never falls', () {
      final rising = [
        EquityPoint(time: DateTime(2024), equity: 1),
        EquityPoint(time: DateTime(2024, 1, 2), equity: 2),
      ];
      expect(equityDrawdowns(rising), [0, 0]);
      expect(equityStats(rising).maxDrawdown, 0);
      expect(equityStats(rising).maxDrawdownStart, isNull);
    });

    test('the summary reports the ends, the high and the deepest fall', () {
      final stats = equityStats(_points);
      expect(stats.start, 100);
      expect(stats.end, 150);
      expect(stats.peak, 200);
      expect(stats.trough, 100);
      expect(stats.maxDrawdown, -0.5);
      expect(stats.maxDrawdownStart, DateTime(2024, 1, 2));
      expect(stats.maxDrawdownEnd, DateTime(2024, 1, 3));
      expect(stats.totalReturn, 0.5);
    });

    test('nothing to measure summarises to nothing', () {
      expect(equityStats(const []), EquityStats.empty);
      expect(equityDrawdowns(const []), isEmpty);
    });
  });

  group('the layout', () {
    test('the panels split the height, the gap taken out', () {
      final layout = layOutEquityCurve(
        _points,
        _bounds,
        drawdownFraction: 0.25,
        gap: 8,
      );
      expect(layout.equityRect.height, 150);
      expect(layout.drawdownRect.top, 158);
      expect(layout.drawdownRect.height, 50);
    });

    test('readings are spread evenly across the width', () {
      final layout = layOutEquityCurve(_points, _bounds);
      expect(layout.equity.map((p) => p.dx), [0, 100, 200, 300]);
    });

    test('the curve is drawn against its own range, highest at the top', () {
      final layout = layOutEquityCurve(
        _points,
        _bounds,
        drawdownFraction: 0.25,
        gap: 8,
      );
      expect(layout.minEquity, 100);
      expect(layout.maxEquity, 200);
      expect(layout.equity[1].dy, 0);
      expect(layout.equity[0].dy, 150);
    });

    test('the drawdown panel fills down from its top', () {
      final layout = layOutEquityCurve(
        _points,
        _bounds,
        drawdownFraction: 0.25,
        gap: 8,
      );
      expect(layout.deepestDrawdown, -0.5);
      expect(layout.drawdown[0].dy, 158); // flat: at the top
      expect(layout.drawdown[2].dy, 208); // deepest: at the bottom
      expect(layout.drawdown[3].dy, 183); // half as deep
    });

    test('one reading draws down the middle', () {
      final layout = layOutEquityCurve(_points.take(1).toList(), _bounds);
      expect(layout.equity.single.dx, 150);
    });

    test('nothing to show, or no room, lays out nothing', () {
      expect(layOutEquityCurve(const [], _bounds).isEmpty, isTrue);
      expect(layOutEquityCurve(_points, Rect.zero).isEmpty, isTrue);
    });

    test('the nearest reading to a position is found', () {
      final layout = layOutEquityCurve(_points, _bounds);
      expect(layout.indexAt(0), 0);
      expect(layout.indexAt(140), 1);
      expect(layout.indexAt(1000), 3);
    });
  });

  group('the widget', () {
    testWidgets('draws, reports touches and takes its default height',
        (tester) async {
      EquityTouchDetails? touched;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                EquityCurveChart(
                  points: _points,
                  onTouch: (d) => touched = d,
                  tooltipBuilder: (context, d) =>
                      Text('card ${d.point.equity}'),
                  semanticLabel: 'Equity',
                ),
              ],
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(EquityCurveChart));
      expect(size.height, 280);

      final topLeft = tester.getTopLeft(find.byType(EquityCurveChart));
      final gesture = await tester.startGesture(
        topLeft + Offset(size.width - 1, size.height / 2),
      );
      await tester.pump();
      expect(touched?.index, 3);
      expect(touched?.drawdown, -0.25);
      expect(find.text('card 150.0'), findsOneWidget);

      // The crosshair follows a drag along the curve.
      await gesture.moveTo(topLeft + Offset(1, size.height / 2));
      await tester.pump();
      expect(touched?.index, 0);

      await gesture.up();
      await tester.pump();
      expect(touched, isNull);
    });

    testWidgets('draws itself in and survives its data changing',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EquityCurveChart(
              points: _points,
              animationDuration: const Duration(milliseconds: 200),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EquityCurveChart(
              points: [EquityPoint(time: DateTime(2025), equity: 10)],
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
