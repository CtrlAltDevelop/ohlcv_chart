import 'package:flutter/material.dart';

import 'line.dart';

/// A free-form line between two (time, price) points.
///
/// A trend line starts anchored at ([time1], [price1]); while the user is
/// still dragging it out, [time2] and [price2] are null. Once both ends are
/// set the line can be selected and either end dragged to a new anchor.
class TrendLine extends ChartLine {
  /// Creates a trend line anchored at ([time1], [price1]).
  TrendLine({
    required this.time1,
    required this.price1,
    this.time2,
    this.price2,
    this.label1,
    this.label2,
    super.color = Colors.yellow,
    super.thickness = 2.0,
    super.isDashed = false,
    super.locked = false,
    super.showLabel = false,
  });

  /// Time of the first anchor.
  DateTime time1;

  /// Time of the second anchor, or null while the line is being drawn.
  DateTime? time2;

  /// Price of the first anchor.
  double price1;

  /// Price of the second anchor, or null while the line is being drawn.
  double? price2;

  /// Optional label painted at the first anchor.
  String? label1;

  /// Optional label painted at the second anchor.
  String? label2;
}
