import 'callout_drawing.dart';
import 'ellipse_drawing.dart';
import 'fib_drawings.dart';
import 'fib_retracement.dart';
import 'freehand_drawing.dart';
import 'gann_drawings.dart';
import 'horizontal_line.dart';
import 'line.dart';
import 'measure_drawing.dart';
import 'multi_point_drawing.dart';
import 'parallel_channel.dart';
import 'pitchfork_drawing.dart';
import 'position_drawing.dart';
import 'range_drawings.dart';
import 'rectangle_drawing.dart';
import 'regression_channel.dart';
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
    'pitchfork' => PitchforkDrawing.fromJson(json),
    'gannFan' => GannFan.fromJson(json),
    'gannBox' => GannBox.fromJson(json),
    'fibExtension' => FibExtension.fromJson(json),
    'fibFan' => FibFan.fromJson(json),
    'fibTimeZones' => FibTimeZones.fromJson(json),
    'regression' => RegressionChannel.fromJson(json),
    'xabcd' => XabcdDrawing.fromJson(json),
    'priceRange' => PriceRangeDrawing.fromJson(json),
    'dateRange' => DateRangeDrawing.fromJson(json),
    'callout' => CalloutDrawing.fromJson(json),
    'path' => PathDrawing.fromJson(json),
    'flag' => FlagDrawing.fromJson(json),
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
        if (entry is Map<String, dynamic>)
          if (drawingFromJson(entry) case final v?) v,
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

  /// The pitchforks.
  List<PitchforkDrawing> get pitchforks => ofType<PitchforkDrawing>();

  /// The Gann fans.
  List<GannFan> get gannFans => ofType<GannFan>();

  /// The Gann boxes.
  List<GannBox> get gannBoxes => ofType<GannBox>();

  /// The trend-based Fibonacci extensions.
  List<FibExtension> get fibExtensions => ofType<FibExtension>();

  /// The Fibonacci fans.
  List<FibFan> get fibFans => ofType<FibFan>();

  /// The Fibonacci time zones.
  List<FibTimeZones> get fibTimeZones => ofType<FibTimeZones>();

  /// The regression channels.
  List<RegressionChannel> get regressions => ofType<RegressionChannel>();

  /// The harmonic patterns.
  List<XabcdDrawing> get xabcds => ofType<XabcdDrawing>();

  /// The price brackets.
  List<PriceRangeDrawing> get priceRanges => ofType<PriceRangeDrawing>();

  /// The date brackets.
  List<DateRangeDrawing> get dateRanges => ofType<DateRangeDrawing>();

  /// The callouts.
  List<CalloutDrawing> get callouts => ofType<CalloutDrawing>();

  /// The multi-segment paths.
  List<PathDrawing> get paths => ofType<PathDrawing>();

  /// The flags.
  List<FlagDrawing> get flags => ofType<FlagDrawing>();

  /// The planned positions.
  List<PositionDrawing> get positions => ofType<PositionDrawing>();

  /// The pinned notes.
  List<TextAnnotation> get texts => ofType<TextAnnotation>();

  /// The freehand strokes.
  List<FreehandDrawing> get freehands => ofType<FreehandDrawing>();

  /// Adds [line], or leaves it where it is if it is already here.
  ///
  /// The chart reports an edit through the same callback as a first placement,
  /// so this doubles as "save whatever just changed" — and an edit must not
  /// quietly change what a drawing is stacked over, which is why an existing
  /// one keeps its place rather than going to the end.
  void save(ChartLine line) {
    if (!all.contains(line)) all.add(line);
  }

  /// Removes [line]; returns whether it was there.
  bool remove(ChartLine line) => all.remove(line);

  /// Removes every drawing.
  void clear() => all.clear();

  /// Where [line] sits in the stack, or -1 when it is not here.
  ///
  /// Later is higher: the last drawing paints over the ones before it, and is
  /// the one a tap in an overlap picks up.
  int indexOf(ChartLine line) =>
      all.indexWhere((candidate) => identical(candidate, line));

  /// Moves [line] to the top of the stack; returns whether it moved.
  bool moveToFront(ChartLine line) => _moveTo(line, all.length - 1);

  /// Moves [line] to the bottom of the stack; returns whether it moved.
  bool moveToBack(ChartLine line) => _moveTo(line, 0);

  /// Moves [line] one place up the stack; returns whether it moved.
  bool moveForward(ChartLine line) {
    final from = indexOf(line);
    return from == -1 ? false : _moveTo(line, from + 1);
  }

  /// Moves [line] one place down the stack; returns whether it moved.
  bool moveBackward(ChartLine line) {
    final from = indexOf(line);
    return from == -1 ? false : _moveTo(line, from - 1);
  }

  /// Puts [line] at [to], clamped to the stack; returns whether it moved.
  bool _moveTo(ChartLine line, int to) {
    final from = indexOf(line);
    if (from == -1) return false;
    final target = to.clamp(0, all.length - 1);
    if (target == from) return false;
    all
      ..removeAt(from)
      ..insert(target, line);
    return true;
  }

  /// A deep copy, sharing nothing with this set.
  ChartDrawings copy() =>
      ChartDrawings([for (final line in all) copyDrawing(line)]);

  /// This set as a JSON-encodable map.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': formatVersion,
        'drawings': [for (final line in all) line.toJson()],
      };
}
