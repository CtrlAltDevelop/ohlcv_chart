# ohlcv_chart

A candlestick (K-line) and market-depth chart for Flutter, drawn entirely with
`CustomPainter` — no WebView, no JavaScript bridge.

Named for the open-high-low-close-volume bars it renders.

![Candles with moving averages, volume and MACD](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/candles.png)

## Features

- **Candlestick and line modes** with pinch-to-zoom, fling scrolling and long-press crosshair.
- **26 indicators**, each a configured instance rather than a flag — so `ATR(8)`, `ATR(14)` and `ATR(20)` are three panes, with their own settings and colours.
- **Main-chart overlays** — `MA`, `EMA`, `BOLL`, `SAR`, `VWAP`, Supertrend, Keltner and Donchian channels, and the Ichimoku Cloud.
- **Swing readers** — a zigzag through the swing highs and lows, Fibonacci retracement of the last swing, and Elliott wave labels, all sized to the market by default.
- **Sub-charts** — `MACD`, `KDJ`, `RSI`, `WR`, `CCI`, `ATR`, `OBV`, `MFI`, `DMI`, Stochastic RSI, `ROC`, `TRIX`, a volume average and the Awesome oscillator, each in its own stacked pane.
- **Drawing tools** — trend lines, horizontal lines and vertical lines, each interactively placed, dragged, locked and removed, with add/remove callbacks so you can persist them.
- **A line editor** that opens on selection: colour, opacity, thickness, solid/dashed/dotted stroke, label text and visibility — every option list, control and pixel of it configurable through `DrawingStyle`.
- **Buy/sell signal markers** pinned to candles.
- **Depth chart** — a separate `DepthChart` widget for the order book, drawn as the cumulative curve, a per-rung histogram, both at once, or a numeric ladder of price, size and running total, on a linear, log or percentage axis and zoomable to the levels around the mid.
- **Info dialog** on long press, either the built-in Material popup or your own builder.
- **"Now price" line** with a live countdown to the close of the current candle.
- **SVG watermark** loaded from an asset path you supply.
- **Fully themeable** — `ChartStyle` for geometry, `ChartColors` for every colour, `DrawingStyle` for the drawing tools; `ChartTranslations` for every label. Filled or hollow candles, dashed or solid crosshair, pane separators, axis-label pills and a placed, tinted watermark.
- **Fits its box** — the candles take whatever height the volume and indicator panes leave, so the chart works from a phone to a desktop window without arithmetic on your side.

## Install

```yaml
dependencies:
  ohlcv_chart: ^1.1.0
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

### Drawing tools

![The line editor open on a selected line](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/line-editor.png)

Selecting a drawn line opens the editor over the chart: colour, thickness,
stroke style, label text and visibility, lock and delete.

![Trend and horizontal lines with labels](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/drawing.png)

Set `currentDrawingTool` to put the chart into placement mode and handle the
callbacks to persist what the user draws:

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
  onAddTrendLine: repository.save,
  onRemoveTrendLine: repository.delete,
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

Tapping an existing line selects it and opens the editing toolbar. Dragging an
end of a trend line moves that end; dragging it anywhere along the stroke moves
the whole line. Every edit — a new colour, a new thickness, a drag, a renamed
label — fires the matching `onAdd*` callback with the updated line, so
persisting a change is the same code path as persisting a new one.

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
  ),
);
```

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
`close`, `changeAmount`, `change`, `amount`), so localising the chart is a matter
of building one from your own `AppLocalizations`. Its `drawing` field does the
same for the line editor:

```dart
ChartTranslations(
  date: l10n.date,
  drawing: DrawingTranslations(color: l10n.colour, delete: l10n.delete),
);
```

The long-press readout sizes itself to its content between `infoDialogWidth` and
`infoDialogMaxWidth`, and is never wider than the chart. Set
`isTapShowInfoDialog` to open it on a plain tap as well.

### Sizing

`mBaseHeight` is the candle area alone; the volume pane (60px) and each indicator
pane (100px) are stacked underneath. Left unset it is derived from the widget's
box, so the whole stack fits — put the chart in an `Expanded` and it fills the
space. Pass a number to pin the candle area instead, for instance inside a scroll
view where there is no height to divide up.

## Notes

- The zoom slider renders only where there is no pinch gesture — web and desktop.
- `watermarkAssetPath` must point at an SVG registered in your app's `pubspec.yaml`
  assets; a missing asset is ignored and the chart renders without a watermark.

## Credits

The rendering core began as a derivative of the open-source `k_chart` package and
has since been substantially extended with drawing tools, signals, multi-indicator
stacking and a reworked painter pipeline.

## License

MIT — see [LICENSE](LICENSE).
