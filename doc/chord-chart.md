# Chord

![Flow between four venues, both ways round a ring](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/chord.png)

`ChordChart` draws flow between nodes both ways round a ring. Where a Sankey
has to break a cycle, a chord draws it: money moving between accounts, volume
between venues, rotation between sectors.

```dart
ChordChart(
  nodes: const [
    ChordNode(label: 'Binance'),
    ChordNode(label: 'OKX'),
    ChordNode(label: 'Bybit'),
  ],
  flows: const [
    ChordFlow(from: 'Binance', to: 'OKX', value: 40),
    ChordFlow(from: 'OKX', to: 'Bybit', value: 25),
    ChordFlow(from: 'Bybit', to: 'Binance', value: 30),
  ],
);
```

The ring is centred in whatever box it is given and keeps its shape. In a box
with no size it takes `defaultSize`.

## Nodes and flows

Flows name their ends by node label; a flow naming a node that is not in the
list is dropped, and negative or non-finite values count as nothing.

Each node's arc is as long as everything passing through it — what leaves plus
what arrives — and every flow takes a slice of both the arcs it touches.
`ChordTotals.of(names, flows)` works those totals out on its own: `out`, `into`
and `totalAt(index)` per node, and `grandTotal`, which counts every flow at
both its ends and so is twice their sum.

`padAngle` is the gap between two arcs. The pads come out of the turn before
the arcs share what is left, so an arc's length stays true to its share however
wide the pads are set. `startAngle` says where the first arc begins — twelve
o'clock by default.

## Ribbons

A ribbon runs from its slice of one arc to its slice of the other, bending
through the centre so it reads as one flow rather than two arcs meeting. It
takes the colour of the end that carries more, which is usually the node it
belongs to.

## Layout

`layOutChord(nodes, flows, size:, ...)` is the layout on its own, without a
widget. It returns a `ChordLayout` with the ring's `center`, `radius`,
`ringThickness` and `innerRadius`, a `ChordArc` per node — its `startAngle`,
`sweepAngle`, `midAngle` and `containsAngle(angle)` — a `ChordRibbon` per flow
with its closed `shape` path, and the `totals` behind them.

`layout.arcAt(point)` finds the arc on the ring under a point and
`layout.ribbonAt(point)` the ribbon inside it, the one on top first.
`progress` sweeps the ring and its ribbons open, for a draw-in animation.

## Touch

`onNodeTap` is called with a node when its arc is touched, `onFlowTap` with a
flow when its ribbon is, and both with null when the touch leaves. Holding an
arc fades everything that does not touch that node; holding a ribbon fades the
rest. A card names a held ribbon's ends and value; `tooltipBuilder` replaces
it.

## Styling

| Field | Default |
| --- | --- |
| `palette` | Eight colours, handed out by node position |
| `ringThickness`, `padAngle`, `startAngle` | 12, 0.03 rad, twelve o'clock |
| `ribbonOpacity`, `ribbonStroke` | 0.4 and 0.5 |
| `showLabels`, `labelWidth`, `labelStyle` | Node names outside the ring |
| `fadeUntouched` | Fading while something is held |
| `animationDuration`, `animationCurve`, `animateOnMount` | The sweep |

`semanticLabel` is what a screen reader announces for the chart.

## See also

- [Sankey](sankey-chart.md) — the same flows in columns, with cycles removed
- [Marimekko](marimekko-chart.md) — two dimensions as columns and cells
