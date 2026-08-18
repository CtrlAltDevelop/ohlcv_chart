import 'dart:ui';

/// A labelled price marker painted over the candles.
///
/// Typically used for buy and sell signals, take-profit and stop-loss levels,
/// or liquidation prices.
class SignalEntity {
  /// Creates a signal marker at [price].
  SignalEntity({
    required this.title,
    required this.price,
    required this.color,
    this.useDash = false,
  });

  /// Text shown in the marker's tag.
  final String title;

  /// The price level the marker sits at, in quote currency.
  final double price;

  /// Colour of both the tag and its leader line.
  final Color color;

  /// Whether the leader line is dashed rather than solid.
  final bool useDash;
}
