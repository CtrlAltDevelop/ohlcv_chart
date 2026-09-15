# ohlcv_chart documentation

Reference documentation for every feature, one page each. Start with
[Candlestick chart](candlestick-chart.md); the remaining pages can be read in
any order.

For installation and an overview of features, see the
[package README](../README.md).

## Getting started

- **[Candlestick chart](candlestick-chart.md)** — the `KChartWidget` and the
  `KLineEntity` data model.
- **[Series charts](series-chart.md)** — `SeriesChart` for numeric data: lines,
  areas, grouped, stacked and floating bars, scatter plots, horizontal
  orientation, custom tooltips, range selection and animation.
- **[Pie chart](pie-chart.md)** — `PieChart`: proportional sections, doughnut
  charts with centre content, exploded slices, badges and touch.
- **[Radar chart](radar-chart.md)** — `RadarChart`: multi-series comparison on a
  polygonal or circular grid.
- **[Heatmap](heatmap-chart.md)** — `HeatmapChart`: value-coloured grids with
  colour scales, legends and hover readouts.
- **[Treemap](treemap-chart.md)** — `TreemapChart`: squarified tiles sized by
  value, nested groups and colour scales for market maps.
- **[Gauge](gauge-chart.md)** — `GaugeChart`: a dial for a single value, with
  ranges, a needle, ticks and animated transitions.
- **[Waterfall](waterfall-chart.md)** — `WaterfallChart`: a bridge from one
  total to another, gains and losses step by step.
- **[Funnel](funnel-chart.md)** — `FunnelChart`: sequential stages with
  conversion percentages.
- **[Sankey](sankey-chart.md)** — `SankeyChart`: flows between nodes, ribbons
  as thick as the quantity moved.
- **[Sunburst](sunburst-chart.md)** — `SunburstChart`: a hierarchy as rings
  round a centre, one ring per level.
- **[Box plot](box-plot-chart.md)** — `BoxPlotChart`: quartiles, whiskers and
  outliers, comparing distributions side by side.
- **[Histogram](histogram-chart.md)** — `HistogramChart`: how often values fall
  in each part of their range, with binning done for you.
- **[Bubble](bubble-chart.md)** — `BubbleChart`: three numbers at once, size
  carried by area.
- **[Calendar](calendar-chart.md)** — `CalendarChart`: daily values as real
  months, each day coloured by its value.
- **[Equity curve](equity-curve-chart.md)** — `EquityCurveChart`: an account's
  value with an underwater drawdown panel beneath it.
- **[Options payoff](option-payoff-chart.md)** — `OptionPayoffChart`: what a
  strategy makes or loses at expiry, with break-evens marked.
- **[Volatility curve](volatility-curve-chart.md)** — `VolatilityCurveChart`:
  smiles, skews and term structures, several expiries at once.
- **[Market profile](market-profile-chart.md)** — `MarketProfileChart`: time at
  price as TPO letters, with the point of control and value area.
- **[Footprint](footprint-chart.md)** — `FootprintChart`: bid and ask volume at
  every price inside every bar, with imbalances marked.
- **[Order-book heatmap](book-heatmap-chart.md)** — `BookHeatmapChart`: resting
  liquidity over time, walls as bright lines.
- **[Cumulative delta](cumulative-delta-chart.md)** — `CumulativeDeltaChart`:
  buying less selling, with divergences against price marked.
- **[Trade timeline](trade-timeline-chart.md)** — `TradeTimelineChart`: each
  trade from entry to exit, a lane per symbol, coloured by result.
- **[Migrating from fl_chart and candlesticks](migrating-from-fl_chart.md)** —
  API mapping from both packages, with examples.

## Indicators and data

- **[Indicators](indicators.md)** — all 31 indicators, the indicator catalogue,
  pane scales, chained indicators, alerts, colours and custom indicators.
- **[Symbol comparison](comparison.md)** — overlaying other instruments, rebased
  or at actual prices, aligned by timestamp.
- **[Chart types](chart-types.md)** — eight chart types and six candle
  transforms: Heikin-Ashi, Renko, line break, Kagi, point & figure and range
  bars.

## Axes and readouts

- **[Price axis](price-axis.md)** — linear, logarithmic, percentage and
  indexed-to-100 scales; inversion, high/low and average markers, dragging,
  locking, custom formatting with `priceFormatter`, and label gutters.
- **[Date axis](date-axis.md)** — automatic time intervals and custom
  formatting with `dateFormatter`.
- **[Legend and crosshair](legend-and-crosshair.md)** — the OHLC legend and
  hover crosshair.
- **[Long-press readout](readout.md)** — the candle details card and custom
  builders.

## Drawing tools

- **[Drawing tools](drawing-tools.md)** — all 29 tools, placement, JSON
  persistence, undo and redo, multi-select, style templates, coordinate
  editing, context menu, drawing manager and alerts.
- **[Customising the line editor](line-editor.md)** — configuring the editor
  through `DrawingStyle`.

## Trading context

- **[Orders and positions](orders-and-positions.md)** — live order and position
  lines with side, size and P&L, draggable to modify.
- **[Event marks](event-marks.md)** — earnings, dividend, split and news
  markers.
- **[Sessions and time zones](sessions.md)** — session dividers, display time
  zone, extended-hours shading and custom bar colours.

## Programmatic control and layout

- **[Driving the chart](driving-the-chart.md)** — `KChartController` for zoom,
  scroll and PNG export, reading and setting the visible range, and disabling
  gestures.
- **[Panes](panes.md)** — stacking, resizing and reordering indicator panes.
- **[Bar replay](bar-replay.md)** — replaying historical data candle by candle.
- **[Sizing](sizing.md)** — how the candle area and panes share the available
  height.
- **[Performance](performance.md)** — rendering optimisations, common pitfalls
  and benchmarking.

## Other

- **[Depth chart](depth-chart.md)** — `DepthChart` for order-book depth: display
  modes, scales, zoom and the bid/ask ratio bar.
- **[Theming](theming.md)** — `ChartStyle`, `ChartColors` and
  `ChartTranslations`.
- **[Migrating from 1.x](migrating-from-1.x.md)** — breaking changes and their
  replacements.
