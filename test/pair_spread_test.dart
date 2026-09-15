import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

DateTime _d(int day) => DateTime(2026, 9, day);

final _points = [
  PairPoint(time: _d(1), a: 10, b: 5),
  PairPoint(time: _d(2), a: 12, b: 6),
  PairPoint(time: _d(3), a: 11, b: 5),
  PairPoint(time: _d(4), a: 13, b: 6.5),
];

void main() {
  group('the spread', () {
    test('series pair up on the times both have', () {
      final aligned = alignPairSeries(
        [(time: _d(2), value: 2), (time: _d(1), value: 1), (time: _d(3), value: 3)],
        [(time: _d(1), value: 10), (time: _d(3), value: 30)],
      );
      expect([for (final p in aligned) p.time], [_d(1), _d(3)]);
      expect(aligned.last.a, 3);
      expect(aligned.last.b, 30);
    });

    test('ratio, log ratio and difference', () {
      expect(pairSpread(_points), [2, 2, 2.2, 2]);
      expect(
        pairSpread(_points, mode: PairSpreadMode.logRatio).first,
        closeTo(math.ln2, 1e-12),
      );
      expect(
        pairSpread(_points, mode: PairSpreadMode.difference, hedgeRatio: 2),
        [0, 0, 1, 0],
      );
      expect(
        pairSpread([PairPoint(time: _d(1), a: 1, b: 0)]).single.isNaN,
        isTrue,
      );
    });

    test('the hedge ratio is the least-squares slope', () {
      final points = [
        for (var i = 1; i <= 4; i++)
          PairPoint(time: _d(i), a: 2.0 * i + 1, b: i.toDouble()),
      ];
      expect(pairHedgeRatio(points), closeTo(2, 1e-12));
      expect(pairHedgeRatio(points.take(1).toList()), 1);
    });

    test('z-scores wait for a full window and treat a flat one as zero', () {
      final z = rollingZScore(const [1, 2, 3, 4, 5], 3);
      expect(z.take(2), [null, null]);
      expect(z[2], closeTo(1.2247, 1e-4));
      expect(rollingZScore(const [4, 4, 4], 2), [null, 0, 0]);
      expect(rollingZScore(const [1, double.nan, 3, 4], 2), [null, null, null, 1]);
    });

    test('signals enter at the threshold and exit on the way back', () {
      final signals = pairSignals(const [0, 2.5, 1, -0.1, -2.2, null, -1, 0.3]);
      expect(
        [for (final s in signals) (s.index, s.kind)],
        [
          (1, PairSignalKind.enterShort),
          (3, PairSignalKind.exit),
          (4, PairSignalKind.enterLong),
          (7, PairSignalKind.exit),
        ],
      );
      expect(
        pairSignals(const [2.5, 0.6, 0.4], exit: 0.5).last.kind,
        PairSignalKind.exit,
      );
    });
  });

  group('the layout', () {
    const bounds = Rect.fromLTWH(0, 0, 400, 200);

    test('panels split the height and points take a slot each', () {
      final layout = layOutPairSpread(
        _points,
        bounds,
        lookback: 2,
        zFraction: 0.5,
        gap: 0,
      );
      expect(layout.spreadRect, const Rect.fromLTWH(0, 0, 400, 100));
      expect(layout.zRect, const Rect.fromLTWH(0, 100, 400, 100));
      expect(layout.xOf(0), 50);
      expect(layout.indexAt(260), 2);
      expect(layout.indexAt(-10), 0);
      expect(layout.zY(0), 150);
      expect(layout.zLimit, greaterThanOrEqualTo(2.5));
      expect(layout.spreadMin, lessThan(2));
      expect(layout.spreadMax, greaterThan(2.2));
    });

    test('difference fits the hedge ratio when none is given', () {
      final points = [
        for (var i = 1; i <= 5; i++)
          PairPoint(time: _d(i), a: 3.0 * i, b: i.toDouble()),
      ];
      final layout = layOutPairSpread(
        points,
        bounds,
        mode: PairSpreadMode.difference,
      );
      for (final v in layout.spread) {
        expect(v, closeTo(0, 1e-9));
      }
    });

    test('nothing to show lays out nothing', () {
      expect(layOutPairSpread(const [], bounds).isEmpty, isTrue);
      expect(layOutPairSpread(_points, Rect.zero).isEmpty, isTrue);
      expect(PairSpreadLayout.empty.indexAt(10), isNull);
    });
  });

  group('the widget', () {
    testWidgets('draws, reports touches and takes its default height',
        (tester) async {
      PairSpreadTouchDetails? touched;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                PairSpreadChart(
                  points: _points,
                  lookback: 2,
                  onTouch: (d) => touched = d,
                  tooltipBuilder: (context, d) => Text('spread ${d.spread}'),
                  semanticLabel: 'Pair',
                ),
              ],
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(PairSpreadChart));
      expect(size.height, 280);

      final topLeft = tester.getTopLeft(find.byType(PairSpreadChart));
      const axis = 56.0;
      final gesture = await tester.startGesture(
        topLeft + Offset(axis + (size.width - axis) * 2.5 / 4, 60),
      );
      await tester.pump();
      expect(touched?.index, 2);
      expect(touched?.spread, 2.2);
      expect(touched?.zScore, isNotNull);
      expect(find.text('spread 2.2'), findsOneWidget);

      await gesture.up();
      await tester.pump();
      expect(touched, isNull);
    });

    testWidgets('animates and survives gaps and new points', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PairSpreadChart(
              points: [
                for (var i = 0; i < 60; i++)
                  PairPoint(
                    time: DateTime(2026).add(Duration(days: i)),
                    a: 100 + 5 * math.sin(i / 4),
                    b: i == 30 ? 0 : 50,
                  ),
              ],
              animationDuration: const Duration(milliseconds: 200),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PairSpreadChart(
              points: _points.take(1).toList(),
              mode: PairSpreadMode.difference,
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
