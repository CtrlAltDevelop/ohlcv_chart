# Indicators

Indicators are configured instances. Pass any number to `indicators`, including
multiple instances of the same indicator with different settings. Overlays are
drawn on the main chart; all other indicators get their own pane, stacked in
list order.

```dart
KChartWidget(
  candles,
  ChartColors(),
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
| `MaIndicator` | `period` (simple moving average) |
| `EmaIndicator` | `period` |
| `BollIndicator` | `period`, `deviations` |
| `SarIndicator` | `start`, `step`, `maximum` |
| `VwapIndicator` | — |
| `AnchoredVwapIndicator` | `anchor` (starting candle) |
| `SessionVwapIndicator` | `session`, `deviations`; resets each session, with bands |
| `PivotPointsIndicator` | `method`, `session`; pivot with three support and three resistance levels |
| `VolumeProfileIndicator` | `bins`, `valueArea`; volume by price level |
| `SupertrendIndicator` | `period`, `multiplier`; colour changes with trend direction |
| `KeltnerIndicator` | `period`, `atrPeriod`, `multiplier` |
| `DonchianIndicator` | `period` |
| `IchimokuIndicator` | `conversionPeriod`, `basePeriod`, `spanPeriod`, `displacement`; shaded cloud |
| `ZigZagIndicator` | `depth` (minimum swing size, in percent) |
| `FibonacciIndicator` | `depth`, `ratios`; retracement of the latest swing |
| `ElliottWaveIndicator` | `depth`; labels swings `1`–`5` and `A`–`C` |

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
| `DmiIndicator` | `period`, with 20 guide |
| `AroonIndicator` | `period`, with 30/70 guides; Aroon Up and Down, 0–100 |
| `StochRsiIndicator` | `rsiPeriod`, `period`, `kSmoothing`, `dSmoothing`, with 20/80 guides |
| `RocIndicator` | `period` |
| `TrixIndicator` | `period`, `signalPeriod` |
| `VolumeMaIndicator` | `period` |
| `AwesomeIndicator` | `fast`, `slow` |

![A zigzag, Fibonacci retracement and Elliott wave labels](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/swings.png)

### Swing indicators

Three overlays are based on price swings rather than a fixed window, and share a
`depth` parameter — the minimum percentage move that defines a swing:

- `ZigZagIndicator` draws the swing legs.
- `FibonacciIndicator` draws a retracement of the latest swing.
- `ElliottWaveIndicator` labels the swings.

The default `depth: 0` sizes the threshold automatically from the data, since a
fixed percentage suited to a volatile daily chart may find no swings on a quiet
intraday chart. The label then shows `auto`. Pass a positive value to set the
threshold explicitly.

The Elliott wave labels are a swing-based approximation, not a rules-validated
wave count; verify them visually.

### Ichimoku

`IchimokuIndicator` shifts its leading spans forward and its lagging line back.
Because the chart stores one value per candle, the portion of the cloud
projected beyond the newest candle is not drawn.

## Levels and profiles

### Volume profile

`VolumeProfileIndicator` groups visible volume into `bins` price bands, drawn as
horizontal bars from the side opposite the price labels so they align with the
price axis.

- The point of control (the band with the most volume) is highlighted.
- The `valueArea` around it is shaded across the chart.
- Other bands are split into volume from rising and falling candles.
- Each candle's volume is distributed evenly across the bands its range covers,
  since OHLCV data contains no intra-candle detail.

Colours: `ChartColors.profileUpColor`, `profileDownColor`, `profilePocColor` and
`profileValueAreaColor`, or `profileColor` for a single colour.
`ChartStyle.profileWidth` sets the width of the largest bar as a fraction of the
chart width.

### Pivot points

`PivotPointsIndicator` calculates the pivot, three support and three resistance
levels from the previous session and draws them across the current session.

- `PivotMethod.standard`, `.fibonacci` and `.camarilla` select the calculation.
- `PivotSession.day`, `.week`, `.month` and `.year` define the session, so an
  intraday chart can use weekly pivots.

### Anchored VWAP

`AnchoredVwapIndicator` calculates VWAP from a chosen candle onwards — for
example, a swing high or low, an earnings date or a session open. No values are
drawn before the `anchor`.

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

### Session VWAP

`SessionVwapIndicator` resets at every session boundary, which is the standard
intraday VWAP: it shows the volume-weighted average price for the current
session only.

```dart
KChartWidget(
  data,
  ChartColors(),
  indicators: [
    SessionVwapIndicator(),                              // resets daily, ±1σ
    SessionVwapIndicator(session: PivotSession.week),    // resets on the Monday
    SessionVwapIndicator(deviations: 0),                 // the average alone
  ],
);
```

![A session VWAP with its band, over an Aroon pane](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/session-vwap.png)

- Bands are drawn at `deviations` volume-weighted standard deviations from the
  average. Because the deviation is volume-weighted, low-volume outliers have
  little effect. `deviations: 0` draws the average only.
- Sessions use the same boundaries as pivot points: days break at the chart's
  day divider, and weeks start on Monday.

**Visible-range VWAP:** anchor `AnchoredVwapIndicator` to the first visible
candle and update it from `onVisibleRangeChanged`:

```dart
KChartWidget(
  data,
  ChartColors(),
  indicators: [AnchoredVwapIndicator(anchor: firstVisible)],
  onVisibleRangeChanged: (range) =>
      setState(() => firstVisible = range.firstIndex),
);
```

**Custom profiles:** a custom indicator can return an `IndicatorProfile` of
`ProfileBin`s from `computeProfile`. The chart draws the bars, highlights the
point of control and shades the value area. This supports other profile types,
such as delta or time profiles.

## Pane options

By default, a pane fits its values on a linear scale. Override `scale` to
change this:

```dart
class LogObvIndicator extends ObvIndicator {
  @override
  IndicatorScale get scale => IndicatorScale.logarithmic;
}
```

| `IndicatorScale` | Behaviour |
| --- | --- |
| `linear` | Evenly spaced values (default) |
| `logarithmic` | Equal ratios use equal space; suited to values spanning orders of magnitude, such as volume or OBV. Falls back to linear when values reach zero or below |
| `percentage` | Change from the first visible value; the base moves as you pan |

Ticks are computed in the chosen scale, so logarithmic panes show ticks at 1, 2
and 5 times each power of ten.

## Chained indicators

`ChainedIndicator` computes an indicator on the output of another indicator
instead of on candles:

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

- The selected source line is converted to flat candles (open, high, low and
  close all equal), so any close-based indicator can be applied.
- Indicators that depend on range or volume (`ATR`, `OBV`, `MFI`) produce no
  output when chained.
- Warm-up periods are combined, so the applied indicator does not start from an
  estimate.
- Pane settings, guides, format and colours come from the applied indicator.
- `flattenToCandles` is exported for manual use.

## Higher-timeframe indicators

`TimeframeIndicator` computes an indicator on a higher timeframe than the chart
— for example, a daily moving average on a 15-minute chart:

```dart
KChartWidget(
  candles,
  ChartColors(),
  timeFrame: const Duration(minutes: 15),
  indicators: [
    MaIndicator(period: 20),
    TimeframeIndicator(
      timeframe: const Duration(days: 1),
      applied: MaIndicator(period: 20),
    ),
    TimeframeIndicator(
      timeframe: const Duration(hours: 4),
      applied: RsiIndicator(period: 14),
    ),
  ],
);
```

![A four-hour moving average and RSI over fifteen-minute candles](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/higher-timeframe.png)

Candles are aggregated to `timeframe` (first open, highest high, lowest low,
last close, total volume), and the indicator is computed on the aggregated bars.
Aggregation uses the chart's own boundaries: daily bars break at the day
divider, and monthly bars follow the calendar.

**No look-ahead or repainting.** Each candle uses the last higher-timeframe bar
that had closed before the candle opened. The line steps once per
higher-timeframe bar, and candles within the first bar have no value. Using the
bar a candle falls inside would expose future data (for example, showing a
morning candle a value that depends on the afternoon), producing misleading
backtests and values that change as the bar develops. Values shown here were
known at the time and never change.

As with `ChainedIndicator`, pane settings, guides, format and colours come from
the applied indicator. The aggregation is available separately:
`CandleTransforms.resample(candles, timeframe)` returns the bars, and
`CandleTransforms.bucketIndices` returns the bar index for each candle.

## Indicator alerts

Indicators can declare alert levels. The chart reports when the latest value
crosses one:

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

- `line` selects which indicator line to monitor — for example,
  `IndicatorAlert(level: 0, line: 2)` for a MACD histogram crossing zero.
- Each alert fires once per crossing and re-arms after the value crosses back.
- Alerts work for both overlays and pane indicators.

## Custom indicators

Subclass `Indicator` and implement `label`, `lines`, `settings` and `compute`.
The chart handles scaling, rendering, legends and labels as for built-in
indicators.

| Line shape | Rendering |
| --- | --- |
| Stroke | Continuous line |
| Dots | Dot per value |
| Histogram | Bars |
| `pivotLine` | Straight segments across candles without values, as used by ZigZag |
| `markers` | Dot with custom text |

`fills` shades the area between two lines, and `colorForPoint` sets the colour
of individual points — for example, Supertrend's colour change at reversals.

![Three ATRs at different periods, each in its own pane](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/panes.png)

Multiple instances of the same indicator can be added, each with its own
settings and colours.

## Recomputing only what moved

Live data updates the newest candle frequently. Recomputing every indicator
over the full history on each update scales with history length rather than
with the size of the change. The chart's `IndicatorCache` instead lets
indicators extend their existing results:

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

`from` is the earliest index that may have changed. Returning `null` (the
default) triggers a full recomputation, which is always correct.

- **17 built-in indicators** recompute in full, because they depend on the whole
  series (for example, volume profile, ZigZag and the swing indicators).
- **14 built-in indicators** support incremental updates. With MA, Bollinger
  Bands, ATR, OBV, RSI and MACD on 200,000 candles, an update takes about 2 ms
  instead of about 100 ms.

The result of `extendSeries` must be identical to `compute`. `series_math.dart`
provides helpers for two common patterns:

- **Windowed calculations.** `graftTail` recomputes from `from - lookback`, which
  is exact when each value depends only on its window. `graftTailLines` does the
  same for multi-line indicators.
- **Recursions whose last value is the full state.** `emaTail`, `atrTail` and
  `obvTail` continue from `previous[from - 1]`, with bit-exact results.

When neither applies — for example, Wilder's smoothing in RSI has internal state
not reflected in its output — `recursiveLookback` restarts the recursion 40
periods earlier. The influence of the seed decays geometrically, leaving a
difference around 18 orders of magnitude smaller, below double-precision
resolution.

**Indicators using external data:** the cache reuses values for the same
instance while candles are unchanged. Create a new instance when the external
data changes so the chart recomputes.

## Colours

Indicator colours come from `ChartColors` by default. Override them per instance
with `color`, or `colors` for multi-line indicators:

```dart
indicators: [
  MaIndicator(period: 20, color: Colors.amber),
  MacdIndicator(colors: [Colors.grey, Colors.blue, Colors.orange]),
],
```

Multiple instances of the same indicator are automatically assigned
successive theme colours.

## Managing indicators at runtime

Indicators are identified by type and settings, excluding colours. `upsert`
therefore updates a matching indicator instead of adding a duplicate:

```dart
final indicators = <Indicator>[MaIndicator(period: 20)];

indicators.upsert(AtrIndicator(period: 14));                    // added
indicators.upsert(AtrIndicator(period: 14, color: Colors.red)); // recoloured
indicators.upsert(AtrIndicator(period: 20));                    // a second pane
indicators.toggle(RsiIndicator());                              // on, then off
```

## Templates

An indicator template is a named set of indicators that can be saved and
applied to any chart — the indicator equivalent of `DrawingTemplate`.

```dart
final saved = IndicatorTemplates(IndicatorTemplate.starters);

// Save what is on the chart now.
saved.save(IndicatorTemplate(name: 'Swing', indicators: indicators));

// Put one on.
setState(() => indicators = [...saved['Swing']!.indicators]);

await prefs.setString('templates', jsonEncode(saved.toJson()));
```

- Saving with an existing name replaces that template in place, so menus built
  from `all` keep their order.
- `IndicatorTemplate.starters` provides four default sets — trend, momentum,
  volatility and volume — which apps can use or ignore.
- Templates use the workspace serialisation format. Indicators the catalog
  cannot rebuild are excluded and listed in `unsaveable`, so your app can
  inform the user:

```dart
final template = IndicatorTemplate(name: 'Mine', indicators: indicators);
if (template.unsaveable.isNotEmpty) {
  // Tell somebody, rather than losing them silently.
}
```

## Building a settings UI

![The example app's add-indicator sheet, built from the catalog](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/indicator-settings.png)

`indicatorCatalog` describes each indicator's settings, value ranges and colour
slots, so indicator configuration UIs can be generated from data. It contains
35 entries: the 31 indicators, with four pivot variants (classic, Fibonacci,
Camarilla and weekly) and two session VWAP variants (daily and weekly) listed
separately. The example app's `IndicatorSheet` is built entirely from the
catalog:

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

`DataUtil.calculate` populates the indicator fields on each `KLineEntity`, which
the long-press readout uses. Indicators compute their own values from the
candles independently.

---

[← All docs](README.md) · [Package README](../README.md)
