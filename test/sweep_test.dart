import 'dart:ui' show PointerDeviceKind;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

const _trials = [
  SweepTrial(x: 1e-4, y: 32, score: 2.4),
  SweepTrial(x: 3e-4, y: 32, score: 2.1),
  SweepTrial(x: 1e-3, y: 32, score: 2.9),
  SweepTrial(x: 1e-4, y: 64, score: 2.3),
  SweepTrial(x: 3e-4, y: 64, score: 1.9),
  SweepTrial(x: 1e-3, y: 64, score: double.nan),
];

void main() {
  group('the grid', () {
    test('gathers distinct settings, ascending', () {
      final grid = sweepGrid(_trials);

      expect(grid.xs, [1e-4, 3e-4, 1e-3]);
      expect(grid.ys, [32, 64]);
      expect(grid.scores[0], [2.4, 2.1, 2.9]);
      expect(grid.scores[1], [2.3, 1.9, null]);
    });

    test('the best is the lowest score, or the highest', () {
      final low = sweepGrid(_trials);
      expect(low.bestX, 1);
      expect(low.bestY, 1);
      expect(low.best, 1.9);

      final high = sweepGrid(_trials, lowerIsBetter: false);
      expect(high.bestX, 2);
      expect(high.bestY, 0);
      expect(high.best, 2.9);
    });

    test('trials on the same combination are averaged', () {
      final grid = sweepGrid(const [
        SweepTrial(x: 1, y: 1, score: 2),
        SweepTrial(x: 1, y: 1, score: 4),
      ]);

      expect(grid.scores.single.single, 3);
      expect(grid.counts.single.single, 2);
    });

    test('the marginals are means of what was tried', () {
      final grid = sweepGrid(_trials);

      expect(grid.columnMeans[0], closeTo(2.35, 1e-9));
      expect(grid.columnMeans[2], closeTo(2.9, 1e-9));
      expect(grid.rowMeans[1], closeTo((2.3 + 1.9) / 2, 1e-9));
    });

    test('nothing, or nothing finite, is an empty grid', () {
      final empty = sweepGrid(const []);
      expect(empty.xs, isEmpty);
      expect(empty.best, isNull);

      final bad = sweepGrid(const [
        SweepTrial(x: double.nan, y: 1, score: 1),
        SweepTrial(x: 1, y: 1, score: double.infinity),
      ]);
      expect(bad.xs, isEmpty);
    });
  });

  test('settings are written compactly', () {
    expect(SweepChart.formatSetting(0.0003), '3e-4');
    expect(SweepChart.formatSetting(128), '128');
    expect(SweepChart.formatSetting(0.5), '0.5');
    expect(SweepChart.formatSetting(0), '0');
    expect(SweepChart.formatSetting(100000), '1e5');
  });

  group('the widget', () {
    Widget host(Widget chart) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 400, height: 300, child: chart)),
    );

    testWidgets('stars the best and reports it on touch', (tester) async {
      SweepTouchDetails? touched;
      await tester.pumpWidget(
        host(SweepChart(trials: _trials, onTouch: (d) => touched = d)),
      );

      expect(find.byType(HeatmapChart), findsOneWidget);
      final heatmap = tester.widget<HeatmapChart>(find.byType(HeatmapChart));
      final labels = [for (final c in heatmap.cells) c.label];
      expect(labels.where((l) => l!.startsWith('★')), hasLength(1));
      expect(labels, contains('★ 1.90'));

      // Four columns (three and the mean), three rows (two and the mean):
      // the best sits in column 1, row 1.
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      final origin = tester.getTopLeft(find.byType(SweepChart));
      const gridW = 400 - 56.0;
      const gridH = 300 - 20.0;
      await gesture.moveTo(
        origin + const Offset(56 + gridW / 4 * 1.5, gridH / 3 * 1.5),
      );

      expect(touched, isNotNull);
      expect(touched!.isBest, isTrue);
      expect(touched!.x, 3e-4);
      expect(touched!.y, 64);
      expect(touched!.score, 1.9);
    });

    testWidgets('survives no trials', (tester) async {
      await tester.pumpWidget(host(const SweepChart(trials: [])));
      expect(tester.takeException(), isNull);
    });
  });
}
