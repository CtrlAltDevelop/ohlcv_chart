# Waffle

![A portfolio as a hundred squares, beside 38 winning trades of 100](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/waffle.png)

`WaffleChart` draws parts of a whole as a grid of squares. With a hundred
cells, each one is a per cent, so a share is counted rather than judged by
angle — which is the thing a pie chart cannot do.

```dart
WaffleChart(
  slices: const [
    WaffleSlice(label: 'Crypto', value: 45, color: Color(0xFF4C86CD)),
    WaffleSlice(label: 'Equities', value: 35, color: Color(0xFF2F9E44)),
    WaffleSlice(label: 'Cash', value: 20, color: Color(0xFF909196)),
  ],
);
```

The grid keeps its square cells and is centred in whatever box it is given. In
a box with no size it takes `defaultSize`.

## Cells

`cells` is what the whole is worth — 100 by default, so each cell is a per
cent — and `columns` how many go across. `rows` sets the height instead, and
then the grid holds `columns × rows` cells whatever `cells` says.

`waffleCounts(slices, cells:, total:)` hands the cells out. Cells are whole
things, so the shares have to be rounded to them: every slice gets its floor,
and the spare cells go to the largest remainders. That keeps each slice within
one cell of its true share and the total exactly `cells`.

Leave `total` out and the slices are a share of their own sum, so they always
fill the grid. Give it and they are a share of that instead, which leaves the
rest of the grid in `emptyColor` — "38 of the 100 trades were winners" rather
than "the winners were 38% of the trades".

Negative and non-finite values count as nothing.

## Filling

| `fill` | Order |
| --- | --- |
| `WaffleFill.bottomRowsUp` (default) | Along the bottom row, then upwards |
| `WaffleFill.topRowsDown` | Along the top row, then downwards |
| `WaffleFill.leftColumnsRight` | Up the leftmost column, then rightwards |

Slices take their cells in the order they were given, so the grid reads as one
run of colour per slice.

## Layout

`layOutWaffle(counts, size:, ...)` is the layout on its own, without a widget.
It returns a `WaffleLayout` with every cell's `Rect`, the `owners` list saying
which slice each belongs to (-1 for an empty cell), and `sliceAt(point)` for
the slice under a point. `progress` fills only the first part of the cells, for
a fill-in animation.

## Touch

`onSliceTap` is called with a slice when one of its cells is touched or dragged
over, and with null when the touch leaves the filled cells. The other slices
dim while one is held, and a card over the slice's first cell names it and how
many cells it holds; `tooltipBuilder` replaces the card and
`WaffleSlice.tooltip` changes only its text.

## Styling

| Field | Default |
| --- | --- |
| `cellGap`, `cellRadius` | 3, and a `BorderRadius` of 2 |
| `emptyColor` | A faint grey for cells no slice reached |
| `padding`, `backgroundColor` | None |
| `animationDuration`, `animationCurve`, `animateOnMount` | The fill-in |
| `defaultSize` | 220, in a box that sets no size |

`semanticLabel` is what a screen reader announces for the chart.

## See also

- [Pie](pie-chart.md) — the same shares as angles, with a ring mode
- [Bullet](bullet-chart.md) — a measure against its target
