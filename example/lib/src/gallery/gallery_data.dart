// The sample data every gallery chart is drawn from.
//
// One copy, shared by the gallery page in the app and by the screenshot tool,
// so the pictures in the documentation are of the same charts the example
// actually runs. Nothing here is random: the shapes are trigonometric, so a
// screenshot taken today matches the one taken last release.
import 'dart:math';

import 'package:material_ui/material_ui.dart';
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

/// Trades seen from the inside, in R: the losers go about a stop's distance
/// against the position before they are cut, the winners dip a little first and
/// then run.
List<TradeExcursion> galleryExcursions({int count = 140}) => [
  for (var i = 0; i < count; i++)
    () {
      final wave = sin(i * 1.7).abs();
      final other = cos(i * 0.9).abs();
      if (i % 5 < 3) {
        // A loser: out near -1R, having gone a little further against, and
        // sometimes a little way for the position first.
        final loss = 0.85 + wave * 0.35;
        return TradeExcursion(
          pnl: -loss * 0.95,
          mae: loss + other * 0.15,
          mfe: 0.1 + other * 0.55,
        );
      }
      // A winner: a shallow dip, then a run of its own size.
      final win = 0.5 + wave * 2.6 + other * 0.9;
      return TradeExcursion(
        pnl: win,
        mae: other * 0.7 + (i % 11 == 0 ? 0.9 : 0),
        mfe: win + 0.15 + wave * 0.8,
      );
    }(),
];

/// A volatility surface: a smile that deepens into short expiries, and a term
/// structure that slopes up a little.
({List<double> strikes, List<String> expiries, List<List<double?>> vols})
galleryVolatilitySurface() {
  const strikes = [80.0, 85.0, 90.0, 95.0, 100.0, 105.0, 110.0, 115.0, 120.0];
  const expiries = ['1W', '2W', '1M', '2M', '3M', '6M', '1Y'];
  const months = [0.25, 0.5, 1.0, 2.0, 3.0, 6.0, 12.0];
  return (
    strikes: strikes,
    expiries: expiries,
    vols: [
      for (var e = 0; e < expiries.length; e++)
        [
          for (var s = 0; s < strikes.length; s++)
            // No quote for the far wings of the shortest expiries.
            e < 2 && (s == 0 || s == strikes.length - 1)
                ? null
                : 0.22 +
                      0.01 * log(1 + months[e]) +
                      pow((strikes[s] - 100) / 100, 2) *
                          (1.4 / sqrt(months[e])) -
                      (strikes[s] - 100) / 100 * 0.12,
        ],
    ],
  );
}

/// Candidate portfolios scattered under a concave frontier.
List<PortfolioPoint> galleryPortfolios({int count = 160}) => [
  for (var i = 0; i < count; i++)
    () {
      final risk = 0.07 + (i / count) * 0.23;
      // The best return a portfolio of this risk can have.
      final best = 0.02 + 0.115 * sqrt((risk - 0.06) / 0.24);
      // How far short of it this one falls, deterministic and never negative.
      final shortfall =
          (0.012 + sin(i * 2.1).abs() * 0.03) * (i % 4 == 0 ? 0.2 : 1);
      return PortfolioPoint(risk: risk, expectedReturn: best - shortfall);
    }(),
];

/// Two futures curves: today's in mild contango, and last month's flatter.
({List<FuturesContract> today, List<FuturesContract> before})
galleryFuturesCurves() {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return (
    today: [
      for (var i = 0; i < 12; i++)
        FuturesContract(
          label: months[i],
          price: 71.4 + i * 0.55 - i * i * 0.012 + sin(i / 2.3) * 0.18,
        ),
    ],
    before: [
      for (var i = 0; i < 12; i++)
        FuturesContract(
          label: months[i],
          price: 69.6 + i * 0.2 - i * i * 0.004 + sin(i / 2.3) * 0.12,
        ),
    ],
  );
}

/// Eight weeks of trades opened through the day: busy at the open and again in
/// the afternoon, quiet at night and at weekends.
List<SeasonalSample> galleryActivity({int weeks = 8}) => [
  for (var day = 0; day < weeks * 7; day++)
    for (var hour = 0; hour < 24; hour++)
      SeasonalSample(
        time: DateTime(2026, 3, 2).add(Duration(days: day, hours: hour)),
        value:
            (day % 7 >= 5 ? 0.15 : 1.0) *
            (exp(-pow(hour - 9.5, 2) / 6) * 9 +
                exp(-pow(hour - 15.5, 2) / 5) * 6 +
                (hour >= 1 && hour <= 6 ? 0.2 : 1.2) +
                sin(day * 1.3 + hour) * 0.6),
      ),
];

// ── Models and training ────────────────────────────────────────────────────

/// A training loss that falls fast and flattens, with noise; a validation loss
/// that follows it, then turns up as the model starts to overfit.
({List<TrainingPoint> train, List<TrainingPoint> validation})
galleryLossCurves({int points = 160}) {
  final train = <TrainingPoint>[];
  final validation = <TrainingPoint>[];
  for (var i = 0; i < points; i++) {
    final step = i * 25.0;
    final base = 0.55 + 3.4 * exp(-i / 22);
    final noise = sin(i * 1.9) * 0.07 + cos(i * 0.7) * 0.05;
    train.add(TrainingPoint(step, base + noise));
    final overfit = i > 90 ? (i - 90) * 0.0042 : 0.0;
    validation.add(TrainingPoint(step, base + 0.16 + overfit + noise * 0.55));
  }
  return (train: train, validation: validation);
}

/// Three learning rates on one task: one learns, one is slow, one blows up.
List<TrainingRun> galleryLearningRates({int points = 120}) => [
  TrainingRun(
    label: 'lr 3e-4',
    points: [
      for (var i = 0; i < points; i++)
        TrainingPoint(i * 50.0, 0.8 + 5.2 * exp(-i / 18) + sin(i * 2.3) * 0.05),
    ],
  ),
  TrainingRun(
    label: 'lr 3e-5',
    points: [
      for (var i = 0; i < points; i++)
        TrainingPoint(i * 50.0, 1.6 + 4.4 * exp(-i / 60) + cos(i * 1.7) * 0.04),
    ],
  ),
  TrainingRun(
    label: 'lr 3e-3',
    points: [
      for (var i = 0; i < points; i++)
        TrainingPoint(
          i * 50.0,
          i < 46
              ? 0.9 + 5.0 * exp(-i / 14) + sin(i * 2.9) * 0.06
              : (i < 50 ? 1.4 * pow(2.6, (i - 45).toDouble()) : double.nan),
        ),
    ],
  ),
];

/// Eight models on a loss that falls as a power of compute, with scatter.
List<ScalingPoint> galleryScaling() => [
  for (var i = 0; i < 8; i++)
    ScalingPoint(
      scale: 1e18 * pow(5.0, i),
      loss:
          14.0 *
          pow(1e18 * pow(5.0, i), -0.0325).toDouble() *
          (1 + sin(i * 2.7) * 0.012),
      label: ['125M', '350M', '760M', '1.3B', '2.7B', '6.7B', '13B', '30B'][i],
    ),
];

/// A learning-rate by batch-size sweep with a valley and a cliff.
List<SweepTrial> gallerySweep() {
  const rates = [1e-4, 3e-4, 1e-3, 3e-3, 1e-2];
  const batches = [16.0, 32.0, 64.0, 128.0, 256.0];
  return [
    for (final lr in rates)
      for (final bs in batches)
        SweepTrial(
          x: lr,
          y: bs,
          score:
              1.9 +
              pow(log(lr / 1.2e-3) / ln10, 2) * 0.55 +
              pow(log(bs / 80) / ln10, 2) * 0.35 +
              (lr >= 1e-2 && bs <= 32 ? 1.4 : 0),
        ),
  ];
}

/// Training jobs over two days across four pods.
List<TrainingJob> galleryJobs() {
  final t0 = DateTime(2026, 9, 1, 6);
  TrainingJob job(
    String name,
    String node,
    double startHour,
    double? hours,
    JobStatus status, {
    int gpus = 64,
  }) => TrainingJob(
    name: name,
    node: node,
    start: t0.add(Duration(minutes: (startHour * 60).round())),
    end: hours == null
        ? null
        : t0.add(Duration(minutes: ((startHour + hours) * 60).round())),
    status: status,
    gpus: gpus,
  );
  return [
    job('pretrain-7b', 'pod-a', 0, 30, JobStatus.completed, gpus: 256),
    job('sft-7b', 'pod-a', 31, 9, JobStatus.completed),
    job('dpo-7b', 'pod-a', 41, null, JobStatus.running),
    job('pretrain-13b', 'pod-b', 2, 14, JobStatus.preempted, gpus: 512),
    job('pretrain-13b·2', 'pod-b', 17, 20, JobStatus.failed, gpus: 512),
    job('pretrain-13b·3', 'pod-b', 39, null, JobStatus.running, gpus: 512),
    job('eval-sweep', 'pod-c', 4, 3, JobStatus.completed, gpus: 8),
    job('ablation-1', 'pod-c', 8, 6, JobStatus.completed, gpus: 16),
    job('ablation-2', 'pod-c', 15, 2, JobStatus.cancelled, gpus: 16),
    job('ablation-3', 'pod-c', 18, 7, JobStatus.completed, gpus: 16),
    job('rl-tune', 'pod-d', 10, 12, JobStatus.completed, gpus: 32),
    job('rl-tune·2', 'pod-d', 24, 5, JobStatus.failed, gpus: 32),
    job('rl-tune·3', 'pod-d', 30, null, JobStatus.running, gpus: 32),
  ];
}

/// Six models across six benchmarks; the last is perplexity, where lower wins.
({List<String> models, List<String> benchmarks, List<List<double?>> scores})
galleryBenchmarkScores() => (
  models: [
    'Atlas-L',
    'Atlas-M',
    'Borealis',
    'Cobalt-70B',
    'Delta-8B',
    'Echo-mini',
  ],
  benchmarks: ['MMLU', 'GSM8K', 'HumanEval', 'MATH', 'GPQA', 'Perplexity'],
  scores: [
    [88.4, 95.1, 90.2, 72.0, 56.1, 4.6],
    [84.9, 91.0, 84.8, 61.5, 48.7, 5.0],
    [86.7, 92.4, 88.1, 66.3, 52.9, 4.8],
    [82.1, 88.9, 79.4, 53.0, 41.5, 5.4],
    [73.6, 79.2, 68.0, 36.8, 31.0, 6.3],
    [62.0, 58.3, null, 21.0, 24.8, 7.9],
  ],
);

/// Fourteen models by price per million tokens and a quality score.
List<ModelPoint> galleryModels() => const [
  ModelPoint(
    name: 'Atlas-L',
    cost: 15,
    score: 88.4,
    size: 200000,
    group: 'Atlas',
  ),
  ModelPoint(
    name: 'Atlas-M',
    cost: 3,
    score: 84.9,
    size: 200000,
    group: 'Atlas',
  ),
  ModelPoint(
    name: 'Atlas-S',
    cost: 0.25,
    score: 75.2,
    size: 200000,
    group: 'Atlas',
  ),
  ModelPoint(
    name: 'Borealis',
    cost: 10,
    score: 86.7,
    size: 128000,
    group: 'Borealis',
  ),
  ModelPoint(
    name: 'Borealis-mini',
    cost: 0.6,
    score: 79.5,
    size: 128000,
    group: 'Borealis',
  ),
  ModelPoint(
    name: 'Cobalt-70B',
    cost: 0.9,
    score: 82.1,
    size: 32000,
    group: 'Open',
  ),
  ModelPoint(
    name: 'Cobalt-8B',
    cost: 0.15,
    score: 69.0,
    size: 32000,
    group: 'Open',
  ),
  ModelPoint(
    name: 'Delta-8B',
    cost: 0.2,
    score: 73.6,
    size: 128000,
    group: 'Open',
  ),
  ModelPoint(
    name: 'Echo-mini',
    cost: 0.08,
    score: 62.0,
    size: 8000,
    group: 'Open',
  ),
  ModelPoint(
    name: 'Foxtrot',
    cost: 30,
    score: 84.0,
    size: 100000,
    group: 'Foxtrot',
  ),
  ModelPoint(
    name: 'Foxtrot-fast',
    cost: 5,
    score: 78.8,
    size: 100000,
    group: 'Foxtrot',
  ),
  ModelPoint(
    name: 'Golf-XL',
    cost: 20,
    score: 83.2,
    size: 1000000,
    group: 'Golf',
  ),
  ModelPoint(
    name: 'Golf-Flash',
    cost: 0.4,
    score: 76.9,
    size: 1000000,
    group: 'Golf',
  ),
  ModelPoint(
    name: 'Hotel',
    cost: 6,
    score: 70.5,
    size: 16000,
    group: 'Foxtrot',
  ),
];

/// Latency every fifteen minutes for a day, with a bad hour in the afternoon.
List<LatencySample> galleryLatency({int count = 96}) => [
  for (var i = 0; i < count; i++)
    () {
      final hour = i / 4;
      final load = 1 + 0.35 * sin((hour - 6) / 24 * 2 * pi).clamp(-1, 1);
      final incident = (i >= 58 && i <= 66)
          ? 1 + (1 - (i - 62).abs() / 5) * 1.6
          : 1.0;
      final p50 =
          420 * load * (1 + sin(i * 1.3) * 0.04) * (incident > 1 ? 1.3 : 1);
      return LatencySample(
        time: DateTime(2026, 9, 1).add(Duration(minutes: i * 15)),
        p50: p50,
        p95: p50 * (2.0 * incident + 0.2 * sin(i * 0.7)),
        p99: p50 * (3.4 * incident + 0.5 * cos(i * 0.5)),
      );
    }(),
];

/// Fourteen days of tokens served, with a cache that warms up.
List<UsageBucket> galleryUsage({int days = 14}) => [
  for (var i = 0; i < days; i++)
    () {
      final traffic = 1 + i * 0.05 + sin(i * 1.2) * 0.18;
      final cacheShare = (0.15 + i * 0.045).clamp(0.0, 0.7);
      final prompt = 42e6 * traffic;
      return UsageBucket(
        time: DateTime(2026, 9, 1).add(Duration(days: i)),
        inputTokens: prompt * (1 - cacheShare),
        cachedTokens: prompt * cacheShare,
        outputTokens: 9e6 * traffic,
        cost:
            prompt * (1 - cacheShare) * 3e-6 +
            prompt * cacheShare * 0.3e-6 +
            9e6 * traffic * 15e-6,
      );
    }(),
];

/// An evaluation across eight categories, with very different sample sizes.
List<EvalCategory> galleryEval() => const [
  EvalCategory(name: 'Arithmetic', passed: 188, failed: 12),
  EvalCategory(name: 'Word problems', passed: 142, failed: 58),
  EvalCategory(name: 'Coding', passed: 301, failed: 44, skipped: 7),
  EvalCategory(name: 'Long context', passed: 64, failed: 36, skipped: 9),
  EvalCategory(name: 'Tool use', passed: 77, failed: 23),
  EvalCategory(name: 'Safety', passed: 480, failed: 20),
  EvalCategory(name: 'Translation', passed: 9, failed: 1),
  EvalCategory(name: 'Reasoning', passed: 118, failed: 82),
];

/// A completion with the surprisal of each token: mostly sure, doubtful where
/// it had to pick a fact — and, there, what it was weighing instead.
List<TokenScore> galleryTokens() {
  const words = [
    ('The', 0.3),
    (' capital', 0.9),
    (' of', 0.1),
    (' Australia', 2.1),
    (' is', 0.2),
    (' Canberra', 3.6),
    (',', 0.4),
    (' not', 2.8),
    (' Sydney', 1.9),
    (' as', 1.2),
    (' many', 1.5),
    (' people', 0.6),
    (' assume', 0.9),
    ('.\n', 0.5),
    ('It', 1.1),
    (' was', 0.8),
    (' chosen', 2.4),
    (' in', 0.7),
    (' 1908', 4.8),
    (' as', 1.3),
    (' a', 0.2),
    (' compromise', 2.2),
    (' between', 0.4),
    (' the', 0.2),
    (' two', 0.8),
    (' largest', 1.4),
    (' cities', 0.3),
    ('.', 0.2),
  ];
  const instead = {
    ' Canberra': [
      TokenAlternative(' Sydney', 0.62),
      TokenAlternative(' Melbourne', 0.21),
      TokenAlternative(' Brisbane', 0.04),
    ],
    ' 1908': [
      TokenAlternative(' 1913', 0.31),
      TokenAlternative(' 1901', 0.22),
      TokenAlternative(' 1927', 0.14),
    ],
    ' not': [TokenAlternative(' and', 0.38), TokenAlternative(' which', 0.21)],
    ' chosen': [
      TokenAlternative(' founded', 0.27),
      TokenAlternative(' built', 0.19),
      TokenAlternative(' selected', 0.12),
    ],
  };
  return [
    for (final (token, s) in words)
      TokenScore(
        token,
        s,
        probability: exp(-s),
        alternatives: instead[token] ?? const [],
      ),
  ];
}
