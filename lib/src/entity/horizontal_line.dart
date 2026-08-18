import 'dart:ui';

import 'line.dart';

class HorizontalLine extends ChartLine {
  HorizontalLine({
    required this.price,
    this.title,
    super.color = const Color(0xFFFFFF00),
    super.thickness = 2.0,
    super.locked = false,
    super.isDashed = false,
    super.showLabel = false,
  });

  double price;
  String? title;
}
