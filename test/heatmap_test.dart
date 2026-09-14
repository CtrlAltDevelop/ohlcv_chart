import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

void main() {
  group('the grid', () {
    const layout = HeatmapLayout(
      grid: Rect.fromLTWH(0, 0, 300, 200),
      rows: 4,
      columns: 6,
    );

    test('squares divide the grid evenly', () {
      expect(layout.columnWidth, 50);
      expect(layout.rowHeight, 50);
      expect(layout.cellRect(0, 0), const Rect.fromLTWH(0, 0, 50, 50));
      expect(layout.cellRect(5, 3), const Rect.fromLTWH(250, 150, 50, 50));
    });

    test('spacing is taken off every square, not off the grid', () {
      const spaced = HeatmapLayout(
        grid: Rect.fromLTWH(0, 0, 300, 200),
        rows: 4,
        columns: 6,
        spacing: 4,
      );
      expect(spaced.cellRect(0, 0), const Rect.fromLTRB(2, 2, 48, 48));
      expect(spaced.grid.width, 300);
    });

    test('a point names the square under it', () {
      expect(layout.cellAt(const Offset(10, 10)), (0, 0));
      expect(layout.cellAt(const Offset(260, 160)), (5, 3));
      expect(layout.cellAt(const Offset(-1, 10)), isNull);
      expect(layout.cellAt(const Offset(10, 400)), isNull);
    });

    test('an empty grid has no squares to hit', () {
      const none = HeatmapLayout(
        grid: Rect.fromLTWH(0, 0, 100, 100),
        rows: 0,
        columns: 0,
      );
      expect(none.cellAt(const Offset(10, 10)), isNull);
    });
  });

  group('scales', () {
    test('a gradient fades between its colours across the range', () {
      const scale = HeatmapGradientScale(
        colors: [Color(0xFF000000), Color(0xFFFFFFFF)],
      );
      expect(scale.colorAt(0, 0, 10), const Color(0xFF000000));
      expect(scale.colorAt(10, 0, 10), const Color(0xFFFFFFFF));
      expect(scale.colorAt(5, 0, 10).r, closeTo(0.5, 0.02));
    });

    test('a value outside the range is held at the end it passed', () {
      const scale = HeatmapGradientScale(
        colors: [Color(0xFF000000), Color(0xFFFFFFFF)],
      );
      expect(scale.colorAt(-5, 0, 10), const Color(0xFF000000));
      expect(scale.colorAt(99, 0, 10), const Color(0xFFFFFFFF));
    });

    test('a range of nothing puts every value at the top colour', () {
      const scale = HeatmapGradientScale(
        colors: [Color(0xFF000000), Color(0xFFFFFFFF)],
      );
      expect(scale.colorAt(3, 3, 3), const Color(0xFFFFFFFF));
    });

    test('steps paint whole bands, and below the first is the first', () {
      const scale = HeatmapStepScale(
        steps: [
          HeatmapStep(0, Color(0xFF111111)),
          HeatmapStep(5, Color(0xFF222222)),
          HeatmapStep(10, Color(0xFF333333)),
        ],
      );
      expect(scale.colorAt(-3, 0, 10), const Color(0xFF111111));
      expect(scale.colorAt(0, 0, 10), const Color(0xFF111111));
      expect(scale.colorAt(7, 0, 10), const Color(0xFF222222));
      expect(scale.colorAt(40, 0, 10), const Color(0xFF333333));
    });
  });

  group('reading the cells', () {
    test('a matrix becomes a cell per value, rows down and columns across', () {
      final cells = heatmapCellsOf([
        [1, 2, 3],
        [4, null],
      ]);
      expect(cells, hasLength(5));
      expect(cells.first.x, 0);
      expect(cells.first.y, 0);
      expect(cells[3].x, 0);
      expect(cells[3].y, 1);
      expect(cells.last.isEmpty, isTrue);
    });

    test('the range skips the empty squares', () {
      final (low, high) = heatmapValueRange(const [
        HeatmapCell(x: 0, y: 0, value: 4),
        HeatmapCell(x: 1, y: 0, value: null),
        HeatmapCell(x: 2, y: 0, value: -2),
      ]);
      expect(low, -2);
      expect(high, 4);
    });

    test('nothing to measure reads as 0 to 1', () {
      expect(heatmapValueRange(const []), (0.0, 1.0));
    });
  });

  group('the widget', () {
    testWidgets('it reports the square under a tap', (tester) async {
      final touched = <HeatmapTouchDetails?>[];
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 300,
              height: 200,
              child: HeatmapChart.matrix(
                const [
                  [1, 2, 3],
                  [4, 5, 6],
                ],
                xAxis: HeatmapAxis.hidden,
                yAxis: HeatmapAxis.hidden,
                onTouch: touched.add,
              ),
            ),
          ),
        ),
      );

      final chart = tester.getRect(find.byType(HeatmapChart));
      // The top-right square is the third column of the first row.
      await tester.tapAt(chart.topRight + const Offset(-10, 10));
      await tester.pump();

      expect(touched.first?.x, 2);
      expect(touched.first?.y, 0);
      expect(touched.first?.value, 3);
    });

    testWidgets('a square with no cell reports itself as empty', (
      tester,
    ) async {
      final touched = <HeatmapTouchDetails?>[];
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: HeatmapChart(
                cells: const [HeatmapCell(x: 0, y: 0, value: 1)],
                columns: 2,
                rows: 2,
                xAxis: HeatmapAxis.hidden,
                yAxis: HeatmapAxis.hidden,
                onTouch: touched.add,
              ),
            ),
          ),
        ),
      );

      final chart = tester.getRect(find.byType(HeatmapChart));
      await tester.tapAt(chart.bottomRight - const Offset(10, 10));
      await tester.pump();

      expect(touched.first?.x, 1);
      expect(touched.first?.cell, isNull);
      expect(touched.first?.value, isNull);
    });

    testWidgets('square cells keep their shape in a box that is not', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 400,
              height: 100,
              child: HeatmapChart.matrix(
                const [
                  [1, 2],
                  [3, 4],
                ],
                squareCells: true,
                xAxis: HeatmapAxis.hidden,
                yAxis: HeatmapAxis.hidden,
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tooltip is placed over the touched square', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 300,
              height: 200,
              child: HeatmapChart.matrix(
                const [
                  [1, 2, 3],
                ],
                xAxis: HeatmapAxis.hidden,
                yAxis: HeatmapAxis.hidden,
                tooltipBuilder: (context, details) => Text('${details.value}'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('2.0'), findsNothing);
      // Held rather than tapped: letting go clears the touch again.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HeatmapChart)),
      );
      await tester.pump();
      expect(find.text('2.0'), findsOneWidget);

      await gesture.up();
      await tester.pump();
      expect(find.text('2.0'), findsNothing);
    });

    testWidgets('the legend draws its scale', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 200,
              child: HeatmapLegend(
                scale: HeatmapGradientScale(colors: [Color(0xFF000000)]),
                low: 'Less',
                high: 'More',
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Less'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
    });
  });
}
