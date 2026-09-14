# The legend and the crosshair

![The OHLC legend above the chart, reading from the crosshair](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/legend-and-crosshair.png)

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
  timeFrame: const Duration(minutes: 15),
  showOhlcLegend: true,
  crosshairOnHover: true,
);
```

The long-press readout is unchanged, and still opens on a press or — with
`isTapShowInfoDialog` — a tap.

---

[← All docs](README.md) · [Package README](../README.md)
