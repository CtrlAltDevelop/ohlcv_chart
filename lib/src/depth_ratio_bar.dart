import 'package:flutter/material.dart';

import 'depth_chart.dart';
import 'depth_ladder.dart';
import 'depth_style.dart';
import 'depth_translations.dart';
import 'entity/depth_book.dart';
import 'entity/depth_entity.dart';

/// Which way the resting orders lean, as one bar.
///
/// The volume on each side is added up and drawn as two lengths meeting in the
/// middle, each labelled with its share of the book. It answers plainly what
/// the shape of a depth chart only hints at: whether the bids or the asks are
/// the heavier side, and by how much.
///
/// It takes the same cumulative curves [DepthChart] and [DepthLadder] do and
/// reads the totals off them, so nothing extra has to be passed in. [zoom]
/// narrows it to the levels near the mid the same way those two do — the split
/// of the whole book and the split of the nearest one percent are different
/// numbers, and which one is wanted depends on what the bar sits beside.
///
/// `showRatioBar: true` puts it under either of those widgets; reach for it
/// directly to place it somewhere else, or to change [duration].
///
/// ```dart
/// DepthRatioBar(
///   DepthEntity.bids(rawBids),
///   DepthEntity.asks(rawAsks),
///   zoom: 0.05,
/// );
/// ```
class DepthRatioBar extends StatelessWidget {
  /// Creates a ratio bar over the same curves the chart takes.
  const DepthRatioBar(
    this.bids,
    this.asks, {
    this.zoom,
    this.duration = const Duration(milliseconds: 300),
    this.chartColors = const DepthChartColors(),
    this.chartStyle = const DepthChartStyle(),
    this.chartTranslations = const DepthChartTranslations(),
    super.key,
  });

  /// Buy-side depth, ascending by price, as [DepthEntity.bids] builds it.
  final List<DepthEntity> bids;

  /// Sell-side depth, ascending by price, as [DepthEntity.asks] builds it.
  final List<DepthEntity> asks;

  /// Counts only the levels within this fraction of the mid price.
  ///
  /// Null — the default — weighs the whole book. Pass the chart's own zoom to
  /// have the bar agree with the picture above it.
  final double? zoom;

  /// How long the split takes to slide when the book moves.
  ///
  /// [Duration.zero] snaps to each new reading instead.
  final Duration duration;

  /// Every colour the bar paints with: [DepthChartColors.upColor] for the bids,
  /// [DepthChartColors.dnColor] for the asks.
  final DepthChartColors chartColors;

  /// Geometry: the bar's thickness, its text size and the gaps around it.
  final DepthChartStyle chartStyle;

  /// Names the two sides for a screen reader.
  final DepthChartTranslations chartTranslations;

  @override
  Widget build(BuildContext context) {
    final book = DepthBook.fromCurves(bids, asks, zoom: zoom);
    final bidVolume = _volume(book.bids);
    final askVolume = _volume(book.asks);
    final total = bidVolume + askVolume;

    // Nothing resting either side — a book still on its way, most often. The
    // bar holds its place as a grey track rather than collapsing the row it
    // sits in and moving everything else.
    final share = total <= 0 ? null : bidVolume / total;

    final textStyle = TextStyle(
      color: chartColors.defaultTextColor,
      fontSize: chartStyle.ratioFontSize,
    );

    // Outside a Material, Flutter's ambient default is the yellow-underlined
    // debug style and a Text merges onto whatever is in scope. The ladder
    // anchors its own for the same reason; the bar can be dropped anywhere too.
    return DefaultTextStyle(
      style: textStyle,
      child: TweenAnimationBuilder<double>(
        duration: duration,
        curve: Curves.easeOut,
        tween: Tween<double>(end: share ?? 0.5),
        builder: (context, bidShare, _) =>
            _bar(bidShare, known: share != null, textStyle: textStyle),
      ),
    );
  }

  Widget _bar(
    double bidShare, {
    required bool known,
    required TextStyle textStyle,
  }) {
    final askShare = 1 - bidShare;
    final radius = Radius.circular(chartStyle.ratioBarHeight / 2);

    return Semantics(
      label: known
          ? '${chartTranslations.bids} ${_percent(bidShare)}, '
                '${chartTranslations.asks} ${_percent(askShare)}'
          : null,
      excludeSemantics: known,
      child: Row(
        children: [
          Text(
            known ? _percent(bidShare) : '--',
            style: known
                ? textStyle.copyWith(color: chartColors.upColor)
                : textStyle,
          ),
          SizedBox(width: chartStyle.padding),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final gap = chartStyle.space;
                final width = (constraints.maxWidth - gap).clamp(
                  0.0,
                  double.infinity,
                );
                // Both ends keep a pill's width, so a side holding almost
                // nothing still reads as a sliver rather than as nothing.
                final least = chartStyle.ratioBarHeight.clamp(0.0, width / 2);
                final bidWidth = least + (width - least * 2) * bidShare;

                return Row(
                  children: [
                    _half(
                      bidWidth,
                      known ? chartColors.upColor : chartColors.barrierColor,
                      BorderRadius.horizontal(left: radius),
                    ),
                    SizedBox(width: gap),
                    _half(
                      width - bidWidth,
                      known ? chartColors.dnColor : chartColors.barrierColor,
                      BorderRadius.horizontal(right: radius),
                    ),
                  ],
                );
              },
            ),
          ),
          SizedBox(width: chartStyle.padding),
          Text(
            known ? _percent(askShare) : '--',
            style: known
                ? textStyle.copyWith(color: chartColors.dnColor)
                : textStyle,
          ),
        ],
      ),
    );
  }

  Widget _half(double width, Color color, BorderRadius radius) => Container(
    width: width,
    height: chartStyle.ratioBarHeight,
    decoration: BoxDecoration(color: color, borderRadius: radius),
  );

  static String _percent(double share) =>
      '${(share * 100).toStringAsFixed(2)}%';

  /// The volume resting on one side: the running total out to its far end.
  static double _volume(List<DepthLevel> levels) {
    var most = 0.0;
    for (final level in levels) {
      if (level.cumulative > most) most = level.cumulative;
    }
    return most;
  }
}
