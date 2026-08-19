/// Every piece of text the depth chart shows.
class DepthChartTranslations {
  /// Creates the labels, defaulting to English.
  const DepthChartTranslations({
    this.price = 'Price',
    this.amount = 'Amount',
    this.size = 'Size',
    this.total = 'Total',
    this.bids = 'Bids',
    this.asks = 'Asks',
    this.spread = 'Spread',
  });

  /// Label of the price row in the readout, and of the ladder's price column.
  final String price;

  /// Label of the volume row in the readout.
  ///
  /// The readout shows the running total out to the price under the finger.
  final String amount;

  /// Label of the size resting on one rung, in the readout and the ladder.
  final String size;

  /// Label of the running-total column in the ladder.
  final String total;

  /// Heading of the bid side of the ladder.
  final String bids;

  /// Heading of the ask side of the ladder.
  final String asks;

  /// Label of the gap between the best bid and the best ask.
  final String spread;
}
