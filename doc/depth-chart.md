# Depth chart

![Cumulative bid and ask depth](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/depth.png)

```dart
DepthChart(
  DepthEntity.bids(rawBids),
  DepthEntity.asks(rawAsks),
  baseUnit: 2,
  quoteUnit: 6,
);
```

The chart plots each rung's `vol` as given, so it must be a running total.
`DepthEntity.bids` and `DepthEntity.asks` sort raw order-book rungs by price and
accumulate them in the right direction — from the best bid downwards and the best
ask upwards — which is what makes the two curves meet at the mid price.

## Modes

![The combined curve and bars beside the order-book ladder](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/depth-modes.png)

`mode` chooses what the book looks like, and all four read the same data:

| `DepthChartMode` | What it draws |
| --- | --- |
| `cumulative` | The running total either side of the mid — the default, and the shape that shows how hard the book is to move through |
| `histogram` | One bar per level, each the size resting on that rung, so the individual walls stand out |
| `combined` | The curves with those bars behind them |
| `ladder` | The numbers: price, size and running total per row, with a bar behind each |

```dart
DepthChart(
  DepthEntity.bids(rawBids),
  DepthEntity.asks(rawAsks),
  mode: DepthChartMode.combined,
  scale: DepthScale.log,
  zoom: 0.05, // only the book within 5% of the mid
);
```

`scale` spaces the volume axis — `linear`, `log` for a book whose far side dwarfs
the near one, or `percent` to label it as a share of the deepest total — and
`zoom` narrows the chart to the levels near the mid, where the trading is. A zoom
so tight that nothing would be left falls back to the whole book rather than to
an empty chart.

Each rung's own size is recovered from the cumulative curves by differencing, so
nothing extra has to be passed in. `DepthBook.fromCurves` does that on its own if
you want the levels for something else:

```dart
final book = DepthBook.fromCurves(bids, asks, zoom: 0.05);
for (final level in book.bids) {
  print('${level.price}: ${level.size} resting of ${level.cumulative}');
}
```

The ladder is also a widget in its own right, for putting the numbers beside a
chart rather than instead of it:

```dart
DepthLadder(bids, asks, levels: 12, barsShowTotal: false);
```

The long-press readout names the size resting on the rung under the finger as
well as the running total out to it.

---

[← All docs](README.md) · [Package README](../README.md)
