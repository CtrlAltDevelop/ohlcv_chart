/// The indicator maths, as pure functions over a candle list.
///
/// Each returns one value per candle, `null` where the indicator has not warmed
/// up yet. `DataUtil` writes these same results onto the candles for callers
/// that read the entity fields; the chart uses the series directly, so several
/// periods of one indicator can be drawn at once.
///
/// Every window is inclusive of the current candle.
library;

import 'dart:math';

import '../entity/k_line_entity.dart';
import 'indicator.dart';

/// Simple moving average of the close over [period] candles.
List<double?> smaSeries(List<KLineEntity> candles, int period) {
  final out = List<double?>.filled(candles.length, null);
  if (period <= 0) return out;

  var sum = 0.0;
  for (var i = 0; i < candles.length; i++) {
    sum += candles[i].close;
    if (i >= period) sum -= candles[i - period].close;
    if (i >= period - 1) out[i] = sum / period;
  }
  return out;
}

/// Exponential moving average of the close, seeded with the first close.
List<double?> emaSeries(List<KLineEntity> candles, int period) {
  final out = List<double?>.filled(candles.length, null);
  if (period <= 0) return out;

  final weight = 2 / (period + 1);
  var previous = 0.0;
  for (var i = 0; i < candles.length; i++) {
    previous = i == 0
        ? candles[i].close
        : candles[i].close * weight + previous * (1 - weight);
    out[i] = previous;
  }
  return out;
}

/// Bollinger bands: the [period] average of the close, and [deviations]
/// standard deviations either side of it.
({List<double?> upper, List<double?> middle, List<double?> lower}) bollSeries(
  List<KLineEntity> candles,
  int period,
  double deviations,
) {
  final middle = smaSeries(candles, period);
  final upper = List<double?>.filled(candles.length, null);
  final lower = List<double?>.filled(candles.length, null);
  if (period <= 1) return (upper: upper, middle: middle, lower: lower);

  for (var i = 0; i < candles.length; i++) {
    // One candle later than the average, matching the original band warm-up.
    if (i < period) continue;
    final mean = middle[i];
    if (mean == null) continue;

    var squared = 0.0;
    for (var j = i - period + 1; j <= i; j++) {
      final difference = candles[j].close - mean;
      squared += difference * difference;
    }
    final deviation = sqrt(squared / (period - 1));
    upper[i] = mean + deviations * deviation;
    lower[i] = mean - deviations * deviation;
  }
  return (upper: upper, middle: middle, lower: lower);
}

/// Parabolic SAR, one dot per candle.
List<double?> sarSeries(
  List<KLineEntity> candles, {
  double start = 0.02,
  double step = 0.02,
  double maximum = 0.2,
}) {
  final out = List<double?>.filled(candles.length, null);

  var accelerationFactor = start;
  // -100 marks "no extreme point yet", as it does in the original.
  var extreme = -100.0;
  var rising = false;
  var sar = 0.0;

  for (var i = 0; i < candles.length; i++) {
    final previousSar = sar;
    final high = candles[i].high;
    final low = candles[i].low;

    if (rising) {
      if (extreme == -100 || extreme < high) {
        extreme = high;
        accelerationFactor = min(accelerationFactor + step, maximum);
      }
      sar = previousSar + accelerationFactor * (extreme - previousSar);
      final lowest = min(candles[max(1, i) - 1].low, low);
      if (sar > low) {
        sar = extreme;
        // Cleared rather than reset to `start`: the first candle of the new
        // trend re-seeds the extreme and adds one step, landing back on start.
        accelerationFactor = 0;
        extreme = -100;
        rising = !rising;
      } else if (sar > lowest) {
        sar = lowest;
      }
    } else {
      if (extreme == -100 || extreme > low) {
        extreme = low;
        accelerationFactor = min(accelerationFactor + step, maximum);
      }
      sar = previousSar + accelerationFactor * (extreme - previousSar);
      final highest = max(candles[max(1, i) - 1].high, high);
      if (sar < high) {
        sar = extreme;
        accelerationFactor = 0;
        extreme = -100;
        rising = !rising;
      } else if (sar < highest) {
        sar = highest;
      }
    }
    out[i] = sar;
  }
  return out;
}

/// Volume-weighted average price, accumulated from the first candle.
List<double?> vwapSeries(List<KLineEntity> candles) {
  final out = List<double?>.filled(candles.length, null);
  var value = 0.0;
  var volume = 0.0;

  for (var i = 0; i < candles.length; i++) {
    final typical = _typicalPrice(candles[i]);
    value += typical * candles[i].vol;
    volume += candles[i].vol;
    out[i] = volume == 0 ? typical : value / volume;
  }
  return out;
}

/// VWAP measured from [anchor] rather than from the start of the series.
///
/// The average is what a position opened at [anchor] has paid on average since,
/// which is why the anchor is usually put on a swing, a gap or a session open.
/// Candles before the anchor have no value.
List<double?> anchoredVwapSeries(List<KLineEntity> candles, int anchor) {
  final out = List<double?>.filled(candles.length, null);
  if (candles.isEmpty) return out;

  final from = anchor.clamp(0, candles.length - 1);
  var value = 0.0;
  var volume = 0.0;

  for (var i = from; i < candles.length; i++) {
    final typical = _typicalPrice(candles[i]);
    value += typical * candles[i].vol;
    volume += candles[i].vol;
    out[i] = volume == 0 ? typical : value / volume;
  }
  return out;
}

/// Pivot levels for every candle, one list per level: `P, R1, R2, R3, S1, S2,
/// S3`.
///
/// Each session's levels come from the session before it, so they are flat
/// across the session and step at the boundary — and the first session has
/// none, having nothing behind it. [sessionOf] says which session a candle
/// belongs to; the default is the calendar day the candle is stamped with.
List<List<double?>> pivotSeries(
  List<KLineEntity> candles, {
  PivotMethod method = PivotMethod.standard,
  Object? Function(KLineEntity candle)? sessionOf,
}) {
  final levels = [
    for (var i = 0; i < 7; i++) List<double?>.filled(candles.length, null),
  ];
  if (candles.isEmpty) return levels;

  Object? sessionKey(KLineEntity candle) {
    if (sessionOf != null) return sessionOf(candle);
    final time = candle.dateTime;
    return time == null ? null : (time.year, time.month, time.day);
  }

  // Walked once: each candle carries the levels worked out from the session
  // that closed before it, while the running high, low and close of the
  // session it is in are gathered for the session after.
  Object? current;
  double? high;
  double? low;
  double? close;
  List<double?>? previous;

  for (var i = 0; i < candles.length; i++) {
    final candle = candles[i];
    final key = sessionKey(candle);

    if (i == 0 || key != current) {
      if (high != null && low != null && close != null) {
        previous = _pivotLevels(high, low, close, method);
      }
      current = key;
      high = candle.high;
      low = candle.low;
    } else {
      high = max(high!, candle.high);
      low = min(low!, candle.low);
    }
    close = candle.close;

    if (previous != null) {
      for (var level = 0; level < levels.length; level++) {
        levels[level][i] = previous[level];
      }
    }
  }
  return levels;
}

/// The seven levels a session of [high], [low] and [close] gives the next one.
List<double?> _pivotLevels(
  double high,
  double low,
  double close,
  PivotMethod method,
) {
  final range = high - low;
  final pivot = (high + low + close) / 3;

  switch (method) {
    case PivotMethod.standard:
      return [
        pivot,
        2 * pivot - low,
        pivot + range,
        high + 2 * (pivot - low),
        2 * pivot - high,
        pivot - range,
        low - 2 * (high - pivot),
      ];
    case PivotMethod.fibonacci:
      return [
        pivot,
        pivot + 0.382 * range,
        pivot + 0.618 * range,
        pivot + range,
        pivot - 0.382 * range,
        pivot - 0.618 * range,
        pivot - range,
      ];
    case PivotMethod.camarilla:
      return [
        pivot,
        close + range * 1.1 / 12,
        close + range * 1.1 / 6,
        close + range * 1.1 / 4,
        close - range * 1.1 / 12,
        close - range * 1.1 / 6,
        close - range * 1.1 / 4,
      ];
  }
}

/// Volume gathered into [bins] price bands across the candles given.
///
/// Each candle's volume is spread evenly over the bands its range covers,
/// which is the usual approximation when only OHLCV is known — the ticks
/// inside the candle are not. [valueArea] is the share of the volume the value
/// area holds, grown outwards from the busiest band.
IndicatorProfile volumeProfile(
  List<KLineEntity> candles, {
  int bins = 24,
  double valueArea = 0.7,
}) {
  if (candles.isEmpty || bins <= 0) {
    return const IndicatorProfile(bins: [], pointOfControl: -1);
  }

  var low = double.infinity;
  var high = -double.infinity;
  for (final candle in candles) {
    low = min(low, candle.low);
    high = max(high, candle.high);
  }
  if (!low.isFinite || !high.isFinite || high <= low) {
    return const IndicatorProfile(bins: [], pointOfControl: -1);
  }

  final step = (high - low) / bins;
  final volumes = List<double>.filled(bins, 0);
  final upVolumes = List<double>.filled(bins, 0);

  for (final candle in candles) {
    final first = ((candle.low - low) / step).floor().clamp(0, bins - 1);
    final last = ((candle.high - low) / step).ceil().clamp(1, bins) - 1;
    final spread = last - first + 1;
    final share = candle.vol / spread;
    final rose = candle.close >= candle.open;

    for (var bin = first; bin <= last; bin++) {
      volumes[bin] += share;
      if (rose) upVolumes[bin] += share;
    }
  }

  final bands = [
    for (var i = 0; i < bins; i++)
      ProfileBin(
        low: low + step * i,
        high: low + step * (i + 1),
        volume: volumes[i],
        upVolume: upVolumes[i],
      ),
  ];

  var poc = 0;
  var total = 0.0;
  for (var i = 0; i < bins; i++) {
    total += volumes[i];
    if (volumes[i] > volumes[poc]) poc = i;
  }
  if (total <= 0) {
    return IndicatorProfile(bins: bands, pointOfControl: -1);
  }

  // The value area grows out from the busiest band, always taking whichever
  // neighbour holds more, until it covers its share of the volume.
  final target = total * valueArea.clamp(0.0, 1.0);
  var lowEdge = poc;
  var highEdge = poc;
  var covered = volumes[poc];
  while (covered < target && (lowEdge > 0 || highEdge < bins - 1)) {
    final below = lowEdge > 0 ? volumes[lowEdge - 1] : -1;
    final above = highEdge < bins - 1 ? volumes[highEdge + 1] : -1;
    if (above >= below) {
      highEdge++;
      covered += above;
    } else {
      lowEdge--;
      covered += below;
    }
  }

  return IndicatorProfile(
    bins: bands,
    pointOfControl: poc,
    valueAreaLow: bands[lowEdge].low,
    valueAreaHigh: bands[highEdge].high,
  );
}

/// MACD: the [fast] and [slow] average spread, its [signal] average, and twice
/// the gap between the two as the histogram.
({List<double?> macd, List<double?> dif, List<double?> dea}) macdSeries(
  List<KLineEntity> candles, {
  int fast = 12,
  int slow = 26,
  int signal = 9,
}) {
  final macd = List<double?>.filled(candles.length, null);
  final dif = List<double?>.filled(candles.length, null);
  final dea = List<double?>.filled(candles.length, null);

  final fastWeight = 2 / (fast + 1);
  final slowWeight = 2 / (slow + 1);
  final signalWeight = 2 / (signal + 1);

  var fastEma = 0.0;
  var slowEma = 0.0;
  var signalEma = 0.0;

  for (var i = 0; i < candles.length; i++) {
    final close = candles[i].close;
    if (i == 0) {
      fastEma = close;
      slowEma = close;
    } else {
      fastEma = fastEma * (1 - fastWeight) + close * fastWeight;
      slowEma = slowEma * (1 - slowWeight) + close * slowWeight;
    }
    final difference = fastEma - slowEma;
    signalEma = signalEma * (1 - signalWeight) + difference * signalWeight;

    dif[i] = difference;
    dea[i] = signalEma;
    macd[i] = (difference - signalEma) * 2;
  }
  return (macd: macd, dif: dif, dea: dea);
}

/// Stochastic oscillator: %K, %D and %J over [period] candles.
({List<double?> k, List<double?> d, List<double?> j}) kdjSeries(
  List<KLineEntity> candles, {
  int period = 9,
  int kSmoothing = 3,
  int dSmoothing = 3,
}) {
  final k = List<double?>.filled(candles.length, null);
  final d = List<double?>.filled(candles.length, null);
  final j = List<double?>.filled(candles.length, null);
  if (candles.isEmpty) return (k: k, d: d, j: j);

  var previousK = 50.0;
  var previousD = 50.0;
  k[0] = previousK;
  d[0] = previousD;
  j[0] = 50.0;

  for (var i = 1; i < candles.length; i++) {
    final entity = candles[i];
    var low = entity.low;
    var high = entity.high;
    for (var window = max(0, i - period + 1); window < i; window++) {
      low = min(low, candles[window].low);
      high = max(high, candles[window].high);
    }

    var rsv = (entity.close - low) * 100.0 / (high - low);
    if (rsv.isNaN) rsv = 0;

    final currentK = ((kSmoothing - 1) * previousK + rsv) / kSmoothing;
    final currentD = ((dSmoothing - 1) * previousD + currentK) / dSmoothing;
    previousK = currentK;
    previousD = currentD;

    k[i] = currentK;
    d[i] = currentD;
    j[i] = 3 * currentK - 2 * currentD;
  }
  return (k: k, d: d, j: j);
}

/// Relative strength index over [period] candles.
List<double?> rsiSeries(List<KLineEntity> candles, int period) {
  final out = List<double?>.filled(candles.length, null);
  if (period <= 0) return out;

  var gainEma = 0.0;
  var moveEma = 0.0;

  for (var i = 0; i < candles.length; i++) {
    double? rsi;
    if (i == 0) {
      rsi = 0;
    } else {
      final change = candles[i].close - candles[i - 1].close;
      gainEma = (max(0, change) + (period - 1) * gainEma) / period;
      moveEma = (change.abs() + (period - 1) * moveEma) / period;
      rsi = gainEma / moveEma * 100;
    }
    if (i < period - 1 || rsi.isNaN) rsi = null;
    out[i] = rsi;
  }
  return out;
}

/// Williams %R over [period] candles, from -100 to 0.
List<double?> wrSeries(List<KLineEntity> candles, int period) {
  final out = List<double?>.filled(candles.length, null);

  for (var i = 0; i < candles.length; i++) {
    var highest = -double.maxFinite;
    var lowest = double.maxFinite;
    for (var window = max(0, i - period); window <= i; window++) {
      highest = max(highest, candles[window].high);
      lowest = min(lowest, candles[window].low);
    }
    if (i < period - 1) {
      // Parked just outside the band until the window fills.
      out[i] = -10;
      continue;
    }
    final r = -100 * (highest - candles[i].close) / (highest - lowest);
    out[i] = r.isNaN ? null : r;
  }
  return out;
}

/// Commodity channel index over [period] candles.
List<double?> cciSeries(List<KLineEntity> candles, int period) {
  final out = List<double?>.filled(candles.length, null);

  for (var i = 0; i < candles.length; i++) {
    final start = max(0, i - period + 1);
    final length = i - start + 1;

    var sum = 0.0;
    for (var window = start; window <= i; window++) {
      sum += _typicalPrice(candles[window]);
    }
    final mean = sum / length;

    var deviation = 0.0;
    for (var window = start; window <= i; window++) {
      deviation += (mean - _typicalPrice(candles[window])).abs();
    }
    final meanDeviation = deviation / length;

    final cci = (_typicalPrice(candles[i]) - mean) / 0.015 / meanDeviation;
    out[i] = cci.isNaN ? 0.0 : cci;
  }
  return out;
}

/// Wilder's average true range over [period] candles.
List<double?> atrSeries(List<KLineEntity> candles, int period) {
  final out = List<double?>.filled(candles.length, null);
  if (period <= 0) return out;

  var seed = 0.0;
  double? atr;

  for (var i = 0; i < candles.length; i++) {
    final range = i == 0
        ? candles[i].high - candles[i].low
        : trueRange(candles[i], candles[i - 1]);

    if (i < period) {
      seed += range;
      // Wilder seeds the average with the mean of the first window.
      atr = i == period - 1 ? seed / period : null;
    } else {
      atr = (atr! * (period - 1) + range) / period;
    }
    out[i] = atr;
  }
  return out;
}

/// On-balance volume, starting from zero.
List<double?> obvSeries(List<KLineEntity> candles) {
  final out = List<double?>.filled(candles.length, null);
  var obv = 0.0;

  for (var i = 0; i < candles.length; i++) {
    if (i > 0) {
      final previousClose = candles[i - 1].close;
      if (candles[i].close > previousClose) {
        obv += candles[i].vol;
      } else if (candles[i].close < previousClose) {
        obv -= candles[i].vol;
      }
    }
    out[i] = obv;
  }
  return out;
}

/// Money flow index over [period] candles, from 0 to 100.
List<double?> mfiSeries(List<KLineEntity> candles, int period) {
  final out = List<double?>.filled(candles.length, null);
  if (period <= 0) return out;

  final positive = List<double>.filled(candles.length, 0);
  final negative = List<double>.filled(candles.length, 0);

  for (var i = 1; i < candles.length; i++) {
    final typical = _typicalPrice(candles[i]);
    final previousTypical = _typicalPrice(candles[i - 1]);
    final flow = typical * candles[i].vol;
    if (typical > previousTypical) positive[i] = flow;
    if (typical < previousTypical) negative[i] = flow;
  }

  for (var i = period; i < candles.length; i++) {
    var positiveFlow = 0.0;
    var negativeFlow = 0.0;
    for (var window = i - period + 1; window <= i; window++) {
      positiveFlow += positive[window];
      negativeFlow += negative[window];
    }
    // All the flow in one direction pins the index to its bounds.
    out[i] = negativeFlow == 0
        ? (positiveFlow == 0 ? 50 : 100)
        : 100 - 100 / (1 + positiveFlow / negativeFlow);
  }
  return out;
}

/// Wilder's directional movement system over [period] candles.
({List<double?> plusDi, List<double?> minusDi, List<double?> adx}) dmiSeries(
  List<KLineEntity> candles,
  int period,
) {
  final plusDi = List<double?>.filled(candles.length, null);
  final minusDi = List<double?>.filled(candles.length, null);
  final adxOut = List<double?>.filled(candles.length, null);
  if (period <= 0) return (plusDi: plusDi, minusDi: minusDi, adx: adxOut);

  var smoothedRange = 0.0;
  var smoothedPlus = 0.0;
  var smoothedMinus = 0.0;
  var dxSeed = 0.0;
  double? adx;

  for (var i = 1; i < candles.length; i++) {
    final previous = candles[i - 1];
    final range = trueRange(candles[i], previous);
    final up = candles[i].high - previous.high;
    final down = previous.low - candles[i].low;
    final plus = up > down && up > 0 ? up : 0.0;
    final minus = down > up && down > 0 ? down : 0.0;

    if (i <= period) {
      smoothedRange += range;
      smoothedPlus += plus;
      smoothedMinus += minus;
    } else {
      smoothedRange = smoothedRange - smoothedRange / period + range;
      smoothedPlus = smoothedPlus - smoothedPlus / period + plus;
      smoothedMinus = smoothedMinus - smoothedMinus / period + minus;
    }
    if (i < period) continue;

    final plus100 = smoothedRange == 0
        ? 0.0
        : 100 * smoothedPlus / smoothedRange;
    final minus100 = smoothedRange == 0
        ? 0.0
        : 100 * smoothedMinus / smoothedRange;
    plusDi[i] = plus100;
    minusDi[i] = minus100;

    final total = plus100 + minus100;
    final dx = total == 0 ? 0.0 : 100 * (plus100 - minus100).abs() / total;

    // The ADX needs a second window: one to warm the DIs, one to average the DX.
    final dxIndex = i - period;
    if (dxIndex < period) {
      dxSeed += dx;
      adx = dxIndex == period - 1 ? dxSeed / period : null;
    } else {
      adx = (adx! * (period - 1) + dx) / period;
    }
    adxOut[i] = adx;
  }
  return (plusDi: plusDi, minusDi: minusDi, adx: adxOut);
}

/// The greater of the candle's own range and its gap from [previous]'s close.
double trueRange(KLineEntity entity, KLineEntity previous) => max(
  entity.high - entity.low,
  max(
    (entity.high - previous.close).abs(),
    (entity.low - previous.close).abs(),
  ),
);

double _typicalPrice(KLineEntity entity) =>
    (entity.high + entity.low + entity.close) / 3;

/// Keltner channels: an [period] EMA of the close with [multiplier] average
/// true ranges either side of it.
({List<double?> upper, List<double?> middle, List<double?> lower})
keltnerSeries(
  List<KLineEntity> candles, {
  required int period,
  required int atrPeriod,
  required double multiplier,
}) {
  final middle = emaSeries(candles, period);
  final atr = atrSeries(candles, atrPeriod);
  final upper = List<double?>.filled(candles.length, null);
  final lower = List<double?>.filled(candles.length, null);

  for (var i = 0; i < candles.length; i++) {
    final centre = middle[i];
    final range = atr[i];
    if (centre == null || range == null) continue;
    upper[i] = centre + range * multiplier;
    lower[i] = centre - range * multiplier;
  }
  return (upper: upper, middle: middle, lower: lower);
}

/// Donchian channels: the highest high and lowest low over [period] candles,
/// with their midline.
({List<double?> upper, List<double?> middle, List<double?> lower})
donchianSeries(List<KLineEntity> candles, int period) {
  final upper = List<double?>.filled(candles.length, null);
  final middle = List<double?>.filled(candles.length, null);
  final lower = List<double?>.filled(candles.length, null);
  if (period <= 0) return (upper: upper, middle: middle, lower: lower);

  for (var i = period - 1; i < candles.length; i++) {
    var high = -double.maxFinite;
    var low = double.maxFinite;
    for (var window = i - period + 1; window <= i; window++) {
      high = max(high, candles[window].high);
      low = min(low, candles[window].low);
    }
    upper[i] = high;
    lower[i] = low;
    middle[i] = (high + low) / 2;
  }
  return (upper: upper, middle: middle, lower: lower);
}

/// Supertrend: an ATR band that follows the trend and flips when price closes
/// through it.
///
/// [trend] is 1 while the line sits below price and -1 while it sits above,
/// which is what makes the line change colour at a reversal.
({List<double?> line, List<int?> trend}) supertrendSeries(
  List<KLineEntity> candles, {
  required int period,
  required double multiplier,
}) {
  final line = List<double?>.filled(candles.length, null);
  final trend = List<int?>.filled(candles.length, null);
  final atr = atrSeries(candles, period);

  double? upperBand;
  double? lowerBand;
  var direction = 1;

  for (var i = 0; i < candles.length; i++) {
    final range = atr[i];
    if (range == null) continue;

    final candle = candles[i];
    final midpoint = (candle.high + candle.low) / 2;
    var upper = midpoint + range * multiplier;
    var lower = midpoint - range * multiplier;

    // Each band only tightens while the trend holds, so the stop never widens
    // away from price mid-move.
    if (upperBand != null && lowerBand != null) {
      final previousClose = candles[i - 1].close;
      if (upper > upperBand && previousClose <= upperBand) upper = upperBand;
      if (lower < lowerBand && previousClose >= lowerBand) lower = lowerBand;

      direction = switch (candle.close) {
        final close when close > upperBand => 1,
        final close when close < lowerBand => -1,
        _ => direction,
      };
    } else {
      direction = candle.close >= midpoint ? 1 : -1;
    }

    upperBand = upper;
    lowerBand = lower;
    line[i] = direction == 1 ? lower : upper;
    trend[i] = direction;
  }
  return (line: line, trend: trend);
}

/// Ichimoku Cloud: conversion and base lines, both spans and the lagging line.
///
/// The spans are shifted forward by [displacement] candles and the lagging line
/// back by the same, as the indicator is drawn. The chart holds one value per
/// candle, so the part of the cloud that would project past the newest candle
/// is not drawn.
({
  List<double?> conversion,
  List<double?> base,
  List<double?> spanA,
  List<double?> spanB,
  List<double?> lagging,
})
ichimokuSeries(
  List<KLineEntity> candles, {
  required int conversionPeriod,
  required int basePeriod,
  required int spanPeriod,
  required int displacement,
}) {
  final conversion = _midpointSeries(candles, conversionPeriod);
  final base = _midpointSeries(candles, basePeriod);
  final spanBRaw = _midpointSeries(candles, spanPeriod);

  final spanA = List<double?>.filled(candles.length, null);
  final spanB = List<double?>.filled(candles.length, null);
  final lagging = List<double?>.filled(candles.length, null);

  for (var i = 0; i < candles.length; i++) {
    final source = i - displacement;
    if (source >= 0) {
      final fast = conversion[source];
      final slow = base[source];
      if (fast != null && slow != null) spanA[i] = (fast + slow) / 2;
      spanB[i] = spanBRaw[source];
    }

    final lagged = i + displacement;
    if (lagged < candles.length) lagging[i] = candles[lagged].close;
  }

  return (
    conversion: conversion,
    base: base,
    spanA: spanA,
    spanB: spanB,
    lagging: lagging,
  );
}

/// The midpoint of the highest high and lowest low over [period] candles.
List<double?> _midpointSeries(List<KLineEntity> candles, int period) {
  final out = List<double?>.filled(candles.length, null);
  if (period <= 0) return out;

  for (var i = period - 1; i < candles.length; i++) {
    var high = -double.maxFinite;
    var low = double.maxFinite;
    for (var window = i - period + 1; window <= i; window++) {
      high = max(high, candles[window].high);
      low = min(low, candles[window].low);
    }
    out[i] = (high + low) / 2;
  }
  return out;
}

/// Stochastic RSI: where the RSI sits in its own [period] range, smoothed.
({List<double?> k, List<double?> d}) stochRsiSeries(
  List<KLineEntity> candles, {
  required int rsiPeriod,
  required int period,
  required int kSmoothing,
  required int dSmoothing,
}) {
  final rsi = rsiSeries(candles, rsiPeriod);
  final raw = List<double?>.filled(candles.length, null);

  for (var i = 0; i < candles.length; i++) {
    if (rsi[i] == null || i < period - 1) continue;
    var high = -double.maxFinite;
    var low = double.maxFinite;
    var complete = true;
    for (var window = i - period + 1; window <= i; window++) {
      final value = rsi[window];
      if (value == null) {
        complete = false;
        break;
      }
      high = max(high, value);
      low = min(low, value);
    }
    if (!complete) continue;
    // A flat RSI window has no range to place the current value in.
    raw[i] = high == low ? 50.0 : (rsi[i]! - low) / (high - low) * 100;
  }

  final k = _smoothValues(raw, kSmoothing);
  return (k: k, d: _smoothValues(k, dSmoothing));
}

/// Rate of change: how far the close has moved over [period] candles, as a
/// percentage.
List<double?> rocSeries(List<KLineEntity> candles, int period) {
  final out = List<double?>.filled(candles.length, null);
  if (period <= 0) return out;

  for (var i = period; i < candles.length; i++) {
    final previous = candles[i - period].close;
    if (previous == 0) continue;
    out[i] = (candles[i].close - previous) / previous * 100;
  }
  return out;
}

/// TRIX: the percentage change of a triple-smoothed EMA, with its signal line.
({List<double?> trix, List<double?> signal}) trixSeries(
  List<KLineEntity> candles, {
  required int period,
  required int signalPeriod,
}) {
  final once = _emaOf([for (final candle in candles) candle.close], period);
  final twice = _emaOf(once, period);
  final thrice = _emaOf(twice, period);

  final trix = List<double?>.filled(candles.length, null);
  for (var i = 1; i < candles.length; i++) {
    final previous = thrice[i - 1];
    if (previous == 0) continue;
    trix[i] = (thrice[i] - previous) / previous * 100;
  }

  return (trix: trix, signal: _smoothValues(trix, signalPeriod));
}

/// Simple moving average of volume over [period] candles.
List<double?> volumeMaSeries(List<KLineEntity> candles, int period) {
  final out = List<double?>.filled(candles.length, null);
  if (period <= 0) return out;

  var sum = 0.0;
  for (var i = 0; i < candles.length; i++) {
    sum += candles[i].vol;
    if (i >= period) sum -= candles[i - period].vol;
    if (i >= period - 1) out[i] = sum / period;
  }
  return out;
}

/// Awesome oscillator: the gap between a [fast] and a [slow] average of the
/// candle midpoint.
List<double?> awesomeSeries(
  List<KLineEntity> candles, {
  required int fast,
  required int slow,
}) {
  final midpoints = [
    for (final candle in candles) (candle.high + candle.low) / 2,
  ];
  final fastMa = _smaOf(midpoints, fast);
  final slowMa = _smaOf(midpoints, slow);

  final out = List<double?>.filled(candles.length, null);
  for (var i = 0; i < candles.length; i++) {
    final quick = fastMa[i];
    final slower = slowMa[i];
    if (quick == null || slower == null) continue;
    out[i] = quick - slower;
  }
  return out;
}

/// A swing pivot: where it sits in the candle list, its price, and whether it
/// is a high or a low.
typedef SwingPivot = ({int index, double price, bool isHigh});

/// A swing threshold worked out from the candles themselves.
///
/// A fixed percentage cannot suit every market: 5% is several swings on a daily
/// crypto chart and nothing at all on a quiet intraday one, where it would draw
/// no swings whatever. This aims for roughly [legs] legs across the candles
/// given, so a zigzag always has something to say.
double autoSwingDepth(List<KLineEntity> candles, {int legs = 8}) {
  if (candles.isEmpty) return 1;

  var high = -double.maxFinite;
  var low = double.maxFinite;
  for (final candle in candles) {
    high = max(high, candle.high);
    low = min(low, candle.low);
  }
  if (low <= 0 || high <= low) return 1;

  final range = (high - low) / low * 100;
  return (range / legs).clamp(0.1, 25);
}

/// The threshold to use for [depth], working one out when it is not positive.
double effectiveSwingDepth(List<KLineEntity> candles, double depth) =>
    depth > 0 ? depth : autoSwingDepth(candles);

/// ZigZag pivots: the alternating swing highs and lows that move price by at
/// least [depth] percent.
///
/// A [depth] of zero or less is worked out from the candles; see
/// [autoSwingDepth].
///
/// The last pivot is provisional — the swing it ends is still running — which
/// is what makes a zigzag redraw as new candles arrive.
List<SwingPivot> zigzagPivots(List<KLineEntity> candles, double depth) {
  if (candles.isEmpty) return const [];

  final threshold = effectiveSwingDepth(candles, depth) / 100;
  final pivots = <SwingPivot>[];

  var extremeIndex = 0;
  var extremeHigh = candles.first.high;
  var extremeLow = candles.first.low;
  // Null until price has moved far enough for a first swing to have a shape.
  bool? risingSwing;

  void record(int index, double price, bool isHigh) {
    pivots.add((index: index, price: price, isHigh: isHigh));
  }

  for (var i = 1; i < candles.length; i++) {
    final candle = candles[i];

    if (risingSwing == null) {
      if (candle.high > extremeHigh) {
        extremeHigh = candle.high;
        extremeIndex = i;
      }
      if (candle.low < extremeLow) {
        extremeLow = candle.low;
        extremeIndex = i;
      }
      if (extremeLow > 0 &&
          (extremeHigh - extremeLow) / extremeLow >= threshold) {
        // The first leg's direction is whichever extreme came last.
        risingSwing = candles[extremeIndex].high == extremeHigh;
        final startIsHigh = !risingSwing;
        record(
          0,
          startIsHigh ? candles.first.high : candles.first.low,
          startIsHigh,
        );
        record(
          extremeIndex,
          risingSwing ? extremeHigh : extremeLow,
          risingSwing,
        );
      }
      continue;
    }

    final last = pivots.last;
    if (risingSwing) {
      if (candle.high >= last.price) {
        pivots[pivots.length - 1] = (
          index: i,
          price: candle.high,
          isHigh: true,
        );
      } else if (last.price > 0 &&
          (last.price - candle.low) / last.price >= threshold) {
        record(i, candle.low, false);
        risingSwing = false;
      }
    } else {
      if (candle.low <= last.price) {
        pivots[pivots.length - 1] = (
          index: i,
          price: candle.low,
          isHigh: false,
        );
      } else if (last.price > 0 &&
          (candle.high - last.price) / last.price >= threshold) {
        record(i, candle.high, true);
        risingSwing = true;
      }
    }
  }

  return pivots;
}

/// A zigzag as one value per candle: the pivot prices, with nulls between them.
List<double?> zigzagSeries(List<KLineEntity> candles, double depth) {
  final out = List<double?>.filled(candles.length, null);
  for (final pivot in zigzagPivots(candles, depth)) {
    out[pivot.index] = pivot.price;
  }
  return out;
}

/// The usual Fibonacci retracement ratios, from the swing's end to its start.
const List<double> fibonacciRatios = [0, 0.236, 0.382, 0.5, 0.618, 0.786, 1];

/// The swing the retracement is measured over: the last completed zigzag leg.
///
/// Returns null while price has not yet moved enough for a leg to exist.
({SwingPivot from, SwingPivot to})? lastSwing(
  List<KLineEntity> candles,
  double depth,
) {
  final pivots = zigzagPivots(candles, depth);
  if (pivots.length < 2) return null;
  return (from: pivots[pivots.length - 2], to: pivots.last);
}

/// Fibonacci retracement levels of the last swing, one flat line per ratio.
///
/// Each level runs from the swing's start to the newest candle, which is where
/// a retracement is read.
List<List<double?>> fibonacciSeries(
  List<KLineEntity> candles,
  double depth, {
  List<double> ratios = fibonacciRatios,
}) {
  final levels = [
    for (var i = 0; i < ratios.length; i++)
      List<double?>.filled(candles.length, null),
  ];
  final swing = lastSwing(candles, depth);
  if (swing == null) return levels;

  final start = swing.from.price;
  final end = swing.to.price;
  for (var level = 0; level < ratios.length; level++) {
    // 0 sits at the swing's end and 1 at its start, so a level reads as "how
    // far price has come back".
    final price = end + (start - end) * ratios[level];
    for (var i = swing.from.index; i < candles.length; i++) {
      levels[level][i] = price;
    }
  }
  return levels;
}

/// Wave labels for a run of zigzag pivots, counted `1`-`5` then `A`-`C`.
///
/// This is a reading of the swings, not a rules-checked Elliott count: it
/// labels the alternating pivots in order and starts again after the correction.
const List<String> elliottWaveLabels = ['1', '2', '3', '4', '5', 'A', 'B', 'C'];

/// The pivots of the last [elliottWaveLabels]-length run, with their labels.
List<({SwingPivot pivot, String label})> elliottWaves(
  List<KLineEntity> candles,
  double depth,
) {
  final pivots = zigzagPivots(candles, depth);
  if (pivots.length < 2) return const [];

  // The impulse is counted from the pivot the current run started at, so the
  // labels stay put as the newest swing extends.
  final cycle = elliottWaveLabels.length;
  final start = ((pivots.length - 1) ~/ cycle) * cycle;
  return [
    for (var i = start; i < pivots.length; i++)
      (pivot: pivots[i], label: elliottWaveLabels[(i - start) % cycle]),
  ];
}

/// Simple moving average of plain values, for series built from something other
/// than the close.
List<double?> _smaOf(List<double> values, int period) {
  final out = List<double?>.filled(values.length, null);
  if (period <= 0) return out;

  var sum = 0.0;
  for (var i = 0; i < values.length; i++) {
    sum += values[i];
    if (i >= period) sum -= values[i - period];
    if (i >= period - 1) out[i] = sum / period;
  }
  return out;
}

/// Exponential moving average of plain values, seeded with the first one.
List<double> _emaOf(List<double> values, int period) {
  final out = List<double>.filled(values.length, 0);
  if (values.isEmpty) return out;

  final weight = 2 / (period + 1);
  var previous = values.first;
  for (var i = 0; i < values.length; i++) {
    previous = i == 0
        ? values[i]
        : values[i] * weight + previous * (1 - weight);
    out[i] = previous;
  }
  return out;
}

/// Moving average of a sparse series, keeping its gaps.
List<double?> _smoothValues(List<double?> values, int period) {
  final out = List<double?>.filled(values.length, null);
  if (period <= 1) return List<double?>.of(values);

  for (var i = period - 1; i < values.length; i++) {
    var sum = 0.0;
    var complete = true;
    for (var window = i - period + 1; window <= i; window++) {
      final value = values[window];
      if (value == null) {
        complete = false;
        break;
      }
      sum += value;
    }
    if (complete) out[i] = sum / period;
  }
  return out;
}
