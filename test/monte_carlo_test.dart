import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

final _paths = <List<double>>[
  [100.0, 110, 120],
  [100.0, 90, 70],
  [100.0, 100, 105],
];

MonteCarloResult _result({double? ruinLevel}) => MonteCarloResult.fromPaths(
  _paths,
  startingEquity: 100,
  percentiles: const [0, 0.5, 1],
  ruinLevel: ruinLevel,
);

void main() {
  group('reading paths', () {
    test('bands take each percentile at every step', () {
      final result = _result();
      expect(result.steps, 2);
      expect(result.bands[0], [100, 90, 70]);
      expect(result.bandAt(0.5), [100, 100, 105]);
      expect(result.bandAt(1), [100, 110, 120]);
      expect(result.bandAt(0.9), isNull);
    });

    test('percentiles interpolate between neighbours', () {
      final result = MonteCarloResult.fromPaths(
        _paths,
        startingEquity: 100,
        percentiles: const [0.75, 0.25],
      );
      expect(result.percentiles, [0.25, 0.75]);
      expect(result.bands[0][1], 95);
      expect(result.finalEquityAt(0.75), 112.5);
    });

    test('drawdowns, loss and ruin are counted per path', () {
      final result = _result(ruinLevel: 80);
      expect(result.maxDrawdowns, [0, closeTo(-0.3, 1e-9), 0]);
      expect(result.drawdownAt(0), closeTo(-0.3, 1e-9));
      expect(result.lossProbability, closeTo(1 / 3, 1e-9));
      expect(result.ruinProbability, closeTo(1 / 3, 1e-9));
      expect(_result().ruinProbability, 0);
    });

    test('nothing to read is empty', () {
      final result = MonteCarloResult.fromPaths(const [], startingEquity: 1);
      expect(result.isEmpty, isTrue);
      expect(result.steps, 0);
      expect(result.lossProbability, 0);
    });
  });

  group('simulating', () {
    test('a seed repeats the run', () {
      final a = runMonteCarlo(
        const [0.01, -0.02, 0.03],
        seed: 3,
        pathCount: 50,
      );
      final b = runMonteCarlo(
        const [0.01, -0.02, 0.03],
        seed: 3,
        pathCount: 50,
      );
      expect(a.paths, b.paths);
      expect(a.paths.length, 50);
      expect(a.steps, 3);
    });

    test('fixed results add and compounding ones multiply', () {
      final fixed = runMonteCarlo(
        const [10],
        startingEquity: 100,
        sizing: MonteCarloSizing.fixed,
        steps: 3,
        pathCount: 2,
      );
      expect(fixed.paths.first, [100, 110, 120, 130]);

      final compound = runMonteCarlo(
        const [0.1],
        startingEquity: 100,
        steps: 2,
        pathCount: 1,
      );
      expect(compound.paths.first.last, closeTo(121, 1e-9));
    });

    test('an account never falls below zero', () {
      final result = runMonteCarlo(
        const [-1.5],
        startingEquity: 100,
        steps: 2,
        pathCount: 1,
      );
      expect(result.paths.first, [100, 0, 0]);
      expect(result.maxDrawdowns.first, -1);
    });

    test('a median of many draws sits near the expected path', () {
      final result = runMonteCarlo(
        const [10, -10, 20, -5],
        startingEquity: 1000,
        sizing: MonteCarloSizing.fixed,
        steps: 100,
        pathCount: 2000,
        seed: 11,
      );
      final median = result.bandAt(0.5)!.last;
      // 100 trades averaging +3.75.
      expect(median, closeTo(1375, 25));
      expect(result.bandAt(0.05)!.last, lessThan(median));
      expect(result.bandAt(0.95)!.last, greaterThan(median));
    });

    test('nothing to draw from simulates nothing', () {
      expect(runMonteCarlo(const []).isEmpty, isTrue);
      expect(runMonteCarlo(const [double.nan]).isEmpty, isTrue);
    });
  });

  group('the layout', () {
    const bounds = Rect.fromLTWH(0, 0, 200, 100);

    test('steps span the width and values the height', () {
      final layout = layOutMonteCarlo(_result(), bounds, min: 0, max: 200);
      expect(layout.xOf(1), 100);
      expect(layout.yOf(100), 50);
      expect(layout.bands.length, 3);
      expect(layout.bands[2][2], const Offset(200, 40));
      expect(layout.stepAt(90), 1);
      expect(layout.stepAt(-50), 0);
    });

    test('the range takes in everything drawn, with room', () {
      final layout = layOutMonteCarlo(
        _result(ruinLevel: 50),
        bounds,
        actual: const [100, 130],
        sampleCount: 2,
      );
      expect(layout.min, lessThan(50));
      expect(layout.max, greaterThan(130));
      expect(layout.samples.length, 2);
      expect(layout.actual.length, 2);
    });

    test('nothing to show lays out nothing', () {
      expect(layOutMonteCarlo(runMonteCarlo(const []), bounds).isEmpty, isTrue);
      expect(layOutMonteCarlo(_result(), Rect.zero).isEmpty, isTrue);
      expect(layOutMonteCarlo(_result(), bounds).stepAt(10), isNotNull);
    });
  });

  group('the widget', () {
    testWidgets('draws, reports touches and takes its default height', (
      tester,
    ) async {
      MonteCarloTouchDetails? touched;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                MonteCarloChart(
                  result: _result(ruinLevel: 80),
                  actual: const [100, 104],
                  onTouch: (d) => touched = d,
                  tooltipBuilder: (context, d) =>
                      Text('median ${d.valueAt(0.5)}'),
                  semanticLabel: 'Monte Carlo',
                ),
              ],
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(MonteCarloChart));
      expect(size.height, 280);

      final topLeft = tester.getTopLeft(find.byType(MonteCarloChart));
      const axis = 52.0;
      final gesture = await tester.startGesture(
        topLeft + Offset(axis + (size.width - axis) / 2, 100),
      );
      await tester.pump();
      expect(touched?.step, 1);
      expect(touched?.values, [90, 100, 110]);
      expect(touched?.actual, 104);
      expect(find.text('median 100.0'), findsOneWidget);

      await gesture.up();
      await tester.pump();
      expect(touched, isNull);
    });

    testWidgets('animates and survives a new result', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MonteCarloChart(
              result: runMonteCarlo(
                [for (var i = 0; i < 40; i++) math.sin(i) / 50],
                seed: 1,
                pathCount: 100,
              ),
              animationDuration: const Duration(milliseconds: 200),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MonteCarloChart(
              result: runMonteCarlo(const []),
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
