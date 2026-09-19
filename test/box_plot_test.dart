import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

const _bounds = Rect.fromLTWH(0, 0, 300, 200);

const _stats = BoxPlotStats(lower: 0, q1: 25, median: 50, q3: 75, upper: 100);

void main() {
  group('the summary', () {
    test('quartiles are interpolated off the sorted samples', () {
      final stats = BoxPlotStats.fromSamples(const [
        7,
        1,
        3,
        5,
        9,
      ], whisker: double.infinity);
      expect(stats.q1, 3);
      expect(stats.median, 5);
      expect(stats.q3, 7);
      expect(stats.mean, 5);
      expect(stats.iqr, 4);
    });

    test('whiskers reach the furthest sample within 1.5 IQRs', () {
      final stats = BoxPlotStats.fromSamples(const [1, 2, 3, 4, 5, 100]);
      expect(stats.outliers, [100]);
      expect(stats.upper, 5);
      expect(stats.lower, 1);
      expect(stats.max, 100);
    });

    test('an infinite whisker keeps everything inside', () {
      final stats = BoxPlotStats.fromSamples(const [
        1,
        2,
        3,
        100,
      ], whisker: double.infinity);
      expect(stats.outliers, isEmpty);
      expect(stats.upper, 100);
    });

    test('values that are not numbers are left out', () {
      final stats = BoxPlotStats.fromSamples(const [1, double.nan, 3]);
      expect(stats.median, 2);
    });

    test('no samples summarise to zeros', () {
      final stats = BoxPlotStats.fromSamples(const []);
      expect(stats.median, 0);
      expect(stats.outliers, isEmpty);
    });
  });

  group('the layout', () {
    final entries = const [
      BoxPlotEntry(stats: _stats, label: 'A'),
      BoxPlotEntry(stats: _stats, label: 'B'),
    ];

    test('entries take a column each, boxes centred in them', () {
      final boxes = layOutBoxPlot(entries, _bounds, min: 0, max: 100);
      expect(boxes[0].band, const Rect.fromLTWH(0, 0, 150, 200));
      expect(boxes[0].centerX, 75);
      expect(boxes[1].centerX, 225);
      expect(boxes[0].rect.width, 64); // capped by maxBoxWidth
    });

    test('values run up the box, min at the bottom', () {
      final boxes = layOutBoxPlot(entries, _bounds, min: 0, max: 100);
      expect(boxes[0].lowerY, 200);
      expect(boxes[0].rect.bottom, 150);
      expect(boxes[0].medianY, 100);
      expect(boxes[0].rect.top, 50);
      expect(boxes[0].upperY, 0);
    });

    test('outliers are placed, and the mean only when there is one', () {
      final boxes = layOutBoxPlot(
        const [
          BoxPlotEntry(
            stats: BoxPlotStats(
              lower: 0,
              q1: 25,
              median: 50,
              q3: 75,
              upper: 100,
              mean: 60,
              outliers: [0, 100],
            ),
          ),
        ],
        _bounds,
        min: 0,
        max: 100,
      );
      expect(boxes.single.meanY, 80);
      expect(boxes.single.outlierYs, [200, 0]);
      expect(
        layOutBoxPlot(entries, _bounds, min: 0, max: 100).first.meanY,
        isNull,
      );
    });

    test('the range covers every entry, outliers included, with padding', () {
      final range = boxPlotRange(const [
        BoxPlotEntry(
          stats: BoxPlotStats(
            lower: 10,
            q1: 20,
            median: 30,
            q3: 40,
            upper: 50,
            outliers: [110],
          ),
        ),
      ]);
      expect(range.min, 5);
      expect(range.max, 115);
    });

    test('a flat range still draws', () {
      final range = boxPlotRange(const [
        BoxPlotEntry(
          stats: BoxPlotStats(lower: 5, q1: 5, median: 5, q3: 5, upper: 5),
        ),
      ]);
      expect(range, (min: 4.0, max: 6.0));
    });

    test('nothing to show, or no room, lays out nothing', () {
      expect(layOutBoxPlot(const [], _bounds, min: 0, max: 1), isEmpty);
      expect(layOutBoxPlot(entries, Rect.zero, min: 0, max: 1), isEmpty);
    });

    test('a point in a column finds its box', () {
      final boxes = layOutBoxPlot(entries, _bounds, min: 0, max: 100);
      expect(boxPlotBoxAt(boxes, const Offset(200, 10))?.index, 1);
      expect(boxPlotBoxAt(boxes, const Offset(200, 500)), isNull);
    });
  });

  group('the widget', () {
    testWidgets('draws, reports touches and takes its default height', (
      tester,
    ) async {
      BoxPlotTouchDetails? touched;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                BoxPlotChart(
                  entries: [
                    BoxPlotEntry.fromSamples(const [
                      1,
                      2,
                      3,
                      4,
                      5,
                    ], label: 'Trend'),
                    BoxPlotEntry.fromSamples(const [
                      2,
                      4,
                      6,
                      8,
                      40,
                    ], label: 'Reversion'),
                  ],
                  onTouch: (d) => touched = d,
                  tooltipBuilder: (context, d) => Text('card ${d.entry.label}'),
                  semanticLabel: 'Returns',
                ),
              ],
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(BoxPlotChart));
      expect(size.height, 260);

      final topLeft = tester.getTopLeft(find.byType(BoxPlotChart));
      final gesture = await tester.startGesture(
        topLeft + Offset(size.width - 40, size.height / 2),
      );
      await tester.pump();
      expect(touched?.entry.label, 'Reversion');
      expect(touched?.stats.outliers, [40]);
      expect(find.text('card Reversion'), findsOneWidget);

      await gesture.up();
      await tester.pump();
      expect(touched, isNull);
    });

    testWidgets('grows in and survives its data changing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BoxPlotChart(
              entries: const [BoxPlotEntry(stats: _stats)],
              animationDuration: const Duration(milliseconds: 200),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BoxPlotChart(
              entries: [
                BoxPlotEntry.fromSamples(const [1, 2, 3]),
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
