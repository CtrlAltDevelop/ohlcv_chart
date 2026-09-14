# Orders and positions

`orders` and `positions` draw what the account actually holds: a line the full
width of the chart, tagged on the axis side. These are not drawings — they come
from the venue rather than from the user, and they are not saved with a layout.

```dart
KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: false,
  timeFrame: const Duration(minutes: 15),
  positions: [
    ChartPosition(
      id: '4471',
      entryPrice: 63_900,
      side: TradeSide.buy,
      quantity: 1.5,
      unrealisedPnl: 812.40,
    ),
  ],
  orders: [
    ChartOrder(id: '17', price: 64_500, side: TradeSide.sell, quantity: 1.5,
        kind: OrderKind.takeProfit),
    ChartOrder(id: '18', price: 62_800, side: TradeSide.sell, quantity: 1.5,
        kind: OrderKind.stop),
  ],
  onOrderDragged: (order, price) => setState(() => preview = price),
  onOrderMoved: (order, price) => broker.amend(order.id, price),
  onOrderTapped: (order) => showOrderSheet(order),
  onPositionTapped: (position) => showPositionSheet(position),
);
```

![A working order and an open position, each tagged on the axis](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/trading.png)

**Drag to modify.** Press an order's line and drag it: the line follows the
pointer, `onOrderDragged` fires all the way so a readout can follow it, and
`onOrderMoved` fires once on release with the price it landed at. The chart never
amends the order itself — it draws what you hand it, so the line snaps back
unless the new price comes round in the next build. That is what you want: the
venue gets the last word. `draggable: false` pins a line down, and an order with
no `onOrderMoved` is not grabbable at all, so the gesture stays the chart's.

A tag reads itself from the side, the kind and the quantity — `Buy 0.5`,
`Stop 2`, `Long 1.5  +812.4` — and `label` overrides the lot. `unrealisedPnl` is
yours to work out: only you know the contract size, the fees and the currency.
Colours come from `ChartColors.buyColor` and `sellColor` unless the order names
its own, and `ChartStyle.trading` — a `TradingStyle` — sets the stroke, the
dashes and how near a line a press has to land.

---

[← All docs](README.md) · [Package README](../README.md)
