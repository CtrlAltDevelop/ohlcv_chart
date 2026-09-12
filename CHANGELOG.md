## 2.4.1

Five changes, one for each point raised in
[#3](https://github.com/CtrlAltDevelop/ohlcv_chart/issues/3) about the intraday
chart.

### Fixed

- **An axis gutter is painted in the chart's own background.** It was filled
  from the canvas edge for the plot's width, which left a gutter on the right
  showing whatever was under the widget, and shifted the fill when a gutter was
  held back on the left. Every band now spans the whole canvas, so a label
  drawn in a gutter has the chart behind it.

- **A price the axis does not reach no longer escapes the candle area.** A
  locked axis makes that ordinary — the range is held where it was, so a tick
  beyond it had nowhere of its own to go and was drawn over the volume and
  indicator panes, or off the canvas where it could not be seen at all. A
  horizontal line at such a price is now left out of the plot and its label is
  pinned to the edge the price went past, marked with an arrow so the level can
  still be found. The current-price line, the signal lines and the trading tags
  are held to the same edge, and the trading lines already were.

### Price axis

- **New `secondaryPriceAxisScale` draws a second axis down the other side.**
  The chart had one price axis, so reading a move as a percentage meant giving
  up the prices. A second axis reads the same candles another way —
  `PriceAxisScale.percentage` for the change since the oldest candle in view —
  in a gutter on the side `verticalTextAlignment` left free, sized by
  `ChartStyle.secondaryPriceAxisWidth`. It marks its own round values rather
  than labelling the price axis's, the grid stays ruled by the price axis, and
  the crosshair and the price tags keep following `priceAxisScale`. The two
  gutters share half the chart's width between them, so a second axis cannot
  crowd the candles out.

- **New `priceFormatter` writes the prices the chart shows.** `fixedLength`
  only said how many decimals to use, so a currency symbol, a thousands
  separator or a tick size had nowhere to go. It takes the writing over the way
  `dateFormatter` does on the date axis, and covers every price the chart says:
  the axis labels, the crosshair's price label, the current-price tag, the
  high, low and signal tags, and the OHLC legend. An axis that reads out a move
  rather than a price — `percentage`, `indexedTo100` — writes that move itself
  and does not ask.

- **New `lockedScaleFollowsPrice` keeps the newest candle on a locked axis.**
  A locked axis holds the range it was given, so a market that trades past that
  range walked off the top or the bottom of the chart until `resetPriceScale`
  was called. With this set the locked range grows just enough to cover the
  newest candle, and never shrinks back or refits to the window — so the axis
  still sits still while scrolling, which is what the lock is for. Only the
  newest candle counts, and only while it is in view: growing the axis to
  swallow the history a scroll moves over would undo the lock a little at a
  time. Off by default, and does nothing without `lockPriceScale`.

### Layout

- **New `ChartStyle.fitContent` spreads a short series across the whole plot.**
  `pointWidth` is a fixed distance, so a handful of intraday bars bunched up
  against the left edge and left the rest of the chart empty. With this set the
  spacing is widened to whatever fills the plot, and the candle and volume bars
  widen with it so they keep their proportions. It only ever widens: a series
  long enough to fill the plot, or one zoomed in past it, is laid out on
  `pointWidth` as before, so the flag can stay on while history pages in.

## 2.4.0

### A chart that sits still

- **New `scrollEnabled` and `zoomEnabled` turn the chart's own gestures off**,
  for a chart that is meant to show one fixed stretch rather than be navigated
  — an intraday session, a thumbnail, a printed figure. With `scrollEnabled`
  off a drag neither slides the window nor flings it, and `onLoadMore` is never
  asked for more candles, since no edge is ever reached. With `zoomEnabled` off
  a pinch does nothing, and the zoom slider — only ever shown on the web and on
  desktop, where there is no pinch — is left off too.
- They are worth turning off together. Zooming out makes the candles narrower,
  which leaves the window room to scroll into, so a chart that only had
  `scrollEnabled` off could be pinched back into a scrollable one.
- Both hold the user back and leave your own code alone, the way
  `priceScaleDrag` already did: `zoomIn`, `zoomOut`, `setChartScale`,
  `goToIndex`, `fitAll` and the rest of `KChartController` still work.
- For a chart drawn at a fixed position, give `ChartStyle.pointWidth` roughly
  the chart's width divided by the number of candles. Once the whole series
  fits, there is nowhere to scroll to even before the flag.

### Price axis

- **New `lockPriceScale` keeps the axis still while the chart scrolls.** The
  axis fits the candles in the window, so scrolling rescaled it: dragging back
  through a trend changed every number on it. Locked, it holds the range it was
  already showing and the candles move under a scale that stays where it is —
  which is what reading a level off the axis while scrolling needs, and what
  paging in history through `onLoadMore` needs in order not to jump. It locks
  onto what is already on screen, so turning it on does not move the chart, and
  `resetPriceScale` hands the axis back: it refits to the window and holds there
  afresh.
- Only the scale is held. The window's own high and low are still measured, so
  their markers keep pointing at the candles that set them, and a locked axis
  can still be dragged and zoomed — from the range it is held at rather than
  the window's. The range is held until it is reset, so a chart that switches to
  another instrument should reset it; paging in candles and live ticks need
  nothing, which is the point.
- **New `ChartStyle.priceAxisWidth` holds a gutter back for the labels.** It is
  taken off whichever side `verticalTextAlignment` puts them on, and the
  candles, the grid, the indicator panes and the date axis all stop short of it,
  so the labels sit in the gutter on their own instead of candles sliding under
  the numbers. The plot is clipped to its own bounds, so nothing spills into the
  gutter, and pressing the labels grabs the scale the way pressing the axis
  strip always has. Left at 0, the default, nothing changes: the labels are
  drawn over the candles exactly as before.

### Fixed

- **`onLoadMore` is called again.** The callback was declared, documented and
  accepted, but nothing in the package ever invoked it, so paging in older
  candles could not work however it was wired up. It is now asked at both
  places the scroll is clamped — dragging and flinging — with the edge latched,
  so a drag held against the edge asks once when it arrives rather than on
  every frame, and asks again after coming away and going back. The flag is
  `true` at the newest candle and `false` at the oldest, as documented.

- **The long-press readout can be turned off and on again.** It listened to a
  single-subscription stream from a subtree that is only mounted while
  `showInfoDialog` is set. Setting it back to `true` made a second listen on a
  stream already listened to, which threw `Bad state: Stream has already been
  listened to` as the readout remounted — and because that throw landed while
  the enclosing `Stack` was mounting its children, what callers actually saw was
  `LateInitializationError: Field '_children' has not been initialized`. The
  controller is a broadcast one now.

## 2.3.1

### Performance

Nothing about the chart's API or how it looks has changed; it is the same chart
drawn for less.

```
Microseconds to paint one frame — 140 candles in a 1200×800 box, median
of three runs. Filled is what it costs now; hollow is what went away.

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

With a long history behind the window, on a scale of its own:

                        0           1000        2000  µs
                        ┼──┬──┬──┬──┼──┬──┬──┬──┼──┬──┬──┬─
50k candles, 20 lines   ██░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░    198 ← 2668  13.5×
```

The last row is the one to look at: a long history behind the window used to
cost far more than what was on screen, and now it does not — **13.5× faster**,
2668µs a frame down to 198.

Measured with `test/paint_benchmark.dart`, which is not run by `flutter test` —
run it by name either side of a change. The assertions that guard this live in
`test/render_perf_test.dart` and count draw calls rather than time, since a
count means the same thing on a busy machine as on an idle one. The new
[performance page](doc/performance.md) has the whole picture.

- **A series is drawn in one call, not one per candle.** The renderers are
  handed a candle at a time, so a line chart spent a `drawPath` on every candle
  in the window — and a throwaway `Path` with it. Each piece is now collected as
  its own subpath and drawn once, which draws the same thing: an unjoined
  subpath strokes exactly as a separate call did. Over a ninety-candle window
  that is 479 draw calls down to 212 for a line, 569 to 213 for an area, 573 to
  217 for a high-low band. Both volume moving averages were stroked per segment
  on *every* chart type — some 180 calls a frame — and are now two paths, which
  takes candles from 573 to 395 and bars from 663 to 485. What is left per
  candle is what is genuinely per candle: a candle body and an OHLC bar stay one
  rectangle each.

- **The crosshair is drawn on a layer of its own.** The chart and the crosshair
  over it now sit behind separate repaint boundaries, and the crosshair is
  driven directly rather than through a rebuild. Moving the mouse redraws the
  crosshair, its readouts and the legends — which read out the candle under it —
  and leaves every candle, indicator and axis label as it was. Before, a chart
  with a resting mouse over it redrew everything on every mouse move.

- **Labels are laid out once.** Laying out text is the most expensive thing the
  chart does per label, and the price axis, the date axis and the legends read
  the same strings frame after frame. They are held laid out, keyed by the
  string, its colour and its size, so a recolour or a resize measures afresh and
  nothing else does.

- **A drawing's anchor no longer searches the history.** A drawing remembers
  when it was placed rather than where, and turning that back into a candle
  index searched the whole series — once per anchor, twice for a two-point
  shape, on every frame. With a long history and a few drawings on it that was
  the most expensive thing in the frame, and it grew with how much history was
  loaded rather than with what was on screen. The lookup is built once per
  series instead, which is **13.5× faster** on fifty thousand candles with
  twenty lines over them.

- **A chart with no events no longer lines any up.** Aligning events handed over
  a list of every candle's timestamp, rebuilt every time a tick moved the newest
  candle. A chart with nothing to align now skips it, as does a chart with no
  alerting drawings when the alert sweep runs.

### Fixed

- The wash under an area or baseline chart was drawn in per-candle slices, so
  each slice was painted over the stroke of the one before it and the line came
  out progressively tinted. The wash now goes down whole and the line is drawn
  over it.

- A pane's legend is no longer drawn under the high and low price markers, which
  could clip it where the two happened to overlap.

### Tests

- `test/render_perf_test.dart` and `test/counting_canvas.dart` — a `Canvas` that
  tallies every drawing call and forwards it to a real one, and assertions on
  what a frame costs. Measured as the *growth* in draw calls as the window
  widens rather than an absolute count, so the grid and the dashed price line —
  which scale with the canvas rather than with the data — stay out of the
  answer, and so the numbers mean the same thing on a busy CI machine as on an
  idle laptop.

- Goldens for the step line, the high-low band and the columns chart, three
  chart types that had none.

## 2.3.0

### Depth chart

- **`DepthRatioBar`** — the volume resting on each side of the book added up and
  drawn as two lengths meeting in the middle, each labelled with its share. It
  says plainly what the shape of a depth chart only hints at: which way the
  resting orders lean, and by how much. `showRatioBar: true` closes off either
  `DepthChart` or `DepthLadder` with one, weighing exactly the levels the widget
  above it is showing — `zoom` and all — so the number agrees with the picture.
  It slides to each new reading rather than jumping, and a book with nothing on
  either side holds its place as a grey track rather than collapsing the row it
  sits in. `DepthChartStyle.ratioBarHeight` and `ratioFontSize` size it.

## 2.2.0

### Indicators

- **`SessionVwapIndicator`** — the VWAP a desk means by the word, beginning
  again at every session boundary rather than dragging the whole history behind
  it, with a band of volume-weighted standard deviations either side. Resets
  daily, weekly, monthly or yearly, on the same boundary the pivot levels step
  on. `deviations: 0` draws the average alone. A VWAP over the *visible range*
  is the existing `AnchoredVwapIndicator` rebuilt from `onVisibleRangeChanged`,
  which the indicators page now shows.

- **`TimeframeIndicator`** — an indicator computed on bars coarser than the
  chart is drawn at, so a daily moving average reads on a fifteen-minute chart.
  Each candle takes the last higher-timeframe bar that had closed when it
  opened, so the line steps once per bar, never repaints, and never shows a
  value computed from the candle's own future. The aggregation is public on its
  own as `CandleTransforms.resample` and `CandleTransforms.bucketIndices`, and
  follows the chart's own bucketing — a daily bar breaks where the day divider
  does, a monthly one on the calendar.

- **`AroonIndicator`** — how recently the highest high and the lowest low of
  the last `period` candles fell, each as a percentage. Up near 100 marks a
  fresh high, down near 100 a fresh low, and the cross between the two lines is
  the usual read of a change in trend. Takes a pane of its own, fixed to 0–100
  with guides at 30 and 70, and resumes on a tick like the other window-based
  indicators. Its two lines are themed through `ChartColors.aroonUpColor` and
  `aroonDownColor`.

### Navigation

- **`ChartLink`** — holds any number of charts on the same visible window and
  crosshair, so scrolling, zooming or pointing at one carries the rest with it.
  No leader: whichever chart the user moves is the one followed, and the link
  guards against the push back that would otherwise bounce the window between
  them. `syncFrom` joins a chart built later to where the others already are.
  `ChartLink(crosshair: false)` and `ChartLink(window: false)` carry one half
  alone. `crosshairPrice` and `priceScale` add the vertical — how high the
  crosshair sits, and the axis's stretch and shift — and are off by default
  because they only mean anything between charts of the same instrument; two
  instruments at different prices share no vertical scale. `ChartLink.all()`
  turns on everything, for one market shown twice.
- **The crosshair is now readable and movable from `KChartController`** —
  `crosshairIndex`, `showCrosshair(index)` and `hideCrosshair()`, with
  `KChartWidget.onCrosshairChanged` reporting where it moved to. It is carried
  by candle rather than by pixel, so charts of different widths point at the
  same bar, and one put up from outside reads as hovered rather than held down
  so it never displaces a press the user is making. `crosshairPrice` reads how
  high it sits and `showCrosshair(index, price: …)` sets it; left off, it rests
  mid-pane.
- **The price axis's shift is now on the controller too**, as `pricePan` and
  `setPricePan`, alongside the `priceZoom` that was already there.
- **`ChartOverview`** — a slim chart of the whole history to sit under the main
  one, with the visible window lit on it. Drag the lit part to scrub, drag
  either edge to widen or narrow the window, or tap anywhere to jump there. It
  drives the chart through the same `KChartController` and reads the window
  back from it, so the two never disagree — and a chart moved by any other
  means moves the strip with it. Panning to either end slides the window up
  against it rather than shrinking it.

### Drawing tools

- **Magnet mode now snaps an anchor being dragged**, not only one being placed
  — which is how a line already drawn gets pinned exactly onto a wick. Dragging
  a drawing by its *body* is still unsnapped on purpose: it moves by the
  distance the pointer has travelled, and snapping one end of that measurement
  would shift the shape rather than move it.

### Saving a workspace

- **`IndicatorTemplate` and `IndicatorTemplates`** — a named set of indicators,
  saved and put on any chart in one gesture; what `DrawingTemplate` is to a
  drawing's look. Saving under a name already taken replaces it in its place,
  and `IndicatorTemplate.starters` holds four ordinary sets so a template menu
  has something in it on the first run. Serialises through the same codec a
  workspace uses, with `unsaveable` naming anything the catalog cannot rebuild.

- **A chart workspace saves and restores.** `ChartWorkspace` bundles the
  indicators, the drawings, the chart type and the price-axis settings into one
  JSON-serialisable snapshot, so an app can reopen the chart somebody left.
  `indicatorToJson` and `indicatorFromJson` do one indicator apiece; anything a
  release does not recognise is skipped rather than throwing.
- `indicatorTypeRebuilding` finds the catalog entry that rebuilds an indicator
  exactly, where `indicatorTypeOf` matched on the name alone — which could hand
  back a daily pivot for a weekly one, both being named `PIVOT`.

### Fixed

- **A session VWAP banded the first candle of every session**, where a lone
  observation has no spread at all — both bands pinned to the average and then
  flung apart on the next candle, drawing a vertical line through the chart at
  every session open. The bands now wait for a second candle; the average still
  starts at the first.
- **`TimeframeIndicator` named its lines after the applied indicator alone**, so
  a daily `MA20` and the chart's own `MA20` were two legend rows reading exactly
  alike. They now carry the timeframe: `MA20@1D`.
- **`ChartOverview` and `ChartLink` acted on a controller notification
  synchronously**, and a chart notifies while it is building — so marking a
  sibling dirty from there threw. Both now wait for the frame to end. The strip
  also read the window before the chart had laid the new one out, drawing the
  window it was about to leave, and never looked again after its first frame.
- **A linked crosshair was clamped into the window being left behind** when the
  window moved in the same pass, and stuck there — a chart still believes its
  old window until the next frame.
- **Reading a chart's window before its first frame threw** a
  `LateInitializationError` rather than answering null. A `KChartController`'s
  getters are reachable the moment it exists, which is before the chart it
  belongs to has been laid out — two linked charts hit this immediately, the
  first one's build asking the second where it was looking.

### Package

- The top-level `docs/` directory is now `doc/`, which is the layout pub
  expects. Nothing in the API moved, but a link to a page under `docs/` —
  a bookmark, or a README of your own — needs updating to `doc/`.
- `KChartHost` gained members: `chartCrosshairIndex`, `chartCrosshairPrice`,
  `chartPricePan`, `setChartPricePan`, and a `price` argument on
  `showChartCrosshair`. It is documented as an interface only `KChartWidget`
  implements, and nothing in this package or the example implements it
  otherwise — but if you had implemented it yourself, those are new members to
  fill in. `KChartController` is the supported way to drive a chart and gained
  only additions.

## 2.1.0

### Axes

- **Both axes now choose round values first and place them, rather than
  dividing the box into equal pixel bands and reading back whatever landed
  there.** The price scale reads `70000, 69500, 69000` where it used to read
  `70429, 69745, 69060`, and the date axis lands on `06:00, 12:00, 18:00`
  rather than on whichever candle fell on an evenly spaced pixel. The grid is
  ruled where the labels are, so a line and its number always agree.
- A logarithmic axis steps by ratio — 1, 2 and 5 times each power of ten — and
  a percentage axis picks round percentages and converts them back to prices.
  A range too narrow to hold a decade falls back to linear steps.
- Below a day, the date axis reads as a run of clock times with the date
  promoted where the day turns over, so an intraday chart shows where one
  session ends and the next begins. A custom `dateFormatter` or
  `ChartStyle.dateTimeFormat` still takes over completely.
- Date labels that would crowd into each other are dropped rather than printed
  over one another.
- Boundaries follow the clock the chart prints, not the underlying instant, so
  a `timeZoneOffset` of half an hour still labels round local times.
- New `niceTicks`, `niceLogTicks`, `niceStep`, `niceTimeStep`, `timeBucket` and
  `startsNewDay` carry the arithmetic, and are exported for a caller drawing
  an axis of its own alongside the chart.

### Replay

- **New `ChartReplayController` plays a chart back candle by candle.** Hand one
  to `KChartWidget.replay` and the chart draws only as far as its `position`,
  so the indicators, the now-price line and the legend know nothing the market
  had not shown yet. `start`, `stepForward`, `stepBack`, `play`, `pause`,
  `toggle`, `setInterval` and `stop` drive it, and it reports every move to its
  listeners so a transport bar can be built straight from it.

### Sessions and per-bar colour

- **New `KChartWidget.session` washes the extended hours.** A `TradingSession`
  says when the regular session opens and closes and which days it is kept on,
  read in the time zone the chart is showing, and the pre-market and after-hours
  stretches are washed behind the candles. A `close` at or before its `open` runs
  overnight, right down to Friday night belonging to Friday. Neighbouring candles
  outside the session are washed as one band, so a long overnight is one
  rectangle rather than a hundred. Coloured from
  `ChartColors.extendedHoursColor`.
- **New `KChartWidget.candleColor`** is asked about every candle, bar and column
  drawn — return a colour to use it, or null for the up or down colour it would
  have had. Anything the caller can work out can decide: a bar inside a session,
  one above an average, one that completes a pattern.
- `CandleEntity` is now exported, since a per-bar colour is asked about one.

### Price scale

- **New `PriceAxisScale.indexedTo100`** quotes the axis with the oldest candle
  in view at 100 — the same information a percentage axis gives, said the way an
  index is usually written. The axis marks round index levels and converts them
  back to the prices they stand for.
- **New `KChartWidget.invertPriceAxis`** runs the axis the other way, with higher
  prices lower down. Everything follows: the candles, the drawings, the
  crosshair, the orders and the comparisons all read off the same flipped axis,
  and a logarithmic axis inverts and stays logarithmic.
- **A candle's colour now comes from its prices rather than from its pixels**, so
  an inverted axis does not paint a rising candle as a falling one. The wick and
  the OHLC bar are drawn from sorted extents for the same reason.
- **New `showAverageClose`** draws a dashed level at the mean close of the
  visible window, coloured from `ChartColors.avgColor`, moving with the window
  since it describes what is on screen.
- **New `showHighLowOnAxis`** tags the window's high and low on the price axis,
  in whatever units the axis reads in — the leader lines say which candle, this
  says what level.

### Orders and positions

- **New `KChartWidget.orders` and `positions` draw what the account holds.** A
  `ChartOrder` rests at a price and a `ChartPosition` sits at its average entry,
  each drawn as a line the full width of the chart and tagged on the axis side —
  `Buy 0.5`, `Stop 2`, `Long 1.5  +812.4`. These are not drawings: they come
  from the venue, not the user, and are not saved with a layout.
- **Drag an order's line to amend it.** The line follows the pointer,
  `onOrderDragged` fires all the way so a readout can follow it, and
  `onOrderMoved` fires once on release. The chart never amends the order itself:
  it draws what it is handed, so the venue gets the last word.
  `ChartOrder.draggable` pins a line down, and an order with no `onOrderMoved`
  is not grabbable at all, so the gesture stays the chart's.
- New `onOrderTapped` and `onPositionTapped`, for a sheet or a menu of your own.
  A press that goes nowhere is reported as a tap rather than a move.
- New `TradeSide`, `OrderKind` and `TradingStyle`, the last held on
  `ChartStyle.trading`; new `ChartColors.buyColor`, `sellColor` and
  `tradeColor`.

### Indicator panes

- **A pane can be spaced by ratio or read as a percentage.** New
  `Indicator.scale` takes `IndicatorScale.linear` (the default),
  `.logarithmic` — for a pane whose interesting range covers orders of
  magnitude — or `.percentage`, which reads out the move away from the first
  value in view. Both rule and label the pane in their own space, so a log
  pane's marks land on 1, 2 and 5 times each power of ten, and a pane whose
  values reach zero falls back to linear rather than drawing nothing.
- **New `ChainedIndicator` computes one indicator over another's output.** The
  source's chosen line is handed on as flat candles, so anything that reads
  closes can be applied — an RSI of a MACD, a second smoothing of a signal
  line. The two warm-ups add up rather than the second starting from a guess,
  and the pane settings, guides, format and colours come from the applied
  indicator. `flattenToCandles` is exported for doing the wrapping by hand.
- **New `Indicator.alerts` and `KChartWidget.onIndicatorAlert`.** An indicator
  declares the levels worth watching — `IndicatorAlert(level: 70)`,
  `IndicatorAlert(level: 0, line: 2)` for a histogram — and the chart reports
  when the newest value crosses one, once per crossing. Overlays and panes are
  both watched.

### Event marks

- **New `KChartWidget.events` marks what happened to the instrument** under the
  candle it happened on: a small badge below the candle area, so it says when
  without covering the price. `ChartEventKind.earnings`, `.dividend`, `.split`,
  `.news` and `.custom` each carry a letter and a colour, and a `ChartEvent`'s
  own `label`, `color` and `icon` override any of it.
- Each event is matched to the candle nearest its time, so one stamped mid-bar
  marks the bar it fell in. `resolveEvents` is exported for working that out
  without a chart in hand.
- **New `onEventTapped`** reports a tapped badge, and a tap reaches the badges
  before it is read as a selection or a drawing point — they are small targets.
- New `ChartColors.eventColors` and `eventColor`, and
  `ChartStyle.eventMarkRadius` and `eventMarkGap`. A radius of zero draws
  nothing while leaving the events on the chart for a list of your own.

### The visible window

- **New `KChartController.visibleRange` says which candles are on screen**, as a
  `ChartVisibleRange`: the first and last index, their instants, how many
  candles and how long the window covers.
- **New `KChartWidget.onVisibleRangeChanged`** reports it whenever it changes —
  after the frame that changed it, and only when it is actually different, so
  scrolling within one candle says nothing. What a "bars on screen" readout, a
  linked second chart, or a feed that loads history on demand listens to.
- **New `showRange`, `showTimeRange`, `goToIndex`, `goToDate` and `fitAll`** move
  the window. `showRange` moves the zoom and the scroll together so the window
  holds exactly what was asked for, as near as the zoom limits allow;
  `goToIndex` and `goToDate` keep the zoom and only scroll, animated by default.
  Each reports whether it could move at all.
- `indexRangeCovering` and `indexNearest` are exported, for working out a window
  from a list of candles without a chart in hand.

### Chart types

- **Three new ways of drawing the candle area.** `ChartType.stepLine` holds each
  close flat until the next one, which is honest about a series only known at
  those instants; `ChartType.hlcArea` washes the high-low range in and draws the
  close through it; `ChartType.columns` draws a column per candle from the
  baseline to the close, up-coloured above it and down-coloured below.
- `ChartStyle.hlcAreaOpacity` sets how solid the HLC band is.
- An HLC area and a column chart both say something per bar, so they keep their
  indicator overlays, their legends and the high-low markers — where a line,
  area, step or baseline chart does not.

### Transformed candles

- **Four new transforms in `CandleTransforms`**, alongside Heikin-Ashi and
  Renko: `lineBreak` blocks price out by breaks, `kagi` runs a whole trend as
  one segment and turns on a retracement, `pointAndFigure` files the highs and
  lows into columns of boxes, and `rangeBars` cuts the move into equal
  distances. Each hands back plain candles at their own times, so the chart, the
  indicators and the drawing tools all work over them unchanged.
- `kagi` takes its reversal in price or, with `asPercent`, as a fraction of the
  extreme — which is the usual way to size one.
- `atrBrickSize` now sizes a brick, a box, a reversal or a range: the same
  average-true-range figure suits all of them.

### Comparing instruments

- **New `KChartWidget.comparisons` draws other instruments over the candles.**
  Each `ComparisonSeries` is a line, rebased by default so it starts where the
  main series does at the left edge of the window and diverges by how
  differently it moved — relative performance rather than price. Panning moves
  the pin with the window.
- `ComparisonScale.price` draws a comparison at its own prices on the same axis
  instead, for two instruments quoted in the same units.
- Points are matched to candles by time, not by position, so a compared
  instrument on a different bar lines up: each candle takes the last point at or
  before its own time. A gap breaks the line; candles before the comparison
  starts draw nothing.
- The price scale opens up to hold whatever a comparison does, and each reads
  out its own move as a percentage on a legend row of its own.
- New `ChartColors.comparisonColors` and `getComparisonColor` — a palette kept
  apart from the moving-average colours, so a compared line is never mistaken
  for an overlay.
- `ComparisonSeries.ofCandles` builds one from another instrument's candles, and
  `alignComparison`, `comparisonAnchor`, `comparisonPriceAt` and
  `resolveComparisons` are exported for a caller drawing its own.

### The right-click menu

- **New right-click menu, on the chart and on any drawing.** A drawing offers
  its coordinates, duplicate, copy, bring-to-front, send-to-back, lock, hide,
  its alert where it has one, and delete — applied to the whole selection where
  there is one. Empty chart offers paste, select all, fit the price scale,
  scroll to the newest candle, undo, redo and clear. Right-clicking a drawing
  selects it first, so what the menu is about and what the chart highlights
  agree.
- `KChartWidget.showContextMenu` turns it off, and `contextMenuBuilder` is
  handed the drawing, the candle, the price and the entries the chart would have
  shown, so an item of your own is one line — or a menu entirely of your own.
- New `ChartMenuItem`, `ChartMenuDivider`, `ChartMenuRequest`,
  `ChartMenuBuilder` and `showChartMenu`, the last of which opens the same menu
  from your own button.

### Drawing UX

- **Several drawings can be selected at once.** Shift- or ⌘-click adds to the
  selection instead of replacing it, and ⌘A takes everything drawn. Dragging one
  moves them all, Delete removes them in a single undoable step, and an edit made
  through the line editor is copied onto the rest — which is what a user who
  selected five lines to recolour meant. The editor says how many it is editing.
- `ChartDrawingController` gained `selection`, `selectionLength`,
  `hasMultipleSelected`, `isSelected`, `selectMany`, `selectAll`,
  `addToSelection`, `removeFromSelection`, `toggleSelection`, `clearSelection`
  and `removeAll`. `selected` still means the one the editor is open on, so
  existing code is unaffected.
- **Copy, paste and duplicate**: ⌘C, ⌘V and ⌘D, each landing the copy a few
  candles clear of the original rather than exactly on top of it. New
  `copyToClipboard`, `canPaste`, `clipboardLength`, `clearClipboard`, `paste`
  and `duplicate` on the controller, and `copySelection`, `pasteDrawings` and
  `duplicateSelection` on the chart.
- **Stacking order**: ⌘] and ⌘[ walk the selection through the stack, ⇧⌘] and
  ⇧⌘[ take it all the way. New `bringToFront`, `sendToBack`, `bringForward`,
  `sendBackward` and `indexOf` on the controller, `moveToFront`, `moveToBack`,
  `moveForward`, `moveBackward` and `indexOf` on `ChartDrawings`, and arrows on
  each row of the drawing manager.
- **Saving an edit no longer restacks the drawing it edited.**
  `ChartDrawings.save` used to move a known drawing to the end of the list, so
  recolouring a line quietly lifted it over everything drawn after it. It now
  leaves it where it is.
- **New `DrawingTemplate`** is one drawing's look — colour, thickness, stroke,
  fill and label visibility — saved so it can be put on another, whatever kind
  either of them is. The controller keeps them by name: `saveTemplate`,
  `putTemplate`, `applyTemplate`, `removeTemplate`, `templates`,
  `templatesToJson` and `loadTemplates`.
- **New coordinates dialog.** The editor's ruler button opens a form over the
  selected drawing's anchors — a price and a candle apiece — so a level placed by
  hand can be typed in exactly. `KChartWidget.showDrawingCoordinates` turns the
  button off, `showDrawingCoordinatesDialog` opens it from your own code, and
  `drawingAnchors`, `setDrawingAnchor` and `drawingAnchorsAreEditable` read and
  write any drawing's anchors generically.
- **Alerts are no longer only for horizontal levels.** New `AlertingDrawing` is
  mixed into `HorizontalLine`, `TrendLine`, `ParallelChannel` and
  `FibRetracement`, each answering `alertLevelsAt` for the levels it has at one
  instant — so a sloping line is watched where it is now, and a retracement at
  every one of its steps. New `KChartWidget.onDrawingAlert` reports the drawing,
  the candle and the price crossed; `onAlertCrossed` still fires for horizontal
  levels, so existing code is unaffected. The editor's bell button now appears
  for all of them.
- `TwoPointDrawing.priceOnLineAt` carries the "where is the line at this
  instant" arithmetic that a trend line, a channel and an alert all need.
- The drawing manager's rows offer duplicate and restack buttons, and answer to
  shift- and ⌘-click the same way the chart does. `showStackingControls` turns
  the arrows off.

### Drawing tools

- **Thirteen new tools, taking the set from 16 to 29.** `pitchfork`, `gannFan`,
  `gannBox`, `fibExtension`, `fibFan`, `fibTimeZones`, `regressionTrend`,
  `xabcd`, `priceRange`, `dateRange`, `callout`, `path` and `flag` join the
  `DrawingTool` enum, each with its own drawing class, its hit test, its drag
  handles and its place in the saved layout.
- **New `MultiPointDrawing` holds its anchors in a list** rather than in
  numbered fields, which is what a five-point harmonic pattern and an
  as-many-as-you-tap path need. `XabcdDrawing` and `PathDrawing` are built on
  it, and one of your own can be too.
- A shape with no fixed number of points is finished by the user: tap twice in
  the same place, or pick another tool — switching tools now finishes an open
  path instead of throwing it away.
- `RegressionChannel` fits a least-squares line through the closes of every
  candle its anchors span, with a band at `deviations` standard deviations
  either side, and refits whenever an anchor moves. The arithmetic is exported
  as `fitRegression`.
- `PitchforkDrawing` draws Andrews', Schiff and modified-Schiff forks, with a
  tine per level. `GannFan` runs Gann's angles off a `1×1`, and `GannBox` rules
  a range at the same fractions across and down. `FibFan`, `FibTimeZones` and
  `FibExtension` cover the three Fibonacci tools that were missing.
- `PriceRangeDrawing` and `DateRangeDrawing` read out one axis each, where a
  measurement reads both. `CalloutDrawing` puts a note in a box with a tail
  back to the candle it is about, and `FlagDrawing` plants a pennant on one
  candle.
- New `shape_geometry.dart` carries the fan, box and fork arithmetic, so the
  painter and the hit test read the same geometry rather than each doing it
  their own way.
- `DrawingTranslations` gained a name for every new shape, and `ChartDrawings`
  a getter — `pitchforks`, `gannFans`, `gannBoxes`, `fibExtensions`, `fibFans`,
  `fibTimeZones`, `regressions`, `xabcds`, `priceRanges`, `dateRanges`,
  `callouts`, `paths`, `flags`.

### Indicators

- **New `VolumeProfileIndicator` gathers volume by price rather than by time.**
  The bars run back from the labelled side of the chart, one per price band, so
  the prices the market actually traded at read off the same axis as the
  candles. The busiest band — the point of control — is picked out, the value
  area around it is shaded, and each band is split into the volume that rose
  and the volume that fell. Colours come from `ChartColors.profileUpColor`,
  `profileDownColor`, `profilePocColor` and `profileValueAreaColor`.
- **New `PivotPointsIndicator` steps the previous session's pivot, three
  supports and three resistances across the current one.** `PivotMethod.standard`,
  `.fibonacci` and `.camarilla` space the levels differently, and new
  `PivotSession.day`, `.week`, `.month` and `.year` say what counts as a
  session.
- **New `AnchoredVwapIndicator` measures VWAP from one candle onwards** instead
  of over the whole series, so it can be anchored to a high, a low, an earnings
  date or the start of a session. It says nothing before its anchor.
- An indicator can now return an `IndicatorProfile` of `ProfileBin`s from
  `computeProfile`, drawn as horizontal bars across the candles. Nothing but
  the volume profile uses it yet, but a delta or time profile would draw the
  same way.
- The three of them are in `indicatorCatalog` as `VP`, `PIVOT`, `PIVOTFIB`,
  `PIVOTCAM`, `PIVOTW` and `AVWAP`, so the demo's picker offers them with their
  settings. A pivot indicator's name carries its session — `PIVOTW`, `PIVOTM`,
  `PIVOTY` — so a weekly pivot and a daily one are told apart when a layout is
  saved and restored.

### Price scale

- **The price axis can be dragged.** It fitted the window and nothing else
  before, so there was no way to look closer at a quiet stretch. Dragging down
  the strip the price labels sit in now stretches the range and makes the
  candles taller, dragging up compresses it, a vertical drag on the candles
  slides a held window, and a double-tap on the labels fits it back. New
  `KChartWidget.priceScaleDrag` turns it off, and
  `ChartStyle.priceScaleGripWidth` sets how far in from the labelled side the
  strip reaches.
- `KChartController` gained `priceZoom`, `setPriceZoom`, `stretchPrice`,
  `compressPrice` and `resetPriceScale`, so a toolbar can do the same.

### Panes

- Indicator panes are ruled and labelled at round values instead of showing
  only their highest and lowest. Three ATRs at three periods can now be read
  against each other rather than being three unlabelled squiggles. A pane with
  a range of its own — RSI, KDJ, WR — is still marked by its guides.
- The MACD and Awesome Oscillator panes draw their zero line. The histogram
  changes colour across it, and until now that axis was invisible.
- The volume pane marks a round level part-way up, so a bar can be read against
  something.

### Fixed

- `NumberUtil.format` printed a whole number as `200.200`, reusing the integer
  digits as the fraction. It now pads, giving `200.00`.
- An order or position tag printed a size or an unrealised P&L at a double's
  full precision — `Long 1  +1415.882446718504` — which ran off the end of the
  tag it was drawn in. It is cut to two decimals now, with nothing trailing.

### Theming

- New `ChartColors.gridColumnColor` for the vertical grid lines, which default
  to a lighter shade of `gridColor`. A chart is read across price far more than
  across time, so the time columns now sit behind the price rows.

### Painters

- `BaseChartRenderer.drawGrid` takes a new optional `columnXs`, the shared x of
  every time tick, so all the panes rule themselves on the same columns. Only
  code that subclasses a renderer directly is affected.

### API

- `DrawingToolbar` is exported. It was always documented as the editor a caller
  could put over its own chart surface, but there was no way to import it.
- `ChartStyle.gridRows` and `gridColumns` are documented. Neither is a count of
  lines any more: each is how densely the axis is labelled, and about half as
  many round values as `gridRows` land inside a window.

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
