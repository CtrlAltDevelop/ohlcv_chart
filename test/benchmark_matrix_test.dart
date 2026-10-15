import 'dart:ui' show PointerDeviceKind;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

const _models = ['A', 'B', 'C'];
const _benchmarks = ['MMLU', 'GSM8K', 'PPL'];
const List<List<double?>> _scores = [
  [86.0, 92.0, 5.0],
  [80.0, 88.0, 6.0],
  [74.0, null, 7.0],
];

void main() {
  group('quality', () {
    test('runs from the worst of a column to the best', () {
      final q = benchmarkQuality(_scores);

      expect(q[0][0], 1);
      expect(q[2][0], 0);
      expect(q[1][0], closeTo(0.5, 1e-9));
      expect(q[2][1], isNull);
    });

    test('a lower-is-better column is turned over', () {
      final q = benchmarkQuality(_scores, lowerIsBetter: {2});

      expect(q[0][2], 1);
      expect(q[2][2], 0);
    });

    test('a column everyone scored alike is the middle', () {
      final q = benchmarkQuality(const [
        [5.0],
        [5.0],
      ]);

      expect(q[0][0], 0.5);
      expect(q[1][0], 0.5);
    });

    test('nothing is nothing', () {
      expect(benchmarkQuality(const []), isEmpty);
      expect(benchmarkAverages(const []), isEmpty);
      expect(benchmarkLeaders(const []), isEmpty);
    });
  });

  group('averages and leaders', () {
    test('an average is over the scores a model has', () {
      final q = benchmarkQuality(_scores, lowerIsBetter: {2});
      final avg = benchmarkAverages(q);

      expect(avg[0], 1);
      expect(avg[2], 0);
      expect(avg[1]! > avg[2]!, isTrue);
      expect(
        benchmarkAverages(const [
          [null, null],
        ]).single,
        isNull,
      );
    });

    test('the leader of a column, turned over where lower wins', () {
      expect(benchmarkLeaders(_scores, lowerIsBetter: {2}), [0, 0, 2 - 2]);
      expect(benchmarkLeaders(_scores), [0, 0, 2]);
    });
  });

  group('the widget', () {
    Widget host(Widget chart) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 500, height: 300, child: chart)),
    );

    testWidgets('stars each leader and orders models by average', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const BenchmarkMatrixChart(
            // Given worst first, to see it put the best on top.
            models: ['C', 'B', 'A'],
            benchmarks: _benchmarks,
            scores: [
              [74.0, null, 7.0],
              [80.0, 88.0, 6.0],
              [86.0, 92.0, 5.0],
            ],
            lowerIsBetter: {2},
          ),
        ),
      );

      final heatmap = tester.widget<HeatmapChart>(find.byType(HeatmapChart));
      expect(heatmap.yAxis.labels, ['A', 'B', 'C']);
      final starred = heatmap.cells.where((c) => c.label!.startsWith('★'));
      expect(starred, hasLength(3));
      expect(heatmap.columns, 4);
    });

    testWidgets('reports a score, its standing and whether it leads', (
      tester,
    ) async {
      BenchmarkTouchDetails? touched;
      await tester.pumpWidget(
        host(
          BenchmarkMatrixChart(
            models: _models,
            benchmarks: _benchmarks,
            scores: _scores,
            lowerIsBetter: const {2},
            onTouch: (d) => touched = d,
          ),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      final origin = tester.getTopLeft(find.byType(BenchmarkMatrixChart));
      // First square: past the 88 px model axis, in the first of three rows
      // above the 22 px benchmark axis.
      await gesture.moveTo(origin + const Offset(88 + 20, 20));

      expect(touched, isNotNull);
      expect(touched!.model, 'A');
      expect(touched!.benchmark, 'MMLU');
      expect(touched!.score, 86);
      expect(touched!.isLeader, isTrue);
      expect(touched!.quality, 1);
    });

    testWidgets('survives no models and ragged rows', (tester) async {
      await tester.pumpWidget(
        host(
          const BenchmarkMatrixChart(models: [], benchmarks: [], scores: []),
        ),
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        host(
          const BenchmarkMatrixChart(
            models: ['A', 'B'],
            benchmarks: ['x', 'y', 'z'],
            scores: [
              [1],
              [2, 3, 4, 5],
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
