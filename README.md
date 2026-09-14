# ohlcv_chart — the most complete candlestick chart for Flutter, with every drawing tool and indicator

> **Read the changelog and the docs.** This package moves quickly — a release
> can carry several new indicators, a new widget or two, and behaviour that has
> been sharpened since the last one. The list below is a summary and goes stale
> between releases; [`CHANGELOG.md`](CHANGELOG.md) says what actually changed
> and why, and [`doc/`](doc/README.md) has a page per feature with the detail.
> Both are worth a minute before you upgrade, and before you conclude something
> is missing.

## Support

The full package is free to use in your own projects — every chart type, all 31
indicators and all 29 drawing tools, nothing held back, nothing paywalled,
commercial projects included. I keep it updated weekly: new indicators, drawing
tools and fixes land as I use it myself.

If it saves you some work, all I ask in return is:

- ⭐ a **star** on the [repository](https://github.com/CtrlAltDevelop/ohlcv_chart)
- 👍 a **like** on [the package on pub.dev](https://pub.dev/packages/ohlcv_chart)
- 👤 a **follow** on [GitHub](https://github.com/CtrlAltDevelop)

That is the whole price, and it is what keeps the weekly updates coming.

A candlestick (K-line) and market-depth chart for Flutter, drawn entirely with
`CustomPainter` — no WebView, no JavaScript bridge.

Named for the open-high-low-close-volume bars it renders.

![Candles with moving averages, volume and MACD](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/candles.png)

## Features

- **Series charts for everything else** — `SeriesChart` draws plain values rather than candles: lines with four curves, areas that fade to a baseline and split colour where they cross it, rounded bars, several series at once, axes you write or hide, a tooltip of your own, one crosshair shared across charts, a range strip for long data and animated data changes. The [migration guide](doc/migrating-from-fl_chart.md) maps `fl_chart` and `candlesticks` onto it.
- **Eight chart types** — candles, OHLC bars, a line, a step line, a filled area, an HLC area, a baseline chart and columns — plus Heikin-Ashi, Renko, three-line break, Kagi, point & figure and range bars as transforms of the candles themselves.
- **31 indicators**, each a configured instance rather than a flag — so `ATR(8)`, `ATR(14)` and `ATR(20)` are three panes, with their own settings and colours.
- **Main-chart overlays** — `MA`, `EMA`, `BOLL`, `SAR`, `VWAP` in three flavours — whole-series, anchored to a candle, or restarted each session with standard-deviation bands — Supertrend, Keltner and Donchian channels, the Ichimoku Cloud, pivot points and a volume profile.
- **Swing readers** — a zigzag through the swing highs and lows, Fibonacci retracement of the last swing, and Elliott wave labels, all sized to the market by default.
- **Sub-charts** — `MACD`, `KDJ`, `RSI`, `WR`, `CCI`, `ATR`, `OBV`, `MFI`, `DMI`, Aroon, Stochastic RSI, `ROC`, `TRIX`, a volume average and the Awesome oscillator, each in its own stacked pane — resizable and reorderable by dragging.
- **Linear, logarithmic, percentage or indexed-to-100 price axis**, so a decade of compounding reads as well as an afternoon — invertible, with the window's high, low and average close markable on it.
- **A price scale you can drag** — pull the labels to stretch or flatten the candles, drag the chart to slide the window, double-tap to fit it back; from code as well, through the controller.
- **A price axis that can be pinned** — `lockPriceScale` holds it at one range instead of refitting it to whatever is on screen, so scrolling moves the candles under a scale that stays put rather than rescaling every number on the axis; and `priceAxisWidth` holds a gutter back for the labels, so the candles stop short of them instead of sliding underneath.
- **Axes that read as round numbers** — both axes choose their values first and are ruled where the labels fall, so a price scale steps `69000, 69500, 70000` and an intraday date axis lands on the hour, never on whatever value happened to fall on an evenly spaced pixel.
- **29 drawing tools** — levels and rays, trend lines, arrows, extended lines, boxes, ellipses, triangles, parallel channels, pitchforks, Gann fans and boxes, four Fibonacci tools, a regression trend with its bands, XABCD patterns, multi-leg paths, price and date brackets, a measuring tool, planned positions with their risk-to-reward, notes, callouts, flags and freehand strokes; each placed by tap or drag, then dragged, locked, hidden and removed.
- **A line editor** that opens on selection: colour, opacity, thickness, solid/dashed/dotted stroke, fill, label text and visibility, alerts, lock and delete — every option list, control and pixel of it configurable through `DrawingStyle`.
- **Undo and redo**, through a `ChartDrawingController` that owns the drawings and their history, with ⌘Z, ⇧⌘Z and Delete on the chart itself.
- **Select several and edit them together** — shift- or ⌘-click, or ⌘A; then drag, restyle or delete the lot in one step, with ⌘C/⌘V/⌘D to copy and ⌘]/⌘[ to restack.
- **Exact coordinates** — a dialog over any drawing's anchors, each price and candle typed in rather than placed by eye.
- **Style templates** — save one drawing's look and put it on the rest.
- **Indicator templates** — a named set of indicators saved and put on any chart in one gesture, with four starter sets to begin from.
- **A layout that persists** — every drawing serialises, so `jsonEncode(drawings.toJson())` and `ChartDrawings.fromJson` are the whole story.
- **A drawing manager** — a ready-made panel listing what is drawn, with show/hide, lock, delete, undo, redo and clear.
- **Price alerts** on a level, a trend line, either side of a channel or every step of a retracement, reported when the market crosses one.
- **Indicator alerts** — an RSI over 70, a histogram turning positive — and panes that can be logarithmic or read as a percentage, with any indicator computable over another's output.
- **Higher timeframes** — a daily moving average on a fifteen-minute chart, through `TimeframeIndicator`; each candle reads the last higher-timeframe bar that had closed when it opened, so the line never repaints and never shows a value from its own future.
- **A right-click menu** on the chart and on any drawing — coordinates, duplicate, restack, lock, hide, alert, delete; paste, select all, fit the scale, undo — with your own items added through one builder.
- **Crosshair on hover** and an **OHLC legend** above the chart, which is how a chart reads on a desktop.
- **Or no interaction at all** — `scrollEnabled` and `zoomEnabled` turn the chart's own gestures off, for an intraday session, a thumbnail or a figure that is meant to sit still rather than be navigated; your own code can still drive it.
- **Driven from your own code** — `KChartController` zooms, scrolls back to the live candle and hands you the chart as a PNG.
- **The visible window, read and set** — which candles are on screen, go-to-date, fit-to-screen, and a callback whenever it moves.
- **An overview strip** — `ChartOverview` draws the whole history under the chart with the visible window lit; drag it to scrub, drag its edges to zoom, tap to jump.
- **Charts kept in step** — `ChartLink` holds any number of charts on the same window and crosshair, so scrolling, zooming or pointing at one carries the rest with it; `ChartLink.all()` carries the crosshair's price and the price axis too, for one market shown twice.
- **Compare a second instrument** — overlay any number of other series, rebased so relative performance reads off the same axis, matched to your candles by time.
- **Bar replay** — rewind to any candle and step or play the market forward, with the indicators only knowing what has arrived.
- **Buy/sell signal markers** pinned to candles.
- **Event marks** — earnings, dividends, splits and news badged under the candle they happened on, and tappable.
- **Orders and positions** — live lines from your venue, tagged with side, size and P&L, and draggable to amend.
- **Extended-hours shading** — the pre-market and after-hours stretches washed behind the candles — and a per-bar colour of your own.
- **Depth chart** — a separate `DepthChart` widget for the order book, drawn as the cumulative curve, a per-rung histogram, both at once, or a numeric ladder of price, size and running total, on a linear, log or percentage axis and zoomable to the levels around the mid, with an optional bid/ask ratio bar underneath showing which way the resting orders lean.
- **Info dialog** on long press, either the built-in Material popup or your own builder.
- **"Now price" line** with a live countdown to the close of the current candle.
- **Session dividers and a display time zone**, so an intraday chart breaks where the trader's day does.
- **A watermark of your own** — any widget, such as an `Image.asset` of your logo, painted faintly in one colour over the candle area.
- **Fully themeable** — `ChartStyle` for geometry, `ChartColors` for every colour, `DrawingStyle` for the drawing tools; `ChartTranslations` for every label. Filled or hollow candles, dashed or solid crosshair, pane separators, axis-label pills and a placed, tinted watermark.
- **Fits its box** — the candles take whatever height the volume and indicator panes leave, so the chart works from a phone to a desktop window without arithmetic on your side.

![The overview strip under a chart, with the visible window lit on it](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/overview.png)

![Two linked charts sharing one crosshair](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/linked-charts.png)

![Bar replay stepping the market forward a candle at a time](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/bar-replay.gif)

## Install

```yaml
dependencies:
  ohlcv_chart: ^2.4.1
```

## Quick start

Feed a `KChartWidget` a `List<KLineEntity>`, having run `DataUtil.calculate`
over it so the indicator fields are populated:

```dart
import 'package:ohlcv_chart/ohlcv_chart.dart';

DataUtil.calculate(candles);

KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: false,
  timeFrame: const Duration(minutes: 15),
  indicators: [MaIndicator(period: 20), MacdIndicator()],
  fixedLength: 2,
);
```

That is a working chart. The [candlestick chart](doc/candlestick-chart.md) page
covers the rest of the constructor, and the [example app](example/) is a tour of
every switch in the package.

## Documentation

One page per feature, in [`doc/`](doc/README.md):

| | |
| --- | --- |
| [Candlestick chart](doc/candlestick-chart.md) | The candles, and the shape `KLineEntity` expects |
| [Indicators](doc/indicators.md) | 31 of them as instances, the catalogue, pane scales, chaining, higher timeframes, alerts |
| [Comparing a second instrument](doc/comparison.md) | Other series over the same window, rebased or at their own prices |
| [Chart types](doc/chart-types.md) | Eight ways to draw a series, and six transforms of the candles |
| [Price axis](doc/price-axis.md) | Linear, log, percentage or indexed to 100; inverting, dragging, locking it, and its gutter |
| [The date axis](doc/date-axis.md) | Round time values, and taking the axis over yourself |
| [The legend and the crosshair](doc/legend-and-crosshair.md) | The OHLC row, and the crosshair on hover |
| [The long-press readout](doc/readout.md) | The card over a held candle, and your own builder |
| [Drawing tools](doc/drawing-tools.md) | All 29 tools, persistence, undo, multi-select, templates, alerts |
| [Customising the line editor](doc/line-editor.md) | Every control of the editor, through `DrawingStyle` |
| [Orders and positions](doc/orders-and-positions.md) | Live lines from your venue, tagged and draggable |
| [Event marks](doc/event-marks.md) | Earnings, dividends, splits and news under the candles |
| [Sessions and time zones](doc/sessions.md) | Day dividers, display time zone, extended hours, per-bar colour |
| [Driving the chart](doc/driving-the-chart.md) | `KChartController`, the visible window, and a chart with no gestures |
| [Panes](doc/panes.md) | Stacking, resizing and reordering the indicator panes |
| [Bar replay](doc/bar-replay.md) | Rewind, then step or play the market forward |
| [Sizing](doc/sizing.md) | How the candle area and the panes divide the height |
| [Depth chart](doc/depth-chart.md) | The order-book widget: four modes, three axes |
| [Theming](doc/theming.md) | `ChartStyle`, `ChartColors` and `ChartTranslations` |
| [Migrating from 1.x](doc/migrating-from-1.x.md) | What changed, and what to use instead |

## Notes

- The zoom slider renders only where there is no pinch gesture — web and desktop.
- `watermark` takes any widget and paints it in `ChartColors.watermarkColor`, so a
  full-colour logo reads as a silhouette; the package no longer depends on
  `flutter_svg` — pass `SvgPicture.asset(...)` from it yourself for an SVG.

## Credits

The rendering core began as a derivative of the open-source `k_chart` package and
has since been substantially extended with drawing tools, signals, multi-indicator
stacking and a reworked painter pipeline.

## License

MIT — see [LICENSE](LICENSE).
