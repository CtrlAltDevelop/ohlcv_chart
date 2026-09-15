# Equity curve

![An equity curve with the underwater drawdown panel beneath it](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/equity-curve.png)

`EquityCurveChart` draws an account's value over time with an *underwater* panel
below it, shading how far the curve has fallen below its own high. It is the
chart every backtest, copy-trading profile and portfolio report ends with.

```dart
EquityCurveChart(
  points: [
    for (final row in backtest)
      EquityPoint(time: row.time, equity: row.equity),
  ],
);
```

The chart fills its constraints. When the height is unbounded, it uses
`defaultHeight`.

## The maths

Two public functions do the work, so the numbers can be shown as text or tested
without a widget:

- `equityDrawdowns(points)` — how far below its own high the curve was at each
  reading, as a fraction (`-0.24` is 24% down). The first reading is always `0`
  and every value is zero or less.
- `equityStats(points)` — an `EquityStats` with `start`, `end`, `peak`,
  `trough`, `totalReturn`, the deepest `maxDrawdown` and the dates it ran
  between (`maxDrawdownStart`, `maxDrawdownEnd`).

```dart
final stats = equityStats(points);
Text('Return ${(stats.totalReturn * 100).toStringAsFixed(1)}% · '
     'Max DD ${(stats.maxDrawdown * 100).toStringAsFixed(1)}%');
```

## Layout

| Parameter | Description |
| --- | --- |
| `drawdownFraction` | How much of the height the underwater panel takes (default `0.3`) |
| `panelGap` | The gap between the two panels |
| `min`, `max` | Ends of the curve's value axis; `null` reads them off the points |
| `axisWidth`, `timeAxisHeight` | Room for the axes |
| `padding` | Space around the chart |

Readings are spread evenly across the width in the order given, so a curve with
gaps in time — weekends, halts — draws without them.

`layOutEquityCurve(points, bounds, …)` returns the `EquityCurveLayout` the chart
paints: the two panel rects, the two point lists, the drawdowns, the value range
and `deepestDrawdown`. `layout.indexAt(dx)` finds the reading nearest a
position.

## Appearance

| Parameter | Description |
| --- | --- |
| `lineColor`, `lineWidth`, `fillOpacity` | The curve and its shading |
| `drawdownColor`, `drawdownOpacity` | The underwater panel |
| `markMaxDrawdown` | Marks the deepest fall on both panels, with its depth written |
| `showValueAxis`, `showDrawdownAxis`, `showTimeAxis` | The three axes |
| `tickCount` | About how many ticks on the value axis |
| `valueFormatter`, `percentFormatter`, `timeFormatter` | Axis label text |
| `gridColor` | Grid ruled at each value tick |
| `crosshairColor` | The line drawn through the touched reading |
| `axisLabelStyle`, `backgroundColor` | Text style and background |

## Touch

The chart reads raw pointer events, so the crosshair follows a finger dragged
along the curve immediately. `onTouch` reports an `EquityTouchDetails` with the
reading's `index`, the `point` itself, its `drawdown` and where it sits, and
`null` when the pointer leaves.

```dart
EquityCurveChart(
  points: points,
  onTouch: (details) => setState(() => _readout = details),
  tooltipBuilder: (context, details) => Card(
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Text('${details.point.equity}\n'
          '${(details.drawdown * 100).toStringAsFixed(1)}% from high'),
    ),
  ),
);
```

## Animation

`animationDuration` draws the curve in from the left; `animationCurve` eases it
and `animateOnMount` controls whether the first build animates. The chart
animates again whenever `points` changes identity.
