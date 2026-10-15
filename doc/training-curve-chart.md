# Training curves

`TrainingCurveChart` draws the loss and accuracy curves of one or more training
runs, the way a training dashboard does: raw readings faint under a **smoothed**
line, an optional **log axis** for a loss that spans decades, the **best
checkpoint** of each run marked, and the step a run's loss **diverged** at.

```dart
TrainingCurveChart(
  runs: [
    TrainingRun(label: 'train', points: train),
    TrainingRun(label: 'val', points: val, dashed: true),
  ],
  smoothing: 0.9,
  logY: true,
  gapBetween: (0, 1), // shade the train/validation gap
);
```

The chart fills its constraints. When the height is unbounded, it uses
`defaultHeight`.

## Runs

| Type | Fields |
| --- | --- |
| `TrainingPoint` | `step` (optimiser step, epoch or tokens seen), `value` |
| `TrainingRun` | `label`, `points`, `color`, `dashed`, `data` |

A point whose value is not finite leaves a gap in the line; a run of one point,
or of none, draws nothing and does not throw.

## Smoothing

`smoothing` runs from 0 (the raw line) to just under 1. It is the exponential
moving average dashboards use, corrected for its slow start, so the first
readings are not pulled toward zero. With `showRaw` the unsmoothed readings stay
as a faint line at `rawOpacity`.

## What it marks

| Mark | Meaning | Switch |
| --- | --- | --- |
| Ringed dot | A run's best checkpoint: its lowest loss, or its highest value when `lowerIsBetter` is false | `showBest` |
| Red line, "diverged" | The step the loss climbed past `divergenceFactor` times its lowest, or went NaN | `showDivergence` |
| Shaded band | The gap between two runs, usually train and validation — overfitting shows as the band opening | `gapBetween: (train, val)` |

## Numbers

| Function | Description |
| --- | --- |
| `smoothValues(values, weight)` | The smoothed series; null where a value was not finite |
| `bestIndex(values, lowerIsBetter:)` | The best reading's index |
| `divergenceIndex(values, factor:)` | Where a loss blew up, or `null` |

## Appearance

| Parameter | Description |
| --- | --- |
| `logY` | A logarithmic value axis; readings of zero or below are not drawn |
| `lineWidth`, `palette` | Line weight and the colours runs take in turn |
| `showLegend`, `legendStyle` | Run names in the corner when there is more than one |
| `showAxes`, `stepFormatter`, `valueFormatter`, `xAxisTitle`, `yAxisTitle` | Axes |
| `gridColor`, `crosshairColor`, `bestColor`, `divergenceColor`, `gapColor` | Colours |

## Touch

`onTouch` reports a `TrainingTouchDetails` with the `step` and a `TrainingReading`
per run — its nearest `point` and `smoothed` value — and `null` when the pointer
leaves. `tooltipBuilder` builds a card beside the crosshair.

## Animation

`animationDuration` draws the lines in from the left. It runs again only when
the runs' values, `smoothing` or `logY` change.

[← All docs](README.md) · [Package README](../README.md)
