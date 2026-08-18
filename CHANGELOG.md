## 1.0.0

- Initial release, extracted from an internal application module.
- `KChartWidget`: candlestick and line rendering, pinch zoom, fling scroll,
  long-press crosshair and info dialog, "now price" line with candle countdown,
  and an SVG watermark.
- Main-chart overlays `MA`, `BOLL` and `SAR`, selectable as a set.
- Secondary charts `MACD`, `KDJ`, `RSI`, `WR` and `CCI`, stacked.
- Drawing tools for trend, horizontal and vertical lines, with selection,
  dragging, colour and thickness editing, and add/remove callbacks.
- Buy/sell `SignalEntity` markers.
- `DepthChart` for bid/ask cumulative market depth with a long-press readout.
- `ChartStyle`, `ChartColors` and `ChartTranslations` for full visual and text
  customisation; `DepthChartStyle`, `DepthChartColors` and
  `DepthChartTranslations` for the depth chart.
- `DataUtil.calculate` computes every indicator in place over a candle list.
