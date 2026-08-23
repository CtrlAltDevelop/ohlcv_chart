# ohlcv_chart

A candlestick (K-line) and market-depth chart for Flutter, drawn entirely with
`CustomPainter` — no WebView, no JavaScript bridge.

Named for the open-high-low-close-volume bars it renders.

![Candles with moving averages, volume and MACD](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/candles.png)

## Features

- **Five chart types** — candles, OHLC bars, a line, a filled area and a baseline chart — plus Heikin-Ashi and Renko as transforms of the candles themselves.
- **29 indicators**, each a configured instance rather than a flag — so `ATR(8)`, `ATR(14)` and `ATR(20)` are three panes, with their own settings and colours.
- **Main-chart overlays** — `MA`, `EMA`, `BOLL`, `SAR`, `VWAP` and anchored `VWAP`, Supertrend, Keltner and Donchian channels, the Ichimoku Cloud, pivot points and a volume profile.
- **Swing readers** — a zigzag through the swing highs and lows, Fibonacci retracement of the last swing, and Elliott wave labels, all sized to the market by default.
- **Sub-charts** — `MACD`, `KDJ`, `RSI`, `WR`, `CCI`, `ATR`, `OBV`, `MFI`, `DMI`, Stochastic RSI, `ROC`, `TRIX`, a volume average and the Awesome oscillator, each in its own stacked pane — resizable and reorderable by dragging.
- **Linear, logarithmic or percentage price axis**, so a decade of compounding reads as well as an afternoon.
- **A price scale you can drag** — pull the labels to stretch or flatten the candles, drag the chart to slide the window, double-tap to fit it back; from code as well, through the controller.
- **Axes that read as round numbers** — both axes choose their values first and are ruled where the labels fall, so a price scale steps `69000, 69500, 70000` and an intraday date axis lands on the hour, never on whatever value happened to fall on an evenly spaced pixel.
- **29 drawing tools** — levels and rays, trend lines, arrows, extended lines, boxes, ellipses, triangles, parallel channels, pitchforks, Gann fans and boxes, four Fibonacci tools, a regression trend with its bands, XABCD patterns, multi-leg paths, price and date brackets, a measuring tool, planned positions with their risk-to-reward, notes, callouts, flags and freehand strokes; each placed by tap or drag, then dragged, locked, hidden and removed.
- **A line editor** that opens on selection: colour, opacity, thickness, solid/dashed/dotted stroke, fill, label text and visibility, alerts, lock and delete — every option list, control and pixel of it configurable through `DrawingStyle`.
- **Undo and redo**, through a `ChartDrawingController` that owns the drawings and their history, with ⌘Z, ⇧⌘Z and Delete on the chart itself.
- **A layout that persists** — every drawing serialises, so `jsonEncode(drawings.toJson())` and `ChartDrawings.fromJson` are the whole story.
- **A drawing manager** — a ready-made panel listing what is drawn, with show/hide, lock, delete, undo, redo and clear.
- **Price alerts** on a level, reported when the market crosses it.
- **Crosshair on hover** and an **OHLC legend** above the chart, which is how a chart reads on a desktop.
- **Driven from your own code** — `KChartController` zooms, scrolls back to the live candle and hands you the chart as a PNG.
- **Bar replay** — rewind to any candle and step or play the market forward, with the indicators only knowing what has arrived.
- **Buy/sell signal markers** pinned to candles.
- **Depth chart** — a separate `DepthChart` widget for the order book, drawn as the cumulative curve, a per-rung histogram, both at once, or a numeric ladder of price, size and running total, on a linear, log or percentage axis and zoomable to the levels around the mid.
- **Info dialog** on long press, either the built-in Material popup or your own builder.
- **"Now price" line** with a live countdown to the close of the current candle.
- **Session dividers and a display time zone**, so an intraday chart breaks where the trader's day does.
- **SVG watermark** loaded from an asset path you supply.
- **Fully themeable** — `ChartStyle` for geometry, `ChartColors` for every colour, `DrawingStyle` for the drawing tools; `ChartTranslations` for every label. Filled or hollow candles, dashed or solid crosshair, pane separators, axis-label pills and a placed, tinted watermark.
- **Fits its box** — the candles take whatever height the volume and indicator panes leave, so the chart works from a phone to a desktop window without arithmetic on your side.

## Contents

- [Candlestick chart](#candlestick-chart) · [Indicators](#indicators)
- [Chart types](#chart-types) · [Price axis](#price-axis) ·
  [The date axis](#the-date-axis) ·
  [The legend and the crosshair](#the-legend-and-the-crosshair)
- [Drawing tools](#drawing-tools) — [what can be drawn](#what-can-be-drawn),
  [persisting a layout](#persisting-a-layout),
  [undo and redo](#undo-redo-and-the-drawing-controller),
  [the drawing manager](#the-drawing-manager), [level alerts](#level-alerts)
- [Customising the line editor](#customising-the-line-editor) ·
  [The long-press readout](#the-long-press-readout)
- [Driving the chart](#driving-the-chart) · [Panes](#panes) ·
  [Bar replay](#bar-replay) · [Sessions and time zones](#sessions-and-time-zones)
- [Depth chart](#depth-chart) · [Theming](#theming) · [Sizing](#sizing)
- [Migrating from 1.x](#migrating-from-1x)

## Install

```yaml
dependencies:
  ohlcv_chart: ^2.0.0
```

## Usage

### Candlestick chart

Feed it a `List<KLineEntity>`. Indicator values are computed in place by
`DataUtil.calculate` before the first paint, and again whenever new candles arrive:

```dart
import 'package:ohlcv_chart/ohlcv_chart.dart';

DataUtil.calculate(candles);

KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: false,
  watermarkAssetPath: 'assets/logo.svg',
  timeFrame: const Duration(minutes: 15),
  indicators: [MaIndicator(period: 20), BollIndicator(), MacdIndicator()],
  timeFormat: TimeFormat.YEAR_MONTH_DAY_WITH_HOUR,
  fixedLength: 2,
  onLoadMore: (isRight) {
    if (!isRight) fetchOlderCandles();
  },
);
```

`KLineEntity.fromJson` accepts the usual OHLCV shape (`open`, `high`, `low`,
`close`, `vol`, `time`/`id`), or build the entity directly.

### Indicators

Indicators are instances, not flags: pass as many as you like to `indicators`,
including several of the same kind with different settings. Overlays draw over
the candles; everything else takes a pane of its own, stacked in the order given.

```dart
KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: false,
  watermarkAssetPath: 'assets/logo.svg',
  timeFrame: const Duration(minutes: 15),
  indicators: [
    MaIndicator(period: 7),
    MaIndicator(period: 25),
    MaIndicator(period: 99, color: Colors.amber),
    AtrIndicator(period: 8),
    AtrIndicator(period: 14),
    AtrIndicator(period: 20),
  ],
);
```

![The Ichimoku cloud and Supertrend, over Stochastic RSI and the Awesome oscillator](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/overlays.png)

| Overlay | Settings |
| --- | --- |
| `MaIndicator` | `period` — the simple moving average |
| `EmaIndicator` | `period` |
| `BollIndicator` | `period`, `deviations` |
| `SarIndicator` | `start`, `step`, `maximum` |
| `VwapIndicator` | — |
| `AnchoredVwapIndicator` | `anchor` — the candle it measures from |
| `PivotPointsIndicator` | `method`, `session`; the pivot with three supports and resistances |
| `VolumeProfileIndicator` | `bins`, `valueArea`; volume by price, drawn back from the axis |
| `SupertrendIndicator` | `period`, `multiplier`; flips colour with the trend |
| `KeltnerIndicator` | `period`, `atrPeriod`, `multiplier` |
| `DonchianIndicator` | `period` |
| `IchimokuIndicator` | `conversionPeriod`, `basePeriod`, `spanPeriod`, `displacement`; the cloud is shaded |
| `ZigZagIndicator` | `depth` — the swing size, in percent |
| `FibonacciIndicator` | `depth`, `ratios`; retraces the last swing |
| `ElliottWaveIndicator` | `depth`; labels the swings `1`–`5`, `A`–`C` |

| Pane | Settings |
| --- | --- |
| `MacdIndicator` | `fast`, `slow`, `signal` |
| `KdjIndicator` | `period`, `kSmoothing`, `dSmoothing` |
| `RsiIndicator` | `period`, with 30/50/70 guides |
| `WrIndicator` | `period` |
| `CciIndicator` | `period` |
| `AtrIndicator` | `period` |
| `ObvIndicator` | — |
| `MfiIndicator` | `period`, with 20/80 guides |
| `DmiIndicator` | `period`, with the 20 guide |
| `StochRsiIndicator` | `rsiPeriod`, `period`, `kSmoothing`, `dSmoothing`, with 20/80 guides |
| `RocIndicator` | `period` |
| `TrixIndicator` | `period`, `signalPeriod` |
| `VolumeMaIndicator` | `period` |
| `AwesomeIndicator` | `fast`, `slow` |

![A zigzag, Fibonacci retracement and Elliott wave labels](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/swings.png)

Three of the overlays read the market's swings rather than a fixed window, all
from the same `depth` — the percentage move that ends a swing:
`ZigZagIndicator` draws the legs, `FibonacciIndicator` retraces the last one,
and `ElliottWaveIndicator` counts them. Left at its default of `0`, `depth`
is sized from the candles — a fixed percentage that gives several swings on a
volatile daily chart finds none at all on a quiet intraday one — and the label
reads `auto`. Pass a positive number to set the threshold yourself. The wave count is a reading of the
swings, not a rules-checked Elliott count; treat it as a sketch to confirm by
eye.

`IchimokuIndicator` shifts its spans forward and its lagging line back as the
indicator is drawn. The chart holds one value per candle, so the stretch of
cloud that would project past the newest candle is not drawn.

##### Levels and profiles

Three overlays read price rather than a window of it.

`VolumeProfileIndicator` gathers the visible volume into `bins` price bands and
draws them as horizontal bars running in from the side the price labels are not
on, so the prices the market actually traded at read off the same axis as the
candles. The busiest band — the point of control — is drawn whole in its own
colour, the `valueArea` around it is washed across the width, and every other
band is split into the volume that traded on rising candles and the volume that
traded on falling ones. A candle's volume is spread evenly over the bands its
range covers, which is as much as OHLCV can say; the ticks inside the candle
are not known. `ChartColors.profileUpColor`, `profileDownColor`,
`profilePocColor` and `profileValueAreaColor` colour it, `profileColor` sets
one colour for the lot, and `ChartStyle.profileWidth` — a fraction of the
chart's width — sizes the busiest bar.

`PivotPointsIndicator` works out the previous session's pivot and steps it,
with three supports and three resistances, across the current one.
`PivotMethod.standard`, `.fibonacci` and `.camarilla` space the levels
differently, and `PivotSession.day`, `.week`, `.month` and `.year` say what
counts as a session, so an intraday chart can pivot off the week instead of the
day it opened in.

`AnchoredVwapIndicator` is a VWAP measured from one candle onwards rather than
over the whole series, so it can be anchored to a high, a low, an earnings date
or the open of a session. It says nothing before its `anchor`.

```dart
KChartWidget(
  data,
  ChartColors(),
  indicators: [
    VolumeProfileIndicator(bins: 32, valueArea: 0.7),
    PivotPointsIndicator(method: PivotMethod.fibonacci),
    AnchoredVwapIndicator(anchor: swingLow),
  ],
);
```

An indicator of your own can draw a profile too: return an `IndicatorProfile`
of `ProfileBin`s from `computeProfile` and the chart draws the bars, picks out
the busiest band and shades the value area. A delta or time profile is the same
shape of answer.

#### Custom indicators

Subclass `Indicator` — give it a `label`, its `lines`, the `settings` that make
it distinct and a `compute` — and the chart scales, draws, legends and labels it
like a built-in one. Lines are drawn as a stroke, dots, a histogram, a
`pivotLine` (straight across the candles with no value, which is what a zigzag
needs) or `markers` (a dot with your own text beside it). `fills` shades the area
between two lines, and `colorForPoint` colours a single point — how the
Supertrend changes colour at a reversal.

![Three ATRs at different periods, each in its own pane](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/panes.png)

The same kind of indicator, three times over, is the point of the list: each
instance carries its own settings and colours.

#### Colours

Every indicator takes its colours from `ChartColors`, and a `color` (or
`colors`, for the multi-line ones) argument overrides that per instance:

```dart
indicators: [
  MaIndicator(period: 20, color: Colors.amber),
  MacdIndicator(colors: [Colors.grey, Colors.blue, Colors.orange]),
],
```

Repeated indicators of one kind take successive theme colours, so three moving
averages are three different colours without being told.

#### Adding and editing at runtime

An indicator is identified by its type and settings — colours are deliberately
left out — so `upsert` restyles the one already on the chart instead of stacking
a duplicate:

```dart
final indicators = <Indicator>[MaIndicator(period: 20)];

indicators.upsert(AtrIndicator(period: 14));                    // added
indicators.upsert(AtrIndicator(period: 14, color: Colors.red)); // recoloured
indicators.upsert(AtrIndicator(period: 20));                    // a second pane
indicators.toggle(RsiIndicator());                              // on, then off
```

#### Building a settings UI

![The example app's add-indicator sheet, built from the catalog](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/indicator-settings.png)

`indicatorCatalog` describes every indicator — its settings, their ranges and
its colour slots — so an "add indicator" sheet can be driven by data rather than
a hard-coded list. The example app's `IndicatorSheet` is built entirely from it:

```dart
final type = indicatorCatalog.firstWhere((t) => t.name == 'ATR');

for (final setting in type.settings) {
  print('${setting.label}: ${setting.defaultValue} '
      '(${setting.min}–${setting.max})');
}

// What the colour pickers should show, per line.
final labels = type.lineLabels();                     // ['ATR']
final defaults = type.defaultColors(ChartColors());   // theme colours

// Build one from the user's choices.
final indicator = type.create(
  values: {'period': 8},
  colors: [Colors.purple],
);

// And read an existing one back into the form.
final values = indicatorTypeOf(indicator)?.valuesOf(indicator); // {'period': 8}
```

`DataUtil.calculate` still fills the indicator fields on each `KLineEntity`,
which the long-press readout uses; the indicators themselves compute their own
values from the candles.

### Chart types

`chartType` decides what the candle area draws:

```dart
KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: false,
  watermarkAssetPath: 'assets/logo.svg',
  timeFrame: const Duration(minutes: 15),
  chartType: ChartType.bars,       // candles, bars, line, area, baseline
  baselinePrice: 42_000,           // baseline only; defaults to the oldest close in view
);
```

| `ChartType` | Draws |
| --- | --- |
| `candles` | a filled or hollow body with a wick — the default |
| `bars` | the high-low range, open ticked left and close ticked right |
| `line` | a line through the closes |
| `area` | the same line with the area beneath it washed in |
| `baseline` | the line washed towards a level, up-coloured above it and down-coloured below |

`isLine: true` still means `ChartType.area`, so nothing written against the older
API changes behaviour.

#### Heikin-Ashi and Renko

Both rewrite the candles rather than the way they are drawn, so they are
transforms rather than chart types. Run the list through `CandleTransforms` and
recompute the indicators over the result:

```dart
final ha = CandleTransforms.heikinAshi(candles);
DataUtil.calculate(ha);

final bricks = CandleTransforms.renko(
  candles,
  brickSize: CandleTransforms.atrBrickSize(candles) ?? 25,
);
DataUtil.calculate(bricks);

KChartWidget(ha, ChartColors(), /* … */);
```

Heikin-Ashi keeps one candle per candle, at the same times, so anything drawn on
the chart stays where it was. Renko throws time away between bricks: a brick is
laid every whole `brickSize` beyond the last, a reversal costs two bricks, and
each brick carries the volume of the candles it covers. `atrBrickSize` sizes a
brick from the market's own average true range, which is the usual way to pick
one.

### Price axis

```dart
KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: false,
  watermarkAssetPath: 'assets/logo.svg',
  timeFrame: const Duration(days: 1),
  priceAxisScale: PriceAxisScale.logarithmic,
);
```

- `linear` — equal prices take equal space. The default.
- `logarithmic` — equal *ratios* take equal space, so 10 → 20 covers as much of
  the axis as 100 → 200. A window whose low is zero or negative has no logarithm
  to space by and falls back to linear until it scrolls back into positive
  prices.
- `percentage` — spaced linearly, but the axis, the crosshair's price label and
  the current-price tag read as the move away from the oldest candle in view.

The volume and indicator panes always stay linear.

The axis picks round values and the grid is ruled where they land, so a label
and its line always agree. A linear axis steps by 1, 2, 2.5 or 5 times a power
of ten; a logarithmic one steps by ratio — 1, 2 and 5 through each power of ten
— falling back to linear steps over a range too narrow to hold a decade; a
percentage axis chooses round percentages and converts them back to prices.

`ChartStyle.gridRows` is how densely that happens. It is not a row count: about
half as many round values as `gridRows` land inside the window, so raise it for
a denser axis and lower it for a sparser one.

```dart
KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: false,
  watermarkAssetPath: 'assets/logo.svg',
  timeFrame: const Duration(days: 1),
  chartStyle: const ChartStyle(gridRows: 12),
);
```

The same arithmetic is exported, for a caller drawing an axis of its own beside
the chart: `niceStep`, `niceTicks` and `niceLogTicks` for values, `niceTimeStep`,
`timeBucket` and `startsNewDay` for times.

#### Dragging the scale

The axis fits the window by default, so the candles always fill the height —
which is what you want until you want to look closer. Dragging down the strip
the price labels sit in stretches the range and makes the candles taller;
dragging up compresses it. Once the scale is being held that way, a vertical
drag anywhere on the candles slides the window up and down, and a double-tap on
the labels hands the axis back to the chart.

```dart
KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: false,
  watermarkAssetPath: 'assets/logo.svg',
  timeFrame: const Duration(days: 1),
  controller: chart,
  priceScaleDrag: true,
  chartStyle: const ChartStyle(priceScaleGripWidth: 52),
);
```

`priceScaleGripWidth` is how far in from the labelled side that strip reaches,
and it is never more than half the chart. A drag through it still scrolls the
chart sideways, a tap still selects what is under it, and while a drawing tool
is armed it steps aside completely — so a line can still be placed against the
axis.

The same three moves are on the controller, for a chart driven from a toolbar:

```dart
chart.stretchPrice();     // taller candles, as dragging down does
chart.compressPrice();    // flatter ones
chart.setPriceZoom(2.5);  // or straight to a factor
chart.resetPriceScale();  // back to fitting the window
chart.priceZoom;          // 1 while the chart is fitting it itself
```

Set `priceScaleDrag: false` to keep the axis fitted to the window whatever the
user does, which is the older behaviour.

### The date axis

The date axis is chosen the same way. Above a day it lands on round dates; below
one it reads as a run of clock times — `06:00, 12:00, 18:00` — with the date
promoted where the day turns over, so an intraday chart shows where one session
ends and the next begins. Labels that would crowd into each other are dropped
rather than printed over one another, and the boundaries follow the clock the
chart prints: a `timeZoneOffset` of half an hour still labels round local times.

`ChartStyle.gridColumns` sets the density, read like `gridRows`. Formatting can
be taken over completely — `ChartStyle.dateTimeFormat` for a fixed pattern, or
`dateFormatter` for full control, which is handed each candle along with a flag
marking the long form the crosshair wants:

```dart
KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: false,
  watermarkAssetPath: 'assets/logo.svg',
  timeFrame: const Duration(minutes: 15),
  dateFormatter: (candle, longForm) => DateFormat(
    longForm ? 'EEE d MMM HH:mm' : 'HH:mm',
  ).format(DateTime.fromMillisecondsSinceEpoch(candle.time!)),
  xFrontPadding: 120,
);
```

`xFrontPadding` is the empty space kept to the right of the newest candle — room
for the "now price" tag and its countdown, and for a level drawn just ahead of
the market.

### The legend and the crosshair

With a mouse, the crosshair follows the pointer without waiting for a press —
that is `crosshairOnHover`, on by default and irrelevant to a touch screen, which
has nothing that hovers. The values then belong above the chart rather than in a
popup, which is what `showOhlcLegend` draws: date, open, high, low, close, the
move over the candle and its volume, on a legend row of its own above the
indicator legends, worded by `ChartTranslations`.

```dart
KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: false,
  watermarkAssetPath: 'assets/logo.svg',
  timeFrame: const Duration(minutes: 15),
  showOhlcLegend: true,
  crosshairOnHover: true,
);
```

The long-press readout is unchanged, and still opens on a press or — with
`isTapShowInfoDialog` — a tap.

### Drawing tools

![The line editor open on a selected line](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/line-editor.png)

Selecting a drawn line opens the editor over the chart: colour, thickness,
stroke style, label text and visibility, lock and delete.

![Trend and horizontal lines with labels](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/drawing.png)

Set `currentDrawingTool` to put the chart into placement mode and handle the
callbacks to persist what the user draws. The per-kind lists below are the
original API and still work; a `drawingController` — see
[Undo, redo and the drawing controller](#undo-redo-and-the-drawing-controller) —
owns the whole layout for you instead, and `drawings:` takes drawings of any
kind, which is where the later ones live:

```dart
KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: true,
  watermarkAssetPath: 'assets/logo.svg',
  timeFrame: const Duration(minutes: 15),
  currentDrawingTool: DrawingTool.trend,
  trendLines: savedTrendLines,
  horizontalLines: savedHorizontalLines,
  verticalLines: savedVerticalLines,
  rectangles: savedRectangles,
  fibRetracements: savedFibRetracements,
  drawings: savedMeasuresChannelsAndNotes,
  onAddTrendLine: repository.save,
  onRemoveTrendLine: repository.delete,
  // Fires for every kind, and is the only report for the later ones.
  onAddDrawing: repository.save,
  onRemoveDrawing: repository.delete,
);
```

Placement works the way a charting desk expects. A horizontal or vertical line
lands with a single tap. A trend line takes one tap per end: tap its start, move,
and tap again to finish — the line rubber-bands along with the pointer in
between. Pressing and dragging from one end to the other still draws a line in
one gesture, on a touch screen as much as with a mouse. Escape abandons a line
that is half-placed, as does tapping outside the chart or switching tools, and
the line editor stays out of the way until the line is finished.

With `magnetMode: true`, each point placed snaps to the nearest open, high, low
or close within `DrawingStyle.magnetSnapDistance` pixels, and lands wherever the
pointer is when nothing is that close.

#### What can be drawn

![A ray, an arrow, a horizontal ray, a range box and a Fibonacci retracement](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/shapes.png)

| `DrawingTool` | Taps | Draws |
| --- | --- | --- |
| `horizontal` | 1 | a level across the whole chart |
| `horizontalRay` | 1 | a level that only applies from that candle rightwards |
| `vertical` | 1 | a line marking one candle |
| `text` | 1 | a note pinned to a point, ready to be typed into |
| `trend` | 2 | a segment between two anchors |
| `ray` | 2 | a segment that carries on past its second anchor |
| `extendedLine` | 2 | a segment that carries on past both anchors |
| `arrow` | 2 | a segment with an arrowhead on its far end |
| `rectangle` | 2 | a box between two opposite corners |
| `ellipse` | 2 | an ellipse inscribed in that box |
| `fibRetracement` | 2 | the levels of a swing, labelled and banded |
| `measure` | 2 | a ruler: the move in price, in percent, in candles and in time |
| `triangle` | 3 | a triangle over three corners |
| `channel` | 3 | a base line and a parallel through the third point |
| `position` | 3 | entry, target and stop, with the risk-to-reward worked out |
| `brush` | drag | a freehand stroke |
| `flag` | 1 | a pennant planted on one candle |
| `gannFan` | 2 | rays at Gann's angles, `1×1` through `1×8` and `8×1` |
| `gannBox` | 2 | a box ruled at the same fractions across and down |
| `fibFan` | 2 | rays at the Fibonacci fractions of a swing |
| `fibTimeZones` | 2 | verticals at Fibonacci multiples of a span |
| `regressionTrend` | 2 | the least-squares fit through the candles between, with bands |
| `priceRange` | 2 | a bracket over a price move, in price and percent |
| `dateRange` | 2 | a bracket under a span, in candles and in time |
| `callout` | 2 | a note in a box, with a tail pointing at a candle |
| `pitchfork` | 3 | a median line and its tines, from three swings |
| `fibExtension` | 3 | an impulse projected on from where the retracement ended |
| `xabcd` | 5 | a harmonic pattern, each leg labelled with its retracement |
| `path` | many | straight legs through as many points as are tapped |

The three trend variants are all `TrendLine`s: `extend` (`LineExtension.none`,
`.right`, `.both`) decides how far past its anchors the line runs, and `arrow`
puts a head on the far end, so a ray persisted by an older version of the app
still loads. `HorizontalLine.startTime` is what makes a level a ray. Rectangles
and retracements are their own types, `RectangleDrawing` and `FibRetracement`,
passed in `rectangles` and `fibRetracements` and reported through
`onAddRectangle` / `onRemoveRectangle` and `onAddFibRetracement` /
`onRemoveFibRetracement`.

Every two-point drawing shares one base, `TwoPointDrawing`: two (time, price)
anchors, either of which can be dragged, plus `isComplete` — false while the
second point is still following the pointer.

`xabcd` and `path` are `MultiPointDrawing`s instead: their anchors live in a
`points` list rather than in numbered fields, which is what lets a path take as
many as it is given. Each tap lands a leg. A pattern finishes when its five
points are in; a path has no count to finish on, so it ends when you tap twice
in the same place, or when the tool is disarmed — switching tools finishes an
open path rather than throwing it away.

##### Fans, forks and fits

`GannFan`'s second anchor places the `1×1` — one unit of price against one unit
of time — and `ratios` multiplies that slope for the rest of the fan, so `2` is
the `1×2` and `0.5` the `2×1`. `GannBox` divides a range by its own proportions
instead: `ratios` are taken as fractions of the box both ways, so the
horizontals mark those fractions of the price range and the verticals the same
fractions of the span.

`FibFan` spreads rays between the flat `0` and the diagonal `1` of a swing —
support that slopes with time, where a retracement's is level.
`FibTimeZones` reads the other axis: the two anchors set one unit of time and
each level marks that many units on, so a swing that took ten candles projects
lines at 10, 20, 30, 50 and 80. `FibExtension` is the trend-based one: the
first two anchors are the impulse, the third is where the retracement ended,
and the levels are projected on from there rather than drawn between the
anchors.

`PitchforkDrawing` takes a pivot and the swing either side of it. The median
runs through the midpoint of the swing and each level draws a tine parallel to
it — `1` being the tines through the anchors themselves, `0` the median.
`PitchforkKind.andrews` leaves the handle on the pivot, `.schiff` lifts it
halfway to the median in price, and `.modifiedSchiff` lifts it in time as well.

`RegressionChannel` is the one drawing that reads the candles rather than only
the anchors: `fitRegression` runs a least-squares fit through the closes of
everything the two anchors span, and `deviations` places a band either side at
that many standard deviations. Move an anchor and the fit is worked out again,
so the line always describes the stretch it covers rather than the two points
it was dropped on.

```dart
KChartWidget(
  data,
  ChartColors(),
  isTrendLine: true,
  currentDrawingTool: DrawingTool.pitchfork,
  drawings: [
    RegressionChannel(
      time1: candles[20].dateTime!, price1: candles[20].close,
      time2: candles[60].dateTime!, price2: candles[60].close,
      deviations: 2,
    ),
    XabcdDrawing(points: [
      for (final i in [10, 20, 30, 40, 50])
        (time: candles[i].dateTime!, price: candles[i].close),
    ]),
  ],
);
```

```dart
RectangleDrawing(
  time1: candles[20].dateTime!, price1: candles[20].high,
  time2: candles[30].dateTime!, price2: candles[30].low,
  fillOpacity: 0.12,
);

FibRetracement(
  time1: swingLow.dateTime!, price1: swingLow.low,
  time2: swingHigh.dateTime!, price2: swingHigh.high,
  levels: [0, 0.382, 0.5, 0.618, 1],   // defaults to the usual seven
);
```

A retracement's levels run from the drawing rightwards to the edge of the chart,
since what a level is worth is what price does after the move. `DrawingStyle`
carries the rest of the geometry: `arrowHeadLength`, `rectangleFillOpacity`,
`shapeFillOpacity`, `measureFillOpacity`, `channelFillOpacity`,
`positionFillOpacity`, and `fibLevels` and `fibFillOpacity` for new retracements
and their bands.

The three-point shapes — `TriangleDrawing`, `ParallelChannel`, `PositionDrawing`
— share `ThreePointDrawing`, which adds `time3` and `price3` and is not complete
until the third point lands. A channel's parallel runs through that point; a
position takes its entry from the first, its target from the second and its stop
from the third, and works out `reward`, `risk` and `riskReward` for the label:

```dart
final plan = PositionDrawing(
  time1: entry.dateTime!, price1: entry.close,
  time2: candles.last.dateTime!, price2: entry.close * 1.06,
  time3: candles.last.dateTime!, price3: entry.close * 0.98,
);
plan.isLong;       // true — the target is above the entry
plan.riskReward;   // 3.0
```

A measurement reads itself out the same way: `priceMove`, `ratio` and `span`, plus
the candle count the chart works out for the label. A note is a `TextAnnotation`
whose `text` the editor's label field types into, and a freehand stroke is a
`FreehandDrawing` — a list of (time, price) points, so it stays on the candles it
was drawn over.

`keepToolArmed` is your own state — the chart never changes `currentDrawingTool`
— but `selectAfterDrawing: false` stops the editor opening over each drawing as
it lands, which is what makes drawing five levels in a row bearable.

Tapping an existing line selects it and opens the editing toolbar. Dragging an
anchor of a two-point drawing moves that anchor; dragging the shape by its
stroke, its outline or one of its levels moves the whole thing, both anchors
together. Every edit — a new colour, a new thickness, a drag, a renamed
label — fires the matching `onAdd*` callback with the updated line, so
persisting a change is the same code path as persisting a new one.

#### Persisting a layout

Every drawing serialises, and `drawingFromJson` turns a map back into the drawing
it came from:

```dart
final drawings = ChartDrawings([
  HorizontalLine(price: 42_000, title: 'entry'),
  TrendLine(time1: a, price1: 1, time2: b, price2: 2),
]);

await prefs.setString('layout', jsonEncode(drawings.toJson()));

final saved = prefs.getString('layout');
final restored = saved == null
    ? ChartDrawings()
    : ChartDrawings.fromJson(jsonDecode(saved) as Map<String, dynamic>);
```

`ChartDrawings` is an ordered set of drawings with typed views —
`horizontalLines`, `trendLines`, `positions` and the rest — so the chart can be
handed the whole layout at once through `drawings:`. A drawing of a kind this
version does not know is skipped rather than throwing, so a layout written by a
newer release still opens. `copyDrawing` deep-copies one, by round-tripping it
through its own JSON.

#### Undo, redo and the drawing controller

Hand the chart a `ChartDrawingController` and it owns the drawings: what the user
places, restyles, drags or deletes goes through the controller, which is what
makes undo possible.

```dart
final drawings = ChartDrawingController();

KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: true,
  watermarkAssetPath: 'assets/logo.svg',
  timeFrame: const Duration(minutes: 15),
  drawingController: drawings,
);

drawings.undo();       // ⌘Z on the chart does the same
drawings.redo();       // ⇧⌘Z, or Ctrl+Y
drawings.clear();      // one undoable step
drawings.select(line); // opens the chart's editor on that drawing
jsonEncode(drawings.toJson());
```

An edit is a step, so restyling a line and undoing gets the old style back — the
controller keeps a deep copy of the last committed state, because the chart edits
a drawing in place and only reports it once the edit lands. `historyLimit`
(50 by default) is how far back it goes; `clearHistory` keeps the drawings and
drops the steps, which is what a fresh symbol wants.

Delete removes the selected drawing, and Escape abandons one being placed. All of
it can be turned off with `enableKeyboardShortcuts: false`. Without a controller
the per-kind lists and callbacks work exactly as before — there is simply no undo.

#### The drawing manager

`DrawingManager` is a plain widget over the same controller: every drawing by
name, with show/hide, lock, delete, undo, redo and clear.

```dart
Row(
  children: [
    Expanded(child: KChartWidget(candles, colors, drawingController: drawings, /* … */)),
    SizedBox(width: 260, child: DrawingManager(controller: drawings)),
  ],
);
```

Tapping a row selects that drawing on the chart, and the chart's own selection
highlights the row. Hiding one leaves it in the layout but off the chart —
`ChartLine.hidden` — and every string it shows, including what each kind is
called, comes from `DrawingTranslations`.

#### Level alerts

A `HorizontalLine` with `alert: true` reports through `onAlertCrossed` whenever
the newest candle closes on the other side of it:

```dart
KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: true,
  watermarkAssetPath: 'assets/logo.svg',
  timeFrame: const Duration(minutes: 15),
  drawings: [HorizontalLine(price: 42_000, alert: true)],
  onAlertCrossed: (line, candle) => notifier.push('crossed ${line.price}'),
);
```

It fires once per crossing — the market has to come back through the level before
it fires again — and the editor's bell button is what arms one from the chart.

### Customising the line editor

`DrawingStyle` decides what the toolbar offers, how it looks, and how close a tap
has to land to count. Everything is optional:

```dart
KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: true,
  watermarkAssetPath: 'assets/logo.svg',
  timeFrame: const Duration(minutes: 15),
  drawingStyle: const DrawingStyle(
    // What the user may pick
    colorOptions: [Color(0xFF4DABF7), Color(0xFF12B886), Color(0xFFFA5252)],
    thicknessOptions: [1, 2, 3, 5],
    lineStyleOptions: [LineStyle.solid, LineStyle.dashed],
    minThickness: 0.5,
    maxThickness: 8,

    // Which controls appear
    showOpacityControl: false,
    showLabelTextControl: true,
    showFillControl: true,     // shapes with an interior
    showAlertControl: true,    // levels only

    // How the bar looks
    toolbarAxis: Axis.horizontal,
    toolbarInitialOffset: Offset(16, 40),
    accentColor: Color(0xFF4DABF7),
    iconSize: 20,

    // How the lines themselves are painted
    handleRadius: 7,
    dashLength: 6,
    dashGap: 4,
    hitTestTolerance: 22,

    // What a newly drawn shape looks like
    rectangleFillOpacity: 0.12,
    shapeFillOpacity: 0.12,
    measureFillOpacity: 0.14,
    channelFillOpacity: 0.08,
    positionFillOpacity: 0.16,
  ),
);
```

A control that a drawing has no use for is left out whatever these say: the fill
slider only appears on a shape with an interior, the alert bell only on a level,
and the label field only on a drawing that can carry one.

A line's own appearance lives on the line, so you can style one before it ever
reaches the chart:

```dart
HorizontalLine(
  price: 68400,
  title: 'take profit',
  color: const Color(0xFF12B886),
  thickness: 2,
  style: LineStyle.dashed,
  showLabel: true,
  locked: true,
);
```

`ChartLine.opacity` reads and writes the alpha of `color`, and `isDashed` still
works for code written before `LineStyle`.

### The long-press readout

![The crosshair and its OHLC card while a candle is held](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/readout.png)

Holding the chart puts a crosshair under the finger with the price and time on
the axes, and a card of that candle's open, high, low, close, change and volume.
`isTapShowInfoDialog` opens it on a tap as well, `infoDialogBuilder` replaces the
card, and `ChartTranslations` names every row.

### Driving the chart

`KChartController` reaches into the chart from your own code: how far it is
zoomed, where it is scrolled, and what it looks like as an image.

```dart
final chart = KChartController();

KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: false,
  watermarkAssetPath: 'assets/logo.svg',
  timeFrame: const Duration(minutes: 15),
  controller: chart,
);

chart.zoomIn();
chart.scrollToNow();                   // animates back to the live candle
chart.isAtRightEdge;                   // whether it is already there
final png = await chart.capture();     // the chart as PNG bytes
```

`capture` returns the chart itself — candles, indicators, drawings — without the
line editor or any other control floating over it. Everything no-ops while no
chart is attached, so a controller built before its widget, or kept after it, is
harmless. The chart also shows its own button back to the live candle whenever it
is scrolled away from one; `showScrollToNowButton: false` turns that off, and its
tooltip comes from `ChartTranslations.jumpToNow`.

### Panes

An indicator pane can be made taller by dragging its lower edge, and moved up or
down the stack by dragging its legend row:

```dart
KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: false,
  watermarkAssetPath: 'assets/logo.svg',
  timeFrame: const Duration(minutes: 15),
  indicators: [MacdIndicator(), RsiIndicator()],
  resizablePanes: true,
  reorderablePanes: true,
  onReorderPane: (from, to) => setState(() {
    indicators.insert(to, indicators.removeAt(from));
  }),
);
```

Each pane is ruled and labelled at round values of its own, rather than showing
only its highest and lowest — which is what lets three ATRs at three periods be
read against each other instead of being three unlabelled squiggles. A pane with
a range it already knows — RSI, KDJ, WR — keeps its guides instead. MACD and the
Awesome oscillator draw their zero line, the axis their histogram changes colour
across, and the volume pane marks a round level part-way up so a bar can be read
against something.

Heights live in the chart, between `ChartStyle.minPaneHeight` and
`maxPaneHeight`, and are given up whenever the panes themselves change. The order
does not: the indicators own that, so the chart reports where a pane was dropped
and leaves the move to you. `ChartStyle.paneResizeTolerance` and `paneGrabHeight`
decide how big each target is.

### Bar replay

Rewind the chart and let the market happen again. `ChartReplayController` holds
the chart at a candle in the past: everything after it — the candles, the
indicators computed from them, the now-price line and the legend — is as it was
at that moment, so a setup can be studied without the answer already on screen.

```dart
final replay = ChartReplayController(interval: const Duration(milliseconds: 300));

KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: false,
  watermarkAssetPath: 'assets/logo.svg',
  timeFrame: const Duration(minutes: 15),
  replay: replay,
);

replay.start(at: 200);   // draw the oldest 200 candles and hold there
replay.stepForward();    // one more
replay.stepBack();       // one fewer
replay.play();           // or let them arrive on their own
replay.pause();
replay.stop();           // hand the whole series back
```

`play()` from cold starts halfway through, so a play button works without a
candle having been picked first, and it gives up on its own at the newest one —
`isPlaying`, `isActive`, `position`, `length` and `isAtEnd` are all there to
drive a transport bar from. It is a `ChangeNotifier`, so those buttons rebuild
themselves; dispose it with the widget that owns it.

Nothing is thrown away while a replay runs: the candle list is untouched and
the drawings stay where they were placed, including any on candles still to
arrive.

### Sessions and time zones

```dart
KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: false,
  watermarkAssetPath: 'assets/logo.svg',
  timeFrame: const Duration(minutes: 15),
  chartStyle: const ChartStyle(showSessionDividers: true),
  timeZoneOffset: const Duration(hours: -5),
);
```

`timeZoneOffset` is added to every candle's time before it is shown — on the axis,
in the crosshair, in the legend and when working out where a day starts. It
changes what is displayed and never the data, so drawings stay anchored to the
candles they were placed on. `showSessionDividers` then marks the first candle of
each day, in `ChartColors.sessionDividerColor`.

### Depth chart

![Cumulative bid and ask depth](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/depth.png)

```dart
DepthChart(
  DepthEntity.bids(rawBids),
  DepthEntity.asks(rawAsks),
  baseUnit: 2,
  quoteUnit: 6,
);
```

The chart plots each rung's `vol` as given, so it must be a running total.
`DepthEntity.bids` and `DepthEntity.asks` sort raw order-book rungs by price and
accumulate them in the right direction — from the best bid downwards and the best
ask upwards — which is what makes the two curves meet at the mid price.

#### Modes

![The combined curve and bars beside the order-book ladder](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/depth-modes.png)

`mode` chooses what the book looks like, and all four read the same data:

| `DepthChartMode` | What it draws |
| --- | --- |
| `cumulative` | The running total either side of the mid — the default, and the shape that shows how hard the book is to move through |
| `histogram` | One bar per level, each the size resting on that rung, so the individual walls stand out |
| `combined` | The curves with those bars behind them |
| `ladder` | The numbers: price, size and running total per row, with a bar behind each |

```dart
DepthChart(
  DepthEntity.bids(rawBids),
  DepthEntity.asks(rawAsks),
  mode: DepthChartMode.combined,
  scale: DepthScale.log,
  zoom: 0.05, // only the book within 5% of the mid
);
```

`scale` spaces the volume axis — `linear`, `log` for a book whose far side dwarfs
the near one, or `percent` to label it as a share of the deepest total — and
`zoom` narrows the chart to the levels near the mid, where the trading is. A zoom
so tight that nothing would be left falls back to the whole book rather than to
an empty chart.

Each rung's own size is recovered from the cumulative curves by differencing, so
nothing extra has to be passed in. `DepthBook.fromCurves` does that on its own if
you want the levels for something else:

```dart
final book = DepthBook.fromCurves(bids, asks, zoom: 0.05);
for (final level in book.bids) {
  print('${level.price}: ${level.size} resting of ${level.cumulative}');
}
```

The ladder is also a widget in its own right, for putting the numbers beside a
chart rather than instead of it:

```dart
DepthLadder(bids, asks, levels: 12, barsShowTotal: false);
```

The long-press readout names the size resting on the rung under the finger as
well as the running total out to it.

### Theming

```dart
KChartWidget(
  candles,
  ChartColors(
    upColor: const Color(0xFF12B886),
    dnColor: const Color(0xFFFA5252),
    bgColor: const Color(0xFF0E1116),
  ),
  chartStyle: const ChartStyle(),
  chartTranslations: const ChartTranslations(),
  // …
);
```

`ChartTranslations` carries every on-chart label (`date`, `open`, `high`, `low`,
`close`, `changeAmount`, `change`, `amount`, `vol`, `jumpToNow`), so localising
the chart is a matter of building one from your own `AppLocalizations`. Its
`drawing` field does the same for the line editor, the drawing manager and what
each of the seventeen kinds is called:

```dart
ChartTranslations(
  date: l10n.date,
  drawing: DrawingTranslations(
    color: l10n.colour,
    delete: l10n.delete,
    fill: l10n.fill,
    alert: l10n.setAlert,
    drawings: l10n.drawings,
    trendLineName: l10n.trendLine,
  ),
);
```

`DrawingTranslations.nameOf` is what turns a drawing into the name the manager
shows, so a kind you have renamed reads the same everywhere.

`ChartColors` gained `sessionDividerColor` for the day dividers and
`gridColumnColor` for the vertical grid lines, which default to a lighter shade
of `gridColor` — a chart is read across price far more than across time, so the
time columns sit behind the price rows. `ChartStyle` now has a `copyWith`, so a
house geometry can be varied a switch at a time:

```dart
final style = ChartTheme.filled.copyWith(showSessionDividers: true);
```

The long-press readout sizes itself to its content between `infoDialogWidth` and
`infoDialogMaxWidth`, and is never wider than the chart. Set
`isTapShowInfoDialog` to open it on a plain tap as well.

### Sizing

`mBaseHeight` is the candle area alone; the volume pane (60px) and each indicator
pane (100px, until one is dragged) are stacked underneath. Left unset it is derived from the widget's
box, so the whole stack fits — put the chart in an `Expanded` and it fills the
space. Pass a number to pin the candle area instead, for instance inside a scroll
view where there is no height to divide up.

### Migrating from 1.x

Nothing was taken off `KChartWidget`: the per-kind drawing lists, their `onAdd*`
and `onRemove*` callbacks and `isLine` all still work, so most apps upgrade by
changing the version and nothing else. Three things to know:

- **Two defaults changed what an existing chart shows.** `crosshairOnHover` and
  `showScrollToNowButton` are both on. The first only ever fires for a pointer
  that hovers, so a touch app never sees it; the second draws a small button over
  the bottom right corner whenever the chart is scrolled away from the newest
  candle. Set either to `false` to keep the old behaviour.
- **A custom `ChartLine` now has to serialise.** `toJson` is part of the base
  class, since that is what lets a layout be saved and a drawing be copied for
  the undo history. Build yours on `baseJson`, and register a `fromJson` of your
  own where you decode:

  ```dart
  class MyDrawing extends TwoPointDrawing {
    @override
    Map<String, dynamic> toJson() => {
      ...baseJson('myDrawing'),
      ...anchorsJson(),
    };
  }
  ```

  Adopting `LabelledDrawing` or `FilledDrawing` is what gets your drawing the
  editor's label field or its fill slider.
- **The painters moved on**, if you imported them from `src/` rather than through
  the public API: `ChartPainter` now takes one `drawings` list rather than a list
  per kind, and reports the crosshair's candle through an `emitInfoWindow`
  callback rather than a `StreamSink`. `MainRenderer.getValue` is now the exact
  inverse of `getY`, which also corrects a price read a few pixels out.

`ChartLine.hidden` is new and defaults to false, so nothing disappears; the
drawing manager is what turns it on.

## Notes

- The zoom slider renders only where there is no pinch gesture — web and desktop.
- `watermarkAssetPath` must point at an SVG registered in your app's `pubspec.yaml`
  assets; a missing asset is ignored and the chart renders without a watermark.

## Support

This package is free to use in your own projects, and I keep it updated weekly —
new indicators, drawing tools and fixes land as I use it myself.

If it saves you some work, the only thing I ask in return is a ⭐ on the
[repository](https://github.com/CtrlAltDevelop/ohlcv_chart) and a follow on
[GitHub](https://github.com/CtrlAltDevelop). That is what keeps the weekly
updates coming.

## Credits

The rendering core began as a derivative of the open-source `k_chart` package and
has since been substantially extended with drawing tools, signals, multi-indicator
stacking and a reworked painter pipeline.

## License

MIT — see [LICENSE](LICENSE).
