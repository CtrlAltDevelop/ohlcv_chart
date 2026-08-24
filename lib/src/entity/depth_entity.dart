/// One point of the depth curve: the cumulative [vol] out to [price].
///
/// [DepthChart] plots these as given, so sort them away from the mid price and
/// pass running totals — [DepthEntity.bids] and [DepthEntity.asks] build
/// those from per-rung sizes.
class DepthEntity {
  /// Creates a depth rung.
  DepthEntity(this.price, this.vol);

  /// Price level, in quote currency.
  double price;

  /// Cumulative volume out to [price], in base currency.
  ///
  /// The chart plots this value as given: pass a running total, not the size
  /// resting on that one rung. [DepthEntity.bids] and [DepthEntity.asks]
  /// convert the per-rung sizes most order-book feeds return.
  double vol;

  /// Builds the bid curve from raw order-book rungs.
  ///
  /// Sorts [rungs] by price and accumulates from the best bid downwards, so the
  /// deepest total sits at the far left of the chart, where the lowest price is,
  /// and the curve falls away to nothing at the mid.
  ///
  /// ```dart
  /// DepthChart(DepthEntity.bids(rawBids), DepthEntity.asks(rawAsks));
  /// ```
  static List<DepthEntity> bids(List<DepthEntity> rungs) {
    final sorted = [...rungs]..sort((a, b) => a.price.compareTo(b.price));
    var running = 0.0;
    final curve = <DepthEntity>[];
    for (final rung in sorted.reversed) {
      running += rung.vol;
      curve.insert(0, DepthEntity(rung.price, running));
    }
    return curve;
  }

  /// Builds the ask curve from raw order-book rungs.
  ///
  /// Sorts [rungs] by price and accumulates from the best ask upwards, so the
  /// curve grows towards the right of the chart.
  static List<DepthEntity> asks(List<DepthEntity> rungs) {
    final sorted = [...rungs]..sort((a, b) => a.price.compareTo(b.price));
    var running = 0.0;
    return [
      for (final rung in sorted) DepthEntity(rung.price, running += rung.vol),
    ];
  }
}
