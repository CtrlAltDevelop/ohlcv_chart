import 'package:material_ui/material_ui.dart';

import 'depth_ratio_bar.dart';
import 'depth_style.dart';
import 'depth_translations.dart';
import 'entity/depth_book.dart';
import 'entity/depth_entity.dart';
import 'utils/number_util.dart';

/// An order book as numbers: price, size and running total, one row a level.
///
/// The asks sit above the bids with the spread between them, the way a trading
/// ladder reads, and each row carries a bar sized by its share of the book so
/// the shape is still visible behind the figures.
///
/// [DepthChart] hands over to this when its mode is `DepthChartMode.ladder`;
/// use it directly to put the numbers beside a chart rather than instead of it.
///
/// ```dart
/// DepthLadder(
///   DepthEntity.bids(rawBids),
///   DepthEntity.asks(rawAsks),
///   levels: 12,
/// );
/// ```
class DepthLadder extends StatelessWidget {
  /// Creates a ladder over the same cumulative curves the chart takes.
  const DepthLadder(
    this.bids,
    this.asks, {
    this.baseUnit = 2,
    this.quoteUnit = 6,
    this.levels = 10,
    this.zoom,
    this.barsShowTotal = true,
    this.showRatioBar = false,
    this.chartColors = const DepthChartColors(),
    this.chartStyle = const DepthChartStyle(),
    this.chartTranslations = const DepthChartTranslations(),
    super.key,
  });

  /// Buy-side depth, ascending by price, as [DepthEntity.bids] builds it.
  final List<DepthEntity> bids;

  /// Sell-side depth, ascending by price, as [DepthEntity.asks] builds it.
  final List<DepthEntity> asks;

  /// Decimal places used for volumes.
  final int baseUnit;

  /// Decimal places used for prices.
  final int quoteUnit;

  /// How many levels of each side to list, counted out from the mid price.
  final int levels;

  /// Keeps only the levels within this fraction of the mid price.
  final double? zoom;

  /// Whether a row's bar is sized by the running total or by its own size.
  ///
  /// The total makes the bars grow away from the mid, showing the shape of the
  /// book; the rung's own size makes each wall stand on its own.
  final bool barsShowTotal;

  /// Whether a [DepthRatioBar] closes the ladder off underneath.
  ///
  /// It weighs the same levels the rows list, so it agrees with what is on
  /// screen rather than with the whole book.
  final bool showRatioBar;

  /// Every colour the ladder paints with.
  final DepthChartColors chartColors;

  /// Geometry: row height, text size and padding.
  final DepthChartStyle chartStyle;

  /// The column headings and the spread label.
  final DepthChartTranslations chartTranslations;

  @override
  Widget build(BuildContext context) {
    final book = DepthBook.fromCurves(bids, asks, zoom: zoom);
    if (book.isEmpty) return const SizedBox.shrink();

    // Both sides are listed outwards from the mid: the best prices first.
    final nearBids = book.bids.reversed.take(levels).toList();
    final nearAsks = book.asks.take(levels).toList();
    final widest = _widestBar([...nearBids, ...nearAsks]);

    final spread = nearAsks.first.price - nearBids.first.price;
    final textStyle = TextStyle(
      color: chartColors.defaultTextColor,
      fontSize: chartStyle.ladderFontSize,
    );

    // Every row states its own colour and size, but a Text still merges onto
    // whatever default style is in scope — and outside a Material that is
    // Flutter's yellow-underlined debug style. Anchoring one here lets the
    // ladder be dropped anywhere, Material ancestor or not.
    return DefaultTextStyle(
      style: textStyle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Header(
            style: textStyle,
            padding: chartStyle.padding,
            translations: chartTranslations,
          ),
          // Asks read downwards to the best one, so the spread sits in the middle.
          for (final level in nearAsks.reversed)
            _Row(
              level: level,
              widest: widest,
              fill: chartColors.dnFillPathColor,
              priceColor: chartColors.dnColor,
              textStyle: textStyle,
              style: chartStyle,
              baseUnit: baseUnit,
              quoteUnit: quoteUnit,
              barsShowTotal: barsShowTotal,
            ),
          _Spread(
            spread: spread,
            mid: book.mid,
            quoteUnit: quoteUnit,
            label: chartTranslations.spread,
            colors: chartColors,
            style: chartStyle,
          ),
          for (final level in nearBids)
            _Row(
              level: level,
              widest: widest,
              fill: chartColors.upFillPathColor,
              priceColor: chartColors.upColor,
              textStyle: textStyle,
              style: chartStyle,
              baseUnit: baseUnit,
              quoteUnit: quoteUnit,
              barsShowTotal: barsShowTotal,
            ),
          if (showRatioBar)
            Padding(
              padding: EdgeInsets.fromLTRB(
                chartStyle.padding,
                chartStyle.padding / 2,
                chartStyle.padding,
                chartStyle.padding,
              ),
              child: DepthRatioBar(
                bids,
                asks,
                zoom: zoom,
                chartColors: chartColors,
                chartStyle: chartStyle,
                chartTranslations: chartTranslations,
              ),
            ),
        ],
      ),
    );
  }

  /// The value a full-width bar stands for.
  double _widestBar(List<DepthLevel> levels) {
    var most = 0.0;
    for (final level in levels) {
      final value = barsShowTotal ? level.cumulative : level.size;
      if (value > most) most = value;
    }
    return most;
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.style,
    required this.padding,
    required this.translations,
  });

  final TextStyle style;
  final double padding;
  final DepthChartTranslations translations;

  @override
  Widget build(BuildContext context) {
    final heading = style.copyWith(fontWeight: FontWeight.w600);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding / 2),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text(translations.price, style: heading)),
          Expanded(
            flex: 3,
            child: Text(
              translations.size,
              style: heading,
              textAlign: TextAlign.end,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              translations.total,
              style: heading,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.level,
    required this.widest,
    required this.fill,
    required this.priceColor,
    required this.textStyle,
    required this.style,
    required this.baseUnit,
    required this.quoteUnit,
    required this.barsShowTotal,
  });

  final DepthLevel level;
  final double widest;
  final Color fill;
  final Color priceColor;
  final TextStyle textStyle;
  final DepthChartStyle style;
  final int baseUnit;
  final int quoteUnit;
  final bool barsShowTotal;

  @override
  Widget build(BuildContext context) {
    final value = barsShowTotal ? level.cumulative : level.size;
    final share = widest <= 0 ? 0.0 : (value / widest).clamp(0.0, 1.0);

    return SizedBox(
      height: style.ladderRowHeight,
      child: Stack(
        children: [
          // The bar grows from the right, away from the prices.
          Align(
            alignment: Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: share == 0 ? null : share,
              child: ColoredBox(color: fill, child: const SizedBox.expand()),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: style.padding),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    NumberUtil.formatFixed(level.price, quoteUnit) ?? '',
                    style: textStyle.copyWith(color: priceColor),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    NumberUtil.formatCompact(level.size, baseUnit),
                    style: textStyle,
                    textAlign: TextAlign.end,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    NumberUtil.formatCompact(level.cumulative, baseUnit),
                    style: textStyle,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Spread extends StatelessWidget {
  const _Spread({
    required this.spread,
    required this.mid,
    required this.quoteUnit,
    required this.label,
    required this.colors,
    required this.style,
  });

  final double spread;
  final double mid;
  final int quoteUnit;
  final String label;
  final DepthChartColors colors;
  final DepthChartStyle style;

  @override
  Widget build(BuildContext context) {
    final percent = mid <= 0 ? 0.0 : spread / mid * 100;
    return Container(
      height: style.ladderRowHeight,
      padding: EdgeInsets.symmetric(horizontal: style.padding),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Text(
            NumberUtil.formatFixed(mid, quoteUnit) ?? '',
            style: TextStyle(
              color: colors.annotationColor,
              fontSize: style.ladderFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '$label ${NumberUtil.formatFixed(spread, quoteUnit) ?? ''} '
            '(${percent.toStringAsFixed(2)}%)',
            style: TextStyle(
              color: colors.defaultTextColor,
              fontSize: style.ladderFontSize,
            ),
          ),
        ],
      ),
    );
  }
}
