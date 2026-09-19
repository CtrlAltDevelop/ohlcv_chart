import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

const _bounds = Rect.fromLTWH(0, 0, 600, 400);

double _area(Rect r) => r.width * r.height;

void main() {
  group('the layout', () {
    test('each item takes its share of the area', () {
      final tiles = layOutTreemap(const [
        TreemapItem(value: 6),
        TreemapItem(value: 3),
        TreemapItem(value: 2),
        TreemapItem(value: 1),
      ], _bounds);

      expect(tiles, hasLength(4));
      final total = _area(_bounds);
      for (final tile in tiles) {
        expect(
          _area(tile.rect) / total,
          closeTo(tile.item.value / 12, 1e-9),
          reason: '${tile.item.value}',
        );
      }
    });

    test('the tiles fill the bounds without overlapping', () {
      final items = [for (var i = 1; i <= 12; i++) TreemapItem(value: i * 1.5)];
      final tiles = layOutTreemap(items, _bounds);

      var covered = 0.0;
      for (final tile in tiles) {
        covered += _area(tile.rect);
        expect(
          _bounds.inflate(1e-6).contains(tile.rect.topLeft) &&
              _bounds.inflate(1e-6).contains(tile.rect.bottomRight),
          isTrue,
        );
      }
      expect(covered, closeTo(_area(_bounds), 1e-6));

      for (var i = 0; i < tiles.length; i++) {
        for (var j = i + 1; j < tiles.length; j++) {
          final overlap = tiles[i].rect.intersect(tiles[j].rect);
          final shared = overlap.width > 1e-6 && overlap.height > 1e-6;
          expect(shared, isFalse, reason: 'tiles $i and $j overlap');
        }
      }
    });

    test('squarified tiles stay close to square', () {
      final tiles = layOutTreemap([
        for (var i = 0; i < 20; i++) const TreemapItem(value: 1),
      ], const Rect.fromLTWH(0, 0, 500, 400));
      for (final tile in tiles) {
        final ratio = tile.rect.longestSide / tile.rect.shortestSide;
        expect(ratio, lessThan(3), reason: '${tile.rect}');
      }
    });

    test('items worth nothing are left out', () {
      final tiles = layOutTreemap(const [
        TreemapItem(value: 5, label: 'kept'),
        TreemapItem(value: 0),
        TreemapItem(value: -3),
        TreemapItem(value: double.nan),
      ], _bounds);
      expect(tiles.map((t) => t.item.label), ['kept']);
      expect(tiles.single.rect, _bounds);
    });

    test('nothing worth anything, or no room, lays out nothing', () {
      expect(layOutTreemap(const [], _bounds), isEmpty);
      expect(layOutTreemap(const [TreemapItem(value: 0)], _bounds), isEmpty);
      expect(layOutTreemap(const [TreemapItem(value: 4)], Rect.zero), isEmpty);
    });

    test('the order given is kept when sorting is off', () {
      final tiles = layOutTreemap(
        const [
          TreemapItem(value: 1, label: 'a'),
          TreemapItem(value: 9, label: 'b'),
        ],
        _bounds,
        sort: false,
      );
      expect(tiles.map((t) => t.item.label), ['a', 'b']);
      expect(tiles.first.index, 0);
    });

    test('spacing is taken off every tile', () {
      final tiles = layOutTreemap(
        const [TreemapItem(value: 1)],
        _bounds,
        spacing: 4,
      );
      expect(tiles.single.rect, _bounds.deflate(2));
    });
  });

  group('groups', () {
    final items = [
      const TreemapItem.group(
        label: 'Tech',
        children: [
          TreemapItem(value: 4, label: 'AAPL'),
          TreemapItem(value: 2, label: 'MSFT'),
        ],
      ),
      const TreemapItem(value: 6, label: 'Cash'),
    ];

    test('a group is sized by what its children add up to', () {
      expect(items.first.total, 6);
      final tiles = layOutTreemap(items, _bounds);
      final group = tiles.firstWhere((t) => t.item.label == 'Tech');
      final cash = tiles.firstWhere((t) => t.item.label == 'Cash');
      expect(_area(group.rect), closeTo(_area(cash.rect), 1e-6));
    });

    test('children come after their group and sit under its header', () {
      final tiles = layOutTreemap(items, _bounds, groupHeaderHeight: 20);
      final groupAt = tiles.indexWhere((t) => t.item.label == 'Tech');
      final group = tiles[groupAt];
      final children = tiles.where((t) => t.parent == group).toList();

      expect(children, hasLength(2));
      expect(group.headerRect, isNotNull);
      for (final child in children) {
        expect(tiles.indexOf(child), greaterThan(groupAt));
        expect(child.depth, 1);
        expect(child.root, same(group));
        expect(child.rect.top, greaterThanOrEqualTo(group.headerRect!.bottom));
        expect(
          group.rect.inflate(1e-6).contains(child.rect.bottomRight),
          isTrue,
        );
      }
    });

    test('a group too short for a header gives it up', () {
      final tiles = layOutTreemap(
        items,
        const Rect.fromLTWH(0, 0, 600, 30),
        groupHeaderHeight: 20,
      );
      final group = tiles.firstWhere((t) => t.item.label == 'Tech');
      expect(group.headerRect, isNull);
    });

    test('a touch finds the leaf, never the group around it', () {
      final tiles = layOutTreemap(items, _bounds, groupHeaderHeight: 20);
      final aapl = tiles.firstWhere((t) => t.item.label == 'AAPL');
      expect(treemapTileAt(tiles, aapl.rect.center), same(aapl));

      final group = tiles.firstWhere((t) => t.item.label == 'Tech');
      expect(treemapTileAt(tiles, group.headerRect!.center), isNull);
      expect(treemapTileAt(tiles, const Offset(-5, -5)), isNull);
    });
  });

  group('the widget', () {
    Widget host(Widget chart) => MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 400, height: 300, child: chart)),
      ),
    );

    testWidgets('draws, and draws nothing without a fuss', (tester) async {
      for (final items in [
        const <TreemapItem>[],
        const [TreemapItem(value: 0)],
        const [
          TreemapItem(value: 3, label: 'A', colorValue: 2),
          TreemapItem.group(
            label: 'G',
            children: [TreemapItem(value: 1, label: 'B', colorValue: -1)],
          ),
        ],
      ]) {
        await tester.pumpWidget(
          host(
            TreemapChart(
              items: items,
              scale: const HeatmapGradientScale(
                colors: [Color(0xFFE03131), Color(0xFF2F9E44)],
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('a touch reports the leaf and shows its card', (tester) async {
      TreemapTouchDetails? reported;
      await tester.pumpWidget(
        host(
          TreemapChart(
            items: const [TreemapItem(value: 1, label: 'only', data: 42)],
            onTouch: (d) => reported = d,
            tooltipBuilder: (context, d) => Text('card ${d.item.label}'),
          ),
        ),
      );

      final centre = tester.getCenter(find.byType(TreemapChart));
      final gesture = await tester.startGesture(centre);
      await tester.pump();

      expect(reported?.item.data, 42);
      expect(find.text('card only'), findsOneWidget);

      await gesture.up();
      await tester.pump();
      expect(reported, isNull);
      expect(find.text('card only'), findsNothing);
    });

    testWidgets('grows in when asked, and settles', (tester) async {
      await tester.pumpWidget(
        host(
          const TreemapChart(
            items: [TreemapItem(value: 1), TreemapItem(value: 2)],
            animationDuration: Duration(milliseconds: 300),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
