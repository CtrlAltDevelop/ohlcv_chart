# Bullet

`BulletChart` puts a measure against its target on a banded track. It is the
compact form of a gauge: where a `GaugeChart` takes a panel to show one number,
a bullet row takes a line, so a column of KPIs fits in the space of a single
dial.

```dart
BulletChart(
  rows: const [
    BulletRow(
      label: 'Win rate',
      value: 58,
      target: 55,
      max: 100,
      bands: [
        BulletBand(to: 40, color: Color(0x33E03131)),
        BulletBand(to: 55, color: Color(0x33F59F00)),
        BulletBand(to: 100, color: Color(0x332F9E44)),
      ],
    ),
    BulletRow(label: 'Profit factor', value: 1.6, target: 2, max: 3),
  ],
);
```

The chart fills the width it is given. In a box with no height — a column, a
scroll view — it takes `intrinsicHeight`, which is `rowHeight` per row plus
`rowGap` between them. In a box too short for that, the rows shrink together to
fit rather than spilling out.

## A row

| Field | What it is |
| --- | --- |
| `label` | Written in the label column, right-aligned against the track |
| `value` | The measure — the length of the bar |
| `target` | Marked by a tick across the track; null marks none |
| `min`, `max` | The ends of the track; `min` defaults to 0 |
| `bands` | Qualitative stretches behind the bar |
| `color`, `targetColor` | Override the chart's colours for this row |
| `valueLabel`, `tooltip` | Override the written value and the touch card |

Each row has its own scale, so a win rate in per cent and a profit factor in
multiples sit in the same chart and each fill their own track.

Leave `max` out and the row takes the largest of its value, its target and its
bands. A row with no bands gets a little room over the longest bar so it never
runs flush into the edge; a banded row ends exactly where its last band does.

## Bands

Bands are given in order and each runs from where the one before it ended to
its own `to`, starting at the row's `min`. Three is the usual number — poor,
fair, good — and they read best faint, with the measure bar solid over them.
A row with no bands is drawn on a plain `trackColor` track instead.

## Layout

`layOutBullet(rows, size:, ...)` is the layout on its own, without a widget. It
returns a `BulletLayout` of `BulletRowLayout`s, each with the row's
`labelRect`, `trackRect`, `barRect`, `bandRects` and `targetX`.
`layout.rowAt(point)` finds the row under a point. `progress` shortens every
bar for a draw-in animation, leaving the bands and targets where they are.

## Touch

`onRowTap` is called with a row when it is touched or dragged over, and with
null when the touch leaves. A card with the row's label and value follows the
finger; `tooltipBuilder` replaces it, and `BulletRow.tooltip` changes only its
text.

## Styling

| Field | Default |
| --- | --- |
| `barColor` | A blue, where a row names no colour |
| `targetColor` | A near-white tick |
| `trackColor` | A faint grey, under rows with no bands |
| `labelWidth`, `labelGap` | 92 and 8; a width of 0 writes no labels |
| `rowHeight`, `rowGap` | 22 and 10 |
| `barThickness` | 0.45 — the bar's height as a share of the track's |
| `targetWidth` | 3 |
| `rounded` | Rounded ends on the bars |
| `showValues`, `valueFormatter` | The value written at the right of the track |
| `animationDuration`, `animationCurve`, `animateOnMount` | The draw-in |

`semanticLabel` is what a screen reader announces for the chart.

## See also

- [Gauge](gauge-chart.md) — one value on a dial, with a needle and ranges
- [Waterfall](waterfall-chart.md) — a total built up step by step
