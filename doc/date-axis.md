# The date axis

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

---

[← All docs](README.md) · [Package README](../README.md)
