# Token heatmap

![A model completion with each token shaded by how surprised the model was by it](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/token-heatmap.png)

`TokenHeatmap` shows a model's text with **each token shaded by a number**:
where the model was unsure, what a prediction leaned on, which words an
attribution method found important. Tokens flow and wrap like text, so a
completion reads as a paragraph with its doubts lit up.

```dart
TokenHeatmap(
  tokens: [
    for (final t in completion.tokens)
      TokenScore.fromLogProb(t.text, t.logProb),
  ],
  showSummary: true,
);
```

The chart takes the height its text needs. In a box that is shorter, the text is
cut off. It does not scroll — put it in a scroll view for a long document.

## Tokens

| Member | Description |
| --- | --- |
| `TokenScore(token, value)` | A token's text, as the tokenizer produced it, and its score |
| `TokenScore.fromLogProb(token, logProb)` | Scores a token by its **surprisal**, `-logProb`: the less likely the model thought it, the higher the score |

A newline inside a token ends the line. Leading spaces are kept, so tokens such
as `" capital"` read as they were produced. A score that is not finite leaves
the token uncoloured.

## Colour

The default `scale` runs green (confident) through amber to red (surprising),
which suits surprisals and entropies. For probabilities, where high is
confident, turn it over:

```dart
TokenHeatmap(
  tokens: probabilities,
  scale: HeatmapGradientScale(colors: [red, amber, green]),
  minValue: 0,
  maxValue: 1,
);
```

`minValue` and `maxValue` fix the ends of the scale — useful to compare two
completions on the same colours — and otherwise take the lowest and highest
score. Text is dark on a light colour and light on a dark one.

## Numbers

| Function | Description |
| --- | --- |
| `summarizeTokens(tokens)` | `count`, `mean`, `max`, `maxIndex` and `perplexity` (`exp(mean)`, for surprisals in nats) |
| `flowTokens(tokens, width, measure)` | The `TokenBox`es and the height, without a renderer |
| `tokenBoxAt(boxes, local)` | Which token a point is over |

`showSummary` writes the mean and the perplexity beside the legend.

## Appearance

| Parameter | Description |
| --- | --- |
| `textStyle` | The text; 14 px by default — use a monospaced font for code |
| `tokenRadius`, `verticalPadding`, `lineGap` | The rectangles and the lines |
| `showLegend`, `lowLabel`, `highLabel`, `legendStyle` | The scale bar |
| `valueFormatter`, `hoverBorder` | Score formatting and the hover outline |

## Touch

`onTouch` reports a `TokenTouchDetails` with the token's `index`, the `token` and
its `rect`, and `null` when the pointer leaves. `tooltipBuilder` builds a card
beside the token — a natural place to list the alternatives the model
considered, from `TokenScore.data`.

[← All docs](README.md) · [Package README](../README.md)
