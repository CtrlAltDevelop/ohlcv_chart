/// One rung of the order book: the [vol] resting at [price].
///
/// [DepthChart] accumulates these into the depth curve, so pass them sorted
/// away from the mid price.
class DepthEntity {
  /// Creates a depth rung.
  DepthEntity(this.price, this.vol);

  /// Price level, in quote currency.
  double price;

  /// Volume resting at [price], in base currency.
  double vol;
}
