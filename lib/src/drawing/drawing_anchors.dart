import '../entity/callout_drawing.dart';
import '../entity/freehand_drawing.dart';
import '../entity/horizontal_line.dart';
import '../entity/line.dart';
import '../entity/multi_point_drawing.dart';
import '../entity/text_annotation.dart';
import '../entity/two_point_drawing.dart';
import '../entity/vertical_lines.dart';

/// One of a drawing's anchors, read out for editing.
///
/// `name` is what to call it in a form — `Start`, `End`, `X`, `Point 3`.
/// `time` is null for an anchor with no time of its own, and `price` is null
/// for one with no price: a horizontal level has a price and no time, a
/// vertical line the other way about.
typedef DrawingAnchor = ({String name, DateTime? time, double? price});

/// Every anchor of [line], in the order it was placed.
///
/// This is what a settings dialog reads to show a drawing's exact coordinates,
/// and [setDrawingAnchor] writes them back. A drawing with anchors still being
/// placed reports only the ones that have landed.
List<DrawingAnchor> drawingAnchors(ChartLine line) {
  switch (line) {
    case HorizontalLine():
      return [
        (
          name: line.isRay ? 'Level and start' : 'Level',
          time: line.startTime,
          price: line.price,
        ),
      ];

    case VerticalLine():
      return [(name: 'Candle', time: line.time, price: null)];

    case TextAnnotation():
      return [(name: 'Point', time: line.time, price: line.price)];

    case FlagDrawing():
      return [(name: 'Point', time: line.time, price: line.price)];

    case MultiPointDrawing():
      final names = line is XabcdDrawing ? XabcdDrawing.pointNames : const [];
      return [
        for (final (index, point) in line.points.indexed)
          (
            name: index < names.length ? names[index] : 'Point ${index + 1}',
            time: point.time,
            price: point.price,
          ),
      ];

    case FreehandDrawing():
      // A stroke is hundreds of points laid down by hand; there is nothing
      // useful to type into. Its ends say where it runs, and are read-only.
      if (line.points.isEmpty) return const [];
      return [
        (
          name: 'Start',
          time: line.points.first.time,
          price: line.points.first.price,
        ),
        (
          name: 'End',
          time: line.points.last.time,
          price: line.points.last.price,
        ),
      ];

    case TwoPointDrawing():
      return [
        (name: 'Start', time: line.time1, price: line.price1),
        if (line.hasSecondPoint)
          (name: 'End', time: line.time2, price: line.price2),
        if (line case ThreePointDrawing(:final time3?, :final price3?))
          (name: 'Third', time: time3, price: price3),
      ];

    default:
      return const [];
  }
}

/// Whether the anchors of [line] can be typed into rather than only read.
///
/// A freehand stroke is the one drawing that cannot: its shape is the hundreds
/// of points it was drawn with, and moving two of them would not mean anything.
bool drawingAnchorsAreEditable(ChartLine line) => line is! FreehandDrawing;

/// Moves the anchor of [line] at [index] to [time] and [price].
///
/// Either may be left null to leave that part of the anchor alone. Returns
/// whether anything moved: an index that is not one of the drawing's anchors,
/// or a drawing whose anchors cannot be typed into, changes nothing.
bool setDrawingAnchor(
  ChartLine line,
  int index, {
  DateTime? time,
  double? price,
}) {
  if (!drawingAnchorsAreEditable(line)) return false;
  if (index < 0 || index >= drawingAnchors(line).length) return false;

  switch (line) {
    case HorizontalLine():
      if (price != null) line.price = price;
      // Only a ray has a start to move; a plain level spans the chart.
      if (time != null && line.isRay) line.startTime = time;
      return true;

    case VerticalLine():
      if (time != null) line.time = time;
      return true;

    case TextAnnotation():
      if (time != null) line.time = time;
      if (price != null) line.price = price;
      return true;

    case FlagDrawing():
      if (time != null) line.time = time;
      if (price != null) line.price = price;
      return true;

    case MultiPointDrawing():
      final point = line.points[index];
      line.points[index] = (
        time: time ?? point.time,
        price: price ?? point.price,
      );
      return true;

    case ThreePointDrawing() when index == 2:
      if (time != null) line.time3 = time;
      if (price != null) line.price3 = price;
      return true;

    case TwoPointDrawing():
      if (index == 0) {
        if (time != null) line.time1 = time;
        if (price != null) line.price1 = price;
      } else {
        if (time != null) line.time2 = time;
        if (price != null) line.price2 = price;
      }
      return true;

    default:
      return false;
  }
}
