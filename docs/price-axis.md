# Price axis

```dart
KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: false,
  watermarkAssetPath: 'assets/logo.svg',
  timeFrame: const Duration(days: 1),
  priceAxisScale: PriceAxisScale.logarithmic,
);
```

![The same market indexed to 100, and with the axis inverted](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/price-scales.png)

- `linear` — equal prices take equal space. The default.
- `logarithmic` — equal *ratios* take equal space, so 10 → 20 covers as much of
  the axis as 100 → 200. A window whose low is zero or negative has no logarithm
  to space by and falls back to linear until it scrolls back into positive
  prices.
- `percentage` — spaced linearly, but the axis, the crosshair's price label and
  the current-price tag read as the move away from the oldest candle in view.
- `indexedTo100` — the same information said the other way about: the oldest
  candle in view reads 100 and everything else is quoted against it, which is
  how an index or a rebased performance series is usually written. The axis
  marks round index levels — 100, 105, 110 — and converts them back to the
  prices they stand for.

![A logarithmic price axis stepping by ratio, under an EMA](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/log-axis.png)

An indicator pane can be logarithmic or read as a percentage in its own right;
see `Indicator.scale`. The volume pane always stays linear.

The axis picks round values and the grid is ruled where they land, so a label
and its line always agree. A linear axis steps by 1, 2, 2.5 or 5 times a power
of ten; a logarithmic one steps by ratio — 1, 2 and 5 through each power of ten
— falling back to linear steps over a range too narrow to hold a decade; a
percentage axis chooses round percentages and converts them back to prices.

`ChartStyle.gridRows` is how densely that happens. It is not a row count: about
half as many round values as `gridRows` land inside the window, so raise it for
a denser axis and lower it for a sparser one.

```dart
KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: false,
  watermarkAssetPath: 'assets/logo.svg',
  timeFrame: const Duration(days: 1),
  chartStyle: const ChartStyle(gridRows: 12),
);
```

The same arithmetic is exported, for a caller drawing an axis of its own beside
the chart: `niceStep`, `niceTicks` and `niceLogTicks` for values, `niceTimeStep`,
`timeBucket` and `startsNewDay` for times.

## Reading it the other way, and other extras

```dart
KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: false,
  watermarkAssetPath: 'assets/logo.svg',
  timeFrame: const Duration(days: 1),
  invertPriceAxis: true,     // higher prices lower down
  showAverageClose: true,    // a level at the mean close over the window
  showHighLowOnAxis: true,   // the window's extremes tagged where they read
);
```

`invertPriceAxis` flips the axis, which is what a chart of a yield or a spread
wants — and what a trader who thinks in the other direction reaches for.
Everything follows: the candles, the drawings, the crosshair, the orders and the
comparisons all read off the same flipped axis, and a rising candle is still
coloured as one, because the colour comes from the prices rather than from the
pixels. A logarithmic axis inverts and stays logarithmic.

`showAverageClose` draws a dashed level at the mean close of the visible window —
the level a mean-reversion read is taken against — coloured from
`ChartColors.avgColor`, and it moves as the chart is panned, since it describes
the window rather than the whole history.

`showHighLowOnAxis` tags the window's high and low on the axis, in whatever units
the axis reads in. The leader lines already point at the candles that set them;
this says what to read them off the axis as.

## Dragging the scale

The axis fits the window by default, so the candles always fill the height —
which is what you want until you want to look closer. Dragging down the strip
the price labels sit in stretches the range and makes the candles taller;
dragging up compresses it. Once the scale is being held that way, a vertical
drag anywhere on the candles slides the window up and down, and a double-tap on
the labels hands the axis back to the chart.

```dart
KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: false,
  watermarkAssetPath: 'assets/logo.svg',
  timeFrame: const Duration(days: 1),
  controller: chart,
  priceScaleDrag: true,
  chartStyle: const ChartStyle(priceScaleGripWidth: 52),
);
```

`priceScaleGripWidth` is how far in from the labelled side that strip reaches,
and it is never more than half the chart. A drag through it still scrolls the
chart sideways, a tap still selects what is under it, and while a drawing tool
is armed it steps aside completely — so a line can still be placed against the
axis.

The same three moves are on the controller, for a chart driven from a toolbar:

```dart
chart.stretchPrice();     // taller candles, as dragging down does
chart.compressPrice();    // flatter ones
chart.setPriceZoom(2.5);  // or straight to a factor
chart.resetPriceScale();  // back to fitting the window
chart.priceZoom;          // 1 while the chart is fitting it itself
```

Set `priceScaleDrag: false` to keep the axis fitted to the window whatever the
user does, which is the older behaviour.

---

[← All docs](README.md) · [Package README](../README.md)
