import '../entity/k_line_entity.dart';
import 'indicator.dart';

/// What one indicator's last computation left behind.
class _Entry {
  _Entry({
    required this.instance,
    required this.series,
    required this.profile,
    required this.length,
    required this.lastTime,
    required this.lastClose,
  });

  /// The very object the values were computed by.
  ///
  /// Two indicators with equal settings are the same indicator as far as the
  /// chart is concerned, but they are still free to compute different values —
  /// one reading a series handed in from outside, say. Holding the instance lets
  /// the cache tell "nothing has changed" from "a new object with the same
  /// settings", and only skip the work for the first.
  Indicator instance;

  IndicatorSeries series;
  IndicatorProfile? profile;

  /// How many candles the series was computed over.
  int length;

  /// Timestamp of the candle that was last, which is how a later list is
  /// recognised as the same series grown rather than a different one.
  DateTime? lastTime;

  /// Close of that candle, so a tick that moves it is noticed.
  double? lastClose;
}

/// Holds computed indicator values between frames.
///
/// A live feed moves the newest candle several times a second, and without a
/// cache every one of those ticks recomputes every indicator over the whole
/// history — work that grows with how much history is loaded rather than with
/// what changed. The cache spots that only the tail can have moved and offers
/// each indicator the chance to extend what it already has, through
/// [Indicator.extendSeries]. An indicator that cannot resume is recomputed in
/// full, so this is a shortcut where one exists and never a different answer.
///
/// Give a chart one cache and keep it for the chart's life; `KChartWidget` owns
/// one already. Entries are keyed by the indicator itself, which compares by
/// type and settings and ignores colour — so restyling an indicator reuses its
/// values, and changing a period computes new ones.
class IndicatorCache {
  final Map<Indicator, _Entry> _entries = <Indicator, _Entry>{};

  /// How many indicator computations the cache has served without recomputing.
  ///
  /// Useful in a test or a benchmark; nothing in the chart reads it.
  int get hits => _hits;
  int _hits = 0;

  /// How many it has had to compute from the first candle.
  int get fullComputations => _full;
  int _full = 0;

  /// How many it has extended from a previous series.
  int get extensions => _extensions;
  int _extensions = 0;

  /// Forgets everything, as though the cache were new.
  void clear() {
    _entries.clear();
  }

  /// Drops the entries for indicators no longer on the chart.
  void retain(Iterable<Indicator> indicators) {
    if (_entries.isEmpty) return;
    final keep = indicators.toSet();
    _entries.removeWhere((indicator, _) => !keep.contains(indicator));
  }

  /// The series for [indicator] over [candles], computed or reused.
  IndicatorSeries seriesFor(Indicator indicator, List<KLineEntity> candles) =>
      _resolve(indicator, candles).series;

  /// The profile for [indicator] over [candles], for the few that draw one.
  IndicatorProfile? profileFor(
    Indicator indicator,
    List<KLineEntity> candles,
  ) => _resolve(indicator, candles).profile;

  _Entry _resolve(Indicator indicator, List<KLineEntity> candles) {
    final cached = _entries[indicator];
    final last = candles.isEmpty ? null : candles.last;

    final candlesSitStill =
        cached != null &&
        cached.length == candles.length &&
        cached.lastTime == last?.dateTime &&
        cached.lastClose == last?.close;

    if (candlesSitStill && identical(cached.instance, indicator)) {
      // The same object over the same candles can only give the same answer.
      _hits++;
      return cached;
    }

    // A different object over candles that have not moved may well compute
    // something else, so there is nothing safe to reuse and nothing to gain
    // from trying: the tail that would be recomputed is the whole series.
    if (cached != null && !candlesSitStill) {
      final from = _resumableFrom(cached, candles);
      if (from != null) {
        final extended = indicator.extendSeries(candles, cached.series, from);
        if (extended != null) {
          _extensions++;
          cached
            ..instance = indicator
            ..series = extended
            // A profile reads the whole window at once and has no tail to
            // extend, so it is recomputed whenever the candles move.
            ..profile = indicator.computeProfile(candles)
            ..length = candles.length
            ..lastTime = last?.dateTime
            ..lastClose = last?.close;
          return cached;
        }
      }
    }

    _full++;
    final entry = _Entry(
      instance: indicator,
      series: indicator.compute(candles),
      profile: indicator.computeProfile(candles),
      length: candles.length,
      lastTime: last?.dateTime,
      lastClose: last?.close,
    );
    _entries[indicator] = entry;
    return entry;
  }

  /// The earliest index that can have changed since [cached] was computed, or
  /// null if the series cannot be picked up where it was left.
  ///
  /// The test is that the candle which used to be last is still in the same
  /// place, by timestamp. That covers the two things a feed does — move the
  /// newest candle, and roll it over into a new one — and rules out the two it
  /// must not be confused with: history paged in at the front, which moves every
  /// index along, and a replay rewinding, which takes candles away.
  ///
  /// The index returned is the *previous* last candle rather than the first new
  /// one, because the tick that appended a candle usually settles the one before
  /// it in the same breath.
  int? _resumableFrom(_Entry cached, List<KLineEntity> candles) {
    if (cached.length == 0 || candles.length < cached.length) return null;

    final boundary = candles[cached.length - 1].dateTime;
    // Without timestamps there is no way to tell a grown series from a
    // different one, so nothing is assumed.
    if (boundary == null || cached.lastTime == null) return null;
    if (boundary != cached.lastTime) return null;

    return cached.length - 1;
  }
}
