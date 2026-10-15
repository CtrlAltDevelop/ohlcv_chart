# ohlcv_chart

[![pub package](https://img.shields.io/pub/v/ohlcv_chart.svg)](https://pub.dev/packages/ohlcv_chart)
[![pub points](https://img.shields.io/pub/points/ohlcv_chart)](https://pub.dev/packages/ohlcv_chart/score)
[![CI](https://github.com/CtrlAltDevelop/ohlcv_chart/actions/workflows/ci.yml/badge.svg)](https://github.com/CtrlAltDevelop/ohlcv_chart/actions/workflows/ci.yml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/CtrlAltDevelop/ohlcv_chart/blob/main/LICENSE)

Candlestick charts for Flutter, with indicators, drawing tools and a library of
other chart types. Pure `CustomPainter` — no WebView, no JavaScript bridge.
Free for any use, with no paid tier.

<p align="center">
  <img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/candles.png" width="720" alt="A candlestick chart with moving averages, volume and a MACD pane">
</p>

## Highlights

- **Candlestick chart** — eight chart types, Heikin-Ashi, Renko, Kagi and more,
  four price scales, sessions, comparison overlays and bar replay.
- **31 indicators** — overlays and stacked panes, each a configured instance,
  with higher-timeframe values that never repaint.
- **29 drawing tools** — Fibonacci, channels, patterns and positions, with an
  editor, undo/redo, alerts and JSON persistence.
- **55 more chart widgets** — series, pie, heatmap, treemap, sankey, depth,
  order flow, volatility and futures curves, risk and portfolio charts, the
  charts a backtest report is made of, and charts for training and serving
  language models.
- **Fully themeable** — `ChartStyle`, `ChartColors` and `ChartTranslations`.

See the [full feature list](doc/features.md) and the [gallery](doc/gallery.md).

> [!NOTE]
> This package has grown large. To keep it fast and focused, the next update
> will split it into separate packages. `ohlcv_chart` will keep only the
> candlestick (OHLCV) chart, its indicators and its drawing tools; the other
> chart widgets will move to their own packages.

## Installation

```yaml
dependencies:
  material_ui: ">=1.0.0 <2.0.0"
  ohlcv_chart: ">=3.1.1 <4.0.0"
```

Requires Dart 3.12 and Flutter 3.44 or later. Widgets are built on the
`material_ui` package rather than the Material library that used to ship in the
Flutter SDK, so import `package:material_ui/material_ui.dart` where your app
imported `package:flutter/material.dart`.

## Quick start

Pass a list of `KLineEntity` to `KChartWidget`. Call `DataUtil.calculate` first
so the indicator values are populated:

```dart
import 'package:ohlcv_chart/ohlcv_chart.dart';

DataUtil.calculate(candles);

KChartWidget(
  candles,
  ChartColors(),
  timeFrame: const Duration(minutes: 15),
  indicators: [MaIndicator(period: 20), MacdIndicator()],
  fixedLength: 2,
);
```

The [example app](example/) demonstrates every option in the package.

## Charts

Screenshots and a reference page for every chart are in the
[gallery](doc/gallery.md).

### Candlestick, indicators and drawing

- **Chart types** — [candles, Heikin-Ashi, Renko, Kagi and more](doc/chart-types.md),
  [symbol comparison](doc/comparison.md), [bar replay](doc/bar-replay.md)
- **Indicators** — [31 overlays and stacked panes](doc/indicators.md),
  [panes](doc/panes.md)
- **Drawing tools and trading** — [29 drawing tools](doc/drawing-tools.md),
  [line editor](doc/line-editor.md),
  [orders and positions](doc/orders-and-positions.md),
  [event marks](doc/event-marks.md)

### Business and statistical

- **Series, pie, radar, heatmap and depth** — [series](doc/series-chart.md),
  [pie and radar](doc/pie-chart.md), [heatmap](doc/heatmap-chart.md),
  [depth](doc/depth-chart.md)
- **Dashboards and reports** — [treemap](doc/treemap-chart.md),
  [sunburst](doc/sunburst-chart.md), [sankey](doc/sankey-chart.md),
  [chord](doc/chord-chart.md), [marimekko](doc/marimekko-chart.md),
  [stream](doc/stream-chart.md), [parallel coordinates](doc/parallel-chart.md),
  [slope and bump](doc/slope-chart.md), [bubble](doc/bubble-chart.md),
  [box plot](doc/box-plot-chart.md), [histogram](doc/histogram-chart.md),
  [violin and ridgeline](doc/violin-chart.md), [dumbbell](doc/dumbbell-chart.md),
  [bullet](doc/bullet-chart.md), [gauge](doc/gauge-chart.md),
  [waffle](doc/waffle-chart.md), [funnel](doc/funnel-chart.md),
  [sparkline grid](doc/sparkline-grid.md)

### Trading analysis

- **Order flow and derivatives** — [market profile](doc/market-profile-chart.md),
  [footprint](doc/footprint-chart.md),
  [order-book heatmap](doc/book-heatmap-chart.md),
  [cumulative delta](doc/cumulative-delta-chart.md),
  [liquidity map](doc/liquidity-map-chart.md),
  [open interest and funding](doc/open-interest-chart.md),
  [options payoff](doc/option-payoff-chart.md),
  [volatility curves](doc/volatility-curve-chart.md),
  [volatility surface](doc/volatility-surface-chart.md),
  [pair spread](doc/pair-spread-chart.md),
  [futures curve](doc/futures-curve-chart.md)
- **Backtests and results** — [equity curve](doc/equity-curve-chart.md),
  [Monte Carlo fan](doc/monte-carlo-chart.md),
  [R-multiple](doc/r-multiple-chart.md),
  [trade timeline](doc/trade-timeline-chart.md),
  [seasonality](doc/seasonality-chart.md), [calendar](doc/calendar-chart.md),
  [waterfall](doc/waterfall-chart.md), [MAE / MFE](doc/mae-mfe-chart.md),
  [value at risk](doc/var-chart.md),
  [efficient frontier](doc/efficient-frontier-chart.md),
  [activity clock](doc/activity-clock-chart.md)

### Models, tokens and AI — new

- **Training** — [training curves](doc/training-curve-chart.md),
  [scaling laws](doc/scaling-law-chart.md),
  [hyperparameter sweep](doc/sweep-chart.md),
  [training timeline](doc/training-timeline-chart.md)
- **Evaluation** — [benchmark matrix](doc/benchmark-matrix-chart.md),
  [model cost against quality](doc/model-pareto-chart.md),
  [evaluation breakdown](doc/eval-breakdown-chart.md)
- **Serving and tokens** — [latency bands](doc/latency-band-chart.md),
  [token usage](doc/token-usage-chart.md),
  [token heatmap](doc/token-heatmap.md)

### Axes and interaction

- **Axes, sessions and layout** — [price axes](doc/price-axis.md),
  [date axis](doc/date-axis.md), [sessions](doc/sessions.md),
  [sizing](doc/sizing.md), [theming](doc/theming.md)
- **Interaction** — [legend and crosshair](doc/legend-and-crosshair.md),
  [long-press readout](doc/readout.md),
  [driving the chart](doc/driving-the-chart.md)

## Documentation

- [Documentation index](doc/README.md) — a reference page per feature
- [Features](doc/features.md) and [gallery](doc/gallery.md)
- [Changelog](CHANGELOG.md) — what changed in each release
- [Migrating from 1.x](doc/migrating-from-1.x.md) and
  [from fl_chart and candlesticks](doc/migrating-from-fl_chart.md)

## Contributing

Bug reports and pull requests are welcome — see
[`CONTRIBUTING.md`](CONTRIBUTING.md). If the package is useful to you, a star
on the [repository](https://github.com/CtrlAltDevelop/ohlcv_chart) or a like on
[pub.dev](https://pub.dev/packages/ohlcv_chart) helps others find it.

## License

Released under the MIT License. See [LICENSE](LICENSE). The rendering core is
derived from the open-source `k_chart` package and has since been substantially
extended.
