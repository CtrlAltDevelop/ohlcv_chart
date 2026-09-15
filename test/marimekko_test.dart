import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

const _columns = [
  MarimekkoColumn(
    label: 'Spot',
    cells: [
      MarimekkoCell(label: 'BTC', value: 60),
      MarimekkoCell(label: 'ETH', value: 40),
    ],
  ),
  MarimekkoColumn(
    label: 'Perps',
    cells: [
      MarimekkoCell(label: 'BTC', value: 150),
      MarimekkoCell(label: 'ETH', value: 50),
    ],
  ),
];

void main() {
  group('a column', () {
    test('is as wide as its cells add up to', () {
      expect(_columns[0].total, 100);
      expect(_columns[0].drawnWidth, 100);
    });

    test('a width of its own wins over the sum', () {
      const column = MarimekkoColumn(
        label: 'x',
        width: 7,
        cells: [MarimekkoCell(label: 'a', value: 100)],
      );
      expect(column.drawnWidth, 7);
    });

    test('negatives and nonsense count as nothing', () {
      const column = MarimekkoColumn(
        label: 'x',
        cells: [
          MarimekkoCell(label: 'a', value: -5),
          MarimekkoCell(label: 'b', value: double.nan),
          MarimekkoCell(label: 'c', value: 3),
        ],
      );
      expect(column.total, 3);
    });
  });

  group('the layout', () {
    test('columns take the width they are worth', () {
      final layout = layOutMarimekko(
        _columns,
        size: const Size(300, 200),
        columnGap: 0,
      );
      // 100 and 200 of 300: a third and two thirds.
      expect(layout.columns[0].widthShare, closeTo(1 / 3, 1e-9));
      expect(layout.columns[0].rect.width, closeTo(100, 1e-9));
      expect(layout.columns[1].rect.width, closeTo(200, 1e-9));
      expect(layout.columns[1].rect.right, closeTo(300, 1e-9));
    });

    test('the gaps come out before the columns share the rest', () {
      final layout = layOutMarimekko(
        _columns,
        size: const Size(302, 200),
        columnGap: 2,
      );
      final total = layout.columns.fold<double>(0, (a, b) => a + b.rect.width);
      expect(total, closeTo(300, 1e-9));
      expect(layout.columns[0].widthShare, closeTo(1 / 3, 1e-9));
    });

    test('every column is the full height, split by its own shares', () {
      final layout = layOutMarimekko(
        _columns,
        size: const Size(300, 200),
        cellGap: 0,
      );
      for (final column in layout.columns) {
        expect(column.rect.height, 200);
      }
      // Spot is 60/40; Perps is 75/25.
      expect(layout.columns[0].cells[0].share, closeTo(0.6, 1e-9));
      expect(layout.columns[0].cells[0].rect.height, closeTo(120, 1e-9));
      expect(layout.columns[1].cells[0].share, closeTo(0.75, 1e-9));
    });

    test('cells stack up from the bottom in the order given', () {
      final layout = layOutMarimekko(
        _columns,
        size: const Size(300, 200),
        cellGap: 0,
      );
      final cells = layout.columns[0].cells;
      expect(cells[0].rect.bottom, closeTo(200, 1e-9));
      expect(cells[1].rect.bottom, closeTo(cells[0].rect.top, 1e-9));
      expect(cells[1].rect.top, closeTo(0, 1e-9));
    });

    test('the same label is the same category across columns', () {
      final layout = layOutMarimekko(_columns, size: const Size(300, 200));
      expect(layout.categories, ['BTC', 'ETH']);
      expect(layout.columns[0].cells[0].category,
          layout.columns[1].cells[0].category);
    });

    test('the header takes its room off the top', () {
      final layout = layOutMarimekko(
        _columns,
        size: const Size(300, 200),
        headerHeight: 20,
      );
      expect(layout.plotRect.top, 20);
      expect(layout.columns.first.headerRect.height, 20);
    });

    test('progress grows the cells up from the bottom', () {
      final half = layOutMarimekko(
        _columns,
        size: const Size(300, 200),
        cellGap: 0,
        progress: 0.5,
      );
      expect(half.columns[0].cells[0].rect.height, closeTo(60, 1e-9));
      expect(half.columns[0].cells[0].rect.bottom, closeTo(200, 1e-9));
    });

    test('nothing to show lays out nothing', () {
      expect(layOutMarimekko(const [], size: const Size(300, 200)).isEmpty,
          true);
      expect(layOutMarimekko(_columns, size: Size.zero).isEmpty, true);
      expect(
        layOutMarimekko(
          const [MarimekkoColumn(label: 'x', cells: [])],
          size: const Size(300, 200),
        ).isEmpty,
        true,
      );
    });

    test('a point finds the cell and the column under it', () {
      final layout = layOutMarimekko(
        _columns,
        size: const Size(300, 200),
        cellGap: 0,
      );
      expect(layout.cellAt(const Offset(50, 190))?.cell.label, 'BTC');
      expect(layout.cellAt(const Offset(50, 10))?.cell.label, 'ETH');
      expect(layout.columnAt(const Offset(250, 100))?.index, 1);
      expect(layout.cellAt(const Offset(-5, 100)), isNull);
    });
  });

  group('the widget', () {
    testWidgets('draws and reports the cell under the finger', (tester) async {
      MarimekkoCell? cell;
      MarimekkoColumn? column;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 200,
              child: MarimekkoChart(
                columns: _columns,
                showHeaders: false,
                onCellTap: (touchedCell, touchedColumn) {
                  cell = touchedCell ?? cell;
                  column = touchedColumn ?? column;
                },
              ),
            ),
          ),
        ),
      );
      expect(find.byType(MarimekkoChart), findsOneWidget);

      final box = tester.getRect(find.byType(MarimekkoChart));
      final gesture =
          await tester.startGesture(Offset(box.right - 40, box.bottom - 20));
      await tester.pump();
      expect(cell?.label, 'BTC');
      expect(column?.label, 'Perps');
      await gesture.up();
      await tester.pump();
    });

    testWidgets('takes its default height in an unbounded box',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MarimekkoChart(columns: _columns, defaultHeight: 180),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(MarimekkoChart)).height, 180);
    });

    testWidgets('grows the cells up over time', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 200,
              child: MarimekkoChart(
                columns: _columns,
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
