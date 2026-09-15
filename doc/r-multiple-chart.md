# R-multiple distribution

![Trade results in R with win rate, expectancy, profit factor and SQN](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/r-multiple.png)

`RMultipleChart` shows how a strategy's trades turned out in R — each result as
a multiple of what the trade risked — with the figures position sizing is read
from: win rate, average win and loss, expectancy, profit factor and SQN.

```dart
RMultipleChart(
  results: rMultiplesFrom(pnls, risks),
);
```

A row of statistics sits over a [histogram](histogram-chart.md). Its bins split
at zero, so no bin mixes wins with losses; losses take `lossColor`, wins
`profitColor`, and lines mark zero and the expectancy.

The chart fills its constraints. When the height is unbounded, it uses
`defaultHeight`.

## Data

`results` is a list of trade results already in R. To get them from money,
`rMultiplesFrom(pnl, risk)` divides each trade's profit by its risk — the
distance to the stop times the size — pairing the lists by position. A trade
whose risk is not a positive number is skipped.

## Statistics

`RMultipleStats.fromResults(results)` works out:

| Field | Description |
| --- | --- |
| `count`, `wins`, `losses` | A result of exactly zero is neither win nor loss |
| `winRate` | Wins over all results, from 0 to 1 |
| `total` | Every result added up |
| `expectancy` | The average result: what a trade is worth before it is taken |
| `averageWin`, `averageLoss` | The loss is negative |
| `largestWin`, `largestLoss` | The loss is negative |
| `profitFactor` | Everything won over everything lost; infinite with no losses |
| `standardDeviation` | The sample standard deviation of the results |
| `sqn` | System quality number: expectancy over its spread, times √count |

Results that are not finite are skipped.

## Statistics row

`defaultRMultipleStats(stats)` gives the figures shown by default. Replace them
with `statsBuilder`, which returns a list of `RMultipleStat(label, value,
color:)` — for translated labels, or other figures:

```dart
RMultipleChart(
  results: results,
  statsBuilder: (s) => [
    RMultipleStat('معاملات', '${s.count}'),
    RMultipleStat('انتظار', '${s.expectancy.toStringAsFixed(2)}R'),
  ],
);
```

`showStats: false` hides the row. `statLabelStyle`, `statValueStyle`,
`statSpacing` and `statsGap` style it.

## Histogram

| Parameter | Description |
| --- | --- |
| `binWidth` | How many R each bin spans (default `0.5`) |
| `profitColor`, `lossColor` | Bins above and below zero |
| `showZeroLine`, `showExpectancyLine`, `referenceColor` | The reference lines |
| `barSpacing`, `barRadius` | Bar shape |
| `tickCount`, `valueFormatter`, `axisLabelStyle`, `gridColor` | Axes; values default to `1.5R` |
| `padding`, `backgroundColor` | Around and behind the chart |

`rMultipleBins(results, binWidth:)` returns the bins, edges on whole multiples
of the width.

## Touch and animation

`onTouch`, `tooltipBuilder`, `animationDuration`, `animationCurve` and
`animateOnMount` are passed to the histogram and behave as they do on
[`HistogramChart`](histogram-chart.md).
