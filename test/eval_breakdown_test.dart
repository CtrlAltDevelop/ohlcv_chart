import 'dart:ui' show PointerDeviceKind;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

const _categories = [
  EvalCategory(name: 'Safety', passed: 96, failed: 4),
  EvalCategory(name: 'Math', passed: 71, failed: 29),
  EvalCategory(name: 'Coding', passed: 88, failed: 12, skipped: 3),
  EvalCategory(name: 'Empty', passed: 0, failed: 0, skipped: 5),
];

void main() {
  group('a category', () {
    test('counts the tasks that ran, apart from those that did not', () {
      const c = EvalCategory(name: 'x', passed: 8, failed: 2, skipped: 4);

      expect(c.attempted, 10);
      expect(c.total, 14);
      expect(c.passRate, 0.8);
    });

    test('has no pass rate when nothing ran', () {
      expect(
        const EvalCategory(
          name: 'x',
          passed: 0,
          failed: 0,
          skipped: 3,
        ).passRate,
        isNull,
      );
    });

    test('a negative count is read as none', () {
      const c = EvalCategory(name: 'x', passed: -4, failed: 5);

      expect(c.attempted, 5);
      expect(c.passRate, 0);
    });
  });

  group('the numbers', () {
    test('the overall rate is over every task that ran', () {
      expect(overallPassRate(_categories), closeTo(255 / 300, 1e-9));
      expect(overallPassRate(const []), isNull);
    });

    test('sorting puts the worst first and the empty last', () {
      final names = [for (final c in sortedByPassRate(_categories)) c.name];

      expect(names, ['Math', 'Coding', 'Safety', 'Empty']);
    });

    test('sorting is stable for equal rates', () {
      final sorted = sortedByPassRate(const [
        EvalCategory(name: 'a', passed: 5, failed: 5),
        EvalCategory(name: 'b', passed: 1, failed: 1),
      ]);

      expect([for (final c in sorted) c.name], ['a', 'b']);
    });

    test('the Wilson interval holds the rate and stays inside 0..1', () {
      final (low, high) = wilsonInterval(80, 100);

      expect(low, lessThan(0.8));
      expect(high, greaterThan(0.8));
      expect(low, greaterThan(0.7));
      expect(high, lessThan(0.88));

      final (l3, h3) = wilsonInterval(3, 3);
      expect(h3, closeTo(1, 1e-9));
      expect(l3, lessThan(0.5));

      final (l0, h0) = wilsonInterval(0, 5);
      expect(l0, 0);
      expect(h0, lessThan(0.6));
    });

    test('with nothing attempted the interval is everything', () {
      expect(wilsonInterval(0, 0), (0.0, 1.0));
      expect(wilsonInterval(5, 0), (0.0, 1.0));
    });

    test('a bigger sample gives a tighter interval', () {
      final small = wilsonInterval(8, 10);
      final large = wilsonInterval(800, 1000);

      expect(large.$2 - large.$1, lessThan(small.$2 - small.$1));
    });
  });

  group('the bars', () {
    test('grow to fill the box, up to a limit', () {
      const chart = EvalBreakdownChart(categories: []);

      // 200 px for four rows: 200 - 26 header over 4, less the 8 gap.
      expect(chart.barHeightFor(200, 4, 26), closeTo(34, 1e-9));
      // Plenty of room: held at the largest.
      expect(chart.barHeightFor(900, 4, 26), 34);
    });

    test('shrink to a least height when there are too many', () {
      const chart = EvalBreakdownChart(categories: []);

      expect(chart.barHeightFor(100, 40, 26), 18);
    });

    test('with nothing to draw they keep the least height', () {
      const chart = EvalBreakdownChart(categories: []);

      expect(chart.barHeightFor(200, 0, 26), 18);
    });
  });

  group('the widget', () {
    Widget host(Widget chart) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 500, height: 300, child: chart)),
    );

    testWidgets('reports a row, worst first, with its interval', (
      tester,
    ) async {
      EvalTouchDetails? touched;
      await tester.pumpWidget(
        host(
          EvalBreakdownChart(
            categories: _categories,
            onTouch: (d) => touched = d,
          ),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      final origin = tester.getTopLeft(find.byType(EvalBreakdownChart));
      // Header 26 px, then bars of 18 with 8 between: the first row's centre.
      await gesture.moveTo(origin + const Offset(200, 26 + 9));

      expect(touched, isNotNull);
      expect(touched!.category.name, 'Math');
      expect(touched!.index, 0);
      expect(touched!.low, lessThan(0.71));
      expect(touched!.high, greaterThan(0.71));
    });

    testWidgets('keeps the given order when asked', (tester) async {
      EvalTouchDetails? touched;
      await tester.pumpWidget(
        host(
          EvalBreakdownChart(
            categories: _categories,
            sortWorstFirst: false,
            threshold: 0.8,
            onTouch: (d) => touched = d,
          ),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      final origin = tester.getTopLeft(find.byType(EvalBreakdownChart));
      await gesture.moveTo(origin + const Offset(200, 26 + 9));

      expect(touched?.category.name, 'Safety');
    });

    testWidgets('survives nothing, long names and more rows than fit', (
      tester,
    ) async {
      await tester.pumpWidget(host(const EvalBreakdownChart(categories: [])));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        host(
          EvalBreakdownChart(
            categories: [
              for (var i = 0; i < 40; i++)
                EvalCategory(
                  name: 'A very long category name number $i',
                  passed: i,
                  failed: 40 - i,
                ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
