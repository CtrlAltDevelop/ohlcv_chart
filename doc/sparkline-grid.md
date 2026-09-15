# Sparkline grid

`SparklineGrid` draws dozens of little charts in one table — small multiples. A
watchlist, a book of accounts, every strategy in a portfolio: one row each, a
name, its shape and its number.

```dart
SparklineGrid(
  columns: 2,
  tiles: [
    SparklineTile(label: 'BTC', values: btcCloses),
    SparklineTile(label: 'ETH', values: ethCloses),
  ],
);
```

The grid fills the width it is given. In a box with no height it takes
`intrinsicHeight` — `tileHeight` per row, plus `tileGap` between rows — which
is what makes it drop straight into a scroll view.

## Tiles

A `SparklineTile` is a label and a list of values, oldest first. Non-finite
values are breaks in the line, not zeros.

`tile.first` and `tile.last` are its ends, skipping breaks; `tile.change` is
how far it moved as a share of where it started; `tile.rose` says which way it
went, and decides whether the line is drawn in `riseColor` or `fallColor`
unless the tile names a colour of its own.

`subtitle` is written under the label, and the right-hand column holds the last
value — `valueLabel` or `valueFormatter` to write something else, like the
change.

## Scales

Every tile is scaled to its own series by default. That is the point of small
multiples: what is being compared is the shape of each line, not its level, and
a watchlist holding a $68,000 price beside a $0.40 one would otherwise be all
flat lines and one spike. Set `sharedScale` to put them all on one scale when
the levels really are comparable.

A flat series sits in the middle of its tile rather than on an edge.
`showBaseline` draws a line at the tile's first value, to read the move
against.

## Layout

`layOutSparklineGrid(tiles, size:, columns:, ...)` is the layout on its own,
without a widget. It returns a `SparklineGridLayout` with `columns`, `rows` and
a `SparklineTileLayout` per tile holding its `rect`, `labelRect`, `sparkRect`
and `valueRect`, the `min` and `max` it was scaled to, an `Offset?` per value —
null where the value was not finite — and its `lastPoint`.

`layout.tileAt(point)` finds the tile under a point and
`layout.sampleAt(tile, point)` which of its values falls there. `progress`
reveals each line left to right, for a draw-in animation.

## Touch

`onTileTap` is called with a tile and the sample under the finger, and with
nulls when the touch leaves. The tile lights up, a dot marks that sample, and a
card names the tile and the value there; `tooltipBuilder` replaces the card.

## Styling

| Field | Default |
| --- | --- |
| `columns`, `tileHeight`, `tileGap` | 1, 48 and 8 |
| `labelWidth`, `valueWidth`, `sparkPadding` | 64, 56 and 4 |
| `riseColor`, `fallColor` | Green and red by direction |
| `lineWidth`, `fillOpacity` | 1.5 and a faint wash under the line |
| `showEndDot`, `endDotRadius` | A dot at the end of each line |
| `tileColor`, `highlightColor` | The tile's own background, and the touch |
| `animationDuration`, `animationCurve`, `animateOnMount` | The draw-in |

`semanticLabel` is what a screen reader announces for the grid.

## See also

- [Series](series-chart.md) — one of these lines, full size, with axes
- [Slope and bump](slope-chart.md) — the same names compared between periods
