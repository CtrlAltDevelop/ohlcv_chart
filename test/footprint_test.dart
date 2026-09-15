import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

const _bounds = Rect.fromLTWH(0, 0, 200, 300);

final _bars = [
  FootprintBar(
    time: DateTime(2024),
    open: 100,
    close: 101,
    levels: const [
      FootprintLevel(price: 100, bidVolume: 30, askVolume: 10),
      FootprintLevel(price: 101, bidVolume: 5, askVolume: 45),
    ],
  ),
  FootprintBar(
    time: DateTime(2024, 1, 1, 0, 1),
    open: 101,
    close: 100,
    levels: const [
      FootprintLevel(price: 100, bidVolume: 20, askVolume: 20),
      FootprintLevel(price: 101, bidVolume: 10, askVolume: 5),
    ],
  ),
];

void main() {
  group('the numbers', () {
    test('a level knows its total, its delta and how lopsided it was', () {
      const level = FootprintLevel(price: 1, bidVolume: 30, askVolume: 10);
      expect(level.total, 40);
      expect(level.delta, -20);
      expect(level.imbalance, -0.5);
      expect(const FootprintLevel(price: 1).imbalance, 0);
    });

    test('a bar adds its levels up and knows its busiest price', () {
      expect(_bars.first.volume, 90);
      expect(_bars.first.delta, 20);
      expect(_bars.first.pointOfControl, 101);
      expect(_bars.last.pointOfControl, 100);
    });

    test('the cumulative delta runs across the bars', () {
      expect(footprintCumulativeDelta(_bars), [20, 15]);
      expect(footprintCumulativeDelta(const []), isEmpty);
    });

    test('a bar without a high or low takes its levels', () {
      final bar = FootprintBar(
        time: DateTime(2024),
        levels: const [
          FootprintLevel(price: 5),
          FootprintLevel(price: 9),
        ],
      );
      expect(bar.bottom, 5);
      expect(bar.top, 9);
    });

    test('the price range covers every bar', () {
      final range = footprintPriceRange(_bars);
      expect(range.min, 100);
      expect(range.max, 101);
      expect(footprintPriceRange(const []), (min: 0.0, max: 1.0));
    });
  });

  group('the layout', () {
    test('bars take a column each, spacing taken off the cells', () {
      final layout =
          layOutFootprint(_bars, _bounds, tickSize: 1, barSpacing: 10);
      expect(layout.columns.length, 2);
      expect(layout.columns.first.rect.width, 100);
      expect(layout.columns.first.cells.first.rect.left, 5);
      expect(layout.columns.first.cells.first.rect.width, 90);
    });

    test('a row is one tick tall and prices run up the plot', () {
      final layout = layOutFootprint(_bars, _bounds, tickSize: 1);
      // The range is 99.5 to 101.5: two ticks over 300px.
      expect(layout.rowHeight, 150);
      expect(layout.yOf(100), 225);
      expect(layout.yOf(101), 75);
    });

    test('the busiest level anywhere is what shading is read against', () {
      final layout = layOutFootprint(_bars, _bounds, tickSize: 1);
      expect(layout.largestVolume, 50);
    });

    test('a cell splits into a bid half and an ask half', () {
      final layout = layOutFootprint(_bars, _bounds, tickSize: 1);
      final cell = layout.columns.first.cells.first;
      expect(cell.bidRect.right, cell.rect.center.dx);
      expect(cell.askRect.left, cell.rect.center.dx);
    });

    test('candles are placed when the bar has an open and a close', () {
      final layout = layOutFootprint(_bars, _bounds, tickSize: 1);
      expect(layout.columns.first.openY, 225);
      expect(layout.columns.first.closeY, 75);
      final noCandle = layOutFootprint(
        [FootprintBar(time: DateTime(2024), levels: const [
          FootprintLevel(price: 100, askVolume: 1),
        ])],
        _bounds,
        tickSize: 1,
      );
      expect(noCandle.columns.single.openY, isNull);
    });

    test('nothing to show, no room, or no tick lays out nothing', () {
      expect(layOutFootprint(const [], _bounds, tickSize: 1).isEmpty, isTrue);
      expect(layOutFootprint(_bars, Rect.zero, tickSize: 1).isEmpty, isTrue);
      expect(layOutFootprint(_bars, _bounds, tickSize: 0).isEmpty, isTrue);
    });

    test('a point in a cell finds it, and the gaps find nothing', () {
      final layout =
          layOutFootprint(_bars, _bounds, tickSize: 1, barSpacing: 10);
      final cell = layout.columns.last.cells.first;
      expect(
        footprintCellAt(layout, cell.rect.center)?.level.price,
        100,
      );
      // The gap between two columns belongs to neither.
      expect(footprintCellAt(layout, const Offset(97, 150)), isNull);
    });
  });

  group('the widget', () {
    testWidgets('draws, reports touches and takes its default height',
        (tester) async {
      FootprintTouchDetails? touched;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                FootprintChart(
                  bars: _bars,
                  tickSize: 1,
                  gridColor: const Color(0x22FFFFFF),
                  onTouch: (d) => touched = d,
                  tooltipBuilder: (context, d) =>
                      Text('card ${d.level.price}'),
                  semanticLabel: 'Order flow',
                ),
              ],
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(FootprintChart));
      expect(size.height, 360);

      final topLeft = tester.getTopLeft(find.byType(FootprintChart));
      final gesture = await tester.startGesture(
        topLeft + Offset(56 + (size.width - 56) / 4, size.height * 0.75),
      );
      await tester.pump();
      expect(touched?.level.price, 100);
      expect(touched?.bar.delta, 20);
      expect(find.text('card 100.0'), findsOneWidget);

      await gesture.up();
      await tester.pump();
      expect(touched, isNull);
    });

    testWidgets('survives its data changing, with numbers off', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FootprintChart(bars: _bars, tickSize: 1),
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FootprintChart(
              bars: [_bars.first],
              tickSize: 0.5,
              showNumbers: false,
              showCandles: false,
              markPointOfControl: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
