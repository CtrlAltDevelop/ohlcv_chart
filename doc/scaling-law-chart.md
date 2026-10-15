# Scaling laws

![Loss against training compute on log-log axes with the fitted power law carried to a target](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/scaling-law.png)

`ScalingLawChart` plots the loss models reached against how much they were given
— parameters, training tokens or FLOPs — on log-log axes, fits the **power law**
through them and carries it past the largest model, so the question "what would
ten times the compute buy?" has a picture.

```dart
ScalingLawChart(
  points: [
    for (final m in runs) ScalingPoint(scale: m.flops, loss: m.loss, label: m.name),
  ],
  fitFrom: 1e19,        // leave the small models that sit off the law out
  extrapolateTo: 1e24,
  targetLoss: 1.8,      // where is the line predicted to reach this?
);
```

The chart fills its constraints. When the height is unbounded, it uses
`defaultHeight`.

## The fit

`fitPowerLaw(points)` is a least-squares line through the logarithms of the
points, `loss = coefficient × scale ^ exponent`:

| Field | Description |
| --- | --- |
| `exponent` | The slope on the log-log plot; negative when more scale lowers the loss |
| `coefficient` | The loss at a scale of 1 |
| `rSquared` | How much of the variation in log loss the line explains |
| `logResidual` | The standard deviation of the points' distance from the line, in log10 of the loss |
| `predict(scale)`, `scaleFor(loss)` | The loss at a scale, and the scale for a loss |

It needs two points at two different scales. A point whose scale or loss is not
a positive finite number is skipped. The fit is a pure power law with no
irreducible term, which is a good description over the range where models are
still improving; `fitFrom` leaves out the small models that sit off it.

## What is drawn

| Mark | Meaning |
| --- | --- |
| Dots | The models, named beside them with `showLabels` |
| Solid line | The fit across the range of the points |
| Dashed line | The fit carried on to `extrapolateTo` |
| Band | One residual standard deviation either side of the fit (`showBand`) |
| Green ring | Where the fit reaches `targetLoss`, with the scale written beside it |
| Corner text | The law and its R² (`showFitLabel`) |

## Touch

`onTouch` reports a `ScalingTouchDetails` with the `point`, what the fit
`predicted` there and the `ratio` — 1.1 is a model 10% worse than the law — or
`null` when the pointer leaves. `tooltipBuilder` builds a card beside the point.

## Appearance

| Parameter | Description |
| --- | --- |
| `pointColor`, `fitColor`, `bandColor`, `targetColor` | Colours |
| `dotRadius`, `labelStyle` | Point size and label style |
| `scaleFormatter`, `lossFormatter` | Axis labels; the scale is written as `1e21` by default |
| `xAxisTitle`, `yAxisTitle`, `axisLabelStyle`, `gridColor` | Axes and grid |

[← All docs](README.md) · [Package README](../README.md)
