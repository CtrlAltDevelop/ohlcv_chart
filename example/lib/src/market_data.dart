import 'dart:math';

import 'package:ohlcv_chart/ohlcv_chart.dart';

/// Generates a synthetic but plausible market so the demo needs no network.
class MarketData {
  MarketData._();

  static const Duration timeFrame = Duration(minutes: 15);

  /// Rounds [time] down to the last close of a [timeFrame] candle.
  ///
  /// A real venue stamps a 15-minute candle at :00, :15, :30 or :45, never at
  /// whatever minute the demo happened to launch on — and the date axis labels
  /// the candle that opens each period, so unaligned data would print 06:09
  /// where a real feed prints 06:00.
  static DateTime alignToTimeFrame(DateTime time) {
    final step = timeFrame.inMilliseconds;
    return DateTime.fromMillisecondsSinceEpoch(
      time.millisecondsSinceEpoch ~/ step * step,
    );
  }

  /// Builds [count] candles ending now, as a seeded random walk.
  static List<KLineEntity> candles({int count = 240}) {
    final random = Random(42);
    final start = alignToTimeFrame(DateTime.now().subtract(timeFrame * count));
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

  /// Builds a second instrument over the same span as [over], for comparison.
  ///
  /// A different seed and a different starting price, so it moves its own way —
  /// which is the point of drawing it against the first.
  static ComparisonSeries comparison(
    List<KLineEntity> over, {
    String label = 'ETH',
    int seed = 7,
    double start = 3400,
  }) {
    final random = Random(seed);
    var price = start;

    return ComparisonSeries(
      label: label,
      points: [
        for (final candle in over)
          if (candle.dateTime case final time?)
            (
              time: time,
              value: price = (price + (random.nextDouble() - 0.47) * 60).clamp(
                1500.0,
                7000.0,
              ),
            ),
      ],
    );
  }

  /// Builds a handful of events over the span [over] covers.
  ///
  /// Spaced out rather than random, so the demo always has one of each kind
  /// somewhere it can be seen and tapped.
  static List<ChartEvent> events(List<KLineEntity> over) {
    if (over.isEmpty) return const [];

    ChartEvent? at(int index, ChartEventKind kind, String detail) {
      if (index < 0 || index >= over.length) return null;
      final time = over[index].dateTime;
      return time == null
          ? null
          : ChartEvent(time: time, kind: kind, detail: detail);
    }

    return [
      ?at(over.length - 180, ChartEventKind.earnings, 'Q3 — beat by a cent'),
      ?at(over.length - 120, ChartEventKind.dividend, r'$0.24 going ex'),
      ?at(over.length - 70, ChartEventKind.split, '4-for-1'),
      ?at(over.length - 30, ChartEventKind.news, 'Listed on another venue'),
    ];
  }

  /// Builds a page of candles older than the first entry of [existing] and
  /// returns the combined list, as a paginating feed would.
  static List<KLineEntity> olderThan(
    List<KLineEntity> existing, {
    int count = 80,
  }) {
    final oldest = existing.first;
    final start = oldest.dateTime ?? DateTime.now();
    final random = Random(start.millisecondsSinceEpoch % 1000);
    var price = oldest.open;

    final page = <KLineEntity>[];
    for (var i = count; i > 0; i--) {
      final drift = (random.nextDouble() - 0.52) * 900;
      final close = price;
      final open = (close - drift).clamp(45000.0, 85000.0);
      final wick = random.nextDouble() * 400;

      page.insert(
        0,
        KLineEntity.fromCustom(
          open: open,
          close: close,
          high: max(open, close) + wick,
          low: min(open, close) - wick,
          vol: 40 + random.nextDouble() * 260,
          dateTime: start.subtract(timeFrame * i),
        ),
      );
      price = open;
    }
    return [...page, ...existing];
  }

  /// Builds an order book centred on the last close.
  ///
  /// The rungs hold the size resting at each price, which is what an exchange
  /// feed returns; `DepthEntity.bids` and `DepthEntity.asks` turn them into the
  /// cumulative curves the depth chart draws.
  static (List<DepthEntity> bids, List<DepthEntity> asks) orderBook(
    double midPrice,
  ) {
    final random = Random(7);
    final bids = <DepthEntity>[];
    final asks = <DepthEntity>[];

    for (var i = 1; i <= 60; i++) {
      final spread = i * 25.0;
      // Deeper rungs are thinner, as they tend to be in a real book.
      final thinning = 1 - i / 90;
      bids.add(
        DepthEntity(
          midPrice - spread,
          (random.nextDouble() * 3 + 0.4) * thinning,
        ),
      );
      asks.add(
        DepthEntity(
          midPrice + spread,
          (random.nextDouble() * 3 + 0.4) * thinning,
        ),
      );
    }
    return (DepthEntity.bids(bids), DepthEntity.asks(asks));
  }
}
