import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../heatmap/heatmap_data.dart';
import '../renderer/text_painter_cache.dart';
import '../series/series_axis.dart';

/// One day of a [CalendarChart] — a day's profit and loss, trades, volume.
@immutable
class CalendarDay {
  /// Creates the entry for [date], worth [value].
  const CalendarDay({
    required this.date,
    required this.value,
    this.color,
    this.data,
  });

  /// The day. Only the year, month and day are read.
  final DateTime date;

  /// What the day is worth: the number the square is coloured by.
  final double value;

  /// A colour of this day's own, which wins over the chart's scale.
  final Color? color;

  /// Anything the app wants back when this day is touched.
  final Object? data;
}

/// Where one day was laid out.
@immutable
class CalendarCell {
  /// Creates the square of [date].
  const CalendarCell({
    required this.date,
    required this.rect,
    required this.month,
    this.day,
  });

  /// The day this square stands for.
  final DateTime date;

  /// The square, in the chart's local pixels.
  final Rect rect;

  /// Which month panel it belongs to, from the first.
  final int month;

  /// What the app gave for this day, or null when it gave nothing.
  final CalendarDay? day;

  /// The day's value, or null when there is none.
  double? get value => day?.value;

  /// Whether [local] is inside the square.
  bool contains(Offset local) => rect.contains(local);
}

/// Where one month was laid out.
@immutable
class CalendarMonthPanel {
  /// Creates the panel of the month beginning [firstDay].
  const CalendarMonthPanel({
    required this.firstDay,
    required this.index,
    required this.rect,
    required this.headerRect,
    required this.total,
    required this.days,
  });

  /// The first day of the month.
  final DateTime firstDay;

  /// Its position among the panels, from the first.
  final int index;

  /// The whole panel, header included.
  final Rect rect;

  /// The strip the month's name is written in.
  final Rect headerRect;

  /// What the month's days add up to.
  final double total;

  /// How many days of the month carry a value.
  final int days;
}

/// The month panels and the day squares inside them.
@immutable
class CalendarLayout {
  /// Creates a layout of [months] and [cells].
  const CalendarLayout({
    required this.months,
    required this.cells,
    required this.cellSize,
    required this.height,
  });

  /// An empty calendar.
  static const CalendarLayout empty =
      CalendarLayout(months: [], cells: [], cellSize: 0, height: 0);

  /// The month panels, in order.
  final List<CalendarMonthPanel> months;

  /// Every day square drawn, in order.
  final List<CalendarCell> cells;

  /// How large one day square is.
  final double cellSize;

  /// How tall the whole calendar came out, whatever room it was given.
  final double height;

  /// Whether nothing was laid out.
  bool get isEmpty => cells.isEmpty;
}

/// The first day of the month [date] falls in.
DateTime _monthOf(DateTime date) => DateTime(date.year, date.month);

/// How many days the month beginning [month] has.
int _daysInMonth(DateTime month) =>
    DateTime(month.year, month.month + 1, 0).day;

/// Lays out one month panel per month from [from] to [to] across [bounds].
///
/// Panels flow left to right, [monthsPerRow] to a row — as many as fit when
/// that is null. Inside a panel the days run in weeks beginning on
/// [firstWeekday], one square each. When the months given cover more rows than
/// [bounds] is tall, the squares are made smaller so everything still fits.
CalendarLayout layOutCalendar(
  List<CalendarDay> days,
  Rect bounds, {
  DateTime? from,
  DateTime? to,
  int firstWeekday = DateTime.monday,
  int? monthsPerRow,
  double cellSpacing = 2,
  double headerHeight = 16,
  double monthSpacing = 12,
  double minPanelWidth = 130,
}) {
  if (bounds.width <= 0 || bounds.height <= 0) return CalendarLayout.empty;

  final byDay = <DateTime, CalendarDay>{};
  var earliest = from == null ? null : _monthOf(from);
  var latest = to == null ? null : _monthOf(to);
  for (final day in days) {
    final at = DateTime(day.date.year, day.date.month, day.date.day);
    byDay[at] = day;
    final month = _monthOf(at);
    if (from == null && (earliest == null || month.isBefore(earliest))) {
      earliest = month;
    }
    if (to == null && (latest == null || month.isAfter(latest))) {
      latest = month;
    }
  }
  if (earliest == null || latest == null || latest.isBefore(earliest)) {
    return CalendarLayout.empty;
  }

  final months = <DateTime>[];
  for (var month = earliest;
      !month.isAfter(latest) && months.length < 240;
      month = DateTime(month.year, month.month + 1)) {
    months.add(month);
  }

  final gap = math.max(0.0, monthSpacing);
  final perRow = (monthsPerRow ??
          math.max(1, ((bounds.width + gap) / (minPanelWidth + gap)).floor()))
      .clamp(1, months.length);
  final rows = (months.length / perRow).ceil();
  final panelWidth = (bounds.width - gap * (perRow - 1)) / perRow;
  if (panelWidth <= 0) return CalendarLayout.empty;

  final spacing = math.max(0.0, cellSpacing);
  var cell = (panelWidth - spacing * 6) / 7;
  if (cell <= 0) return CalendarLayout.empty;

  // Six week rows is the most any month needs; keeping every panel the same
  // height lines the rows up.
  const weeks = 6;
  var panelHeight = headerHeight + weeks * (cell + spacing);
  final needed = rows * panelHeight + gap * (rows - 1);
  if (needed > bounds.height) {
    // Shrink the squares until the whole calendar fits the box it was given.
    final free = bounds.height - gap * (rows - 1) - rows * headerHeight;
    cell = math.max(0.0, free / (rows * weeks) - spacing);
    panelHeight = headerHeight + weeks * (cell + spacing);
  }
  if (cell <= 0) return CalendarLayout.empty;

  final panels = <CalendarMonthPanel>[];
  final cells = <CalendarCell>[];

  for (var i = 0; i < months.length; i++) {
    final month = months[i];
    final left = bounds.left + (i % perRow) * (panelWidth + gap);
    final top = bounds.top + (i ~/ perRow) * (panelHeight + gap);
    final rect = Rect.fromLTWH(left, top, panelWidth, panelHeight);

    var total = 0.0;
    var counted = 0;
    // Which column the first of the month falls in, given the week's start.
    final lead = (DateTime(month.year, month.month, 1).weekday - firstWeekday +
            7) %
        7;
    for (var day = 1; day <= _daysInMonth(month); day++) {
      final date = DateTime(month.year, month.month, day);
      final at = lead + day - 1;
      final entry = byDay[date];
      if (entry != null) {
        total += entry.value.isFinite ? entry.value : 0;
        counted++;
      }
      cells.add(
        CalendarCell(
          date: date,
          month: i,
          day: entry,
          rect: Rect.fromLTWH(
            left + (at % 7) * (cell + spacing),
            top + headerHeight + (at ~/ 7) * (cell + spacing),
            cell,
            cell,
          ),
        ),
      );
    }

    panels.add(
      CalendarMonthPanel(
        firstDay: month,
        index: i,
        rect: rect,
        headerRect: Rect.fromLTWH(left, top, panelWidth, headerHeight),
        total: total,
        days: counted,
      ),
    );
  }

  return CalendarLayout(
    months: panels,
    cells: cells,
    cellSize: cell,
    height: rows * panelHeight + gap * (rows - 1),
  );
}

/// The day square under [local], or null when there is none.
CalendarCell? calendarCellAt(CalendarLayout layout, Offset local) {
  for (final cell in layout.cells) {
    if (cell.contains(local)) return cell;
  }
  return null;
}

/// The lowest and the highest value among [days], or (0, 1) when there is
/// nothing to measure.
(double, double) calendarValueRange(List<CalendarDay> days) {
  var min = double.infinity;
  var max = double.negativeInfinity;
  for (final day in days) {
    if (!day.value.isFinite) continue;
    min = math.min(min, day.value);
    max = math.max(max, day.value);
  }
  if (!min.isFinite || !max.isFinite) return (0, 1);
  return (min, max);
}

/// What a touch on a [CalendarChart] landed on.
@immutable
class CalendarTouchDetails {
  /// Creates the details of a touch on [cell].
  const CalendarTouchDetails({required this.cell, required this.month});

  /// The day square touched.
  final CalendarCell cell;

  /// The month panel it sits in.
  final CalendarMonthPanel month;

  /// The day it stands for.
  DateTime get date => cell.date;

  /// What the app gave for that day, or null when it gave nothing.
  CalendarDay? get day => cell.day;
}

/// The names months are written by, January first.
const List<String> defaultCalendarMonthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// The names weekdays are written by, Monday first.
/// How much room the weekday row takes under a month's title, where
/// [CalendarChart.showWeekdayHeader] asks for one.
const double calendarWeekdayRowHeight = 12;

const List<String> defaultCalendarWeekdayNames = [
  'M',
  'T',
  'W',
  'T',
  'F',
  'S',
  'S',
];

/// A day-by-day calendar, each day coloured by its value.
///
/// It reads a run of daily numbers at a glance: profit and loss by day, trades
/// taken, hours worked.
///
/// ```dart
/// CalendarChart(
///   days: [
///     for (final entry in pnlByDay.entries)
///       CalendarDay(date: entry.key, value: entry.value),
///   ],
///   scale: const HeatmapStepScale(
///     steps: [
///       HeatmapStep(-double.infinity, Color(0xFFE03131)),
///       HeatmapStep(0, Color(0xFF2F9E44)),
///     ],
///   ),
/// );
/// ```
///
/// The chart fills the box it is given, and is [defaultHeight] high in a box
/// with no height of its own.
class CalendarChart extends StatefulWidget {
  /// Creates a calendar of [days].
  const CalendarChart({
    super.key,
    required this.days,
    this.from,
    this.to,
    this.scale = const HeatmapGradientScale(
      colors: [Color(0xFFE03131), Color(0x22FFFFFF), Color(0xFF2F9E44)],
    ),
    this.min,
    this.max,
    this.symmetricRange = true,
    this.firstWeekday = DateTime.monday,
    this.monthsPerRow,
    this.cellSpacing = 2,
    this.cellRadius = 2,
    this.headerHeight = 16,
    this.monthSpacing = 12,
    this.minPanelWidth = 130,
    this.showDayNumbers = false,
    this.showWeekdayHeader = false,
    this.monthNames = defaultCalendarMonthNames,
    this.weekdayNames = defaultCalendarWeekdayNames,
    this.monthLabelBuilder,
    this.valueFormatter,
    this.headerStyle,
    this.dayNumberStyle,
    this.hoverBorder = const BorderSide(color: Color(0xCCFFFFFF), width: 1.5),
    this.onTouch,
    this.tooltipBuilder,
    this.tooltipMargin = 10,
    this.animationDuration = Duration.zero,
    this.animationCurve = Curves.easeOutCubic,
    this.animateOnMount = true,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.defaultHeight = 320,
    this.semanticLabel,
  });

  /// The days that carry a value. Days left out are drawn empty.
  final List<CalendarDay> days;

  /// The first month to draw; null starts at the earliest day given.
  final DateTime? from;

  /// The last month to draw; null ends at the latest day given.
  final DateTime? to;

  /// Turns a day's value into the colour of its square.
  final HeatmapScale scale;

  /// The value the scale starts from; null reads it off the days.
  final double? min;

  /// The value it reaches; null reads it off the days.
  final double? max;

  /// Whether an automatic range is made symmetric about zero, so that a
  /// diverging scale puts its middle colour on a flat day. Ignored when [min]
  /// and [max] are both given.
  final bool symmetricRange;

  /// The day a week begins on: [DateTime.monday] by default.
  final int firstWeekday;

  /// How many month panels sit in a row; null fits as many as it can.
  final int? monthsPerRow;

  /// The gap left between two day squares.
  final double cellSpacing;

  /// How rounded a day square is.
  final double cellRadius;

  /// How much room a month's name takes above its panel.
  final double headerHeight;

  /// The gap left between two month panels.
  final double monthSpacing;

  /// The narrowest a month panel is allowed to be when fitting them to a row.
  final double minPanelWidth;

  /// Whether the day of the month is written in each square.
  final bool showDayNumbers;

  /// Whether the weekday initials are written under each month's name.
  final bool showWeekdayHeader;

  /// The names months are written by, January first.
  final List<String> monthNames;

  /// The names weekdays are written by, Monday first.
  final List<String> weekdayNames;

  /// Writes a month's header; null writes its name, its year when the
  /// calendar spans more than one, and its total.
  final String? Function(CalendarMonthPanel month)? monthLabelBuilder;

  /// Writes a value in the default header; null writes at most two decimals
  /// with a sign.
  final String Function(double value)? valueFormatter;

  /// Style of a month's header.
  final TextStyle? headerStyle;

  /// Style of a day number.
  final TextStyle? dayNumberStyle;

  /// Drawn round the day under the pointer; null marks none.
  final BorderSide? hoverBorder;

  /// Called as a touch moves over the days, and with null when it leaves.
  final ValueChanged<CalendarTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched day; null shows none.
  final Widget? Function(BuildContext context, CalendarTouchDetails details)?
      tooltipBuilder;

  /// How far the card sits from the day.
  final double tooltipMargin;

  /// How long the squares take to fade in; zero draws them at once.
  final Duration animationDuration;

  /// The easing of [animationDuration].
  final Curve animationCurve;

  /// Whether the first build fades in.
  final bool animateOnMount;

  /// Space kept clear around the chart.
  final EdgeInsets padding;

  /// Painted behind the whole chart.
  final Color? backgroundColor;

  /// The height taken in a box that sets none.
  final double defaultHeight;

  /// What a screen reader announces for the chart.
  final String? semanticLabel;

  @override
  State<CalendarChart> createState() => _CalendarChartState();
}

class _CalendarChartState extends State<CalendarChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 128);
  CalendarLayout _layout = CalendarLayout.empty;
  DateTime? _touched;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
      value: 1,
    )..addListener(() => setState(() {}));
    if (widget.animateOnMount && widget.animationDuration > Duration.zero) {
      _animation.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(CalendarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
    if (!identical(oldWidget.days, widget.days)) {
      _touched = null;
      if (widget.animationDuration > Duration.zero) {
        _animation.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  void _handle(Offset local) {
    final cell = calendarCellAt(_layout, local);
    if (cell?.date == _touched) return;
    setState(() => _touched = cell?.date);
    widget.onTouch?.call(
      cell == null
          ? null
          : CalendarTouchDetails(
              cell: cell,
              month: _layout.months[cell.month],
            ),
    );
  }

  void _leave() {
    if (_touched == null) return;
    setState(() => _touched = null);
    widget.onTouch?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.animationCurve.transform(_animation.value);
    final range = calendarValueRange(widget.days);
    var min = widget.min ?? range.$1;
    var max = widget.max ?? range.$2;
    if (widget.symmetricRange && (widget.min == null || widget.max == null)) {
      final reach = math.max(min.abs(), max.abs());
      min = widget.min ?? -reach;
      max = widget.max ?? reach;
    }

    Widget chart = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.maybeSizeOf(context)?.width ?? 300;
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : widget.defaultHeight;
        final size = Size(width, height);
        _layout = layOutCalendar(
          widget.days,
          widget.padding.deflateRect(Offset.zero & size),
          from: widget.from,
          to: widget.to,
          firstWeekday: widget.firstWeekday,
          monthsPerRow: widget.monthsPerRow,
          cellSpacing: widget.cellSpacing,
          // A weekday row is written under the month's title, so the header
          // needs the room for both rather than stacking them on each other.
          headerHeight: widget.headerHeight +
              (widget.showWeekdayHeader ? calendarWeekdayRowHeight : 0),
          monthSpacing: widget.monthSpacing,
          minPanelWidth: widget.minPanelWidth,
        );

        final touched = _touched;
        final cell = touched == null
            ? null
            : _layout.cells.where((c) => c.date == touched).firstOrNull;
        final details = cell == null
            ? null
            : CalendarTouchDetails(
                cell: cell,
                month: _layout.months[cell.month],
              );
        final builder = widget.tooltipBuilder;
        final tooltip = details == null || builder == null
            ? null
            : builder(context, details);

        return SizedBox(
          width: width,
          height: height,
          child: MouseRegion(
            onHover: (e) => _handle(e.localPosition),
            onExit: (_) => _leave(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _handle(d.localPosition),
              onTapUp: (_) => _leave(),
              onTapCancel: _leave,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: CalendarChartPainter(
                        chart: widget,
                        layout: _layout,
                        min: min,
                        max: max,
                        touched: cell?.date,
                        animation: t,
                        textCache: _text,
                      ),
                    ),
                  ),
                  if (tooltip != null && cell != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomSingleChildLayout(
                          delegate: _CalendarTooltipLayout(
                            anchor: cell.rect,
                            margin: widget.tooltipMargin,
                          ),
                          child: tooltip,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );

    final label = widget.semanticLabel;
    if (label != null) {
      chart = Semantics(container: true, label: label, child: chart);
    }
    return chart;
  }
}

/// Puts the tooltip above the touched day, or below it when there is no room,
/// kept inside the chart.
class _CalendarTooltipLayout extends SingleChildLayoutDelegate {
  _CalendarTooltipLayout({required this.anchor, required this.margin});

  final Rect anchor;
  final double margin;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest);

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var top = anchor.top - margin - childSize.height;
    if (top < 0) top = anchor.bottom + margin;
    return Offset(
      (anchor.center.dx - childSize.width / 2).clamp(
        0.0,
        math.max(0.0, size.width - childSize.width),
      ),
      top.clamp(0.0, math.max(0.0, size.height - childSize.height)),
    );
  }

  @override
  bool shouldRelayout(_CalendarTooltipLayout oldDelegate) =>
      oldDelegate.anchor != anchor || oldDelegate.margin != margin;
}

/// Paints a [CalendarChart]: the month headers and the day squares.
class CalendarChartPainter extends CustomPainter {
  /// Creates the painter for [chart], laid out as [layout].
  CalendarChartPainter({
    required this.chart,
    required this.layout,
    required this.min,
    required this.max,
    required this.touched,
    required this.animation,
    required this.textCache,
  });

  final CalendarChart chart;
  final CalendarLayout layout;
  final double min;
  final double max;
  final DateTime? touched;
  final double animation;
  final TextPainterCache textCache;

  @override
  void paint(Canvas canvas, Size size) {
    final background = chart.backgroundColor;
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
    }
    if (layout.isEmpty) return;

    final t = animation.clamp(0.0, 1.0);
    final radius = Radius.circular(math.max(0, chart.cellRadius));
    final fill = Paint()..isAntiAlias = true;

    for (final cell in layout.cells) {
      final value = cell.value;
      final color = cell.day?.color ??
          (value == null || !value.isFinite
              ? chart.scale.emptyColor
              : chart.scale.colorAt(value, min, max));
      fill.color = t >= 1 ? color : color.withValues(alpha: color.a * t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(cell.rect, radius),
        fill,
      );
      if (chart.showDayNumbers) _paintDayNumber(canvas, cell, color);
    }

    for (final month in layout.months) {
      _paintHeader(canvas, month);
    }

    final hover = chart.hoverBorder;
    final at = touched;
    if (at != null &&
        hover != null &&
        hover.style != BorderStyle.none &&
        hover.width > 0) {
      for (final cell in layout.cells) {
        if (cell.date != at) continue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(cell.rect.inflate(hover.width / 2), radius),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = hover.width
            ..color = hover.color
            ..isAntiAlias = true,
        );
      }
    }
  }

  void _paintDayNumber(Canvas canvas, CalendarCell cell, Color color) {
    if (layout.cellSize < 14) return;
    final style = chart.dayNumberStyle ??
        TextStyle(
          fontSize: math.min(10, layout.cellSize / 2),
          color: color.computeLuminance() > 0.5
              ? const Color(0x99000000)
              : const Color(0x99FFFFFF),
        );
    final tp = textCache.get('${cell.date.day}', style);
    if (tp.width > cell.rect.width - 2) return;
    tp.paint(
      canvas,
      cell.rect.center - Offset(tp.width / 2, tp.height / 2),
    );
  }

  void _paintHeader(Canvas canvas, CalendarMonthPanel month) {
    final text = _headerOf(month);
    if (text != null && text.isNotEmpty) {
      final style = seriesAxisLabelStyle
          .copyWith(fontSize: 11, fontWeight: FontWeight.w600)
          .merge(chart.headerStyle);
      final tp = textCache.get(text, style);
      if (tp.width <= month.headerRect.width) {
        tp.paint(
          canvas,
          Offset(
            month.headerRect.left,
            // Against the top when a weekday row shares the header, centred
            // in it when the title has the header to itself.
            chart.showWeekdayHeader
                ? month.headerRect.top
                : month.headerRect.center.dy - tp.height / 2,
          ),
        );
      }
    }
    if (!chart.showWeekdayHeader || chart.weekdayNames.length < 7) return;

    final style = seriesAxisLabelStyle.copyWith(fontSize: 9);
    final step = layout.cellSize + chart.cellSpacing;
    for (var i = 0; i < 7; i++) {
      // Monday first in [weekdayNames], whatever day the week starts on.
      final name = chart.weekdayNames[(chart.firstWeekday - 1 + i) % 7];
      final tp = textCache.get(name, style);
      tp.paint(
        canvas,
        Offset(
          month.rect.left + i * step + (layout.cellSize - tp.width) / 2,
          month.headerRect.bottom - tp.height,
        ),
      );
    }
  }

  String? _headerOf(CalendarMonthPanel month) {
    final builder = chart.monthLabelBuilder;
    if (builder != null) return builder(month);
    final names = chart.monthNames;
    final name = names.length >= 12
        ? names[month.firstDay.month - 1]
        : '${month.firstDay.month}';
    final spansYears = layout.months.isNotEmpty &&
        layout.months.first.firstDay.year != layout.months.last.firstDay.year;
    final head = spansYears ? '$name ${month.firstDay.year}' : name;
    if (month.days == 0) return head;
    return '$head  ${_format(month.total)}';
  }

  String _format(double value) {
    final format = chart.valueFormatter;
    if (format != null) return format(value);
    final rounded = double.parse(value.toStringAsFixed(2));
    final text = rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toString();
    return rounded > 0 ? '+$text' : text;
  }

  @override
  bool shouldRepaint(CalendarChartPainter oldDelegate) =>
      !identical(oldDelegate.chart, chart) ||
      !identical(oldDelegate.layout, layout) ||
      oldDelegate.min != min ||
      oldDelegate.max != max ||
      oldDelegate.touched != touched ||
      oldDelegate.animation != animation;
}
