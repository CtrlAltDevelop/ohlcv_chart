# Indicators

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

## Levels and profiles

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

![A volume profile and an anchored VWAP over the candles](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/profile.png)

An indicator of your own can draw a profile too: return an `IndicatorProfile`
of `ProfileBin`s from `computeProfile` and the chart draws the bars, picks out
the busiest band and shades the value area. A delta or time profile is the same
shape of answer.

## Pane options

An indicator's pane is fitted to its values and spaced evenly, which is right
for almost everything. Two getters change that where it is not:

```dart
class LogObvIndicator extends ObvIndicator {
  @override
  IndicatorScale get scale => IndicatorScale.logarithmic;
}
```

`IndicatorScale.logarithmic` steps by ratio, so a doubling takes the same room
wherever it happens — what a volume or an on-balance-volume pane wants, where
the interesting range covers orders of magnitude. A pane whose values reach zero
or below has no logarithm to space by and quietly falls back to linear.
`IndicatorScale.percentage` reads out the move away from the first value in
view, so panning moves the base along with the window. Both rule and label the
pane in their own space, so a log pane's marks land on 1, 2 and 5 times each
power of ten.

## An indicator over an indicator

`ChainedIndicator` computes one indicator over another's output instead of over
the candles:

```dart
KChartWidget(
  candles,
  ChartColors(),
  indicators: [
    MacdIndicator(),
    ChainedIndicator(
      source: MacdIndicator(),
      applied: RsiIndicator(period: 14),
    ),
    // A second smoothing of the MACD's signal line.
    ChainedIndicator(
      source: MacdIndicator(),
      applied: MaIndicator(period: 9),
      sourceLine: 1,
    ),
  ],
);
```

The source's chosen line is handed on as flat candles — open, high, low and
close all the same value — which is what lets any indicator that reads closes be
applied. One that reads the range or the volume instead (`ATR`, `OBV`, `MFI`)
has nothing to read there and draws nothing; that is the caller's choice to
make. The two warm-ups add up rather than the second starting from a guess, and
the pane settings, guides, format and colours all come from the applied
indicator. `flattenToCandles` is exported if you would rather do the wrapping
yourself.

## Indicator alerts

An indicator declares the levels worth watching, and the chart reports when the
newest value crosses one:

```dart
class AlertingRsi extends RsiIndicator {
  AlertingRsi() : super(period: 14);

  @override
  List<IndicatorAlert> get alerts => const [
    IndicatorAlert(level: 70, label: 'overbought'),
    IndicatorAlert(level: 30, label: 'oversold'),
  ];
}

KChartWidget(
  candles,
  ChartColors(),
  indicators: [AlertingRsi()],
  onIndicatorAlert: (indicator, alert, candle, value) =>
      notifier.push('${indicator.name} ${alert.label}: $value'),
);
```

`line` picks which of the indicator's lines to watch — a MACD histogram turning
positive is `IndicatorAlert(level: 0, line: 2)`. Each fires once per crossing:
the value has to come back through the level before it fires again. Overlays and
panes are both watched.

## Custom indicators

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

## Recomputing only what moved

A live feed moves the newest candle several times a second, and computing every
indicator over the whole history each time is work that grows with how much
history is loaded rather than with what actually changed. The chart keeps an
`IndicatorCache` and offers each indicator the chance to extend the series it
already has instead:

```dart
class MyIndicator extends Indicator {
  @override
  IndicatorSeries? extendSeries(
    List<KLineEntity> candles,
    IndicatorSeries previous,
    int from,
  ) => IndicatorSeries([
    graftTail(candles, previous.lines[0], from, period - 1,
        (slice) => myMaths(slice, period)),
  ]);
}
```

`from` is the earliest index that can have moved. Return null — the default —
and the series is computed in full, which is always correct and is what sixteen
of the built-in indicators still do: anything reading the whole series at once,
such as a volume profile, a zigzag or the swing overlays built on it, has no
tail to extend. The other thirteen resume, and a chart carrying a moving
average, Bollinger bands, an ATR, an OBV, an RSI and a MACD over 200,000 candles
spends around 2ms a tick on them rather than around 100ms.

Whatever `extendSeries` returns has to be what `compute` would have returned.
Two shapes make that hold, and `series_math.dart` has a helper for each:

- **A window.** `graftTail` recomputes from `from - lookback`, which is exact
  when a value depends only on the candles in its own window. `graftTailLines`
  is the same for an indicator drawing several lines from one pass.
- **A recursion whose own last value is its whole state.** `emaTail`, `atrTail`
  and `obvTail` seed from `previous[from - 1]` and carry on, which is exact to
  the last bit.

Where neither holds — Wilder's smoothing inside an RSI keeps state its published
values do not show — `recursiveLookback` picks the recursion up forty periods
back instead. An exponential recursion forgets its seed geometrically, so by
then the difference is some eighteen orders of magnitude down, well beneath the
gap between neighbouring doubles.

One thing to know if you write an indicator that reads a series handed in from
outside rather than the candles: the cache reuses values for the same instance
while the candles sit still, and recomputes for a new one, so rebuilding your
indicator is what tells the chart its values have changed.

## Colours

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

## Adding and editing at runtime

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

## Building a settings UI

![The example app's add-indicator sheet, built from the catalog](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/indicator-settings.png)

`indicatorCatalog` describes every indicator — its settings, their ranges and
its colour slots — so an "add indicator" sheet can be driven by data rather than
a hard-coded list. It holds 32 entries: the 29 indicators above, with the four
pivot flavours — classic, Fibonacci, Camarilla and weekly — listed one apiece.
The example app's `IndicatorSheet` is built entirely from it:

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

---

[← All docs](README.md) · [Package README](../README.md)
