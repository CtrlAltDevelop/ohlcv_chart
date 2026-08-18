import '../entity/k_entity.dart';

/// A single candle, plus the indicator values computed for it.
///
/// Create these from your market data, then hand the whole list to
/// [DataUtil.calculate], which fills in the MA, BOLL, SAR, MACD, KDJ, RSI,
/// WR and CCI fields in place before the chart is painted.
class KLineEntity extends KEntity {
  /// Builds a candle from a decoded JSON map.
  ///
  /// Reads `open`, `high`, `low`, `close`, `vol`, and optionally `amount`,
  /// `ratio` and `change`. The timestamp comes from `time` in milliseconds,
  /// falling back to `id` in seconds.
  factory KLineEntity.fromJson(Map<String, dynamic> json) {
    int timestampMillis = 0;
    final dynamic timeValue = json['time'];
    final dynamic idValue = json['id'];

    if (timeValue != null && timeValue is num) {
      timestampMillis = timeValue.toInt();
    } else if (idValue != null && idValue is num) {
      timestampMillis = idValue.toInt() * 1000;
    }

    return KLineEntity.fromCustom(
      open: (json['open'] as num?)?.toDouble() ?? 0.0,
      high: (json['high'] as num?)?.toDouble() ?? 0.0,
      low: (json['low'] as num?)?.toDouble() ?? 0.0,
      close: (json['close'] as num?)?.toDouble() ?? 0.0,
      vol: (json['vol'] as num?)?.toDouble() ?? 0.0,
      dateTime: DateTime.fromMillisecondsSinceEpoch(
        timestampMillis,
        isUtc: true,
      ),
      amount: (json['amount'] as num?)?.toDouble(),
      ratio: (json['ratio'] as num?)?.toDouble(),
      change: (json['change'] as num?)?.toDouble(),
    );
  }

  /// Builds a candle from already-parsed values.
  KLineEntity.fromCustom({
    required double open,
    required double high,
    required double low,
    required double close,
    required double vol,
    required DateTime this.dateTime,
    this.amount,
    this.ratio,
    this.change,
  }) {
    this.open = open;
    this.high = high;
    this.low = low;
    this.close = close;
    this.vol = vol;
  }

  /// Traded turnover in quote currency, when the feed provides it.
  double? amount;

  /// Absolute price change over the candle, when the feed provides it.
  double? change;

  /// Percentage price change over the candle, when the feed provides it.
  double? ratio;

  /// The candle's open time.
  DateTime? dateTime;

  /// Serialises the candle's raw OHLCV values back to a JSON map.
  Map<String, dynamic> toJson() => {
    'dateTime': dateTime?.toIso8601String(),
    'open': open,
    'close': close,
    'high': high,
    'low': low,
    'vol': vol,
    'amount': amount,
    'ratio': ratio,
    'change': change,
  };

  @override
  String toString() {
    return 'KLineEntity{open: $open, high: $high, low: $low, close: $close, vol: $vol, dateTime: $dateTime, amount: $amount, ratio: $ratio, change: $change}';
  }
}
