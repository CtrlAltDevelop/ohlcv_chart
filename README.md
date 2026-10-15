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
- **39 more chart widgets** — series, pie, heatmap, treemap, sankey, depth,
  order flow, and the charts a backtest report is made of.
- **Fully themeable** — `ChartStyle`, `ChartColors` and `ChartTranslations`.

See the [full feature list](doc/features.md) and the [gallery](doc/gallery.md).

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

## Preview

<table>
<tr>
<td width="33%"><a href="doc/indicators.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/overlays.png" alt="Ichimoku and Supertrend overlays"></a></td>
<td width="33%"><a href="doc/drawing-tools.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/shapes.png" alt="Drawing tools"></a></td>
<td width="33%"><a href="doc/orders-and-positions.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/trading.png" alt="Orders and positions"></a></td>
</tr>
<tr>
<td width="33%"><a href="doc/series-chart.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/series-charts.png" alt="Business charts"></a></td>
<td width="33%"><a href="doc/depth-chart.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/depth.png" alt="Depth chart"></a></td>
<td width="33%"><a href="doc/heatmap-chart.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/heatmap.png" alt="Heatmap"></a></td>
</tr>
</table>

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
