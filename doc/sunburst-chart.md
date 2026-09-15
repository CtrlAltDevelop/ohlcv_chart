# Sunburst

`SunburstChart` draws a hierarchy as rings round a centre, one ring per level.
Typical uses include portfolio composition (asset class → sector → holding),
budget breakdowns and folder sizes.

It takes the same `TreemapItem` tree as [Treemap](treemap-chart.md), so one data
structure can drive either chart.

```dart
SunburstChart(
  items: const [
    TreemapItem.group(
      label: 'Equities',
      children: [
        TreemapItem(value: 32, label: 'AAPL'),
        TreemapItem(value: 18, label: 'MSFT'),
      ],
    ),
    TreemapItem(value: 25, label: 'Bonds'),
  ],
);
```

The chart fills its constraints. When the height is unbounded, it uses
`defaultHeight`.

## Items

`TreemapItem(value: …)` is a leaf; `TreemapItem.group(children: […])` is a level
sized by its children's total. Both accept `label`, `color` and `data`.

## Layout

Each item takes the share of its parent's sweep that its value is of its
siblings' total. The first level shares `sweepAngle`; rings run from the hole in
the middle out to the chart's radius, split evenly over the levels present.

| Parameter | Description |
| --- | --- |
| `innerRadiusFraction` | Hole in the middle, as a share of the radius (default `0.25`) |
| `startAngle` | Where the first arc begins, in radians clockwise from three o'clock (default: twelve o'clock) |
| `sweepAngle` | How far round the rings go (default: a whole turn; `math.pi` gives a half sunburst) |
| `ringGap` | Gap between two rings |
| `maxDepth` | How many levels to draw; `null` draws them all |
| `padding` | Space around the chart |

`layOutSunburst(items, innerRadius: …, outerRadius: …)` returns the
`SunburstArc` list the chart paints, and `sunburstArcAt(arcs, center, local)`
hit-tests it — the deepest ring wins. Both are public, so a layout can be
computed and tested without a widget.

Arcs narrower than `minSweep` radians are dropped along with everything inside
them, so a long tail of tiny items cannot make the chart unreadable.

## Appearance

| Parameter | Description |
| --- | --- |
| `palette` | Colours taken in turn by the first level |
| `depthFade` | How much lighter each ring is drawn than the one inside it (default `0.12`) |
| `showLabels` | Whether labels are written along the arcs |
| `labelBuilder` | Custom text for a `SunburstArc`; default is the item's name |
| `valueFormatter` | Formats values for items without a name (default: thousands separators) |
| `labelStyle` | Style of a label; without it, text is black or white based on arc brightness |
| `center` | A widget shown in the hole in the middle |
| `backgroundColor` | Painted behind the chart |

Labels follow their arc and stay upright; an arc too short or too thin to hold
its label is left unlabelled.

## Touch

`onTouch` reports a `SunburstTouchDetails` — the `arc`, its `item` and the
`center` the rings are drawn round — as the pointer moves, and `null` when it
leaves. `hoverBorder` outlines the arc under the pointer, and `tooltipBuilder`
shows a card beside it.

```dart
SunburstChart(
  items: items,
  onTouch: (details) => setState(() => _selected = details?.item),
  tooltipBuilder: (context, details) => Card(
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Text('${details.item.label}: ${details.arc.total}'),
    ),
  ),
);
```

## Animation

`animationDuration` sweeps the rings in; `animationCurve` eases it and
`animateOnMount` controls whether the first build animates. The chart animates
again whenever `items` changes identity.
