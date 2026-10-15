# Training timeline

`TrainingTimelineChart` shows training jobs on a timeline: a lane per machine or
pool, a bar from start to end **coloured by how the job finished**, and a strip
underneath counting how many jobs were running at each moment. It answers "what
was the cluster doing, and where did it fall over?"

```dart
TrainingTimelineChart(
  jobs: [
    TrainingJob(
      name: 'llama-8b-sft',
      node: 'pod-a',
      start: DateTime(2026, 9, 1, 8),
      end: DateTime(2026, 9, 1, 19),
      status: JobStatus.completed,
      gpus: 64,
    ),
    TrainingJob(name: 'rl-sweep', node: 'pod-b', start: DateTime(2026, 9, 1, 10)),
  ],
);
```

The chart fills its constraints. When the height is unbounded, it uses
`defaultHeight`. It is a `TradeTimelineChart` underneath, so its lanes, time
axis and pointer behave as that chart's do.

## Jobs

| Field | Description |
| --- | --- |
| `name` | What the job is called |
| `start`, `end` | When it ran; a null `end`, or `JobStatus.running`, runs to `now` |
| `node` | The lane: a machine or a pool; null is an unnamed lane |
| `status` | `running`, `completed`, `failed`, `preempted` or `cancelled` |
| `gpus`, `data` | Accelerators held, and app data returned on touch |

## Colour

| Status | Colour parameter |
| --- | --- |
| `running` | `runningColor` |
| `completed` | `completedColor` |
| `failed` | `failedColor` |
| `preempted` | `preemptedColor` |
| `cancelled` | `cancelledColor` |

`colorOf(status)` returns the colour in use, for a legend of your own.

## Touch

`onTouch` reports a `TrainingJobTouchDetails` with the `job`, the `time` under
the pointer and `duration(now)`, and `null` when the pointer leaves.
`tooltipBuilder` builds a card beside the bar.

## Appearance

| Parameter | Description |
| --- | --- |
| `showRunningCount`, `countColor` | The strip counting concurrent jobs |
| `laneLabelWidth`, `laneLabelStyle` | The lane names |
| `axisLabelStyle`, `timeFormatter`, `gridColor` | The time axis |
| `now` | The time running jobs are drawn to |

[← All docs](README.md) · [Package README](../README.md)
