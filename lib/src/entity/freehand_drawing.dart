import 'dart:ui';

import 'line.dart';

/// One point of a freehand stroke, anchored to a candle and a price.
typedef FreehandPoint = ({DateTime time, double price});

/// A stroke drawn by hand, point by point, as the pointer moves.
///
/// Anchored to candles like every other drawing, so it stays where it was drawn
/// when the chart is panned or zoomed. Placed by dragging rather than tapping: a
/// stroke of one point is not a stroke yet.
class FreehandDrawing extends ChartLine {
  /// Creates a stroke over [points], in the order they were drawn.
  FreehandDrawing({
    List<FreehandPoint>? points,
    super.color = const Color(0xFFFF9100),
    super.thickness = 2.0,
    super.style,
    super.isDashed = false,
    super.locked = false,
    super.showLabel = false,
    super.hidden = false,
  }) : points = points ?? <FreehandPoint>[];

  /// Rebuilds a stroke from [json].
  factory FreehandDrawing.fromJson(Map<String, dynamic> json) {
    final entries = json['points'];
    return FreehandDrawing(
      points: [
        if (entries is List)
          for (final entry in entries)
            if (entry is Map<String, dynamic>)
              if (LineJson.time(entry, 'time') case final time?)
                (time: time, price: LineJson.number(entry, 'price')),
      ],
      color: LineJson.color(json, const Color(0xFFFF9100)),
      thickness: LineJson.number(json, 'thickness', 2),
      style: LineJson.style(json),
      locked: LineJson.flag(json, 'locked'),
      showLabel: LineJson.flag(json, 'showLabel'),
      hidden: LineJson.flag(json, 'hidden'),
    );
  }

  /// The stroke's points, oldest first.
  List<FreehandPoint> points;

  /// Whether there is enough of a stroke to draw.
  bool get isComplete => points.length > 1;

  /// Adds [point] to the end of the stroke, unless it is where the stroke
  /// already is.
  ///
  /// A drag reports many events per candle, and a stroke that stored every one
  /// of them would be mostly duplicates.
  void extendTo(FreehandPoint point) {
    final last = points.isEmpty ? null : points.last;
    if (last != null && last.time == point.time && last.price == point.price) {
      return;
    }
    points.add(point);
  }

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson('freehand'),
    'points': [
      for (final point in points)
        {'time': point.time.toIso8601String(), 'price': point.price},
    ],
  };
}
