import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../heatmap/heatmap_chart.dart';
import '../heatmap/heatmap_data.dart';

/// The index of the strike nearest [spot] — the at-the-money column — or null
/// when there are no strikes or the spot is not a number.
int? atTheMoneyIndex(List<double> strikes, double spot) {
  if (!spot.isFinite) return null;
  int? best;
  var closest = double.infinity;
  for (var i = 0; i < strikes.length; i++) {
    if (!strikes[i].isFinite) continue;
    final distance = (strikes[i] - spot).abs();
    if (distance < closest) {
      closest = distance;
      best = i;
    }
  }
  return best;
}

/// How far each strike's volatility in [row] sits from the one at [atmIndex]:
/// the skew, as a difference of fractions. Null where either is missing.
List<double?> surfaceSkew(List<double?> row, int? atmIndex) {
  final atm = atmIndex != null && atmIndex < row.length ? row[atmIndex] : null;
  return [
    for (final value in row)
      value == null || atm == null || !value.isFinite || !atm.isFinite
          ? null
          : value - atm,
  ];
}

/// What a touch on a [VolatilitySurfaceChart] landed on.
@immutable
class VolatilitySurfaceTouchDetails {
  /// Creates the details of a touch on the square at [expiryIndex] and
  /// [strikeIndex].
  const VolatilitySurfaceTouchDetails({
    required this.expiryIndex,
    required this.strikeIndex,
    required this.expiry,
    required this.strike,
    required this.volatility,
    required this.atTheMoneyVolatility,
    required this.rect,
  });

  /// Which expiry, counted from the top.
  final int expiryIndex;

  /// Which strike, counted from the left.
  final int strikeIndex;

  /// What the expiry is called.
  final String expiry;

  /// The strike.
  final double strike;

  /// The implied volatility there, as a fraction; null where there is none.
  final double? volatility;

  /// The volatility at the money for the same expiry, as a fraction; null when
  /// the chart has no spot or that reading is missing.
  final double? atTheMoneyVolatility;

  /// The square, in the chart's local pixels.
  final Rect rect;

  /// How far this strike sits above the at-the-money volatility, as a
  /// difference of fractions; null when either is missing.
  double? get skew {
    final here = volatility;
    final atm = atTheMoneyVolatility;
    if (here == null || atm == null) return null;
    return here - atm;
  }
}

/// Implied volatility across strike and expiry at once — a volatility surface
/// as a heatmap.
///
/// ```dart
/// VolatilitySurfaceChart(
///   strikes: const [90, 95, 100, 105, 110],
///   expiries: const ['1W', '1M', '3M', '6M'],
///   volatilities: [
///     [0.34, 0.30, 0.28, 0.29, 0.32], // one row per expiry
///     [0.31, 0.28, 0.26, 0.27, 0.29],
///     [0.29, 0.27, 0.25, 0.26, 0.28],
///     [0.28, 0.26, 0.25, 0.26, 0.27],
///   ],
///   spot: 100,
/// );
/// ```
///
/// Squares run from [lowColor] through [midColor] to [highColor]. Volatilities
/// are fractions: 0.25 is 25%. A [spot] marks the at-the-money strike's column
/// in the tooltip's skew, and `null` entries are left empty. The chart fills the
/// box it is given, and is [defaultHeight] high in a box with no height of its
/// own.
class VolatilitySurfaceChart extends StatelessWidget {
  /// Creates a surface of [volatilities], one row per entry of [expiries] and
  /// one column per entry of [strikes].
  const VolatilitySurfaceChart({
    super.key,
    required this.strikes,
    required this.expiries,
    required this.volatilities,
    this.spot,
    this.lowColor = const Color(0xFF3B6FD4),
    this.midColor = const Color(0xFFE8C547),
    this.highColor = const Color(0xFFD94841),
    this.minVolatility,
    this.maxVolatility,
    this.showValues = true,
    this.valueFormatter,
    this.strikeFormatter,
    this.labelStyle,
    this.axisLabelStyle,
    this.expiryAxisWidth = 44,
    this.strikeAxisHeight = 20,
    this.spacing = 1,
    this.radius = const BorderRadius.all(Radius.circular(2)),
    this.onTouch,
    this.tooltipBuilder,
    this.animationDuration = Duration.zero,
    this.animationCurve = Curves.easeOutCubic,
    this.animateOnMount = true,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.defaultHeight = 240,
    this.semanticLabel,
  });

  /// The strikes along the bottom, left to right.
  final List<double> strikes;

  /// What each expiry is called, top to bottom.
  final List<String> expiries;

  /// The implied volatilities as fractions, a row per expiry holding a value
  /// per strike. A row shorter than [strikes], or a null, leaves squares empty.
  final List<List<double?>> volatilities;

  /// The price of the underlying; null reads no at-the-money strike.
  final double? spot;

  /// The colour of the lowest volatility.
  final Color lowColor;

  /// The colour half way up.
  final Color midColor;

  /// The colour of the highest.
  final Color highColor;

  /// The volatility painted in [lowColor]; null takes the lowest on the
  /// surface.
  final double? minVolatility;

  /// The volatility painted in [highColor]; null takes the highest.
  final double? maxVolatility;

  /// Whether each square's volatility is written in it.
  final bool showValues;

  /// Writes a volatility; null writes a percentage with no decimals.
  final String Function(double volatility)? valueFormatter;

  /// Writes a strike; null writes at most two decimals.
  final String Function(double strike)? strikeFormatter;

  /// Style of the values in the squares; null picks black or white.
  final TextStyle? labelStyle;

  /// Style of the strike and expiry names.
  final TextStyle? axisLabelStyle;

  /// Room held for the expiry names.
  final double expiryAxisWidth;

  /// Room held for the strikes.
  final double strikeAxisHeight;

  /// The gap between squares.
  final double spacing;

  /// The rounding of each square's corners.
  final BorderRadius radius;

  /// Called as a touch moves over the squares, and with null when it leaves.
  final ValueChanged<VolatilitySurfaceTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched square; null shows none.
  final Widget? Function(
    BuildContext context,
    VolatilitySurfaceTouchDetails details,
  )?
  tooltipBuilder;

  /// How long the squares take to fade in; zero draws them at once.
  final Duration animationDuration;

  /// The easing of [animationDuration].
  final Curve animationCurve;

  /// Whether the first build animates.
  final bool animateOnMount;

  /// Space kept clear around the chart.
  final EdgeInsets padding;

  /// Painted behind the whole chart.
  final Color? backgroundColor;

  /// The height taken in a box that sets none.
  final double defaultHeight;

  /// What a screen reader announces for the chart.
  final String? semanticLabel;

  /// The lowest and highest volatility drawn.
  ({double min, double max}) get volatilityRange {
    var low = double.infinity;
    var high = double.negativeInfinity;
    for (final row in volatilities) {
      for (final value in row) {
        if (value == null || !value.isFinite) continue;
        low = math.min(low, value);
        high = math.max(high, value);
      }
    }
    if (!low.isFinite) {
      return (min: minVolatility ?? 0, max: maxVolatility ?? 1);
    }
    return (min: minVolatility ?? low, max: maxVolatility ?? high);
  }

  @override
  Widget build(BuildContext context) {
    final cells = <HeatmapCell>[
      for (var e = 0; e < expiries.length && e < volatilities.length; e++)
        for (var s = 0; s < strikes.length && s < volatilities[e].length; s++)
          if (volatilities[e][s] case final value?
              when value.isFinite && strikes[s].isFinite)
            HeatmapCell(x: s, y: e, value: value),
    ];

    final range = volatilityRange;
    final atm = spot == null ? null : atTheMoneyIndex(strikes, spot!);
    final format = valueFormatter ?? (v) => '${(v * 100).round()}%';

    VolatilitySurfaceTouchDetails details(HeatmapTouchDetails touch) {
      final row = touch.y < volatilities.length
          ? volatilities[touch.y]
          : const <double?>[];
      final atmValue = atm != null && atm < row.length ? row[atm] : null;
      return VolatilitySurfaceTouchDetails(
        expiryIndex: touch.y,
        strikeIndex: touch.x,
        expiry: touch.y < expiries.length ? expiries[touch.y] : '',
        strike: touch.x < strikes.length ? strikes[touch.x] : double.nan,
        volatility: touch.value,
        atTheMoneyVolatility: atmValue != null && atmValue.isFinite
            ? atmValue
            : null,
        rect: touch.rect,
      );
    }

    String strikeLabel(int s) {
      if (s >= strikes.length) return '';
      final value = strikes[s];
      if (strikeFormatter != null) return strikeFormatter!(value);
      final rounded = double.parse(value.toStringAsFixed(2));
      return rounded == rounded.roundToDouble()
          ? rounded.toStringAsFixed(0)
          : rounded.toString();
    }

    final touch = onTouch;
    final builder = tooltipBuilder;
    return HeatmapChart(
      cells: cells,
      columns: strikes.length,
      rows: expiries.length,
      scale: HeatmapGradientScale(colors: [lowColor, midColor, highColor]),
      minValue: range.min,
      maxValue: range.max,
      xAxis: HeatmapAxis(
        labelBuilder: strikeLabel,
        size: strikeAxisHeight,
        style: axisLabelStyle,
        interval: strikes.length > 12 ? 2 : 1,
      ),
      yAxis: HeatmapAxis(
        labels: expiries,
        size: expiryAxisWidth,
        style: axisLabelStyle,
      ),
      spacing: spacing,
      radius: radius,
      labelBuilder: showValues
          ? (cell) => cell.isEmpty ? null : format(cell.value!)
          : null,
      labelStyle: labelStyle,
      onTouch: touch == null
          ? null
          : (t) => touch(t == null ? null : details(t)),
      tooltipBuilder: builder == null
          ? null
          : (context, t) => builder(context, details(t)),
      animationDuration: animationDuration,
      animationCurve: animationCurve,
      animateOnMount: animateOnMount,
      padding: padding,
      backgroundColor: backgroundColor,
      defaultHeight: defaultHeight,
      semanticLabel: semanticLabel,
    );
  }
}
