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
      TokenScore.fromLogProb(
        t.text,
        t.logProb,
        alternatives: [
          for (final a in t.topLogProbs)
            TokenAlternative(a.text, exp(a.logProb)),
        ],
      ),
  ],
  highlightTop: 3,
  showStrip: true,
  showSummary: true,
);
```

The chart takes the height its text needs. In a box that is shorter, the text is
cut off. It does not scroll — put it in a scroll view for a long document.

## Tokens

| Member | Description |
| --- | --- |
| `TokenScore(token, value)` | A token's text, as the tokenizer produced it, and its score |
| `probability` | The probability the model gave the token, 0 to 1, for the readout |
| `alternatives` | `TokenAlternative(token, probability)` — what else the model was weighing, most likely first |
| `TokenScore.fromLogProb(token, logProb)` | Scores a token by its **surprisal**, `-logProb`: the less likely the model thought it, the higher the score. Sets `probability` too |

A newline inside a token ends the line. Leading spaces are kept, so tokens such
as `" capital"` read as they were produced. A score that is not finite leaves
the token uncoloured.

## How it is drawn

Each token is a rounded box with room round its text. A token that begins a word
— where the tokenizer put a space — sits a little apart from the one before it,
and one that carries a word on sits close, so the boxes of a word read as a word.

| Parameter | Description |
| --- | --- |
| `shading` | `TokenShading.soft` (the default) tints the box and draws a line of the full colour under the text; `TokenShading.solid` fills it with the full colour, the text turning dark or light to suit |
| `horizontalPadding`, `verticalPadding` | Room round the text inside a box |
| `wordGap`, `tokenGap` | The gap before a token that begins a word, and before one that carries on |
| `lineGap`, `tokenRadius` | Space between lines, and the rounding |

## Reading a long text

| Parameter | What it does |
| --- | --- |
| `highlightTop: n` | Rings the *n* highest-scoring tokens and numbers them 1 to *n* — the places to look first |
| `focusAbove: v` | Leaves every token scoring below *v* unshaded and dim, so only the doubtful ones are lit |
| `showStrip` | A strip of every token's score, in order, above the legend. Over a text longer than the strip is wide, each bar is the highest of the tokens it covers, so a single bad token is never averaged away |
| `showWhitespace` | Writes spaces as `·` and line breaks as `↵`, to see what the tokenizer really produced |
| `selectedIndex` | Holds one token outlined, for a selection your app keeps |

The legend marks where the **mean** falls on the scale, and `showSummary` writes
the mean and the perplexity under it.

## The readout

Touching a token opens a card with its text, its score, its **rank** among the
tokens (`rank 2 of 28`), the probability the model gave it, and — if you
supplied them — the alternatives it was weighing instead. It needs no code:

```dart
TokenHeatmap(tokens: tokens, scoreLabel: 'surprisal')
```

`scoreLabel` names the score in it, `showReadout: false` turns it off, and
`tooltipBuilder` replaces it with a card of your own.

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
| `tokenRanks(tokens)` | Each token's rank, 1 for the highest; equal scores share one |
| `topTokens(tokens, n)` | The indices of the *n* highest, highest first |
| `binTokenScores(tokens, bins)` | The strip's bars: the highest score of each slice |
| `flowTokens(tokens, width, measure)` | The `TokenBox`es and the height, without a renderer |
| `tokenDisplay(token, showWhitespace:)` | How a token is written on screen |

## Appearance

| Parameter | Description |
| --- | --- |
| `textStyle` | The text; 14 px by default — use a monospaced font for code |
| `tokenRadius`, `verticalPadding`, `lineGap` | The rectangles and the lines |
| `showLegend`, `lowLabel`, `highLabel`, `legendStyle` | The scale bar |
| `stripHeight`, `highlightColor`, `dimColor` | The strip, the rings, the dimmed text |
| `valueFormatter`, `hoverBorder` | Score formatting and the hover outline |

## Touch

`onTouch` reports a `TokenTouchDetails` with the token's `index`, the `token`,
its `rect`, its `rank` and how many tokens were `scored`, and `null` when the
pointer leaves.

[← All docs](README.md) · [Package README](../README.md)
