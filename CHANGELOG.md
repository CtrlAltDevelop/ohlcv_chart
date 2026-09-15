## Unreleased

### Added

- **`TreemapChart`** — tiles sized by value using the squarified layout, with
  nested groups and headers, colour by `HeatmapScale` or palette, fitted
  labels, touch, tooltips and grow-in animation. `layOutTreemap` and
  `treemapTileAt` are public. See [Treemap](doc/treemap-chart.md).
- **`GaugeChart`** — a dial for a single value, with any start and sweep angle,
  coloured ranges, a value bar, a needle, major and minor ticks, centre text or
  a custom centre widget, and animated transitions between values.
  `GaugeLayout` is public. See [Gauge](doc/gauge-chart.md).
- **`FunnelChart`** — tapered or stepped stages sized by value, with a minimum
  width, conversion from the first and previous stage, labels inside or beside
  each stage, shape-accurate touch, tooltips and animation. `layOutFunnel` and
  `funnelSegmentAt` are public. See [Funnel](doc/funnel-chart.md).
- **`SankeyChart`** — flows between nodes drawn as ribbons sized by value, with
  columns derived from the links, cycle-safe layout, blended or fixed ribbon
  colours, node and ribbon touch, hover highlighting with the rest faded back,
  tooltips and grow-in animation. `layOutSankey`, `sankeyNodeAt` and
  `sankeyLinkAt` are public. See [Sankey](doc/sankey-chart.md).
- **`SunburstChart`** — a hierarchy as rings round a centre, taking the same
  `TreemapItem` tree as the treemap, with any start and sweep angle, a depth
  limit, curved upright labels, a centre widget, touch that picks the deepest
  ring, tooltips and sweep-in animation. `layOutSunburst` and `sunburstArcAt`
  are public. See [Sunburst](doc/sunburst-chart.md).
- **`BoxPlotChart`** — quartiles, median, whiskers, mean and outliers for
  several sets of numbers side by side, with `BoxPlotStats.fromSamples` doing
  the statistics (interpolated quartiles, Tukey whiskers), a value axis, grid,
  column-wide touch, tooltips and grow-in animation. `BoxPlotStats`,
  `boxPlotRange`, `layOutBoxPlot` and `boxPlotBoxAt` are public. See
  [Box plot](doc/box-plot-chart.md).
- **`HistogramChart`** — the shape of a distribution, with `histogramBins`
  counting raw samples by bin count, bin width or the square-root rule, a
  separate colour for bins below zero, reference lines, both axes, a grid,
  column-wide touch, tooltips and grow-up animation. `HistogramBin`,
  `layOutHistogram` and `histogramBarAt` are public. See
  [Histogram](doc/histogram-chart.md).
- **`BubbleChart`** — two axes and a third number carried by bubble area, with
  automatic or fixed ranges, axis titles, a grid, reference lines on both axes,
  labels inside the bubbles that fit, smallest-first hit testing, tooltips and
  grow-in animation. `bubbleRange`, `layOutBubbles` and `bubbleAt` are public.
  See [Bubble](doc/bubble-chart.md).
- **`CalendarChart`** — daily values laid out as real month panels, coloured by
  any `HeatmapScale`, with a range made symmetric about zero by default, a
  configurable first weekday, monthly totals in the headers, optional day
  numbers and weekday initials, touch, tooltips and fade-in animation.
  `layOutCalendar`, `calendarCellAt` and `calendarValueRange` are public. See
  [Calendar](doc/calendar-chart.md).
- **`EquityCurveChart`** — an account's value over time with an underwater
  drawdown panel beneath it, the deepest fall marked and labelled, a crosshair
  that follows a drag, value, percentage and time axes, tooltips and draw-in
  animation. `equityDrawdowns`, `equityStats` (peak, trough, total return, max
  drawdown and its dates) and `layOutEquityCurve` are public. See
  [Equity curve](doc/equity-curve-chart.md).
- **`OptionPayoffChart`** — an options strategy's profit at expiry, with long
  and short call, put and underlying legs, quantity and contract size, profit
  and loss shaded apart, strike lines, a spot marker, a crosshair that follows
  a drag, tooltips and draw-in animation. `OptionLeg`, `optionPayoff`,
  `optionBreakEvens`, `optionPriceRange` and `layOutOptionPayoff` are public.
  See [Options payoff](doc/option-payoff-chart.md).
- **`VolatilityCurveChart`** — implied volatility against strike or maturity,
  with several curves at once, solid or dashed lines, smoothing that cannot
  overshoot, an at-the-money marker, a legend, percentage axis, a crosshair
  that reads every curve at once, tooltips and draw-in animation.
  `volatilityRange` and `layOutVolatility` are public. See
  [Volatility curve](doc/volatility-curve-chart.md).
- **`MarketProfileChart`** — time at price drawn as TPO letters or blocks, with
  `buildMarketProfile` reading your candles into levels by tick size or row
  count and working out the point of control and the 70% value area, a price
  axis, row touch, tooltips and grow-out animation. `MarketProfile`,
  `layOutMarketProfile` and `marketProfileBarAt` are public. See
  [Market profile](doc/market-profile-chart.md).
- **`FootprintChart`** — bid against ask volume at every price inside every bar,
  each cell shaded by size and outlined where the flow was one-sided, with each
  bar's point of control, a thin candle behind each column, numbers that drop
  out when there is no room, a price axis, cell touch and tooltips.
  `FootprintLevel`, `FootprintBar`, `footprintCumulativeDelta`,
  `footprintPriceRange`, `layOutFootprint` and `footprintCellAt` are public. See
  [Footprint](doc/footprint-chart.md).
- **`BookHeatmapChart`** — resting order-book liquidity over time, one column
  per snapshot and one row per price, with gamma-shaped brightness so a book
  with one huge wall stays readable, a mid-price track, a price axis, a
  crosshair that follows a drag, and a readout of the level under the pointer.
  `BookLevel`, `BookSnapshot`, `bookPriceRange`, `layOutBookHeatmap` and
  `bookHeatmapCellAt` are public. See
  [Order-book heatmap](doc/book-heatmap-chart.md).
- **`CumulativeDeltaChart`** — buying less selling as a running total, with each
  bar's own delta in a panel beneath, divergences against price marked both
  ways, a crosshair that follows a drag, tooltips and draw-in animation.
  `DeltaBar`, `cumulativeDelta`, `deltaBarsFromFootprint`, `deltaDivergences`
  and `layOutCumulativeDelta` are public. See
  [Cumulative delta](doc/cumulative-delta-chart.md).
- **`WaterfallChart`** — a bridge from one total to another, each step picking
  up where the last left off, with totals and subtotals on the baseline,
  connectors, values over the bars, touch, tooltips and grow-in animation.
  `WaterfallStep`, `waterfallTotals`, `waterfallRange`, `layOutWaterfall` and
  `waterfallBarAt` are public. See [Waterfall](doc/waterfall-chart.md).
- **`TradeTimelineChart`** — when an account was in the market: each trade a bar
  from entry to exit in a lane per symbol, overlapping trades packed into rows,
  coloured and shaded by result, long or short arrows, open trades running to
  now, an open-trade count strip, a crosshair, tooltips and animation.
  `TimelineTrade`, `tradeTimelineRange`, `packTradeRows`,
  `tradeTimelineExposure` and `layOutTradeTimeline` are public. See
  [Trade timeline](doc/trade-timeline-chart.md).
- **`RMultipleChart`** — trade results in R as a histogram split at zero, with
  win rate, average win and loss, expectancy, profit factor and SQN over it,
  and lines at zero and the expectancy. `RMultipleStats`, `rMultiplesFrom`,
  `rMultipleBins` and `defaultRMultipleStats` are public. See
  [R-multiple distribution](doc/r-multiple-chart.md).
- **`MonteCarloChart`** — simulated equity paths as percentile bands round the
  median, with faint sample paths, the real curve laid over, dashed start and
  ruin levels, a summary of final equity, loss and ruin odds and drawdown, a
  crosshair, tooltips and draw-in animation. `runMonteCarlo` bootstraps trades
  with compound or fixed sizing and a seed; `MonteCarloResult`,
  `MonteCarloResult.fromPaths` and `layOutMonteCarlo` are public. See
  [Monte Carlo fan](doc/monte-carlo-chart.md).
- **`SeasonalityChart`** — results across the calendar, month by year, weekday
  by hour or weekday by month, gathered by compounding, sum, mean, median, win
  rate or count, with a total per row and an average per column, coloured from
  loss through zero to profit on a heatmap. `SeasonalSample`,
  `seasonalReturnsFromPrices`, `seasonalityTable` and `seasonalAggregate` are
  public. See [Seasonality](doc/seasonality-chart.md).
- **`ChordChart`** — flow between nodes both ways round a ring, cycles drawn
  rather than broken: arcs as long as everything passing through their node,
  pads taken out of the turn before the arcs share it, ribbons bending through
  the centre and coloured by their larger end, labels outside the ring,
  fading, tooltips and a sweep-open animation. `ChordNode`, `ChordFlow`,
  `ChordTotals`, `ChordArc`, `ChordRibbon`, `ChordLayout` and `layOutChord`
  are public. See [Chord](doc/chord-chart.md).
- **`MarimekkoChart`** — two dimensions at once: columns as wide as they are
  big, each split by its own shares, cells with the same label sharing a
  colour across columns, gaps taken out before the shares are worked out,
  clipped headers with each column's share of the width, names inside the
  cells that fit them, tooltips and a draw-in animation. `MarimekkoColumn`,
  `MarimekkoCell`, `MarimekkoLayout`, `MarimekkoColumnLayout`,
  `MarimekkoCellLayout` and `layOutMarimekko` are public. See
  [Marimekko](doc/marimekko-chart.md).
- **`StreamChart`** — a stack that flows: bands stacked on a wiggle,
  silhouette or zero baseline, ordered inside-out so the busiest bands sit
  where the stack moves least, with eased edges, names written in each band's
  thickest period, a period crosshair, fading, tooltips and a draw-in
  animation. `stackStream` works out the baseline the Byron and Wattenberg
  way; `StreamSeries`, `StreamBaseline`, `StreamOrder`, `StreamStack`,
  `StreamLayout`, `StreamSeriesLayout` and `layOutStream` are public. See
  [Stream graph](doc/stream-chart.md).
- **`ViolinChart`** — the shape of a distribution rather than only its
  quartiles, as violins side by side or as an overlapping ridgeline, every
  shape measured against the tallest peak so their areas compare, with the
  box-plot quartiles inside them, a value axis, tooltips and a draw-in
  animation. `kernelDensity` estimates the shape with a Gaussian kernel and
  Silverman's bandwidth; `DensityCurve`, `ViolinSeries`, `ViolinShape`,
  `ViolinLayout`, `ViolinSeriesLayout` and `layOutViolin` are public. See
  [Violin and ridgeline](doc/violin-chart.md).
- **`SlopeChart`** — how things moved between periods, as a slope chart on a
  value scale or a bump chart on a rank one, with eased crossings, labels and
  values at both ends of every line, broken lines where a series has no value,
  column-first hit testing, fading, tooltips and a draw-in animation.
  `SlopeSeries`, `SlopeScale`, `SlopeLayout`, `SlopeSeriesLayout`,
  `rankValues` and `layOutSlope` are public. See
  [Slope and bump](doc/slope-chart.md).
- **`DumbbellChart`** — two values a row joined by a bar, every row on one
  shared scale, end dots coloured by direction, a value axis and gridlines
  under them, optional numbers outside the dots, touch reporting, tooltips and
  a draw-in animation. `DumbbellRow`, `DumbbellLayout`, `DumbbellRowLayout`
  and `layOutDumbbell` are public. See [Dumbbell](doc/dumbbell-chart.md).
- **`WaffleChart`** — parts of a whole as a grid of squares, a cell per per
  cent, shared out by largest remainder so no slice is more than one cell from
  its true share, filled from any corner, with an optional total that leaves
  the rest of the grid empty, dimming, tooltips and a fill-in animation.
  `WaffleSlice`, `WaffleFill`, `WaffleLayout`, `waffleCounts` and
  `layOutWaffle` are public. See [Waffle](doc/waffle-chart.md).
- **`BulletChart`** — a measure against its target on a banded qualitative
  track, a row per KPI, each row on its own scale, with a target tick, the
  value written at the end, rows that shrink to fit a short box, touch
  reporting, tooltips and a draw-in animation. `BulletRow`, `BulletBand`,
  `BulletLayout`, `BulletRowLayout` and `layOutBullet` are public. See
  [Bullet](doc/bullet-chart.md).
- **`PairSpreadChart`** — the relationship between two symbols for pair
  trading: their difference at a hedge ratio, their ratio or the log of it,
  with a rolling mean and standard-deviation bands over it and a z-score panel
  below, entry and exit signals marked on both, a shared crosshair, tooltips
  and animation. `PairPoint`, `alignPairSeries`, `pairHedgeRatio`,
  `pairSpread`, `pairZScores`, `pairSignals` and `layOutPairSpread` are
  public. See [Pair spread](doc/pair-spread-chart.md).

### Fixed

- **Backspace no longer deletes a selected drawing while typing.** The
  chart's keyboard shortcuts (Delete, Backspace, ⌘A, ⌘C, ⌘V, ⌘D, undo, redo
  and restacking) are now ignored while a text field has focus, including
  the line editor's own label field and any text field elsewhere in the app.
- **Indicators update when only the volume, high or low of the newest candle
  changes.** The indicator cache previously compared only the close, so a
  trade at an unchanged price left volume-based indicators (VolumeMA, OBV,
  MFI, VWAP, volume profile) and range-based ones (ATR, Donchian) stale.
- **`ChartOverview` redraws when the newest candle is updated in place.**
- **Scroll animations no longer leak.** Each fling and animated scroll created
  an `AnimationController` that was never disposed.

### Performance

- **The current-price countdown no longer redraws the chart.** The
  now-price line, high/low markers and signals are drawn on a separate layer,
  so the countdown's once-a-second update repaints only that layer instead of
  rebuilding the widget and redrawing every candle.
- **Dragging the crosshair by touch no longer redraws the chart.** A long-press
  drag now repaints only the crosshair layer, as mouse hover already did.
- `ChartOverview` without `colors` no longer repaints on every rebuild.

### Documentation

- **Rewritten README, documentation pages and changelog.** The prose is
  shorter and more direct, with features grouped by area, reference tables and
  consistent headings. No API names, examples or behaviour descriptions were
  removed.
- The pub.dev package description and screenshot captions are reworded.

## 2.5.0

This release adds general-purpose chart widgets — `SeriesChart`, `PieChart`,
`RadarChart` and `HeatmapChart` — so apps no longer need a second charting
package for non-financial data. It also simplifies the `KChartWidget`
constructor, removes the `flutter_svg` dependency and lowers the minimum SDK
versions.

### Breaking changes

- **`watermarkAssetPath` is replaced by `watermark`.** The new parameter accepts
  any widget (`Image.asset`, `Icon`, `Text`, or `SvgPicture` from `flutter_svg`).
  `watermarkScale`, `watermarkAlignment` and `ChartColors.watermarkColor` behave
  as before. The watermark is now painted over the candle area and ignores
  pointer events. To migrate, remove `watermarkAssetPath` or pass the image as
  `watermark`.
- **`timeFrame` is now `Duration?`.** Code that reads it back from the widget as
  non-null needs a fallback.

### Added — `SeriesChart`

- **`SeriesChart`** plots numeric x/y data. `LineSeries`, `BarSeries` and
  `ScatterSeries` take `SeriesPoint(x, y)` values, or plain values through
  `.values` (placed at `x = 0, 1, 2, …`). `null` produces a gap. Multiple series
  can be combined in one chart and are drawn in list order.
- **Line styles:** `LineCurve.linear`, `smooth`, `step` and `monotone` (which
  never overshoots adjacent points). Lines support dashes, gradients, per-point
  dots via `dotBuilder`, `shadow`, `stepPosition`, and a `negativeColor` below
  `baseline`, split at the exact crossing point.
- **Area fills:** `SeriesFill` fades from the line's peak to the baseline, with
  `negativeGradient` for values below it. `toBaseline: false` fills to the
  bottom of the plot. `SeriesBetweenFill` shades the region between two lines.
- **Bars:** rounded ends via `radius`; fixed or relative width bounded by
  `minWidth` and `maxWidth`; colour via `negativeColor` or `colorBuilder`;
  optional `trackColor`, `border` and `labelBuilder`. Bars sharing a `stack`
  are stacked, and a `SeriesPoint` with `low` renders a floating bar for ranges
  and waterfalls.
- **Scatter:** per-point size, colour, shape (circle, square, diamond, cross)
  and labels. `SeriesTouchSnap.nearestPoint` reads out a single point.
- **Error bars:** `SeriesPoint.xError` and `yError`, styled by
  `SeriesErrorBars`.
- **Axes:** `SeriesXAxis` accepts a label list, `ticks`, `interval` or
  `labelBuilder`, and skips overlapping labels. `SeriesYAxis` supports
  `formatter`, side and fixed `width` for aligning stacked charts. Both axes
  support `title` and `hidden`; `SeriesXAxis.side` places labels above the plot.
- **Grid and annotations:** `SeriesGrid` (solid or dashed), plot `border`,
  `SeriesReferenceLine` and `SeriesBand`.
- **Value range:** the y range fits the visible `minX`–`maxX` window, with
  padding that ends on round ticks and never crosses zero for all-positive
  data. `minY`, `maxY` and `includeZero` override it.
- **Orientation:** `SeriesOrientation.horizontal` rotates the chart, including
  fills, gradients, crosshair and tooltip.
- **Touch and tooltips:** the crosshair activates on `press`, `longPress`,
  `tap` or hover. The default tooltip lists every series; `SeriesTooltip.builder`
  provides a custom widget, positioned automatically within the chart bounds.
  `onTouch` reports the x value and each series' value, or `null` on release.
- **`SeriesChartController`** synchronises the crosshair across charts.
- **`SeriesRangeSelector`** shows a miniature of the full data set with a
  draggable, resizable window.
- **Animation:** with `animationDuration` set, values interpolate between
  updates, and new data grows from the baseline, including on first build.

### Added — pie, radar and heatmap charts

- **`PieChart`** renders pie, doughnut and ring-gauge charts. Each `PieSection`
  is sized by its share of the total and supports a colour or gradient,
  configurable label position, individual `radius`, `offset` (exploded slices),
  border and `badge` widget. `centerSpaceRadius` and `centerChild` create a
  doughnut with centre content; `sectionsSpace`, `startDegreeOffset` and
  `clockwise` control layout. Touched sections grow by `touchedSectionGrowth`.
- **`RadarChart`** compares multiple `RadarSeries` across named `features`.
  Series support fill, dashed outlines and dots. The grid can be polygonal or
  circular, with `tickCount` rings between `minValue` and `maxValue`, spokes and
  optional tick labels (`showTicks`). `onTouch` reports the nearest feature.
- **`HeatmapChart`** colours a grid by value, from a matrix or sparse
  `HeatmapCell`s. Colour scales: `HeatmapGradientScale` (continuous) and
  `HeatmapStepScale` (banded). Includes `HeatmapAxis` row and column labels,
  in-cell labels via `labelBuilder` with automatic contrast, `hoverBorder`,
  `tooltipBuilder`, `squareCells` for contribution graphs and `HeatmapLegend`.
  Touching an empty cell reports the cell with no value.
- **Layout helpers:** `layOutPie`, `pieSectionAt`, `radarCorner`, `RadarLayout`
  and `HeatmapLayout` are public for testing and custom overlays.
- All three widgets support animated updates.

### Changed

- **`isTrendLine` and `timeFrame` are optional.**
  `KChartWidget(candles, ChartColors())` is now a complete chart. Drawing tools
  are disabled unless `isTrendLine` is set. Without `timeFrame`, the
  current-price label shows the price only, with no countdown timer.
- **Minimum SDK lowered to Flutter 3.27 and Dart 3.6** (previously Flutter 3.47
  and Dart 3.13).
- **Wider dependency ranges:** `decimal` from 3.0.0 and `intl` from 0.19.0 to
  below 0.21, for compatibility with the `intl` version pinned by
  `flutter_localizations`. Tests pass on both the lowest and latest versions.
- **Removed dependency:** `flutter_svg`.

### Documentation

- New pages: [Series charts](doc/series-chart.md), [Pie chart](doc/pie-chart.md),
  [Radar chart](doc/radar-chart.md), [Heatmap](doc/heatmap-chart.md) and
  [Migrating from fl_chart and candlesticks](doc/migrating-from-fl_chart.md).
- Corrected the drawing-kind count in `theming.md` and the count of fully
  recomputed indicators in `indicators.md`.

## 2.4.1

This release addresses the intraday-chart issues reported in
[#3](https://github.com/CtrlAltDevelop/ohlcv_chart/issues/3).

### Fixed

- **Axis gutters use the chart background.** The background was previously
  filled only across the plot width, so a right-hand gutter showed whatever was
  behind the widget and a left-hand gutter shifted the fill. Background bands
  now span the full canvas.
- **Out-of-range prices stay inside the candle area.** With a locked axis, ticks
  outside the visible range were drawn over the volume and indicator panes or
  off the canvas. Horizontal lines outside the range are now omitted, and their
  labels are pinned to the nearest edge with an arrow. The current-price line,
  signal lines and trading tags follow the same rule.

### Added

- **`secondaryPriceAxisScale`** draws a second price axis on the opposite side
  (for example, `PriceAxisScale.percentage` alongside prices), sized by
  `ChartStyle.secondaryPriceAxisWidth`. It computes its own round values; the
  grid, crosshair and price tags continue to follow `priceAxisScale`. The two
  gutters together are limited to half the chart width.
- **`priceFormatter`** customises how prices are displayed — currency symbols,
  thousands separators, tick sizes — similar to `dateFormatter`. It applies to
  axis labels, the crosshair label, current-price, high/low and signal tags, and
  the OHLC legend. `percentage` and `indexedTo100` axes keep their own
  formatting.
- **`lockedScaleFollowsPrice`** expands a locked axis just enough to keep the
  newest candle visible while it is in view. The range never shrinks or refits
  to the window. Disabled by default; requires `lockPriceScale`.
- **`ChartStyle.fitContent`** widens candle spacing so a short series fills the
  plot, scaling candle and volume bars proportionally. It never narrows
  spacing, so it can stay enabled as more history loads.

## 2.4.0

### Added

- **`scrollEnabled` and `zoomEnabled`** disable the chart's built-in gestures,
  for fixed views such as a single session, a thumbnail or a static figure.
  - With scrolling disabled, drags and flings are ignored and `onLoadMore` is
    never called.
  - With zooming disabled, pinch is ignored and the zoom slider (web and
    desktop) is hidden.
  - Disable both together: zooming out can otherwise create room to scroll.
  - Programmatic control through `KChartController` (`zoomIn`, `zoomOut`,
    `setChartScale`, `goToIndex`, `fitAll`, …) is unaffected.
  - To show the full series, set `ChartStyle.pointWidth` to roughly the chart
    width divided by the candle count.
- **`lockPriceScale`** keeps the price axis fixed while scrolling instead of
  refitting it to the visible candles, which avoids jumps when paging history
  through `onLoadMore`. It locks to the current range, so enabling it does not
  move the chart; `resetPriceScale` refits and locks again.
  - High/low markers still track the visible window, and a locked axis can
    still be dragged and zoomed.
  - Reset the scale when switching instruments. New candles and live ticks need
    no action.
- **`ChartStyle.priceAxisWidth`** reserves a gutter for the price labels on the
  side set by `verticalTextAlignment`. Candles, grid, indicator panes and the
  date axis stop at the gutter, and the plot is clipped to its bounds. The
  default of `0` keeps the previous behaviour.

### Fixed

- **`onLoadMore` is now invoked.** The callback was accepted but never called.
  It now fires when a drag or fling reaches either edge — once per arrival,
  not every frame — with `true` at the newest candle and `false` at the oldest.
- **Toggling `showInfoDialog` no longer throws.** Re-enabling the readout
  subscribed twice to a single-subscription stream, surfacing as
  `LateInitializationError: Field '_children' has not been initialized`. The
  stream controller is now a broadcast controller.

## 2.3.1

### Performance

This release improves rendering performance with no API or visual changes.

```
Paint time per frame (µs) — 140 candles, 1200×800, median of three runs.
Filled bar: 2.3.1. Hollow bar: 2.3.0.

                        0           200          400  µs
                        ┼──┬──┬──┬──┼──┬───┬──┬──┼──┬──┬──┬
candles                 ███████████████████░░░░░░░░░        312 ← 445  1.4×
OHLC bars               ██████████████████░░░░░░            285 ← 391  1.4×
line                    ████████████░░░░░░░                 190 ← 307  1.6×
area                    ████████████░░░░░░░░░░░░            191 ← 386  2.0×
baseline                ███████████░░░░░░░░░░               173 ← 344  2.0×
step line               ██████████░░░░░░░░░                 162 ← 300  1.9×
high-low band           ██████████░░░░░░░░░░░               163 ← 344  2.1×
columns                 ██████████░░░░░░                    164 ← 254  1.5×
candles + 6 indicators  ████████████████████████░░░░░░░░    382 ← 522  1.4×
a mouse move            ████░░░░░░░░░░░░░░░░░░░░░░░░        72 ← 445  6.2×

Long history behind the visible window:

                        0           1000        2000  µs
                        ┼──┬──┬──┬──┼──┬──┬──┬──┼──┬──┬──┬─
50k candles, 20 lines   ██░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░    198 ← 2668  13.5×
```

With a long history, frame cost previously grew with the total number of
candles; it now depends only on what is visible — **13.5× faster** (2668 µs to
198 µs).

Benchmarks are in `test/paint_benchmark.dart` (not part of `flutter test`).
Regression checks in `test/render_perf_test.dart` count draw calls rather than
time, so they are stable across machines. See the new
[performance page](doc/performance.md) for details.

- **Batched series drawing.** Line, area and band series are now drawn as one
  path instead of one `drawPath` per candle. Over a 90-candle window, draw calls
  drop from 479 to 212 (line), 569 to 213 (area) and 573 to 217 (high-low band).
  Volume moving averages are also batched, reducing candles from 573 to 395
  calls and bars from 663 to 485.
- **Separate crosshair layer.** The chart and crosshair now sit behind separate
  repaint boundaries, and the crosshair updates without a rebuild. Mouse
  movement repaints only the crosshair, its labels and the legends.
- **Text layout caching.** Axis and legend labels are cached by string, colour
  and size.
- **Constant-time drawing anchors.** Resolving a drawing's timestamp to a candle
  index previously searched the entire series for every anchor on every frame.
  A per-series lookup table is now built once.
- **Skipped work when unused.** Event alignment is skipped for charts without
  events, and the alert sweep is skipped when no drawing has alerts.

### Fixed

- Area and baseline fills were painted in per-candle slices that overlapped the
  line, tinting it progressively. The fill is now drawn once, beneath the line.
- Pane legends are no longer clipped by the high and low price markers.

### Tests

- Added `test/render_perf_test.dart` and `test/counting_canvas.dart`, a
  `Canvas` wrapper that counts draw calls. Assertions measure how draw calls
  grow with window size, excluding canvas-sized elements such as the grid.
- Added golden tests for the step line, high-low band and columns chart types.

## 2.3.0

### Added

- **`DepthRatioBar`** shows the share of resting volume on each side of the
  order book. Enable it with `showRatioBar: true` on `DepthChart` or
  `DepthLadder`; it uses the same levels as the widget above it, including
  `zoom`. Changes animate, and an empty book shows a neutral track. Sized by
  `DepthChartStyle.ratioBarHeight` and `ratioFontSize`.

## 2.2.0

### Indicators

- **`SessionVwapIndicator`** — VWAP that resets at each session boundary (daily,
  weekly, monthly or yearly, matching pivot sessions), with volume-weighted
  standard-deviation bands. `deviations: 0` draws the average only. For a VWAP
  over the visible range, rebuild `AnchoredVwapIndicator` from
  `onVisibleRangeChanged`, as shown in the indicators guide.
- **`TimeframeIndicator`** — computes any indicator on a higher timeframe, such
  as a daily moving average on a 15-minute chart. Each candle uses the last
  higher-timeframe bar closed before it opened, so values never repaint or
  look ahead. Aggregation is available as `CandleTransforms.resample` and
  `CandleTransforms.bucketIndices`, using the chart's day and calendar
  boundaries.
- **`AroonIndicator`** — Aroon Up and Down as percentages over `period` candles,
  in a 0–100 pane with guides at 30 and 70. Supports incremental updates.
  Colours: `ChartColors.aroonUpColor` and `aroonDownColor`.

### Navigation

- **`ChartLink`** synchronises the visible window and crosshair across charts.
  Any chart can lead, and feedback loops are prevented. `syncFrom` aligns a chart
  added later. `ChartLink(crosshair: false)` and `ChartLink(window: false)` sync
  one aspect only. `crosshairPrice` and `priceScale` also sync the vertical
  position and price-axis zoom/pan; they are off by default because they only
  apply to charts of the same instrument. `ChartLink.all()` enables everything.
- **Crosshair control on `KChartController`:** `crosshairIndex`,
  `crosshairPrice`, `showCrosshair(index, price: …)` and `hideCrosshair()`, plus
  `KChartWidget.onCrosshairChanged`. The crosshair is tracked by candle index so
  charts of different widths stay aligned, and a programmatic crosshair behaves
  as a hover so it never interrupts user input.
- **Price-axis pan on the controller:** `pricePan` and `setPricePan`, alongside
  the existing `priceZoom`.
- **`ChartOverview`** — a compact chart of the full history with the visible
  window highlighted. Drag the window to scroll, drag its edges to zoom, or tap
  to jump. It uses the same `KChartController` as the main chart, so both stay
  in sync.

### Drawing tools

- **Magnet mode applies to anchor drags** as well as placement. Dragging a whole
  drawing remains unsnapped so its shape is preserved.

### Workspaces

- **`IndicatorTemplate` and `IndicatorTemplates`** save and apply named sets of
  indicators. Saving under an existing name replaces it in place, and
  `IndicatorTemplate.starters` provides four default sets. Serialised with the
  workspace codec; `unsaveable` lists indicators the catalog cannot rebuild.
- **`ChartWorkspace`** serialises indicators, drawings, chart type and
  price-axis settings to JSON. `indicatorToJson` and `indicatorFromJson` handle
  single indicators; unknown entries are skipped rather than throwing.
- **`indicatorTypeRebuilding`** finds the catalog entry that exactly rebuilds an
  indicator. `indicatorTypeOf` matches by name only, which could not distinguish
  daily and weekly pivots.

### Fixed

- `SessionVwapIndicator` no longer draws bands on the first candle of a session,
  which produced a vertical spike at every session open. Bands start from the
  second candle.
- `TimeframeIndicator` legend labels now include the timeframe (for example,
  `MA20@1D`) so they are distinguishable from the chart's own indicators.
- `ChartOverview` and `ChartLink` no longer throw when a controller notifies
  during build; updates are deferred to the end of the frame. The overview also
  reads the window after layout rather than before.
- A linked crosshair is no longer clamped to the previous window when the window
  moves in the same frame.
- Reading a chart's visible window before its first layout now returns `null`
  instead of throwing `LateInitializationError`.

### Package

- **Breaking for documentation links:** the `docs/` directory is renamed to
  `doc/`, following pub conventions. Update any links to pages under `docs/`.
- `KChartHost` has new members: `chartCrosshairIndex`, `chartCrosshairPrice`,
  `chartPricePan`, `setChartPricePan`, and a `price` argument on
  `showChartCrosshair`. This interface is implemented only by `KChartWidget`;
  custom implementations must add these members. `KChartController` gained
  additions only.

## 2.1.0

### Axes

- **Round tick values.** Both axes now select round values first and place
  gridlines at them, instead of labelling evenly spaced pixels. The price axis
  shows `70000, 69500, 69000` rather than `70429, 69745, 69060`, and the date
  axis lands on times such as `06:00, 12:00, 18:00`.
- Logarithmic axes step at 1, 2 and 5 times each power of ten, falling back to
  linear steps for narrow ranges. Percentage axes use round percentages.
- Intraday date axes show clock times, with the date where the day changes. A
  custom `dateFormatter` or `ChartStyle.dateTimeFormat` still takes precedence.
- Overlapping date labels are omitted.
- Tick boundaries follow the displayed time zone, so half-hour
  `timeZoneOffset` values still produce round local times.
- New public helpers for custom axes: `niceTicks`, `niceLogTicks`, `niceStep`,
  `niceTimeStep`, `timeBucket` and `startsNewDay`.

### Replay

- **`ChartReplayController`** replays a chart candle by candle. Pass it to
  `KChartWidget.replay`; the chart, indicators, current-price line and legend
  only see data up to `position`. Controls: `start`, `stepForward`, `stepBack`,
  `play`, `pause`, `toggle`, `setInterval` and `stop`. Listeners are notified on
  every change.

### Sessions and per-bar colour

- **`KChartWidget.session`** shades pre-market and after-hours periods. A
  `TradingSession` defines open and close times and trading days in the
  displayed time zone; sessions where `close` is at or before `open` span
  midnight. Consecutive out-of-session candles are drawn as a single band.
  Colour: `ChartColors.extendedHoursColor`.
- **`KChartWidget.candleColor`** overrides the colour of individual candles,
  bars and columns. Return `null` to keep the default up/down colour.
- `CandleEntity` is now exported.

### Price scale

- **`PriceAxisScale.indexedTo100`** labels the axis relative to the oldest
  visible candle at 100.
- **`KChartWidget.invertPriceAxis`** inverts the price axis. Candles, drawings,
  crosshair, orders and comparisons all follow, and logarithmic axes remain
  logarithmic.
- Candle colour is now determined from prices rather than pixel positions, so
  inverted axes colour candles correctly. Wicks and OHLC bars use sorted
  extents for the same reason.
- **`showAverageClose`** draws a dashed line at the mean close of the visible
  window (`ChartColors.avgColor`).
- **`showHighLowOnAxis`** labels the visible high and low on the price axis.

### Orders and positions

- **`KChartWidget.orders` and `positions`** display account data. A
  `ChartOrder` is drawn at its price and a `ChartPosition` at its average entry,
  each as a full-width line with an axis tag (for example, `Buy 0.5`,
  `Long 1.5  +812.4`). They are not drawings and are not saved with layouts.
- **Draggable orders.** `onOrderDragged` fires during the drag and
  `onOrderMoved` on release. The chart does not modify the order itself; the
  app applies the change. `ChartOrder.draggable` disables dragging per order,
  and orders are not draggable without an `onOrderMoved` handler.
- **`onOrderTapped` and `onPositionTapped`** callbacks. A press without movement
  is reported as a tap.
- New `TradeSide`, `OrderKind` and `TradingStyle` (via `ChartStyle.trading`),
  and `ChartColors.buyColor`, `sellColor` and `tradeColor`.

### Indicator panes

- **`Indicator.scale`** — `IndicatorScale.linear` (default), `.logarithmic` or
  `.percentage` (change from the first visible value). Ticks are computed in
  the chosen space; logarithmic panes fall back to linear when values reach
  zero.
- **`ChainedIndicator`** computes one indicator over another's output, such as
  RSI of MACD. Warm-up periods are combined, and pane settings, guides, format
  and colours come from the applied indicator. `flattenToCandles` is exported.
- **`Indicator.alerts` and `KChartWidget.onIndicatorAlert`** report when the
  latest value crosses a declared level, such as `IndicatorAlert(level: 70)` or
  `IndicatorAlert(level: 0, line: 2)`. Fires once per crossing, for overlays
  and panes.

### Event marks

- **`KChartWidget.events`** shows badges below the candle area for
  `ChartEventKind.earnings`, `.dividend`, `.split`, `.news` and `.custom`, each
  with a default letter and colour. `ChartEvent.label`, `color` and `icon`
  override them.
- Events are matched to the nearest candle by time; `resolveEvents` is exported.
- **`onEventTapped`** reports taps on badges, which take priority over
  selection and drawing input.
- New `ChartColors.eventColors` and `eventColor`, and `ChartStyle.eventMarkRadius`
  and `eventMarkGap`. A radius of `0` hides the badges while keeping the data.

### Visible range

- **`KChartController.visibleRange`** returns a `ChartVisibleRange` with the
  first and last index, their timestamps, candle count and duration.
- **`KChartWidget.onVisibleRangeChanged`** fires after a frame in which the
  visible range actually changed.
- **`showRange`, `showTimeRange`, `goToIndex`, `goToDate` and `fitAll`** move the
  window. `showRange` adjusts zoom and scroll together; `goToIndex` and
  `goToDate` scroll only, animated by default. Each returns whether the window
  moved.
- `indexRangeCovering` and `indexNearest` are exported.

### Chart types

- **`ChartType.stepLine`**, **`ChartType.hlcArea`** and **`ChartType.columns`**.
  `ChartStyle.hlcAreaOpacity` sets the HLC band opacity. HLC area and columns
  keep indicator overlays, legends and high/low markers.

### Candle transforms

- **`CandleTransforms.lineBreak`, `kagi`, `pointAndFigure` and `rangeBars`**,
  alongside Heikin-Ashi and Renko. Each returns regular candles, so indicators
  and drawing tools work unchanged.
- `kagi` accepts the reversal as a price or, with `asPercent`, a percentage.
- `atrBrickSize` can size bricks, boxes, reversals and ranges.

### Comparisons

- **`KChartWidget.comparisons`** overlays other instruments as lines. By default
  each `ComparisonSeries` is rebased to the main series at the left edge of the
  window to show relative performance; `ComparisonScale.price` plots actual
  prices instead.
- Points are aligned to candles by timestamp (last point at or before each
  candle). Gaps break the line.
- The price range expands to include comparisons, and each has a legend row
  showing its percentage change.
- New `ChartColors.comparisonColors` and `getComparisonColor`, separate from
  the moving-average palette.
- `ComparisonSeries.ofCandles`, `alignComparison`, `comparisonAnchor`,
  `comparisonPriceAt` and `resolveComparisons` are exported.

### Context menu

- **Right-click menu** on the chart and on drawings. Drawing actions:
  coordinates, duplicate, copy, bring to front, send to back, lock, hide, alert
  and delete, applied to the whole selection. Chart actions: paste, select all,
  fit price scale, scroll to latest, undo, redo and clear. Right-clicking a
  drawing selects it.
- `KChartWidget.showContextMenu` disables the menu; `contextMenuBuilder`
  customises or replaces it.
- New `ChartMenuItem`, `ChartMenuDivider`, `ChartMenuRequest`,
  `ChartMenuBuilder` and `showChartMenu`.

### Drawing interaction

- **Multi-select.** Shift- or ⌘-click adds to the selection and ⌘A selects all.
  Selected drawings move, delete (as one undo step) and restyle together; the
  line editor shows the selection count.
- `ChartDrawingController` adds `selection`, `selectionLength`,
  `hasMultipleSelected`, `isSelected`, `selectMany`, `selectAll`,
  `addToSelection`, `removeFromSelection`, `toggleSelection`, `clearSelection`
  and `removeAll`. `selected` is unchanged.
- **Copy, paste and duplicate** with ⌘C, ⌘V and ⌘D, offset from the original.
  Controller: `copyToClipboard`, `canPaste`, `clipboardLength`,
  `clearClipboard`, `paste`, `duplicate`. Chart: `copySelection`,
  `pasteDrawings`, `duplicateSelection`.
- **Stacking order** with ⌘] / ⌘[ (one step) and ⇧⌘] / ⇧⌘[ (to front/back).
  Controller: `bringToFront`, `sendToBack`, `bringForward`, `sendBackward`,
  `indexOf`. `ChartDrawings`: `moveToFront`, `moveToBack`, `moveForward`,
  `moveBackward`, `indexOf`. The drawing manager gains reorder buttons.
- **`DrawingTemplate`** stores a drawing's colour, thickness, stroke, fill and
  label visibility for reuse across drawing types. Controller: `saveTemplate`,
  `putTemplate`, `applyTemplate`, `removeTemplate`, `templates`,
  `templatesToJson`, `loadTemplates`.
- **Coordinates dialog** for editing a drawing's anchor prices and candles.
  `KChartWidget.showDrawingCoordinates` hides the button,
  `showDrawingCoordinatesDialog` opens it programmatically, and
  `drawingAnchors`, `setDrawingAnchor` and `drawingAnchorsAreEditable` provide
  generic anchor access.
- **Alerts on more drawings.** The `AlertingDrawing` mixin is applied to
  `HorizontalLine`, `TrendLine`, `ParallelChannel` and `FibRetracement` via
  `alertLevelsAt`. `KChartWidget.onDrawingAlert` reports the drawing, candle and
  price; `onAlertCrossed` continues to fire for horizontal lines.
- `TwoPointDrawing.priceOnLineAt` returns a line's price at a given time.
- Drawing manager rows support duplicate, reorder and shift/⌘-click selection.
  `showStackingControls` hides the reorder buttons.

### Fixed

- `ChartDrawings.save` no longer moves an edited drawing to the top of the
  stack.
- `NumberUtil.format` printed whole numbers as `200.200`; it now prints
  `200.00`.
- Order and position tags now round size and P&L to two decimals.

### Drawing tools

- **13 new tools (29 total):** `pitchfork`, `gannFan`, `gannBox`,
  `fibExtension`, `fibFan`, `fibTimeZones`, `regressionTrend`, `xabcd`,
  `priceRange`, `dateRange`, `callout`, `path` and `flag`, each with hit
  testing, drag handles and serialisation.
- **`MultiPointDrawing`** stores a variable number of anchors; `XabcdDrawing`
  and `PathDrawing` are built on it. Finish a variable-point drawing by tapping
  the same point twice or switching tools (which now completes rather than
  discards an open path).
- `RegressionChannel` fits a least-squares line to closes across its span with
  bands at `deviations` standard deviations. `fitRegression` is exported.
- `PitchforkDrawing` supports Andrews', Schiff and modified Schiff variants.
  `GannFan`, `GannBox`, `FibFan`, `FibTimeZones` and `FibExtension` complete the
  Gann and Fibonacci sets.
- `PriceRangeDrawing`, `DateRangeDrawing`, `CalloutDrawing` and `FlagDrawing`.
- Shared geometry for fans, boxes and pitchforks in `shape_geometry.dart`.
- `DrawingTranslations` names for all new tools, and `ChartDrawings` getters:
  `pitchforks`, `gannFans`, `gannBoxes`, `fibExtensions`, `fibFans`,
  `fibTimeZones`, `regressions`, `xabcds`, `priceRanges`, `dateRanges`,
  `callouts`, `paths`, `flags`.

### Indicators

- **`VolumeProfileIndicator`** — volume by price band, with point of control,
  value area and up/down volume split. Colours: `ChartColors.profileUpColor`,
  `profileDownColor`, `profilePocColor`, `profileValueAreaColor`.
- **`PivotPointsIndicator`** — pivot, three supports and three resistances from
  the previous session. `PivotMethod.standard`, `.fibonacci` and `.camarilla`;
  sessions `PivotSession.day`, `.week`, `.month` and `.year`.
- **`AnchoredVwapIndicator`** — VWAP from a chosen candle onwards.
- Indicators can return an `IndicatorProfile` of `ProfileBin`s from
  `computeProfile` to draw horizontal histograms.
- Catalog entries: `VP`, `PIVOT`, `PIVOTFIB`, `PIVOTCAM`, `PIVOTW` and `AVWAP`.
  Pivot names include the session (`PIVOTW`, `PIVOTM`, `PIVOTY`) so they
  round-trip through saved layouts.

### Price scale

- **Draggable price axis.** Drag the label strip to stretch or compress, drag
  vertically on the chart to pan, and double-tap the labels to refit.
  `KChartWidget.priceScaleDrag` disables it; `ChartStyle.priceScaleGripWidth`
  sets the grab area.
- `KChartController` adds `priceZoom`, `setPriceZoom`, `stretchPrice`,
  `compressPrice` and `resetPriceScale`.

### Panes

- Indicator panes show gridlines and labels at round values instead of only
  their extremes. Panes with fixed ranges (RSI, KDJ, WR) keep their guides.
- MACD and Awesome Oscillator panes draw a zero line.
- The volume pane shows a reference level.

### Theming

- **`ChartColors.gridColumnColor`** for vertical gridlines, defaulting to a
  lighter shade of `gridColor`.

### API

- `BaseChartRenderer.drawGrid` takes an optional `columnXs` so all panes share
  vertical gridlines. Affects only custom renderer subclasses.
- `DrawingToolbar` is now exported.
- `ChartStyle.gridRows` and `gridColumns` are documented as label density
  rather than line counts.

## 2.0.0

### Drawing tools

- **Placement flow:** horizontal and vertical lines are placed with one tap;
  trend lines with one tap per end, previewing the second end. Press-and-drag
  still works, and small accidental movement no longer discards the anchor.
- With a mouse, armed horizontal and vertical tools preview their position.
- Escape or switching tools cancels a partially placed drawing.
- The line editor no longer opens during placement.
- **`KChartWidget.magnetMode`** snaps placement to the nearest open, high, low
  or close within `DrawingStyle.magnetSnapDistance`.
- **Six new tools:** `DrawingTool.ray`, `.extendedLine`, `.arrow`,
  `.horizontalRay`, `.rectangle` and `.fibRetracement`.
- `LineExtension`, `TrendLine.extend` and `TrendLine.arrow` implement the line
  variants; trend lines saved by earlier versions still load.
  `HorizontalLine.startTime` turns a level into a ray.
- `RectangleDrawing` and `FibRetracement`, with `KChartWidget.rectangles`,
  `fibRetracements`, `onAddRectangle`, `onRemoveRectangle`,
  `onAddFibRetracement` and `onRemoveFibRetracement`.
- `TwoPointDrawing` base class, supporting individual anchor drags or moving the
  whole shape.
- `DrawingStyle.arrowHeadLength`, `.rectangleFillOpacity`, `.fibLevels` and
  `.fibFillOpacity`.
- The label field applies to rectangles, and Fibonacci level labels no longer
  overlap.
- **Seven more tools:** `DrawingTool.measure` (price, percent, candles and
  time), `.channel`, `.position` (risk-to-reward), `.ellipse`, `.triangle`,
  `.text` and `.brush`.
- `MeasureDrawing`, `ParallelChannel`, `PositionDrawing`, `EllipseDrawing`,
  `TriangleDrawing`, `TextAnnotation`, `FreehandDrawing` and the
  `ThreePointDrawing` base class.
- `LabelledDrawing` and `FilledDrawing` expose the label field and fill slider
  to every applicable drawing.
- `DrawingStyle.shapeFillOpacity`, `.measureFillOpacity`, `.channelFillOpacity`,
  `.positionFillOpacity`, `.showFillControl` and `.showAlertControl`.

### Persistence

- All drawings serialise. `ChartLine.toJson` and `drawingFromJson` round-trip a
  layout: `jsonEncode(drawings.toJson())` to save, `ChartDrawings.fromJson` to
  load. Unknown drawing kinds are skipped, so layouts from newer versions still
  open.
- **`ChartDrawings`** — an ordered collection with typed views
  (`horizontalLines`, `trendLines`, `positions`, …) and `copyDrawing` for deep
  copies.
- **`KChartWidget.drawings`**, `onAddDrawing` and `onRemoveDrawing` handle all
  drawing kinds. Per-kind lists and callbacks are unchanged.

### Undo and redo

- **`ChartDrawingController`** (via `KChartWidget.drawingController`) owns all
  drawings and records every add, edit, move and delete as an undoable step.
- Keyboard shortcuts: ⌘Z / ⇧⌘Z (Ctrl+Z / Ctrl+Y on other platforms), Delete and
  Escape. `enableKeyboardShortcuts` disables them.
- The controller also owns the selection, keeping external panels and the chart
  in sync.
- **`KChartWidget.selectAfterDrawing`** controls whether the editor opens after
  each placement.

### Drawing manager

- **`DrawingManager`** lists all drawings with show/hide, lock, delete, undo,
  redo and clear. Tapping a row selects the drawing.
- `ChartLine.hidden` hides a drawing without removing it.
- `DrawingTranslations` covers the manager and all seventeen drawing kinds via
  `nameOf`.

### Alerts

- **`HorizontalLine.alert` and `KChartWidget.onAlertCrossed`** report when the
  latest candle closes across a level, once per crossing. The editor's bell
  button toggles the alert.

### Chart types

- **`KChartWidget.chartType`:** `ChartType.candles`, `.bars`, `.line`, `.area`
  and `.baseline` (filled towards `baselinePrice` or the oldest visible close).
  `isLine: true` still produces an area chart.
- **`CandleTransforms.heikinAshi`** and **`.renko`**, with `.atrBrickSize` for
  ATR-based brick sizing.

### Price axis

- **`KChartWidget.priceAxisScale`:** `PriceAxisScale.logarithmic` and
  `.percentage` (change from the oldest visible candle). Non-positive ranges
  fall back to linear.
- `ChartPainter.calculatePrice` and the crosshair price use the renderer's
  inverse mapping, fixing a small crosshair offset on linear axes.

### Desktop support

- **`KChartWidget.crosshairOnHover`** shows the crosshair on mouse hover.
- **`KChartWidget.showOhlcLegend`** displays date, OHLC, change and volume
  above the chart, localised by `ChartTranslations`.
- Fixed a repaint loop caused by notifying the info dialog on every paint.
- Fixed the info dialog throwing on the oldest candle.

### Programmatic control

- **`KChartController`:** `zoomIn`, `zoomOut`, `zoomTo`, `scrollToNow`,
  `isAtRightEdge` and `capture` (PNG export without overlays).
- A scroll-to-latest button appears when scrolled away from the newest candle
  (`showScrollToNowButton`, tooltip `ChartTranslations.jumpToNow`).

### Panes, sessions and time zones

- Indicator panes can be resized by their lower edge (`resizablePanes`) and
  reordered by their legend (`reorderablePanes`, `onReorderPane`). New
  `ChartStyle.paneResizeTolerance`, `.paneGrabHeight`, `.minPaneHeight` and
  `.maxPaneHeight`.
- `ChartStyle.showSessionDividers` and `ChartColors.sessionDividerColor` mark the
  start of each day.
- **`KChartWidget.timeZoneOffset`** shifts displayed times on axes, crosshair,
  legend and day boundaries without modifying data.
- `ChartStyle.copyWith`.
- Fixed pointer events not reaching the chart's `Listener`, which was blocked by
  an enclosing `MouseRegion`.

### Example app

- Demonstrates all tools, chart types, price axes, transforms, the drawing
  manager, undo/redo, JSON save/restore, PNG capture, pane resizing and
  reordering, session dividers and time zones.
- Control panel options wrap as chips to avoid overflow on narrow screens.

### Tests

- Golden tests for chart types, Heikin-Ashi, Renko, logarithmic axis, legend,
  session dividers and all drawings.
- New test suites for serialisation, the drawing controller and shortcuts, the
  drawing manager, shapes, alerts, price axes, chart types, transforms, panes,
  sessions and hover.

## 1.1.0

### Line editor

- **Redesigned line editor.** Selecting a line opens a floating, draggable
  toolbar with a colour grid and opacity slider, thickness presets and slider,
  stroke style previews, a label field, and lock, delete and done buttons. It
  replaces the previous `SimpleDialog` pickers and is hosted in the app overlay
  to avoid gesture conflicts with the chart.
- **`DrawingStyle`** (`KChartWidget.drawingStyle`) configures available colours,
  thicknesses and strokes, visible controls, toolbar appearance and position,
  handle and label geometry, dash lengths and tap tolerance.
- **`DrawingTranslations`** (`ChartTranslations.drawing`) localises the editor.
- **`LineStyle`** (`solid`, `dashed`, `dotted`) on `ChartLine`, and a
  `ChartLine.opacity` accessor. `isDashed` still works.
- Editing, renaming or moving a line now fires the matching `onAdd*` callback,
  so changes can be persisted.
- Trend lines can be selected and dragged by their stroke, not only their
  endpoints.
- `DepthChartStyle` and `DepthChartColors` are now exported.

### Fixed — line editor

- The long-press readout no longer overflows; rows ellipsise and the card sizes
  between the new `infoDialogWidth` and `infoDialogMaxWidth`.
- Line thickness and handle shape no longer distort with horizontal zoom.
- Vertical line labels are drawn once and respect `showLabel`.
- Vertical lines no longer have an extra hard-coded 1-pixel overlay.
- Line label padding is symmetric.

### Indicators

Indicators are now configurable instances rather than enum flags, so the same
indicator can be added multiple times with different settings and colours.

- **Breaking:** `mainStateLi`, `secondaryStateLi` and `maDayList` are replaced
  by a single `indicators` list — for example `MaIndicator(period: 20)`,
  `AtrIndicator(period: 8)` or `MacdIndicator(fast: 5, slow: 34, signal: 5)`.
  `MainState` and `SecondaryState` are removed. Overlays draw on the main chart;
  other indicators each get a pane, in list order.
- Multiple instances of the same indicator are supported, with automatic theme
  colours.
- Each instance accepts `color`, or `colors` for multi-line indicators (`BOLL`,
  `MACD`, `KDJ`, `DMI`), overriding `ChartColors`.
- Indicators are compared by type and settings, excluding colours.
  `indicators.upsert(...)` updates a matching indicator; `toggle` and
  `removeIndicator` are also available. Duplicate entries are de-duplicated.
- **`indicatorCatalog`** describes every indicator's settings, ranges, defaults
  and colour slots for building configuration UIs. See `IndicatorType.create`,
  `valuesOf`, `lineLabels`, `defaultColors` and `indicatorTypeOf`.
- Indicator calculations are now pure functions shared by indicators and
  `DataUtil`.
- **Custom indicators:** subclass `Indicator` and implement `label`, `lines`,
  `settings` and `compute`.

**12 new indicators:**

- Overlays: `SupertrendIndicator`, `KeltnerIndicator`, `DonchianIndicator` and
  `IchimokuIndicator` (with a shaded cloud and standard displacement).
- Swing analysis, controlled by `depth`: `ZigZagIndicator`,
  `FibonacciIndicator` (retracement of the latest swing) and
  `ElliottWaveIndicator` (labels `1`–`5` and `A`–`C`; a swing-based reading, not
  a rules-validated count).
- Panes: `StochRsiIndicator` (20/80 guides), `RocIndicator`, `TrixIndicator`,
  `VolumeMaIndicator` and `AwesomeIndicator`.
- New line shapes for any indicator: `IndicatorShape.pivotLine`,
  `IndicatorShape.markers` (with `markerLabel`) and `fills` between two lines
  (with `fillColor`).
- Swing indicators default to `depth: 0`, which sizes the threshold
  automatically (about eight swings across the data). The label shows `auto`.
- New `ChartColors` entries: `keltnerColor`, `donchianColor`, `conversionColor`,
  `baseColor`, `spanAColor`, `spanBColor`, `laggingColor`, `stochRsiColor`,
  `rocColor`, `trixColor`, `volumeMaColor`, `awesomeColor`, `zigzagColor`,
  `fibonacciColor` and `waveColor`.

### Depth chart

- **`mode`** (`DepthChartMode`): `cumulative` (default), `histogram`, `combined`
  and `ladder`.
- **`DepthLadder`** widget, usable standalone, with `levels` and `barsShowTotal`.
- **`scale`** (`DepthScale`): `linear`, `log` and `percent`.
- **`zoom`** limits levels to a fraction of the mid price, falling back to the
  full book if nothing remains.
- **`DepthBook`** and **`DepthLevel`** derive per-level sizes from cumulative
  curves; `DepthBook.fromCurves` is public.
- The long-press readout shows both the level size and cumulative total.
- New `DepthChartTranslations` entries (`size`, `total`, `bids`, `asks`,
  `spread`) and `DepthChartStyle.barWidthFactor`, `ladderRowHeight` and
  `ladderFontSize`.

### Rendering

- New overlays: `EMA` (sharing the `MA` palette) and `VWAP`.
- New sub-charts: `ATR` (14), `OBV`, `MFI` (14, with 20/80 guides) and `DMI`
  (+DI, −DI and ADX, with a 20 guide), each with its own `ChartColors` entry.
  `DataUtil.calculate` computes them; `calcEMA`, `calcVWAP`, `calcATR`,
  `calcOBV`, `calcMFI` and `calcDMI` are public.
- The main chart range includes `EMA` and `VWAP`, as it does for `BOLL` and
  `SAR`.
- `mBaseHeight` is optional; the candle area fills the remaining height (360 in
  an unbounded box). Pane heights are available via
  `BaseDimension.volumeHeight`, `secondaryPaneHeight` and `legendRowHeight`.
- Visual refinements: coloured pane separators, padded axis-label pills,
  translucent legend pills, optional hollow up candles, a dashed current-price
  line in up/down colours, high/low markers with leader lines, configurable
  crosshair dashes and an aligned, tinted watermark.
- New `ChartStyle` fields: `hollowUpCandles`, `gridStrokeWidth`,
  `separatorWidth`, `axisLabelBackground`, `axisLabelPadding`,
  `labelCornerRadius`, `legendPadding`, `legendSpacing`, `crossDashLength`,
  `crossDashGap`, `nowPriceDashed`, `watermarkAlignment`, `watermarkScale`.
  New `ChartColors` fields: `separatorColor`, `axisLabelBgColor`,
  `legendBgColor`, `watermarkColor`.
- `DepthEntity.bids` and `DepthEntity.asks` build cumulative curves from raw
  order-book levels.
- `VerticalTextAlignment` is now exported.
- The example app demonstrates all overlays and panes, drawing tools with two
  editor styles, live updates, `onLoadMore` pagination, signal markers, readout
  styles, light and dark themes, German localisation, hollow candles and the
  depth chart, with a responsive layout.

### Fixed — rendering

- Pivot-line indicators such as ZigZag now draw segments that span the visible
  window.
- Indicators with no visible values no longer draw an empty path.
- `isTapShowInfoDialog` now works: a tap opens, moves and closes the readout.
- Crosshair price and date labels are shown and hidden together with the
  crosshair, and suppressed while drawing or dragging.
- The volume pane separator no longer uses a hard-coded `Colors.amber`.
- The vertical grid draws the requested number of columns instead of ~120
  mostly off-screen lines.
- The current-price line uses `nowPriceUpColor` and `nowPriceDnColor`.
- The watermark is centred in the candle area.
- The candle area no longer collapses when panes need more height than
  available; panes shrink instead.
- The bottom price label is omitted when it would overlap a pane legend.
- `NumberUtil.formatCompact` preserves the sign of negative values.

## 1.0.0

Initial release, extracted from an internal application module.

- `KChartWidget` with candlestick and line rendering, pinch zoom, fling scroll,
  long-press crosshair and info dialog, current-price line with candle
  countdown, and an SVG watermark.
- Main-chart overlays: `MA`, `BOLL` and `SAR`.
- Secondary charts: `MACD`, `KDJ`, `RSI`, `WR` and `CCI`.
- Trend, horizontal and vertical line drawing tools with selection, dragging,
  colour and thickness editing, and add/remove callbacks.
- Buy/sell `SignalEntity` markers.
- `DepthChart` for cumulative bid/ask depth with a long-press readout.
- `ChartStyle`, `ChartColors` and `ChartTranslations`, plus `DepthChartStyle`,
  `DepthChartColors` and `DepthChartTranslations`, for styling and localisation.
- `DataUtil.calculate` computes all indicators over a candle list.
- Supports iOS, Android, web, Windows, macOS and Linux. The zoom slider is shown
  only on web and desktop.

### Fixed

- `DataUtil.calculate` no longer throws on an empty list.
- Secondary charts scale correctly when an indicator stays below zero (the
  running maximum was seeded with `double.minPositive`).
- `SAR` resets its acceleration factor consistently on both reversal directions.
- The current-price countdown timer starts and stops when `showNowPrice`
  changes.
