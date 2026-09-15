# Series charts

`SeriesChart` plots numeric x/y data — for example, balance per day, sign-ups
per month or profit per trade — for dashboards, wallets and reports. Where
`KChartWidget` is designed for OHLC candles over time, `SeriesChart` supports
lines, areas, bars and scatter plots, multiple series, configurable axes, custom
tooltips, a range selector for long data sets, and animated updates.

![A return split at zero, profit bars, deposits and withdrawals with a tooltip, and a balance sparkline — all SeriesChart](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/series-charts.png)

```dart
SeriesChart(
  series: [
    LineSeries.values(
      balances,                       // List<double?>, placed at x = 0, 1, 2 …
      color: purple,
      curve: LineCurve.monotone,
      fill: SeriesFill.fade(purple),
    ),
  ],
  xAxis: SeriesXAxis(labels: dayNames),
  yAxis: SeriesYAxis(formatter: formatUsd),
);
```

All other parameters are optional; the defaults produce a clean, readable
chart. The sections below describe each part.

## Series

A chart takes a list of `PlotSeries`, drawn in order with the first series at
the bottom. Line, bar and scatter series can be combined in one chart.

Points are `SeriesPoint(x, y)`, ordered by ascending x. For a plain list of
values, the `.values` constructors place them at `x = 0, 1, 2, …`. A `null`
value creates a gap: lines break and bars are omitted.

### Lines

```dart
LineSeries(
  points: [SeriesPoint(0, 12), SeriesPoint(1, 18), SeriesPoint(2, null), …],
  label: l10n.balance,           // named by the default tooltip
  color: purple,
  width: 2,                      // 0 draws no line: with `dot`, a scatter plot
  curve: LineCurve.monotone,
  dashPattern: [6, 4],           // null draws solid
  roundCap: true,
  gradient: someGradient,        // paints the stroke instead of `color`
  negativeColor: red,            // below `baseline`, split exactly where it crosses
  baseline: 0,
  fill: SeriesFill.fade(purple),
  dot: SeriesDot(radius: 2),
  dotBuilder: (index, point) => index == touched ? SeriesDot(radius: 3) : null,
);
```

`curve` sets how points are connected:

| `LineCurve` | Rendering |
| --- | --- |
| `linear` | Straight segments |
| `smooth` | Smooth curve through all points; may overshoot peaks (`fl_chart`'s `isCurved`) |
| `monotone` | Smooth curve that never overshoots adjacent points (`isCurved` + `preventCurveOverShooting`) |
| `step` | Holds each value until the next point; `stepPosition` sets where the step occurs — `0` at the first point, `0.5` midway, `1` at the second |

`shadow` draws a blurred copy of the line beneath it.

### Fills

`SeriesFill` fills the area between the line and its `baseline`, or the bottom
of the plot when `toBaseline` is `false`. Fills anchored to the baseline never
cross it.

- **Above the baseline**, `gradient` (or `color`) spans from the line's peak to
  the baseline, fading out at the baseline.
- **Below the baseline**, `negativeGradient` (or `negativeColor`) spans in the
  opposite direction. If unset, the upper gradient is mirrored, so both halves
  fade away from the line.

```dart
// Green above zero, red below, each fading towards zero.
LineSeries.values(
  roi,
  color: green,
  negativeColor: red,
  curve: LineCurve.monotone,
  fill: SeriesFill.fade(green, negativeColor: red, opacity: .24),
);
```

### Bars

```dart
BarSeries.values(
  profits,
  color: green,
  negativeColor: red,            // or colorBuilder: (index, point) => …
  baseline: 0,                   // bars grow from here, up or down
  radius: 3,                     // on the end away from the baseline
  widthFactor: .6,               // share of the room between two x values
  minWidth: 3.5,
  maxWidth: 12,
  width: null,                   // or a fixed width
  trackColor: faint,             // a full-height bar behind each one
  gradient: null,                // painted over each bar
);
```

Multiple bar series are grouped side by side at each x value. When a chart
contains bars, half a unit of padding is added to each end of the x range so
the first and last bars are fully visible.

Bar series with the same `stack` value are stacked instead: positive values
stack upwards and negative values downwards from the baseline, and only the
outermost bar is rounded. A stack occupies one group position, so stacks and
unstacked series can be combined.

```dart
SeriesChart(
  series: [
    BarSeries.values(deposits, color: green, stack: 'flow', radius: 0),
    BarSeries.values(withdrawals, color: red, stack: 'flow', radius: 3),
  ],
);
```

A point with `low` draws a floating bar between two values instead of from the
baseline, for ranges or waterfall charts:

```dart
BarSeries(
  points: [SeriesPoint(0, 8, low: 4), SeriesPoint(1, 11, low: 8)],
);
```

`border` outlines each bar, and `labelBuilder` adds a label beyond its end:

```dart
BarSeries.values(
  profits,
  border: const BorderSide(color: outline),
  labelBuilder: (index, point) => formatUsd(point.y!),
);
```

### Scatter

![Every trade as a dot, wins as circles and losses as crosses, one of them read out](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/series-scatter.png)

`ScatterSeries` draws one dot per point, positioned freely on both axes:

```dart
SeriesChart(
  series: [
    ScatterSeries(
      points: trades,
      dotBuilder: (index, point) => SeriesDot(
        radius: 3 + point.y! / 40,
        shape: point.y! < 0 ? SeriesDotShape.cross : SeriesDotShape.circle,
        color: point.y! < 0 ? red : green,
      ),
      labelBuilder: (index, point) => names[index],
    ),
  ],
  touch: const SeriesTouch(snap: SeriesTouchSnap.nearestPoint),
);
```

`SeriesTouchSnap.nearestPoint` selects the single nearest dot within
`SeriesTouch.threshold` pixels, instead of all values at that x. This is the
recommended mode for scatter plots.

Dot `shape` can be `circle`, `square`, `diamond` or `cross`.

### Error bars

Points can include error ranges on either axis:

```dart
SeriesPoint(
  0,
  5,
  yError: const SeriesErrorRange(0.4, 0.9),   // below, above
  xError: const SeriesErrorRange.symmetric(0.2),
);
```

All series types render error bars, styled by `errorBars: SeriesErrorBars(color,
width, capLength)`. Pass `errorBars: null` to hide them. The value range expands
to include them.

### Fill between lines

![A waterfall of floating bars beside a forecast with its band and its error bars](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/series-ranges.png)

The screenshot shows floating bars (left) and a `betweenFills` band with error
bars (right).

`betweenFills` shades the area between two series, such as a high and low, or a
forecast and actual values:

```dart
SeriesChart(
  series: [
    LineSeries.values(high, color: blue),
    LineSeries.values(low, color: blue),
  ],
  betweenFills: const [
    SeriesBetweenFill(from: 0, to: 1, color: Color(0x2200A3FF)),
  ],
);
```

## Horizontal orientation

![Stacked in and out bars running rightwards, months down the left, values along the bottom](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/series-horizontal.png)

`orientation: SeriesOrientation.horizontal` places the x axis vertically and
values horizontally, producing a horizontal bar chart:

```dart
SeriesChart(
  orientation: SeriesOrientation.horizontal,
  series: [BarSeries.values(byCategory, radius: 3)],
  xAxis: SeriesXAxis(labels: categoryNames),
);
```

All elements rotate accordingly: curves and steps follow the x axis, gradients
still point towards high values, and the crosshair and tooltip adapt to the
orientation. In horizontal mode, `SeriesAxisSide.left` places the value axis at
the bottom and `SeriesXSide.bottom` places the x labels on the left.

## Axes, grid and border

```dart
SeriesChart(
  series: …,
  xAxis: SeriesXAxis(
    labels: monthLabels,          // labels[i] names x = i; '' prints nothing
    interval: 2,                  // keep only every second one
    height: 22,                   // room held below the plot
    style: captionStyle,
  ),
  yAxis: SeriesYAxis(
    width: 30,                    // room beside the plot; charts sharing it line up
    side: SeriesAxisSide.left,
    formatter: formatUsdAxis,
    tickCount: 5,                 // or interval: 500, or ticks: [0, 500, 1000]
  ),
  grid: SeriesGrid(color: gray700, dashPattern: [4, 4], vertical: true),
  border: BorderSide(color: gray700),
);
```

The x axis determines label and vertical gridline positions in this order of
precedence:

1. `ticks`, if provided.
2. Each index with a non-blank entry in `labels`, filtered to multiples of
   `interval` if set. A label list containing only month starts is therefore
   spaced automatically.
3. Every `interval`.
4. Approximately `tickCount` round values.

Overlapping labels are omitted, and `fitInside` shifts the first and last labels
inwards so they are not clipped. `labelBuilder` generates a label from an x
value.

Both axes accept a `title`, drawn beyond the labels and rotated for vertical
axes. `SeriesXSide.top` places x labels above the plot, and
`SeriesAxisSide.right` places the value axis on the right.

```dart
SeriesChart(
  xAxis: SeriesXAxis(labels: monthLabels, title: l10n.month),
  yAxis: SeriesYAxis(formatter: formatUsdAxis, title: l10n.balance),
);
```

`SeriesXAxis.hidden`, `SeriesYAxis.hidden` and `SeriesGrid.none` remove each
element and its reserved space. Hiding all three produces a sparkline.

## Value range

By default, the x range spans all points and the value range fits the data,
with `yPadding` (10%) added above and below and then extended to round ticks.
Padding never crosses zero for data that is entirely positive or entirely
negative.

| Parameter | Description |
| --- | --- |
| `minX`, `maxX` | Fix the plot bounds. Set both to show a window of a longer series; the value range then fits the visible data. |
| `xPadding` | Padding on each side of the x range, in x units. |
| `minY`, `maxY` | Fix the value range. |
| `includeZero` | Always include zero. |
| `yPadding` | Padding above and below, as a fraction of the range. |
| `niceYRange` | Extend to round tick values (enabled by default). |

## Reference lines and bands

```dart
referenceLines: [
  SeriesReferenceLine.horizontal(0, color: gray600, dashPattern: [3, 3]),
  SeriesReferenceLine.horizontal(target, label: l10n.target, extendsRange: true),
  SeriesReferenceLine.vertical(todayIndex.toDouble(), label: l10n.today),
],
bands: [SeriesBand.vertical(5, 7, color: weekendShade)],
```

Reference lines are not interactive and are drawn beneath the series unless
`aboveSeries` is set. Horizontal lines only expand the value range when
`extendsRange` is `true`, so distant targets do not compress the data.

## Touch

```dart
SeriesChart(
  series: …,
  touch: SeriesTouch(
    trigger: SeriesTouchTrigger.longPress,   // press · longPress · tap · none
    hover: true,                             // a mouse shows it too
    line: SeriesCrosshairLine(color: gray600),
    horizontalLine: null,
    showMarkers: true,
    markerBuilder: (v) => SeriesDot(radius: 3, color: v.value < 0 ? red : green),
    tooltip: SeriesTooltip(
      placement: SeriesTooltipPlacement.beside,   // or above the point
      title: (details) => dateLabels[details.index],
      valueFormatter: (v) => formatUsd(v.value),
      backgroundColor: paper,
      borderColor: gray700,
    ),
  ),
  onTouch: (details) => setState(() => touched = details?.index),
);
```

| `SeriesTouchTrigger` | Behaviour |
| --- | --- |
| `press` | Shown while pressed or dragging; hidden on release. Matches `fl_chart`'s default. |
| `longPress` | Shown after a long press and follows the pointer, so swipes still scroll the page. |
| `tap` | Placed by tap and remains visible. Drag to move; tap the same point to clear. |
| Shown only by hover or the controller. |

The crosshair snaps to the nearest point. `onTouch` is called when it moves to
a different x, and with `null` when it is dismissed. `SeriesTouchDetails`
contains the x value (`index` for charts built from plain values) and, for each
series with a value at that x, the series, point, screen position and colour.

For a custom tooltip, provide `SeriesTooltip.builder`. The chart positions the
result beside the crosshair or above the point, within the chart bounds. Return
`null` from the builder, or pass `tooltip: null`, to hide the tooltip. Pass
`touch: null` to disable touch and hover entirely.

### Synchronised crosshair

![A balance panel over a profit panel, one crosshair marking the same day in both](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/series-panels.png)

`SeriesChartController` shows or clears the crosshair programmatically. Charts
that share a controller display the crosshair at the same x value — for example,
a balance panel above a profit panel:

```dart
final crosshair = SeriesChartController();

Column(children: [
  SizedBox(height: 200, child: SeriesChart(series: balance, controller: crosshair, …)),
  SizedBox(height: 96,  child: SeriesChart(series: profit,  controller: crosshair,
                                            touch: SeriesTouch(tooltip: null), …)),
]);
```

Stacked charts align when they use the same `SeriesYAxis` width and x range.

## Range selector

![Three series over a window of five months, a day read out, and the range selector that moves the window](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/series-window.png)

`SeriesRangeSelector` shows a miniature of the full data set with a selectable
window. Drag the window to move it, or drag a handle to resize it. The selector
does not store state: apply the window to the main chart's `minX` and `maxX`,
and store the window it reports.

```dart
var window = SeriesWindow(count - 30, count - 1.0);

SeriesChart(series: series, minX: window.start - .5, maxX: window.end + .5, …);
SeriesRangeSelector(
  series: overviewSeries,
  window: window,
  minSpan: 4,
  onChanged: (next) => setState(() => window = next),
);
```

## Animation

```dart
SeriesChart(
  series: …,
  animationDuration: Duration(milliseconds: 450),
  animationCurve: Curves.easeOutCubic,
  animateOnMount: true,
);
```

With a non-zero duration, data changes are animated:

- If each series has the same number of points as before, values and the value
  range interpolate from their previous positions.
- Otherwise, and on first build, values grow from each series' baseline (or
  from the plot edge if the baseline is out of range).
- Colour and style changes alone are not animated.

Use a zero duration for data that changes during a drag, such as a window moved
by a range selector, so the chart tracks the pointer without lag.

## Sizing

The chart fills its constraints. When the height is unbounded — for example,
in a `Column` without `Expanded` or in a scroll view — it uses `defaultHeight`
(200). `padding` adds space around the entire chart, including axes.
`clipToPlot: false` allows thick lines and edge dots to extend beyond the plot
area instead of being clipped.

## Migration

See [Migrating from fl_chart and candlesticks](migrating-from-fl_chart.md) for an
API mapping and examples.
