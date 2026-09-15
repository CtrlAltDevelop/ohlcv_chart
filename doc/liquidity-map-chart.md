# Liquidity map

`LiquidityMapChart` shows where the stops are. Leveraged positions do not close
quietly: each one is a market order waiting at a price. Stacked up the price
axis, they show where a move would find fuel — which is the thing a depth chart
cannot say, because those orders are not in the book yet.

```dart
LiquidityMapChart(
  bins: liquidityBins(levels, binCount: 48),
  currentPrice: 68400,
);
```

The chart fills its constraints. In a box with no height it takes
`defaultHeight`.

## Levels and buckets

A `LiquidityLevel` is a position, or a cluster of them, that would be closed at
one price: its `price`, its `size` in whatever unit you are counting, its
`side` — `LiquiditySide.long` for one that a fall closes, `short` for one a
rise closes — and optionally the `leverage` it was opened at, which is how
exchanges usually bucket these.

`liquidityBins(levels, binCount:, min:, max:)` buckets them into price bands.
Left without bounds, the range is the levels' own with a little air. It is the
same bucketing a volume profile uses, so a liquidity map and a profile drawn
over the same range line up band for band.

A `LiquidityBin` holds `longSize`, `shortSize` and the `levels` that fell in
it, plus `mid`, `total` and `imbalance` — -1 where the bucket is all long, 1
where it is all short.

## Reading it

Long liquidations grow in from the left of the middle line and shorts from the
right, so the two sides read apart at a glance: a wall of green below the price
is where a fall accelerates, a wall of red above is where a squeeze does.

Bars are scaled to the largest bucket, and the largest is labelled with its
size. That makes one chart's bars incomparable with another's, so pass
`largest` to pin the scale across reloads.

`layout.exposureTo(price)` is the point of the chart: everything that would be
liquidated between the current price and there — longs on the way down, shorts
on the way up. It needs `currentPrice` to be set; without it there is no line
drawn and nothing to measure from.

## Layout

`layOutLiquidityMap(bins, size:, ...)` is the layout on its own, without a
widget. It returns a `LiquidityMapLayout` with the `plotRect`, the price `min`
and `max`, the `largest` bucket the bars were scaled to, the `currentPrice` and
its `priceY`, and a `LiquidityBinLayout` per bucket holding its `rowRect`,
`longRect` and `shortRect`. `layout.yOf(price)` places a price and
`layout.binAt(point)` finds the bucket under a point. `progress` grows the bars
in, for a draw-in animation.

## Touch

`onBinTap` is called with a bucket when it is touched or dragged over, and with
null when the touch leaves. A card names the bucket's price, both sides' sizes
and what a move there would set off; `tooltipBuilder` replaces it.

## Styling

| Field | Default |
| --- | --- |
| `longColor`, `shortColor` | Green left of the middle, red right |
| `barGap` | 1 |
| `showAxis`, `axisWidth`, `axisSteps`, `priceFormatter` | The price axis |
| `sizeFormatter` | Writes the sizes in the card and the peak label |
| `priceLineColor`, `gridColor` | The current price, and the gridlines |
| `showPeakLabel` | The largest bucket's size, written on it |
| `animationDuration`, `animationCurve`, `animateOnMount` | The draw-in |

`semanticLabel` is what a screen reader announces for the chart.

## See also

- [Order-book heatmap](book-heatmap-chart.md) — resting liquidity over time
- [Market profile](market-profile-chart.md) — time at price, over the same bands
