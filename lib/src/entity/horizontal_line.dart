import 'dart:ui';

import 'line.dart';

/// A horizontal line pinned to a [price].
///
/// Spans the full chart width, or — when [startTime] is set — runs right from
/// that instant as a horizontal ray. Useful for support and resistance levels,
/// or for marking an order price.
///
/// Set [alert] and the chart reports through `KChartWidget.onAlertCrossed`,
/// and through `onDrawingAlert`, whenever the newest candle crosses the level.
class HorizontalLine extends ChartLine
    implements LabelledDrawing, AlertingDrawing {
  /// Creates a horizontal line at [price].
  HorizontalLine({
    required this.price,
    this.startTime,
    this.title,
    this.alert = false,
    super.color = const Color(0xFFFFFF00),
    super.thickness = 2.0,
    super.locked = false,
    super.style,
    super.isDashed = false,
    super.showLabel = false,
    super.hidden = false,
  });

  /// Rebuilds a horizontal line from [json].
  factory HorizontalLine.fromJson(Map<String, dynamic> json) => HorizontalLine(
    price: LineJson.number(json, 'price'),
    startTime: LineJson.time(json, 'startTime'),
    title: LineJson.text(json, 'title'),
    alert: LineJson.flag(json, 'alert'),
    color: LineJson.color(json),
    thickness: LineJson.number(json, 'thickness', 2),
    style: LineJson.style(json),
    locked: LineJson.flag(json, 'locked'),
    showLabel: LineJson.flag(json, 'showLabel'),
    hidden: LineJson.flag(json, 'hidden'),
  );

  /// The price level the line sits at, in quote currency.
  double price;

  /// Where the line starts, or null for one spanning the whole chart.
  ///
  /// When set, the line is a ray: it begins at this candle and runs right to
  /// the edge of the chart, so a level only applies from the moment it was
  /// drawn onwards.
  DateTime? startTime;

  /// Whether the line only covers the chart from [startTime] rightwards.
  bool get isRay => startTime != null;

  /// Optional label painted next to the line when `showLabel` is true.
  String? title;

  /// Whether crossing this level fires `KChartWidget.onAlertCrossed`.
  @override
  bool alert;

  @override
  List<double> alertLevelsAt(DateTime time) {
    // A ray does not exist before the candle it starts at, so it cannot be
    // crossed there either.
    final start = startTime;
    if (start != null && time.isBefore(start)) return const [];
    return [price];
  }

  @override
  String? get labelText => title;

  @override
  set labelText(String? value) => title = value;

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson('horizontal'),
    'price': price,
    if (startTime != null) 'startTime': startTime!.toIso8601String(),
    if (title != null) 'title': title,
    'alert': alert,
  };
}
