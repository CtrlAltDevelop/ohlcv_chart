# Date axis

Like the price axis, the date axis selects round values before placing labels.

- **Daily and longer timeframes** use round dates.
- **Intraday timeframes** use clock times such as `06:00, 12:00, 18:00`, with
  the date shown where the day changes so session boundaries are visible.
- **Overlapping labels** are omitted.
- **Time zones:** boundaries are computed in the displayed time, so a
  half-hour `timeZoneOffset` still produces round local times.

![The axis the chart picks, and the same candles under a dateFormatter](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/date-axis.png)

## Customisation

`ChartStyle.gridColumns` controls label density, in the same way as `gridRows`
on the price axis.

To control formatting, use `ChartStyle.dateTimeFormat` for a fixed pattern, or
`dateFormatter` for full control. `dateFormatter` receives each candle and a
flag indicating whether the long form (used by the crosshair) is required:

```dart
KChartWidget(
  candles,
  ChartColors(),
  timeFrame: const Duration(minutes: 15),
  dateFormatter: (candle, longForm) => DateFormat(
    longForm ? 'EEE d MMM HH:mm' : 'HH:mm',
  ).format(candle.dateTime!),
  xFrontPadding: 120,
);
```

`xFrontPadding` reserves space to the right of the newest candle, for the
current-price tag and countdown, or for drawings placed ahead of the latest
price.

---

[← All docs](README.md) · [Package README](../README.md)
