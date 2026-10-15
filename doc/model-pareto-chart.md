# Model cost against quality

`ModelParetoChart` plots models by what they cost and how good they are, and
traces the **Pareto frontier** through the ones nothing beats: the cheapest way
to get each level of quality. Models off the frontier are drawn faintly, and
touching one says what the same money buys instead.

```dart
ModelParetoChart(
  models: const [
    ModelPoint(name: 'Large', cost: 15, score: 88, size: 200000, group: 'A'),
    ModelPoint(name: 'Small', cost: 0.25, score: 71, size: 128000, group: 'A'),
    ModelPoint(name: 'Open 70B', cost: 0.9, score: 79, group: 'B'),
  ],
  costFormatter: (v) => '\$${v}',
  xAxisTitle: 'Price per 1M tokens',
  yAxisTitle: 'MMLU',
);
```

The chart fills its constraints. When the height is unbounded, it uses
`defaultHeight`.

## Models

| Field | Description |
| --- | --- |
| `name` | What the model is called |
| `cost` | What it costs — a price per million tokens, a latency, a parameter count. Lower is better |
| `score` | How good it is. Higher is better |
| `size` | What the bubble's **area** shows, such as the context window; null draws every bubble alike |
| `group` | A family or provider; models of a group share a palette colour |
| `color`, `data` | A colour of its own, and app data returned on touch |

## The frontier

`paretoIndices(models)` returns the indices of the models on it, by rising cost.
A model is on it when none is both cheaper and better. Of two models at one cost
only the higher score is on it. A model whose cost or score is not finite is
never on it.

## Axes

`logCost` (on by default) puts cost on a logarithmic axis, since prices span
decades; a model whose cost is zero or less is then not drawn. Turn it off for a
linear axis.

## Appearance

| Parameter | Description |
| --- | --- |
| `minRadius`, `maxRadius` | The radii the sizes are spread between |
| `palette` | Colours taken in turn by groups |
| `showFrontier`, `frontierColor`, `dimOpacity` | The frontier line, and how faint off-frontier models are |
| `labelAll`, `labelStyle` | Name every model, not only those on the frontier |
| `showLegend`, `legendStyle` | The groups, in the corner |
| `costFormatter`, `scoreFormatter`, `xAxisTitle`, `yAxisTitle` | Axes |

## Touch

`onTouch` reports a `ModelTouchDetails` with the `model`, whether it is
`onFrontier`, and — for one that is not — `beatenBy`: the best frontier model
that costs no more. `null` when the pointer leaves.

[← All docs](README.md) · [Package README](../README.md)
