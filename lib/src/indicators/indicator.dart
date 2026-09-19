import 'package:material_ui/material_ui.dart' show Color;

import '../chart_style.dart';
import '../entity/k_line_entity.dart';

/// Where an indicator is drawn.
enum IndicatorPlacement {
  /// Over the candles, on the price scale.
  overlay,

  /// In its own pane below the chart, on its own scale.
  pane,
}

/// How one of an indicator's lines is painted.
enum IndicatorShape {
  /// A continuous stroke through every value.
  line,

  /// One dot per candle.
  dots,

  /// Bars growing from zero.
  histogram,

  /// A stroke from value to value, straight across the candles that have none.
  ///
  /// What a zigzag needs: its values sit only on the pivots, and the line is
  /// the leg between them.
  pivotLine,

  /// A dot per value with the indicator's own text beside it.
  ///
  /// See [Indicator.markerLabel], which is what the text comes from.
  markers,
}

/// A shaded area between two of an indicator's lines, such as an Ichimoku
/// cloud.
class IndicatorFill {
  /// Shades between [line] and [against].
  const IndicatorFill(this.line, this.against);

  /// The line the fill is measured from.
  final int line;

  /// The line it is shaded against.
  final int against;
}

/// How an indicator's values are written out in legends and axis labels.
enum IndicatorFormat {
  /// The chart's `fixedLength` decimals, for values on the price scale.
  price,

  /// Two decimals, for oscillators.
  decimal,

  /// Abbreviated with a K, M or B suffix, for volume-sized values.
  compact,
}

/// One line of an indicator: what it is called and how it is drawn.
class IndicatorLine {
  /// Creates a line description.
  const IndicatorLine(this.label, {this.shape = IndicatorShape.line});

  /// Name shown in the legend, such as `MA5` or `+DI`.
  final String label;

  /// How the line is painted.
  final IndicatorShape shape;
}

/// An indicator's computed values: one list per line, one entry per candle.
///
/// Entries are null where the indicator has not warmed up yet.
class IndicatorSeries {
  /// Creates a series from one list of values per line.
  const IndicatorSeries(this.lines);

  /// Values per line, in the order of the indicator's [Indicator.lines].
  final List<List<double?>> lines;

  /// The value of [line] at [index], or null if there is none.
  double? valueAt(int line, int index) {
    if (line < 0 || line >= lines.length) return null;
    final values = lines[line];
    if (index < 0 || index >= values.length) return null;
    return values[index];
  }
}

/// One price band of a volume profile: how much traded between two prices.
class ProfileBin {
  /// Creates a band running from [low] to [high].
  const ProfileBin({
    required this.low,
    required this.high,
    required this.volume,
    this.upVolume = 0,
  });

  /// Bottom of the band.
  final double low;

  /// Top of the band.
  final double high;

  /// Everything that traded inside it.
  final double volume;

  /// The part of [volume] that traded on candles that closed up.
  ///
  /// What splits a bin into its buying and selling halves. Never more than
  /// [volume].
  final double upVolume;

  /// The part of [volume] that traded on candles that closed down.
  double get downVolume => volume - upVolume;
}

/// Volume gathered by price rather than by time: what a volume profile draws.
///
/// Returned by [Indicator.computeProfile] and drawn as horizontal bars across
/// the candles, so the prices the market spent its volume at can be read off
/// the same axis as the candles themselves.
class IndicatorProfile {
  /// Creates a profile over [bins], lowest first.
  const IndicatorProfile({
    required this.bins,
    required this.pointOfControl,
    this.valueAreaHigh,
    this.valueAreaLow,
  });

  /// The bands, from the lowest price up.
  final List<ProfileBin> bins;

  /// Index into [bins] of the band that traded most — the point of control.
  ///
  /// -1 when there is nothing to draw.
  final int pointOfControl;

  /// Top of the band that holds the value area, if one was worked out.
  final double? valueAreaHigh;

  /// Bottom of it.
  final double? valueAreaLow;

  /// The busiest band's volume, which every other bar is drawn relative to.
  double get peakVolume => bins.isEmpty
      ? 0
      : bins.map((bin) => bin.volume).reduce((a, b) => a > b ? a : b);

  /// Whether there is anything to draw.
  bool get isEmpty => bins.isEmpty || peakVolume <= 0;
}

/// How a session's pivot levels are worked out from the session before it.
enum PivotMethod {
  /// The classic pivot: `(H + L + C) / 3`, with the supports and resistances
  /// stepped out by the session's range.
  standard,

  /// The same pivot, with the levels placed at 38.2%, 61.8% and 100% of the
  /// range instead.
  fibonacci,

  /// Levels crowded much closer to the close, which is what a mean-reverting
  /// day is read with.
  camarilla,
}

/// The stretch of time one set of pivot levels is worked out from.
enum PivotSession {
  /// A calendar day, which is what an intraday chart is usually pivoted off.
  day,

  /// A calendar week, running from the Monday.
  week,

  /// A calendar month.
  month,

  /// A calendar year.
  year;

  /// What marks [candle] out as belonging to one session rather than another.
  ///
  /// Two candles in the same session answer equal, so the series can be split
  /// by walking it once. A candle with no timestamp answers null and is left
  /// out of every session.
  Object? keyOf(KLineEntity candle) {
    final time = candle.dateTime;
    if (time == null) return null;
    return switch (this) {
      PivotSession.day => (time.year, time.month, time.day),
      // The Monday of the week the candle falls in, so a week that straddles
      // a month or a year still reads as one session.
      PivotSession.week => () {
        final monday = time.subtract(Duration(days: time.weekday - 1));
        return (monday.year, monday.month, monday.day);
      }(),
      PivotSession.month => (time.year, time.month),
      PivotSession.year => time.year,
    };
  }
}

/// How an indicator's pane spaces the values it draws.
enum IndicatorScale {
  /// Even steps: the default, and what an oscillator wants.
  linear,

  /// Steps by ratio, so a doubling takes the same room wherever it happens.
  ///
  /// What a volume or an on-balance-volume pane wants, where the interesting
  /// range covers orders of magnitude. A pane whose values reach zero or below
  /// has no logarithm to space by and falls back to linear.
  logarithmic,

  /// The move away from the first value in view, as a percentage.
  ///
  /// Panning moves the base along with the window, so what is read is always
  /// the move over what is on screen.
  percentage,
}

/// A level on an indicator that reports when the newest value crosses it.
///
/// Add them to an indicator's [Indicator.alerts] and the chart reports through
/// `KChartWidget.onIndicatorAlert` whenever the newest candle's value moves from
/// one side of [level] to the other — an RSI going over 70, a MACD histogram
/// turning positive.
class IndicatorAlert {
  /// Creates an alert on [level] of [line].
  const IndicatorAlert({required this.level, this.line = 0, this.label});

  /// The value being crossed.
  final double level;

  /// Which of the indicator's lines to watch.
  final int line;

  /// What to call it in a notification, or null for the level itself.
  final String? label;

  @override
  bool operator ==(Object other) =>
      other is IndicatorAlert &&
      other.level == level &&
      other.line == line &&
      other.label == label;

  @override
  int get hashCode => Object.hash(level, line, label);
}

/// One configured indicator: a type, its settings, and optionally its colours.
///
/// Add as many as you like, including several of the same kind with different
/// settings — `AtrIndicator(period: 8)`, `AtrIndicator(period: 14)` and
/// `AtrIndicator(period: 20)` are three separate panes:
///
/// ```dart
/// KChartWidget(
///   candles,
///   ChartColors(),
///   isTrendLine: false,
///   timeFrame: const Duration(minutes: 15),
///   indicators: [
///     MaIndicator(period: 50, color: Colors.amber),
///     AtrIndicator(period: 8),
///     AtrIndicator(period: 14),
///   ],
/// );
/// ```
///
/// Two indicators of the same type with the same [settings] are equal, whatever
/// colours they carry. That is what makes re-adding one an edit rather than a
/// duplicate: see `upsert` on a list of indicators, and note that the chart
/// keeps the last of any equal pair it is given.
abstract class Indicator {
  /// Creates an indicator, optionally overriding its line colours.
  Indicator({List<Color>? colors})
    : colors = colors == null ? null : List<Color>.unmodifiable(colors);

  /// Colour per line, in the order of [lines]; null falls back to the theme.
  final List<Color>? colors;

  /// Whether this draws over the candles or in its own pane.
  IndicatorPlacement get placement;

  /// Short name of the indicator type, such as `ATR`.
  String get name;

  /// Name with its settings, such as `ATR(14)`.
  String get label;

  /// Legend row overlays share; instances with the same group sit on one row.
  String get group => name;

  /// The lines this indicator draws.
  List<IndicatorLine> get lines;

  /// The settings that, with the type, make one indicator distinct.
  ///
  /// Colours are deliberately left out, so re-adding an indicator with a new
  /// colour updates the one already there.
  ///
  /// Two indicators of a type with equal settings are taken to be the same
  /// indicator throughout: `dedupeIndicators` keeps one of them, `upsert`
  /// replaces one with the other, and an alert on one carries its state over to
  /// the other. So a custom indicator that reads a period or a source field
  /// should name it here.
  ///
  /// An indicator may still compute different values from one build to the next
  /// with its settings unchanged — reading a series handed in from outside, say.
  /// That works: `IndicatorCache` only reuses values for the very same instance
  /// while the candles sit still, and recomputes for a new one.
  List<Object?> get settings;

  /// Computes one value per candle for each of [lines].
  IndicatorSeries compute(List<KLineEntity> candles);

  /// Recomputes [previous] for candles that have changed at or after [from].
  ///
  /// A live feed moves the newest candle several times a second. Rather than
  /// recompute the whole history each time, the chart offers the series it
  /// already has and the earliest index that can have moved; an indicator that
  /// can pick the recursion up from there returns the extended series, and one
  /// that cannot returns null and is recomputed in full.
  ///
  /// Whatever is returned must be what [compute] would give for the same
  /// candles: this is a shortcut through the arithmetic, not a cheaper estimate
  /// of it. The one allowance is rounding — a series that carries a running
  /// total accumulates it differently when it starts part-way along, which
  /// moves the last bit or two of a value and nothing a chart can draw.
  /// `graftTail`, `emaTail`, `atrTail` and `obvTail` in `series_math.dart` are
  /// the shapes that hold:
  /// a window the value depends on, or a recursion whose own last value is all
  /// the state it needs. Anything reading the whole history — a cumulative
  /// total, a smoothing whose state is not published, a swing count — should
  /// leave this alone.
  ///
  /// [from] is always at least 0 and at most `candles.length`.
  ///
  /// The series returned may reuse [previous]'s own storage rather than allocate
  /// alongside it — a tick leaves the series the same length, and copying every
  /// value to move the last one would put back the cost this is here to avoid.
  /// So [previous] is spent once this has been called, and the caller must read
  /// the returned series instead. `IndicatorCache` does exactly that.
  IndicatorSeries? extendSeries(
    List<KLineEntity> candles,
    IndicatorSeries previous,
    int from,
  ) => null;

  /// Volume gathered by price, for an indicator that draws a profile.
  ///
  /// Null for all but a handful: most indicators have one value per candle and
  /// nothing to say about the prices in between. An overlay that returns one
  /// has it drawn as horizontal bars over the candles, on the same axis.
  IndicatorProfile? computeProfile(List<KLineEntity> candles) => null;

  /// Areas shaded between two lines, drawn under them.
  List<IndicatorFill> get fills => const [];

  /// Colour of [fill], which may differ with which of its lines is on top.
  ///
  /// [isAbove] is whether `fill.line` currently sits above `fill.against` —
  /// what turns an Ichimoku cloud from green to red.
  Color fillColor(
    IndicatorFill fill,
    ChartColors theme, {
    required bool isAbove,
  }) => (isAbove ? theme.upColor : theme.dnColor).withValues(alpha: 0.12);

  /// Text drawn beside the point at [index] on [line], for a marker series.
  ///
  /// Returns null where the point has no label. Only [IndicatorShape.markers]
  /// looks at it.
  String? markerLabel(int line, int index) => null;

  /// Levels to draw a faint guide line at, such as 30 and 70 for an RSI.
  List<double> get guides => const [];

  /// A scale to pin the pane to, rather than fitting it to the values.
  (double, double)? get fixedRange => null;

  /// Whether the pane's scale must include zero, as a histogram needs.
  bool get includeZero => false;

  /// How this indicator's pane spaces its values.
  ///
  /// Linear for almost everything; a pane whose interesting range covers orders
  /// of magnitude reads better logarithmic, and one being compared against
  /// itself over time reads better as a percentage. Ignored by an overlay,
  /// which is drawn on the price scale.
  IndicatorScale get scale => IndicatorScale.linear;

  /// Levels that report when the newest value crosses them.
  ///
  /// Reported through `KChartWidget.onIndicatorAlert`, once per crossing — the
  /// value has to come back through the level before it fires again.
  List<IndicatorAlert> get alerts => const [];

  /// How values are written out.
  IndicatorFormat get format => IndicatorFormat.decimal;

  /// Colour of [line], preferring what the caller gave over the theme.
  ///
  /// [ordinal] is the indicator's position among others of its [group], which
  /// is how repeated moving averages pick up different theme colours.
  Color colorFor(int line, ChartColors theme, {int ordinal = 0}) {
    final overrides = colors;
    if (overrides != null && line < overrides.length) return overrides[line];
    return defaultColor(line, theme, ordinal);
  }

  /// Theme colour for [line] when the caller has not chosen one.
  Color defaultColor(int line, ChartColors theme, int ordinal);

  /// Colour for a single point, where it differs from the line's colour.
  ///
  /// Returns null to use the line colour. Lets a histogram take the up and down
  /// colours, or SAR dots flip with the trend.
  Color? colorForPoint(
    int line,
    int index,
    KLineEntity candle,
    double value,
    ChartColors theme,
  ) => null;

  @override
  bool operator ==(Object other) =>
      other is Indicator &&
      other.runtimeType == runtimeType &&
      _sameSettings(other.settings, settings);

  @override
  int get hashCode => Object.hash(runtimeType, Object.hashAll(settings));

  @override
  String toString() => label;

  static bool _sameSettings(List<Object?> a, List<Object?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Editing helpers for a list of indicators.
extension IndicatorListEditing on List<Indicator> {
  /// Adds [indicator], or replaces the equal one already in the list.
  ///
  /// Equality ignores colours, so adding `AtrIndicator(period: 14)` in a new
  /// colour restyles the ATR(14) that is already there — in its existing
  /// position — rather than stacking a second, identical pane. Returns true
  /// when an existing indicator was replaced.
  bool upsert(Indicator indicator) {
    final at = indexOf(indicator);
    if (at == -1) {
      add(indicator);
      return false;
    }
    this[at] = indicator;
    return true;
  }

  /// Removes [indicator] if the list holds it, and reports whether it did.
  bool removeIndicator(Indicator indicator) => remove(indicator);

  /// Adds [indicator] if it is missing, removes it if it is present.
  ///
  /// Returns true when the indicator ends up in the list.
  bool toggle(Indicator indicator) {
    if (remove(indicator)) return false;
    add(indicator);
    return true;
  }
}
