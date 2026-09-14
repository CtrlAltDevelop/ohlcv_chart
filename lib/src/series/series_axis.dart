import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The colour axis labels use when no style is given.
const Color seriesAxisTextColor = Color(0xFF909196);

/// The grid colour when none is given.
const Color seriesGridColor = Color(0x33909196);

/// The style axis labels start from, before an axis's own style.
const TextStyle seriesAxisLabelStyle = TextStyle(
  fontSize: 10,
  color: seriesAxisTextColor,
);

/// The style axis titles start from, before an axis's own title style.
const TextStyle seriesAxisTitleStyle = TextStyle(
  fontSize: 11,
  color: seriesAxisTextColor,
  fontWeight: FontWeight.w600,
);

/// Which side of the plot the value axis sits on.
///
/// In a horizontal chart, where the value axis runs across the plot, `left`
/// puts it along the bottom and `right` along the top.
enum SeriesAxisSide {
  /// Labels to the left of the plot, right-aligned against it.
  left,

  /// Labels to the right of the plot, left-aligned against it.
  right,
}

/// Which side of the plot the x axis sits on.
///
/// In a horizontal chart, where the x axis runs down the plot, `bottom` puts
/// it on the left and `top` on the right.
enum SeriesXSide {
  /// Labels under the plot.
  bottom,

  /// Labels over the plot.
  top,
}

/// Writes the label for one position on an axis; null or empty prints none.
typedef SeriesLabelBuilder = String? Function(double value);

/// The x axis of a [SeriesChart].
///
/// Which x values get a label — and a grid line — is decided in this order:
/// [ticks] if given; otherwise every index whose entry in [labels] is not
/// empty, thinned to multiples of [interval] when that is set; otherwise every
/// [interval]; otherwise about [tickCount] round values. Labels that would
/// overlap the one before are dropped.
@immutable
class SeriesXAxis {
  /// Creates an x axis.
  const SeriesXAxis({
    this.show = true,
    this.height = 22,
    this.side = SeriesXSide.bottom,
    this.labels,
    this.labelBuilder,
    this.ticks,
    this.interval,
    this.tickCount = 6,
    this.style,
    this.gap = 4,
    this.fitInside = true,
    this.title,
    this.titleStyle,
  });

  /// No labels and no room held for them.
  static const hidden = SeriesXAxis(show: false);

  /// Whether labels are drawn and room is held for them.
  final bool show;

  /// Room held for the labels, measured across the axis. A horizontal chart
  /// holds at least this beside the plot, and more when a label needs it.
  final double height;

  /// Which side of the plot the labels sit on.
  final SeriesXSide side;

  /// A label per index — `labels[i]` names `x = i`. An empty string prints
  /// nothing, so a list that only names month starts spaces itself.
  final List<String>? labels;

  /// Writes the label for an x value, overriding [labels].
  final SeriesLabelBuilder? labelBuilder;

  /// The exact x values to label and rule.
  final List<double>? ticks;

  /// Label every this many units of x.
  final double? interval;

  /// About how many labels to print when nothing else decides.
  final int tickCount;

  /// Label text style.
  final TextStyle? style;

  /// Space between the plot and the labels.
  final double gap;

  /// Slides the first and last labels inward so they are not cut off.
  final bool fitInside;

  /// A name for the whole axis, written beyond its labels.
  final String? title;

  /// Style of [title].
  final TextStyle? titleStyle;

  /// The label for [x], or null when there is none.
  ///
  /// [step] is the distance between two labels, which decides how many
  /// decimals a plain number is written with; without it, [interval] or 1.
  String? labelFor(double x, {double? step}) {
    final builder = labelBuilder;
    if (builder != null) return builder(x);
    final names = labels;
    if (names != null) {
      final index = x.round();
      if ((x - index).abs() > 1e-9 || index < 0 || index >= names.length) {
        return null;
      }
      return names[index];
    }
    return formatSeriesNumber(x, step ?? interval ?? 1);
  }
}

/// The value axis of a [SeriesChart].
@immutable
class SeriesYAxis {
  /// Creates a value axis.
  const SeriesYAxis({
    this.show = true,
    this.side = SeriesAxisSide.left,
    this.width = 40,
    this.formatter,
    this.ticks,
    this.interval,
    this.tickCount = 5,
    this.style,
    this.gap = 4,
    this.title,
    this.titleStyle,
  });

  /// No labels and no room held for them.
  static const hidden = SeriesYAxis(show: false);

  /// Whether labels are drawn and room is held for them.
  final bool show;

  /// Which side of the plot the labels sit on.
  final SeriesAxisSide side;

  /// Room beside the plot for the labels. Charts stacked one above another
  /// line up when they share it. A horizontal chart measures its value labels
  /// instead.
  final double width;

  /// Writes a value as its label; it also writes the default tooltip's values.
  final String Function(double value)? formatter;

  /// The exact values to label and rule.
  final List<double>? ticks;

  /// Label every this many units, starting from a multiple of it.
  final double? interval;

  /// About how many labels to print when nothing else decides.
  final int tickCount;

  /// Label text style.
  final TextStyle? style;

  /// Space between the plot and the labels.
  final double gap;

  /// A name for the whole axis, written beyond its labels.
  final String? title;

  /// Style of [title].
  final TextStyle? titleStyle;

  /// Writes [value], using [formatter] when there is one and otherwise as many
  /// decimals as [step] needs.
  String format(double value, double step) {
    final write = formatter;
    return write != null ? write(value) : formatSeriesNumber(value, step);
  }
}

/// The lines ruled across the plot at the axis labels.
///
/// Named for an upright chart: [horizontal] lines sit at the values and
/// [vertical] lines at the x labels, whichever way the chart is turned.
@immutable
class SeriesGrid {
  /// Creates a grid.
  const SeriesGrid({
    this.horizontal = true,
    this.vertical = true,
    this.color = seriesGridColor,
    this.width = 1,
    this.dashPattern,
    this.verticalColor,
    this.verticalDashPattern,
  });

  /// No grid lines.
  static const none = SeriesGrid(horizontal: false, vertical: false);

  /// Lines at the value-axis ticks.
  final bool horizontal;

  /// Lines at the x-axis ticks.
  final bool vertical;

  /// Line colour.
  final Color color;

  /// Line width.
  final double width;

  /// Dash and gap lengths, such as `[4, 4]`; null draws solid lines.
  final List<double>? dashPattern;

  /// Colour of the lines at the x ticks; null follows [color].
  final Color? verticalColor;

  /// Dashes of the lines at the x ticks; null follows [dashPattern].
  final List<double>? verticalDashPattern;
}

/// Where a [SeriesReferenceLine] or [SeriesBand] is measured, named for an
/// upright chart.
enum SeriesDirection {
  /// At a value — across an upright chart, down a horizontal one.
  horizontal,

  /// At an x — down an upright chart, across a horizontal one.
  vertical,
}

/// A fixed level drawn over or under the series, such as a zero line or a
/// target.
///
/// It is not interactive, and it does not widen the value range unless
/// [extendsRange] says so — a far-off target would otherwise flatten the data.
@immutable
class SeriesReferenceLine {
  /// A line at the value [value].
  const SeriesReferenceLine.horizontal(
    this.value, {
    this.color = const Color(0x99909196),
    this.width = 1,
    this.dashPattern,
    this.label,
    this.labelStyle,
    this.labelAlignment = Alignment.topRight,
    this.aboveSeries = false,
    this.extendsRange = false,
  }) : direction = SeriesDirection.horizontal;

  /// A line at x = [value].
  const SeriesReferenceLine.vertical(
    this.value, {
    this.color = const Color(0x99909196),
    this.width = 1,
    this.dashPattern,
    this.label,
    this.labelStyle,
    this.labelAlignment = Alignment.topRight,
    this.aboveSeries = false,
  })  : direction = SeriesDirection.vertical,
        extendsRange = false;

  /// What the line is measured at.
  final SeriesDirection direction;

  /// The value (horizontal) or x (vertical) it is drawn at.
  final double value;

  /// Line colour.
  final Color color;

  /// Line width.
  final double width;

  /// Dash and gap lengths; null draws solid.
  final List<double>? dashPattern;

  /// Text written beside the line.
  final String? label;

  /// Style of [label].
  final TextStyle? labelStyle;

  /// Where along and beside the line [label] sits, as it runs on screen:
  /// `topRight` puts it above the right end of a line across the plot.
  final Alignment labelAlignment;

  /// Whether it is drawn over the series rather than under them.
  final bool aboveSeries;

  /// Whether the value range grows to include a line at a value.
  final bool extendsRange;
}

/// A shaded stretch of the plot between two values or two x positions.
@immutable
class SeriesBand {
  /// A band between the values [from] and [to].
  const SeriesBand.horizontal(this.from, this.to, {this.color, this.gradient})
      : direction = SeriesDirection.horizontal;

  /// A band between x = [from] and x = [to].
  const SeriesBand.vertical(this.from, this.to, {this.color, this.gradient})
      : direction = SeriesDirection.vertical;

  /// What the band is measured at.
  final SeriesDirection direction;

  /// One edge.
  final double from;

  /// The other edge.
  final double to;

  /// Fill colour; ignored when [gradient] is set.
  final Color? color;

  /// Gradient laid over the band as it is drawn.
  final Gradient? gradient;
}

/// Writes [value] with as many decimals as a step of [step] needs to tell its
/// neighbours apart, and none for a whole number.
String formatSeriesNumber(double value, double step) {
  if (!value.isFinite) return '';
  if (value == value.roundToDouble() && step >= 1) {
    return value.toStringAsFixed(0);
  }
  // As many decimals as it takes for the step itself to be a whole number:
  // one for 0.5, two for 0.25.
  var decimals = 0;
  var scaled = step.abs();
  while (decimals < 8 &&
      scaled > 0 &&
      (scaled - scaled.roundToDouble()).abs() >
          1e-6 * (scaled < 1 ? 1 : scaled)) {
    scaled *= 10;
    decimals++;
  }
  if (step == 0) decimals = 2;
  final text = value.toStringAsFixed(decimals);
  return text == '-${0.toStringAsFixed(decimals)}' ? text.substring(1) : text;
}
