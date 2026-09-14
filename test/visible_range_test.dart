import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

import 'test_utils.dart';

DateTime _at(int minute) =>
    DateTime.utc(2024, 1, 1).add(Duration(minutes: minute));

/// [count] candles, calculated, one a minute from 2024-01-01.
List<KLineEntity> _candles([int count = 240]) {
  final data = candles(rampThenFall(count));
  DataUtil.calculate(data);
  return data;
}

Widget _chart(
  List<KLineEntity> data, {
  KChartController? controller,
  ValueChanged<ChartVisibleRange>? onVisibleRangeChanged,
}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: 500,
      height: 600,
      child: KChartWidget(
        data,
        ChartColors(),
        isTrendLine: false,
        timeFrame: const Duration(minutes: 1),
        showNowPrice: false,
        controller: controller,
        onVisibleRangeChanged: onVisibleRangeChanged,
      ),
    ),
  ),
);

void main() {
  group('the range itself', () {
    test('it reads out its own ends, and how many candles it holds', () {
      final data = _candles(60);
      final range = ChartVisibleRange.of(data, 10, 19);

      expect(range.firstIndex, 10);
      expect(range.lastIndex, 19);
      expect(range.length, 10);
      expect(range.firstTime, _at(10));
      expect(range.lastTime, _at(19));
      expect(range.span, const Duration(minutes: 9));
    });

    test('ends outside the data are pulled back inside it', () {
      final data = _candles(20);
      final range = ChartVisibleRange.of(data, -5, 500);

      expect(range.firstIndex, 0);
      expect(range.lastIndex, 19);
    });

    test('no candles is a range of nothing, with no times', () {
      final range = ChartVisibleRange.of(const [], 0, 0);

      expect(range.firstTime, isNull);
      expect(range.span, isNull);
    });

    test('two ranges over the same candles are equal', () {
      final data = _candles(20);
      expect(
        ChartVisibleRange.of(data, 2, 8),
        ChartVisibleRange.of(data, 2, 8),
      );
      expect(
        ChartVisibleRange.of(data, 2, 8).hashCode,
        ChartVisibleRange.of(data, 2, 8).hashCode,
      );
      expect(
        ChartVisibleRange.of(data, 2, 8),
        isNot(ChartVisibleRange.of(data, 2, 9)),
      );
    });

    test('it says what it is, for a log line', () {
      final data = _candles(20);
      expect(
        ChartVisibleRange.of(data, 2, 8).toString(),
        contains('7 candles'),
      );
    });
  });

  group('reading the window', () {
    testWidgets('the controller reports what is in view', (tester) async {
      final controller = KChartController();
      final data = _candles();
      await tester.pumpWidget(_chart(data, controller: controller));
      await tester.pumpAndSettle();

      final range = controller.visibleRange!;
      expect(range.firstIndex, greaterThanOrEqualTo(0));
      expect(range.lastIndex, data.length - 1);
      expect(range.length, lessThan(data.length));
      expect(range.lastTime, data.last.dateTime);
    });

    testWidgets('nothing is reported without a chart to ask', (tester) async {
      final controller = KChartController();
      expect(controller.visibleRange, isNull);
      expect(controller.showRange(0, 10), isFalse);
      expect(controller.goToIndex(5), isFalse);
      expect(controller.fitAll(), isFalse);
    });

    testWidgets('a chart with no candles reports no window', (tester) async {
      final controller = KChartController();
      await tester.pumpWidget(_chart(const [], controller: controller));
      await tester.pumpAndSettle();

      expect(controller.visibleRange, isNull);
      expect(controller.fitAll(), isFalse);
    });
  });

  group('moving the window', () {
    testWidgets('showRange puts the candles asked for on screen', (
      tester,
    ) async {
      final controller = KChartController();
      await tester.pumpWidget(_chart(_candles(), controller: controller));
      await tester.pumpAndSettle();

      expect(controller.showRange(40, 79), isTrue);
      await tester.pumpAndSettle();

      final range = controller.visibleRange!;
      // Zoomed and scrolled together, so the window holds about what was asked
      // for — within a candle either side of the edges.
      expect(range.firstIndex, closeTo(40, 2));
      expect(range.lastIndex, closeTo(79, 2));
    });

    testWidgets('the ends may be given in either order', (tester) async {
      final controller = KChartController();
      await tester.pumpWidget(_chart(_candles(), controller: controller));
      await tester.pumpAndSettle();

      controller.showRange(79, 40);
      await tester.pumpAndSettle();
      final backwards = controller.visibleRange!;

      controller.showRange(40, 79);
      await tester.pumpAndSettle();

      expect(controller.visibleRange, backwards);
    });

    testWidgets(
      'a range wider than the zoom allows is shown as near as it can',
      (tester) async {
        final controller = KChartController();
        // Far more candles than the chart can fit at its zoom-out limit.
        await tester.pumpWidget(_chart(_candles(2000), controller: controller));
        await tester.pumpAndSettle();

        expect(controller.showRange(0, 1999), isTrue);
        await tester.pumpAndSettle();

        expect(controller.scale, closeTo(0.1, 1e-9), reason: 'at the limit');
        expect(controller.visibleRange!.firstIndex, 0);
      },
    );

    testWidgets('a single candle is shown by zooming right in', (tester) async {
      final controller = KChartController();
      await tester.pumpWidget(_chart(_candles(), controller: controller));
      await tester.pumpAndSettle();

      expect(controller.showRange(100, 100), isTrue);
      await tester.pumpAndSettle();

      expect(controller.scale, closeTo(3.0, 1e-9), reason: 'at the limit');
      expect(controller.visibleRange!.firstIndex, closeTo(100, 2));
    });

    testWidgets('goToIndex centres the candle without changing the zoom', (
      tester,
    ) async {
      final controller = KChartController();
      await tester.pumpWidget(_chart(_candles(), controller: controller));
      await tester.pumpAndSettle();
      final zoom = controller.scale;

      expect(controller.goToIndex(80, animated: false), isTrue);
      await tester.pumpAndSettle();

      final range = controller.visibleRange!;
      expect(controller.scale, zoom);
      expect(range.firstIndex, lessThan(80));
      expect(range.lastIndex, greaterThan(80));
      // Roughly in the middle, within a couple of candles.
      expect((range.firstIndex + range.lastIndex) / 2, closeTo(80, 3));
    });

    testWidgets('an animated scroll settles where it was sent', (tester) async {
      final controller = KChartController();
      await tester.pumpWidget(_chart(_candles(), controller: controller));
      await tester.pumpAndSettle();

      expect(controller.goToIndex(60), isTrue);
      await tester.pumpAndSettle();

      final range = controller.visibleRange!;
      expect((range.firstIndex + range.lastIndex) / 2, closeTo(60, 3));
    });

    testWidgets('fitAll opens the window as wide as it goes', (tester) async {
      final controller = KChartController();
      await tester.pumpWidget(_chart(_candles(120), controller: controller));
      await tester.pumpAndSettle();
      final before = controller.visibleRange!.length;

      expect(controller.fitAll(), isTrue);
      await tester.pumpAndSettle();

      final after = controller.visibleRange!;
      expect(after.length, greaterThan(before));
      expect(after.firstIndex, 0);
      expect(after.lastIndex, 119);
    });

    testWidgets('an index outside the data is pulled back inside it', (
      tester,
    ) async {
      final controller = KChartController();
      await tester.pumpWidget(_chart(_candles(60), controller: controller));
      await tester.pumpAndSettle();

      expect(controller.goToIndex(9999, animated: false), isTrue);
      await tester.pumpAndSettle();
      expect(controller.visibleRange!.lastIndex, 59);

      expect(controller.goToIndex(-50, animated: false), isTrue);
      await tester.pumpAndSettle();
      expect(controller.visibleRange!.firstIndex, 0);
    });
  });

  group('moving by time', () {
    testWidgets('goToDate finds the candle nearest the instant', (
      tester,
    ) async {
      final controller = KChartController();
      final data = _candles();
      await tester.pumpWidget(_chart(data, controller: controller));
      await tester.pumpAndSettle();

      // Between two candles, so it goes to whichever is closer.
      expect(
        controller.goToDate(
          data,
          _at(100).add(const Duration(seconds: 20)),
          animated: false,
        ),
        isTrue,
      );
      await tester.pumpAndSettle();

      final range = controller.visibleRange!;
      expect((range.firstIndex + range.lastIndex) / 2, closeTo(100, 3));
    });

    testWidgets('showTimeRange covers the span asked for', (tester) async {
      final controller = KChartController();
      final data = _candles();
      await tester.pumpWidget(_chart(data, controller: controller));
      await tester.pumpAndSettle();

      expect(controller.showTimeRange(data, _at(50), _at(90)), isTrue);
      await tester.pumpAndSettle();

      final range = controller.visibleRange!;
      expect(range.firstTime!.isAfter(_at(50)), isFalse);
      expect(range.lastTime!.isBefore(_at(90)), isFalse);
    });

    testWidgets('a span with no candles in it moves nothing', (tester) async {
      final controller = KChartController();
      final data = _candles(60);
      await tester.pumpWidget(_chart(data, controller: controller));
      await tester.pumpAndSettle();

      // Long before the data starts.
      expect(
        controller.showTimeRange(
          data,
          DateTime.utc(2000),
          DateTime.utc(2000, 1, 2),
        ),
        isFalse,
      );
      expect(controller.goToDate(const [], _at(0)), isFalse);
    });

    test('the covering range widens outwards between candles', () {
      final data = _candles(60);

      // Both instants fall on candles, so it is exact.
      expect(indexRangeCovering(data, _at(10), _at(20)), (10, 20));
      // Between candles: the range covers the span rather than falling inside
      // it.
      expect(
        indexRangeCovering(
          data,
          _at(10).add(const Duration(seconds: 30)),
          _at(20).add(const Duration(seconds: 30)),
        ),
        (10, 20),
      );
      // A span starting before the data still shows what there is of it.
      expect(indexRangeCovering(data, DateTime.utc(2000), _at(5)), (0, 5));
      expect(indexRangeCovering(const [], _at(0), _at(1)), isNull);
      expect(
        indexRangeCovering(data, DateTime.utc(2000), DateTime.utc(2001)),
        isNull,
      );
    });

    test('the nearest candle is the nearest either way', () {
      final data = _candles(60);

      expect(indexNearest(data, _at(30)), 30);
      expect(indexNearest(data, _at(30).add(const Duration(seconds: 10))), 30);
      expect(indexNearest(data, _at(30).add(const Duration(seconds: 50))), 31);
      expect(indexNearest(data, DateTime.utc(2000)), 0);
      expect(indexNearest(data, DateTime.utc(2030)), 59);
      expect(indexNearest(const [], _at(0)), isNull);
    });
  });

  group('being told when the window moves', () {
    testWidgets('the first frame reports what is in view', (tester) async {
      final seen = <ChartVisibleRange>[];
      await tester.pumpWidget(
        _chart(_candles(), onVisibleRangeChanged: seen.add),
      );
      await tester.pumpAndSettle();

      expect(seen, isNotEmpty);
      expect(seen.last.lastIndex, 239);
    });

    testWidgets('scrolling reports the new window', (tester) async {
      final controller = KChartController();
      final seen = <ChartVisibleRange>[];
      await tester.pumpWidget(
        _chart(
          _candles(),
          controller: controller,
          onVisibleRangeChanged: seen.add,
        ),
      );
      await tester.pumpAndSettle();
      final first = seen.last;

      controller.showRange(20, 60);
      await tester.pumpAndSettle();

      expect(seen.last, isNot(first));
      expect(seen.last.firstIndex, closeTo(20, 2));
    });

    testWidgets('a frame that changes nothing reports nothing', (tester) async {
      final seen = <ChartVisibleRange>[];
      final data = _candles();
      await tester.pumpWidget(_chart(data, onVisibleRangeChanged: seen.add));
      await tester.pumpAndSettle();
      final count = seen.length;

      // Rebuilt with the same data and the same window.
      await tester.pumpWidget(_chart(data, onVisibleRangeChanged: seen.add));
      await tester.pumpAndSettle();

      expect(seen, hasLength(count));
    });
  });
}
