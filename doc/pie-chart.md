# Pie chart

![A doughnut of holdings with a total in the hole, its biggest slice pulled out and badged](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/pie-radar.png)

`PieChart` draws a ring of sections, each as wide as its share of the whole: a
pie, a doughnut when the middle is left open, or a single-section gauge. (The
radar beside it is [its own page](radar-chart.md).)

```dart
PieChart(
  sections: [
    PieSection(value: 40, color: blue, label: '40%'),
    PieSection(value: 35, color: green, label: '35%'),
    PieSection(value: 25, color: amber, label: '25%'),
  ],
  centerSpaceRadius: 40,
  centerChild: const Text('Total'),
);
```

The chart fills the box it is given, and is `defaultSize` square in a box that
sets no size of its own.

## Sections

A section's `value` is a share, not an angle. The values are added up and each
section gets the part of the circle it is worth, so `[40, 35, 25]` and
`[8, 7, 5]` draw the same pie. A section worth nothing is left out, and a set of
sections worth nothing at all draws nothing.

| Field | What it does |
| --- | --- |
| `color` | Fill colour |
| `gradient` | Fill gradient, measured over the section; it wins over `color` |
| `label`, `labelStyle` | Written on the section |
| `labelPosition` | Where the label sits: 0 at the inner edge, 1 at the outer one |
| `radius` | How far this one section reaches, so it can stand out |
| `border` | An outline round it |
| `offset` | How far it is pushed out of the circle — the exploded slice |
| `badge`, `badgePosition` | A widget pinned to the section |

## The circle

| Field | What it does |
| --- | --- |
| `radius` | How far the sections reach; null fills the box |
| `centerSpaceRadius` | The hole in the middle; 0 draws a full pie |
| `centerSpaceColor` | Painted in the hole |
| `centerChild` | A widget centred in the hole — a total, a title, a button |
| `sectionsSpace` | The gap between two sections, in pixels round the outer edge |
| `startDegreeOffset` | Where the first section starts, clockwise from twelve |
| `clockwise` | Whether the sections go round clockwise |

## Touch

A touch or a hovering mouse names the section under it. That section grows by
`touchedSectionGrowth` while it is held — the room for it is taken off the
radius, so nothing is cut off at the edge — and `onTouch` reports which one it
is, with `null` when the touch leaves.

```dart
PieChart(
  sections: sections,
  onTouch: (details) => setState(() => selected = details?.index),
);
```

## Placing your own widgets

The geometry is public, so anything can be put exactly where a section is:

```dart
final slices = layOutPie(
  sections: sections,
  radius: 80,
  innerRadius: 40,
);
final at = slices[1].pointAt(centre, 0.5); // the middle of the second section
```

`pieSectionAt` answers the other question — which section a point is inside,
and `null` for the hole or the space around the circle.

## Animation

With `animationDuration` set, the sections sweep open from the start angle,
each one keeping its place. `animateOnMount: false` draws the first build
whole.
