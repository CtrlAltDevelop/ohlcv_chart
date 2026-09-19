// The sample data every gallery chart is drawn from.
//
// One copy, shared by the gallery page in the app and by the screenshot tool,
// so the pictures in the documentation are of the same charts the example
// actually runs. Nothing here is random: the shapes are trigonometric, so a
// screenshot taken today matches the one taken last release.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

/// The palette the gallery hands out, in order.
const galleryPalette = [
  galleryBlue,
  galleryGreen,
  galleryAmber,
  galleryPurple,
  galleryRed,
  galleryTeal,
];

/// The blue a gallery chart starts with.
const galleryBlue = Color(0xFF4DABF7);

/// The green it uses for a gain.
const galleryGreen = Color(0xFF12B886);

/// The amber it uses for a warning.
const galleryAmber = Color(0xFFFAB005);

/// A purple, for a third series.
const galleryPurple = Color(0xFF9775FA);

/// The red it uses for a loss.
const galleryRed = Color(0xFFFA5252);

/// A teal, for a sixth series.
const galleryTeal = Color(0xFF3BC9DB);

/// The month names the gallery labels its axes with.
const galleryMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Dollars, shortened past a thousand.
String galleryUsd(double value) {
  final sign = value < 0 ? '-' : '';
  final amount = value.abs();
  final digits = amount >= 1000
      ? '${(amount / 1000).toStringAsFixed(1)}k'
      : amount.toStringAsFixed(0);
  return '$sign\$$digits';
}

/// A price, in thousands.
String galleryPrice(double value) => '\$${(value / 1000).toStringAsFixed(0)}k';

/// A price, written out.
String galleryFullPrice(double value) => value.toStringAsFixed(0);

/// A percentage, to one decimal.
String galleryPercent(double value) => '${value.toStringAsFixed(1)}%';

/// Millions of dollars.
String galleryMillions(double value) =>
    '\$${(value / 1e6).toStringAsFixed(0)}M';

/// A smooth, repeatable series.
List<double> galleryWave(
  int count, {
  double base = 0,
  double swing = 1,
  double drift = 0,
  double phase = 0,
}) => [
  for (var i = 0; i < count; i++)
    base +
        sin(i / 6.1 + phase) * swing +
        cos(i / 2.7 + phase * 1.3) * swing * 0.4 +
        i * drift,
];

/// A spread of daily returns, with a fat tail either side.
List<double> galleryReturns({
  double mean = 0.4,
  double spread = 2.2,
  int count = 400,
  double skew = 0,
}) => [
  for (var i = 0; i < count; i++)
    mean +
        sin(i * 2.399) * spread +
        cos(i * 0.733) * spread * 0.6 +
        sin(i * 0.211) * spread * skew,
];

/// Trade results in R: a wall of losers stopping out at about -1R, and a tail
/// of winners running.
List<double> galleryRMultiples({int count = 180}) => [
  for (var i = 0; i < count; i++)
    i % 5 < 3
        ? -1.05 + sin(i * 2.7) * 0.22
        : 0.3 + sin(i * 1.13).abs() * 2.9 + cos(i * 0.47).abs() * 1.4,
];

/// The same book in money: three losers to two winners, a real edge but a
/// thin one.
List<double> galleryTradePnl({int count = 180}) => [
  for (var i = 0; i < count; i++)
    i % 5 < 3 ? -640.0 - (i % 7) * 30 : 1180.0 + sin(i * 1.31).abs() * 520,
];

/// An account that grows, with a drawdown in the middle of the year.
List<EquityPoint> galleryEquity({int days = 260}) => [
  for (var i = 0; i < days; i++)
    EquityPoint(
      time: DateTime(2026).add(Duration(days: i)),
      equity:
          40000 +
          i * 62 +
          sin(i / 17.0) * 3400 +
          cos(i / 5.3) * 900 -
          (i > 150 && i < 200 ? (i - 150) * 74 : 0),
    ),
];

/// Order flow: the bars the profile, footprint and delta charts all read.
///
/// The price wanders both ways rather than climbing, so the profile it builds
/// has a middle to find a point of control in.
List<FootprintBar> galleryFootprint({int bars = 22, double tick = 20}) {
  final out = <FootprintBar>[];
  double pathAt(int i) =>
      68000 + sin(i / 3.1) * 240 + cos(i / 1.3) * 90 - sin(i / 7.7) * 120;
  for (var b = 0; b < bars; b++) {
    final open = pathAt(b);
    final close = pathAt(b + 1);
    final drift = close - open;
    final high = max(open, close) + 40 + (b % 3) * 20;
    final low = min(open, close) - 40 - (b % 4) * 15;
    final levels = <FootprintLevel>[];
    for (var p = low; p <= high; p += tick) {
      final fromMid = (p - (open + close) / 2).abs() / 120;
      final weight = (2.4 - fromMid).clamp(0.2, 2.4);
      final lean = drift >= 0 ? 1.35 : 0.72;
      levels.add(
        FootprintLevel(
          price: p,
          bidVolume: (weight * 34 * (2 - lean) + (p ~/ tick) % 7).toDouble(),
          askVolume: (weight * 34 * lean + (p ~/ tick) % 5).toDouble(),
        ),
      );
    }
    out.add(
      FootprintBar(
        time: DateTime(2026, 4, 2, 9, 30).add(Duration(minutes: b * 5)),
        levels: levels,
        open: open,
        high: high,
        low: low,
        close: close,
      ),
    );
  }
  return out;
}

/// Those same bars as candles, for the market profile.
List<KLineEntity> galleryCandles({int bars = 22}) => [
  for (final bar in galleryFootprint(bars: bars))
    KLineEntity.fromCustom(
      dateTime: bar.time,
      vol: 0,
      open: bar.open ?? 0,
      high: bar.high ?? 0,
      low: bar.low ?? 0,
      close: bar.close ?? 0,
    ),
];

/// An order book over twenty minutes, with two walls resting at prices of
/// their own while the mid wanders past them.
List<BookSnapshot> galleryBook({int snapshots = 80}) => [
  for (var t = 0; t < snapshots; t++)
    () {
      final mid = 68000 + sin(t / 9.1) * 180;
      return BookSnapshot(
        time: DateTime(2026, 4, 2, 9, 30).add(Duration(seconds: t * 15)),
        mid: mid,
        levels: [
          for (var i = 1; i <= 24; i++) ...[
            () {
              final price = mid - i * 20;
              return BookLevel(
                price: price,
                size:
                    (price >= 67740 && price < 67760 ? 900.0 : 0) +
                    120 +
                    sin(i / 2.3 + t / 7) * 70 +
                    (i % 5) * 12,
                side: BookSide.bid,
              );
            }(),
            () {
              final price = mid + i * 20;
              return BookLevel(
                price: price,
                size:
                    (price >= 68300 && price < 68320 && t > 24 ? 820.0 : 0) +
                    120 +
                    cos(i / 2.1 + t / 6) * 70 +
                    (i % 4) * 15,
                side: BookSide.ask,
              );
            }(),
          ],
        ],
      );
    }(),
];

/// Leveraged positions stacked up the price axis, longs below the market and
/// shorts above it.
List<LiquidityLevel> galleryLiquidity({int count = 260}) => [
  for (var i = 0; i < count; i++)
    LiquidityLevel(
      price: 62000 + i * 46,
      size:
          (i % 17 == 0 ? 900.0 : 120) +
          sin(i / 6.1).abs() * 260 +
          cos(i / 2.3).abs() * 90,
      side: 62000 + i * 46 < 68000 ? LiquiditySide.long : LiquiditySide.short,
      leverage: [5.0, 10.0, 25.0, 50.0][i % 4],
    ),
];

/// Open interest, funding and price, every eight hours for forty days.
List<OpenInterestPoint> galleryOpenInterest({int count = 120}) => [
  for (var i = 0; i < count; i++)
    OpenInterestPoint(
      time: DateTime(
        2026,
        4,
      ).add(Duration(hours: i * 8)).millisecondsSinceEpoch,
      openInterest:
          820e6 + sin(i / 14.0) * 90e6 + cos(i / 4.1) * 24e6 + i * 1.1e6,
      funding: sin(i / 9.0) * 0.00045 + cos(i / 3.3) * 0.00012,
      price: 66000 + sin(i / 11.0) * 2600 + cos(i / 3.7) * 600 + i * 12,
    ),
];

/// Two instruments that drift apart and back, for the pair chart.
List<PairPoint> galleryPair({int days = 160}) => [
  for (var i = 0; i < days; i++)
    PairPoint(
      time: DateTime(2026).add(Duration(days: i)),
      a: 100 + i * 0.22 + sin(i / 11.0) * 4 + cos(i / 3.1) * 1.2,
      b: 40 + i * 0.08 + sin(i / 13.0) * 1.1,
    ),
];

/// A quarter of daily results, flat at weekends.
List<CalendarDay> galleryCalendar({int days = 92}) => [
  for (var i = 0; i < days; i++)
    CalendarDay(
      date: DateTime(2026, 4, 1).add(Duration(days: i)),
      value: (i % 7 == 5 || i % 7 == 6)
          ? 0
          : sin(i / 4.1) * 900 + cos(i / 1.7) * 420 + (i % 5 - 2) * 130,
    ),
];

/// Five years of monthly returns, with a weak September.
List<SeasonalSample> gallerySeasonality() => [
  for (var year = 2022; year <= 2026; year++)
    for (var month = 1; month <= 12; month++)
      SeasonalSample(
        time: DateTime(year, month, 15),
        value:
            sin(month / 1.9 + year * 0.7) * 0.05 +
            cos(month / 3.3) * 0.03 +
            (month == 9 ? -0.04 : 0.01),
      ),
];

/// Trades to lay out on a timeline, over two days.
List<TimelineTrade> galleryTrades() {
  final start = DateTime(2026, 4, 6, 9);
  TimelineTrade trade(
    String symbol,
    int startHour,
    int hours,
    double pnl, {
    bool long = true,
  }) => TimelineTrade(
    entryTime: start.add(Duration(hours: startHour)),
    exitTime: start.add(Duration(hours: startHour + hours)),
    lane: symbol,
    side: long ? TradeSide.buy : TradeSide.sell,
    pnl: pnl,
  );

  return [
    trade('BTC', 0, 9, 1840),
    trade('BTC', 14, 6, -620, long: false),
    trade('BTC', 26, 12, 2400),
    trade('ETH', 2, 18, -940),
    trade('ETH', 24, 8, 1120),
    trade('ETH', 40, 5, 310),
    trade('SOL', 6, 22, 3200),
    trade('SOL', 34, 7, -480, long: false),
    trade('ARB', 10, 14, 760),
    trade('ARB', 30, 9, -210),
    trade('OP', 4, 26, 1580),
    trade('OP', 38, 10, 640),
    trade('LINK', 8, 16, 890),
    trade('LINK', 32, 11, -340, long: false),
    trade('AVAX', 12, 20, 1460),
    trade('DOGE', 0, 13, -780, long: false),
    trade('DOGE', 28, 15, 2100),
  ];
}

/// When the timeline's "now" is, so the open trades have an end to run to.
DateTime get galleryTimelineNow =>
    DateTime(2026, 4, 6, 9).add(const Duration(hours: 50));

/// A watchlist: twelve symbols, each with its own shape.
List<SparklineTile> galleryWatchlist() {
  SparklineTile tile(String name, String venue, double phase, double drift) {
    final values = galleryWave(
      40,
      base: 100,
      swing: 5,
      drift: drift,
      phase: phase,
    );
    final change = (values.last - values.first) / values.first * 100;
    return SparklineTile(
      label: name,
      subtitle: venue,
      values: values,
      valueLabel: '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%',
    );
  }

  return [
    tile('BTC', 'Binance', 0.2, 0.28),
    tile('ETH', 'Binance', 1.4, -0.16),
    tile('SOL', 'OKX', 2.6, 0.34),
    tile('ARB', 'OKX', 0.9, -0.22),
    tile('OP', 'Bybit', 3.1, 0.12),
    tile('LDO', 'Bybit', 1.9, -0.3),
    tile('UNI', 'Binance', 2.2, 0.06),
    tile('AAVE', 'Deribit', 0.5, 0.19),
    tile('DOGE', 'Binance', 1.1, 0.41),
    tile('AVAX', 'OKX', 2.8, -0.11),
    tile('LINK', 'Bybit', 0.7, 0.24),
    tile('DOT', 'Binance', 3.4, -0.27),
  ];
}

/// The bands of a stream graph: what the book was made of, month by month.
List<double> galleryBand(
  double base,
  double phase,
  double drift, {
  int periods = 24,
}) => [
  for (var i = 0; i < periods; i++)
    (base + sin(i / 3.4 + phase) * base * 0.45 + i * drift).clamp(2.0, 200.0),
];
