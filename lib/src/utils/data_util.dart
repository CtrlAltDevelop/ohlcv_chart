import '../entity/k_line_entity.dart';
import '../indicators/series_math.dart';

/// Computes every indicator the chart can draw.
class DataUtil {
  /// Fills the indicator fields on each entry of [dataList], in place.
  ///
  /// Handy when you read the values yourself — the chart computes what it draws
  /// from the indicators you give it, so calling this is not required for
  /// rendering. [maDayList] is the set of moving-average periods, and [n] and
  /// [k] the Bollinger band period and standard-deviation multiplier.
  static void calculate(
    List<KLineEntity> dataList, [
    List<int> maDayList = const [5, 10, 20],
    int n = 20,
    int k = 2,
  ]) {
    if (dataList.isEmpty) return;

    /// calculate main state
    calcMA(dataList, maDayList);
    calcEMA(dataList, maDayList);
    calcBOLL(dataList, n, k);
    calcSAR(dataList);
    calcVWAP(dataList);

    /// calculate secondary state
    calcVolumeMA(dataList);
    calcKDJ(dataList);
    calcMACD(dataList);
    calcRSI(dataList);
    calcWR(dataList);
    calcCCI(dataList);
    calcATR(dataList);
    calcOBV(dataList);
    calcMFI(dataList);
    calcDMI(dataList);
  }

  /// Fills `maValueList` with one simple moving average per period.
  static void calcMA(List<KLineEntity> dataList, List<int> maDayList) {
    final series = [
      for (final period in maDayList) smaSeries(dataList, period),
    ];
    for (var i = 0; i < dataList.length; i++) {
      // Zero, not null, is this field's "no value yet" — the renderers and any
      // existing caller both read it that way.
      dataList[i].maValueList = [for (final line in series) line[i] ?? 0];
    }
  }

  /// Fills `emaValueList` with one exponential moving average per period.
  ///
  /// Each average is seeded with the first close, so it has a value from the
  /// first candle rather than after a warm-up.
  static void calcEMA(List<KLineEntity> dataList, List<int> maDayList) {
    final series = [
      for (final period in maDayList) emaSeries(dataList, period),
    ];
    for (var i = 0; i < dataList.length; i++) {
      dataList[i].emaValueList = [for (final line in series) line[i] ?? 0];
    }
  }

  /// Fills `mb`, `up` and `dn` with the Bollinger bands, and `bollMa` with the
  /// average they are centred on.
  static void calcBOLL(List<KLineEntity> dataList, int n, int k) {
    final bands = bollSeries(dataList, n, k.toDouble());
    for (var i = 0; i < dataList.length; i++) {
      final entity = dataList[i];
      entity.bollMa = bands.middle[i];
      entity.mb = bands.upper[i] == null ? null : bands.middle[i];
      entity.up = bands.upper[i];
      entity.dn = bands.lower[i];
    }
  }

  /// Fills `sar` with the parabolic SAR.
  static void calcSAR(List<KLineEntity> dataList) {
    final series = sarSeries(dataList);
    for (var i = 0; i < dataList.length; i++) {
      dataList[i].sar = series[i];
    }
  }

  /// Fills `vwap` with the volume-weighted average price.
  ///
  /// Accumulated over the whole list rather than reset per session, so it
  /// answers "what has everyone paid so far" across the candles you pass.
  static void calcVWAP(List<KLineEntity> dataList) {
    final series = vwapSeries(dataList);
    for (var i = 0; i < dataList.length; i++) {
      dataList[i].vwap = series[i];
    }
  }

  /// Fills `dif`, `dea` and `macd`.
  static void calcMACD(List<KLineEntity> dataList) {
    final series = macdSeries(dataList);
    for (var i = 0; i < dataList.length; i++) {
      final entity = dataList[i];
      entity.dif = series.dif[i];
      entity.dea = series.dea[i];
      entity.macd = series.macd[i];
    }
  }

  /// Fills `k`, `d` and `j` with the stochastic oscillator.
  static void calcKDJ(List<KLineEntity> dataList) {
    final series = kdjSeries(dataList);
    for (var i = 0; i < dataList.length; i++) {
      final entity = dataList[i];
      entity.k = series.k[i];
      entity.d = series.d[i];
      entity.j = series.j[i];
    }
  }

  /// Fills `rsi` with the relative strength index over [period] candles.
  static void calcRSI(List<KLineEntity> dataList, [int period = 14]) {
    final series = rsiSeries(dataList, period);
    for (var i = 0; i < dataList.length; i++) {
      dataList[i].rsi = series[i];
    }
  }

  /// Fills `r` with Williams %R over [period] candles.
  static void calcWR(List<KLineEntity> dataList, [int period = 14]) {
    final series = wrSeries(dataList, period);
    for (var i = 0; i < dataList.length; i++) {
      dataList[i].r = series[i];
    }
  }

  /// Fills `cci` with the commodity channel index over [period] candles.
  static void calcCCI(List<KLineEntity> dataList, [int period = 14]) {
    final series = cciSeries(dataList, period);
    for (var i = 0; i < dataList.length; i++) {
      dataList[i].cci = series[i];
    }
  }

  /// Fills `atr` with Wilder's average true range over [period] candles.
  static void calcATR(List<KLineEntity> dataList, [int period = 14]) {
    final series = atrSeries(dataList, period);
    for (var i = 0; i < dataList.length; i++) {
      dataList[i].atr = series[i];
    }
  }

  /// Fills `obv` with on-balance volume, starting from zero.
  static void calcOBV(List<KLineEntity> dataList) {
    final series = obvSeries(dataList);
    for (var i = 0; i < dataList.length; i++) {
      dataList[i].obv = series[i];
    }
  }

  /// Fills `mfi` with the money flow index over [period] candles.
  static void calcMFI(List<KLineEntity> dataList, [int period = 14]) {
    final series = mfiSeries(dataList, period);
    for (var i = 0; i < dataList.length; i++) {
      dataList[i].mfi = series[i];
    }
  }

  /// Fills `pdi`, `mdi` and `adx` with Wilder's directional movement system.
  static void calcDMI(List<KLineEntity> dataList, [int period = 14]) {
    final series = dmiSeries(dataList, period);
    for (var i = 0; i < dataList.length; i++) {
      final entity = dataList[i];
      entity.pdi = series.plusDi[i];
      entity.mdi = series.minusDi[i];
      entity.adx = series.adx[i];
    }
  }

  /// Fills `ma5Volume` and `ma10Volume` with trailing volume averages.
  static void calcVolumeMA(List<KLineEntity> dataList) {
    double volumeMa5 = 0;
    double volumeMa10 = 0;

    for (int i = 0; i < dataList.length; i++) {
      final entry = dataList[i];

      volumeMa5 += entry.vol;
      volumeMa10 += entry.vol;

      if (i == 4) {
        entry.ma5Volume = volumeMa5 / 5;
      } else if (i > 4) {
        volumeMa5 -= dataList[i - 5].vol;
        entry.ma5Volume = volumeMa5 / 5;
      } else {
        entry.ma5Volume = 0;
      }

      if (i == 9) {
        entry.ma10Volume = volumeMa10 / 10;
      } else if (i > 9) {
        volumeMa10 -= dataList[i - 10].vol;
        entry.ma10Volume = volumeMa10 / 10;
      } else {
        entry.ma10Volume = 0;
      }
    }
  }
}
