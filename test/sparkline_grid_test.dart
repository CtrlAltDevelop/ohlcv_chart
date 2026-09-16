import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

const _tiles = [
  SparklineTile(label: 'BTC', values: [10, 12, 11, 16]),
  SparklineTile(label: 'ETH', values: [8, 6, 7, 4]),
  SparklineTile(label: 'SOL', values: [3, 5, 4, 5]),
];

void main() {
  group('a tile', () {
    test('knows its ends, its move and which way it went', () {
      expect(_tiles[0].first, 10);
      expect(_tiles[0].last, 16);
      expect(_tiles[0].change, closeTo(0.6, 1e-9));
      expect(_tiles[0].rose, true);
      expect(_tiles[1].rose, false);
    });

    test('non-finite values are skipped at both ends', () {
      const tile = SparklineTile(
        label: 'x',
        values: [double.nan, 4, double.infinity, 6, double.nan],
      );
      expect(tile.first, 4);
      expect(tile.last, 6);
    });

    test('a tile with nothing in it has no ends and no move', () {
      const tile = SparklineTile(label: 'x', values: []);
      expect(tile.first, isNull);
      expect(tile.change, isNull);
      expect(tile.rose, true);
    });
  });

  group('the layout', () {
    test('tiles fill left to right and then down', () {
      final layout = layOutSparklineGrid(
        _tiles,
        size: const Size(400, 200),
        columns: 2,
        tileHeight: 40,
        tileGap: 10,
      );
      expect(layout.columns, 2);
      expect(layout.rows, 2);
      expect(layout.tiles[0].rect.left, 0);
      expect(layout.tiles[1].rect.left, closeTo(205, 1e-9));
      expect(layout.tiles[2].rect.top, closeTo(50, 1e-9));
      expect(layout.tiles[2].rect.left, 0);
    });

    test('a tile is scaled to its own series by default', () {
      final layout = layOutSparklineGrid(
        _tiles,
        size: const Size(400, 200),
        columns: 1,
      );
      expect(layout.tiles[0].min, 10);
      expect(layout.tiles[0].max, 16);
      expect(layout.tiles[1].min, 4);
      expect(layout.tiles[1].max, 8);
      // Each line touches the top and the bottom of its own tile.
      expect(
        layout.tiles[1].points.first!.dy,
        closeTo(layout.tiles[1].sparkRect.top, 1e-9),
      );
    });

    test('a shared scale puts every tile on the same one', () {
      final layout = layOutSparklineGrid(
        _tiles,
        size: const Size(400, 200),
        columns: 1,
        sharedScale: true,
      );
      expect(layout.tiles[0].min, 3);
      expect(layout.tiles[0].max, 16);
      expect(layout.tiles[1].min, 3);
      expect(layout.tiles[2].max, 16);
    });

    test('a flat line sits in the middle of its tile', () {
      final layout = layOutSparklineGrid(
        const [
          SparklineTile(label: 'x', values: [5, 5, 5])
        ],
        size: const Size(400, 200),
      );
      final laid = layout.tiles.single;
      expect(
        laid.points.first!.dy,
        closeTo(laid.sparkRect.center.dy, 1e-6),
      );
    });

    test('a break in the values is a break in the line', () {
      final layout = layOutSparklineGrid(
        const [
          SparklineTile(label: 'x', values: [1, double.nan, 3])
        ],
        size: const Size(400, 200),
      );
      expect(layout.tiles.single.points[1], isNull);
      expect(layout.tiles.single.lastPoint, layout.tiles.single.points[2]);
    });

    test('progress reveals each line left to right', () {
      final layout = layOutSparklineGrid(
        _tiles,
        size: const Size(400, 200),
        progress: 0.5,
      );
      expect(layout.tiles.first.points[0], isNotNull);
      expect(layout.tiles.first.points[3], isNull);
    });

    test('nothing to show lays out nothing', () {
      expect(
        layOutSparklineGrid(const [], size: const Size(400, 200)).isEmpty,
        true,
      );
      expect(layOutSparklineGrid(_tiles, size: Size.zero).isEmpty, true);
      expect(
        layOutSparklineGrid(_tiles, size: const Size(400, 200), columns: 0)
            .isEmpty,
        true,
      );
    });

    test('a point finds the tile and where in its series it fell', () {
      final layout = layOutSparklineGrid(
        _tiles,
        size: const Size(400, 200),
        columns: 1,
        tileHeight: 40,
        tileGap: 0,
      );
      final tile = layout.tileAt(const Offset(200, 20));
      expect(tile?.index, 0);
      expect(layout.sampleAt(tile!, Offset(tile.sparkRect.left, 20)), 0);
      expect(layout.sampleAt(tile, Offset(tile.sparkRect.right, 20)), 3);
      expect(layout.tileAt(const Offset(200, 500)), isNull);
    });
  });

  group('the widget', () {
    testWidgets('draws and reports the tile under the finger', (tester) async {
      SparklineTile? touched;
      int? sample;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 200,
              child: SparklineGrid(
                tiles: _tiles,
                tileHeight: 40,
                tileGap: 0,
                onTileTap: (tile, at) {
                  touched = tile ?? touched;
                  sample = at ?? sample;
                },
              ),
            ),
          ),
        ),
      );
      expect(find.byType(SparklineGrid), findsOneWidget);

      final box = tester.getRect(find.byType(SparklineGrid));
      final gesture = await tester.startGesture(
        Offset(box.right - 60, box.top + 60),
      );
      await tester.pump();
      expect(touched?.label, 'ETH');
      expect(sample, isNotNull);
      await gesture.up();
      await tester.pump();
    });

    testWidgets('takes its own height in an unbounded box', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SparklineGrid(
                tiles: _tiles,
                columns: 1,
                tileHeight: 40,
                tileGap: 10,
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(SparklineGrid)).height, 140);
    });

    testWidgets('draws the lines in over time', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 200,
              child: SparklineGrid(
                tiles: _tiles,
                showBaseline: true,
                tileColor: Color(0x11FFFFFF),
                animationDuration: Duration(milliseconds: 200),
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
