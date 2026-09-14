# Heatmap

![Six months of activity as a contribution graph, beside orders by hour and weekday](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/heatmap.png)

`HeatmapChart` draws a grid of squares coloured by their value — the thing a
table of numbers hides. A contribution graph, a correlation matrix, sales by
weekday and hour, a risk grid.

```dart
HeatmapChart.matrix(
  byHourAndDay,                    // a list of rows, each a list of columns
  scale: HeatmapGradientScale.of(green),
  xAxis: const HeatmapAxis(labels: dayNames),
  yAxis: const HeatmapAxis(labels: hourNames, size: 34),
  spacing: 3,
  radius: 3,
);
```

The chart fills the box it is given, and is `defaultHeight` high in a box with
no height of its own.

## The squares

`HeatmapChart.matrix` reads a list of rows, each holding its columns — a row
shorter than the widest one simply has no squares past its end. Give the cells
yourself when the data is sparse, or when a square needs a colour or a label
of its own:

```dart
HeatmapChart(
  cells: [
    for (final day in days)
      HeatmapCell(x: day.week, y: day.weekday, value: day.commits),
    const HeatmapCell(x: 9, y: 3, value: 12, color: amber, label: 'ship'),
  ],
  columns: 53,
  rows: 7,
);
```

A cell with a `null` value is empty and takes the scale's `emptyColor`, which
is what a month that has not happened yet should look like. Two cells at the
same position draw the later one. `columns` and `rows` are fitted from the
cells unless they are given, so a grid that must keep its shape while the data
fills in should name them.

## Colour

| Scale | Draws |
| --- | --- |
| `HeatmapGradientScale(colors: [...], stops: [...])` | a fade through the colours, spread over the value range |
| `HeatmapGradientScale.of(color)` | one colour deepening from faint to full — the contribution graph |
| `HeatmapStepScale(steps: [HeatmapStep(from, color)])` | whole bands: under 0, 0 to 5, 5 and up |

The range the scale is spread over is the lowest and highest value among the
cells, or `minValue` and `maxValue` when those are set — which is what keeps
two heatmaps beside each other comparable.

A `HeatmapCell.color` overrules the scale for that one square.

## Labels

`HeatmapAxis` names the columns and the rows:

```dart
HeatmapChart(
  cells: cells,
  xAxis: const HeatmapAxis(labels: months, interval: 2),
  yAxis: const HeatmapAxis(labels: weekdays, size: 34),
);
```

| Field | What it does |
| --- | --- |
| `labels`, `labelBuilder` | What each column or row is called |
| `interval` | Label only every nth one |
| `side` | `start` — under the grid, or left of it — or `end` |
| `size`, `gap`, `style` | The room held, the space before it, and the text |

`HeatmapAxis.hidden` removes an axis along with its room.

`labelBuilder` on the chart writes inside the squares, and a `HeatmapCell`'s
own `label` wins over it. With no `labelStyle` the text is black or white by
how dark its square is, and a label too big for its square is left out rather
than drawn over the next one.

## Touch

A touch or a hovering mouse names the square under it. `hoverBorder` marks it,
`onTouch` reports it — column, row, cell and the square in pixels — and
`tooltipBuilder` puts a card above it:

```dart
HeatmapChart(
  cells: cells,
  onTouch: (details) => setState(() => reading = details),
  tooltipBuilder: (context, details) => Card(
    child: Text('${days[details.x]}: ${details.value ?? 0}'),
  ),
);
```

A square with no cell still reports itself, with a `null` cell and value, so an
empty day reads as "nothing here" rather than as no touch at all.

## The legend

`HeatmapLegend` draws the scale as a bar, with a word at either end:

```dart
HeatmapLegend(scale: scale, low: 'Less', high: 'More', width: 90);
```

Left without a `width` it fills the row it is in.

## Shape and animation

`squareCells` keeps the squares square, leaving the grid smaller than the box
when the two are not the same shape — a contribution graph wants this. With
`animationDuration` set, the squares come up from the empty colour to their
own.
