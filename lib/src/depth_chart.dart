import 'package:flutter/material.dart';

import 'depth_style.dart';
import 'depth_translations.dart';
import 'entity/depth_entity.dart';
import 'renderer/depth_painter.dart';

/// A cumulative market-depth chart for one order book.
///
/// [bids] and [asks] are drawn as two filled curves either side of the mid
/// price. Long-pressing anywhere reveals a crosshair with the price and
/// cumulative volume under the finger.
///
/// ```dart
/// DepthChart(bids, asks, baseUnit: 2, quoteUnit: 6);
/// ```
class DepthChart extends StatefulWidget {
  /// Creates a depth chart over [bids] and [asks].
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

  /// Buy-side rungs, sorted away from the mid price.
  final List<DepthEntity> bids;

  /// Sell-side rungs, sorted away from the mid price.
  final List<DepthEntity> asks;

  /// Decimal places used for volumes.
  final int baseUnit;

  /// Decimal places used for prices.
  final int quoteUnit;

  /// Shifts the painted curves within the widget's bounds.
  final Offset offset;

  /// Every colour the depth chart paints with.
  final DepthChartColors chartColors;

  /// Geometry: paddings, stroke widths and text sizes.
  final DepthChartStyle chartStyle;

  /// Labels used by the depth chart's axes and readout.
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
