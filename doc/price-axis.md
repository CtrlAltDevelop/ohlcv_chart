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

## Writing the prices yourself

`fixedLength` is how many decimals a price is written to. `priceFormatter`
takes the writing over, the way `dateFormatter` does on the date axis:

```dart
KChartWidget(
  candles,
  ChartColors(),
  priceFormatter: (price) => NumberFormat.currency(symbol: r'$').format(price),
  // ...
)
```

It writes every price the chart says: the axis labels, the crosshair's price
label, the current-price tag, the high, low and signal tags, and the OHLC
legend. An axis that reads out a move rather than a price — `percentage`,
`indexedTo100` — writes that move itself and does not ask.

Drawings keep their own labels, which are yours to set through each one's
`title`.

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

## Keeping it still while the chart scrolls

The axis fits the candles in the window, so scrolling rescales it: drag back
through a trend and every number on the axis changes as the window moves.
`lockPriceScale` holds it at one range instead.

```dart
KChartWidget(
  data,
  ChartColors(),
  lockPriceScale: true,
  // ...
)
```

It locks onto the range the axis was already showing, so turning it on does not
move the chart. From then on the candles move under a scale that stays where it
is — which is what reading a level off the axis while scrolling needs, and what
paging in history through `onLoadMore` needs in order not to jump.

Only the scale is held. The window's own high and low are still measured, so
`showHighLowOnAxis` and the high and low markers keep pointing at the candles
that set them, and a locked axis can still be dragged and zoomed — from the
range it is held at rather than the window's.

`resetPriceScale` hands the axis back to the chart: it refits to whatever is on
screen and holds there afresh.

```dart
chart.resetPriceScale();  // refit to the window, then hold there
```

Because the range is held until it is reset, a chart that switches to another
instrument should reset it — a range from one instrument means nothing on
another. Paging in candles and live ticks need nothing, which is the point.

### When the market trades past the locked range

A held range is a range the market can leave. `lockedScaleFollowsPrice` grows
it just enough to keep the newest candle on the chart:

```dart
KChartWidget(
  data,
  ChartColors(),
  lockPriceScale: true,
  lockedScaleFollowsPrice: true,
  // ...
)
```

It only ever grows, and never refits to the window, so the axis still sits
still while the chart is scrolled. Only the newest candle counts, and only
while it is in view — growing the axis to swallow the history a scroll moves
over would undo the lock a little at a time.

Left off, a price outside the range is not lost either: a level the axis cannot
reach has its label pinned to the edge it went past, marked with an arrow,
rather than being drawn outside the candle area where it cannot be seen.

## Holding a gutter back for it

By default the price labels are drawn over the candles, and the candles scroll
underneath them. `ChartStyle.priceAxisWidth` holds a gutter back instead: the
candles, the grid, the indicator panes and the date axis all stop short of it,
and the labels sit in it on their own.

```dart
KChartWidget(
  data,
  ChartColors(),
  chartStyle: const ChartStyle(priceAxisWidth: 56),
  // Which side it is held back on follows the labels.
  verticalTextAlignment: VerticalTextAlignment.right,
  // ...
)
```

56 or so suits four or five digits at the default text size. The gutter is
never allowed past half the width, so a narrow chart is still mostly candles.

The plot is clipped to its own bounds, so nothing — a candle at the edge of the
window, an indicator line, the now-price level — spills into the gutter, and
the axis reads the same however far the chart is scrolled. Pressing the labels
still grabs the scale, as below; the gutter counts as part of the axis strip.

Left at 0, the default, nothing changes and the labels are drawn over the
candles as they always were.

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

That is the opposite of [locking it](#keeping-it-still-while-the-chart-scrolls),
which is worth keeping straight: `priceScaleDrag: false` means the axis *always*
refits to the window, and `lockPriceScale: true` means it *never* does. The two
can be combined — an axis held at one range that the user cannot drag off it.

---

[← All docs](README.md) · [Package README](../README.md)
