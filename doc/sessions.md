# Sessions and time zones

```dart
KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: false,
  timeFrame: const Duration(minutes: 15),
  chartStyle: const ChartStyle(showSessionDividers: true),
  timeZoneOffset: const Duration(hours: -5),
);
```

![The pre-market and after-hours stretches washed behind the candles](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/sessions.png)

`timeZoneOffset` is added to every candle's time before it is shown — on the axis,
in the crosshair, in the legend and when working out where a day starts. It
changes what is displayed and never the data, so drawings stay anchored to the
candles they were placed on. `showSessionDividers` then marks the first candle of
each day, in `ChartColors.sessionDividerColor`.

## Extended hours

`session` says what the regular session is, and the stretches outside it — the
pre-market and the after-hours — are washed behind the candles:

```dart
KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: false,
  timeFrame: const Duration(minutes: 15),
  timeZoneOffset: const Duration(hours: -5),
  session: const TradingSession(
    open: Duration(hours: 9, minutes: 30),
    close: Duration(hours: 16),
  ),
);
```

Read in the time zone the chart is showing, so the bands land where the trader
sees them rather than where UTC does. `weekdays` chooses the days it is kept on,
and a `close` at or before its `open` runs overnight — which is how a market that
opens in one day and closes in the next is described, right down to Friday night
belonging to Friday. Neighbouring candles outside the session are washed as one
band, so a long overnight is one rectangle rather than a hundred. The colour is
`ChartColors.extendedHoursColor`.

## Colouring a bar yourself

`candleColor` is asked about every candle, bar and column drawn. Return a colour
to use it, or null to leave the up or down colour it would have had:

```dart
KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: false,
  timeFrame: const Duration(minutes: 15),
  candleColor: (candle, index) {
    final range = candle.high - candle.low;
    return range > candle.close * 0.012 ? Colors.amber : null;
  },
);
```

Anything the caller can work out can decide: a bar inside a session, one above an
average, one that completes a pattern, one belonging to a particular account.
The `index` is into the list handed to the chart, so a precomputed answer can be
looked up rather than recalculated.

---

[← All docs](README.md) · [Package README](../README.md)
