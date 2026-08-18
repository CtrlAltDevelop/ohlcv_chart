import 'package:flutter/material.dart';

import 'line.dart';

class TrendLine extends ChartLine {
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

  DateTime time1;
  DateTime? time2;
  double price1;
  double? price2;
  String? label1;
  String? label2;
}
