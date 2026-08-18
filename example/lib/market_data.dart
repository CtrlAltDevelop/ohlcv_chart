import 'dart:math';

import 'package:ohlcv_chart/ohlcv_chart.dart';

/// Generates a synthetic but plausible market so the demo needs no network.
class MarketData {
  MarketData._();

  static const Duration timeFrame = Duration(minutes: 15);

  /// Builds [count] candles ending now, as a seeded random walk.
  static List<KLineEntity> candles({int count = 240}) {
    final random = Random(42);
    final start = DateTime.now().subtract(timeFrame * count);
    var price = 64000.0;

    final candles = <KLineEntity>[];
    for (var i = 0; i < count; i++) {
      final drift = (random.nextDouble() - 0.48) * 900;
      final open = price;
      final close = (open + drift).clamp(45000.0, 85000.0);
      final wick = random.nextDouble() * 400;

      candles.add(
        KLineEntity.fromCustom(
          open: open,
          close: close,
          high: max(open, close) + wick,
          low: min(open, close) - wick,
          vol: 40 + random.nextDouble() * 260,
          dateTime: start.add(timeFrame * i),
        ),
      );
      price = close;
    }

    // The chart draws nothing for MA, BOLL, SAR or the sub-charts until the
    // indicator fields have been filled in.
    DataUtil.calculate(candles);
    return candles;
  }

  /// Builds an order book centred on the last close.
  static (List<DepthEntity> bids, List<DepthEntity> asks) orderBook(
    double midPrice,
  ) {
    final random = Random(7);
    final bids = <DepthEntity>[];
    final asks = <DepthEntity>[];

    for (var i = 1; i <= 60; i++) {
      final spread = i * 25.0;
      bids.add(DepthEntity(midPrice - spread, random.nextDouble() * 3 + 0.4));
      asks.add(DepthEntity(midPrice + spread, random.nextDouble() * 3 + 0.4));
    }
    return (bids, asks);
  }
}
