# Marimekko

![Volume by venue and instrument, columns as wide as they are big](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/marimekko.png)

`MarimekkoChart` — a mosaic chart — shows two dimensions at once. Every column
is as wide as it is big and as tall as every other, so the width says how much
a group is worth and the height says what it is made of. Volume by venue split
by instrument, revenue by desk split by product, exposure by sector split by
symbol: one chart instead of a pie beside a bar.

```dart
MarimekkoChart(
  columns: const [
    MarimekkoColumn(
      label: 'Spot',
      cells: [
        MarimekkoCell(label: 'BTC', value: 60),
        MarimekkoCell(label: 'ETH', value: 40),
      ],
    ),
    MarimekkoColumn(
      label: 'Perps',
      cells: [
        MarimekkoCell(label: 'BTC', value: 150),
        MarimekkoCell(label: 'ETH', value: 50),
      ],
    ),
  ],
);
```

Spot is a third of the width and Perps two thirds, because that is what they
are worth; inside each, the cells split the full height by their own shares.

The chart fills its constraints. In a box with no height it takes
`defaultHeight`.

## Columns and cells

A column's width is the sum of its cells, which is the usual thing. Give
`MarimekkoColumn.width` to set it from something else — the number of trades,
say, when the cells are profit.

Cells stack from the bottom in the order given. Negative and non-finite values
count as nothing.

Cells with the same `label` across columns are the same category and take the
same colour: `layout.categories` is the distinct labels in the order they were
first seen, and the palette is handed out by that position. A cell's own
`color` overrides it.

The gaps — `columnGap` between columns, `cellGap` between cells — come out of
the width before the columns share what is left, so the shares stay true
whatever the gap is set to.

## Labels

`showHeaders` writes the column names across the top in `headerHeight` of room,
and `showWidthShare` adds each column's share of the width after its name. A
name is clipped to its own column, so a narrow column never writes over its
neighbour's.

`showCellLabels` writes a cell's name inside it, where the cell is at least
`minLabelHeight` tall and the text fits across. `cellFormatter` writes
something else — the value, or the share.

## Layout

`layOutMarimekko(columns, size:, ...)` is the layout on its own, without a
widget. It returns a `MarimekkoLayout` with the `plotRect`, the `categories`,
and a `MarimekkoColumnLayout` per column holding its `rect`, `headerRect`,
`widthShare` and its cells — each a `MarimekkoCellLayout` with its `rect`, its
`share` of the column and its `category`.

`layout.cellAt(point)` and `layout.columnAt(point)` find what is under a point.
`progress` grows the cells up from the bottom of their column, for a draw-in
animation.

## Touch

`onCellTap` is called with a cell and its column when one is touched or dragged
over, and with nulls when the touch leaves. The touched cell lightens, and a
card names the column, the cell, its value and its share;`tooltipBuilder`
replaces the card.

## Styling

| Field | Default |
| --- | --- |
| `palette` | Eight colours, handed out by category |
| `columnGap`, `cellGap` | 2 and 1 |
| `headerHeight`, `headerStyle`, `showWidthShare` | The column names |
| `minLabelHeight`, `cellStyle`, `cellFormatter` | The cell names |
| `animationDuration`, `animationCurve`, `animateOnMount` | The draw-in |

`semanticLabel` is what a screen reader announces for the chart.

## See also

- [Treemap](treemap-chart.md) — the same two dimensions as nested rectangles
- [Stream graph](stream-chart.md) — how a whole was made up over many periods
