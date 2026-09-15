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

`DepthChart` plots each level's `vol` as provided, so values must be cumulative.
`DepthEntity.bids` and `DepthEntity.asks` convert raw order-book levels: they
sort by price and accumulate outwards from the best bid and best ask, so the two
curves meet at the mid price.

## Display modes

![The combined curve and bars beside the order-book ladder](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/depth-modes.png)

`mode` selects one of four views of the same data:

| `DepthChartMode` | Rendering |
| --- | --- |
| `cumulative` | Cumulative depth on each side of the mid price (default); shows market liquidity |
| `histogram` | One bar per price level showing its individual size; highlights large orders |
| `combined` | Cumulative curves with histogram bars behind them |
| `ladder` | Table of price, size and cumulative total, with a bar behind each row |

```dart
DepthChart(
  DepthEntity.bids(rawBids),
  DepthEntity.asks(rawAsks),
  mode: DepthChartMode.combined,
  scale: DepthScale.log,
  zoom: 0.05, // only the book within 5% of the mid
);
```

## Scale and zoom

- `scale` sets the volume axis: `linear`, `log` (useful when far levels are much
  larger than near ones) or `percent` (share of the maximum cumulative total).
- `zoom` limits the chart to levels within a fraction of the mid price. If no
  levels remain, the full book is shown.

## Per-level data

Individual level sizes are derived from the cumulative curves, so no additional
input is required. Use `DepthBook.fromCurves` to access them directly:

```dart
final book = DepthBook.fromCurves(bids, asks, zoom: 0.05);
for (final level in book.bids) {
  print('${level.price}: ${level.size} resting of ${level.cumulative}');
}
```

`DepthLadder` is also available as a standalone widget, for example to show the
ladder next to a chart:

```dart
DepthLadder(bids, asks, levels: 12, barsShowTotal: false);
```

The long-press readout shows both the size at the selected level and the
cumulative total.

## Ratio bar

`showRatioBar: true` adds a `DepthRatioBar` below either widget. It shows the
total bid and ask volume as two proportional segments, each labelled with its
percentage, indicating the balance of resting orders. Changes animate smoothly.

```dart
DepthChart(
  DepthEntity.bids(rawBids),
  DepthEntity.asks(rawAsks),
  zoom: 0.05,
  showRatioBar: true, // the split of the book within 5% of the mid
);
```

The ratio uses the same levels as the widget above it, including `zoom`, so the
figures match the chart. This matters because the balance near the mid price
often differs from the balance of the full book.

Use `DepthRatioBar` directly to place it elsewhere, measure a different range,
or change the animation duration:

```dart
DepthRatioBar(bids, asks, zoom: 0.01, duration: Duration.zero);
```

| Setting | Purpose |
| --- | --- |
| `DepthChartStyle.ratioBarHeight` | Bar thickness and end radius |
| `DepthChartStyle.ratioFontSize` | Percentage label size |
| `upColor` / `dnColor` | Bid and ask colours |

When both sides are empty (for example, while data is loading), the bar shows a
grey track labelled `--` and keeps its height.

---

[← All docs](README.md) · [Package README](../README.md)
