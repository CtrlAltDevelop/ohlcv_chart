import 'dart:ui';

abstract class ChartLine {
  ChartLine({
    this.color = const Color(0xFFFFFF00),
    this.thickness = 2.0,
    this.isDashed = false,
    this.locked = false,
    this.showLabel = true,
  });

  Color color;
  double thickness;
  bool isDashed;
  bool locked;
  bool showLabel;
}
