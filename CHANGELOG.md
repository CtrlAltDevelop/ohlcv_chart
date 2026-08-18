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
- Runs on iOS, Android, web, Windows, macOS and Linux. The zoom slider now
  appears only where there is no pinch gesture — web and desktop — where
  before a always-true platform check rendered it on mobile as well.

Fixed while extracting the module:

- `DataUtil.calculate` no longer throws on an empty candle list, so the chart
  can be built before the first candles arrive.
- Secondary charts scale to their true maximum when an indicator stays below
  zero. `MACD` and `CCI` in a sustained decline previously scaled against zero,
  because the running maximum was seeded with `double.minPositive` — a tiny
  positive number rather than a lower bound.
- `SAR` resets its acceleration factor identically on both trend reversals;
  the up-to-down reversal previously restarted one step too fast.
- The "now price" countdown timer starts and stops when `showNowPrice` changes,
  instead of only being read once when the chart is first built.
