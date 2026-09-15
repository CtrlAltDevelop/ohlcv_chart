# Sessions and time zones

```dart
KChartWidget(
  candles,
  ChartColors(),
  timeFrame: const Duration(minutes: 15),
  chartStyle: const ChartStyle(showSessionDividers: true),
  timeZoneOffset: const Duration(hours: -5),
);
```

![The pre-market and after-hours stretches washed behind the candles](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/sessions.png)

## Display time zone

`timeZoneOffset` is applied to candle times wherever they are displayed: the
date axis, crosshair, legend and day-boundary calculations. It affects display
only; the underlying data is unchanged, so drawings stay anchored to their
candles.

`showSessionDividers` draws a line at the first candle of each day, using
`ChartColors.sessionDividerColor`.

## Extended hours

`session` defines the regular trading session. Pre-market and after-hours
periods are shaded behind the candles:

```dart
KChartWidget(
  candles,
  ChartColors(),
  timeFrame: const Duration(minutes: 15),
  timeZoneOffset: const Duration(hours: -5),
  session: const TradingSession(
    open: Duration(hours: 9, minutes: 30),
    close: Duration(hours: 16),
  ),
);
```

- Session times are interpreted in the displayed time zone.
- `weekdays` selects the trading days.
- If `close` is at or before `open`, the session spans midnight; the overnight
  portion belongs to the day the session opened (for example, Friday night
  belongs to Friday).
- Consecutive out-of-session candles are drawn as a single band.
- The shading colour is `ChartColors.extendedHoursColor`.

## Custom bar colours

`candleColor` is called for every candle, bar and column. Return a colour to
override it, or `null` to keep the default up/down colour:

```dart
KChartWidget(
  candles,
  ChartColors(),
  timeFrame: const Duration(minutes: 15),
  candleColor: (candle, index) {
    final range = candle.high - candle.low;
    return range > candle.close * 0.012 ? Colors.amber : null;
  },
);
```

Use it to highlight any condition your app can compute — session membership,
price relative to an average, pattern completion and so on. `index` refers to
the list passed to the chart, so you can look up precomputed results.

---

[← All docs](README.md) · [Package README](../README.md)
