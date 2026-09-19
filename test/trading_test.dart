import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart/src/renderer/chart_painter.dart';

import 'test_utils.dart';

/// Sixty candles, calculated, walking 100 up and back down.
List<KLineEntity> _candles() {
  final data = candles(rampThenFall(60));
  DataUtil.calculate(data);
  return data;
}

Widget _chart(
  List<KLineEntity> data, {
  List<ChartOrder> orders = const [],
  List<ChartPosition> positions = const [],
  void Function(ChartOrder, double)? onOrderMoved,
  void Function(ChartOrder, double)? onOrderDragged,
  ValueChanged<ChartOrder>? onOrderTapped,
  ValueChanged<ChartPosition>? onPositionTapped,
  ChartStyle? style,
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
        chartStyle: style ?? ChartStyle(),
        orders: orders,
        positions: positions,
        onOrderMoved: onOrderMoved,
        onOrderDragged: onOrderDragged,
        onOrderTapped: onOrderTapped,
        onPositionTapped: onPositionTapped,
      ),
    ),
  ),
);

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

/// Where on screen a price falls in the candle area.
Offset _atPrice(WidgetTester tester, double price, {double dx = 200}) {
  final painter = _painterOf(tester);
  final chart = tester.getTopLeft(find.byType(KChartWidget));
  return chart + Offset(dx, painter.getMainY(price));
}

/// A price comfortably inside the visible range.
double _middlePrice(WidgetTester tester) {
  final renderer = _painterOf(tester).mMainRenderer;
  return (renderer.maxValue + renderer.minValue) / 2;
}

void main() {
  group('what an order says about itself', () {
    test('the tag names the side, the kind and the size', () {
      expect(
        const ChartOrder(
          id: '1',
          price: 100,
          side: TradeSide.buy,
          quantity: 2,
        ).tagText,
        'Buy 2',
      );
      expect(
        const ChartOrder(id: '1', price: 100, side: TradeSide.sell).tagText,
        'Sell',
      );
      expect(
        const ChartOrder(
          id: '1',
          price: 100,
          side: TradeSide.sell,
          kind: OrderKind.stop,
          quantity: 0.5,
        ).tagText,
        'Stop 0.5',
      );
      expect(
        const ChartOrder(
          id: '1',
          price: 100,
          side: TradeSide.buy,
          kind: OrderKind.takeProfit,
        ).tagText,
        'Target',
      );
      expect(
        const ChartOrder(
          id: '1',
          price: 100,
          side: TradeSide.buy,
          kind: OrderKind.stopLimit,
        ).tagText,
        'Stop limit',
      );
    });

    test('a label of its own wins over all of that', () {
      expect(
        const ChartOrder(
          id: '1',
          price: 100,
          side: TradeSide.buy,
          quantity: 2,
          label: 'Ladder 3',
        ).tagText,
        'Ladder 3',
      );
    });

    test('moving one leaves everything else about it alone', () {
      const order = ChartOrder(
        id: '7',
        price: 100,
        side: TradeSide.sell,
        kind: OrderKind.stop,
        quantity: 3,
        draggable: false,
      );
      final moved = order.movedTo(120);

      expect(moved.price, 120);
      expect(moved.id, '7');
      expect(moved.side, TradeSide.sell);
      expect(moved.kind, OrderKind.stop);
      expect(moved.quantity, 3);
      expect(moved.draggable, isFalse);
    });

    test('two orders over the same thing are equal', () {
      const a = ChartOrder(id: '1', price: 100, side: TradeSide.buy);
      const b = ChartOrder(id: '1', price: 100, side: TradeSide.buy);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(a.movedTo(101)));
    });
  });

  group('what a position says about itself', () {
    test('the tag names the side, the size and what it is worth', () {
      expect(
        const ChartPosition(
          id: '1',
          entryPrice: 100,
          side: TradeSide.buy,
          quantity: 2,
        ).tagText,
        'Long 2',
      );
      expect(
        const ChartPosition(
          id: '1',
          entryPrice: 100,
          side: TradeSide.sell,
        ).tagText,
        'Short',
      );
      expect(
        const ChartPosition(
          id: '1',
          entryPrice: 100,
          side: TradeSide.buy,
          quantity: 2,
          unrealisedPnl: 140,
        ).tagText,
        'Long 2  +140',
      );
      expect(
        const ChartPosition(
          id: '1',
          entryPrice: 100,
          side: TradeSide.buy,
          unrealisedPnl: -12.5,
        ).tagText,
        'Long  -12.5',
      );
    });

    test('a P&L that is not a round number is cut to two decimals', () {
      // What an account actually reports: enough precision to be wrong on a
      // tag, which is only as wide as the text in it.
      expect(
        const ChartPosition(
          id: '1',
          entryPrice: 100,
          side: TradeSide.buy,
          quantity: 1,
          unrealisedPnl: 1415.882446718504,
        ).tagText,
        'Long 1  +1415.88',
      );
      // Nothing trailing: neither a zero nor the point itself.
      expect(
        const ChartPosition(
          id: '1',
          entryPrice: 100,
          side: TradeSide.buy,
          unrealisedPnl: 0.001,
        ).tagText,
        'Long  +0',
      );
      expect(
        const ChartOrder(
          id: '1',
          price: 100,
          side: TradeSide.buy,
          quantity: 0.3333333333,
        ).tagText,
        'Buy 0.33',
      );
    });

    test('it says whether it is making money, or that it does not know', () {
      expect(
        const ChartPosition(
          id: '1',
          entryPrice: 1,
          side: TradeSide.buy,
          unrealisedPnl: 5,
        ).isUp,
        isTrue,
      );
      expect(
        const ChartPosition(
          id: '1',
          entryPrice: 1,
          side: TradeSide.buy,
          unrealisedPnl: -5,
        ).isUp,
        isFalse,
      );
      expect(
        const ChartPosition(id: '1', entryPrice: 1, side: TradeSide.buy).isUp,
        isNull,
      );
    });

    test('two positions over the same thing are equal', () {
      const a = ChartPosition(id: '1', entryPrice: 100, side: TradeSide.buy);
      const b = ChartPosition(id: '1', entryPrice: 100, side: TradeSide.buy);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(
          const ChartPosition(id: '1', entryPrice: 101, side: TradeSide.buy),
        ),
      );
    });

    test('each side has a colour of its own', () {
      final colors = ChartColors();
      expect(colors.tradeColor(TradeSide.buy), colors.buyColor);
      expect(colors.tradeColor(TradeSide.sell), colors.sellColor);
    });
  });

  group('drawing them', () {
    testWidgets('orders and positions draw without complaint', (tester) async {
      await tester.pumpWidget(_chart(_candles()));
      final price = _middlePrice(tester);

      await tester.pumpWidget(
        _chart(
          _candles(),
          orders: [
            ChartOrder(id: '1', price: price, side: TradeSide.buy, quantity: 2),
            ChartOrder(
              id: '2',
              price: price + 5,
              side: TradeSide.sell,
              kind: OrderKind.stop,
            ),
          ],
          positions: [
            ChartPosition(
              id: 'p',
              entryPrice: price - 5,
              side: TradeSide.buy,
              quantity: 1,
              unrealisedPnl: 12,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_painterOf(tester).orders, hasLength(2));
      expect(_painterOf(tester).openPositions, hasLength(1));
    });

    testWidgets('a line outside the window is left out', (tester) async {
      await tester.pumpWidget(
        _chart(
          _candles(),
          orders: const [
            // Nowhere near the candles.
            ChartOrder(id: '1', price: 100000, side: TradeSide.buy),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('grabbing an order', () {
    testWidgets('a press near the line picks it up', (tester) async {
      await tester.pumpWidget(_chart(_candles()));
      final price = _middlePrice(tester);
      final order = ChartOrder(id: '1', price: price, side: TradeSide.buy);

      await tester.pumpWidget(
        _chart(_candles(), orders: [order], onOrderMoved: (_, _) {}),
      );
      await tester.pumpAndSettle();

      expect(_painterOf(tester).orderAt(_atPrice(tester, price)), same(order));
      // Well away from the line, nothing is grabbed.
      expect(_painterOf(tester).orderAt(_atPrice(tester, price + 40)), isNull);
    });

    testWidgets('an order that cannot be dragged cannot be grabbed', (
      tester,
    ) async {
      await tester.pumpWidget(_chart(_candles()));
      final price = _middlePrice(tester);

      await tester.pumpWidget(
        _chart(
          _candles(),
          orders: [
            ChartOrder(
              id: '1',
              price: price,
              side: TradeSide.buy,
              draggable: false,
            ),
          ],
          onOrderMoved: (_, _) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(_painterOf(tester).orderAt(_atPrice(tester, price)), isNull);
    });

    testWidgets('the nearer of two close lines is the one grabbed', (
      tester,
    ) async {
      await tester.pumpWidget(_chart(_candles()));
      final price = _middlePrice(tester);
      final near = ChartOrder(id: 'near', price: price, side: TradeSide.buy);
      final far = ChartOrder(id: 'far', price: price + 1, side: TradeSide.sell);

      await tester.pumpWidget(
        _chart(
          _candles(),
          orders: [far, near],
          onOrderMoved: (_, _) {},
          style: ChartStyle(trading: const TradingStyle(grabTolerance: 200)),
        ),
      );
      await tester.pumpAndSettle();

      expect(_painterOf(tester).orderAt(_atPrice(tester, price)), same(near));
    });

    testWidgets('a position line answers to a tap', (tester) async {
      await tester.pumpWidget(_chart(_candles()));
      final price = _middlePrice(tester);
      final tapped = <ChartPosition>[];
      final position = ChartPosition(
        id: 'p',
        entryPrice: price,
        side: TradeSide.buy,
      );

      await tester.pumpWidget(
        _chart(_candles(), positions: [position], onPositionTapped: tapped.add),
      );
      await tester.pumpAndSettle();

      await tester.tapAt(_atPrice(tester, price));
      await tester.pumpAndSettle();

      expect(tapped, [same(position)]);
    });

    testWidgets('a tap on an order line reports it', (tester) async {
      await tester.pumpWidget(_chart(_candles()));
      final price = _middlePrice(tester);
      final tapped = <ChartOrder>[];
      final order = ChartOrder(id: '1', price: price, side: TradeSide.buy);

      await tester.pumpWidget(
        _chart(_candles(), orders: [order], onOrderTapped: tapped.add),
      );
      await tester.pumpAndSettle();

      await tester.tapAt(_atPrice(tester, price));
      await tester.pumpAndSettle();

      expect(tapped, [same(order)]);
    });
  });

  group('dragging an order', () {
    testWidgets('the line follows the drag and reports where it landed', (
      tester,
    ) async {
      await tester.pumpWidget(_chart(_candles()));
      final price = _middlePrice(tester);
      final moved = <(String, double)>[];
      final dragged = <double>[];
      final order = ChartOrder(id: '1', price: price, side: TradeSide.buy);

      await tester.pumpWidget(
        _chart(
          _candles(),
          orders: [order],
          onOrderMoved: (o, p) => moved.add((o.id, p)),
          onOrderDragged: (_, p) => dragged.add(p),
        ),
      );
      await tester.pumpAndSettle();

      final from = _atPrice(tester, price);
      final gesture = await tester.startGesture(from);
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump();

      // Reported while dragging, and the line has followed.
      expect(dragged, isNotEmpty);
      expect(dragged.last, greaterThan(price), reason: 'dragged upwards');
      expect(
        _painterOf(tester).orders.single.price,
        closeTo(dragged.last, 1e-6),
      );
      // The order handed in is untouched: the chart does not amend it itself.
      expect(order.price, price);

      await gesture.up();
      await tester.pumpAndSettle();

      expect(moved, hasLength(1));
      expect(moved.single.$1, '1');
      expect(moved.single.$2, greaterThan(price));
      // And the line is back where the order still says it is.
      expect(_painterOf(tester).orders.single.price, price);
    });

    testWidgets('a press that goes nowhere is a tap, not a move', (
      tester,
    ) async {
      await tester.pumpWidget(_chart(_candles()));
      final price = _middlePrice(tester);
      final moved = <double>[];
      final tapped = <ChartOrder>[];
      final order = ChartOrder(id: '1', price: price, side: TradeSide.buy);

      await tester.pumpWidget(
        _chart(
          _candles(),
          orders: [order],
          onOrderMoved: (_, p) => moved.add(p),
          onOrderTapped: tapped.add,
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(_atPrice(tester, price));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(moved, isEmpty);
      expect(tapped, hasLength(1));
    });

    testWidgets('without a move callback the drag scrolls the chart instead', (
      tester,
    ) async {
      await tester.pumpWidget(_chart(_candles()));
      final price = _middlePrice(tester);

      await tester.pumpWidget(
        _chart(
          _candles(),
          orders: [ChartOrder(id: '1', price: price, side: TradeSide.buy)],
        ),
      );
      await tester.pumpAndSettle();

      // No onOrderMoved, so nothing is grabbed and the gesture is the chart's.
      await tester.dragFrom(_atPrice(tester, price), const Offset(80, 0));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('the trading style', () {
    test('copyWith replaces only what it is given', () {
      const style = TradingStyle(lineWidth: 2, grabTolerance: 20);
      final wider = style.copyWith(lineWidth: 3);

      expect(wider.lineWidth, 3);
      expect(wider.grabTolerance, 20);
      expect(wider.orderStyle, style.orderStyle);
    });

    test('the chart style carries one, and copies it across', () {
      final style = ChartStyle();
      expect(style.trading.orderStyle, LineStyle.dashed);

      final custom = style.copyWith(
        trading: const TradingStyle(orderStyle: LineStyle.dotted),
      );
      expect(custom.trading.orderStyle, LineStyle.dotted);
      // And everything else survived the copy.
      expect(custom.eventMarkRadius, style.eventMarkRadius);
    });
  });
}
