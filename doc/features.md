# Features

## Candlestick chart

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

## Indicators

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

## Drawing tools

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

## Interaction and navigation

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

## Trading features

- **Orders and positions** — live lines showing side, size and P&L, draggable
  to modify.
- **Signal markers** — buy and sell markers pinned to candles.
- **Event marks** — tappable badges for earnings, dividends, splits and news.
- **Symbol comparison** — overlay any number of instruments, rebased for
  relative performance and aligned by timestamp.
- **Sessions and time zones** — session dividers, a display time zone,
  extended-hours shading and per-bar colours.
- **Live price line** with a countdown to the current candle's close.

## Other chart widgets

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
- **`VolatilitySurfaceChart`** — implied volatility across strike and expiry as
  a heatmap, with the skew against the at-the-money strike on touch.
- **`FuturesCurveChart`** — prices against delivery month, one or more curves,
  with contango and backwardation read off the first and the calendar spread on
  touch.
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
- **`MaeMfeChart`** — every trade as a point by how far it went against you or
  for you and what it made, with the limit line, reference stops, and the
  winners a stop would have cost.
- **`VarChart`** — a histogram of returns with the loss tail picked out and the
  value at risk and expected shortfall marked, worked out from the history.
- **`EfficientFrontierChart`** — portfolios by risk and return with the
  efficient frontier traced through the best, the best Sharpe ratio, the least
  risky portfolio and the capital market line.
- **`MonteCarloChart`** — a fan of simulated equity paths as percentile bands,
  with the odds of loss and ruin and the real curve laid over.
- **`SeasonalityChart`** — returns by month and year or weekday and hour, with
  yearly totals and the typical month worked out for you.
- **`ActivityClockChart`** — a week as a clock face: the hours of the day round
  the dial and a weekday on each ring, coloured by trades, volume or profit.
- **`DepthChart`** — order-book depth as a cumulative curve, per-level
  histogram, both combined, or a numeric ladder; on a linear, logarithmic or
  percentage axis, zoomable around the mid price, with an optional bid/ask
  ratio bar.
- **`TrainingCurveChart`** — loss and accuracy curves of one or more training runs with smoothing, a log axis, the best checkpoint, divergence and the train/validation gap marked.

## Customisation

- **Theming** — `ChartStyle` for layout, `ChartColors` for colours,
  `DrawingStyle` for drawing tools and `ChartTranslations` for every label.
  Includes filled or hollow candles, crosshair style, pane separators and
  axis-label pills.
- **Watermark** — any widget, such as an `Image.asset` logo, painted as a faint
  single-colour overlay on the candle area.

## Platform notes

- The zoom slider is shown only on platforms without pinch gestures (web and
  desktop).
- `watermark` paints the widget in `ChartColors.watermarkColor`, so full-colour
  logos render as a silhouette. The package does not depend on `flutter_svg`;
  to use an SVG, pass `SvgPicture.asset(...)` from that package.

Back to the [documentation index](README.md).
