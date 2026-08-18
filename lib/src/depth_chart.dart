import 'package:flutter/material.dart';

import 'depth_style.dart';
import 'depth_translations.dart';
import 'entity/depth_entity.dart';
import 'renderer/depth_painter.dart';

class DepthChart extends StatefulWidget {
  const DepthChart(
    this.bids,
    this.asks, {
    this.baseUnit = 2,
    this.quoteUnit = 6,
    this.offset = const Offset(8, 0),
    this.chartTranslations = const DepthChartTranslations(),
    this.chartStyle = const DepthChartStyle(),
    this.chartColors = const DepthChartColors(),
    super.key,
  });

  final List<DepthEntity> bids;
  final List<DepthEntity> asks;
  final int baseUnit;
  final int quoteUnit;
  final Offset offset;
  final DepthChartColors chartColors;
  final DepthChartStyle chartStyle;
  final DepthChartTranslations chartTranslations;

  @override
  State<DepthChart> createState() => _DepthChartState();
}

class _DepthChartState extends State<DepthChart> {
  Offset? pressOffset;
  bool isLongPress = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (details) {
        pressOffset = details.localPosition;
        isLongPress = true;
        setState(() {});
      },
      onLongPressMoveUpdate: (details) {
        pressOffset = details.localPosition;
        isLongPress = true;
        setState(() {});
      },
      onLongPressEnd: (details) {
        pressOffset = null;
        isLongPress = false;
        setState(() {});
      },
      child: CustomPaint(
        size: const Size.fromHeight(200),
        painter: DepthChartPainter(
          widget.bids,
          widget.asks,
          pressOffset,
          isLongPress,
          widget.quoteUnit,
          widget.baseUnit,
          widget.chartColors,
          widget.chartStyle,
          widget.offset,
          widget.chartTranslations,
        ),
      ),
    );
  }
}
