import '../entity/k_entity.dart';

class KLineEntity extends KEntity {
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

  double? amount;
  double? change;
  double? ratio;
  DateTime? dateTime;

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
