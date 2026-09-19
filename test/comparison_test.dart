import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart/src/renderer/chart_painter.dart';

import 'test_utils.dart';

DateTime _at(int minute) =>
    DateTime.utc(2024, 1, 1).add(Duration(minutes: minute));

/// Sixty candles, calculated, one a minute.
List<KLineEntity> _candles([List<double>? closes]) {
  final data = candles(closes ?? rampThenFall(60));
  DataUtil.calculate(data);
  return data;
}

Widget _chart(
  List<KLineEntity> data,
  List<ComparisonSeries> comparisons, {
  ChartColors? colors,
}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: 500,
      height: 600,
      child: KChartWidget(
        data,
        colors ?? ChartColors(),
        isTrendLine: false,
        timeFrame: const Duration(minutes: 15),
        showNowPrice: false,
        comparisons: comparisons,
      ),
    ),
  ),
);

/// The painter the chart is currently drawing with.
ChartPainter _painterOf(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find
        .descendant(
          of: find.byType(KChartWidget),
          matching: find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is ChartPainter,
          ),
        )
        .first,
  );
  return paint.painter! as ChartPainter;
}

void main() {
  group('lining a comparison up with the candles', () {
    test('each candle takes the last point at or before its own time', () {
      final data = _candles();
      final series = ComparisonSeries(
        label: 'ETH',
        points: [(time: _at(10), value: 50), (time: _at(20), value: 60)],
      );

      final values = alignComparison(data, series);

      expect(values[0], isNull, reason: 'nothing before the first point');
      expect(values[9], isNull);
      expect(values[10], 50);
      expect(values[15], 50, reason: 'held until the next point arrives');
      expect(values[20], 60);
      expect(values[59], 60, reason: 'and held to the end');
    });

    test('a series handed over out of order still lines up', () {
      final data = _candles();
      final series = ComparisonSeries(
        label: 'ETH',
        points: [(time: _at(20), value: 60), (time: _at(10), value: 50)],
      );

      expect(series.points.first.time, _at(10));
      expect(alignComparison(data, series)[15], 50);
    });

    test('no points is no values', () {
      final data = _candles();
      final values = alignComparison(
        data,
        ComparisonSeries(label: 'ETH', points: const []),
      );

      expect(values, hasLength(data.length));
      expect(values.every((v) => v == null), isTrue);
    });

    test('no candles is nothing at all', () {
      expect(
        alignComparison(
          const [],
          ComparisonSeries(label: 'ETH', points: [(time: _at(0), value: 1)]),
        ),
        isEmpty,
      );
    });

    test('a comparison can be built straight from another set of candles', () {
      final other = _candles([for (var i = 0; i < 10; i++) 200.0 + i]);
      final series = ComparisonSeries.ofCandles(label: 'ETH', candles: other);

      expect(series.points, hasLength(10));
      expect(series.points.first.value, 200);
      expect(series.points.last.value, 209);
      expect(series.isEmpty, isFalse);
    });

    test('resolving keeps each comparison in its own place', () {
      final data = _candles();
      final resolved = resolveComparisons(data, [
        ComparisonSeries(label: 'A', points: [(time: _at(0), value: 1)]),
        ComparisonSeries(label: 'B', points: [(time: _at(0), value: 2)]),
      ]);

      expect(resolved, hasLength(2));
      expect(resolved.first.ordinal, 0);
      expect(resolved.last.ordinal, 1);
      expect(resolved.first.valueAt(5), 1);
      expect(resolved.last.valueAt(5), 2);
      expect(resolved.first.valueAt(-1), isNull);
      expect(resolved.first.valueAt(9999), isNull);
    });
  });

  group('rebasing a comparison', () {
    ResolvedComparison resolvedOf(
      List<KLineEntity> data,
      List<double> values, {
      ComparisonScale scale = ComparisonScale.percent,
    }) {
      final series = ComparisonSeries(
        label: 'ETH',
        scale: scale,
        points: [
          for (final (i, value) in values.indexed) (time: _at(i), value: value),
        ],
      );
      return ResolvedComparison(
        series: series,
        values: alignComparison(data, series),
      );
    }

    test('it is pinned to the main series at the left of the window', () {
      // Main goes 100, 101, 102…; the comparison 50, 51, 52…
      final data = _candles([for (var i = 0; i < 10; i++) 100.0 + i]);
      final resolved = resolvedOf(data, [
        for (var i = 0; i < 10; i++) 50.0 + i,
      ]);

      final anchor = comparisonAnchor(resolved, data, 0, 9)!;
      expect(anchor.value, 50);
      expect(anchor.price, 100, reason: "the main series' close there");

      // Both start together, and the comparison's proportional move is applied
      // to the main price: 52/50 is +4%, so 100 becomes 104.
      expect(comparisonPriceAt(resolved, 0, anchor), closeTo(100, 1e-9));
      expect(comparisonPriceAt(resolved, 2, anchor), closeTo(104, 1e-9));
    });

    test('panning the window moves the pin with it', () {
      final data = _candles([for (var i = 0; i < 10; i++) 100.0 + i]);
      final resolved = resolvedOf(data, [
        for (var i = 0; i < 10; i++) 50.0 + i,
      ]);

      final later = comparisonAnchor(resolved, data, 5, 9)!;
      expect(later.value, 55);
      expect(later.price, 105);
      expect(comparisonPriceAt(resolved, 5, later), closeTo(105, 1e-9));
    });

    test('a comparison on its own prices ignores the pin entirely', () {
      final data = _candles([for (var i = 0; i < 10; i++) 100.0 + i]);
      final resolved = resolvedOf(data, [
        for (var i = 0; i < 10; i++) 50.0 + i,
      ], scale: ComparisonScale.price);

      expect(comparisonAnchor(resolved, data, 0, 9), isNull);
      expect(comparisonPriceAt(resolved, 3, null), 53);
    });

    test('nothing is drawn until there is something to pin to', () {
      final data = _candles();
      final series = ComparisonSeries(
        label: 'ETH',
        points: [(time: _at(30), value: 50)],
      );
      final resolved = ResolvedComparison(
        series: series,
        values: alignComparison(data, series),
      );

      // The window ends before the comparison starts.
      expect(comparisonAnchor(resolved, data, 0, 10), isNull);
      expect(comparisonPriceAt(resolved, 5, null), isNull);

      final anchor = comparisonAnchor(resolved, data, 0, 59)!;
      expect(anchor.value, 50);
      // Still nothing at a candle the comparison says nothing about.
      expect(comparisonPriceAt(resolved, 5, anchor), isNull);
      expect(comparisonPriceAt(resolved, 35, anchor), isNotNull);
    });

    test('a value of zero cannot be measured against', () {
      final data = _candles([for (var i = 0; i < 10; i++) 100.0 + i]);
      final resolved = resolvedOf(data, [0, 0, 50, 55, 60, 65, 70, 75, 80, 85]);

      // The first two candles cannot be a base, so the third is.
      final anchor = comparisonAnchor(resolved, data, 0, 9)!;
      expect(anchor.value, 50);
      expect(anchor.price, 102);
    });
  });

  group('a comparison on the chart', () {
    testWidgets('the price scale is stretched to hold it', (tester) async {
      // The comparison doubles while the main series barely moves, so the
      // scale has to open up to fit it.
      final data = _candles([for (var i = 0; i < 30; i++) 100.0]);

      await tester.pumpWidget(_chart(data, const []));
      final alone = _painterOf(tester).mMainRenderer.maxValue;

      await tester.pumpWidget(
        _chart(data, [
          ComparisonSeries(
            label: 'ETH',
            points: [
              for (var i = 0; i < 30; i++) (time: _at(i), value: 50.0 + i * 5),
            ],
          ),
        ]),
      );
      final together = _painterOf(tester).mMainRenderer.maxValue;

      expect(together, greaterThan(alone));
    });

    testWidgets('it reads out its move in the legend', (tester) async {
      final data = _candles([for (var i = 0; i < 30; i++) 100.0]);
      await tester.pumpWidget(
        _chart(data, [
          ComparisonSeries(
            label: 'ETH',
            points: [
              for (var i = 0; i < 30; i++) (time: _at(i), value: 50.0 + i),
            ],
          ),
        ]),
      );

      // The legend is painted, not a widget, so what is asserted is that the
      // chart made room for the extra row and drew without complaint.
      expect(tester.takeException(), isNull);
      final painter = _painterOf(tester);
      expect(painter.comparisons, hasLength(1));
      expect(painter.comparisonAnchors, hasLength(1));
      expect(painter.comparisonAnchors.first, isNotNull);
    });

    testWidgets('several are drawn, each in its own colour', (tester) async {
      final data = _candles();
      final colors = ChartColors();

      await tester.pumpWidget(
        _chart(data, [
          ComparisonSeries(
            label: 'A',
            points: [for (var i = 0; i < 60; i++) (time: _at(i), value: 50.0)],
          ),
          ComparisonSeries(
            label: 'B',
            points: [for (var i = 0; i < 60; i++) (time: _at(i), value: 70.0)],
            color: const Color(0xFF00FF00),
          ),
        ], colors: colors),
      );

      final renderer = _painterOf(tester).mMainRenderer;
      expect(renderer.comparisons, hasLength(2));
      expect(
        renderer.colorOfComparison(renderer.comparisons.first),
        colors.getComparisonColor(0),
      );
      expect(
        renderer.colorOfComparison(renderer.comparisons.last),
        const Color(0xFF00FF00),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty comparison draws nothing and breaks nothing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _chart(_candles(), [
          ComparisonSeries(label: 'nothing', points: const []),
        ]),
      );

      expect(tester.takeException(), isNull);
      expect(_painterOf(tester).comparisonAnchors.single, isNull);
    });

    testWidgets('a comparison added later is lined up again', (tester) async {
      final data = _candles();
      await tester.pumpWidget(_chart(data, const []));
      expect(_painterOf(tester).comparisons, isEmpty);

      await tester.pumpWidget(
        _chart(data, [
          ComparisonSeries(
            label: 'ETH',
            points: [for (var i = 0; i < 60; i++) (time: _at(i), value: 50.0)],
          ),
        ]),
      );

      expect(_painterOf(tester).comparisons, hasLength(1));
      expect(_painterOf(tester).comparisons.single.valueAt(5), 50);
    });

    testWidgets('a comparison over a line chart still draws', (tester) async {
      final data = _candles();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              height: 600,
              child: KChartWidget(
                data,
                ChartColors(),
                isTrendLine: false,
                timeFrame: const Duration(minutes: 15),
                showNowPrice: false,
                chartType: ChartType.line,
                comparisons: [
                  ComparisonSeries(
                    label: 'ETH',
                    points: [
                      for (var i = 0; i < 60; i++) (time: _at(i), value: 50.0),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('a comparison is compared by value', () {
    test('two built from the same points are equal', () {
      ComparisonSeries of() => ComparisonSeries(
        label: 'ETH',
        points: [(time: _at(0), value: 1), (time: _at(1), value: 2)],
      );

      expect(of(), of());
      expect(of().hashCode, of().hashCode);
    });

    test('a different label, colour or scale is a different comparison', () {
      final base = ComparisonSeries(
        label: 'ETH',
        points: [(time: _at(0), value: 1)],
      );

      expect(
        base,
        isNot(
          ComparisonSeries(label: 'BTC', points: [(time: _at(0), value: 1)]),
        ),
      );
      expect(
        base,
        isNot(
          ComparisonSeries(
            label: 'ETH',
            points: [(time: _at(0), value: 1)],
            scale: ComparisonScale.price,
          ),
        ),
      );
      expect(
        base,
        isNot(
          ComparisonSeries(label: 'ETH', points: [(time: _at(0), value: 2)]),
        ),
      );
    });

    test('the palette repeats rather than running out', () {
      final colors = ChartColors();
      expect(
        colors.getComparisonColor(0),
        colors.getComparisonColor(colors.comparisonColors.length),
      );
    });

    test('an empty palette falls back to something visible', () {
      final colors = ChartColors()..comparisonColors = const [];
      expect(colors.getComparisonColor(0), colors.defaultTextColor);
    });
  });
}
