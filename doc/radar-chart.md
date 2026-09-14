# Radar chart

![A five-feature radar web with two scored strategies drawn over it](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/pie-radar.png)

`RadarChart` compares several things over the same features: a web of spokes,
one outline per series. (The doughnut beside it is
[its own page](pie-chart.md).)

```dart
RadarChart(
  features: const ['Speed', 'Power', 'Range', 'Cost', 'Weight'],
  series: [
    RadarSeries(values: const [4, 3, 5, 2, 4], color: blue, label: 'Now'),
    RadarSeries(values: const [3, 5, 2, 4, 3], color: amber, label: 'Target'),
  ],
  maxValue: 5,
);
```

The chart fills the box it is given, and is `defaultSize` square in a box that
sets no size of its own.

## Series

A `RadarSeries` carries one value per feature, in the order `features` names
them. A value beyond the range is held at the edge rather than drawn off the
web, and a `null` leaves that corner out of the outline.

| Field | What it does |
| --- | --- |
| `color` | The outline colour |
| `fillColor` | Inside the outline; null uses a faint `color` |
| `width`, `dashPattern` | The outline itself; `width: 0` draws none |
| `dot` | A dot on every corner |
| `label` | What the series is called, for a legend of your own |

## The web

| Field | What it does |
| --- | --- |
| `features` | What each corner is called; an empty list leaves them unnamed |
| `minValue`, `maxValue` | The middle and the outer ring; `maxValue` null takes the largest value given |
| `tickCount` | How many rings are drawn |
| `shape` | `RadarShape.polygon` — the spider web — or `circle` |
| `startDegreeOffset` | Where the first feature sits, clockwise from twelve |
| `gridColor`, `gridWidth` | The rings |
| `spokeColor`, `spokeWidth` | The spokes out to each corner |
| `showTicks`, `tickStyle` | The value each ring stands for, written up the first spoke |
| `featureStyle`, `featureGap` | The names outside the web |
| `radius` | How far the web reaches; null fits the box, leaving room for the names |

## Touch

`onTouch` reports the corner nearest the finger — which series, which feature
and the value there — within `touchThreshold` pixels, and `null` when the touch
leaves.

```dart
RadarChart(
  series: series,
  onTouch: (details) => setState(() => hovered = details?.featureIndex),
);
```

## Placing your own widgets

`radarCorner` and `RadarLayout` are public, so a legend chip or a badge can be
put exactly on a corner:

```dart
const layout = RadarLayout(
  centre: Offset(120, 120),
  radius: 100,
  count: 5,
  minValue: 0,
  maxValue: 10,
  startAngle: -math.pi / 2,
);
final at = layout.cornerFor(2, 7); // where the third feature's 7 is drawn
```

## Animation

With `animationDuration` set, the outlines grow out of the middle.
