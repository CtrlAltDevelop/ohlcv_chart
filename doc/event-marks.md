# Event marks

Something happened to the instrument — it reported, it went ex-dividend, it
split, it was in the news. `events` marks each under the candle nearest its own
time, as a small badge below the candle area, so it says *when* without covering
the price it happened at:

```dart
KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: false,
  timeFrame: const Duration(days: 1),
  events: [
    ChartEvent(time: reportedAt, kind: ChartEventKind.earnings),
    ChartEvent(
      time: exDate,
      kind: ChartEventKind.dividend,
      detail: r'$0.24 per share',
    ),
    ChartEvent(time: splitAt, kind: ChartEventKind.split, label: '4:1'),
    ChartEvent(time: headlineAt, kind: ChartEventKind.news),
  ],
  onEventTapped: (event) => showAboutEvent(event),
);
```

![Earnings, a dividend, a split and a news mark under the candles](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/events.png)

`ChartEventKind.earnings`, `.dividend`, `.split`, `.news` and `.custom` each
carry a letter and a colour — `E`, `D`, `S`, `N`, `•`, coloured from
`ChartColors.eventColors` — and `label`, `color` and `icon` override any of it.
`detail` is for a panel or a tooltip of your own; nothing on the chart reads it.

Tapping a badge reports through `onEventTapped`, and a tap gets to the badges
before it is read as a selection or a drawing point, since they are small
targets. `ChartStyle.eventMarkRadius` sizes them and `eventMarkGap` sets how far
below the candles they sit; a radius of zero draws nothing while leaving the
events on the chart for a list of your own. `resolveEvents` is exported for
working out which candle each event falls on without a chart in hand.

---

[← All docs](README.md) · [Package README](../README.md)
