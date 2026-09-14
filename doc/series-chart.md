# Series charts

`KChartWidget` reads candles against time. `SeriesChart` reads any numbers
against any numbers: a balance per day, sign-ups per month, profit per trade.
These are the charts a dashboard, a wallet or a report draws. It has lines,
areas and bars, several series at once, axes you can write or hide, a touch
readout you can replace, a range strip for long data, and animation between
data sets.

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

Everything else is optional. Every parameter's default draws a plain,
readable chart, and each section below changes one part of it.

## Series

A chart takes a list of `PlotSeries`, drawn bottom layer first. There are two
kinds, and one chart can mix them.

Points are `SeriesPoint(x, y)` and run from the lowest x to the highest. When
your data is just a list of values, the `.values` constructors place them at
`x = 0, 1, 2, …`. A `null` value is a gap: a line breaks there and a bar is
left out.

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

`curve` decides how points are joined:

| `LineCurve` | Draws |
| --- | --- |
| `linear` | straight segments |
| `smooth` | a curve through every point that can swing past a peak (`fl_chart`'s `isCurved`) |
| `monotone` | a curve through every point that never swings past its neighbours (`isCurved` + `preventCurveOverShooting`) |
| `step` | holds each value until the next point |

### Fills

A `SeriesFill` colours the area between the line and its `baseline`, or the
bottom of the plot when `toBaseline` is false. A fill anchored to the baseline
never paints across it. Above the baseline it uses `gradient` (or `color`),
measured from the line's highest point down to the baseline, so it fades out
exactly at the baseline. Below the baseline it uses `negativeGradient` (or
`negativeColor`), measured the other way. Left unset, the lower half reuses the
upper gradient flipped upside down, so both halves fade away from the line.

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

Several bar series on one chart stand side by side at each x. When there are
bars, the x range gets half a unit of room at either end, so the first and last
bars are drawn whole.

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

The x axis chooses which x values to label, and to draw a vertical grid line
at, in this order:

1. `ticks`, if given.
2. Otherwise, every index whose entry in `labels` is not blank, kept only at
   multiples of `interval` when that is set. A label list that names only month
   starts therefore spaces itself.
3. Otherwise, every `interval`.
4. Otherwise, about `tickCount` round values.

Labels that would overlap the one before are dropped, and `fitInside` slides
the first and last labels in so their text is not cut off. Use `labelBuilder`
to write a label from its x.

`SeriesXAxis.hidden`, `SeriesYAxis.hidden` and `SeriesGrid.none` remove each
part, along with the room it held. A 58-pixel sparkline is a chart with all
three hidden.

## The range of values

With nothing set, x spans the points and the value range fits the data. The
fitted range gets `yPadding` (10%) of room above and below, then widens to the
next round tick at each end. The padding never pushes a series that stays above
zero below zero, or one that stays below zero above it.

| Parameter | Does |
| --- | --- |
| `minX`, `maxX` | Pin the plot's edges. Set both to show a window of a longer series; the values range then fits what is in the window. |
| `xPadding` | Room either side of the fitted x range, in x units. |
| `minY`, `maxY` | Pin the value range. |
| `includeZero` | Always reach zero. |
| `yPadding` | Room above and below, as a share of the range. |
| `niceYRange` | Widen to round ticks (on by default). |

## Reference lines and bands

```dart
referenceLines: [
  SeriesReferenceLine.horizontal(0, color: gray600, dashPattern: [3, 3]),
  SeriesReferenceLine.horizontal(target, label: l10n.target, extendsRange: true),
  SeriesReferenceLine.vertical(todayIndex.toDouble(), label: l10n.today),
],
bands: [SeriesBand.vertical(5, 7, color: weekendShade)],
```

Reference lines are not interactive, and they sit under the series unless
`aboveSeries` is set. A horizontal line only widens the value range when
`extendsRange` asks, because otherwise a far-off target would flatten the data.

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
| `press` | Shows while a finger is down or dragging, and hides when it lifts. This is `fl_chart`'s default. |
| `longPress` | Shows after a long press and follows the finger, so a quick swipe still scrolls the page. |
| `tap` | A tap places it and it stays there. A drag moves it, and tapping the same point again clears it. |
| `none` | Only hover or the controller can show it. |

The crosshair snaps to the nearest point. `onTouch` is called after it moves to
another x, and with `null` when it goes away. Its `SeriesTouchDetails` carry
the x (`index` for charts of plain values) and, for every series with a value
there, the series, the point, its position on the chart and its colour at that
value.

To draw your own tooltip, give `SeriesTooltip.builder`. The chart still places
the result beside the crosshair or above the point and keeps it inside the
chart. Return `null` from the builder, or pass `tooltip: null`, to show no
tooltip at all. Pass `touch: null` to make the chart ignore touch and hover
entirely.

### Several charts, one crosshair

A `SeriesChartController` shows or clears the crosshair from code. Give two
charts the same controller, and touching either one marks the same x on both.
For example, a balance panel and a profit panel under it:

```dart
final crosshair = SeriesChartController();

Column(children: [
  SizedBox(height: 200, child: SeriesChart(series: balance, controller: crosshair, …)),
  SizedBox(height: 96,  child: SeriesChart(series: profit,  controller: crosshair,
                                            touch: SeriesTouch(tooltip: null), …)),
]);
```

Charts stacked like this line up as long as they give `SeriesYAxis` the same
`width` and use the same x range.

## A window over long data

`SeriesRangeSelector` draws the whole data set small, with a window over it.
Drag inside the window to move it, or drag a handle to move that edge. The
selector holds no data of its own: show the window through the main chart's
`minX` and `maxX`, and keep the window it reports.

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

With a non-zero duration, new data moves into place. If each series has the
same number of points as before, every value moves from where it was, and the
value range moves with it. Otherwise, and on the first build, the values grow
out of each series' baseline, or from the edge of the plot when the baseline is
out of range. A change of colour or style alone does not animate.

Leave the duration at zero for data that changes while it is being dragged,
such as a window moved by a range selector, so the chart keeps up with the
finger.

## Sizing

The chart fills the box it is given. In a box with no height of its own, such
as a `Column` without an `Expanded` or a scroll view, it is `defaultHeight`
(200) tall. `padding` keeps space clear around the whole chart, axes included.
`clipToPlot: false` lets a thick line or a dot at the edge draw past the plot
instead of being cut off.

## Migrating

[Migrating from fl_chart and candlesticks](migrating-from-fl_chart.md) maps
their APIs onto this one, with worked examples.
