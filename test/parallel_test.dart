import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

const _axes = [
  ParallelAxis(label: 'Return'),
  ParallelAxis(label: 'Drawdown', inverted: true),
  ParallelAxis(label: 'Win rate'),
];

const _lines = [
  ParallelLine(label: 'Trend', values: [34, 18, 41]),
  ParallelLine(label: 'Revert', values: [21, 9, 63]),
];

void main() {
  group('the scales', () {
    test('each axis takes its own smallest and largest', () {
      final scales = parallelScales(_axes, _lines);
      expect(scales[0].min, 21);
      expect(scales[0].max, 34);
      expect(scales[2].min, 41);
      expect(scales[2].max, 63);
    });

    test('given ends win over the data', () {
      final scales = parallelScales(
        const [ParallelAxis(label: 'x', min: 0, max: 100)],
        const [
          ParallelLine(label: 'a', values: [50]),
        ],
      );
      expect(scales.single.min, 0);
      expect(scales.single.max, 100);
    });

    test('an inverted axis puts small at the top', () {
      final scales = parallelScales(_axes, _lines);
      expect(scales[1].inverted, true);
      // Drawdown 9 is better than 18, so it sits higher.
      expect(scales[1].fractionOf(9), greaterThan(scales[1].fractionOf(18)));
    });

    test('a measure everything agrees on lands in the middle', () {
      final scales = parallelScales(
        const [ParallelAxis(label: 'x')],
        const [
          ParallelLine(label: 'a', values: [5]),
          ParallelLine(label: 'b', values: [5]),
        ],
      );
      expect(scales.single.fractionOf(5), closeTo(0.5, 1e-9));
    });

    test('an axis nothing has a value for still has a scale', () {
      final scales = parallelScales(
        const [ParallelAxis(label: 'x')],
        const [
          ParallelLine(label: 'a', values: [null]),
        ],
      );
      expect(scales.single.max, greaterThan(scales.single.min));
    });
  });

  group('the layout', () {
    test('axes are spread evenly across the plot', () {
      final layout = layOutParallel(_axes, _lines, size: const Size(400, 200));
      expect(layout.axisX.first, closeTo(layout.plotRect.left, 1e-9));
      expect(layout.axisX.last, closeTo(layout.plotRect.right, 1e-9));
      expect(layout.axisX[1], closeTo(layout.plotRect.center.dx, 1e-9));
    });

    test('a line crosses every axis at its own value', () {
      final layout = layOutParallel(
        _axes,
        _lines,
        size: const Size(400, 200),
        headerHeight: 0,
        footerHeight: 0,
      );
      // Trend is the top of the return axis and the bottom of drawdown.
      expect(layout.lines[0].points[0]!.dy, closeTo(layout.plotRect.top, 1e-9));
      expect(
        layout.lines[0].points[1]!.dy,
        closeTo(layout.plotRect.bottom, 1e-9),
      );
      expect(layout.lines[1].points[1]!.dy, closeTo(layout.plotRect.top, 1e-9));
    });

    test('a missing value breaks the line there', () {
      final layout = layOutParallel(_axes, const [
        ParallelLine(label: 'a', values: [1, null, 3]),
      ], size: const Size(400, 200));
      expect(layout.lines.single.points[1], isNull);
      expect(layout.lines.single.points[0], isNotNull);
    });

    test('a legend takes its room off the left', () {
      final layout = layOutParallel(
        _axes,
        _lines,
        size: const Size(400, 200),
        legendWidth: 64,
      );
      expect(layout.plotRect.left, 64);
      expect(layout.axisX.first, 64);
    });

    test('the header and the ends take their room', () {
      final layout = layOutParallel(
        _axes,
        _lines,
        size: const Size(400, 200),
        headerHeight: 22,
        footerHeight: 16,
      );
      expect(layout.plotRect.top, 22);
      expect(layout.plotRect.bottom, 184);
    });

    test('progress reveals the axes left to right', () {
      final layout = layOutParallel(
        _axes,
        _lines,
        size: const Size(400, 200),
        progress: 0.5,
      );
      expect(layout.lines[0].points[0], isNotNull);
      expect(layout.lines[0].points[1], isNotNull);
      expect(layout.lines[0].points[2], isNull);
    });

    test('nothing to show lays out nothing', () {
      expect(
        layOutParallel(const [], _lines, size: const Size(400, 200)).isEmpty,
        true,
      );
      expect(
        layOutParallel(_axes, const [], size: const Size(400, 200)).isEmpty,
        true,
      );
      expect(layOutParallel(_axes, _lines, size: Size.zero).isEmpty, true);
    });

    test('a point finds the nearest axis and the line on it', () {
      final layout = layOutParallel(
        _axes,
        _lines,
        size: const Size(400, 200),
        headerHeight: 0,
        footerHeight: 0,
      );
      expect(layout.axisAt(layout.axisX[2] + 20), 2);
      final at = layout.lines[1].points[2]!;
      expect(layout.lineAt(at)?.index, 1);
      expect(layout.lineAt(const Offset(200, -500)), isNull);
    });
  });

  group('the widget', () {
    testWidgets('draws and reports the line under the finger', (tester) async {
      ParallelLine? touched;
      int? axis;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 200,
              child: ParallelChart(
                axes: _axes,
                lines: _lines,
                onLineTap: (line, at) {
                  touched = line ?? touched;
                  axis = at ?? axis;
                },
              ),
            ),
          ),
        ),
      );
      expect(find.byType(ParallelChart), findsOneWidget);

      final box = tester.getRect(find.byType(ParallelChart));
      final gesture = await tester.startGesture(
        Offset(box.left + 1, box.top + 30),
      );
      await tester.pump();
      expect(touched?.label, 'Trend');
      expect(axis, 0);
      await gesture.up();
      await tester.pump();
    });

    testWidgets('takes its default height in an unbounded box', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ParallelChart(
                axes: _axes,
                lines: _lines,
                defaultHeight: 190,
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(ParallelChart)).height, 190);
    });

    testWidgets('draws the lines in over time', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 200,
              child: ParallelChart(
                axes: _axes,
                lines: _lines,
                curved: true,
                showLegend: true,
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
