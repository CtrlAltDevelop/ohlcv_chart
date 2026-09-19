import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

const _levels = [
  LiquidityLevel(price: 60000, size: 20, side: LiquiditySide.long),
  LiquidityLevel(price: 62000, size: 50, side: LiquiditySide.long),
  LiquidityLevel(price: 72000, size: 30, side: LiquiditySide.short),
  LiquidityLevel(price: 76000, size: 10, side: LiquiditySide.short),
];

void main() {
  group('the bins', () {
    test('sides are counted apart, in the bucket they fall in', () {
      final bins = liquidityBins(_levels, binCount: 4, min: 60000, max: 80000);
      expect(bins, hasLength(4));
      expect(bins[0].longSize, 70); // 60,000 and 62,000
      expect(bins[0].shortSize, 0);
      expect(bins[2].shortSize, 30); // 72,000
      expect(bins[3].shortSize, 10); // 76,000
    });

    test('the top price lands in the last bucket, not past the end', () {
      final bins = liquidityBins(
        const [LiquidityLevel(price: 100, size: 5, side: LiquiditySide.short)],
        binCount: 4,
        min: 0,
        max: 100,
      );
      expect(bins.last.shortSize, 5);
    });

    test('a bucket knows its total and which side owns it', () {
      final bins = liquidityBins(_levels, binCount: 4, min: 60000, max: 80000);
      expect(bins[0].total, 70);
      expect(bins[0].imbalance, -1);
      expect(bins[2].imbalance, 1);
      expect(bins[1].imbalance, 0);
      expect(bins[0].mid, 62500);
    });

    test('bounds default to the levels, with a little air', () {
      final bins = liquidityBins(_levels, binCount: 10);
      expect(bins.first.from, lessThan(60000));
      expect(bins.last.to, greaterThan(76000));
    });

    test('negatives and nonsense count as nothing', () {
      expect(
        liquidityBins(const [
          LiquidityLevel(price: 10, size: -5, side: LiquiditySide.long),
        ]),
        isEmpty,
      );
      expect(liquidityBins(const []), isEmpty);
    });
  });

  group('the layout', () {
    final bins = liquidityBins(_levels, binCount: 4, min: 60000, max: 80000);

    test('the lowest price is at the bottom of the plot', () {
      final layout = layOutLiquidityMap(
        bins,
        size: const Size(400, 200),
        axisWidth: 0,
      );
      expect(layout.min, 60000);
      expect(layout.max, 80000);
      expect(layout.bins.first.rowRect.bottom, closeTo(200, 1e-9));
      expect(layout.bins.last.rowRect.top, closeTo(0, 1e-9));
      expect(layout.yOf(80000), closeTo(0, 1e-9));
    });

    test('longs grow in from the left and shorts from the right', () {
      final layout = layOutLiquidityMap(
        bins,
        size: const Size(400, 200),
        axisWidth: 0,
        barGap: 0,
      );
      final middle = layout.plotRect.center.dx;
      expect(layout.bins[0].longRect.right, closeTo(middle, 1e-9));
      expect(layout.bins[0].longRect.left, lessThan(middle));
      expect(layout.bins[2].shortRect.left, closeTo(middle, 1e-9));
      expect(layout.bins[2].shortRect.right, greaterThan(middle));
    });

    test('bars are scaled to the largest bucket', () {
      final layout = layOutLiquidityMap(
        bins,
        size: const Size(400, 200),
        axisWidth: 0,
      );
      expect(layout.largest, 70);
      // The largest bucket fills its half of the plot.
      expect(layout.bins[0].longRect.width, closeTo(200, 1e-9));
      expect(layout.bins[2].shortRect.width, closeTo(200 * 30 / 70, 1e-9));
    });

    test('a given scale pins the bars across reloads', () {
      final layout = layOutLiquidityMap(
        bins,
        size: const Size(400, 200),
        axisWidth: 0,
        largest: 140,
      );
      expect(layout.bins[0].longRect.width, closeTo(100, 1e-9));
    });

    test('the current price is placed, and remembered', () {
      final layout = layOutLiquidityMap(
        bins,
        size: const Size(400, 200),
        axisWidth: 0,
        currentPrice: 70000,
      );
      expect(layout.currentPrice, 70000);
      expect(layout.priceY, closeTo(100, 1e-9));
    });

    test('exposure counts what a move that far would set off', () {
      final layout = layOutLiquidityMap(
        bins,
        size: const Size(400, 200),
        currentPrice: 70000,
      );
      // Down to 61,000 sets off the longs below; up to 78,000 both short
      // buckets, one of which sits at 77,500.
      expect(layout.exposureTo(61000), 70);
      expect(layout.exposureTo(78000), 40);
      expect(layout.exposureTo(77000), 30);
      // Nothing is counted the wrong side of the market.
      expect(layout.exposureTo(70000), 0);
    });

    test('with no current price there is no exposure to report', () {
      final layout = layOutLiquidityMap(bins, size: const Size(400, 200));
      expect(layout.currentPrice, isNull);
      expect(layout.exposureTo(61000), 0);
    });

    test('progress grows the bars in', () {
      final half = layOutLiquidityMap(
        bins,
        size: const Size(400, 200),
        axisWidth: 0,
        progress: 0.5,
      );
      expect(half.bins[0].longRect.width, closeTo(100, 1e-9));
    });

    test('nothing to show lays out nothing', () {
      expect(
        layOutLiquidityMap(const [], size: const Size(400, 200)).isEmpty,
        true,
      );
      expect(layOutLiquidityMap(bins, size: Size.zero).isEmpty, true);
    });

    test('a point finds the bucket it is over', () {
      final layout = layOutLiquidityMap(
        bins,
        size: const Size(400, 200),
        axisWidth: 0,
      );
      expect(layout.binAt(const Offset(200, 190))?.index, 0);
      expect(layout.binAt(const Offset(200, 10))?.index, 3);
      expect(layout.binAt(const Offset(200, 400)), isNull);
    });
  });

  group('the widget', () {
    testWidgets('draws and reports the bucket under the finger', (
      tester,
    ) async {
      LiquidityBin? touched;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 200,
              child: LiquidityMapChart(
                bins: liquidityBins(
                  _levels,
                  binCount: 4,
                  min: 60000,
                  max: 80000,
                ),
                currentPrice: 70000,
                onBinTap: (bin) => touched = bin ?? touched,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(LiquidityMapChart), findsOneWidget);

      final box = tester.getRect(find.byType(LiquidityMapChart));
      final gesture = await tester.startGesture(
        Offset(box.center.dx, box.bottom - 10),
      );
      await tester.pump();
      expect(touched?.longSize, 70);
      await gesture.up();
      await tester.pump();
    });

    testWidgets('takes its default height in an unbounded box', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LiquidityMapChart(
                bins: liquidityBins(_levels, binCount: 8),
                defaultHeight: 200,
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(LiquidityMapChart)).height, 200);
    });

    testWidgets('grows the bars in over time', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 200,
              child: LiquidityMapChart(
                bins: liquidityBins(_levels, binCount: 8),
                animationDuration: const Duration(milliseconds: 200),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
