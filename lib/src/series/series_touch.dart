import 'package:flutter/widgets.dart';

import 'series_data.dart';

/// The gesture that shows a chart's crosshair and tooltip.
enum SeriesTouchTrigger {
  /// Shown while a finger is down or dragging across the chart, gone when it
  /// lifts — `fl_chart`'s default.
  press,

  /// Shown after a long press, following the finger until it lifts. Leaves a
  /// quick swipe free to scroll whatever the chart sits in.
  longPress,

  /// A tap places it and it stays; a drag moves it, and tapping the same point
  /// again clears it.
  tap,

  /// Only a mouse hovering, or the controller, shows it.
  none,
}

/// What a touch picks out on a [SeriesChart].
enum SeriesTouchSnap {
  /// The x nearest the finger, and every series' value there — right for
  /// lines and bars over a shared x.
  x,

  /// The single point nearest the finger, within `SeriesTouch.threshold` —
  /// right for a scatter plot.
  nearestPoint,
}

/// Where the tooltip sits relative to the touched point.
enum SeriesTooltipPlacement {
  /// Beside the crosshair, at the top of the plot, flipping to the other side
  /// when there is no room.
  beside,

  /// Centred above the highest touched value, dropping below it when there is
  /// no room.
  above,
}

/// A line drawn through the touched point.
@immutable
class SeriesCrosshairLine {
  /// Creates a crosshair line.
  const SeriesCrosshairLine({
    this.color = const Color(0x66909196),
    this.width = 1,
    this.dashPattern,
  });

  /// Line colour.
  final Color color;

  /// Line width.
  final double width;

  /// Dash and gap lengths; null draws solid.
  final List<double>? dashPattern;
}

/// Chooses the marker for one touched value; null draws none for it.
typedef SeriesMarkerBuilder = SeriesDot? Function(SeriesTouchValue value);

/// Builds a tooltip for the touched values; return null to show none.
typedef SeriesTooltipBuilder =
    Widget? Function(BuildContext context, SeriesTouchDetails details);

/// The card that names the touched values.
@immutable
class SeriesTooltip {
  /// Creates a tooltip.
  ///
  /// With no [builder], the card lists [title] and a coloured row per touched
  /// series, each value written by [valueFormatter] or the value axis's
  /// formatter.
  const SeriesTooltip({
    this.builder,
    this.title,
    this.valueFormatter,
    this.placement = SeriesTooltipPlacement.beside,
    this.margin = 8,
    this.backgroundColor = const Color(0xF2202329),
    this.borderColor,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    this.titleStyle,
    this.valueStyle,
    this.shadows = const [
      BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2)),
    ],
    this.showSeriesLabels = false,
  });

  /// Builds the whole tooltip; the chart places it and keeps it inside.
  final SeriesTooltipBuilder? builder;

  /// Writes the heading; null uses the x-axis label of the touched x.
  final String? Function(SeriesTouchDetails details)? title;

  /// Writes one touched value.
  final String Function(SeriesTouchValue value)? valueFormatter;

  /// Where the card sits.
  final SeriesTooltipPlacement placement;

  /// Gap between the card and the crosshair or point.
  final double margin;

  /// Card colour.
  final Color backgroundColor;

  /// Card outline; null draws none.
  final Color? borderColor;

  /// Card corner radius.
  final BorderRadius borderRadius;

  /// Space inside the card.
  final EdgeInsets padding;

  /// Heading style.
  final TextStyle? titleStyle;

  /// Value style; null uses white at 12.
  final TextStyle? valueStyle;

  /// Card shadow.
  final List<BoxShadow> shadows;

  /// Whether each row starts with the series label.
  final bool showSeriesLabels;
}

/// How a [SeriesChart] reacts to touch and hover.
@immutable
class SeriesTouch {
  /// Creates a touch configuration.
  const SeriesTouch({
    this.trigger = SeriesTouchTrigger.press,
    this.hover = true,
    this.snap = SeriesTouchSnap.x,
    this.threshold = 24,
    this.line = const SeriesCrosshairLine(),
    this.horizontalLine,
    this.showMarkers = true,
    this.markerBuilder,
    this.tooltip = const SeriesTooltip(),
  });

  /// The gesture that shows the crosshair.
  final SeriesTouchTrigger trigger;

  /// Whether a hovering mouse shows it too.
  final bool hover;

  /// Whether a touch picks an x or a single point.
  final SeriesTouchSnap snap;

  /// How close, in logical pixels, a point has to be for
  /// [SeriesTouchSnap.nearestPoint] to pick it.
  final double threshold;

  /// The line through the touched x, across the values; null draws none.
  final SeriesCrosshairLine? line;

  /// A line through the first touched value, across the x axis; null draws
  /// none.
  final SeriesCrosshairLine? horizontalLine;

  /// Whether each touched value gets a marker.
  final bool showMarkers;

  /// Chooses each marker; null draws a dot of radius 4 in the series colour at
  /// that value.
  final SeriesMarkerBuilder? markerBuilder;

  /// The tooltip; null shows none, leaving `onTouch` to do something else.
  final SeriesTooltip? tooltip;
}

/// One series' value at the touched x.
@immutable
class SeriesTouchValue {
  /// Creates a touched value.
  const SeriesTouchValue({
    required this.seriesIndex,
    required this.series,
    required this.pointIndex,
    required this.point,
    required this.position,
    required this.color,
  });

  /// Where the series is in `SeriesChart.series`.
  final int seriesIndex;

  /// The series.
  final PlotSeries series;

  /// Where the point is in the series' points.
  final int pointIndex;

  /// The point.
  final SeriesPoint point;

  /// The point on the chart, in the chart's local pixels — the far end of a
  /// bar.
  final Offset position;

  /// The series colour at this value.
  final Color color;

  /// The value.
  double get value => point.y!;
}

/// What is under the crosshair.
@immutable
class SeriesTouchDetails {
  /// Creates touch details.
  const SeriesTouchDetails({
    required this.x,
    required this.values,
    required this.position,
    required this.plotRect,
  });

  /// The touched x, snapped to the nearest point.
  final double x;

  /// Every series with a value at [x], in series order — or, for
  /// [SeriesTouchSnap.nearestPoint], the one point touched. Series with
  /// `showInTooltip` off and series with a gap here are left out.
  final List<SeriesTouchValue> values;

  /// Where the tooltip is anchored: on an upright chart the crosshair's x at
  /// the height of the highest touched value; on a horizontal one the
  /// crosshair's y beside the furthest value.
  final Offset position;

  /// The plot area, in the chart's local pixels.
  final Rect plotRect;

  /// [x] as an index, for charts of plain values.
  int get index => x.round();

  /// The touched value of the series at [seriesIndex], if it has one.
  SeriesTouchValue? valueOf(int seriesIndex) {
    for (final value in values) {
      if (value.seriesIndex == seriesIndex) return value;
    }
    return null;
  }
}

/// Shows or clears a [SeriesChart]'s crosshair from code, and shares it.
///
/// Give two charts the same controller and touching either marks the same x
/// on both — a price panel and a volume panel under it, say.
class SeriesChartController extends ChangeNotifier {
  double? _x;
  int? _seriesIndex;
  int? _pointIndex;

  /// The x under the crosshair, or null when it is hidden.
  double? get x => _x;

  /// The series of the single point shown, when one was named.
  int? get seriesIndex => _seriesIndex;

  /// The index of the single point shown, when one was named.
  int? get pointIndex => _pointIndex;

  /// Shows the crosshair at [x] — or, given [seriesIndex] and [pointIndex],
  /// on that one point.
  void show(double x, {int? seriesIndex, int? pointIndex}) {
    if (_x == x && _seriesIndex == seriesIndex && _pointIndex == pointIndex) {
      return;
    }
    _x = x;
    _seriesIndex = seriesIndex;
    _pointIndex = pointIndex;
    notifyListeners();
  }

  /// Hides the crosshair.
  void clear() {
    if (_x == null) return;
    _x = null;
    _seriesIndex = null;
    _pointIndex = null;
    notifyListeners();
  }
}
