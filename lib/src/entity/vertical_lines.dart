import 'dart:ui';

import 'line.dart';

class VerticalLine extends ChartLine {
  VerticalLine({
    required this.time,
    this.title,
    super.color = const Color(0xFFFFFF00),
    super.thickness = 2.0,
    super.locked = false,
    super.isDashed = false,
    super.showLabel = false,
  });

  DateTime time;
  String? title;
}
