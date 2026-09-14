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

A candlestick (K-line) chart, a market-depth chart, and line, bar, scatter,
pie, radar and heatmap charts for Flutter, drawn entirely with `CustomPainter`
— no WebView, no JavaScript bridge. One package for the trading screen and for the balance,
growth and report charts around it.

Named for the open-high-low-close-volume bars it renders.

![Candles with moving averages, volume and MACD](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/candles.png)

## Features

- **Series charts for everything else** — `SeriesChart` draws plain values rather than candles: lines with four curves, areas that fade to a baseline and split colour where they cross it, bars that group, stack or float, scatter plots, error bars, a band between two lines, axes you write, name or hide, a chart you can turn on its side, a tooltip of your own, one crosshair shared across charts, a range strip for long data and animated data changes. The [migration guide](doc/migrating-from-fl_chart.md) maps `fl_chart` and `candlesticks` onto it.
- **A pie chart and a radar chart** — `PieChart` for a pie, a doughnut with a widget in its hole or a ring gauge, with exploded slices and badges; `RadarChart` for a web of features with one outline per series. The two shapes an axis cannot draw, in the same package as the rest.
- **A heatmap** — `HeatmapChart` colours a grid of squares by their value, from a matrix or from sparse cells: a fading or a stepped colour scale, labels in the squares and down both sides, a legend, and a readout for the square under the pointer. A contribution graph, a correlation matrix or sales by weekday and hour.
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

## The whole package in pictures

Every widget, every chart type and every tool below is in this one package, and
each picture links to the page that covers it.

### Series, pie, radar and heatmap charts

<table>
<tr>
<td width="33%" valign="top"><a href="doc/series-chart.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/series-charts.png" width="100%" alt="Four business charts"></a><br /><sub><b><a href="doc/series-chart.md">Four business charts</a></b><br />A return split at zero, profit bars, flows with a tooltip and a sparkline.</sub></td>
<td width="33%" valign="top"><a href="doc/pie-chart.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/pie-radar.png" width="100%" alt="Pie and radar"></a><br /><sub><b><a href="doc/pie-chart.md">Pie and radar</a></b><br />A doughnut with its total in the hole, and a web scoring two strategies.</sub></td>
<td width="33%" valign="top"><a href="doc/heatmap-chart.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/heatmap.png" width="100%" alt="Heatmap"></a><br /><sub><b><a href="doc/heatmap-chart.md">Heatmap</a></b><br />Six months of activity, and orders by hour and weekday, by value.</sub></td>
</tr>
<tr>
<td width="33%" valign="top"><a href="doc/series-chart.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/series-scatter.png" width="100%" alt="Scatter"></a><br /><sub><b><a href="doc/series-chart.md">Scatter</a></b><br />A dot per trade, shaped and coloured by the point, read out one at a time.</sub></td>
<td width="33%" valign="top"><a href="doc/series-chart.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/series-horizontal.png" width="100%" alt="Stacked and turned"></a><br /><sub><b><a href="doc/series-chart.md">Stacked and turned</a></b><br />Bars piled on each other on a chart running rightwards, both axes named.</sub></td>
<td width="33%" valign="top"><a href="doc/series-chart.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/series-ranges.png" width="100%" alt="Floating bars and bands"></a><br /><sub><b><a href="doc/series-chart.md">Floating bars and bands</a></b><br />A waterfall, and a forecast inside its band with error bars.</sub></td>
</tr>
<tr>
<td width="33%" valign="top"><a href="doc/series-chart.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/series-window.png" width="100%" alt="A window over long data"></a><br /><sub><b><a href="doc/series-chart.md">A window over long data</a></b><br />Three series over five months, with the strip that moves the window.</sub></td>
<td width="33%" valign="top"><a href="doc/series-chart.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/series-panels.png" width="100%" alt="One crosshair, two panels"></a><br /><sub><b><a href="doc/series-chart.md">One crosshair, two panels</a></b><br />A balance panel over a profit panel, marking the same day in both.</sub></td>
<td width="33%" valign="top"><a href="doc/depth-chart.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/depth.png" width="100%" alt="Depth chart"></a><br /><sub><b><a href="doc/depth-chart.md">Depth chart</a></b><br />Cumulative bid and ask depth from the order book.</sub></td>
</tr>
<tr>
<td width="33%" valign="top"><a href="doc/depth-chart.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/depth-modes.png" width="100%" alt="Depth, four ways"></a><br /><sub><b><a href="doc/depth-chart.md">Depth, four ways</a></b><br />The curve, the per-rung bars, both at once, or a numeric ladder.</sub></td>
<td width="33%" valign="top"><a href="doc/depth-chart.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/depth-ratio.png" width="100%" alt="The bid/ask ratio bar"></a><br /><sub><b><a href="doc/depth-chart.md">The bid/ask ratio bar</a></b><br />Which way the resting orders lean, under the depth chart.</sub></td>
<td width="33%"></td>
</tr>
</table>

### Candles, and the ways to draw them

<table>
<tr>
<td width="33%" valign="top"><a href="doc/chart-types.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/chart-types.png" width="100%" alt="Eight chart types"></a><br /><sub><b><a href="doc/chart-types.md">Eight chart types</a></b><br />Bars, baseline, area, step line, HLC area and columns.</sub></td>
<td width="33%" valign="top"><a href="doc/chart-types.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/bar-types.png" width="100%" alt="Four bar transforms"></a><br /><sub><b><a href="doc/chart-types.md">Four bar transforms</a></b><br />Line break, Kagi, point & figure and range bars.</sub></td>
<td width="33%" valign="top"><a href="doc/chart-types.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/aggregations.png" width="100%" alt="Heikin-Ashi and Renko"></a><br /><sub><b><a href="doc/chart-types.md">Heikin-Ashi and Renko</a></b><br />The same market re-aggregated before it is drawn.</sub></td>
</tr>
<tr>
<td width="33%" valign="top"><a href="doc/comparison.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/comparison.png" width="100%" alt="A second instrument"></a><br /><sub><b><a href="doc/comparison.md">A second instrument</a></b><br />Another series over the same window, rebased or at its own prices.</sub></td>
<td width="33%" valign="top"><a href="doc/theming.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/theming.png" width="100%" alt="Dark and light"></a><br /><sub><b><a href="doc/theming.md">Dark and light</a></b><br />The same chart under both palettes, every colour yours.</sub></td>
<td width="33%"></td>
</tr>
</table>

### 31 indicators

<table>
<tr>
<td width="33%" valign="top"><a href="doc/indicators.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/overlays.png" width="100%" alt="Main-chart overlays"></a><br /><sub><b><a href="doc/indicators.md">Main-chart overlays</a></b><br />The Ichimoku cloud and Supertrend, over Stochastic RSI and Awesome.</sub></td>
<td width="33%" valign="top"><a href="doc/indicators.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/profile.png" width="100%" alt="Profile and anchored VWAP"></a><br /><sub><b><a href="doc/indicators.md">Profile and anchored VWAP</a></b><br />A volume profile and a VWAP anchored to a candle.</sub></td>
<td width="33%" valign="top"><a href="doc/indicators.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/swings.png" width="100%" alt="Swing readers"></a><br /><sub><b><a href="doc/indicators.md">Swing readers</a></b><br />A zigzag, a Fibonacci retracement and Elliott wave labels.</sub></td>
</tr>
<tr>
<td width="33%" valign="top"><a href="doc/panes.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/panes.png" width="100%" alt="Stacked panes"></a><br /><sub><b><a href="doc/panes.md">Stacked panes</a></b><br />Three ATRs at different periods, each in its own resizable pane.</sub></td>
<td width="33%" valign="top"><a href="doc/indicators.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/higher-timeframe.png" width="100%" alt="Higher timeframes"></a><br /><sub><b><a href="doc/indicators.md">Higher timeframes</a></b><br />A four-hour average and RSI over fifteen-minute candles.</sub></td>
<td width="33%" valign="top"><a href="doc/indicators.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/indicator-settings.png" width="100%" alt="Built from the catalogue"></a><br /><sub><b><a href="doc/indicators.md">Built from the catalogue</a></b><br />The example app's add-indicator sheet, generated from it.</sub></td>
</tr>
</table>

### Drawing tools, orders and events

<table>
<tr>
<td width="33%" valign="top"><a href="doc/drawing-tools.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/drawing.png" width="100%" alt="29 drawing tools"></a><br /><sub><b><a href="doc/drawing-tools.md">29 drawing tools</a></b><br />Trend and horizontal lines with labels, snapped and persisted.</sub></td>
<td width="33%" valign="top"><a href="doc/drawing-tools.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/shapes.png" width="100%" alt="Rays, boxes and fibs"></a><br /><sub><b><a href="doc/drawing-tools.md">Rays, boxes and fibs</a></b><br />A ray, an arrow, a horizontal ray, a range box and a retracement.</sub></td>
<td width="33%" valign="top"><a href="doc/line-editor.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/line-editor.png" width="100%" alt="The line editor"></a><br /><sub><b><a href="doc/line-editor.md">The line editor</a></b><br />Every control of a selected drawing, styled by DrawingStyle.</sub></td>
</tr>
<tr>
<td width="33%" valign="top"><a href="doc/orders-and-positions.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/trading.png" width="100%" alt="Orders and positions"></a><br /><sub><b><a href="doc/orders-and-positions.md">Orders and positions</a></b><br />A working order and an open position, each tagged on the axis.</sub></td>
<td width="33%" valign="top"><a href="doc/orders-and-positions.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/planning.png" width="100%" alt="Planning a trade"></a><br /><sub><b><a href="doc/orders-and-positions.md">Planning a trade</a></b><br />A planned position with its risk-to-reward, inside a channel.</sub></td>
<td width="33%" valign="top"><a href="doc/event-marks.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/events.png" width="100%" alt="Event marks"></a><br /><sub><b><a href="doc/event-marks.md">Event marks</a></b><br />Earnings, a dividend, a split and news under the candles.</sub></td>
</tr>
</table>

### Reading it, and driving it

<table>
<tr>
<td width="33%" valign="top"><a href="doc/legend-and-crosshair.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/legend-and-crosshair.png" width="100%" alt="Legend and crosshair"></a><br /><sub><b><a href="doc/legend-and-crosshair.md">Legend and crosshair</a></b><br />The OHLC row above the chart, reading from the crosshair.</sub></td>
<td width="33%" valign="top"><a href="doc/readout.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/readout.png" width="100%" alt="The long-press readout"></a><br /><sub><b><a href="doc/readout.md">The long-press readout</a></b><br />The card over a held candle, or a builder of your own.</sub></td>
<td width="33%" valign="top"><a href="doc/driving-the-chart.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/overview.png" width="100%" alt="The overview strip"></a><br /><sub><b><a href="doc/driving-the-chart.md">The overview strip</a></b><br />The whole series under the chart, with the visible window lit.</sub></td>
</tr>
<tr>
<td width="33%" valign="top"><a href="doc/driving-the-chart.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/linked-charts.png" width="100%" alt="Linked charts"></a><br /><sub><b><a href="doc/driving-the-chart.md">Linked charts</a></b><br />Two charts sharing one crosshair.</sub></td>
<td width="33%" valign="top"><a href="doc/bar-replay.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/bar-replay.gif" width="100%" alt="Bar replay"></a><br /><sub><b><a href="doc/bar-replay.md">Bar replay</a></b><br />Rewind, then step or play the market forward.</sub></td>
<td width="33%" valign="top"><a href="doc/bar-replay.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/bar-replay.png" width="100%" alt="Held mid-replay"></a><br /><sub><b><a href="doc/bar-replay.md">Held mid-replay</a></b><br />The chart stopped at the 150th candle of 420, under a transport bar.</sub></td>
</tr>
</table>

### The axes, the session and the box

<table>
<tr>
<td width="33%" valign="top"><a href="doc/price-axis.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/price-scales.png" width="100%" alt="Four price axes"></a><br /><sub><b><a href="doc/price-axis.md">Four price axes</a></b><br />Linear, log, percentage or indexed to 100 — and invertible.</sub></td>
<td width="33%" valign="top"><a href="doc/price-axis.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/log-axis.png" width="100%" alt="A log axis"></a><br /><sub><b><a href="doc/price-axis.md">A log axis</a></b><br />Stepping by ratio, so a decade of compounding reads evenly.</sub></td>
<td width="33%" valign="top"><a href="doc/date-axis.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/date-axis.png" width="100%" alt="The date axis"></a><br /><sub><b><a href="doc/date-axis.md">The date axis</a></b><br />The round time values the chart picks, or your own formatter.</sub></td>
</tr>
<tr>
<td width="33%" valign="top"><a href="doc/sessions.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/sessions.png" width="100%" alt="Sessions and time zones"></a><br /><sub><b><a href="doc/sessions.md">Sessions and time zones</a></b><br />Pre-market and after-hours washed behind the candles.</sub></td>
<td width="33%" valign="top"><a href="doc/sessions.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/session-vwap.png" width="100%" alt="Session VWAP"></a><br /><sub><b><a href="doc/sessions.md">Session VWAP</a></b><br />A VWAP restarted each session, with its standard-deviation band.</sub></td>
<td width="33%" valign="top"><a href="doc/sizing.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/sizing.png" width="100%" alt="Fits its box"></a><br /><sub><b><a href="doc/sizing.md">Fits its box</a></b><br />The candle area filling the box, and pinned to a height.</sub></td>
</tr>
<tr>
<td width="33%" valign="top"><a href="doc/theming.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/watermark.png" width="100%" alt="A watermark of your own"></a><br /><sub><b><a href="doc/theming.md">A watermark of your own</a></b><br />Any widget, painted faintly over the candle area.</sub></td>
<td width="33%"></td>
<td width="33%"></td>
</tr>
</table>

## Install

```yaml
dependencies:
  ohlcv_chart: ^2.5.0
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
| [Series charts](doc/series-chart.md) | `SeriesChart` for values: lines, areas, bars, scatter, touch, a range strip, animation |
| [Pie chart](doc/pie-chart.md) | `PieChart`: sections, a doughnut hole, badges, touch |
| [Radar chart](doc/radar-chart.md) | `RadarChart`: a web of features with an outline per series |
| [Heatmap](doc/heatmap-chart.md) | `HeatmapChart`: a grid coloured by value, with a scale and a legend |
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
| [Migrating from fl_chart and candlesticks](doc/migrating-from-fl_chart.md) | Their APIs mapped onto this package's, with worked examples |

## Notes

- Needs Dart 3.6 and Flutter 3.27 or later.
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
