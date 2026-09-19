import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

const _series = [
  StreamSeries(label: 'BTC', values: [40, 55, 48]),
  StreamSeries(label: 'ETH', values: [30, 20, 35]),
  StreamSeries(label: 'Cash', values: [30, 25, 17]),
];

void main() {
  group('a series', () {
    test('negatives, gaps and nonsense count as nothing', () {
      const one = StreamSeries(label: 'a', values: [5, -3, double.nan]);
      expect(one.valueAt(0), 5);
      expect(one.valueAt(1), 0);
      expect(one.valueAt(2), 0);
      expect(one.valueAt(9), 0);
    });
  });

  group('the stack', () {
    test('bands sit on each other, no gaps and no overlap', () {
      final stack = stackStream(
        _series,
        periods: 3,
        baseline: StreamBaseline.zero,
        order: StreamOrder.given,
      );
      for (var p = 0; p < 3; p++) {
        expect(stack.bottoms[0][p], 0);
        expect(stack.bottoms[1][p], stack.tops[0][p]);
        expect(stack.bottoms[2][p], stack.tops[1][p]);
        expect(
          stack.tops[2][p] - stack.bottoms[0][p],
          closeTo(_series.fold<double>(0, (a, b) => a + b.valueAt(p)), 1e-9),
        );
      }
    });

    test('a zero baseline starts every period at zero', () {
      final stack = stackStream(
        _series,
        periods: 3,
        baseline: StreamBaseline.zero,
      );
      expect(stack.min, 0);
    });

    test('a silhouette is centred on zero', () {
      final stack = stackStream(
        _series,
        periods: 3,
        baseline: StreamBaseline.silhouette,
      );
      for (var p = 0; p < 3; p++) {
        final low = stack.bottoms[stack.order.first][p];
        final high = stack.tops[stack.order.last][p];
        expect(low + high, closeTo(0, 1e-9));
      }
    });

    test('a wiggle baseline keeps the bands flatter than a zero one', () {
      double wobble(StreamStack stack) {
        var sum = 0.0;
        for (var i = 0; i < _series.length; i++) {
          for (var p = 1; p < 3; p++) {
            final mid = (stack.tops[i][p] + stack.bottoms[i][p]) / 2;
            final before = (stack.tops[i][p - 1] + stack.bottoms[i][p - 1]) / 2;
            sum += (mid - before).abs();
          }
        }
        return sum;
      }

      final flat = wobble(
        stackStream(_series, periods: 3, baseline: StreamBaseline.wiggle),
      );
      final stacked = wobble(
        stackStream(_series, periods: 3, baseline: StreamBaseline.zero),
      );
      expect(flat, lessThan(stacked));
    });

    test('inside-out puts the largest band in the middle', () {
      final stack = stackStream(
        _series,
        periods: 3,
        order: StreamOrder.insideOut,
      );
      // BTC is the largest, so it is neither at the bottom nor the top.
      expect(stack.order.indexOf(0), 1);
      expect(stack.order, hasLength(3));
      expect(stack.order.toSet(), {0, 1, 2});
    });

    test('largest first puts it against the baseline', () {
      final stack = stackStream(
        _series,
        periods: 3,
        order: StreamOrder.largestFirst,
      );
      expect(stack.order.first, 0);
    });

    test('nothing at all is empty', () {
      expect(stackStream(const [], periods: 3).isEmpty, true);
      expect(stackStream(_series, periods: 0).isEmpty, true);
    });
  });

  group('the layout', () {
    test('periods are spread evenly across the plot', () {
      final layout = layOutStream(
        _series,
        size: const Size(400, 200),
        periods: 3,
      );
      expect(layout.columnX.first, closeTo(layout.plotRect.left, 1e-9));
      expect(layout.columnX.last, closeTo(layout.plotRect.right, 1e-9));
    });

    test('the stack fills the plot from top to bottom', () {
      final layout = layOutStream(
        _series,
        size: const Size(400, 200),
        periods: 3,
        baseline: StreamBaseline.zero,
      );
      var top = double.infinity, bottom = double.negativeInfinity;
      for (final laid in layout.series) {
        for (final at in laid.topPoints) {
          top = at.dy < top ? at.dy : top;
        }
        for (final at in laid.bottomPoints) {
          bottom = at.dy > bottom ? at.dy : bottom;
        }
      }
      expect(top, closeTo(layout.plotRect.top, 1e-6));
      expect(bottom, closeTo(layout.plotRect.bottom, 1e-6));
    });

    test('progress flattens the bands towards the middle', () {
      final half = layOutStream(
        _series,
        size: const Size(400, 200),
        periods: 3,
        progress: 0.5,
      );
      final full = layOutStream(
        _series,
        size: const Size(400, 200),
        periods: 3,
      );
      expect(
        half.series.first.thicknessAt(0),
        closeTo(full.series.first.thicknessAt(0) / 2, 1e-6),
      );
    });

    test('the axis takes its room off the bottom', () {
      final layout = layOutStream(
        _series,
        size: const Size(400, 200),
        periods: 3,
        axisHeight: 20,
      );
      expect(layout.plotRect.bottom, closeTo(180, 1e-9));
    });

    test('nothing to show lays out nothing', () {
      expect(
        layOutStream(const [], size: const Size(400, 200), periods: 3).isEmpty,
        true,
      );
      expect(layOutStream(_series, size: Size.zero, periods: 3).isEmpty, true);
    });

    test('a point finds the band it is inside, and the period', () {
      final layout = layOutStream(
        _series,
        size: const Size(400, 200),
        periods: 3,
        baseline: StreamBaseline.zero,
      );
      final laid = layout.series[1];
      final inside = Offset(
        laid.topPoints[1].dx,
        (laid.topPoints[1].dy + laid.bottomPoints[1].dy) / 2,
      );
      expect(layout.seriesAt(inside)?.index, 1);
      expect(layout.periodAt(inside.dx), 1);
      expect(layout.seriesAt(const Offset(200, -50)), isNull);
    });
  });

  group('the widget', () {
    testWidgets('draws and reports the band under the finger', (tester) async {
      StreamSeries? touched;
      int? period;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 200,
              child: StreamChart(
                series: _series,
                periodLabels: const ['Jan', 'Feb', 'Mar'],
                onSeriesTap: (series, at) {
                  touched = series ?? touched;
                  period = at ?? period;
                },
              ),
            ),
          ),
        ),
      );
      expect(find.byType(StreamChart), findsOneWidget);

      final box = tester.getRect(find.byType(StreamChart));
      final gesture = await tester.startGesture(box.center);
      await tester.pump();
      expect(touched, isNotNull);
      expect(period, 1);
      await gesture.up();
      await tester.pump();
    });

    testWidgets('takes its default height in an unbounded box', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StreamChart(series: _series, defaultHeight: 160),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(StreamChart)).height, 160);
    });

    testWidgets('counts its periods from the longest series', (tester) async {
      const chart = StreamChart(
        series: [
          StreamSeries(label: 'a', values: [1, 2]),
          StreamSeries(label: 'b', values: [1, 2, 3]),
        ],
      );
      expect(chart.resolvedPeriods, 3);
    });

    testWidgets('opens the bands out over time', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 200,
              child: StreamChart(
                series: _series,
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
