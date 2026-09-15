# Volatility curve

`VolatilityCurveChart` draws implied volatility against strike or maturity: a
smile, a skew, or a term structure. Several curves can be shown at once — one
per expiry — with a crosshair that reads all of them.

```dart
VolatilityCurveChart(
  slices: const [
    VolatilitySlice(
      label: '7d',
      points: [
        VolatilityPoint(x: 90, volatility: 0.42),
        VolatilityPoint(x: 100, volatility: 0.31),
        VolatilityPoint(x: 110, volatility: 0.36),
      ],
    ),
    VolatilitySlice(
      label: '30d',
      dashed: true,
      points: [
        VolatilityPoint(x: 90, volatility: 0.38),
        VolatilityPoint(x: 100, volatility: 0.33),
        VolatilityPoint(x: 110, volatility: 0.35),
      ],
    ),
  ],
  atTheMoney: 100,
  xAxisTitle: 'Strike',
);
```

Volatilities are fractions: `0.32` is written as `32%`. The bottom axis is
whatever the readings' `x` means — a strike, a moneyness, or days to expiry for
a term structure.

The chart fills its constraints. When the height is unbounded, it uses
`defaultHeight`.

## Slices

| `VolatilitySlice` field | Description |
| --- | --- |
| `points` | The readings; sorted along the bottom axis when laid out |
| `label` | Written in the legend |
| `color` | Fixed colour; otherwise taken from `palette` in order |
| `dashed` | Draws the curve dashed — a model or forward curve |
| `data` | Arbitrary app data |

Readings that are not finite are dropped, so a strike with no quote can be left
in the list.

## Layout

| Parameter | Description |
| --- | --- |
| `minX`, `maxX` | Ends of the bottom axis; `null` reads them off the readings |
| `minVolatility`, `maxVolatility` | Ends of the volatility axis; `null` reads them off the readings with room either side, never below zero |
| `atTheMoney` | The strike the underlying is at now, marked with a line |
| `padding` | Space around the chart |

`volatilityRange(slices)` returns the ranges the chart would pick, and
`layOutVolatility(slices, bounds, …)` returns the `VolatilityLayout` it paints,
with `xOf` and `yOf` for mapping values to pixels and `curve.nearest(dx)` for
finding a reading.

## Appearance

| Parameter | Description |
| --- | --- |
| `palette` | Colours taken in turn by curves without one |
| `lineWidth`, `curved` | Curve weight; `curved: false` joins readings with straight lines |
| `showPoints`, `pointRadius` | A dot at each reading |
| `showLegend`, `legendStyle` | The curve names in the corner |
| `showAxes`, `axisWidth`, `axisHeight`, `tickCount` | The two axes |
| `xFormatter`, `volatilityFormatter`, `axisLabelStyle` | Axis label text |
| `xAxisTitle`, `axisTitleStyle` | The bottom axis title |
| `gridColor`, `atTheMoneyColor`, `crosshairColor` | Grid and markers |
| `backgroundColor` | Painted behind the chart |

The smoothing puts its control points half way between readings, so a curve
cannot overshoot into volatilities that were never quoted.

## Touch

The chart reads raw pointer events, so the crosshair follows a drag at once.
`onTouch` reports a `VolatilityTouchDetails` holding one `VolatilityReadout` per
curve — the nearest reading on each — and `null` when the pointer leaves.

```dart
VolatilityCurveChart(
  slices: slices,
  tooltipBuilder: (context, details) => Card(
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final readout in details.readouts)
            Text('${readout.curve.slice.label}: '
                '${(readout.point.volatility * 100).toStringAsFixed(1)}%'),
        ],
      ),
    ),
  ),
);
```

## Animation

`animationDuration` draws the curves in from the left; `animationCurve` eases it
and `animateOnMount` controls whether the first build animates. The chart
animates again whenever `slices` changes identity.
