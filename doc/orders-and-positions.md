# Orders and positions

`orders` and `positions` display account data from your broker or exchange as
full-width lines labelled on the price axis. They are not drawings: they are not
user-editable shapes and are not saved with layouts.

```dart
KChartWidget(
  candles,
  ChartColors(),
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

## Modifying orders by drag

1. Press and drag an order line. The line follows the pointer, and
   `onOrderDragged` fires continuously for live previews.
2. On release, `onOrderMoved` fires once with the new price.
3. The chart does not modify the order. The line returns to its original price
   unless your app passes the updated order on the next build. This keeps your
   broker as the source of truth.

Set `draggable: false` to lock an individual order. Orders are not draggable
when `onOrderMoved` is not provided.

## Labels and styling

- Labels are generated from side, kind and quantity — for example `Buy 0.5`,
  `Stop 2` or `Long 1.5  +812.4`. Use `label` to override.
- `unrealisedPnl` is supplied by your app, since contract size, fees and
  currency are account-specific.
- Colours default to `ChartColors.buyColor` and `sellColor`, and can be set per
  order.
- `ChartStyle.trading` (a `TradingStyle`) configures stroke width, dash pattern
  and the hit-test distance.

---

[← All docs](README.md) · [Package README](../README.md)
