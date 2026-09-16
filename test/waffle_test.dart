import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

const _slices = [
  WaffleSlice(label: 'Crypto', value: 45, color: Color(0xFF4C86CD)),
  WaffleSlice(label: 'Equities', value: 35, color: Color(0xFF2F9E44)),
  WaffleSlice(label: 'Cash', value: 20, color: Color(0xFF909196)),
];

void main() {
  group('the counts', () {
    test('shares out every cell, and no more', () {
      final counts = waffleCounts(_slices);
      expect(counts, [45, 35, 20]);
      expect(counts.fold<int>(0, (a, b) => a + b), 100);
    });

    test('the largest remainders get the spare cells', () {
      const thirds = [
        WaffleSlice(label: 'a', value: 1, color: Color(0xFF000000)),
        WaffleSlice(label: 'b', value: 1, color: Color(0xFF000000)),
        WaffleSlice(label: 'c', value: 1, color: Color(0xFF000000)),
      ];
      final counts = waffleCounts(thirds);
      expect(counts.fold<int>(0, (a, b) => a + b), 100);
      // 33.33 each: two slices round up, none is more than a cell out.
      expect(counts.every((c) => c == 33 || c == 34), true);
    });

    test('a given total leaves the rest of the grid empty', () {
      final counts = waffleCounts(
        const [WaffleSlice(label: 'a', value: 30, color: Color(0xFF000000))],
        total: 100,
      );
      expect(counts, [30]);
    });

    test('a total under the real sum never overfills the grid', () {
      final counts = waffleCounts(_slices, total: 50);
      expect(counts.fold<int>(0, (a, b) => a + b), lessThanOrEqualTo(100));
    });

    test('negatives and nothing at all count as zero', () {
      expect(
        waffleCounts(const [
          WaffleSlice(label: 'a', value: -5, color: Color(0xFF000000)),
        ]),
        [0],
      );
      expect(waffleCounts(const []), isEmpty);
    });
  });

  group('the layout', () {
    test('cells are square and fill from the bottom left', () {
      final layout = layOutWaffle(
        const [10],
        size: const Size(200, 200),
        columns: 10,
        rows: 10,
      );
      expect(layout.cells, hasLength(100));
      expect(
          layout.cells.first.width, closeTo(layout.cells.first.height, 1e-9));
      // The first ten cells are the bottom row.
      for (var i = 0; i < 10; i++) {
        expect(layout.owners[i], 0);
        expect(layout.cells[i].bottom, closeTo(layout.cells[0].bottom, 1e-9));
      }
      expect(layout.owners[10], -1);
    });

    test('filling from the top runs the other way', () {
      final layout = layOutWaffle(
        const [10],
        size: const Size(200, 200),
        rows: 10,
        fill: WaffleFill.topRowsDown,
      );
      expect(layout.cells.first.top, lessThan(layout.cells.last.top));
    });

    test('slices take their cells in order', () {
      final layout = layOutWaffle(
        waffleCounts(_slices),
        size: const Size(200, 200),
        rows: 10,
      );
      expect(layout.owners.where((o) => o == 0), hasLength(45));
      expect(layout.owners.where((o) => o == 1), hasLength(35));
      expect(layout.owners.where((o) => o == 2), hasLength(20));
    });

    test('progress fills only the first part of the cells', () {
      final layout = layOutWaffle(
        waffleCounts(_slices),
        size: const Size(200, 200),
        rows: 10,
        progress: 0.5,
      );
      expect(layout.owners.where((o) => o >= 0), hasLength(50));
    });

    test('nothing to show lays out nothing', () {
      expect(layOutWaffle(const [10], size: Size.zero).isEmpty, true);
      expect(
          layOutWaffle(const [10], size: const Size(200, 200), columns: 0)
              .isEmpty,
          true);
    });

    test('a point finds the slice under it, and nothing in a gap', () {
      final layout = layOutWaffle(
        waffleCounts(_slices),
        size: const Size(200, 200),
        rows: 10,
      );
      expect(layout.sliceAt(layout.cells.first.center), 0);
      expect(layout.sliceAt(const Offset(-5, -5)), isNull);
    });
  });

  group('the widget', () {
    testWidgets('draws and reports the slice under the finger', (tester) async {
      WaffleSlice? touched;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 220,
              height: 220,
              child: WaffleChart(
                slices: _slices,
                onSliceTap: (slice) => touched = slice ?? touched,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(WaffleChart), findsOneWidget);

      final box = tester.getRect(find.byType(WaffleChart));
      final gesture = await tester.startGesture(
        Offset(box.left + 12, box.bottom - 12),
      );
      await tester.pump();
      expect(touched?.label, 'Crypto');
      await gesture.up();
      await tester.pump();
    });

    testWidgets('takes its default size in an unbounded box', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WaffleChart(slices: _slices, defaultSize: 180),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(WaffleChart)).height, 180);
    });

    testWidgets('fills the cells in over time', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 220,
              height: 220,
              child: WaffleChart(
                slices: _slices,
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
