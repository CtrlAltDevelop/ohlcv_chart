import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

const _series = [
  SlopeSeries(label: 'BTC', values: [4.2, 19.0, 11.5]),
  SlopeSeries(label: 'ETH', values: [12.1, 8.4, 2.0]),
  SlopeSeries(label: 'SOL', values: [9.7, 1.2, 6.3]),
];

void main() {
  group('ranking', () {
    test('1 is the largest, unless asked the other way', () {
      expect(rankValues(const [4.2, 12.1, 9.7]), [3, 1, 2]);
      expect(rankValues(const [4.2, 12.1, 9.7], ascending: true), [1, 3, 2]);
    });

    test('ties share a place and the next one skips', () {
      expect(rankValues(const [5, 5, 1]), [1, 1, 3]);
    });

    test('a missing value has no rank', () {
      expect(rankValues(const [5, null, 1]), [1, null, 2]);
      expect(rankValues(const [double.nan, 1]), [null, 1]);
    });
  });

  group('the layout', () {
    test('periods are spread evenly across the plot', () {
      final layout = layOutSlope(
        _series,
        size: const Size(400, 200),
        periods: 3,
        labelWidth: 0,
      );
      expect(layout.columnX, hasLength(3));
      expect(layout.columnX.first, closeTo(layout.plotRect.left, 1e-9));
      expect(layout.columnX.last, closeTo(layout.plotRect.right, 1e-9));
      expect(layout.columnX[1], closeTo(layout.plotRect.center.dx, 1e-9));
    });

    test('a single period sits in the middle', () {
      final layout = layOutSlope(
        _series,
        size: const Size(400, 200),
        periods: 1,
        labelWidth: 0,
      );
      expect(layout.columnX.single, closeTo(layout.plotRect.center.dx, 1e-9));
    });

    test('on a value scale the largest is highest', () {
      final layout = layOutSlope(
        _series,
        size: const Size(400, 200),
        periods: 3,
      );
      // BTC peaks at period 1; ETH is lowest there.
      expect(
        layout.series[0].points[1]!.dy,
        lessThan(layout.series[1].points[1]!.dy),
      );
    });

    test('on a rank scale first place sits at the top of the plot', () {
      final layout = layOutSlope(
        _series,
        size: const Size(400, 200),
        periods: 3,
        scale: SlopeScale.rank,
      );
      expect(layout.min, 1);
      expect(layout.max, 3);
      // Period 0: ETH 12.1 is first, SOL second, BTC third.
      expect(layout.series[1].points[0]!.dy, closeTo(layout.plotRect.top, 1e-9));
      expect(
        layout.series[0].points[0]!.dy,
        closeTo(layout.plotRect.bottom, 1e-9),
      );
    });

    test('a missing value breaks the line there', () {
      final layout = layOutSlope(
        const [
          SlopeSeries(label: 'a', values: [1, null, 3]),
        ],
        size: const Size(400, 200),
        periods: 3,
      );
      expect(layout.series.single.points[1], isNull);
      expect(layout.series.single.points[0], isNotNull);
      expect(layout.series.single.lastPoint, layout.series.single.points[2]);
    });

    test('progress reveals the columns left to right', () {
      final layout = layOutSlope(
        _series,
        size: const Size(400, 200),
        periods: 3,
        labelWidth: 0,
        progress: 0.5,
      );
      expect(layout.series[0].points[0], isNotNull);
      expect(layout.series[0].points[1], isNotNull);
      expect(layout.series[0].points[2], isNull);
    });

    test('the header takes its room off the top', () {
      final layout = layOutSlope(
        _series,
        size: const Size(400, 200),
        periods: 3,
        headerHeight: 20,
      );
      expect(layout.plotRect.top, 20);
    });

    test('nothing to show lays out nothing', () {
      expect(
        layOutSlope(const [], size: const Size(400, 200), periods: 3).isEmpty,
        true,
      );
      expect(layOutSlope(_series, size: Size.zero, periods: 3).isEmpty, true);
      expect(
        layOutSlope(_series, size: const Size(400, 200), periods: 0).isEmpty,
        true,
      );
    });

    test('a point finds the nearest line, and the nearest column', () {
      final layout = layOutSlope(
        _series,
        size: const Size(400, 200),
        periods: 3,
        labelWidth: 0,
      );
      final at = layout.series[1].points[1]!;
      expect(layout.seriesAt(at)?.index, 1);
      expect(layout.seriesAt(at + const Offset(0, 90)), isNot(same(layout.series[1])));
      expect(layout.seriesAt(const Offset(200, -400)), isNull);
      expect(layout.columnAt(layout.columnX.last + 30), 2);
    });
  });

  group('the widget', () {
    testWidgets('draws and reports the line under the finger', (tester) async {
      SlopeSeries? touched;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 200,
              child: SlopeChart(
                series: _series,
                periodLabels: const ['Q1', 'Q2', 'Q3'],
                onSeriesTap: (series) => touched = series ?? touched,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(SlopeChart), findsOneWidget);

      final box = tester.getRect(find.byType(SlopeChart));
      final gesture = await tester.startGesture(box.center);
      await tester.pump();
      expect(touched, isNotNull);
      await gesture.up();
      await tester.pump();
    });

    testWidgets('takes its default height in an unbounded box',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SlopeChart(series: _series, defaultHeight: 180),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(SlopeChart)).height, 180);
    });

    testWidgets('counts its periods from the longest series', (tester) async {
      const chart = SlopeChart(
        series: [
          SlopeSeries(label: 'a', values: [1, 2]),
          SlopeSeries(label: 'b', values: [1, 2, 3]),
        ],
      );
      expect(chart.resolvedPeriods, 3);
    });

    testWidgets('draws the lines in over time', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 200,
              child: SlopeChart(
                series: _series,
                scale: SlopeScale.rank,
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
