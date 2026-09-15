# Dumbbell

`DumbbellChart` puts two values on one line and joins them with a bar. Before
and after, low and high, bid and ask, last quarter and this one: the gap is the
point, and a bar between two dots shows it far better than two bars side by
side.

```dart
DumbbellChart(
  rows: const [
    DumbbellRow(label: 'BTC', from: 61200, to: 68400),
    DumbbellRow(label: 'ETH', from: 3400, to: 3120),
  ],
);
```

The chart fills the width it is given. In a box with no height it takes
`intrinsicHeight` — `rowHeight` per row, plus the axis.

## Rows

| Field | What it is |
| --- | --- |
| `label` | Written in the label column |
| `from`, `to` | The two ends of the bar |
| `fromColor`, `toColor`, `barColor` | Override the chart's colours |
| `tooltip` | Overrides the text of the touch card |

`row.change` is `to − from` and `row.rose` says which way it went. Rows that
rose get `riseColor` on the end dot and rows that fell get `fallColor`, so the
direction reads before the values do. Set `toColor` on the chart to use one
colour for every row instead.

All rows share one scale, so their gaps are comparable. `min` and `max` set it;
left out, the chart takes the smallest and largest value in the rows with a
little air either side.

## The axis

`showAxis` writes the value axis under the plot in `axisHeight` of room, and
`tickCount` sets how many gaps it is divided into — the same values are drawn
as gridlines behind the rows in `gridColor`. `axisFormatter` writes the labels.

`showValues` writes each row's two numbers on the outside of its dots, where
they do not cross the bar. `valueFormatter` writes those.

## Layout

`layOutDumbbell(rows, size:, ...)` is the layout on its own, without a widget.
It returns a `DumbbellLayout` with the `plotRect`, the shared `min` and `max`,
the `ticks`, and a `DumbbellRowLayout` per row holding its `labelRect`,
`trackRect`, `fromCenter` and `toCenter`. `layout.xOf(value)` places a value
and `layout.rowAt(point)` finds the row under a point. `progress` grows each
bar out from its start, for a draw-in animation.

## Touch

`onRowTap` is called with a row when it is touched or dragged over, and with
null when the touch leaves. A card names the row and both its ends;
`tooltipBuilder` replaces it.

## Styling

| Field | Default |
| --- | --- |
| `fromColor` | A grey start dot |
| `riseColor`, `fallColor` | Green and red end dots |
| `barColor` | The end dot's colour, faded |
| `barWidth`, `dotRadius` | 3 and 5 |
| `labelWidth`, `labelGap`, `rowHeight` | 92, 8 and 26 |
| `animationDuration`, `animationCurve`, `animateOnMount` | The draw-in |

`semanticLabel` is what a screen reader announces for the chart.

## See also

- [Box plot](box-plot-chart.md) — quartiles and whiskers rather than two ends
- [Bullet](bullet-chart.md) — a measure against its target
