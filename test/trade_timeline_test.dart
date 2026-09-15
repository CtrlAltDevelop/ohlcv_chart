import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

final _t0 = DateTime(2026, 9, 1);
DateTime _h(int hours) => _t0.add(Duration(hours: hours));

final _trades = [
  TimelineTrade(lane: 'BTC', entryTime: _h(0), exitTime: _h(4), pnl: 100),
  TimelineTrade(
    lane: 'BTC',
    entryTime: _h(2),
    exitTime: _h(6),
    pnl: -50,
    side: TradeSide.sell,
  ),
  TimelineTrade(lane: 'ETH', entryTime: _h(4), exitTime: _h(8), pnl: 20),
];

void main() {
  group('the helpers', () {
    test('the range runs from the first entry to the last exit', () {
      final range = tradeTimelineRange(_trades);
      expect(range.start, _h(0));
      expect(range.end, _h(8));
    });

    test('an open trade runs to now', () {
      final trades = [TimelineTrade(entryTime: _h(1))];
      expect(tradeTimelineRange(trades, now: _h(5)).end, _h(5));
      expect(trades.single.endAt(_h(5)), _h(5));
      // Without a now, a lone open trade still gets a span to draw in.
      expect(
        tradeTimelineRange(trades).end,
        _h(1).add(const Duration(minutes: 1)),
      );
    });

    test('overlapping trades take separate rows, back-to-back ones share', () {
      expect(packTradeRows(_trades), [0, 1, 0]);
      expect(packTradeRows(const []), isEmpty);
    });

    test('exposure counts what is open, not doubling a hand-over', () {
      final steps = tradeTimelineExposure(_trades);
      expect(
        [for (final s in steps) s.count],
        [1, 2, 2, 1, 0],
      );
      expect(steps[2].time, _h(4));
    });
  });

  group('the layout', () {
    const bounds = Rect.fromLTWH(0, 0, 800, 200);
    TradeTimelineLayout layOut() =>
        layOutTradeTimeline(_trades, bounds, laneGap: 10, rowGap: 0);

    test('lanes appear in order, with the rows they need', () {
      final layout = layOut();
      expect([for (final l in layout.lanes) l.label], ['BTC', 'ETH']);
      expect([for (final l in layout.lanes) l.rowCount], [2, 1]);
      expect(layout.lanes[0].rect.height, 44);
      expect(layout.lanes[1].rect.top, 54);
    });

    test('bars run from entry to exit', () {
      final bars = layOut().bars;
      expect(bars[0].rect, const Rect.fromLTRB(0, 0, 400, 22));
      expect(bars[1].rect.left, 200);
      expect(bars[1].row, 1);
      expect(bars[2].lane, 1);
      expect(bars[2].rect.right, 800);
    });

    test('rows shrink to fit a short box', () {
      final layout = layOutTradeTimeline(
        _trades,
        const Rect.fromLTWH(0, 0, 800, 30),
        laneGap: 0,
        rowGap: 0,
      );
      expect(layout.bars.first.rect.height, 10);
    });

    test('trades outside the span are left out, the rest are cut to it', () {
      final layout =
          layOutTradeTimeline(_trades, bounds, start: _h(5), end: _h(9));
      expect([for (final b in layout.bars) b.index], [1, 2]);
      expect(layout.bars.first.rect.left, 0);
    });

    test('a quick trade still has width, and can be touched', () {
      final layout = layOutTradeTimeline(
        [
          TimelineTrade(entryTime: _h(0), exitTime: _h(10)),
          TimelineTrade(
            entryTime: _h(5),
            exitTime: _h(5).add(const Duration(seconds: 1)),
          ),
        ],
        bounds,
        minBarWidth: 2,
      );
      final quick = layout.bars[1];
      expect(quick.rect.width, 2);
      expect(
          layout
              .barAt(Offset(quick.rect.left + 3, quick.rect.center.dy))
              ?.index,
          1);
    });

    test('times and positions convert both ways', () {
      final layout = layOut();
      expect(layout.xOf(_h(2)), 200);
      expect(layout.timeAt(600), _h(6));
      expect(layout.barAt(const Offset(100, 10))?.index, 0);
      expect(layout.barAt(const Offset(100, 190)), isNull);
    });

    test('nothing to show lays out nothing', () {
      expect(layOutTradeTimeline(const [], bounds).isEmpty, isTrue);
      expect(layOutTradeTimeline(_trades, Rect.zero).isEmpty, isTrue);
    });
  });

  group('the widget', () {
    testWidgets('draws, reports touches and takes its default height',
        (tester) async {
      TradeTimelineTouchDetails? touched;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TradeTimelineChart(
                  trades: _trades,
                  onTouch: (d) => touched = d,
                  tooltipBuilder: (context, d) => Text('pnl ${d.trade.pnl}'),
                  semanticLabel: 'Trades',
                ),
              ],
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(TradeTimelineChart));
      expect(size.height, 240);

      final topLeft = tester.getTopLeft(find.byType(TradeTimelineChart));
      const labels = 72.0;
      final gesture = await tester.startGesture(
        topLeft + Offset(labels + (size.width - labels) / 16, 10),
      );
      await tester.pump();
      expect(touched?.trade.pnl, 100);
      expect(find.text('pnl 100.0'), findsOneWidget);

      await gesture.up();
      await tester.pump();
      expect(touched, isNull);
    });

    testWidgets('animates, and survives open trades and changes',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TradeTimelineChart(
              trades: _trades,
              animationDuration: const Duration(milliseconds: 200),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TradeTimelineChart(
              trades: [TimelineTrade(entryTime: _h(1), pnl: 12)],
              now: _h(3),
              showExposure: false,
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
