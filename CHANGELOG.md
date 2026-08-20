## 2.0.0

### Drawing tools

- Placing a line now follows the flow of the big charting apps. Horizontal and
  vertical lines land with a single tap; a trend line takes one tap per end,
  with the far end rubber-banding along with the pointer in between. Press and
  drag still draws a line in one gesture, and a press that only wandered a pixel
  no longer throws the anchor away — the next tap finishes that line.
- With a mouse, an armed horizontal or vertical tool previews where its line
  would land as the pointer moves.
- Escape cancels a line that is half-placed, as does switching to another tool.
- The line editor no longer opens over a line that is still being placed.
- New `KChartWidget.magnetMode`, which snaps points being placed to the nearest
  open, high, low or close, within the new `DrawingStyle.magnetSnapDistance`.
- Six new things to draw, on the same tap-tap placement: `DrawingTool.ray` and
  `.extendedLine` for a line that carries on past one or both of its anchors,
  `.arrow` for one with an arrowhead, `.horizontalRay` for a level that only
  applies from its own candle rightwards, `.rectangle` for a price range box,
  and `.fibRetracement` for a labelled, banded retracement of a swing.
- New `LineExtension` and `TrendLine.extend` and `.arrow` carry the three line
  variants, so trend lines saved by an earlier version still load. New
  `HorizontalLine.startTime` turns a level into a ray.
- New `RectangleDrawing` and `FibRetracement`, drawn from `KChartWidget`'s new
  `rectangles` and `fibRetracements` and reported through `onAddRectangle`,
  `onRemoveRectangle`, `onAddFibRetracement` and `onRemoveFibRetracement`.
- New `TwoPointDrawing` base, shared by every drawing with two anchors. Its
  anchors can be dragged one at a time or the shape moved as a whole, whichever
  the tap landed on.
- New `DrawingStyle.arrowHeadLength`, `.rectangleFillOpacity`, `.fibLevels` and
  `.fibFillOpacity`.
- The editor's label field now also names a rectangle, and a retracement's level
  labels are stacked so they no longer print on top of each other when the
  levels bunch up.
- Nine more things to draw: `DrawingTool.measure` for a ruler that reads out the
  move in price, in percent, in candles and in time; `.channel` for a parallel
  channel; `.position` for a planned trade with its risk-to-reward; `.ellipse`
  and `.triangle`; `.text` for a note pinned to a point; and `.brush` for a
  freehand stroke.
- New `MeasureDrawing`, `ParallelChannel`, `PositionDrawing`, `EllipseDrawing`,
  `TriangleDrawing`, `TextAnnotation` and `FreehandDrawing`, plus the
  `ThreePointDrawing` base the three-point shapes share.
- New `LabelledDrawing` and `FilledDrawing`, which is how the editor's label
  field and its new fill slider reach every drawing that has one.
- New `DrawingStyle.shapeFillOpacity`, `.measureFillOpacity`,
  `.channelFillOpacity` and `.positionFillOpacity` for the new shapes' washes,
  plus `.showFillControl` and `.showAlertControl` for the two new buttons.

### Persisting what is drawn

- Every drawing now serialises. `ChartLine.toJson` and the top-level
  `drawingFromJson` are a matched pair, so a layout survives a restart:
  `jsonEncode(drawings.toJson())` on the way out, `ChartDrawings.fromJson` on the
  way back. A drawing of a kind this version does not know is skipped rather than
  throwing, so a layout written by a newer release still opens.
- New `ChartDrawings`: an ordered set of drawings with typed views —
  `horizontalLines`, `trendLines`, `positions` and the rest — and `copyDrawing`,
  which deep-copies one through its own JSON.
- New `KChartWidget.drawings`, which takes drawings of any kind, and
  `onAddDrawing` / `onRemoveDrawing`, which report every kind. The per-kind lists
  and callbacks are unchanged.

### Undo and redo

- New `ChartDrawingController`, handed to `KChartWidget.drawingController`. It
  owns the drawings: everything the user places, restyles, drags or deletes goes
  through it, which is what makes `undo` and `redo` possible. An edit is a step,
  so restyling a line and undoing gets the old style back.
- ⌘Z, ⇧⌘Z (Ctrl and Ctrl+Y elsewhere) and Delete now work on the chart itself,
  and Escape still abandons a drawing being placed. `enableKeyboardShortcuts`
  turns the lot off.
- The controller also holds the selection, so a panel outside the chart and the
  chart itself always agree on what is selected.
- New `KChartWidget.selectAfterDrawing`, so the editor need not open over each
  drawing as it lands — which is what makes drawing several in a row bearable.

### The drawing manager

- New `DrawingManager`, a widget over a `ChartDrawingController`: every drawing
  by name, with show/hide, lock, delete, undo, redo and clear. Tapping a row
  selects that drawing on the chart.
- New `ChartLine.hidden`, which leaves a drawing in the layout but off the chart.
- `DrawingTranslations` now covers the manager and the names of all seventeen
  kinds, through `nameOf`.

### Alerts

- New `HorizontalLine.alert` and `KChartWidget.onAlertCrossed`: a level with an
  alert reports when the newest candle closes on the other side of it, once per
  crossing. The editor's bell button arms one.

### Chart types

- New `KChartWidget.chartType`: `ChartType.candles`, `.bars` for OHLC bars,
  `.line`, `.area` and `.baseline` — the close line washed towards
  `baselinePrice`, or towards the oldest close in view. `isLine: true` still
  means an area chart.
- New `CandleTransforms.heikinAshi` and `.renko`, which rewrite the candles
  rather than the way they are drawn, plus `.atrBrickSize` to size a Renko brick
  from the market's own range.

### Price axis

- New `KChartWidget.priceAxisScale`: `PriceAxisScale.logarithmic` gives equal
  ratios equal space, which is what makes a long history readable, and
  `.percentage` reads the axis out as the move away from the oldest candle in
  view. A window whose low is zero or negative falls back to a linear axis rather
  than drawing nothing.
- `ChartPainter.calculatePrice` and the crosshair's price now come from the
  renderer's own inverse mapping, so a price and its pixel agree exactly whatever
  the axis is spaced by. That also fixes the crosshair reading a price a few
  pixels off on a linear axis.

### Reading the chart on a desktop

- The crosshair now follows a resting mouse, without waiting for a press — new
  `KChartWidget.crosshairOnHover`, which touch devices never see.
- New `KChartWidget.showOhlcLegend`, which reads the candle out above the chart —
  date, open, high, low, close, the move over it and its volume — on a legend row
  of its own, worded by `ChartTranslations`.
- Fixed a repaint loop: the info dialog was told about the candle under the
  crosshair on every paint, which rebuilt the dialog, which painted again. It is
  only told when something has actually changed.
- Fixed the info dialog throwing when the crosshair sat on the oldest candle,
  which has nothing before it to compare against.

### Driving the chart from your own code

- New `KChartController`: `zoomIn`, `zoomOut`, `zoomTo`, `scrollToNow`,
  `isAtRightEdge` and `capture`, which hands back the chart as PNG bytes without
  the editor or any other control floating over it.
- The chart now shows a button back to the live candle whenever it is scrolled
  away from one — `showScrollToNowButton`, with its tooltip in
  `ChartTranslations.jumpToNow`.

### Panes, sessions and time zones

- An indicator pane can be dragged taller or shorter by its lower edge
  (`resizablePanes`) and up or down the stack by its legend row
  (`reorderablePanes` and `onReorderPane`, which reports the move and leaves it
  to the host, since the indicators own their order). New
  `ChartStyle.paneResizeTolerance`, `.paneGrabHeight`, `.minPaneHeight` and
  `.maxPaneHeight`.
- New `ChartStyle.showSessionDividers` and `ChartColors.sessionDividerColor`,
  which mark the first candle of each day.
- New `KChartWidget.timeZoneOffset`, added to every candle's time before it is
  shown — on the axis, in the crosshair, in the legend and when working out where
  a day starts. It never touches the data.
- New `ChartStyle.copyWith`.
- Fixed raw pointer events never reaching the chart's own `Listener`, which sat
  outside a `MouseRegion` that swallowed them. That is what a press has to be
  read from to tell a pane's edge from its body, since a drag is only recognised
  once it has moved on.

### The demo

- The example now drives all of it: every tool and chart type, the three price
  axes, Heikin-Ashi and Renko, the drawing manager beside the chart, undo and
  redo, saving the layout as JSON and restoring it, capturing the chart as a PNG,
  resizable and reorderable panes, day dividers and a display time zone.
- Its control panel lays every option list out as wrapping chips, so the panel no
  longer overflows at its narrowest.

### Tests

- Golden tests over the painters: the five chart types, Heikin-Ashi and Renko, a
  logarithmic axis, the legend and day dividers, and every drawing at once.
- New suites for serialisation, the drawing controller and its shortcuts, the
  drawing manager, the new shapes and alerts, the price axes, the chart types and
  transforms, and the chart surface — the controller, panes, sessions and hover.

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
