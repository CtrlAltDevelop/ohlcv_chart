## 1.1.0

### Drawing tools

- Reworked the line editor. Selecting a drawn line now opens a floating,
  draggable toolbar with a colour swatch grid and opacity slider, thickness
  presets plus a fine slider, solid/dashed/dotted stroke previews, an inline
  label field, and lock, delete and done buttons. It replaces the two bare
  `SimpleDialog` pickers, and its panels are hosted in the app overlay, so their
  sliders and text field no longer compete with the chart's pan and zoom.
- New `DrawingStyle`, passed as `KChartWidget.drawingStyle`: the colours,
  thicknesses and stroke styles on offer, which controls appear, the toolbar's
  colours, radius, padding, axis, icon size and start position, the drawn lines'
  handle and label geometry, dash lengths, and how close to a line a tap has to
  land to select it.
- New `DrawingTranslations`, reachable as `ChartTranslations.drawing`, covering
  every label and tooltip in the editor.
- `LineStyle` - `solid`, `dashed` or `dotted` - on `ChartLine`, alongside a
  `ChartLine.opacity` accessor backed by the colour's alpha channel. `isDashed`
  still reads and writes as before.
- Editing a line now reports it: restyling, renaming or dragging one fires the
  matching `onAdd*` callback, which previously only fired when a line was first
  placed, so those changes could not be persisted.
- A trend line can be selected by its stroke rather than only its two ends, and
  dragging it there moves the whole line.
- `DepthChartStyle` and `DepthChartColors` are exported, so the depth chart can
  actually be themed.

Fixed:

- The long-press readout no longer overflows. Its rows shrink and ellipsise, and
  the card sizes itself to its content between the new `infoDialogWidth` and
  `infoDialogMaxWidth`, capped by the chart's own width. Long translations and
  intraday timestamps used to run past its fixed 130 pixels.
- Drawn lines keep the thickness they were given at every zoom level, and their
  drag handles stay circular. Both were painted inside the chart's horizontal
  scale, which stretched them.
- A vertical line's label is painted once, and only when `showLabel` is set. It
  was drawn twice, and the first pass ignored the flag.
- A vertical line is no longer overlaid by a hard-coded 1-pixel solid line that
  ignored its colour, thickness and stroke style.
- Line labels are padded evenly; the right side had twice the padding of the left.

### Indicators

Indicators are now configured instances rather than enum flags, so the same kind
can be on the chart several times with different settings and colours.

- **Breaking:** `mainStateLi`, `secondaryStateLi` and `maDayList` are replaced by
  a single `indicators` list of `Indicator` instances — `MaIndicator(period: 20)`,
  `AtrIndicator(period: 8)`, `MacdIndicator(fast: 5, slow: 34, signal: 5)` and so
  on. `MainState` and `SecondaryState` are gone. Overlays draw over the candles;
  the rest each take a pane, stacked in the order given.
- Several of one kind is the point: `ATR(8)`, `ATR(14)` and `ATR(20)` are three
  panes, and three moving averages take three theme colours without being told.
- Every instance takes a `color` — or `colors`, one per line, for `BOLL`, `MACD`,
  `KDJ` and `DMI` — which overrides the `ChartColors` palette for that instance
  alone.
- An indicator is identified by its type and settings, colours deliberately
  excluded, so `indicators.upsert(...)` restyles the matching one already on the
  chart instead of stacking a duplicate. `toggle` and `removeIndicator` round out
  the list editing, and the chart itself keeps the last of any equal pair it is
  given.
- New `indicatorCatalog` describes every indicator — its settings with their
  ranges and defaults, and its colour slots — so an "add indicator" dialog can be
  built from data. `IndicatorType.create` builds an instance from a values map,
  `valuesOf` reads an existing one back into the form, `lineLabels` and
  `defaultColors` label and seed the colour pickers, and `indicatorTypeOf` finds
  the entry describing an indicator. The example app's indicator sheet is built
  entirely from it.
- Indicator maths moved into pure series functions that take candles and return
  values, shared by the indicators and by `DataUtil`, which still fills in the
  fields on each `KLineEntity` for the long-press readout.
- Custom indicators: subclass `Indicator`, give it a `label`, `lines`, `settings`
  and a `compute`, and the chart draws, scales, legends and labels it like any
  built-in one.

Twelve new indicators, all of them configurable and repeatable like the rest:

- Overlays: `SupertrendIndicator` (an ATR stop that changes colour when it
  flips), `KeltnerIndicator`, `DonchianIndicator` and `IchimokuIndicator`, whose
  cloud is shaded between its two spans and whose spans and lagging line carry
  the usual displacement.
- Swing readers, all driven by one `depth` — the percentage move that ends a
  swing: `ZigZagIndicator` draws the legs, `FibonacciIndicator` retraces the last
  one so the levels follow the market instead of being placed by hand, and
  `ElliottWaveIndicator` labels the pivots `1`-`5` then `A`-`C`. The wave count
  is a reading of the swings rather than a rules-checked Elliott count.
- Panes: `StochRsiIndicator` (with 20/80 guides), `RocIndicator`,
  `TrixIndicator`, `VolumeMaIndicator` and `AwesomeIndicator`, whose bars take
  the up and down colours by whether momentum grew.
- Three new line shapes behind them, available to any indicator:
  `IndicatorShape.pivotLine` strokes straight across the candles that have no
  value, `IndicatorShape.markers` draws a dot with the indicator's own text
  beside it through `markerLabel`, and `fills` shades the area between two lines
  with `fillColor` deciding its colour from which line is on top.
- The swing readers size their threshold from the candles by default, rather
  than a fixed percentage: `depth: 0` — now the default — aims for roughly eight
  legs across the data, so a zigzag reads the same on a quiet intraday chart as
  on a volatile daily one. A fixed 5% drew nothing at all on a market that never
  moved 5%. Pass any positive `depth` to set it yourself; the label says `auto`
  when it is worked out.
- New `ChartColors` entries for each of them: `keltnerColor`, `donchianColor`,
  `conversionColor`, `baseColor`, `spanAColor`, `spanBColor`, `laggingColor`,
  `stochRsiColor`, `rocColor`, `trixColor`, `volumeMaColor`, `awesomeColor`,
  `zigzagColor`, `fibonacciColor` and `waveColor`.

### Depth chart

The depth chart draws the same book four ways, and can say what is resting on
each rung rather than only the running total.

- New `mode`, a `DepthChartMode`: `cumulative` — the curves it has always drawn
  and still the default — `histogram`, one bar per level sized by what rests on
  that rung alone, `combined` for both at once, and `ladder`, a numeric table of
  price, size and running total with a bar behind each row.
- New `DepthLadder`, the widget behind that last mode, usable on its own to put
  the numbers beside a chart rather than instead of it. `levels` sets how many
  rungs a side it lists and `barsShowTotal` whether its bars follow the running
  total or each rung's own size.
- New `scale`, a `DepthScale`: `linear`, `log` for a book whose far side dwarfs
  the near one, or `percent` to label the axis as a share of the deepest total.
- New `zoom`, which keeps only the levels within that fraction of the mid price.
  A zoom so tight that nothing would be left falls back to the whole book rather
  than to an empty chart.
- New `DepthBook` and `DepthLevel`: each rung's own size recovered from the
  cumulative curves by differencing, so nothing extra has to be passed in.
  `DepthBook.fromCurves` is public for callers who want the levels themselves.
- The long-press readout names the size resting on the rung under the finger as
  well as the running total out to it, and its dot follows whatever the mode
  draws.
- New `DepthChartTranslations` entries — `size`, `total`, `bids`, `asks` and
  `spread` — and `DepthChartStyle.barWidthFactor`, `ladderRowHeight` and
  `ladderFontSize`.

### Rendering

Six new indicators, a reworked look, and a demo that exercises all of it.

- New main-chart overlays: `EMA` — exponential moving averages over the same
  periods as `MA`, sharing its palette — and `VWAP`, accumulated over the
  candles you pass.
- New sub-charts: `ATR` (14), `OBV`, `MFI` (14, with 20/80 guides) and `DMI`
  (+DI, −DI and ADX, with the 20 guide). Each has its own `ChartColors` entry,
  and `DataUtil.calculate` fills them in alongside the existing indicators;
  `calcEMA`, `calcVWAP`, `calcATR`, `calcOBV`, `calcMFI` and `calcDMI` are
  public if you want a subset.
- The main chart's price range now stretches to hold `EMA` and `VWAP`, the way
  it already did for `BOLL` and `SAR`, so a lagging average is never clipped.
- `mBaseHeight` is optional. Left unset, the candle area takes whatever height
  the panes below it do not need, so the chart fills its box instead of painting
  past it; in a box with no height to divide it falls back to 360. Pane heights
  are available as `BaseDimension.volumeHeight`, `secondaryPaneHeight` and
  `legendRowHeight`.
- Rendering polish, all of it configurable: pane separators in their own colour,
  price-axis labels padded and set on a pill so they stay readable over candles,
  indicator legends on rounded translucent pills, optional hollow rising
  candles, a dashed "now price" line in the up/down colours with its tag on the
  side the axis labels are not using, high/low markers drawn with a leader line,
  a crosshair with configurable dash lengths, and a watermark placed by
  alignment and tinted rather than pinned to a fixed offset.
- New `ChartStyle` fields: `hollowUpCandles`, `gridStrokeWidth`,
  `separatorWidth`, `axisLabelBackground`, `axisLabelPadding`,
  `labelCornerRadius`, `legendPadding`, `legendSpacing`, `crossDashLength`,
  `crossDashGap`, `nowPriceDashed`, `watermarkAlignment`, `watermarkScale`.
  New `ChartColors` fields: `separatorColor`, `axisLabelBgColor`,
  `legendBgColor`, `watermarkColor`, plus the new indicators' colours.
- `DepthEntity.bids` and `DepthEntity.asks` build cumulative depth curves from
  raw order-book rungs, sorting by price and accumulating outwards from the mid.
- `VerticalTextAlignment` is exported, so `verticalTextAlignment` can be named.
- The example is now a full tour: every overlay and pane, drawing tools with two
  editor styles, live ticks that roll the candle over, `onLoadMore` pagination,
  signal markers, both readout styles plus a custom builder, light and dark
  palettes, a German localisation, filled and hollow candles, and the depth
  chart — laid out side by side on a wide window and stacked on a narrow one.

Fixed:

- A pivot line — a zigzag, and anything else defined only at its corners — draws
  the leg that crosses the visible window. The painter walked only the candles in
  view, so a swing whose two ends sat either side of the window drew nothing at
  all, and the line vanished as soon as it was zoomed into.
- An indicator with no values in view no longer hands an empty path to the
  canvas.
- `isTapShowInfoDialog` does something. The tap flag it depends on was never
  set, so the readout only ever opened on a long press; a tap now opens it,
  moves it, and closes it again.
- The crosshair's price and date labels no longer appear without the crosshair
  itself. Both are shown together, and both are suppressed while a line is
  being drawn or dragged, instead of the labels being drawn whenever a long
  press happened and the lines being hidden for good as soon as the drawing
  tools were enabled.
- The line above the volume pane is no longer amber: the separator paint had a
  hard-coded `Colors.amber` that no theme could reach.
- The vertical grid draws the number of columns asked for. Both the main chart
  and the volume pane looped over a pixel distance instead of the column count,
  drawing around 120 lines per frame, nearly all of them off screen.
- The "now price" line uses `nowPriceUpColor` and `nowPriceDnColor`, which
  existed for it but went unused — it was drawn in the high/low marker colours,
  near-black by default.
- The watermark is centred in the candle area rather than pinned to a
  hard-coded offset that put it off screen on small charts.
- The candle area no longer collapses in a box shorter than the panes ask for;
  the panes shrink to fit instead of overlapping the candles.
- The bottom price-axis label is left out when a pane sits below the main chart,
  where it used to be drawn on top of that pane's legend.
- `NumberUtil.formatCompact` keeps the sign of negative values, which OBV needs.

## 1.0.0

- Initial release, extracted from an internal application module.
- `KChartWidget`: candlestick and line rendering, pinch zoom, fling scroll,
  long-press crosshair and info dialog, "now price" line with candle countdown,
  and an SVG watermark.
- Main-chart overlays `MA`, `BOLL` and `SAR`, selectable as a set.
- Secondary charts `MACD`, `KDJ`, `RSI`, `WR` and `CCI`, stacked.
- Drawing tools for trend, horizontal and vertical lines, with selection,
  dragging, colour and thickness editing, and add/remove callbacks.
- Buy/sell `SignalEntity` markers.
- `DepthChart` for bid/ask cumulative market depth with a long-press readout.
- `ChartStyle`, `ChartColors` and `ChartTranslations` for full visual and text
  customisation; `DepthChartStyle`, `DepthChartColors` and
  `DepthChartTranslations` for the depth chart.
- `DataUtil.calculate` computes every indicator in place over a candle list.
- Runs on iOS, Android, web, Windows, macOS and Linux. The zoom slider now
  appears only where there is no pinch gesture — web and desktop — where
  before a always-true platform check rendered it on mobile as well.

Fixed while extracting the module:

- `DataUtil.calculate` no longer throws on an empty candle list, so the chart
  can be built before the first candles arrive.
- Secondary charts scale to their true maximum when an indicator stays below
  zero. `MACD` and `CCI` in a sustained decline previously scaled against zero,
  because the running maximum was seeded with `double.minPositive` — a tiny
  positive number rather than a lower bound.
- `SAR` resets its acceleration factor identically on both trend reversals;
  the up-to-down reversal previously restarted one step too fast.
- The "now price" countdown timer starts and stops when `showNowPrice` changes,
  instead of only being read once when the chart is first built.
