# Legend and crosshair

![The OHLC legend above the chart, reading from the crosshair](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/legend-and-crosshair.png)

On desktop and web, `crosshairOnHover` (enabled by default) makes the crosshair
follow the mouse without a press. It has no effect on touch devices.

`showOhlcLegend` displays the values of the candle under the crosshair above
the chart: date, open, high, low, close, change and volume. The legend occupies
its own row above the indicator legends and is localised by
`ChartTranslations`.

```dart
KChartWidget(
  candles,
  ChartColors(),
  timeFrame: const Duration(minutes: 15),
  showOhlcLegend: true,
  crosshairOnHover: true,
);
```

The [long-press readout](readout.md) remains available and opens on a long
press, or on tap with `isTapShowInfoDialog`.

---

[← All docs](README.md) · [Package README](../README.md)
