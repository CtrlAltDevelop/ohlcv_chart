import 'package:flutter/material.dart' show Color;

import '../chart_style.dart';
import '../entity/k_line_entity.dart';
import 'indicator.dart';
import 'indicator_cache.dart';

/// An indicator paired with its computed values, ready to draw.
class ResolvedIndicator {
  /// Creates a resolved indicator.
  const ResolvedIndicator({
    required this.indicator,
    required this.series,
    this.ordinal = 0,
    this.profile,
  });

  /// The configured indicator.
  final Indicator indicator;

  /// Its values, one list per line.
  final IndicatorSeries series;

  /// Position among the other indicators of its group.
  ///
  /// Lets repeated moving averages take different colours from the theme.
  final int ordinal;

  /// Volume gathered by price, for the few indicators that draw a profile.
  final IndicatorProfile? profile;

  /// Colour of [line], from the indicator or the theme.
  Color colorFor(int line, ChartColors theme) =>
      indicator.colorFor(line, theme, ordinal: ordinal);

  /// Value of [line] at [index].
  double? valueAt(int line, int index) => series.valueAt(line, index);
}

/// Drops duplicate indicators, keeping the last of each equal pair.
///
/// The survivor keeps the earliest position, so restyling an indicator does not
/// make its pane jump down the stack.
List<Indicator> dedupeIndicators(Iterable<Indicator> indicators) {
  final kept = <Indicator>[];
  for (final indicator in indicators) {
    final at = kept.indexOf(indicator);
    if (at == -1) {
      kept.add(indicator);
    } else {
      kept[at] = indicator;
    }
  }
  return kept;
}

/// Every indicator on a chart, computed and split by where it is drawn.
class ResolvedIndicators {
  /// Creates a resolution.
  const ResolvedIndicators({
    required this.overlays,
    required this.panes,
    required this.legendRowCount,
  });

  /// An empty resolution, for a chart with no indicators.
  static const ResolvedIndicators empty = ResolvedIndicators(
    overlays: <ResolvedIndicator>[],
    panes: <ResolvedIndicator>[],
    legendRowCount: 0,
  );

  /// Indicators drawn over the candles.
  final List<ResolvedIndicator> overlays;

  /// Indicators drawn in their own panes, in the order they are stacked.
  final List<ResolvedIndicator> panes;

  /// Legend rows the overlays need above the candles, one per group.
  final int legendRowCount;
}

/// Computes [indicators] over [candles], ready for the painters.
///
/// Duplicates are dropped first — see [dedupeIndicators] — so re-adding an
/// indicator that is already on the chart restyles it instead of stacking a
/// second copy. Each indicator is told its position among the others of its
/// group, which is how a second moving average picks up a different colour.
///
/// Pass a [cache] that outlives the call — one per chart — and an indicator
/// whose candles have only grown at the end extends the values it already has
/// instead of recomputing the whole history. Without one every call computes
/// everything from the first candle.
ResolvedIndicators resolveIndicators(
  Iterable<Indicator> indicators,
  List<KLineEntity>? candles, {
  IndicatorCache? cache,
}) {
  final unique = dedupeIndicators(indicators);
  if (unique.isEmpty) {
    cache?.clear();
    return ResolvedIndicators.empty;
  }

  final data = candles ?? const <KLineEntity>[];
  final overlays = <ResolvedIndicator>[];
  final panes = <ResolvedIndicator>[];
  final ordinals = <String, int>{};
  final groups = <String>{};

  for (final indicator in unique) {
    final group = indicator.group;
    final ordinal = ordinals[group] ?? 0;
    ordinals[group] = ordinal + 1;
    final resolved = ResolvedIndicator(
      indicator: indicator,
      series: cache == null
          ? indicator.compute(data)
          : cache.seriesFor(indicator, data),
      ordinal: ordinal,
      profile: cache == null
          ? indicator.computeProfile(data)
          : cache.profileFor(indicator, data),
    );
    if (indicator.placement == IndicatorPlacement.overlay) {
      overlays.add(resolved);
      groups.add(group);
    } else {
      panes.add(resolved);
    }
  }

  cache?.retain(unique);

  return ResolvedIndicators(
    overlays: overlays,
    panes: panes,
    legendRowCount: groups.length,
  );
}
