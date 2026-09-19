import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

const _bounds = Rect.fromLTWH(0, 0, 200, 300);

final _snapshots = [
  BookSnapshot(
    time: DateTime(2024),
    mid: 100.5,
    levels: const [
      BookLevel(price: 100, size: 40, side: BookSide.bid),
      BookLevel(price: 101, size: 10, side: BookSide.ask),
    ],
  ),
  BookSnapshot(
    time: DateTime(2024, 1, 1, 0, 1),
    mid: 100.5,
    levels: const [
      BookLevel(price: 100, size: 5, side: BookSide.bid),
      BookLevel(price: 101, size: 80, side: BookSide.ask),
    ],
  ),
];

void main() {
  group('the layout', () {
    test('snapshots take a column each', () {
      final layout = layOutBookHeatmap(_snapshots, _bounds, tickSize: 1);
      expect(layout.columns.length, 2);
      expect(layout.columns.first.rect.width, 100);
      expect(layout.columns.last.rect.left, 100);
    });

    test('a row is one tick tall and prices run up the plot', () {
      final layout = layOutBookHeatmap(_snapshots, _bounds, tickSize: 1);
      // 99.5 to 101.5: two ticks over 300px.
      expect(layout.rowHeight, 150);
      expect(layout.yOf(100), 225);
      expect(layout.yOf(101), 75);
      expect(layout.priceAt(225), closeTo(100, 1e-9));
    });

    test('the largest resting size is what the shading is read against', () {
      final layout = layOutBookHeatmap(_snapshots, _bounds, tickSize: 1);
      expect(layout.largestSize, 80);
      final fixed = layOutBookHeatmap(
        _snapshots,
        _bounds,
        tickSize: 1,
        largestSize: 1000,
      );
      expect(fixed.largestSize, 1000);
    });

    test('the mid is placed for the columns that carry one', () {
      final layout = layOutBookHeatmap(_snapshots, _bounds, tickSize: 1);
      expect(layout.columns.first.midY, 150);
      final noMid = layOutBookHeatmap(
        [
          BookSnapshot(
            time: DateTime(2024),
            levels: const [BookLevel(price: 1, size: 1, side: BookSide.bid)],
          ),
        ],
        _bounds,
        tickSize: 1,
      );
      expect(noMid.columns.single.midY, isNull);
    });

    test('the price range covers every level', () {
      expect(bookPriceRange(_snapshots), (min: 100.0, max: 101.0));
      expect(bookPriceRange(const []), (min: 0.0, max: 1.0));
    });

    test('nothing to show, no room, or no tick lays out nothing', () {
      expect(layOutBookHeatmap(const [], _bounds, tickSize: 1).isEmpty, isTrue);
      expect(
        layOutBookHeatmap(_snapshots, Rect.zero, tickSize: 1).isEmpty,
        isTrue,
      );
      expect(
        layOutBookHeatmap(_snapshots, _bounds, tickSize: 0).isEmpty,
        isTrue,
      );
    });

    test('a point in a cell finds it', () {
      final layout = layOutBookHeatmap(_snapshots, _bounds, tickSize: 1);
      final cell = bookHeatmapCellAt(layout, const Offset(150, 75));
      expect(cell?.level.price, 101);
      expect(cell?.level.size, 80);
      expect(
        bookHeatmapCellAt(layout, const Offset(150, 299))?.level.price,
        100,
      );
    });
  });

  group('the widget', () {
    testWidgets('draws, reports touches and takes its default height', (
      tester,
    ) async {
      BookHeatmapTouchDetails? touched;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                BookHeatmapChart(
                  snapshots: _snapshots,
                  tickSize: 1,
                  onTouch: (d) => touched = d,
                  tooltipBuilder: (context, d) =>
                      Text('card ${d.cell?.level.size ?? 0}'),
                  semanticLabel: 'Order book',
                ),
              ],
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(BookHeatmapChart));
      expect(size.height, 320);

      final topLeft = tester.getTopLeft(find.byType(BookHeatmapChart));
      final gesture = await tester.startGesture(
        topLeft + Offset(56 + (size.width - 56) * 0.75, size.height * 0.25),
      );
      await tester.pump();
      expect(touched?.cell?.level.price, 101);
      expect(touched?.snapshot.time, DateTime(2024, 1, 1, 0, 1));
      expect(find.text('card 80.0'), findsOneWidget);

      await gesture.up();
      await tester.pump();
      expect(touched, isNull);
    });

    testWidgets('survives its data changing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookHeatmapChart(snapshots: _snapshots, tickSize: 1),
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookHeatmapChart(
              snapshots: [_snapshots.first],
              tickSize: 0.5,
              showMid: false,
              showPriceAxis: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
