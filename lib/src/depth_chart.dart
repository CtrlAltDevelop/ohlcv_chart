import 'package:flutter/material.dart';

import 'depth_ladder.dart';
import 'depth_mode.dart';
import 'depth_style.dart';
import 'depth_translations.dart';
import 'entity/depth_entity.dart';
import 'renderer/depth_painter.dart';

/// A market-depth chart for one order book.
///
/// [bids] and [asks] are drawn either side of the mid price, both ascending by
/// price from left to right. Long-pressing anywhere reveals a crosshair with
/// the price, the running total and the size resting on the rung under the
/// finger.
///
/// [mode] chooses the picture: the cumulative curves it has always drawn, a
/// histogram of what rests on each rung, both at once, or a numeric ladder —
/// see [DepthChartMode]. [scale] spaces the volume axis, and [zoom] narrows the
/// chart to the levels near the mid.
///
/// The curves are plotted exactly as given, so each rung's `vol` must be a
/// running total; [DepthEntity.bids] and [DepthEntity.asks] build those from the
/// per-rung sizes an exchange feed returns.
///
/// ```dart
/// DepthChart(
///   DepthEntity.bids(rawBids),
///   DepthEntity.asks(rawAsks),
///   baseUnit: 2,
///   quoteUnit: 6,
/// );
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
    this.mode = DepthChartMode.cumulative,
    this.scale = DepthScale.linear,
    this.zoom,
    this.ladderLevels = 10,
    super.key,
  });

  /// Buy-side depth, ascending by price: the deepest cumulative total first.
  final List<DepthEntity> bids;

  /// Sell-side depth, ascending by price: the best ask first.
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

  /// Which picture of the book to draw; see [DepthChartMode].
  final DepthChartMode mode;

  /// How volume is spaced up the vertical axis.
  final DepthScale scale;

  /// Keeps only the levels within this fraction of the mid price.
  ///
  /// `0.05` shows the book within five percent of the mid, where most of the
  /// trading is; null — the default — draws the whole book. A zoom so tight
  /// that nothing is left falls back to the whole book rather than to nothing.
  final double? zoom;

  /// How many levels of each side the ladder lists.
  final int ladderLevels;

  @override
  State<DepthChart> createState() => _DepthChartState();
}

class _DepthChartState extends State<DepthChart> {
  Offset? pressOffset;
  bool isLongPress = false;

  @override
  Widget build(BuildContext context) {
    if (widget.mode == DepthChartMode.ladder) {
      return DepthLadder(
        widget.bids,
        widget.asks,
        baseUnit: widget.baseUnit,
        quoteUnit: widget.quoteUnit,
        levels: widget.ladderLevels,
        zoom: widget.zoom,
        chartColors: widget.chartColors,
        chartStyle: widget.chartStyle,
        chartTranslations: widget.chartTranslations,
      );
    }

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
          mode: widget.mode,
          scale: widget.scale,
          zoom: widget.zoom,
        ),
      ),
    );
  }
}
