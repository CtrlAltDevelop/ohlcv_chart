import '../entity/k_line_entity.dart';

/// Finds the candle a drawing is anchored to, by its timestamp.
///
/// A drawing remembers when it was placed rather than where, so every anchor
/// has to be turned back into an index before it can be drawn. Doing that with
/// `indexWhere` walks the series once per anchor per frame — with a long
/// history and a handful of drawings on it, that is the most expensive thing in
/// the frame, and it grows with how much history is loaded rather than with
/// what is on screen.
///
/// This builds the lookup once and keeps it until the series changes. Give a
/// chart one and keep it for the chart's life; `KChartWidget` owns one already.
class CandleIndex {
  Map<DateTime, int> _byTime = const <DateTime, int>{};
  List<KLineEntity>? _source;
  int _length = 0;
  DateTime? _lastTime;

  /// How many candles have been walked to build the lookup.
  ///
  /// Useful in a test or a benchmark; nothing in the chart reads it. It counts
  /// the work the old `indexWhere` did on every anchor, so a chart that keeps
  /// it near the length of the series is reusing the lookup as intended.
  int get scans => _scans;
  int _scans = 0;

  /// How many anchors have been resolved through it.
  int get lookups => _lookups;
  int _lookups = 0;

  /// Forgets the lookup, as though the index were new.
  void clear() {
    _byTime = const <DateTime, int>{};
    _source = null;
    _length = 0;
    _lastTime = null;
  }

  /// The index of the first candle stamped [time], or null if there is none.
  ///
  /// First rather than any, which is what `indexWhere` answered: a series with
  /// a timestamp twice still draws the anchor where it always did.
  int? indexOf(List<KLineEntity> candles, DateTime? time) {
    if (time == null) return null;
    _lookups++;
    _refresh(candles);
    return _byTime[time];
  }

  /// Rebuilds the lookup when the series it was built from has moved on.
  ///
  /// A live feed appends to the same list, so identity alone would not notice;
  /// the length and the newest timestamp are what say the series has changed,
  /// the same test [IndicatorCache] makes.
  void _refresh(List<KLineEntity> candles) {
    final last = candles.isEmpty ? null : candles.last.dateTime;
    if (identical(_source, candles) &&
        _length == candles.length &&
        _lastTime == last) {
      return;
    }

    final built = <DateTime, int>{};
    for (var i = 0; i < candles.length; i++) {
      final at = candles[i].dateTime;
      if (at == null) continue;
      built.putIfAbsent(at, () => i);
    }
    _scans += candles.length;

    _byTime = built;
    _source = candles;
    _length = candles.length;
    _lastTime = last;
  }
}
