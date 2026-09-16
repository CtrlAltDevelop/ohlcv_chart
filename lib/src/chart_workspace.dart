import 'chart_type.dart';
import 'entity/drawing_codec.dart';
import 'indicators/indicator.dart';
import 'indicators/indicator_codec.dart';
import 'price_axis_scale.dart';

/// A chart set up the way somebody left it: its indicators, its drawings and
/// how it was reading the price.
///
/// `ChartDrawings` already persists a drawing layout, and this is the rest of
/// it. Saving both together is what turns "a chart" into "the chart I was
/// working on" — reopen it and the moving averages, the trend lines and the log
/// axis are all where they were.
///
/// ```dart
/// await prefs.setString('workspace', jsonEncode(
///   ChartWorkspace(
///     indicators: indicators,
///     drawings: controller.drawings,
///     priceAxisScale: PriceAxisScale.logarithmic,
///   ).toJson(),
/// ));
///
/// final saved = prefs.getString('workspace');
/// final workspace = saved == null
///     ? const ChartWorkspace()
///     : ChartWorkspace.fromJson(jsonDecode(saved) as Map<String, dynamic>);
///
/// KChartWidget(
///   candles,
///   ChartColors(),
///   isTrendLine: false,
///   indicators: workspace.indicators,
///   drawings: workspace.drawings.all,
///   chartType: workspace.chartType,
///   priceAxisScale: workspace.priceAxisScale,
///   invertPriceAxis: workspace.invertPriceAxis,
/// );
/// ```
///
/// What is deliberately not here: the visible window. A first and last candle
/// index means nothing against a different stretch of history, and restoring a
/// window is `KChartController.showTimeRange` — dates, which do survive. Nor are
/// the colours and geometry, which are `ChartColors` and `ChartStyle`: how your
/// app looks is your app's business, not something a user rearranges.
class ChartWorkspace {
  /// Creates a workspace.
  const ChartWorkspace({
    this.indicators = const [],
    this.drawings,
    this.chartType,
    this.priceAxisScale = PriceAxisScale.linear,
    this.invertPriceAxis = false,
  });

  /// Restores a workspace saved by [toJson].
  ///
  /// Anything this version does not recognise is skipped rather than throwing,
  /// so a workspace written by a newer release still opens — with the indicators
  /// and drawings it does understand, and defaults for the rest.
  factory ChartWorkspace.fromJson(Map<String, dynamic> json) {
    final rawIndicators = json['indicators'];
    return ChartWorkspace(
      indicators: [
        if (rawIndicators is List)
          for (final entry in rawIndicators)
            if (entry is Map<String, dynamic>)
              if (indicatorFromJson(entry) case final v?) v,
      ],
      drawings: switch (json['drawings']) {
        final Map<String, dynamic> saved => ChartDrawings.fromJson(saved),
        _ => null,
      },
      chartType: _enumByName(ChartType.values, json['chartType']),
      priceAxisScale:
          _enumByName(PriceAxisScale.values, json['priceAxisScale']) ??
              PriceAxisScale.linear,
      invertPriceAxis: json['invertPriceAxis'] == true,
    );
  }

  /// The version stamped into [toJson], so a later format can be told apart.
  static const int formatVersion = 1;

  /// The indicators on the chart, in the order they were added.
  final List<Indicator> indicators;

  /// The drawings, or null if none were saved.
  final ChartDrawings? drawings;

  /// How the series is drawn, or null for the chart's own default.
  final ChartType? chartType;

  /// How the price axis spaces its prices.
  final PriceAxisScale priceAxisScale;

  /// Whether the price axis runs the other way up.
  final bool invertPriceAxis;

  /// The indicators that [toJson] cannot write down.
  ///
  /// An indicator of your own, or a built-in carrying a setting the catalog does
  /// not describe, has no entry to rebuild it from — see `indicatorToJson`. They
  /// are left out of the saved workspace rather than saved as something else, and
  /// listed here so an app can say so instead of silently losing them.
  List<Indicator> get unsaveable => [
        for (final indicator in indicators)
          if (indicatorToJson(indicator) == null) indicator,
      ];

  /// Writes the workspace out, ready for `jsonEncode`.
  Map<String, dynamic> toJson() {
    final saved = drawings;
    return {
      'version': formatVersion,
      'indicators': [
        for (final indicator in indicators)
          if (indicatorToJson(indicator) case final v?) v,
      ],
      if (saved != null && saved.isNotEmpty) 'drawings': saved.toJson(),
      if (chartType != null) 'chartType': chartType!.name,
      'priceAxisScale': priceAxisScale.name,
      if (invertPriceAxis) 'invertPriceAxis': true,
    };
  }

  /// A copy with the given fields replaced.
  ///
  /// Passing null leaves a field alone, which is why [chartType] cannot be
  /// cleared this way — build a new workspace for that.
  ChartWorkspace copyWith({
    List<Indicator>? indicators,
    ChartDrawings? drawings,
    ChartType? chartType,
    PriceAxisScale? priceAxisScale,
    bool? invertPriceAxis,
  }) =>
      ChartWorkspace(
        indicators: indicators ?? this.indicators,
        drawings: drawings ?? this.drawings,
        chartType: chartType ?? this.chartType,
        priceAxisScale: priceAxisScale ?? this.priceAxisScale,
        invertPriceAxis: invertPriceAxis ?? this.invertPriceAxis,
      );

  @override
  String toString() => 'ChartWorkspace(${indicators.length} indicators, '
      '${drawings?.length ?? 0} drawings, $priceAxisScale)';

  static T? _enumByName<T extends Enum>(List<T> values, Object? name) {
    if (name is! String) return null;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}
