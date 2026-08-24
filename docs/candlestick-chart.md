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

---

[← All docs](README.md) · [Package README](../README.md)
