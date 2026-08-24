# Chart types

`chartType` decides what the candle area draws:

```dart
KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: false,
  watermarkAssetPath: 'assets/logo.svg',
  timeFrame: const Duration(minutes: 15),
  chartType: ChartType.bars,       // candles, bars, line, area, baseline
  baselinePrice: 42_000,           // baseline only; defaults to the oldest close in view
);
```

![Bars, baseline, area, step line, HLC area and columns](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/chart-types.png)

| `ChartType` | Draws |
| --- | --- |
| `candles` | a filled or hollow body with a wick — the default |
| `bars` | the high-low range, open ticked left and close ticked right |
| `line` | a line through the closes |
| `area` | the same line with the area beneath it washed in |
| `baseline` | the line washed towards a level, up-coloured above it and down-coloured below |
| `stepLine` | the same line, holding each close flat until the next one |
| `hlcArea` | the high-low range washed in, with the close drawn through it |
| `columns` | a column per candle, from the baseline to the close |

`isLine: true` still means `ChartType.area`, so nothing written against the older
API changes behaviour.

## Transformed candles

Heikin-Ashi, Renko, three-line break, Kagi, point & figure and range bars all
rewrite the candles rather than the way they are drawn, so they are transforms
rather than chart types. Run the list through `CandleTransforms` and recompute
the indicators over the result:

```dart
final ha = CandleTransforms.heikinAshi(candles);
DataUtil.calculate(ha);

final bricks = CandleTransforms.renko(
  candles,
  brickSize: CandleTransforms.atrBrickSize(candles) ?? 25,
);
DataUtil.calculate(bricks);

KChartWidget(ha, ChartColors(), /* … */);
```

![Heikin-Ashi candles beside the same market as Renko bricks](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/aggregations.png)

Heikin-Ashi keeps one candle per candle, at the same times, so anything drawn on
the chart stays where it was. The rest throw time away between bars, and each
carries the volume of the candles it covers:

| Transform | What draws a bar |
| --- | --- |
| `renko(brickSize:)` | price closing a whole brick beyond the last; a reversal costs two |
| `lineBreak(lines: 3)` | a close beyond the last block, or beyond the extreme of the last `lines` blocks to turn round |
| `kagi(reversal:, asPercent:)` | a retracement of `reversal` from the extreme; a whole trend is one segment |
| `pointAndFigure(boxSize:, reversalBoxes: 3)` | a whole box of travel, read off the highs and lows; a new column takes `reversalBoxes` back |
| `rangeBars(range:)` | price travelling `range` from where the bar opened |

`atrBrickSize` sizes a brick, a box, a reversal or a range from the market's own
average true range, which is the usual way to pick one:

```dart
final step = CandleTransforms.atrBrickSize(candles) ?? candles.last.close * 0.005;

final blocks = CandleTransforms.lineBreak(candles);
final segments = CandleTransforms.kagi(candles, reversal: step);
final columns = CandleTransforms.pointAndFigure(candles, boxSize: step);
final bars = CandleTransforms.rangeBars(candles, range: step);
```

![Line break, Kagi, point & figure and range bars](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/bar-types.png)

Every one of them hands back plain candles at their own times, so the chart, the
indicators and the drawing tools all work over them unchanged. What each bar
means differs: a Kagi segment is a whole trend, a point-and-figure candle is a
whole column of boxes, and a range bar is exactly `range` of travel.

---

[← All docs](README.md) · [Package README](../README.md)
