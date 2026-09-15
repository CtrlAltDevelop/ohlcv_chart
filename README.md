# ohlcv_chart

A candlestick chart for Flutter with 31 indicators and 29 drawing tools, plus
depth, series, pie, radar and heatmap charts. Everything is rendered with
`CustomPainter` — no WebView and no JavaScript bridge.

![Candles with moving averages, volume and MACD](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/candles.png)

## Overview

`ohlcv_chart` covers both the trading screen and the balance, growth and
reporting charts that surround it, in a single dependency. The name refers to
the open, high, low, close and volume data the candlestick chart renders.

The entire package is free, including for commercial use. Every chart type,
indicator and drawing tool is included; there is no paid tier.

> [!NOTE]
> The package is updated frequently, and the feature list below is a summary.
> See [`CHANGELOG.md`](CHANGELOG.md) for what changed in each release, and
> [`doc/`](doc/README.md) for a reference page per feature.

## Features

### Candlestick chart

- **Eight chart types** — candles, OHLC bars, line, step line, area, HLC area,
  baseline and columns — plus Heikin-Ashi, Renko, three-line break, Kagi,
  point & figure and range bars as transforms of the source candles.
- **Four price scales** — linear, logarithmic, percentage or indexed to 100.
  The axis can be inverted and can mark the visible high, low and average close.
- **Interactive price scale** — drag the axis labels to stretch or compress the
  candles, drag the chart to pan, and double-tap to refit. All of it is also
  available through the controller.
- **Fixed price range** — `lockPriceScale` holds the axis at a set range instead
  of refitting it while scrolling, and `priceAxisWidth` reserves a gutter so the
  candles never run underneath the labels.
- **Round axis values** — both axes pick readable values first (`69000`,
  `69500`, `70000`; intraday dates on the hour) and place gridlines to match.
- **Responsive sizing** — the candle area takes the height left over by the
  volume and indicator panes, from a phone to a desktop window.

### Indicators

- **31 indicators**, each a configured instance rather than a flag, so
  `ATR(8)`, `ATR(14)` and `ATR(20)` can run side by side with their own
  settings and colours.
- **Overlays** — `MA`, `EMA`, `BOLL`, `SAR`, Supertrend, Keltner and Donchian
  channels, the Ichimoku Cloud, pivot points, a volume profile, and `VWAP`
  (whole-series, anchored to a candle, or per session with standard-deviation
  bands).
- **Swing analysis** — ZigZag, Fibonacci retracement of the latest swing and
  Elliott wave labels, sized to the market by default.
- **Sub-chart panes** — `MACD`, `KDJ`, `RSI`, `WR`, `CCI`, `ATR`, `OBV`, `MFI`,
  `DMI`, Aroon, Stochastic RSI, `ROC`, `TRIX`, volume average and the Awesome
  Oscillator, each in a stacked pane that can be resized and reordered.
- **Higher timeframes** — for example, a daily moving average on a
  15-minute chart via `TimeframeIndicator`. Values come only from bars closed
  before each candle opened, so the line never repaints.
- **Composition and alerts** — compute any indicator over another's output, use
  logarithmic or percentage pane scales, and raise alerts on conditions such as
  RSI above 70.
- **Indicator templates** — save a named set of indicators and apply it to any
  chart; four starter sets are included.

### Drawing tools

- **29 tools** — horizontal levels and rays, trend lines, arrows, extended
  lines, rectangles, ellipses, triangles, parallel channels, pitchforks, Gann
  fans and boxes, four Fibonacci tools, regression trend, XABCD patterns,
  multi-leg paths, price and date ranges, a measuring tool, long/short positions
  with risk-to-reward, notes, callouts, flags and freehand. Each can be placed,
  moved, locked, hidden and removed.
- **Line editor** — opens on selection with colour, opacity, width, line style,
  fill, label, alerts, lock and delete. Every control is customisable through
  `DrawingStyle`.
- **Undo and redo** through `ChartDrawingController`, with ⌘Z, ⇧⌘Z and Delete
  shortcuts.
- **Multi-select** — shift- or ⌘-click, or ⌘A, then move, restyle or delete as a
  group; ⌘C, ⌘V and ⌘D copy, paste and duplicate, and ⌘] / ⌘[ change stacking
  order.
- **Precise placement** — a dialog for entering each anchor's price and candle
  directly.
- **Style templates** — save a drawing's appearance and apply it to others.
- **Persistence** — drawings serialise to JSON with `drawings.toJson()` and load
  back with `ChartDrawings.fromJson`.
- **Drawing manager** — a ready-made panel listing all drawings, with
  show/hide, lock, delete, undo, redo and clear.
- **Price alerts** on horizontal levels, trend lines, channel boundaries and
  Fibonacci levels, triggered when price crosses them.

### Interaction and navigation

- **Crosshair and OHLC legend** on hover, for desktop and web.
- **Long-press readout** — the built-in Material card or your own builder.
- **Context menu** on the chart and on drawings, extensible with your own items.
- **`KChartController`** — zoom, jump back to the latest candle and export the
  chart as a PNG.
- **Visible range** — read and set the visible candles, go to a date, fit to
  screen, and listen for changes.
- **Overview strip** — `ChartOverview` shows the full history with the visible
  range highlighted; drag to scroll, drag its edges to zoom, tap to jump.
- **Linked charts** — `ChartLink` synchronises the visible range and crosshair
  across any number of charts; `ChartLink.all()` also syncs the price axis.
- **Static mode** — `scrollEnabled` and `zoomEnabled` disable built-in gestures
  for thumbnails and fixed figures, while programmatic control still works.
- **Bar replay** — rewind to any candle and step or play forward, with
  indicators limited to the data revealed so far.

### Trading features

- **Orders and positions** — live lines showing side, size and P&L, draggable
  to modify.
- **Signal markers** — buy and sell markers pinned to candles.
- **Event marks** — tappable badges for earnings, dividends, splits and news.
- **Symbol comparison** — overlay any number of instruments, rebased for
  relative performance and aligned by timestamp.
- **Sessions and time zones** — session dividers, a display time zone,
  extended-hours shading and per-bar colours.
- **Live price line** with a countdown to the current candle's close.

### Other chart widgets

- **`SeriesChart`** — lines with four curve styles, areas with baseline fills
  that change colour where they cross it, grouped, stacked and floating bars,
  scatter plots, error bars, bands, custom or hidden axes, horizontal
  orientation, custom tooltips, shared crosshairs, a range selector for long
  data, and animated updates.
- **`PieChart`** — pie, doughnut (with a widget in the centre) or ring gauge,
  with exploded slices and badges.
- **`RadarChart`** — multi-series radar charts, one outline per series.
- **`HeatmapChart`** — a grid coloured by value from a matrix or sparse cells,
  with continuous or stepped colour scales, cell and axis labels, a legend and
  a hover readout. Suited to contribution graphs, correlation matrices and
  time-of-day breakdowns.
- **`TreemapChart`** — squarified tiles sized by value, with nested groups,
  colour scales for market maps, labels, touch and tooltips.
- **`GaugeChart`** — a dial or semicircle for a single value, with coloured
  ranges, a needle, ticks, centre text and animated transitions.
- **`WaterfallChart`** — a bridge from an opening total to a closing one, step
  by step, with subtotals, connectors and values over the bars.
- **`FunnelChart`** — tapered or stepped stages with conversion percentages,
  fitted or side labels, touch and tooltips.
- **`SankeyChart`** — flows between nodes as ribbons sized by value, with
  automatic columns, node and link touch, and highlight on hover.
- **`SunburstChart`** — a hierarchy as rings round a centre, from the same tree
  a treemap takes, with curved labels, a centre widget and touch.
- **`BoxPlotChart`** — quartiles, whiskers, mean and outliers side by side, with
  the statistics worked out from raw samples for you.
- **`HistogramChart`** — the shape of a distribution, with binning by count or
  width, a colour for negative bins and reference lines.
- **`BubbleChart`** — risk against return with a third number as bubble area,
  with axis titles, reference lines and labelled bubbles.
- **`CalendarChart`** — daily profit and loss as real months, each day coloured
  by its value, with monthly totals in the headers.
- **`EquityCurveChart`** — an account's value with an underwater drawdown panel,
  the deepest fall marked, and drawdown statistics you can read yourself.
- **`OptionPayoffChart`** — an options strategy's profit at expiry, with exact
  break-evens, strike lines, the spot marked, and profit and loss shaded apart.
- **`VolatilityCurveChart`** — implied volatility smiles, skews and term
  structures, several expiries at once with a crosshair that reads them all.
- **`MarketProfileChart`** — time at price as TPO letters, with the point of
  control and the value area worked out from your candles.
- **`FootprintChart`** — bid against ask volume at every price inside every bar,
  shaded by size, with imbalances outlined and cumulative delta.
- **`BookHeatmapChart`** — resting order-book liquidity over time, walls showing
  as bright lines, with a mid-price track and a crosshair readout.
- **`CumulativeDeltaChart`** — buying less selling as a running total with each
  bar's own delta beneath, and divergences against price marked.
- **`TradeTimelineChart`** — every trade as a bar from entry to exit, a lane per
  symbol, coloured by result, with an open-trade count beneath.
- **`RMultipleChart`** — trade results in R, with expectancy, win rate, profit
  factor and SQN worked out for you.
- **`MonteCarloChart`** — a fan of simulated equity paths as percentile bands,
  with the odds of loss and ruin and the real curve laid over.
- **`SeasonalityChart`** — returns by month and year or weekday and hour, with
  yearly totals and the typical month worked out for you.
- **`DepthChart`** — order-book depth as a cumulative curve, per-level
  histogram, both combined, or a numeric ladder; on a linear, logarithmic or
  percentage axis, zoomable around the mid price, with an optional bid/ask
  ratio bar.

### Customisation

- **Theming** — `ChartStyle` for layout, `ChartColors` for colours,
  `DrawingStyle` for drawing tools and `ChartTranslations` for every label.
  Includes filled or hollow candles, crosshair style, pane separators and
  axis-label pills.
- **Watermark** — any widget, such as an `Image.asset` logo, painted as a faint
  single-colour overlay on the candle area.

## Requirements

- Dart 3.6 or later
- Flutter 3.27 or later

## Installation

```yaml
dependencies:
  ohlcv_chart: ^2.5.0
```

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

See [Candlestick chart](doc/candlestick-chart.md) for the full constructor
reference. The [example app](example/) demonstrates every option in the package.

## Gallery

Each image links to the documentation page for that feature.
### Series, pie, radar, heatmap and depth charts

<table>
<tr>
<td width="33%" valign="top"><a href="doc/series-chart.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/series-charts.png" width="100%" alt="Four business charts"></a><br /><sub><b><a href="doc/series-chart.md">Four business charts</a></b><br />Returns split at zero, profit bars, cash flows with a tooltip, and a sparkline.</sub></td>
<td width="33%" valign="top"><a href="doc/pie-chart.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/pie-radar.png" width="100%" alt="Pie and radar"></a><br /><sub><b><a href="doc/pie-chart.md">Pie and radar</a></b><br />A doughnut with its total in the centre, and a radar comparing two strategies.</sub></td>
<td width="33%" valign="top"><a href="doc/heatmap-chart.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/heatmap.png" width="100%" alt="Heatmap"></a><br /><sub><b><a href="doc/heatmap-chart.md">Heatmap</a></b><br />Six months of activity, and orders by hour and weekday.</sub></td>
</tr>
<tr>
<td width="33%" valign="top"><a href="doc/series-chart.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/series-scatter.png" width="100%" alt="Scatter"></a><br /><sub><b><a href="doc/series-chart.md">Scatter</a></b><br />One point per trade, with per-point shape and colour and a single-point readout.</sub></td>
<td width="33%" valign="top"><a href="doc/series-chart.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/series-horizontal.png" width="100%" alt="Stacked horizontal bars"></a><br /><sub><b><a href="doc/series-chart.md">Stacked horizontal bars</a></b><br />Stacked bars in horizontal orientation, with titled axes.</sub></td>
<td width="33%" valign="top"><a href="doc/series-chart.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/series-ranges.png" width="100%" alt="Floating bars and bands"></a><br /><sub><b><a href="doc/series-chart.md">Floating bars and bands</a></b><br />A waterfall chart, and a forecast band with error bars.</sub></td>
</tr>
<tr>
<td width="33%" valign="top"><a href="doc/series-chart.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/series-window.png" width="100%" alt="Range selector"></a><br /><sub><b><a href="doc/series-chart.md">Range selector</a></b><br />Three series over five months, with a range selector below.</sub></td>
<td width="33%" valign="top"><a href="doc/series-chart.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/series-panels.png" width="100%" alt="Synchronised crosshair"></a><br /><sub><b><a href="doc/series-chart.md">Synchronised crosshair</a></b><br />Balance and profit panels sharing one crosshair.</sub></td>
<td width="33%" valign="top"><a href="doc/depth-chart.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/depth.png" width="100%" alt="Depth chart"></a><br /><sub><b><a href="doc/depth-chart.md">Depth chart</a></b><br />Cumulative bid and ask depth.</sub></td>
</tr>
<tr>
<td width="33%" valign="top"><a href="doc/depth-chart.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/depth-modes.png" width="100%" alt="Depth chart modes"></a><br /><sub><b><a href="doc/depth-chart.md">Depth chart modes</a></b><br />Cumulative, histogram, combined and ladder modes.</sub></td>
<td width="33%" valign="top"><a href="doc/depth-chart.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/depth-ratio.png" width="100%" alt="The bid/ask ratio bar"></a><br /><sub><b><a href="doc/depth-chart.md">The bid/ask ratio bar</a></b><br />The balance of bid and ask volume, below the depth chart.</sub></td>
<td width="33%"></td>
</tr>
</table>

### Chart types

<table>
<tr>
<td width="33%" valign="top"><a href="doc/chart-types.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/chart-types.png" width="100%" alt="Eight chart types"></a><br /><sub><b><a href="doc/chart-types.md">Eight chart types</a></b><br />OHLC bars, baseline, area, step line, HLC area and columns.</sub></td>
<td width="33%" valign="top"><a href="doc/chart-types.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/bar-types.png" width="100%" alt="Four bar transforms"></a><br /><sub><b><a href="doc/chart-types.md">Four bar transforms</a></b><br />Line break, Kagi, point & figure and range bars.</sub></td>
<td width="33%" valign="top"><a href="doc/chart-types.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/aggregations.png" width="100%" alt="Heikin-Ashi and Renko"></a><br /><sub><b><a href="doc/chart-types.md">Heikin-Ashi and Renko</a></b><br />Candles re-aggregated before rendering.</sub></td>
</tr>
<tr>
<td width="33%" valign="top"><a href="doc/comparison.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/comparison.png" width="100%" alt="Symbol comparison"></a><br /><sub><b><a href="doc/comparison.md">Symbol comparison</a></b><br />Another instrument on the same axis, rebased or at actual prices.</sub></td>
<td width="33%" valign="top"><a href="doc/theming.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/theming.png" width="100%" alt="Dark and light"></a><br /><sub><b><a href="doc/theming.md">Dark and light</a></b><br />The same chart in both themes, with every colour configurable.</sub></td>
<td width="33%"></td>
</tr>
</table>

### 31 indicators

<table>
<tr>
<td width="33%" valign="top"><a href="doc/indicators.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/overlays.png" width="100%" alt="Main-chart overlays"></a><br /><sub><b><a href="doc/indicators.md">Main-chart overlays</a></b><br />Ichimoku Cloud and Supertrend, with Stochastic RSI and Awesome Oscillator panes.</sub></td>
<td width="33%" valign="top"><a href="doc/indicators.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/profile.png" width="100%" alt="Profile and anchored VWAP"></a><br /><sub><b><a href="doc/indicators.md">Profile and anchored VWAP</a></b><br />A volume profile and a VWAP anchored to a candle.</sub></td>
<td width="33%" valign="top"><a href="doc/indicators.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/swings.png" width="100%" alt="Swing analysis"></a><br /><sub><b><a href="doc/indicators.md">Swing analysis</a></b><br />ZigZag, Fibonacci retracement and Elliott wave labels.</sub></td>
</tr>
<tr>
<td width="33%" valign="top"><a href="doc/panes.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/panes.png" width="100%" alt="Stacked panes"></a><br /><sub><b><a href="doc/panes.md">Stacked panes</a></b><br />Three ATR periods, each in its own resizable pane.</sub></td>
<td width="33%" valign="top"><a href="doc/indicators.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/higher-timeframe.png" width="100%" alt="Higher timeframes"></a><br /><sub><b><a href="doc/indicators.md">Higher timeframes</a></b><br />A four-hour moving average and RSI on 15-minute candles.</sub></td>
<td width="33%" valign="top"><a href="doc/indicators.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/indicator-settings.png" width="100%" alt="Indicator catalogue"></a><br /><sub><b><a href="doc/indicators.md">Indicator catalogue</a></b><br />The example app's indicator picker, generated from the catalogue.</sub></td>
</tr>
</table>

### Drawing tools and trading

<table>
<tr>
<td width="33%" valign="top"><a href="doc/drawing-tools.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/drawing.png" width="100%" alt="29 drawing tools"></a><br /><sub><b><a href="doc/drawing-tools.md">29 drawing tools</a></b><br />Labelled trend and horizontal lines, with snapping and persistence.</sub></td>
<td width="33%" valign="top"><a href="doc/drawing-tools.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/shapes.png" width="100%" alt="Rays, boxes and Fibonacci"></a><br /><sub><b><a href="doc/drawing-tools.md">Rays, boxes and Fibonacci</a></b><br />A ray, an arrow, a horizontal ray, a range box and a Fibonacci retracement.</sub></td>
<td width="33%" valign="top"><a href="doc/line-editor.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/line-editor.png" width="100%" alt="The line editor"></a><br /><sub><b><a href="doc/line-editor.md">The line editor</a></b><br />Controls for the selected drawing, customisable through DrawingStyle.</sub></td>
</tr>
<tr>
<td width="33%" valign="top"><a href="doc/orders-and-positions.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/trading.png" width="100%" alt="Orders and positions"></a><br /><sub><b><a href="doc/orders-and-positions.md">Orders and positions</a></b><br />A working order and an open position, each labelled on the axis.</sub></td>
<td width="33%" valign="top"><a href="doc/orders-and-positions.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/planning.png" width="100%" alt="Planning a trade"></a><br /><sub><b><a href="doc/orders-and-positions.md">Planning a trade</a></b><br />A planned position with risk-to-reward, inside a channel.</sub></td>
<td width="33%" valign="top"><a href="doc/event-marks.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/events.png" width="100%" alt="Event marks"></a><br /><sub><b><a href="doc/event-marks.md">Event marks</a></b><br />Earnings, dividend, split and news markers below the candles.</sub></td>
</tr>
</table>

### Interaction and navigation

<table>
<tr>
<td width="33%" valign="top"><a href="doc/legend-and-crosshair.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/legend-and-crosshair.png" width="100%" alt="Legend and crosshair"></a><br /><sub><b><a href="doc/legend-and-crosshair.md">Legend and crosshair</a></b><br />The OHLC legend, updated from the crosshair position.</sub></td>
<td width="33%" valign="top"><a href="doc/readout.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/readout.png" width="100%" alt="The long-press readout"></a><br /><sub><b><a href="doc/readout.md">The long-press readout</a></b><br />The built-in candle details card, or a custom builder.</sub></td>
<td width="33%" valign="top"><a href="doc/driving-the-chart.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/overview.png" width="100%" alt="The overview strip"></a><br /><sub><b><a href="doc/driving-the-chart.md">The overview strip</a></b><br />The full series below the chart, with the visible range highlighted.</sub></td>
</tr>
<tr>
<td width="33%" valign="top"><a href="doc/driving-the-chart.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/linked-charts.png" width="100%" alt="Linked charts"></a><br /><sub><b><a href="doc/driving-the-chart.md">Linked charts</a></b><br />Two charts with a synchronised crosshair.</sub></td>
<td width="33%" valign="top"><a href="doc/bar-replay.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/bar-replay.gif" width="100%" alt="Bar replay"></a><br /><sub><b><a href="doc/bar-replay.md">Bar replay</a></b><br />Rewind, then step or play forward candle by candle.</sub></td>
<td width="33%" valign="top"><a href="doc/bar-replay.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/bar-replay.png" width="100%" alt="Replay controls"></a><br /><sub><b><a href="doc/bar-replay.md">Replay controls</a></b><br />Paused at candle 150 of 420, with the playback bar.</sub></td>
</tr>
</table>

### Axes, sessions and layout

<table>
<tr>
<td width="33%" valign="top"><a href="doc/price-axis.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/price-scales.png" width="100%" alt="Four price axes"></a><br /><sub><b><a href="doc/price-axis.md">Four price axes</a></b><br />Linear, logarithmic, percentage or indexed to 100, and invertible.</sub></td>
<td width="33%" valign="top"><a href="doc/price-axis.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/log-axis.png" width="100%" alt="Logarithmic axis"></a><br /><sub><b><a href="doc/price-axis.md">Logarithmic axis</a></b><br />Evenly spaced ratios for long-term price history.</sub></td>
<td width="33%" valign="top"><a href="doc/date-axis.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/date-axis.png" width="100%" alt="The date axis"></a><br /><sub><b><a href="doc/date-axis.md">The date axis</a></b><br />Automatic round time intervals, or a custom formatter.</sub></td>
</tr>
<tr>
<td width="33%" valign="top"><a href="doc/sessions.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/sessions.png" width="100%" alt="Sessions and time zones"></a><br /><sub><b><a href="doc/sessions.md">Sessions and time zones</a></b><br />Pre-market and after-hours periods shaded behind the candles.</sub></td>
<td width="33%" valign="top"><a href="doc/sessions.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/session-vwap.png" width="100%" alt="Session VWAP"></a><br /><sub><b><a href="doc/sessions.md">Session VWAP</a></b><br />VWAP reset each session, with standard-deviation bands.</sub></td>
<td width="33%" valign="top"><a href="doc/sizing.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/sizing.png" width="100%" alt="Responsive sizing"></a><br /><sub><b><a href="doc/sizing.md">Responsive sizing</a></b><br />The candle area filling its container, or set to a fixed height.</sub></td>
</tr>
<tr>
<td width="33%" valign="top"><a href="doc/theming.md"><img src="https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/watermark.png" width="100%" alt="Custom watermark"></a><br /><sub><b><a href="doc/theming.md">Custom watermark</a></b><br />Any widget, rendered faintly over the candle area.</sub></td>
<td width="33%"></td>
<td width="33%"></td>
</tr>
</table>

## Documentation

Each feature has a reference page in [`doc/`](doc/README.md):

| Page | Covers |
| --- | --- |
| [Candlestick chart](doc/candlestick-chart.md) | The main chart widget and the `KLineEntity` data model |
| [Series charts](doc/series-chart.md) | `SeriesChart`: lines, areas, bars, scatter, touch, range selector and animation |
| [Pie chart](doc/pie-chart.md) | `PieChart`: sections, doughnut charts, badges and touch |
| [Radar chart](doc/radar-chart.md) | `RadarChart`: multi-series comparison across features |
| [Heatmap](doc/heatmap-chart.md) | `HeatmapChart`: value-coloured grids, colour scales and legends |
| [Treemap](doc/treemap-chart.md) | `TreemapChart`: tiles sized by value, groups and market maps |
| [Gauge](doc/gauge-chart.md) | `GaugeChart`: dials with ranges, needle, ticks and centre content |
| [Waterfall](doc/waterfall-chart.md) | `WaterfallChart`: a total built up step by step |
| [Funnel](doc/funnel-chart.md) | `FunnelChart`: stage drop-off with conversion percentages |
| [Sankey](doc/sankey-chart.md) | `SankeyChart`: flows between nodes, sized by value |
| [Sunburst](doc/sunburst-chart.md) | `SunburstChart`: a hierarchy as rings round a centre |
| [Box plot](doc/box-plot-chart.md) | `BoxPlotChart`: quartiles, whiskers and outliers |
| [Histogram](doc/histogram-chart.md) | `HistogramChart`: distribution shape, with binning helpers |
| [Bubble](doc/bubble-chart.md) | `BubbleChart`: three numbers at once, size carried by area |
| [Calendar](doc/calendar-chart.md) | `CalendarChart`: daily values laid out as real months |
| [Equity curve](doc/equity-curve-chart.md) | `EquityCurveChart`: equity with an underwater drawdown panel |
| [Options payoff](doc/option-payoff-chart.md) | `OptionPayoffChart`: strategy profit at expiry, with break-evens |
| [Volatility curve](doc/volatility-curve-chart.md) | `VolatilityCurveChart`: smiles, skews and term structures |
| [Market profile](doc/market-profile-chart.md) | `MarketProfileChart`: time at price, TPO letters and value area |
| [Footprint](doc/footprint-chart.md) | `FootprintChart`: bid and ask volume at every price, order flow |
| [Order-book heatmap](doc/book-heatmap-chart.md) | `BookHeatmapChart`: resting liquidity over time |
| [Cumulative delta](doc/cumulative-delta-chart.md) | `CumulativeDeltaChart`: running delta with divergences |
| [Trade timeline](doc/trade-timeline-chart.md) | `TradeTimelineChart`: when each trade was open, and what it made |
| [R-multiple distribution](doc/r-multiple-chart.md) | `RMultipleChart`: results in R, with expectancy and SQN |
| [Monte Carlo fan](doc/monte-carlo-chart.md) | `MonteCarloChart`: simulated equity paths as percentile bands |
| [Seasonality](doc/seasonality-chart.md) | `SeasonalityChart`: results by month and year, or weekday and hour |
| [Parallel coordinates](doc/parallel-chart.md) | `ParallelChart`: many things on many measures, one axis each |
| [Chord](doc/chord-chart.md) | `ChordChart`: flow between nodes both ways round a ring |
| [Marimekko](doc/marimekko-chart.md) | `MarimekkoChart`: two dimensions at once, column width and cell height |
| [Stream graph](doc/stream-chart.md) | `StreamChart`: a stack that flows, on a wiggle baseline |
| [Violin and ridgeline](doc/violin-chart.md) | `ViolinChart`: the shape of a distribution, not just its quartiles |
| [Slope and bump](doc/slope-chart.md) | `SlopeChart`: how things moved between periods, by value or by rank |
| [Dumbbell](doc/dumbbell-chart.md) | `DumbbellChart`: two values a row, joined by a bar |
| [Waffle](doc/waffle-chart.md) | `WaffleChart`: parts of a whole as a grid of squares |
| [Bullet](doc/bullet-chart.md) | `BulletChart`: a measure against its target on a banded track |
| [Pair spread](doc/pair-spread-chart.md) | `PairSpreadChart`: the spread or ratio of two symbols, with z-score bands |
| [Indicators](doc/indicators.md) | All 31 indicators, the catalogue, pane scales, chaining, higher timeframes and alerts |
| [Symbol comparison](doc/comparison.md) | Overlaying other instruments, rebased or at actual prices |
| [Chart types](doc/chart-types.md) | Eight chart types and six candle transforms |
| [Price axis](doc/price-axis.md) | Scale types, inversion, dragging, locking and label gutter |
| [Date axis](doc/date-axis.md) | Automatic time intervals and custom formatting |
| [Legend and crosshair](doc/legend-and-crosshair.md) | The OHLC legend and hover crosshair |
| [Long-press readout](doc/readout.md) | The candle details card and custom builders |
| [Drawing tools](doc/drawing-tools.md) | All 29 tools, persistence, undo, multi-select, templates and alerts |
| [Customising the line editor](doc/line-editor.md) | Configuring the editor through `DrawingStyle` |
| [Orders and positions](doc/orders-and-positions.md) | Live order and position lines, labelled and draggable |
| [Event marks](doc/event-marks.md) | Earnings, dividend, split and news markers |
| [Sessions and time zones](doc/sessions.md) | Session dividers, display time zone, extended hours and per-bar colours |
| [Driving the chart](doc/driving-the-chart.md) | `KChartController`, the visible range and static charts |
| [Panes](doc/panes.md) | Stacking, resizing and reordering indicator panes |
| [Bar replay](doc/bar-replay.md) | Replaying historical data candle by candle |
| [Sizing](doc/sizing.md) | How the candle area and panes share the available height |
| [Depth chart](doc/depth-chart.md) | `DepthChart`: four display modes and three scales |
| [Theming](doc/theming.md) | `ChartStyle`, `ChartColors` and `ChartTranslations` |
| [Migrating from 1.x](doc/migrating-from-1.x.md) | Breaking changes and their replacements |
| [Migrating from fl_chart and candlesticks](doc/migrating-from-fl_chart.md) | API mapping from both packages, with examples |

## Platform notes

- The zoom slider is shown only on platforms without pinch gestures (web and
  desktop).
- `watermark` paints the widget in `ChartColors.watermarkColor`, so full-colour
  logos render as a silhouette. The package does not depend on `flutter_svg`;
  to use an SVG, pass `SvgPicture.asset(...)` from that package.

## Support the project

If `ohlcv_chart` is useful to you, please consider:

- starring the [repository](https://github.com/CtrlAltDevelop/ohlcv_chart)
- liking the [package on pub.dev](https://pub.dev/packages/ohlcv_chart)
- following [CtrlAltDevelop on GitHub](https://github.com/CtrlAltDevelop)

It helps other developers find the package and supports its continued
development. Bug reports and pull requests are welcome — see
[`CONTRIBUTING.md`](CONTRIBUTING.md).

## Credits

The rendering core is derived from the open-source `k_chart` package and has
since been substantially extended with drawing tools, signals, multi-indicator
stacking and a reworked rendering pipeline.

## License

Released under the MIT License. See [LICENSE](LICENSE).
