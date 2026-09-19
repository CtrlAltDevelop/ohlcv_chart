import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

const _rows = [
  DumbbellRow(label: 'BTC', from: 0, to: 100),
  DumbbellRow(label: 'ETH', from: 80, to: 20),
];

void main() {
  group('a row', () {
    test('knows how far it moved and which way', () {
      expect(_rows[0].change, 100);
      expect(_rows[0].rose, true);
      expect(_rows[1].change, -60);
      expect(_rows[1].rose, false);
    });
  });

  group('the layout', () {
    test('every row shares one scale', () {
      final layout = layOutDumbbell(
        _rows,
        size: const Size(400, 200),
        labelWidth: 0,
        min: 0,
        max: 100,
      );
      expect(layout.rows[0].fromCenter.dx, closeTo(layout.plotRect.left, 1e-9));
      expect(layout.rows[0].toCenter.dx, closeTo(layout.plotRect.right, 1e-9));
      expect(layout.rows[1].fromCenter.dx, closeTo(layout.xOf(80), 1e-9));
    });

    test('rows stack down the plot, evenly', () {
      final layout = layOutDumbbell(
        _rows,
        size: const Size(400, 200),
        axisHeight: 0,
        tickCount: 0,
      );
      expect(layout.rows, hasLength(2));
      expect(layout.rows[0].trackRect.height, closeTo(100, 1e-9));
      expect(layout.rows[1].trackRect.top, closeTo(100, 1e-9));
      expect(
        layout.rows[0].fromCenter.dy,
        closeTo(layout.rows[0].trackRect.center.dy, 1e-9),
      );
    });

    test('the bounds leave air either side when not given', () {
      final layout = layOutDumbbell(_rows, size: const Size(400, 200));
      expect(layout.min, lessThan(0));
      expect(layout.max, greaterThan(100));
    });

    test('a flat chart still has a range', () {
      final layout = layOutDumbbell(const [
        DumbbellRow(label: 'a', from: 5, to: 5),
      ], size: const Size(400, 200));
      expect(layout.max, greaterThan(layout.min));
    });

    test('the dots are kept a radius clear of the edges', () {
      final layout = layOutDumbbell(
        _rows,
        size: const Size(400, 200),
        labelWidth: 0,
        dotRadius: 6,
      );
      expect(layout.plotRect.right, closeTo(400 - 6, 1e-9));
    });

    test('the axis takes its room off the bottom', () {
      final layout = layOutDumbbell(
        _rows,
        size: const Size(400, 200),
        axisHeight: 20,
      );
      expect(layout.plotRect.bottom, closeTo(180, 1e-9));
    });

    test('progress grows each bar out from its start', () {
      final half = layOutDumbbell(
        _rows,
        size: const Size(400, 200),
        labelWidth: 0,
        min: 0,
        max: 100,
        progress: 0.5,
      );
      final full = layOutDumbbell(
        _rows,
        size: const Size(400, 200),
        labelWidth: 0,
        min: 0,
        max: 100,
      );
      expect(half.rows[0].fromCenter.dx, full.rows[0].fromCenter.dx);
      expect(
        half.rows[0].toCenter.dx,
        closeTo(
          (full.rows[0].fromCenter.dx + full.rows[0].toCenter.dx) / 2,
          1e-6,
        ),
      );
    });

    test('ticks run the whole scale', () {
      final layout = layOutDumbbell(
        _rows,
        size: const Size(400, 200),
        min: 0,
        max: 100,
        tickCount: 4,
      );
      expect(layout.ticks, [0, 25, 50, 75, 100]);
    });

    test('nothing to show lays out nothing', () {
      expect(
        layOutDumbbell(const [], size: const Size(400, 200)).isEmpty,
        true,
      );
      expect(layOutDumbbell(_rows, size: Size.zero).isEmpty, true);
      expect(
        layOutDumbbell(const [
          DumbbellRow(label: 'a', from: double.nan, to: double.nan),
        ], size: const Size(400, 200)).isEmpty,
        true,
      );
    });

    test('a point finds the row it is over', () {
      final layout = layOutDumbbell(
        _rows,
        size: const Size(400, 200),
        axisHeight: 0,
      );
      expect(layout.rowAt(const Offset(200, 10))?.index, 0);
      expect(layout.rowAt(const Offset(200, 150))?.index, 1);
      expect(layout.rowAt(const Offset(200, 400)), isNull);
    });
  });

  group('the widget', () {
    testWidgets('draws and reports the row under the finger', (tester) async {
      DumbbellRow? touched;
      var cleared = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 200,
              child: DumbbellChart(
                rows: _rows,
                showValues: true,
                onRowTap: (row) {
                  if (row == null) {
                    cleared = true;
                  } else {
                    touched = row;
                  }
                },
              ),
            ),
          ),
        ),
      );
      expect(find.byType(DumbbellChart), findsOneWidget);

      final box = tester.getRect(find.byType(DumbbellChart));
      final gesture = await tester.startGesture(
        Offset(box.center.dx, box.top + 20),
      );
      await tester.pump();
      expect(touched?.label, 'BTC');
      await gesture.up();
      await tester.pump();
      expect(cleared, true);
    });

    testWidgets('takes its own height in an unbounded box', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DumbbellChart(rows: _rows, rowHeight: 30, axisHeight: 20),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(DumbbellChart)).height, 80);
    });

    testWidgets('grows the bars out over time', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 200,
              child: DumbbellChart(
                rows: _rows,
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
