# Hyperparameter sweep

![A hyperparameter sweep as a grid of validation losses with the best combination starred](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/sweep.png)

`SweepChart` lays a two-setting sweep out as a grid of scores — a learning rate
across, a batch size down — coloured good to bad, with the **best combination
starred** and a last column and row holding the **mean** of each setting, which
is what it is worth whatever the other is set to.

```dart
SweepChart(
  trials: [
    for (final r in runs)
      SweepTrial(x: r.learningRate, y: r.batchSize, score: r.valLoss),
  ],
  xAxisLabel: 'learning rate',
  yAxisLabel: 'batch size',
);
```

The chart fills its constraints. When the height is unbounded, it uses
`defaultHeight`. It is built on `HeatmapChart`.

## Trials

| Field | Description |
| --- | --- |
| `x`, `y` | The two settings; the grid has a column per distinct `x` and a row per distinct `y`, ascending |
| `score` | The result: a validation loss, an accuracy |
| `data` | App data, returned on touch |

Trials that share both settings are averaged. A trial whose settings or score
are not finite is skipped, and a combination nobody tried is an empty square.

## The grid

`sweepGrid(trials, lowerIsBetter:)` returns what the chart draws:

| Member | Description |
| --- | --- |
| `xs`, `ys` | The distinct settings |
| `scores[y][x]`, `counts[y][x]` | The mean score and the trial count of each combination |
| `bestX`, `bestY`, `best` | The best combination — lowest, or highest with `lowerIsBetter: false` |
| `columnMeans`, `rowMeans` | The mean score of each setting |

## Appearance

| Parameter | Description |
| --- | --- |
| `lowerIsBetter` | Which end of the scores is good; sets the colour direction too |
| `goodColor`, `midColor`, `badColor` | The scale |
| `showMarginals`, `marginalLabel` | The mean column and row |
| `showValues`, `scoreFormatter` | Scores written in the squares |
| `xFormatter`, `yFormatter` | Setting labels; `3e-4`, `128` by default |
| `yAxisWidth`, `xAxisHeight`, `spacing`, `radius` | Layout |

## Touch

`onTouch` reports a `SweepTouchDetails` with the settings `x` and `y`, the
`score`, the trial `count`, and whether the square `isBest` or a marginal, and
`null` when the pointer leaves.

[← All docs](README.md) · [Package README](../README.md)
