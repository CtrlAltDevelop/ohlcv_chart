import 'entity/k_line_entity.dart';

/// Which candles the chart is showing.
///
/// [firstIndex] and [lastIndex] are into the list handed to the chart, both
/// inclusive, and [firstTime] and [lastTime] are those candles' own instants —
/// null for a candle with no timestamp. [length] is how many candles are in
/// view, which is what a "bars on screen" readout wants.
///
/// Reported through `KChartWidget.onVisibleRangeChanged` and readable at any
/// time from `KChartController.visibleRange`.
class ChartVisibleRange {
  /// Creates a range over the candles from [firstIndex] to [lastIndex].
  const ChartVisibleRange({
    required this.firstIndex,
    required this.lastIndex,
    this.firstTime,
    this.lastTime,
  });

  /// The range over [candles] from [firstIndex] to [lastIndex].
  ///
  /// Reads the two candles' instants so the caller does not have to.
  factory ChartVisibleRange.of(
    List<KLineEntity> candles,
    int firstIndex,
    int lastIndex,
  ) {
    final from = firstIndex.clamp(0, candles.isEmpty ? 0 : candles.length - 1);
    final to = lastIndex.clamp(0, candles.isEmpty ? 0 : candles.length - 1);
    return ChartVisibleRange(
      firstIndex: from,
      lastIndex: to,
      firstTime: candles.isEmpty ? null : candles[from].dateTime,
      lastTime: candles.isEmpty ? null : candles[to].dateTime,
    );
  }

  /// Index of the oldest candle in view.
  final int firstIndex;

  /// Index of the newest candle in view.
  final int lastIndex;

  /// When the oldest candle in view opened, if it says.
  final DateTime? firstTime;

  /// When the newest candle in view opened, if it says.
  final DateTime? lastTime;

  /// How many candles are in view.
  int get length => lastIndex - firstIndex + 1;

  /// How long the window covers, or null when either end has no time.
  Duration? get span {
    final from = firstTime;
    final to = lastTime;
    return from == null || to == null ? null : to.difference(from);
  }

  @override
  bool operator ==(Object other) =>
      other is ChartVisibleRange &&
      other.firstIndex == firstIndex &&
      other.lastIndex == lastIndex &&
      other.firstTime == firstTime &&
      other.lastTime == lastTime;

  @override
  int get hashCode => Object.hash(firstIndex, lastIndex, firstTime, lastTime);

  @override
  String toString() =>
      'ChartVisibleRange($firstIndex–$lastIndex, $length candles)';
}
