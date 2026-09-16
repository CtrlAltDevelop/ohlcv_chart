import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

const _bounds = Rect.fromLTWH(0, 0, 400, 100);

void main() {
  group('binning', () {
    test('samples are counted into bins of equal width', () {
      final bins = histogramBins(
        const [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
        binCount: 2,
      );
      expect(bins.map((b) => b.from), [0, 5]);
      expect(bins.map((b) => b.to), [5, 10]);
      // A sample on a boundary goes up; the last bin keeps its upper edge.
      expect(bins.map((b) => b.count), [5, 6]);
    });

    test('binWidth sets the width and the range grows to fit whole bins', () {
      final bins = histogramBins(const [0, 1, 2, 7], binWidth: 3);
      expect(bins.length, 3);
      expect(bins.last.to, 9);
      expect(bins.map((b) => b.count), [3, 0, 1]);
    });

    test('an explicit range drops what falls outside it', () {
      final bins = histogramBins(
        const [-5, 1, 2, 50],
        binCount: 2,
        min: 0,
        max: 4,
      );
      expect(bins.map((b) => b.count), [1, 1]);
    });

    test('with neither count nor width, the square-root rule is used', () {
      final bins = histogramBins(List.filled(16, 1.0).toList());
      expect(bins.length, 4);
    });

    test('identical samples still make a bin around them', () {
      final bins = histogramBins(const [3, 3, 3], binCount: 1);
      expect(bins.single.from, 2.5);
      expect(bins.single.to, 3.5);
      expect(bins.single.count, 3);
    });

    test(
        'values that are not numbers are left out, and nothing bins to nothing',
        () {
      expect(histogramBins(const [double.nan, double.infinity]), isEmpty);
      expect(histogramBins(const []), isEmpty);
    });
  });

  group('the layout', () {
    final bins = histogramBins(const [0, 1, 2, 3], binCount: 4);

    test('bars sit where their range falls, spacing taken off', () {
      final bars = layOutHistogram(bins, _bounds, maxCount: 1, barSpacing: 0);
      expect(bars.map((b) => b.rect.left), [0, 100, 200, 300]);
      expect(bars.map((b) => b.rect.width), [100, 100, 100, 100]);
      final spaced = layOutHistogram(bins, _bounds, maxCount: 1, barSpacing: 5);
      expect(spaced.first.rect.left, 5);
      expect(spaced.first.rect.width, 90);
      expect(spaced.first.band.width, 100);
    });

    test('bar height is the count against the tallest', () {
      final bars = layOutHistogram(bins, _bounds, maxCount: 2);
      expect(bars.first.rect.height, 50);
      expect(bars.first.rect.bottom, 100);
    });

    test('a count past the top is clamped, and no counts draw flat', () {
      final bars = layOutHistogram(bins, _bounds, maxCount: 0.5);
      expect(bars.first.rect.height, 100);
      expect(
        layOutHistogram(bins, _bounds, maxCount: 0).first.rect.height,
        0,
      );
    });

    test('nothing to show, or no room, lays out nothing', () {
      expect(layOutHistogram(const [], _bounds, maxCount: 1), isEmpty);
      expect(layOutHistogram(bins, Rect.zero, maxCount: 1), isEmpty);
    });

    test('a point in a column finds its bar', () {
      final bars = layOutHistogram(bins, _bounds, maxCount: 1);
      expect(histogramBarAt(bars, const Offset(250, 10))?.index, 2);
      expect(histogramBarAt(bars, const Offset(250, 500)), isNull);
    });
  });

  group('the widget', () {
    testWidgets('draws, reports touches and takes its default height',
        (tester) async {
      HistogramTouchDetails? touched;
      final bins = histogramBins(const [-2, -1, 0, 1, 2, 2], binCount: 4);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                HistogramChart(
                  bins: bins,
                  negativeColor: Colors.red,
                  referenceLines: const [0],
                  onTouch: (d) => touched = d,
                  tooltipBuilder: (context, d) => Text('card ${d.bin.count}'),
                  semanticLabel: 'Returns',
                ),
              ],
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(HistogramChart));
      expect(size.height, 220);

      final topLeft = tester.getTopLeft(find.byType(HistogramChart));
      final gesture = await tester.startGesture(
        topLeft + Offset(size.width - 20, size.height / 2),
      );
      await tester.pump();
      expect(touched?.bin.count, 3);
      expect(find.text('card 3.0'), findsOneWidget);

      await gesture.up();
      await tester.pump();
      expect(touched, isNull);
    });

    testWidgets('grows in and survives its data changing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistogramChart(
              bins: histogramBins(const [1, 2, 3, 4], binCount: 3),
              animationDuration: const Duration(milliseconds: 200),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistogramChart(
              bins: histogramBins(const [5, 6], binCount: 2),
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
