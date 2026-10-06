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

By default the grid's vertical lines rule wherever a candle crosses a time
bucket (`GridColumnMode.dateTicks`), so each line lines up with a round time.
With only a handful of candles in view — a sparse intraday window, say —
there may be only one or two such crossings, leaving most of the chart
without a line. Set `ChartStyle.gridColumnMode` to
`GridColumnMode.evenlySpaced` to divide the chart width into `gridColumns`
equal bands instead, so the grid always spans the chart regardless of candle
count — at the cost of the lines no longer landing on round times:

```dart
ChartStyle(
  gridColumnMode: GridColumnMode.evenlySpaced,
);
```

The grid can also be trimmed or dashed, each part on its own:

```dart
ChartStyle(
  showGridRows: false,           // vertical lines only
  showGridColumns: true,
  gridDashPattern: [4, 3],       // 4px dash, 3px gap; null is solid
);
```

`hideGrid` on the widget still hides the whole grid. The date labels keep
their round times in either column mode, so with `evenlySpaced` a line and a
label need not meet.

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
