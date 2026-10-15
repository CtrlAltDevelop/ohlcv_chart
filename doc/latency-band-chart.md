# Latency bands

`LatencyBandChart` shows an inference service's latency over time as **bands**:
the median as a line, the span up to the 95th percentile and on to the 99th
shaded, an **objective** drawn across, and the intervals that broke it marked.
The tail is what users feel, and a median line alone hides it.

```dart
LatencyBandChart(
  samples: [
    for (final w in windows)
      LatencySample(time: w.start, p50: w.p50, p95: w.p95, p99: w.p99),
  ],
  slo: 1200,
  valueFormatter: (ms) => '${ms.round()} ms',
);
```

The chart fills its constraints. When the height is unbounded, it uses
`defaultHeight`.

## Samples

| Field | Description |
| --- | --- |
| `time` | When the interval began |
| `p50`, `p95`, `p99` | The latencies, in one unit of your choice |
| `data` | App data, returned on touch |

A sample with a value that is not finite is left out of the lines and the bands.

## The objective

`slo` draws a dashed line, and `sloPercentile` says which percentile it is set
on — `p95` by default. Every interval whose percentile is over it gets a red
mark on the bottom of the plot, and is flagged `breached` on touch.

| Function | Description |
| --- | --- |
| `sloBreaches(samples, slo, percentile:)` | The indices of the intervals over the objective |

An interval exactly on the objective is within it.

## Appearance

| Parameter | Description |
| --- | --- |
| `logY` | A logarithmic axis, for a tail far above the median |
| `medianColor`, `p95Color`, `p99Color`, `sloColor`, `breachColor` | Colours |
| `lineWidth`, `showLegend`, `showBreaches` | Line weight, the legend and the marks |
| `valueFormatter`, `timeFormatter`, `yAxisTitle` | Axes |

## Touch

`onTouch` reports a `LatencyTouchDetails` with the `sample`, its `index` and
whether it `breached`, and `null` when the pointer leaves. `tooltipBuilder`
builds a card beside the crosshair.

[← All docs](README.md) · [Package README](../README.md)
