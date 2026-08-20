import '../entity/ellipse_drawing.dart';
import '../entity/fib_retracement.dart';
import '../entity/freehand_drawing.dart';
import '../entity/horizontal_line.dart';
import '../entity/line.dart';
import '../entity/measure_drawing.dart';
import '../entity/parallel_channel.dart';
import '../entity/position_drawing.dart';
import '../entity/rectangle_drawing.dart';
import '../entity/text_annotation.dart';
import '../entity/trend_line.dart';
import '../entity/triangle_drawing.dart';
import '../entity/vertical_lines.dart';

/// Every piece of text the line-editing toolbar shows.
///
/// Build one from your own localisations and hand it to
/// [ChartTranslations.drawing]:
///
/// ```dart
/// ChartTranslations(
///   drawing: DrawingTranslations(color: l10n.color, delete: l10n.delete),
/// );
/// ```
class DrawingTranslations {
  /// Creates a translation set, defaulting to English.
  const DrawingTranslations({
    this.color = 'Colour',
    this.opacity = 'Opacity',
    this.thickness = 'Thickness',
    this.lineStyle = 'Style',
    this.solid = 'Solid',
    this.dashed = 'Dashed',
    this.dotted = 'Dotted',
    this.label = 'Label',
    this.labelHint = 'Label text',
    this.showLabel = 'Show label',
    this.hideLabel = 'Hide label',
    this.lock = 'Lock',
    this.unlock = 'Unlock',
    this.fill = 'Fill',
    this.alert = 'Alert me here',
    this.clearAlert = 'Remove alert',
    this.delete = 'Delete',
    this.done = 'Done',
    this.move = 'Move toolbar',
    this.drawings = 'Drawings',
    this.noDrawings = 'Nothing drawn yet',
    this.undo = 'Undo',
    this.redo = 'Redo',
    this.clearAll = 'Clear all',
    this.show = 'Show',
    this.hide = 'Hide',
    this.horizontalLineName = 'Horizontal line',
    this.horizontalRayName = 'Horizontal ray',
    this.verticalLineName = 'Vertical line',
    this.trendLineName = 'Trend line',
    this.rayName = 'Ray',
    this.extendedLineName = 'Extended line',
    this.arrowName = 'Arrow',
    this.rectangleName = 'Rectangle',
    this.ellipseName = 'Ellipse',
    this.triangleName = 'Triangle',
    this.fibRetracementName = 'Fib retracement',
    this.measureName = 'Measurement',
    this.channelName = 'Parallel channel',
    this.longPositionName = 'Long position',
    this.shortPositionName = 'Short position',
    this.textName = 'Note',
    this.freehandName = 'Freehand',
    this.drawingName = 'Drawing',
  });

  /// Title of the colour popover.
  final String color;

  /// Label of the opacity slider.
  final String opacity;

  /// Title of the thickness popover.
  final String thickness;

  /// Title of the stroke-style popover.
  final String lineStyle;

  /// Name of `LineStyle.solid`.
  final String solid;

  /// Name of `LineStyle.dashed`.
  final String dashed;

  /// Name of `LineStyle.dotted`.
  final String dotted;

  /// Title of the label popover.
  final String label;

  /// Placeholder shown in the empty label field.
  final String labelHint;

  /// Tooltip of the label toggle while the label is hidden.
  final String showLabel;

  /// Tooltip of the label toggle while the label is shown.
  final String hideLabel;

  /// Tooltip of the lock button while the line is unlocked.
  final String lock;

  /// Tooltip of the lock button while the line is locked.
  final String unlock;

  /// Label of the fill slider.
  final String fill;

  /// Tooltip of the alert button while the level has no alert.
  final String alert;

  /// Tooltip of the alert button while the level has one.
  final String clearAlert;

  /// Tooltip of the delete button.
  final String delete;

  /// Tooltip of the button that dismisses the toolbar.
  final String done;

  /// Tooltip of the drag grip.
  final String move;

  /// Title of the drawing manager.
  final String drawings;

  /// Shown by the drawing manager when there is nothing to list.
  final String noDrawings;

  /// Tooltip of the undo button.
  final String undo;

  /// Tooltip of the redo button.
  final String redo;

  /// Tooltip of the button that deletes every drawing.
  final String clearAll;

  /// Tooltip of the visibility toggle while a drawing is hidden.
  final String show;

  /// Tooltip of the visibility toggle while a drawing is shown.
  final String hide;

  /// Name of a horizontal line.
  final String horizontalLineName;

  /// Name of a horizontal ray.
  final String horizontalRayName;

  /// Name of a vertical line.
  final String verticalLineName;

  /// Name of a trend line.
  final String trendLineName;

  /// Name of a ray.
  final String rayName;

  /// Name of an extended line.
  final String extendedLineName;

  /// Name of an arrow.
  final String arrowName;

  /// Name of a rectangle.
  final String rectangleName;

  /// Name of an ellipse.
  final String ellipseName;

  /// Name of a triangle.
  final String triangleName;

  /// Name of a Fibonacci retracement.
  final String fibRetracementName;

  /// Name of a measurement.
  final String measureName;

  /// Name of a parallel channel.
  final String channelName;

  /// Name of a long position.
  final String longPositionName;

  /// Name of a short position.
  final String shortPositionName;

  /// Name of a pinned note.
  final String textName;

  /// Name of a freehand stroke.
  final String freehandName;

  /// Name of a drawing of no particular kind.
  final String drawingName;

  /// What to call [line] in a list of drawings.
  String nameOf(ChartLine line) => switch (line) {
    HorizontalLine(isRay: true) => horizontalRayName,
    HorizontalLine() => horizontalLineName,
    VerticalLine() => verticalLineName,
    TrendLine(arrow: true) => arrowName,
    TrendLine(extend: LineExtension.right) => rayName,
    TrendLine(extend: LineExtension.both) => extendedLineName,
    TrendLine() => trendLineName,
    RectangleDrawing() => rectangleName,
    EllipseDrawing() => ellipseName,
    TriangleDrawing() => triangleName,
    FibRetracement() => fibRetracementName,
    MeasureDrawing() => measureName,
    ParallelChannel() => channelName,
    PositionDrawing(isLong: true) => longPositionName,
    PositionDrawing() => shortPositionName,
    TextAnnotation() => textName,
    FreehandDrawing() => freehandName,
    _ => drawingName,
  };
}
