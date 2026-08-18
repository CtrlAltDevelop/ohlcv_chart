import 'dart:ui';

import 'line.dart';

/// A horizontal line pinned to a [price], spanning the full chart width.
///
/// Useful for support and resistance levels, or for marking an order price.
class HorizontalLine extends ChartLine {
  /// Creates a horizontal line at [price].
  HorizontalLine({
    required this.price,
    this.title,
    super.color = const Color(0xFFFFFF00),
    super.thickness = 2.0,
    super.locked = false,
    super.isDashed = false,
    super.showLabel = false,
  });

  /// The price level the line sits at, in quote currency.
  double price;

  /// Optional label painted next to the line when `showLabel` is true.
  String? title;
}
