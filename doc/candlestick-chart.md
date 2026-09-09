# Candlestick chart

Feed it a `List<KLineEntity>`. Indicator values are computed in place by
`DataUtil.calculate` before the first paint, and again whenever new candles arrive:

```dart
import 'package:ohlcv_chart/ohlcv_chart.dart';

DataUtil.calculate(candles);

KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: false,
  watermarkAssetPath: 'assets/logo.svg',
  timeFrame: const Duration(minutes: 15),
  indicators: [MaIndicator(period: 20), BollIndicator(), MacdIndicator()],
  timeFormat: TimeFormat.YEAR_MONTH_DAY_WITH_HOUR,
  fixedLength: 2,
  onLoadMore: (isRight) {
    if (!isRight) fetchOlderCandles();
  },
);
```

`KLineEntity.fromJson` accepts the usual OHLCV shape (`open`, `high`, `low`,
`close`, `vol`, `time`/`id`), or build the entity directly.

`onLoadMore` fires when the scroll lands on an edge — `false` at the oldest
candle, `true` at the newest — once when it arrives rather than on every frame
the drag spends there, and again if the user comes away and goes back. Prepend
the older candles you fetch and hand the chart the longer list; it keeps its
place in the data, so the window does not jump.

---

[← All docs](README.md) · [Package README](../README.md)
