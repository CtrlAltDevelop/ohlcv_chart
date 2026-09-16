import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'line.dart';

/// One anchor of a multi-point drawing: a candle and a price.
typedef DrawingPoint = ({DateTime time, double price});

/// A drawing anchored to a list of points rather than to two or three fields.
///
/// [TwoPointDrawing] and its three-point cousin cover the shapes with a fixed,
/// small number of anchors. This covers the rest: a harmonic pattern wants
/// five, a path wants as many as the user keeps tapping. Placement works the
/// same way either side — a tap lands a point and the last one follows the
/// pointer — but the anchors live in [points], and [pointCount] says how many
/// the shape is waiting for.
abstract class MultiPointDrawing extends ChartLine {
  /// Creates a drawing over [points], in the order they were placed.
  MultiPointDrawing({
    List<DrawingPoint>? points,
    super.color,
    super.thickness,
    super.style,
    super.isDashed,
    super.locked,
    super.showLabel,
    super.hidden,
  }) : points = points ?? <DrawingPoint>[];

  /// The anchors, in the order they were placed.
  List<DrawingPoint> points;

  /// How many anchors the finished shape has, or null when it takes as many as
  /// it is given.
  ///
  /// A harmonic pattern answers five; a path answers null and is finished by
  /// the user rather than by counting.
  int? get pointCount;

  /// The fewest anchors worth drawing, for a shape with no fixed count.
  int get minimumPoints => 2;

  /// Whether every anchor the shape needs has landed.
  bool get isComplete {
    final needed = pointCount;
    return needed == null
        ? points.length >= minimumPoints
        : points.length >= needed;
  }

  /// Whether one more tap can still be taken.
  ///
  /// A shape with a fixed count stops accepting points once it has them all; a
  /// path never does.
  bool get acceptsMorePoints =>
      pointCount == null || points.length < pointCount!;

  /// Moves the last anchor to [point], which is how one rubber-bands.
  void moveLastTo(DrawingPoint point) {
    if (points.isEmpty) {
      points.add(point);
      return;
    }
    points[points.length - 1] = point;
  }

  /// Lands another anchor at [point], if the shape will take one.
  void addPoint(DrawingPoint point) {
    if (acceptsMorePoints) points.add(point);
  }

  /// Every anchor, ready to be merged into a subclass's JSON map.
  @protected
  Map<String, dynamic> pointsJson() => <String, dynamic>{
        'points': [
          for (final point in points)
            {'time': point.time.toIso8601String(), 'price': point.price},
        ],
      };

  /// The anchors held in [json], skipping any that cannot be read.
  static List<DrawingPoint> pointsFromJson(Map<String, dynamic> json) {
    final entries = json['points'];
    if (entries is! List) return <DrawingPoint>[];
    return [
      for (final entry in entries)
        if (entry is Map<String, dynamic>)
          if (LineJson.time(entry, 'time') case final time?)
            (time: time, price: LineJson.number(entry, 'price')),
    ];
  }
}

/// A five-point harmonic pattern: X, A, B, C and D.
///
/// The legs are drawn point to point, the retracement of each leg is labelled
/// with its ratio, and the two triangles the pattern is read as — XAB and BCD —
/// are washed in. Whether the ratios make it a Gartley, a Bat or a Butterfly is
/// left to the eye; the drawing measures, it does not name.
class XabcdDrawing extends MultiPointDrawing implements FilledDrawing {
  /// Creates a pattern over [points], X first.
  XabcdDrawing({
    super.points,
    this.fillOpacity = 0.08,
    super.color = const Color(0xFFBA68C8),
    super.thickness = 1.5,
    super.style,
    super.isDashed = false,
    super.locked = false,
    super.showLabel = true,
    super.hidden = false,
  });

  /// Rebuilds a pattern from [json].
  factory XabcdDrawing.fromJson(Map<String, dynamic> json) => XabcdDrawing(
        points: MultiPointDrawing.pointsFromJson(json),
        fillOpacity: LineJson.number(json, 'fillOpacity', 0.08),
        color: LineJson.color(json, const Color(0xFFBA68C8)),
        thickness: LineJson.number(json, 'thickness', 1.5),
        style: LineJson.style(json),
        locked: LineJson.flag(json, 'locked'),
        showLabel: LineJson.flag(json, 'showLabel', true),
        hidden: LineJson.flag(json, 'hidden'),
      );

  /// What each anchor is called, in the order they are placed.
  static const List<String> pointNames = ['X', 'A', 'B', 'C', 'D'];

  /// How solid the wash inside the two triangles is.
  @override
  double fillOpacity;

  @override
  int? get pointCount => 5;

  /// The retracement of the leg ending at [index], as a fraction.
  ///
  /// `AB/XA` for B, `BC/AB` for C and `CD/BC` for D — the ratios a harmonic
  /// pattern is judged on. Null for X and A, which have no leg behind them,
  /// and for a leg of no length at all.
  double? retracementAt(int index) {
    if (index < 2 || index >= points.length) return null;
    final leg = (points[index].price - points[index - 1].price).abs();
    final previous = (points[index - 1].price - points[index - 2].price).abs();
    if (previous == 0) return null;
    return leg / previous;
  }

  @override
  Map<String, dynamic> toJson() => {
        ...baseJson('xabcd'),
        ...pointsJson(),
        'fillOpacity': fillOpacity,
      };
}

/// A run of straight segments through as many points as were tapped.
///
/// A trend line that does not have to be one line. Tap along a move and every
/// tap adds a leg; double-tap, or press the tool again, to finish. Optionally
/// closed into a polygon, or tipped with an arrowhead on the last leg.
class PathDrawing extends MultiPointDrawing implements FilledDrawing {
  /// Creates a path through [points], in order.
  PathDrawing({
    super.points,
    this.closed = false,
    this.arrow = false,
    this.fillOpacity = 0.08,
    super.color = const Color(0xFF4FC3F7),
    super.thickness = 2.0,
    super.style,
    super.isDashed = false,
    super.locked = false,
    super.showLabel = false,
    super.hidden = false,
  });

  /// Rebuilds a path from [json].
  factory PathDrawing.fromJson(Map<String, dynamic> json) => PathDrawing(
        points: MultiPointDrawing.pointsFromJson(json),
        closed: LineJson.flag(json, 'closed'),
        arrow: LineJson.flag(json, 'arrow'),
        fillOpacity: LineJson.number(json, 'fillOpacity', 0.08),
        color: LineJson.color(json, const Color(0xFF4FC3F7)),
        thickness: LineJson.number(json, 'thickness', 2),
        style: LineJson.style(json),
        locked: LineJson.flag(json, 'locked'),
        showLabel: LineJson.flag(json, 'showLabel'),
        hidden: LineJson.flag(json, 'hidden'),
      );

  /// Whether the last point joins back to the first.
  bool closed;

  /// Whether the last leg carries an arrowhead.
  bool arrow;

  /// How solid the wash inside a closed path is.
  ///
  /// An open path has no inside, so this does nothing until [closed] is set.
  @override
  double fillOpacity;

  @override
  int? get pointCount => null;

  @override
  Map<String, dynamic> toJson() => {
        ...baseJson('path'),
        ...pointsJson(),
        'closed': closed,
        'arrow': arrow,
        'fillOpacity': fillOpacity,
      };
}
