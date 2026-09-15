# Heatmap

![Six months of activity as a contribution graph, beside orders by hour and weekday](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/heatmap.png)

`HeatmapChart` renders a grid of cells coloured by value, making patterns in
tabular data easy to see. Typical uses include contribution graphs, correlation
matrices, sales by weekday and hour, and risk grids.

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

The chart fills its constraints. When the height is unbounded, it uses
`defaultHeight`.

## Data

`HeatmapChart.matrix` accepts a list of rows, each containing column values.
Rows shorter than the widest row have no cells beyond their length.

For sparse data, or when individual cells need a custom colour or label, pass
cells directly:

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

- A cell with a `null` value is empty and uses the scale's `emptyColor`.
- If two cells share a position, the later one is drawn.
- `columns` and `rows` are inferred from the cells unless specified. Set them
  explicitly to keep the grid size stable while data loads.

## Colour scales

| Scale | Rendering |
| --- | --- |
| `HeatmapGradientScale(colors: [...], stops: [...])` | Continuous gradient across the value range |
| `HeatmapGradientScale.of(color)` | Single colour from faint to full intensity, as in contribution graphs |
| `HeatmapStepScale(steps: [HeatmapStep(from, color)])` | Discrete colour bands by threshold |

The scale spans the minimum and maximum cell values, or `minValue` and
`maxValue` when set. Set them explicitly to keep multiple heatmaps comparable.

`HeatmapCell.color` overrides the scale for an individual cell.

## Labels

`HeatmapAxis` labels columns and rows:

```dart
HeatmapChart(
  cells: cells,
  xAxis: const HeatmapAxis(labels: months, interval: 2),
  yAxis: const HeatmapAxis(labels: weekdays, size: 34),
);
```

| Field | Description |
| --- | --- |
| `labels`, `labelBuilder` | Label text for each column or row |
| `interval` | Show every nth label |
| `side` | `start` (below or left of the grid) or `end` |
| `size`, `gap`, `style` | Reserved space, spacing and text style |

`HeatmapAxis.hidden` removes an axis and its reserved space.

The chart's `labelBuilder` adds text inside cells; `HeatmapCell.label` takes
precedence. Without a `labelStyle`, text is black or white depending on cell
brightness. Labels that do not fit their cell are omitted.

## Touch

Touch or mouse hover identifies the cell under the pointer. `hoverBorder`
highlights it, `onTouch` reports the column, row, cell and cell bounds, and
`tooltipBuilder` shows a widget above it:

```dart
HeatmapChart(
  cells: cells,
  onTouch: (details) => setState(() => reading = details),
  tooltipBuilder: (context, details) => Card(
    child: Text('${days[details.x]}: ${details.value ?? 0}'),
  ),
);
```

Positions without a cell are still reported, with `null` cell and value, so
empty cells can be distinguished from no touch.

## Legend

`HeatmapLegend` displays the colour scale as a bar with labels at each end:

```dart
HeatmapLegend(scale: scale, low: 'Less', high: 'More', width: 90);
```

Without `width`, the legend fills the available width.

## Layout and animation

- `squareCells` keeps cells square, shrinking the grid within its bounds if
  needed. Recommended for contribution graphs.
- When `animationDuration` is set, cells animate from the empty colour to their
  value colour.
