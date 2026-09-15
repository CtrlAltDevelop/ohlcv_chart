# Price axis

```dart
KChartWidget(
  candles,
  ChartColors(),
  timeFrame: const Duration(days: 1),
  priceAxisScale: PriceAxisScale.logarithmic,
);
```

![The same market indexed to 100, and with the axis inverted](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/price-scales.png)

## Scale types

| `PriceAxisScale` | Behaviour |
| --- | --- |
| `linear` | Equal price differences use equal space (default) |
| `logarithmic` | Equal ratios use equal space, so 10 → 20 spans the same distance as 100 → 200. Falls back to linear while the visible low is zero or negative |
| `percentage` | Linear spacing; the axis, crosshair label and current-price tag show change from the oldest visible candle |
| `indexedTo100` | The oldest visible candle is 100 and other values are relative to it, as with an index or rebased performance series. Ticks fall on round index levels (100, 105, 110) |

![A logarithmic price axis stepping by ratio, under an EMA](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/log-axis.png)

Indicator panes can use their own logarithmic or percentage scale through
`Indicator.scale`. The volume pane is always linear.

## Ticks and gridlines

The axis selects round values and draws gridlines at them, so labels and lines
always align.

- **Linear:** steps of 1, 2, 2.5 or 5 times a power of ten.
- **Logarithmic:** steps of 1, 2 and 5 within each power of ten, falling back to
  linear steps when the range spans less than a decade.
- **Percentage:** round percentages, converted to prices.

`ChartStyle.gridRows` controls tick density. It is not a row count: roughly half
as many round values as `gridRows` fall within the window. Increase it for more
ticks, decrease it for fewer.

```dart
KChartWidget(
  candles,
  ChartColors(),
  timeFrame: const Duration(days: 1),
  chartStyle: const ChartStyle(gridRows: 12),
);
```

The tick functions are exported for custom axes: `niceStep`, `niceTicks` and
`niceLogTicks` for values, and `niceTimeStep`, `timeBucket` and `startsNewDay`
for times.

## Secondary axis

`secondaryPriceAxisScale` adds a second axis on the opposite side — for example,
percentage change alongside prices:

```dart
KChartWidget(
  candles,
  ChartColors(),
  secondaryPriceAxisScale: PriceAxisScale.percentage,
  chartStyle: const ChartStyle(
    priceAxisWidth: 56,
    secondaryPriceAxisWidth: 56,
  ),
  // ...
)
```

- The secondary axis computes its own round values (for example +2%, +4%, +6%).
- Gridlines follow the primary axis only.
- Both gutters together are limited to half the chart width. Set
  `secondaryPriceAxisWidth: 0` to draw its labels over the candles instead.
- The crosshair, current-price tag and other readouts continue to use
  `priceAxisScale`.

## Price formatting

`fixedLength` sets the number of decimal places. For full control, use
`priceFormatter`, which works like `dateFormatter` on the date axis:

```dart
KChartWidget(
  candles,
  ChartColors(),
  priceFormatter: (price) => NumberFormat.currency(symbol: r'$').format(price),
  // ...
)
```

`priceFormatter` applies to axis labels, the crosshair price label, the
current-price tag, high, low and signal tags, and the OHLC legend. `percentage`
and `indexedTo100` axes format their own values and do not use it.

Drawing labels are set separately through each drawing's `title`.

## Inversion and markers

```dart
KChartWidget(
  candles,
  ChartColors(),
  timeFrame: const Duration(days: 1),
  invertPriceAxis: true,     // higher prices lower down
  showAverageClose: true,    // a level at the mean close over the window
  showHighLowOnAxis: true,   // the window's extremes tagged where they read
);
```

- **`invertPriceAxis`** places higher prices lower on the axis, which is useful
  for yields and spreads. Candles, drawings, crosshair, orders and comparisons
  all follow. Candle colours are based on prices, so rising candles keep their
  up colour. Logarithmic axes remain logarithmic.
- **`showAverageClose`** draws a dashed line at the mean close of the visible
  window, using `ChartColors.avgColor`. It updates as you pan.
- **`showHighLowOnAxis`** labels the visible high and low on the price axis, in
  the axis's units.

## Locking the scale

By default, the axis refits to the visible candles, so its values change while
scrolling. `lockPriceScale` keeps the axis at a fixed range instead.

```dart
KChartWidget(
  data,
  ChartColors(),
  lockPriceScale: true,
  // ...
)
```

- The lock applies to the range currently shown, so enabling it does not move
  the chart.
- Candles scroll beneath a stable scale, which makes it easier to read levels
  and prevents jumps when loading history through `onLoadMore`.
- Visible high and low markers, including `showHighLowOnAxis`, continue to track
  the visible window.
- A locked axis can still be dragged and zoomed, relative to its locked range.

`resetPriceScale` refits the axis to the visible candles and locks it again:

```dart
chart.resetPriceScale();  // refit to the window, then hold there
```

Reset the scale when switching instruments. New candles and live updates do not
require a reset.

### Following price beyond the locked range

`lockedScaleFollowsPrice` expands the locked range just enough to keep the newest
candle visible:

```dart
KChartWidget(
  data,
  ChartColors(),
  lockPriceScale: true,
  lockedScaleFollowsPrice: true,
  // ...
)
```

The range only expands and never refits to the window, so the axis remains
stable while scrolling. It considers only the newest candle, and only while it is
visible.

Without this option, levels outside the locked range are not hidden: their
labels are pinned to the nearest edge and marked with an arrow.

## Label gutter

By default, price labels are drawn over the candles. `ChartStyle.priceAxisWidth`
reserves a gutter so that candles, grid, indicator panes and the date axis stop
before the labels:

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

- A width of about 56 fits four to five digits at the default text size.
- The gutter is limited to half the chart width.
- The plot is clipped to its bounds, so candles, indicators and the
  current-price line do not overlap the gutter.
- The gutter is part of the drag area for scaling.
- The default of `0` keeps labels drawn over the candles.

## Dragging the scale

By default, the axis fits the visible candles to the full height. Users can
adjust this directly:

- **Drag down** on the price labels to stretch the range (taller candles).
- **Drag up** to compress it.
- **Drag vertically** on the chart to pan once the scale is adjusted.
- **Double-tap** the labels to refit.

```dart
KChartWidget(
  candles,
  ChartColors(),
  timeFrame: const Duration(days: 1),
  controller: chart,
  priceScaleDrag: true,
  chartStyle: const ChartStyle(priceScaleGripWidth: 52),
);
```

`priceScaleGripWidth` sets the width of the drag area from the labelled edge,
limited to half the chart. Horizontal drags in this area still scroll the chart,
taps still select, and the area is disabled while a drawing tool is active so
drawings can be placed near the axis.

The same actions are available on the controller:

```dart
chart.stretchPrice();     // taller candles, as dragging down does
chart.compressPrice();    // flatter ones
chart.setPriceZoom(2.5);  // or straight to a factor
chart.resetPriceScale();  // back to fitting the window
chart.priceZoom;          // 1 while the chart is fitting it itself
```

Set `priceScaleDrag: false` to always fit the axis to the visible candles.

Note the distinction from [locking the scale](#locking-the-scale):
`priceScaleDrag: false` means the axis **always** refits, while
`lockPriceScale: true` means it **never** refits. They can be combined to keep a
fixed range that users cannot adjust.

---

[← All docs](README.md) · [Package README](../README.md)
