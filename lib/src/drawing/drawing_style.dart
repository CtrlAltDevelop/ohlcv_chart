import 'package:flutter/material.dart';

import '../entity/line.dart';

/// The colours the line editor offers by default.
///
/// A spread that stays legible on both light and dark chart backgrounds.
const List<Color> kDefaultDrawingColors = <Color>[
  Color(0xFF2962FF), // blue
  Color(0xFF00BCD4), // cyan
  Color(0xFF00C853), // green
  Color(0xFFFFD600), // yellow
  Color(0xFFFF9100), // orange
  Color(0xFFFF1744), // red
  Color(0xFFE040FB), // magenta
  Color(0xFF9E9E9E), // grey
  Color(0xFFFFFFFF), // white
  Color(0xFF11151C), // near-black
];

/// The thicknesses the line editor offers by default, in logical pixels.
const List<double> kDefaultDrawingThicknesses = <double>[
  1.0,
  1.5,
  2.0,
  3.0,
  4.0,
  6.0,
];

/// How the drawing tools look, what the editing toolbar offers, and how
/// forgiving the chart is about taps that land near a line.
///
/// Pass one to [KChartWidget.drawingStyle]. Everything has a sensible default,
/// so override only what you care about:
///
/// ```dart
/// KChartWidget(
///   candles,
///   ChartColors(),
///   isTrendLine: true,
///   watermarkAssetPath: 'assets/logo.svg',
///   timeFrame: const Duration(minutes: 15),
///   drawingStyle: const DrawingStyle(
///     colorOptions: [Colors.tealAccent, Colors.orangeAccent],
///     thicknessOptions: [1, 2, 4],
///     showOpacityControl: false,
///     toolbarAxis: Axis.vertical,
///   ),
/// );
/// ```
@immutable
class DrawingStyle {
  /// Creates a drawing style; every argument is optional.
  const DrawingStyle({
    this.colorOptions = kDefaultDrawingColors,
    this.thicknessOptions = kDefaultDrawingThicknesses,
    this.lineStyleOptions = LineStyle.values,
    this.minThickness = 0.5,
    this.maxThickness = 8.0,
    this.showColorControl = true,
    this.showOpacityControl = true,
    this.showThicknessControl = true,
    this.showLineStyleControl = true,
    this.showLabelControl = true,
    this.showLabelTextControl = true,
    this.showLockControl = true,
    this.showDeleteControl = true,
    this.showDoneControl = true,
    this.toolbarBackgroundColor,
    this.toolbarBorderColor,
    this.toolbarBorderWidth = 1.0,
    this.toolbarBorderRadius = 26.0,
    this.toolbarPadding = const EdgeInsets.symmetric(
      horizontal: 6,
      vertical: 2,
    ),
    this.toolbarShadows,
    this.toolbarInitialOffset = const Offset(16, 40),
    this.toolbarDraggable = true,
    this.toolbarAxis = Axis.horizontal,
    this.iconSize = 20.0,
    this.iconColor,
    this.accentColor = const Color(0xFF2962FF),
    this.deleteColor = const Color(0xFFFF5252),
    this.doneColor = const Color(0xFF00E676),
    this.popoverBackgroundColor,
    this.popoverBorderRadius = 14.0,
    this.swatchSize = 26.0,
    this.swatchesPerRow = 5,
    this.handleRadius = 6.0,
    this.handleBorderWidth = 2.0,
    this.handleBorderColor = const Color(0xFFFFFFFF),
    this.dashLength = 6.0,
    this.dashGap = 4.0,
    this.dotGap = 3.0,
    this.hitTestTolerance = 20.0,
    this.handleHitTestTolerance = 40.0,
    this.labelTextSize = 10.0,
    this.labelBackgroundColor,
    this.labelBackgroundAlpha = 220,
    this.labelBorderWidth = 1.4,
    this.labelCornerRadius = 5.0,
    this.labelPadding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  });

  // ── What the editor offers ────────────────────────────────────────────────

  /// Colours shown in the colour picker.
  final List<Color> colorOptions;

  /// Thickness presets shown in the thickness picker, in logical pixels.
  final List<double> thicknessOptions;

  /// Stroke styles shown in the style picker.
  final List<LineStyle> lineStyleOptions;

  /// Lower bound of the fine thickness slider.
  final double minThickness;

  /// Upper bound of the fine thickness slider.
  final double maxThickness;

  // ── Which controls appear ─────────────────────────────────────────────────

  /// Shows the colour swatches.
  final bool showColorControl;

  /// Shows the opacity slider under the colour swatches.
  final bool showOpacityControl;

  /// Shows the thickness presets and slider.
  final bool showThicknessControl;

  /// Shows the solid/dashed/dotted picker.
  final bool showLineStyleControl;

  /// Shows the button that hides and shows the line's label.
  final bool showLabelControl;

  /// Shows the field that edits the label's text.
  ///
  /// Only horizontal and vertical lines have an editable title, so the control
  /// is hidden for trend lines regardless.
  final bool showLabelTextControl;

  /// Shows the lock button, which freezes a line in place.
  final bool showLockControl;

  /// Shows the delete button.
  final bool showDeleteControl;

  /// Shows the button that deselects the line and dismisses the toolbar.
  final bool showDoneControl;

  // ── Toolbar appearance ───────────────────────────────────────────────────

  /// Toolbar fill. Defaults to the chart background.
  final Color? toolbarBackgroundColor;

  /// Toolbar outline. Defaults to a faint tint of [iconColor].
  final Color? toolbarBorderColor;

  /// Width of the toolbar outline; 0 removes it.
  final double toolbarBorderWidth;

  /// Corner radius of the toolbar.
  final double toolbarBorderRadius;

  /// Space between the toolbar's outline and its buttons.
  final EdgeInsets toolbarPadding;

  /// Shadow cast by the toolbar. Defaults to one soft drop shadow.
  final List<BoxShadow>? toolbarShadows;

  /// Where the toolbar first appears, relative to the chart's top left.
  final Offset toolbarInitialOffset;

  /// Whether the grip can be dragged to move the toolbar.
  final bool toolbarDraggable;

  /// Lays the buttons out in a row or a column.
  final Axis toolbarAxis;

  /// Size of the toolbar's icons.
  final double iconSize;

  /// Icon colour. Defaults to the chart's default text colour.
  final Color? iconColor;

  /// Highlight used for the active value in every picker.
  final Color accentColor;

  /// Colour of the delete button.
  final Color deleteColor;

  /// Colour of the done button.
  final Color doneColor;

  /// Popover fill. Defaults to [toolbarBackgroundColor].
  final Color? popoverBackgroundColor;

  /// Corner radius of the popovers.
  final double popoverBorderRadius;

  /// Side length of one colour swatch.
  final double swatchSize;

  /// How many swatches per row in the colour popover.
  final int swatchesPerRow;

  // ── Painted geometry ─────────────────────────────────────────────────────

  /// Radius of the round drag handles on a selected line.
  final double handleRadius;

  /// Width of the ring around a drag handle; 0 removes it.
  final double handleBorderWidth;

  /// Colour of the ring around a drag handle.
  final Color handleBorderColor;

  /// Length of one dash in a [LineStyle.dashed] stroke.
  final double dashLength;

  /// Gap between dashes in a [LineStyle.dashed] stroke.
  final double dashGap;

  /// Gap between dots in a [LineStyle.dotted] stroke.
  final double dotGap;

  /// How far from a line a tap may land and still select it, in pixels.
  final double hitTestTolerance;

  /// How far from a drag handle a tap may land and still grab it, in pixels.
  final double handleHitTestTolerance;

  // ── Painted labels ───────────────────────────────────────────────────────

  /// Font size of a line's label.
  final double labelTextSize;

  /// Label fill. Defaults to the chart's default text colour.
  final Color? labelBackgroundColor;

  /// Alpha applied to the label fill, 0 to 255.
  final int labelBackgroundAlpha;

  /// Width of the label's outline, which takes the line's colour.
  final double labelBorderWidth;

  /// Corner radius of the label.
  final double labelCornerRadius;

  /// Space between a label's outline and its text.
  final EdgeInsets labelPadding;

  /// The thickness slider's bounds, widened to hold every preset.
  ///
  /// Keeps a slider whose range was left at the default from clipping a
  /// custom preset list.
  (double, double) get thicknessRange {
    var min = minThickness;
    var max = maxThickness;
    for (final t in thicknessOptions) {
      if (t < min) min = t;
      if (t > max) max = t;
    }
    return (min, max < min ? min : max);
  }

  /// Returns a copy with the given fields replaced.
  DrawingStyle copyWith({
    List<Color>? colorOptions,
    List<double>? thicknessOptions,
    List<LineStyle>? lineStyleOptions,
    double? minThickness,
    double? maxThickness,
    bool? showColorControl,
    bool? showOpacityControl,
    bool? showThicknessControl,
    bool? showLineStyleControl,
    bool? showLabelControl,
    bool? showLabelTextControl,
    bool? showLockControl,
    bool? showDeleteControl,
    bool? showDoneControl,
    Color? toolbarBackgroundColor,
    Color? toolbarBorderColor,
    double? toolbarBorderWidth,
    double? toolbarBorderRadius,
    EdgeInsets? toolbarPadding,
    List<BoxShadow>? toolbarShadows,
    Offset? toolbarInitialOffset,
    bool? toolbarDraggable,
    Axis? toolbarAxis,
    double? iconSize,
    Color? iconColor,
    Color? accentColor,
    Color? deleteColor,
    Color? doneColor,
    Color? popoverBackgroundColor,
    double? popoverBorderRadius,
    double? swatchSize,
    int? swatchesPerRow,
    double? handleRadius,
    double? handleBorderWidth,
    Color? handleBorderColor,
    double? dashLength,
    double? dashGap,
    double? dotGap,
    double? hitTestTolerance,
    double? handleHitTestTolerance,
    double? labelTextSize,
    Color? labelBackgroundColor,
    int? labelBackgroundAlpha,
    double? labelBorderWidth,
    double? labelCornerRadius,
    EdgeInsets? labelPadding,
  }) {
    return DrawingStyle(
      colorOptions: colorOptions ?? this.colorOptions,
      thicknessOptions: thicknessOptions ?? this.thicknessOptions,
      lineStyleOptions: lineStyleOptions ?? this.lineStyleOptions,
      minThickness: minThickness ?? this.minThickness,
      maxThickness: maxThickness ?? this.maxThickness,
      showColorControl: showColorControl ?? this.showColorControl,
      showOpacityControl: showOpacityControl ?? this.showOpacityControl,
      showThicknessControl: showThicknessControl ?? this.showThicknessControl,
      showLineStyleControl: showLineStyleControl ?? this.showLineStyleControl,
      showLabelControl: showLabelControl ?? this.showLabelControl,
      showLabelTextControl: showLabelTextControl ?? this.showLabelTextControl,
      showLockControl: showLockControl ?? this.showLockControl,
      showDeleteControl: showDeleteControl ?? this.showDeleteControl,
      showDoneControl: showDoneControl ?? this.showDoneControl,
      toolbarBackgroundColor:
          toolbarBackgroundColor ?? this.toolbarBackgroundColor,
      toolbarBorderColor: toolbarBorderColor ?? this.toolbarBorderColor,
      toolbarBorderWidth: toolbarBorderWidth ?? this.toolbarBorderWidth,
      toolbarBorderRadius: toolbarBorderRadius ?? this.toolbarBorderRadius,
      toolbarPadding: toolbarPadding ?? this.toolbarPadding,
      toolbarShadows: toolbarShadows ?? this.toolbarShadows,
      toolbarInitialOffset: toolbarInitialOffset ?? this.toolbarInitialOffset,
      toolbarDraggable: toolbarDraggable ?? this.toolbarDraggable,
      toolbarAxis: toolbarAxis ?? this.toolbarAxis,
      iconSize: iconSize ?? this.iconSize,
      iconColor: iconColor ?? this.iconColor,
      accentColor: accentColor ?? this.accentColor,
      deleteColor: deleteColor ?? this.deleteColor,
      doneColor: doneColor ?? this.doneColor,
      popoverBackgroundColor:
          popoverBackgroundColor ?? this.popoverBackgroundColor,
      popoverBorderRadius: popoverBorderRadius ?? this.popoverBorderRadius,
      swatchSize: swatchSize ?? this.swatchSize,
      swatchesPerRow: swatchesPerRow ?? this.swatchesPerRow,
      handleRadius: handleRadius ?? this.handleRadius,
      handleBorderWidth: handleBorderWidth ?? this.handleBorderWidth,
      handleBorderColor: handleBorderColor ?? this.handleBorderColor,
      dashLength: dashLength ?? this.dashLength,
      dashGap: dashGap ?? this.dashGap,
      dotGap: dotGap ?? this.dotGap,
      hitTestTolerance: hitTestTolerance ?? this.hitTestTolerance,
      handleHitTestTolerance:
          handleHitTestTolerance ?? this.handleHitTestTolerance,
      labelTextSize: labelTextSize ?? this.labelTextSize,
      labelBackgroundColor: labelBackgroundColor ?? this.labelBackgroundColor,
      labelBackgroundAlpha: labelBackgroundAlpha ?? this.labelBackgroundAlpha,
      labelBorderWidth: labelBorderWidth ?? this.labelBorderWidth,
      labelCornerRadius: labelCornerRadius ?? this.labelCornerRadius,
      labelPadding: labelPadding ?? this.labelPadding,
    );
  }
}
