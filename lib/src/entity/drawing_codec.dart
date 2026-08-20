import 'ellipse_drawing.dart';
import 'fib_retracement.dart';
import 'freehand_drawing.dart';
import 'horizontal_line.dart';
import 'line.dart';
import 'measure_drawing.dart';
import 'parallel_channel.dart';
import 'position_drawing.dart';
import 'rectangle_drawing.dart';
import 'text_annotation.dart';
import 'trend_line.dart';
import 'triangle_drawing.dart';
import 'vertical_lines.dart';

/// Rebuilds one drawing from the map [ChartLine.toJson] produced.
///
/// Returns null for a map with no `type`, or a `type` this version does not
/// know: a layout saved by a newer release still loads, minus the drawings that
/// have no meaning here.
ChartLine? drawingFromJson(Map<String, dynamic> json) {
  return switch (json['type']) {
    'horizontal' => HorizontalLine.fromJson(json),
    'vertical' => VerticalLine.fromJson(json),
    'trend' => TrendLine.fromJson(json),
    'rectangle' => RectangleDrawing.fromJson(json),
    'fibRetracement' => FibRetracement.fromJson(json),
    'measure' => MeasureDrawing.fromJson(json),
    'ellipse' => EllipseDrawing.fromJson(json),
    'triangle' => TriangleDrawing.fromJson(json),
    'channel' => ParallelChannel.fromJson(json),
    'position' => PositionDrawing.fromJson(json),
    'text' => TextAnnotation.fromJson(json),
    'freehand' => FreehandDrawing.fromJson(json),
    _ => null,
  };
}

/// A deep copy of [line], made by round-tripping it through its own JSON.
///
/// This is how the undo history keeps a snapshot that later edits cannot reach
/// back and change.
T copyDrawing<T extends ChartLine>(T line) =>
    drawingFromJson(line.toJson()) as T;

/// Every drawing on a chart, in the order they were placed.
///
/// Hand the whole set to the chart through `KChartWidget.drawings`, or let a
/// `ChartDrawingController` own it. [toJson] and [ChartDrawings.fromJson] are
/// the pair to persist with:
///
/// ```dart
/// await prefs.setString('layout', jsonEncode(drawings.toJson()));
///
/// final saved = prefs.getString('layout');
/// final drawings = saved == null
///     ? ChartDrawings()
///     : ChartDrawings.fromJson(jsonDecode(saved) as Map<String, dynamic>);
/// ```
class ChartDrawings {
  /// Creates a set holding [drawings], oldest first.
  ChartDrawings([Iterable<ChartLine>? drawings]) : all = [...?drawings];

  /// Restores a set saved by [toJson].
  ///
  /// Drawings this version does not recognise are skipped rather than throwing,
  /// so a layout written by a newer release still opens.
  factory ChartDrawings.fromJson(Map<String, dynamic> json) {
    final entries = json['drawings'];
    if (entries is! List) return ChartDrawings();
    return ChartDrawings([
      for (final entry in entries)
        if (entry is Map<String, dynamic>) ?drawingFromJson(entry),
    ]);
  }

  /// The version stamped into [toJson], so a later format can be told apart.
  static const int formatVersion = 1;

  /// Every drawing, in the order they were placed.
  final List<ChartLine> all;

  /// How many drawings there are.
  int get length => all.length;

  /// Whether there is nothing drawn.
  bool get isEmpty => all.isEmpty;

  /// Whether anything is drawn.
  bool get isNotEmpty => all.isNotEmpty;

  /// Just the drawings of one kind, in order.
  List<T> ofType<T extends ChartLine>() => all.whereType<T>().toList();

  /// The horizontal lines and rays.
  List<HorizontalLine> get horizontalLines => ofType<HorizontalLine>();

  /// The vertical lines.
  List<VerticalLine> get verticalLines => ofType<VerticalLine>();

  /// The trend lines, rays, extended lines and arrows.
  List<TrendLine> get trendLines => ofType<TrendLine>();

  /// The rectangles.
  List<RectangleDrawing> get rectangles => ofType<RectangleDrawing>();

  /// The Fibonacci retracements.
  List<FibRetracement> get fibRetracements => ofType<FibRetracement>();

  /// The measurements.
  List<MeasureDrawing> get measures => ofType<MeasureDrawing>();

  /// The ellipses.
  List<EllipseDrawing> get ellipses => ofType<EllipseDrawing>();

  /// The triangles.
  List<TriangleDrawing> get triangles => ofType<TriangleDrawing>();

  /// The parallel channels.
  List<ParallelChannel> get channels => ofType<ParallelChannel>();

  /// The planned positions.
  List<PositionDrawing> get positions => ofType<PositionDrawing>();

  /// The pinned notes.
  List<TextAnnotation> get texts => ofType<TextAnnotation>();

  /// The freehand strokes.
  List<FreehandDrawing> get freehands => ofType<FreehandDrawing>();

  /// Adds [line], or moves it to the end if it is already here.
  ///
  /// The chart reports an edit through the same callback as a first placement,
  /// so this doubles as "save whatever just changed".
  void save(ChartLine line) {
    all
      ..remove(line)
      ..add(line);
  }

  /// Removes [line]; returns whether it was there.
  bool remove(ChartLine line) => all.remove(line);

  /// Removes every drawing.
  void clear() => all.clear();

  /// A deep copy, sharing nothing with this set.
  ChartDrawings copy() =>
      ChartDrawings([for (final line in all) copyDrawing(line)]);

  /// This set as a JSON-encodable map.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': formatVersion,
    'drawings': [for (final line in all) line.toJson()],
  };
}
