# Benchmark matrix

![Six models against six benchmarks, each score coloured by its standing in its column](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/benchmark-matrix.png)

`BenchmarkMatrixChart` compares models across benchmarks in one grid: each score
coloured by **how it stands among the models on that benchmark**, the leader of
each benchmark starred, and an average column to rank the models by.

```dart
BenchmarkMatrixChart(
  models: const ['Model A', 'Model B', 'Model C'],
  benchmarks: const ['MMLU', 'GSM8K', 'HumanEval', 'Perplexity'],
  scores: [
    [86.4, 92.0, 80.5, 5.1],
    [83.1, 88.7, 76.2, 5.6],
    [79.9, 81.3, 71.0, 6.4],
  ],
  lowerIsBetter: const {3}, // perplexity: lower wins
);
```

The chart fills its constraints. When the height is unbounded, it uses
`defaultHeight`. It is built on `HeatmapChart`.

## Reading it

Colour is **relative within a column**, so a hard benchmark and an easy one read
alike and one metric's scale does not wash out the others; the number written in
the square is the raw score. `lowerIsBetter` holds the indices of benchmarks
where a lower score wins, and turns their colours over.

The `Avg` column is each model's mean standing, 0 to 100, across the
benchmarks it has a score for. With `sortByAverage` the best model is on top.
A missing score — `null` or not finite — is an empty square and is left out of
the average.

## Numbers

| Function | Description |
| --- | --- |
| `benchmarkQuality(scores, lowerIsBetter:)` | Each score's standing in its column, 0 to 1 |
| `benchmarkAverages(quality)` | Each model's mean standing |
| `benchmarkLeaders(scores, lowerIsBetter:)` | The best model of each benchmark |

## Appearance

| Parameter | Description |
| --- | --- |
| `lowColor`, `midColor`, `highColor` | The scale, worst to best |
| `markLeaders`, `showAverage`, `averageLabel` | The star and the average column |
| `scoreFormatter`, `labelStyle`, `axisLabelStyle` | Numbers and labels |
| `modelAxisWidth`, `benchmarkAxisHeight`, `spacing`, `radius` | Layout |

## Touch

`onTouch` reports a `BenchmarkTouchDetails` with the `model`, `benchmark`, raw
`score`, its `quality`, and whether it `isLeader` or the `isAverage` column, and
`null` when the pointer leaves.

[← All docs](README.md) · [Package README](../README.md)
