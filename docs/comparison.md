# Comparing a second instrument

Hand `comparisons` a list of `ComparisonSeries` and each is drawn as a line over
the candles. By default it is *rebased*: pinned to the main series at the left
edge of the visible window, so the two lines start together and diverge by how
differently they moved. That is what comparing two instruments means — relative
performance, not price — and panning the chart moves the pin along with the
window, so what is read is always the move over what is on screen.

```dart
KChartWidget(
  btcCandles,
  ChartColors(),
  comparisons: [
    ComparisonSeries.ofCandles(label: 'ETH', candles: ethCandles),
    ComparisonSeries(
      label: 'DXY',
      points: [for (final p in dollarIndex) (time: p.time, value: p.close)],
      color: Colors.tealAccent,
      style: LineStyle.dashed,
    ),
  ],
);
```

![A second instrument rebased over the candles](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/comparison.png)

`ComparisonScale.price` draws it at its own prices on the same axis instead,
which is right where the two are quoted in the same units — a future against its
spot, two tenors of one curve — and misleading where they are not.

Points are matched to candles by time rather than by position, so a compared
instrument on a different bar still lines up: each candle takes the last point
at or before its own time, and holds it until the next one arrives. A gap breaks
the line rather than drawing across it, and candles before the comparison starts
draw nothing at all. The price scale opens up to hold whatever the comparison
does, and each one reads out its own move as a percentage on a legend row of its
own. Colours come from `ChartColors.comparisonColors`, taken in turn, unless the
series names its own.

The arithmetic is exported if you would rather do the drawing yourself:
`alignComparison` lines a series up against a list of candles,
`comparisonAnchor` works out where a rebased one is pinned over a window, and
`comparisonPriceAt` maps one value to the price it draws at.

---

[← All docs](README.md) · [Package README](../README.md)
