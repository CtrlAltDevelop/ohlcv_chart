import 'dart:ui' show PointerDeviceKind;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

const _trades = [
  TradeExcursion(pnl: 2, mae: 0.5, mfe: 2.5, label: 'a'),
  TradeExcursion(pnl: -1, mae: 1.2, mfe: 0.3, label: 'b'),
  TradeExcursion(pnl: 1, mae: 1.5, mfe: 1.8, label: 'c'),
  TradeExcursion(pnl: 0, mae: 0, mfe: 0, label: 'd'),
];

void main() {
  group('the statistics', () {
    test('count winners, losers and the averages', () {
      final stats = ExcursionStats.fromTrades(_trades);

      expect(stats.count, 4);
      expect(stats.winners, 2);
      expect(stats.losers, 1);
      expect(stats.averageAdverse, closeTo((0.5 + 1.2 + 1.5) / 4, 1e-9));
      expect(stats.averageFavourable, closeTo((2.5 + 0.3 + 1.8) / 4, 1e-9));
    });

    test('the edge ratio is the favourable move over the adverse one', () {
      final stats = ExcursionStats.fromTrades(_trades);

      expect(stats.edgeRatio, closeTo(4.6 / 3.2, 1e-9));
      expect(
        ExcursionStats.fromTrades(const [
          TradeExcursion(pnl: 1, mae: 0, mfe: 1),
        ]).edgeRatio,
        double.infinity,
      );
      expect(ExcursionStats.fromTrades(const []).edgeRatio, 0);
    });

    test('a trade that is not a number is skipped', () {
      final stats = ExcursionStats.fromTrades(const [
        TradeExcursion(pnl: double.nan, mae: 1, mfe: 1),
        TradeExcursion(pnl: 1, mae: 1, mfe: 2),
      ]);

      expect(stats.count, 1);
    });

    test('winnersStoppedAt counts the winners a stop would have cost', () {
      expect(winnersStoppedAt(_trades, 1.0), 1);
      expect(winnersStoppedAt(_trades, 0.5), 2);
      expect(winnersStoppedAt(_trades, 5), 0);
    });
  });

  group('the layout', () {
    const bounds = Rect.fromLTWH(0, 0, 200, 100);

    test('the range runs from zero to the longest excursion', () {
      final range = excursionRange(_trades, ExcursionKind.adverse);

      expect(range.minX, 0);
      expect(range.maxX, closeTo(1.5 * 1.08, 1e-9));
      expect(range.minY, lessThan(-1));
      expect(range.maxY, greaterThan(2));
    });

    test('a dot sits at its excursion across and its result up', () {
      final dots = layOutExcursions(
        _trades,
        bounds,
        kind: ExcursionKind.adverse,
        minX: 0,
        maxX: 2,
        minY: -2,
        maxY: 2,
      );

      expect(dots, hasLength(4));
      expect(dots[0].center, const Offset(50, 0));
      expect(dots[1].center, const Offset(120, 75));
    });

    test('the favourable kind reads the other excursion', () {
      final dots = layOutExcursions(
        _trades,
        bounds,
        kind: ExcursionKind.favourable,
        minX: 0,
        maxX: 2.5,
        minY: -2,
        maxY: 2,
      );

      expect(dots[0].center.dx, 200);
    });

    test('a trade that is not finite is left out, keeping its index', () {
      final dots = layOutExcursions(
        const [
          TradeExcursion(pnl: 1, mae: double.nan, mfe: 1),
          TradeExcursion(pnl: 1, mae: 1, mfe: 1),
        ],
        bounds,
        kind: ExcursionKind.adverse,
        minX: 0,
        maxX: 2,
        minY: 0,
        maxY: 2,
      );

      expect(dots.single.index, 1);
    });

    test('nothing to lay out, or no room, lays nothing out', () {
      expect(
        layOutExcursions(
          const [],
          bounds,
          kind: ExcursionKind.adverse,
          minX: 0,
          maxX: 1,
          minY: 0,
          maxY: 1,
        ),
        isEmpty,
      );
      expect(
        layOutExcursions(
          _trades,
          Rect.zero,
          kind: ExcursionKind.adverse,
          minX: 0,
          maxX: 1,
          minY: 0,
          maxY: 1,
        ),
        isEmpty,
      );
    });

    test('the nearest dot within reach is picked', () {
      final dots = layOutExcursions(
        _trades,
        bounds,
        kind: ExcursionKind.adverse,
        minX: 0,
        maxX: 2,
        minY: -2,
        maxY: 2,
      );

      expect(excursionDotAt(dots, const Offset(52, 3))?.index, 0);
      expect(excursionDotAt(dots, const Offset(0, 100), reach: 5), isNull);
    });
  });

  group('the widget', () {
    Widget host(Widget chart) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 400, height: 300, child: chart)),
    );

    testWidgets('draws, and reports a touch on a dot', (tester) async {
      ExcursionTouchDetails? touched;
      await tester.pumpWidget(
        host(
          MaeMfeChart(
            trades: _trades,
            xReferenceLines: const [1],
            onTouch: (d) => touched = d,
            tooltipBuilder: (context, d) => Text('${d.trade.label}'),
          ),
        ),
      );

      // The first trade's dot, worked out the way the chart lays it out: a
      // 400x300 box, 44 px of side axis and 32 px of bottom axis and title.
      final range = excursionRange(_trades, ExcursionKind.adverse);
      final x = 44 + 0.5 / range.maxX * (400 - 44);
      final y =
          (300 - 32) -
          (2 - range.minY) / (range.maxY - range.minY) * (300 - 32);
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      final origin = tester.getTopLeft(find.byType(MaeMfeChart));
      await gesture.moveTo(origin + Offset(x, y));

      expect(touched?.trade.label, 'a');
      await tester.pump();
      expect(find.text('a'), findsOneWidget);

      await gesture.moveTo(origin + const Offset(1, 299));
      await tester.pump();
      expect(touched, isNull);
    });

    testWidgets('fills a box with no height of its own', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(children: [MaeMfeChart(trades: _trades)]),
          ),
        ),
      );

      expect(tester.getSize(find.byType(MaeMfeChart)).height, 260);
    });
  });
}
