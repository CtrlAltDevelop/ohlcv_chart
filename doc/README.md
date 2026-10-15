# ohlcv_chart documentation

Reference documentation for every feature, one page each. Start with
[Candlestick chart](candlestick-chart.md); the remaining pages can be read in
any order.

For installation and a quick start, see the [package README](../README.md);
for what the package does at a glance, see [Features](features.md) and the
[Gallery](gallery.md).

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
- **[Volatility surface](volatility-surface-chart.md)** —
  `VolatilitySurfaceChart`: implied volatility across strike and expiry as a
  heatmap, with the skew against the at-the-money strike.
- **[Futures curve](futures-curve-chart.md)** — `FuturesCurveChart`: prices
  against delivery month, with contango, backwardation and calendar spreads.
- **[Market profile](market-profile-chart.md)** — `MarketProfileChart`: time at
  price as TPO letters, with the point of control and value area.
- **[Footprint](footprint-chart.md)** — `FootprintChart`: bid and ask volume at
  every price inside every bar, with imbalances marked.
- **[Order-book heatmap](book-heatmap-chart.md)** — `BookHeatmapChart`: resting
  liquidity over time, walls as bright lines.
- **[Open interest and funding](open-interest-chart.md)** —
  `OpenInterestChart`: open interest over price, funding beneath.
- **[Liquidity map](liquidity-map-chart.md)** — `LiquidityMapChart`: where the
  leveraged stops sit, and what a move would set off.
- **[Cumulative delta](cumulative-delta-chart.md)** — `CumulativeDeltaChart`:
  buying less selling, with divergences against price marked.
- **[Trade timeline](trade-timeline-chart.md)** — `TradeTimelineChart`: each
  trade from entry to exit, a lane per symbol, coloured by result.
- **[R-multiple distribution](r-multiple-chart.md)** — `RMultipleChart`: trade
  results in R, with expectancy, profit factor and SQN.
- **[MAE / MFE scatter](mae-mfe-chart.md)** — `MaeMfeChart`: every trade by how
  far it went against you or for you, to place a stop and a target.
- **[Value at risk](var-chart.md)** — `VarChart`: a histogram of returns with the
  loss tail picked out, and VaR and expected shortfall marked.
- **[Monte Carlo fan](monte-carlo-chart.md)** — `MonteCarloChart`: simulated
  equity paths as percentile bands, with the odds of loss and ruin.
- **[Seasonality](seasonality-chart.md)** — `SeasonalityChart`: results by month
  and year, or weekday and hour, with totals and averages.
- **[Activity clock](activity-clock-chart.md)** — `ActivityClockChart`: a week
  as a clock face, an hour round the dial and a weekday on each ring.
- **[Sparkline grid](sparkline-grid.md)** — `SparklineGrid`: small multiples
  for a watchlist, a name and a shape each.
- **[Parallel coordinates](parallel-chart.md)** — `ParallelChart`: many things
  compared on many measures, an axis each.
- **[Chord](chord-chart.md)** — `ChordChart`: flow between nodes both ways
  round a ring, cycles included.
- **[Marimekko](marimekko-chart.md)** — `MarimekkoChart`: two dimensions at
  once, columns as wide as they are big.
- **[Stream graph](stream-chart.md)** — `StreamChart`: how a whole was made up
  over time, on a wiggle baseline.
- **[Violin and ridgeline](violin-chart.md)** — `ViolinChart`: the shape of a
  distribution, side by side or stacked as a ridgeline.
- **[Slope and bump](slope-chart.md)** — `SlopeChart`: how things moved between
  periods, by value or by changing rank.
- **[Dumbbell](dumbbell-chart.md)** — `DumbbellChart`: two values a row joined
  by a bar, for before and after or low and high.
- **[Waffle](waffle-chart.md)** — `WaffleChart`: parts of a whole as a grid of
  squares, a cell per per cent.
- **[Bullet](bullet-chart.md)** — `BulletChart`: a measure against its target
  on a banded track, a row per KPI.
- **[Pair spread](pair-spread-chart.md)** — `PairSpreadChart`: the spread or
  ratio of two symbols, with z-score bands and entry and exit signals.
- **[Efficient frontier](efficient-frontier-chart.md)** —
  `EfficientFrontierChart`: portfolios by risk and return, with the frontier,
  the best Sharpe ratio and the capital market line.
- **[Migrating from fl_chart and candlesticks](migrating-from-fl_chart.md)** —
  API mapping from both packages, with examples.
- **[Training curves](training-curve-chart.md)** — `TrainingCurveChart`: loss and accuracy of one or more runs, with smoothing, a log axis, the best checkpoint and divergence marked.
- **[Scaling laws](scaling-law-chart.md)** — `ScalingLawChart`: loss against compute on log-log axes, with the power law fitted and carried past the data.
- **[Hyperparameter sweep](sweep-chart.md)** — `SweepChart`: a two-setting sweep as a grid of scores, with the best combination starred.
- **[Training timeline](training-timeline-chart.md)** — `TrainingTimelineChart`: training jobs by machine, coloured by how they finished.
- **[Benchmark matrix](benchmark-matrix-chart.md)** — `BenchmarkMatrixChart`: models against benchmarks, coloured by standing, with the leaders starred.
- **[Model cost against quality](model-pareto-chart.md)** — `ModelParetoChart`: models by cost and score with the Pareto frontier traced through the ones nothing beats.
- **[Latency bands](latency-band-chart.md)** — `LatencyBandChart`: p50, p95 and p99 latency over time as bands, with an objective and the intervals that broke it.
- **[Token usage](token-usage-chart.md)** — `TokenUsageChart`: input, output and cached tokens over time as stacked columns, with the cost as a line.
- **[Evaluation breakdown](eval-breakdown-chart.md)** — `EvalBreakdownChart`: an evaluation by category: passed, failed and skipped, worst first, with an interval on each rate.

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
