# k_chart_pro

A candlestick (K-line) and market-depth chart for Flutter, drawn entirely with
`CustomPainter` — no WebView, no JavaScript bridge.

## Features

- **Candlestick and line modes** with pinch-to-zoom, fling scrolling and long-press crosshair.
- **Main-chart overlays** — moving averages (`MA`), Bollinger bands (`BOLL`) and parabolic SAR, any combination at once.
- **Sub-charts** — `MACD`, `KDJ`, `RSI`, `WR` and `CCI`, stacked below the main chart.
- **Drawing tools** — trend lines, horizontal lines and vertical lines, each interactively placed, dragged, restyled (colour and thickness) and removed, with add/remove callbacks so you can persist them.
- **Buy/sell signal markers** pinned to candles.
- **Depth chart** — a separate `DepthChart` widget rendering bid/ask cumulative depth with a long-press readout.
- **Info dialog** on long press, either the built-in Material popup or your own builder.
- **"Now price" line** with a live countdown to the close of the current candle.
- **SVG watermark** loaded from an asset path you supply.
- **Fully themeable** — `ChartStyle` for geometry and `ChartColors` for every colour; `ChartTranslations` for every label.

## Install

```yaml
dependencies:
  k_chart_pro: ^1.0.0
```

## Usage

### Candlestick chart

Feed it a `List<KLineEntity>`. Indicator values are computed in place by
`DataUtil.calculate` before the first paint, and again whenever new candles arrive:

```dart
import 'package:k_chart_pro/k_chart_pro.dart';

DataUtil.calculate(candles);

KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: false,
  watermarkAssetPath: 'assets/logo.svg',
  timeFrame: const Duration(minutes: 15),
  mainStateLi: const {MainState.MA, MainState.BOLL},
  secondaryStateLi: const {SecondaryState.MACD},
  timeFormat: TimeFormat.YEAR_MONTH_DAY_WITH_HOUR,
  fixedLength: 2,
  onLoadMore: (isRight) {
    if (!isRight) fetchOlderCandles();
  },
);
```

`KLineEntity.fromJson` accepts the usual OHLCV shape (`open`, `high`, `low`,
`close`, `vol`, `time`/`id`), or build the entity directly.

### Drawing tools

Set `currentDrawingTool` to put the chart into placement mode and handle the
callbacks to persist what the user draws:

```dart
KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: true,
  watermarkAssetPath: 'assets/logo.svg',
  timeFrame: const Duration(minutes: 15),
  currentDrawingTool: DrawingTool.trend,
  trendLines: savedTrendLines,
  horizontalLines: savedHorizontalLines,
  verticalLines: savedVerticalLines,
  onAddTrendLine: repository.save,
  onRemoveTrendLine: repository.delete,
);
```

Tapping an existing line selects it and opens an edit panel for its colour and
thickness; the same `onAdd*` callback fires with the updated line.

### Depth chart

```dart
DepthChart(
  bids,
  asks,
  baseUnit: 2,
  quoteUnit: 6,
);
```

`DepthEntity` pairs a `price` with the `vol` at that price; the painter accumulates them.

### Theming

```dart
KChartWidget(
  candles,
  ChartColors(
    upColor: const Color(0xFF12B886),
    dnColor: const Color(0xFFFA5252),
    bgColor: const Color(0xFF0E1116),
  ),
  chartStyle: const ChartStyle(),
  chartTranslations: const ChartTranslations(),
  // …
);
```

`ChartTranslations` carries every on-chart label (`date`, `open`, `high`, `low`,
`close`, `changeAmount`, `change`, `amount`), so localising the chart is a matter
of building one from your own `AppLocalizations`.

## Notes

- `KChartWidget` imports `dart:io` for a platform check, so it targets the mobile
  and desktop embedders.
- `watermarkAssetPath` must point at an SVG registered in your app's `pubspec.yaml`
  assets; a missing asset is ignored and the chart renders without a watermark.

## Credits

The rendering core began as a derivative of the open-source `k_chart` package and
has since been substantially extended with drawing tools, signals, multi-indicator
stacking and a reworked painter pipeline.

## License

MIT — see [LICENSE](LICENSE).
