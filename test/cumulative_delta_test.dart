import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

const _bounds = Rect.fromLTWH(0, 0, 400, 106);

List<DeltaBar> _bars(List<double> deltas, {List<double>? prices}) => [
      for (var i = 0; i < deltas.length; i++)
        DeltaBar(
          time: DateTime(2024).add(Duration(minutes: i)),
          delta: deltas[i],
          price: prices == null ? null : prices[i],
        ),
    ];

void main() {
  group('the maths', () {
    test('the running total adds the bars up', () {
      expect(cumulativeDelta(_bars([10, -4, 6])), [10, 6, 12]);
      expect(cumulativeDelta(const []), isEmpty);
    });

    test('a delta that is not a number is skipped, not carried', () {
      expect(cumulativeDelta(_bars([10, double.nan, 5])), [10, 10, 15]);
    });

    test('footprint bars become delta bars, keeping the close', () {
      final bars = deltaBarsFromFootprint([
        FootprintBar(
          time: DateTime(2024),
          close: 101,
          levels: const [FootprintLevel(price: 100, askVolume: 7)],
        ),
      ]);
      expect(bars.single.delta, 7);
      expect(bars.single.price, 101);
    });
  });

  group('divergences', () {
    test('a new high in price that delta did not follow is bearish', () {
      final marks = deltaDivergences(
        _bars(
          [10, 10, 10, -30, 1],
          prices: [1, 2, 3, 2, 4],
        ),
        lookback: 4,
      );
      expect(marks.single.index, 4);
      expect(marks.single.kind, DeltaDivergence.bearish);
    });

    test('a new low in price that delta did not follow is bullish', () {
      final marks = deltaDivergences(
        _bars(
          [-10, -10, -10, 30, -1],
          prices: [4, 3, 2, 3, 1],
        ),
        lookback: 4,
      );
      expect(marks.single.kind, DeltaDivergence.bullish);
    });

    test('price and delta agreeing is no divergence', () {
      final marks = deltaDivergences(
        _bars([1, 2, 3, 4, 5], prices: [1, 2, 3, 4, 5]),
        lookback: 4,
      );
      expect(marks, isEmpty);
    });

    test('bars without a price, and short runs, are left alone', () {
      expect(deltaDivergences(_bars([1, 2, 3]), lookback: 2), isEmpty);
      expect(
        deltaDivergences(_bars([1, 2], prices: [1, 2]), lookback: 5),
        isEmpty,
      );
    });
  });

  group('the layout', () {
    test('the panels split the height, the gap taken out', () {
      final layout = layOutCumulativeDelta(
        _bars([1, -1]),
        _bounds,
        histogramFraction: 0.25,
        gap: 6,
      );
      expect(layout.lineRect.height, 75);
      expect(layout.barsRect.top, 81);
      expect(layout.barsRect.height, 25);
    });

    test('the line runs across the middle of each column', () {
      final layout = layOutCumulativeDelta(_bars([1, 1, 1, 1]), _bounds);
      expect(layout.line.map((p) => p.dx), [50, 150, 250, 350]);
    });

    test('zero is always on the total axis', () {
      final layout = layOutCumulativeDelta(_bars([5, 5]), _bounds);
      expect(layout.minTotal, 0);
      expect(layout.maxTotal, 10);
    });

    test('a buying bar stands on zero and a selling bar hangs from it', () {
      final layout = layOutCumulativeDelta(
        _bars([10, -5]),
        _bounds,
        histogramFraction: 0.5,
        gap: 0,
        barSpacing: 0,
      );
      expect(layout.largestDelta, 10);
      expect(layout.bars[0].bottom, layout.zeroY);
      expect(layout.bars[0].height, closeTo(26.5, 0.001));
      expect(layout.bars[1].top, layout.zeroY);
      expect(layout.bars[1].height, closeTo(13.25, 0.001));
    });

    test('nothing to show, or no room, lays out nothing', () {
      expect(layOutCumulativeDelta(const [], _bounds).isEmpty, isTrue);
      expect(layOutCumulativeDelta(_bars([1]), Rect.zero).isEmpty, isTrue);
    });

    test('the nearest bar to a position is found', () {
      final layout = layOutCumulativeDelta(_bars([1, 1, 1, 1]), _bounds);
      expect(layout.indexAt(0), 0);
      expect(layout.indexAt(260), 2);
      expect(layout.indexAt(9999), 3);
    });
  });

  group('the widget', () {
    testWidgets('draws, reports touches and takes its default height',
        (tester) async {
      CumulativeDeltaTouchDetails? touched;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CumulativeDeltaChart(
                  bars: _bars([10, -4, 6], prices: [1, 2, 3]),
                  onTouch: (d) => touched = d,
                  tooltipBuilder: (context, d) => Text('card ${d.total}'),
                  semanticLabel: 'Cumulative delta',
                ),
              ],
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(CumulativeDeltaChart));
      expect(size.height, 220);

      final topLeft = tester.getTopLeft(find.byType(CumulativeDeltaChart));
      final gesture = await tester.startGesture(
        topLeft + Offset(size.width - 1, size.height / 2),
      );
      await tester.pump();
      expect(touched?.index, 2);
      expect(touched?.total, 12);
      expect(find.text('card 12.0'), findsOneWidget);

      await gesture.up();
      await tester.pump();
      expect(touched, isNull);
    });

    testWidgets('draws itself in and survives its data changing',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CumulativeDeltaChart(
              bars: _bars([1, -2, 3, -4], prices: [1, 2, 3, 4]),
              animationDuration: const Duration(milliseconds: 200),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CumulativeDeltaChart(
              bars: _bars([5]),
              showDivergences: false,
              animationDuration: const Duration(milliseconds: 200),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
