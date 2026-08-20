import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'chart_controller.dart';
import 'chart_style.dart';
import 'chart_translations.dart';
import 'chart_type.dart';
import 'components/popup_info_view.dart';
import 'drawing/drawing_controller.dart';
import 'drawing/drawing_style.dart';
import 'drawing/drawing_toolbar.dart';
import 'entity/ellipse_drawing.dart';
import 'entity/fib_retracement.dart';
import 'entity/freehand_drawing.dart';
import 'entity/horizontal_line.dart';
import 'entity/info_window_entity.dart';
import 'entity/k_line_entity.dart';
import 'entity/line.dart';
import 'entity/measure_drawing.dart';
import 'entity/parallel_channel.dart';
import 'entity/position_drawing.dart';
import 'entity/rectangle_drawing.dart';
import 'entity/signal_entity.dart';
import 'entity/text_annotation.dart';
import 'entity/trend_line.dart';
import 'entity/triangle_drawing.dart';
import 'entity/two_point_drawing.dart';
import 'entity/vertical_lines.dart';
import 'indicators/indicator.dart';
import 'indicators/resolved_indicator.dart';
import 'price_axis_scale.dart';
import 'renderer/base_chart_painter.dart';
import 'renderer/base_dimension.dart';
import 'renderer/chart_painter.dart';
import 'renderer/main_renderer.dart';
import 'utils/date_format_util.dart';

/// The drawing mode the chart is currently in.
///
/// Anything other than [none] makes the next tap place a line instead of
/// moving the crosshair. Every tool can be used either way round: tap to
/// place each point, or press and drag from the first point to the last.
enum DrawingTool {
  /// Normal chart interaction; taps select existing lines.
  none,

  /// The next tap places a [HorizontalLine] across the whole chart.
  horizontal,

  /// The next tap places a [HorizontalLine] running right from that candle.
  horizontalRay,

  /// The next tap places a [VerticalLine].
  vertical,

  /// The next two taps place the ends of a [TrendLine].
  trend,

  /// The next two taps place a [TrendLine] that carries on past its second
  /// end, to the edge of the chart.
  ray,

  /// The next two taps place a [TrendLine] that carries on past both ends.
  extendedLine,

  /// The next two taps place a [TrendLine] with an arrowhead on its far end.
  arrow,

  /// The next two taps place opposite corners of a [RectangleDrawing].
  rectangle,

  /// The next two taps place the box an [EllipseDrawing] is drawn inside.
  ellipse,

  /// The next three taps place the corners of a [TriangleDrawing].
  triangle,

  /// The next two taps place the swing a [FibRetracement] measures.
  fibRetracement,

  /// The next two taps place the span a [MeasureDrawing] reads out.
  measure,

  /// The next three taps place a [ParallelChannel]: two for its base line, one
  /// for the parallel.
  channel,

  /// The next three taps place a [PositionDrawing]: entry, target, then stop.
  position,

  /// The next tap pins a [TextAnnotation], ready to be typed into.
  text,

  /// A drag lays down a [FreehandDrawing].
  brush,
}

/// Ready-made date patterns for [KChartWidget.timeFormat].
class TimeFormat {
  /// `yyyy-MM-dd`, for daily candles and longer.
  static const List<String> YEAR_MONTH_DAY = [yyyy, '-', mm, '-', dd];

  /// `yyyy-MM-dd HH:mm`, for intraday candles.
  static const List<String> YEAR_MONTH_DAY_WITH_HOUR = [
    yyyy,
    '-',
    mm,
    '-',
    dd,
    ' ',
    HH,
    ':',
    nn,
  ];
}

/// An interactive candlestick chart.
///
/// Pass the candles positionally along with a [ChartColors]. Run
/// [DataUtil.calculate] over the list first so the indicator fields are
/// populated, otherwise the overlays and sub-charts have nothing to draw.
///
/// The chart supports pinch-to-zoom, fling scrolling, a long-press crosshair
/// with an info dialog, and — when [isTrendLine] is set and a
/// [currentDrawingTool] is selected — placing trend, horizontal and vertical
/// lines that the user can then select, drag, restyle and delete. The
/// `onAdd*` and `onRemove*` callbacks let you persist those.
///
/// ```dart
/// DataUtil.calculate(candles);
///
/// KChartWidget(
///   candles,
///   ChartColors(),
///   isTrendLine: false,
///   watermarkAssetPath: 'assets/logo.svg',
///   timeFrame: const Duration(minutes: 15),
///   indicators: [MaIndicator(period: 20), MacdIndicator()],
/// );
/// ```
class KChartWidget extends StatefulWidget {
  /// Creates a candlestick chart over [candles], coloured by [chartColors].
  const KChartWidget(
    this.candles,
    this.chartColors, {
    required this.isTrendLine,
    required this.watermarkAssetPath,
    required this.timeFrame,
    this.xFrontPadding = 80,
    this.signals = const <SignalEntity>[],
    this.verticalLines = const <VerticalLine>[],
    this.horizontalLines = const <HorizontalLine>[],
    this.trendLines = const <TrendLine>[],
    this.rectangles = const <RectangleDrawing>[],
    this.fibRetracements = const <FibRetracement>[],
    this.drawings = const <ChartLine>[],
    this.indicators = const <Indicator>[],
    this.drawingController,
    this.currentDrawingTool = DrawingTool.none,
    this.magnetMode = false,
    this.enableKeyboardShortcuts = true,
    this.crosshairOnHover = true,
    this.showOhlcLegend = false,
    this.priceAxisScale = PriceAxisScale.linear,
    this.chartType,
    this.baselinePrice,
    this.timeZoneOffset = Duration.zero,
    this.controller,
    this.showScrollToNowButton = true,
    this.resizablePanes = false,
    this.reorderablePanes = false,
    this.onReorderPane,
    this.onAddTrendLine,
    this.onAddHorizontalLine,
    this.onAddVerticalLine,
    this.onAddRectangle,
    this.onAddFibRetracement,
    this.onRemoveTrendLine,
    this.onRemoveRectangle,
    this.onRemoveFibRetracement,
    this.onRemoveHorizontalLine,
    this.onRemoveVerticalLine,
    this.onAddDrawing,
    this.onRemoveDrawing,
    this.onAlertCrossed,
    this.selectAfterDrawing = true,
    this.volHidden = false,
    this.isLine = false,
    this.isTapShowInfoDialog = false,
    this.hideGrid = false,
    this.showNowPrice = true,
    this.showInfoDialog = true,
    this.materialInfoDialog = true,
    this.chartStyle = const ChartStyle(),
    this.drawingStyle = const DrawingStyle(),
    this.chartTranslations = const ChartTranslations(),
    this.timeFormat = TimeFormat.YEAR_MONTH_DAY,
    this.infoDialogBuilder,
    this.dateFormatter,
    this.onLoadMore,
    this.fixedLength = 2,
    this.flingTime = 600,
    this.flingRatio = 0.5,
    this.flingCurve = Curves.decelerate,
    this.isOnDrag,
    this.verticalTextAlignment = VerticalTextAlignment.left,
    this.mBaseHeight,
    this.infoDialogWidth = 132,
    this.infoDialogMaxWidth = 240,
    super.key,
  });

  /// The candles to draw, oldest first. Null renders a loading indicator.
  final List<KLineEntity>? candles;

  /// Price markers painted over the candles.
  final List<SignalEntity> signals;

  /// Vertical lines to draw, typically restored from storage.
  final List<VerticalLine> verticalLines;

  /// Horizontal lines to draw, typically restored from storage.
  final List<HorizontalLine> horizontalLines;

  /// Trend lines to draw, typically restored from storage.
  final List<TrendLine> trendLines;

  /// Boxes drawn over the candles, marking a price range over a span of time.
  final List<RectangleDrawing> rectangles;

  /// Fibonacci retracements drawn over the candles.
  final List<FibRetracement> fibRetracements;

  /// Drawings of any kind, drawn alongside the per-kind lists above.
  ///
  /// The kinds that came later — measurements, ellipses, triangles, channels,
  /// positions, notes and freehand strokes — have no list of their own; put
  /// them here, or hand the whole set to a [drawingController] and let it keep
  /// them. They report through [onAddDrawing] and [onRemoveDrawing].
  final List<ChartLine> drawings;

  /// The indicators to draw, in the order they were added.
  ///
  /// Each entry is a configured instance, so the same kind may appear several
  /// times with different settings — `AtrIndicator(period: 8)` and
  /// `AtrIndicator(period: 20)` are two panes. Overlays such as
  /// [MaIndicator] draw over the candles; the rest each take a pane below.
  ///
  /// Two instances of one kind with the same settings are equal whatever
  /// colours they carry, and the chart keeps only the last of an equal pair.
  /// That is what makes re-adding an indicator in a new colour an edit rather
  /// than a duplicate; see `upsert` on the list.
  final List<Indicator> indicators;

  /// Owns the drawings, and their undo history, instead of the lists above.
  ///
  /// With a controller the chart draws what the controller holds and writes
  /// every placement, edit and deletion back to it, which is what makes undo
  /// and redo — ⌘Z and ⇧⌘Z on the chart, or
  /// [ChartDrawingController.undo] from a button of your own — work. The
  /// `onAdd*` and `onRemove*` callbacks still fire either way.
  ///
  /// Left null, the chart reads the per-kind lists and the host owns them, as
  /// it always has.
  final ChartDrawingController? drawingController;

  /// Lets the chart claim ⌘Z, ⇧⌘Z and Delete while a drawing is selected.
  ///
  /// Undo and redo need a [drawingController]; Delete and Escape work either
  /// way. A key the chart has no use for is always left for the host.
  final bool enableKeyboardShortcuts;

  /// The active drawing mode; see [DrawingTool].
  final DrawingTool currentDrawingTool;

  /// Snaps points being placed to the nearest open, high, low or close.
  ///
  /// A point only snaps when a candle's price is within
  /// [DrawingStyle.magnetSnapDistance] pixels of the pointer; further away it
  /// lands wherever the pointer is.
  final bool magnetMode;

  /// Called when the user finishes drawing or edits a trend line.
  ///
  /// Rays, extended lines and arrows are trend lines too, distinguished by
  /// [TrendLine.extend] and [TrendLine.arrow], so they arrive here as well.
  final ValueChanged<TrendLine>? onAddTrendLine;

  /// Called when the user finishes drawing or edits a rectangle.
  final ValueChanged<RectangleDrawing>? onAddRectangle;

  /// Called when the user finishes drawing or edits a retracement.
  final ValueChanged<FibRetracement>? onAddFibRetracement;

  /// Called when the user deletes a rectangle from the editing toolbar.
  final ValueChanged<RectangleDrawing>? onRemoveRectangle;

  /// Called when the user deletes a retracement from the editing toolbar.
  final ValueChanged<FibRetracement>? onRemoveFibRetracement;

  /// Called when the user places or edits a horizontal line.
  final ValueChanged<HorizontalLine>? onAddHorizontalLine;

  /// Called when the user places or edits a vertical line.
  final ValueChanged<VerticalLine>? onAddVerticalLine;

  /// Called when the user deletes a trend line.
  final ValueChanged<TrendLine>? onRemoveTrendLine;

  /// Called when the user deletes a horizontal line.
  final ValueChanged<HorizontalLine>? onRemoveHorizontalLine;

  /// Called when the user deletes a vertical line.
  final ValueChanged<VerticalLine>? onRemoveVerticalLine;

  /// Called when the user places or edits a drawing of any kind.
  ///
  /// Fires alongside the per-kind callback where there is one, and is the only
  /// report for the kinds that have none.
  final ValueChanged<ChartLine>? onAddDrawing;

  /// Called when the user deletes a drawing of any kind.
  final ValueChanged<ChartLine>? onRemoveDrawing;

  /// Called when the newest candle crosses a level with `alert` set.
  ///
  /// Fires once per crossing — the level's own side of the market has to change
  /// before it fires again — and carries the candle that did the crossing.
  final void Function(HorizontalLine line, KLineEntity candle)? onAlertCrossed;

  /// Whether a drawing the user has just finished is left selected, with the
  /// editor open on it.
  ///
  /// Turn it off to draw several of something without dismissing an editor
  /// between each one.
  final bool selectAfterDrawing;

  /// Duration of one candle, used to place lines and count down the close.
  final Duration timeFrame;

  /// Draws a filled close-price line instead of candles.
  ///
  /// A shorthand for `chartType: ChartType.area`, kept for the callers that
  /// already use it. [chartType] wins when both are given.
  final bool isLine;

  /// What the candle area draws for each candle: candles, OHLC bars, a line, an
  /// area or a baseline.
  ///
  /// Left null it follows [isLine] — `ChartType.area` when that is set,
  /// `ChartType.candles` otherwise. Heikin-Ashi and Renko are transforms of the
  /// candles rather than ways of drawing them; run the list through
  /// `CandleTransforms` and leave this on [ChartType.candles].
  final ChartType? chartType;

  /// The level a [ChartType.baseline] chart is washed towards.
  ///
  /// Left null it is the oldest close in view, so the wash reads as the move
  /// across the window on screen.
  final double? baselinePrice;

  /// Drives the chart from outside it: scrolling, zooming and capturing it as
  /// an image.
  ///
  /// See [KChartController]. Only one chart at a time may use a controller.
  final KChartController? controller;

  /// Shows a button that jumps back to the newest candle, whenever the chart is
  /// scrolled away from it.
  final bool showScrollToNowButton;

  /// Lets an indicator pane be made taller or shorter by dragging its lower
  /// edge.
  ///
  /// The heights live in the chart, between `ChartStyle.minPaneHeight` and
  /// `ChartStyle.maxPaneHeight`, and reset when the panes themselves change.
  final bool resizablePanes;

  /// Lets an indicator pane be dragged up or down the stack by its legend row.
  ///
  /// The chart does not own the order — the indicators do — so it reports where
  /// the pane was dropped through [onReorderPane] and leaves the move to you.
  final bool reorderablePanes;

  /// Called when a pane has been dragged from position `from` to position `to`.
  ///
  /// Reorder your own `indicators` to match:
  ///
  /// ```dart
  /// onReorderPane: (from, to) => setState(() {
  ///   indicators.insert(to, indicators.removeAt(from));
  /// }),
  /// ```
  final void Function(int from, int to)? onReorderPane;

  /// Shifted onto every candle's time before it is shown.
  ///
  /// Candle times are read as they come — usually UTC — and this is what puts
  /// the axis, the crosshair's date and the session dividers into the zone the
  /// trader works in. It changes what is displayed, never the data.
  final Duration timeZoneOffset;

  /// Opens the info dialog on tap as well as on long press.
  final bool isTapShowInfoDialog;

  /// Hides the background grid.
  final bool hideGrid;

  /// Draws the current price line and its countdown to the candle close.
  final bool showNowPrice;

  /// Enables the long-press info dialog.
  final bool showInfoDialog;

  /// Uses the Material info dialog rather than the Cupertino-styled one.
  final bool materialInfoDialog;

  /// Labels used by the info dialog and on-chart text.
  final ChartTranslations chartTranslations;

  /// Date pattern for axis labels; see [TimeFormat].
  final List<String> timeFormat;

  /// Height of the candle area, before the volume and indicator panes are
  /// added below it.
  ///
  /// Left null — the default — the candles take whatever height is left in the
  /// widget's box once those panes have had their share, so the whole stack
  /// fits without being clipped. In a box of unbounded height, such as inside a
  /// scroll view, it falls back to 360.
  final double? mBaseHeight;

  /// Replaces the built-in long-press info dialog.
  ///
  /// Receives the selected candle and the one before it.
  final Widget? Function(BuildContext, KLineEntity?, KLineEntity?)?
  infoDialogBuilder;

  /// Overrides axis date formatting; the flag marks the long form.
  final String Function(KLineEntity, bool)? dateFormatter;

  /// Fires when the user scrolls past an edge; the flag is true at the right.
  final ValueChanged<bool>? onLoadMore;

  /// Decimal places used for every price shown.
  final int fixedLength;

  /// Duration of the fling animation, in milliseconds.
  final int flingTime;

  /// Multiplier applied to fling velocity.
  final double flingRatio;

  /// Easing applied to the fling animation.
  final Curve flingCurve;

  /// Reports whether the user is currently dragging the chart.
  final ValueChanged<bool>? isOnDrag;

  /// Every colour the chart paints with.
  final ChartColors chartColors;

  /// Geometry: paddings, stroke widths and text sizes.
  final ChartStyle chartStyle;

  /// How the drawing tools look and what their editor offers.
  final DrawingStyle drawingStyle;

  /// Which side the price axis labels sit on.
  final VerticalTextAlignment verticalTextAlignment;

  /// Enables the drawing tools and their edit panel.
  final bool isTrendLine;

  /// Hides the volume pane.
  final bool volHidden;

  /// Follows a mouse with the crosshair, without waiting for a press.
  ///
  /// Only ever comes into play with a pointer that hovers, so a touch device is
  /// unaffected. The info dialog still waits for a long press or, with
  /// [isTapShowInfoDialog], a tap: on a desktop the values belong in the
  /// legend, which is what [showOhlcLegend] is for.
  final bool crosshairOnHover;

  /// How the candle area spaces its price axis: linearly, by ratio, or as a
  /// percentage move away from the oldest candle in view.
  ///
  /// See [PriceAxisScale]. The volume and indicator panes stay linear.
  final PriceAxisScale priceAxisScale;

  /// Reads the candle out above the chart: date, open, high, low, close, the
  /// move over it and its volume.
  ///
  /// Follows the crosshair, falling back to the newest candle, and takes one
  /// legend row of its own above the indicator legends. Its wording comes from
  /// [chartTranslations].
  final bool showOhlcLegend;

  /// Empty space kept to the right of the newest candle.
  final double xFrontPadding;

  /// Asset path of an SVG watermark; a missing asset is ignored.
  final String watermarkAssetPath;

  /// Narrowest the long-press info dialog may be.
  final double infoDialogWidth;

  /// Widest the long-press info dialog may grow before its rows ellipsise.
  ///
  /// Also capped by the chart's own width, so the dialog always fits.
  final double infoDialogMaxWidth;

  @override
  State<KChartWidget> createState() => _KChartWidgetState();
}

class _KChartWidgetState extends State<KChartWidget>
    with TickerProviderStateMixin
    implements KChartHost {
  final StreamController<InfoWindowEntity?> mInfoWindowStream =
      StreamController<InfoWindowEntity?>();

  /// The drawings the chart is painting, from the controller when there is one
  /// and from the per-kind lists otherwise.
  List<ChartLine> _drawings = const [];

  /// The drawing the editing toolbar is open on, when the chart is keeping
  /// track of that itself.
  ///
  /// With a [KChartWidget.drawingController] the selection lives there instead,
  /// so a drawing manager and the chart agree on what is selected.
  ChartLine? _localSelection;

  /// The drawing the editing toolbar is open on.
  ///
  /// The controller is the authority when there is one, so the chart and a
  /// drawing manager can never disagree about what is selected.
  ChartLine? get _selected {
    final controller = widget.drawingController;
    return controller == null ? _localSelection : controller.selected;
  }

  set _selected(ChartLine? line) {
    final controller = widget.drawingController;
    if (controller == null) {
      _localSelection = line;
      return;
    }
    controller.select(line);
  }

  /// The drawing being placed, before the user has finished it.
  ChartLine? _draft;

  bool _isDrawing = false;

  /// True once the first anchor of a two-point drawing has landed and the
  /// chart is waiting for the point that finishes it.
  ///
  /// This is what lets a line be drawn the way a charting desk expects: click
  /// once, move, click again — with a drag from the first point to the last
  /// still working as it always did.
  bool _awaitingSecondPoint = false;

  /// True while an armed tool is only trailing the mouse: the line under the
  /// cursor is a preview and nothing has been placed yet.
  bool _isPreviewing = false;

  /// True while a mouse is resting over the chart with no tool armed, which is
  /// what puts the crosshair under the cursor.
  bool _isHovering = false;

  /// Where the mouse was the last time a hover was acted on.
  ///
  /// Flutter re-sends a hover after a rebuild, so acting on one that has not
  /// moved would repaint forever.
  Offset? _lastHoverPosition;

  /// Where the pointer went down, before any gesture was recognised.
  ///
  /// A drag is only recognised once it has moved past the slop, by which time
  /// its focal point has left the spot the user actually pressed — and a pane's
  /// edge or its legend strip is only a few pixels tall.
  Offset? _pointerDown;

  double mScaleX = 1.0;
  double mScrollX = 0.0;
  double mSelectX = 0.0;
  double mSelectY = 0.0;
  double mHeight = 0;
  double mWidth = 0;
  AnimationController? _controller;
  Animation<double>? aniX;
  Timer? _countdownTimer;

  PictureInfo? _watermarkPicture;
  late Offset _toolbarOffset;

  /// The height of each indicator pane, once the user has dragged one.
  ///
  /// Empty until then, and thrown away whenever the panes change, so a new
  /// indicator never inherits a height meant for a different one.
  List<double> _paneHeights = const [];

  /// The pane whose lower edge is being dragged, if any.
  int? _resizingPane;

  /// The pane being dragged to a new place in the stack, if any, and how far it
  /// has been dragged.
  int? _reorderingPane;
  double _reorderDelta = 0;

  /// Where the pointer was, and what the drawing looked like, when a drag on a
  /// selected drawing began. Lets a two-point shape move as a whole.
  ({int index, double price})? _dragStart;
  List<({int index, double price})>? _dragOrigin;

  late ChartPainter painter;
  double _lastScale = 1.0;
  bool isScale = false;
  bool isDrag = false;
  bool isLongPress = false;
  bool isOnTap = false;
  bool isDraggingHandle = false;

  /// Which part of a two-point drawing a drag is holding: 1 or 2 for an
  /// anchor, 0 for the whole shape.
  int? draggingAnchor;

  @override
  void initState() {
    super.initState();
    _toolbarOffset = widget.drawingStyle.toolbarInitialOffset;
    _loadWatermark();
    _syncCountdownTimer();
    _resolveIndicators();
    widget.drawingController?.addListener(_onDrawingsChanged);
    widget.controller?.attach(this);
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  /// Redraws when the controller's drawings change, dropping a selection whose
  /// drawing is no longer there — which is what an undo leaves behind.
  void _onDrawingsChanged() {
    if (_selected == null) {
      // Whatever was selected has gone — deleted, undone, or replaced by a
      // freshly loaded layout — so there is nothing left to drag either.
      isDraggingHandle = false;
      draggingAnchor = null;
      _dragStart = null;
      _dragOrigin = null;
    }
    if (mounted) setState(() {});
  }

  /// Handles the keys the drawing tools answer to, wherever the focus is.
  ///
  /// Escape throws away whatever is being drawn, Delete removes the selected
  /// drawing, and ⌘Z and ⇧⌘Z — Ctrl on Windows and Linux, where Ctrl+Y also
  /// redoes — walk the controller's history. Each one is only claimed when the
  /// chart actually has something to do with it, so a key the host wanted for a
  /// dialog of its own is never swallowed.
  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (!_isDrawing && !_isPreviewing) return false;
      _cancelDrawing();
      return true;
    }

    if (!widget.enableKeyboardShortcuts || !widget.isTrendLine) return false;

    if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      final selected = _selected;
      if (selected == null || selected.locked) return false;
      _deleteSelected();
      return true;
    }

    final controller = widget.drawingController;
    if (controller == null || !_isCommandPressed) return false;

    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final shift =
        keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight);

    if (event.logicalKey == LogicalKeyboardKey.keyZ) {
      return shift ? controller.redo() : controller.undo();
    }
    if (event.logicalKey == LogicalKeyboardKey.keyY) {
      return controller.redo();
    }
    return false;
  }

  /// Whether the platform's shortcut modifier is held: ⌘ on Apple platforms,
  /// Ctrl everywhere else.
  bool get _isCommandPressed {
    final keyboard = HardwareKeyboard.instance;
    final isApple =
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return isApple ? keyboard.isMetaPressed : keyboard.isControlPressed;
  }

  /// The indicators, computed over the candles and split by where they draw.
  ResolvedIndicators _resolved = ResolvedIndicators.empty;

  /// What the last resolution was computed from, so a rebuild that changes
  /// neither the candles nor the indicators reuses it.
  ({int length, Object? last, DateTime? time})? _resolvedFrom;

  /// The indicator instances the last resolution was computed from.
  ///
  /// Compared by identity rather than equality: two indicators of one kind with
  /// the same settings are equal whatever colours they carry, and a recolour
  /// still has to be redrawn.
  List<Indicator> _resolvedIndicators = const [];

  ({int length, Object? last, DateTime? time}) get _candleFingerprint {
    final candles = widget.candles;
    final last = candles == null || candles.isEmpty ? null : candles.last;
    return (
      length: candles?.length ?? 0,
      last: last?.close,
      time: last?.dateTime,
    );
  }

  void _resolveIndicators() {
    _resolved = resolveIndicators(widget.indicators, widget.candles);
    _resolvedFrom = _candleFingerprint;
    _resolvedIndicators = List<Indicator>.of(widget.indicators);
  }

  bool get _indicatorsAreStale {
    final current = widget.indicators;
    if (current.length != _resolvedIndicators.length) return true;
    for (var i = 0; i < current.length; i++) {
      if (!identical(current[i], _resolvedIndicators[i])) return true;
    }
    return false;
  }

  /// Recomputes the indicators when the candles or the indicators have moved on.
  ///
  /// Called from `build` because both lists are usually mutated in place — a
  /// live feed appends candles, an "add indicator" button appends indicators —
  /// which `didUpdateWidget` cannot see.
  void _refreshIndicatorsIfStale() {
    if (_resolvedFrom != _candleFingerprint || _indicatorsAreStale) {
      _resolveIndicators();
    }
  }

  /// Runs the one-second repaint only while the now-price countdown is shown.
  void _syncCountdownTimer() {
    if (widget.showNowPrice) {
      _countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _countdownTimer?.cancel();
      _countdownTimer = null;
    }
  }

  Future<void> _loadWatermark() async {
    try {
      final info = await vg.loadPicture(
        SvgAssetLoader(widget.watermarkAssetPath),
        null,
      );
      if (mounted) setState(() => _watermarkPicture = info);
    } catch (_) {
      // A missing or malformed watermark asset simply leaves the chart
      // unwatermarked; it must never break the chart itself.
    }
  }

  @override
  void didUpdateWidget(covariant KChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.watermarkAssetPath != widget.watermarkAssetPath) {
      _loadWatermark();
    }
    if (oldWidget.showNowPrice != widget.showNowPrice) {
      _syncCountdownTimer();
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach(this);
      widget.controller?.attach(this);
    }
    if (oldWidget.drawingController != widget.drawingController) {
      oldWidget.drawingController?.removeListener(_onDrawingsChanged);
      widget.drawingController?.addListener(_onDrawingsChanged);
    }
    if (!identical(oldWidget.candles, widget.candles)) _resolveIndicators();
    if (oldWidget.currentDrawingTool != widget.currentDrawingTool) {
      // Picking a different tool abandons whatever the last one had started.
      // The rebuild is already under way, so no setState here.
      _resetDraft();
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    widget.drawingController?.removeListener(_onDrawingsChanged);
    widget.controller?.detach(this);
    _countdownTimer?.cancel();
    mInfoWindowStream.close();
    _controller?.dispose();
    super.dispose();
  }

  ChartLine? _getSelectedLine() => _selected;

  void _deselectAll() {
    setState(() {
      _selected = null;
      isDraggingHandle = false;
      draggingAnchor = null;
      _dragStart = null;
      _dragOrigin = null;
    });
  }

  void _deleteSelected() {
    final line = _getSelectedLine();
    if (line != null) {
      widget.drawingController?.remove(line);
      widget.onRemoveDrawing?.call(line);
    }
    if (line is HorizontalLine) widget.onRemoveHorizontalLine?.call(line);
    if (line is VerticalLine) widget.onRemoveVerticalLine?.call(line);
    if (line is TrendLine) widget.onRemoveTrendLine?.call(line);
    if (line is RectangleDrawing) widget.onRemoveRectangle?.call(line);
    if (line is FibRetracement) widget.onRemoveFibRetracement?.call(line);
    _deselectAll();
  }

  /// Reports an edited line through the matching `onAdd*` callback, which is
  /// where a host persists it.
  void _notifyLineChanged(ChartLine line) {
    widget.drawingController?.save(line);
    widget.onAddDrawing?.call(line);
    switch (line) {
      case HorizontalLine():
        widget.onAddHorizontalLine?.call(line);
      case VerticalLine():
        widget.onAddVerticalLine?.call(line);
      case TrendLine():
        widget.onAddTrendLine?.call(line);
      case RectangleDrawing():
        widget.onAddRectangle?.call(line);
      case FibRetracement():
        widget.onAddFibRetracement?.call(line);
    }
  }

  void _notifySelectedChanged() {
    final line = _getSelectedLine();
    if (line != null) _notifyLineChanged(line);
  }

  void _moveToolbar(Offset delta) {
    setState(() {
      // Always leave a grabbable corner of the bar inside the chart.
      const margin = 48.0;
      _toolbarOffset = Offset(
        (_toolbarOffset.dx + delta.dx).clamp(
          0.0,
          math.max(0.0, mWidth - margin),
        ),
        (_toolbarOffset.dy + delta.dy).clamp(
          0.0,
          math.max(0.0, mHeight - margin),
        ),
      );
    });
  }

  /// The candle area's height: what the caller asked for, or whatever the box
  /// has left once the panes below have taken their share.
  double _resolveBaseHeight(double available) {
    final asked = widget.mBaseHeight;
    if (asked != null) return asked;
    if (!available.isFinite) return _unboundedBaseHeight;

    return math.max(
      BaseChartPainter.minMainHeight,
      available -
          BaseDimension.panesHeight(
            volHidden: widget.volHidden,
            paneCount: _resolved.panes.length,
            legendRowCount: _legendRowCount,
            paneHeights: _effectivePaneHeights,
          ),
    );
  }

  /// Candle height used when the box does not constrain its height at all.
  static const double _unboundedBaseHeight = 360;

  /// What the candle area draws, taking `isLine` as `ChartType.area` for the
  /// callers that predate [KChartWidget.chartType].
  ChartType get _chartType =>
      widget.chartType ?? (widget.isLine ? ChartType.area : ChartType.candles);

  /// How many legend rows sit above the candles: one per indicator group, plus
  /// one for the OHLC legend when it is shown.
  /// The pane heights to lay out with, defaulting each pane to the standard
  /// height until it has been dragged.
  List<double> get _effectivePaneHeights {
    final count = _resolved.panes.length;
    if (_paneHeights.length != count) {
      _paneHeights = List<double>.filled(
        count,
        BaseDimension.secondaryPaneHeight,
      );
    }
    return _paneHeights;
  }

  int get _legendRowCount =>
      _resolved.legendRowCount + (widget.showOhlcLegend ? 1 : 0);

  /// Which side of each alerting level the market was last seen on, so one
  /// crossing is reported once.
  final Map<HorizontalLine, bool> _alertSides = <HorizontalLine, bool>{};

  /// Reports any alerting level the newest candle has crossed.
  ///
  /// Called from build, so the report itself is left until the frame is done: a
  /// host that rebuilds in answer to it must not be asked to do so mid-build.
  void _checkAlerts() {
    final candles = widget.candles;
    if (candles == null || candles.isEmpty) return;

    final last = candles.last;
    final crossed = <HorizontalLine>[];
    final seen = <HorizontalLine>{};

    for (final line in _drawings.whereType<HorizontalLine>()) {
      if (!line.alert) continue;
      seen.add(line);

      final above = last.close >= line.price;
      final before = _alertSides[line];
      _alertSides[line] = above;
      // The first sighting sets the side; only a change from it is a crossing.
      if (before != null && before != above) crossed.add(line);
    }

    _alertSides.removeWhere((line, _) => !seen.contains(line));

    final report = widget.onAlertCrossed;
    if (report == null || crossed.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final line in crossed) {
        report(line, last);
      }
    });
  }

  /// Reads the drawings for this frame, from the controller when there is one.
  ///
  /// Called at the top of every build, because either source is usually mutated
  /// in place: the controller edits its own set, and a host without one appends
  /// to the lists it passed.
  void _collectDrawings() {
    final controller = widget.drawingController;
    if (controller != null) {
      _drawings = controller.snapshot.all;
      return;
    }

    _drawings = <ChartLine>[
      ...widget.horizontalLines,
      ...widget.verticalLines,
      ...widget.trendLines,
      ...widget.rectangles,
      ...widget.fibRetracements,
      ...widget.drawings,
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.candles != null && widget.candles!.isEmpty) {
      mScrollX = mSelectX = 0.0;
      mScaleX = 1.0;
    }

    _refreshIndicatorsIfStale();
    _collectDrawings();
    _checkAlerts();

    return LayoutBuilder(
      builder: (context, constraints) {
        mHeight = constraints.maxHeight;
        mWidth = constraints.maxWidth;

        final baseDimension = BaseDimension(
          mBaseHeight: _resolveBaseHeight(constraints.maxHeight),
          volHidden: widget.volHidden,
          paneCount: _resolved.panes.length,
          legendRowCount: _legendRowCount,
          paneHeights: _effectivePaneHeights,
        );

        painter = ChartPainter(
          widget.chartStyle,
          widget.chartColors,
          baseDimension: baseDimension,
          drawings: _drawings,
          signals: widget.signals,
          timeFrame: widget.timeFrame,
          emitInfoWindow: _emitInfoWindow,
          xFrontPadding: widget.xFrontPadding,
          isTrendLine: widget.isTrendLine,
          selectY: mSelectY,
          candles: widget.candles,
          scaleX: mScaleX,
          scrollX: mScrollX,
          selectX: mSelectX,
          isLongPress: isLongPress,
          isOnTap: isOnTap,
          isHovering: _isHovering,
          suppressCrosshair: _isDrawing || isDraggingHandle,
          isTapShowInfoDialog: widget.isTapShowInfoDialog,
          overlays: _resolved.overlays,
          panes: _resolved.panes,
          volHidden: widget.volHidden,
          isLine:
              _chartType != ChartType.candles && _chartType != ChartType.bars,
          chartType: _chartType,
          baselinePrice: widget.baselinePrice,
          timeZoneOffset: widget.timeZoneOffset,
          highlightedPane: _reorderingPane,
          hideGrid: widget.hideGrid,
          showNowPrice: widget.showNowPrice,
          fixedLength: widget.fixedLength,
          verticalTextAlignment: widget.verticalTextAlignment,
          dateFormatter: widget.dateFormatter,
          watermarkPicture: _watermarkPicture,
          draftLine: _draft,
          selectedLine: _selected,
          drawingStyle: widget.drawingStyle,
          chartTranslations: widget.chartTranslations,
          showOhlcLegend: widget.showOhlcLegend,
          priceAxisScale: widget.priceAxisScale,
        );

        return Stack(
          children: [
            MouseRegion(
              opaque: false,
              cursor: _hoverCursor,
              onHover: (event) => _handleHover(event.localPosition),
              onExit: (_) {
                _lastHoverPosition = null;
                if (_isPreviewing) _cancelDrawing();
                _clearHoverCrosshair();
              },
              // Inside the MouseRegion, which otherwise keeps the raw pointer
              // events from reaching a Listener above it.
              child: Listener(
                onPointerDown: (event) => _pointerDown = event.localPosition,
                onPointerMove: (event) {
                  if (_isDrawing && _draft is TwoPointDrawing) {
                    mSelectX = event.localPosition.dx;
                    mSelectY = event.localPosition.dy;
                    notifyChanged();
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    if (isLongPress) {
                      isLongPress = false;
                      _closeInfoWindow();
                    }

                    final pos = details.localPosition;

                    if (!_isInChartArea(pos)) {
                      _closeInfoWindow();
                      _cancelDrawing();
                      return;
                    }

                    if (widget.currentDrawingTool == DrawingTool.none) {
                      _trySelectLine(pos);
                      _handleReadoutTap(pos);
                    } else {
                      _handleDrawingTap(pos);
                    }
                    notifyChanged();
                  },
                  onLongPressStart: (details) {
                    isOnTap = false;
                    isLongPress = true;
                    mSelectX = details.localPosition.dx;
                    mSelectY = details.localPosition.dy.clamp(
                      painter.mMainRect.top,
                      painter.mMainRect.bottom,
                    );

                    if (widget.currentDrawingTool == DrawingTool.none) {
                      _trySelectLine(details.localPosition);
                    } else {
                      _cancelDrawing();
                    }
                    notifyChanged();
                  },
                  onLongPressMoveUpdate: (details) {
                    if (isDraggingHandle) {
                      _applyHandleDrag(details.localPosition);
                    } else if (widget.currentDrawingTool == DrawingTool.none) {
                      mSelectX = details.localPosition.dx;
                      mSelectY = details.localPosition.dy;
                      notifyChanged();
                    }
                  },
                  onLongPressEnd: (_) {
                    isLongPress = false;
                    if (isDraggingHandle) _notifySelectedChanged();
                    notifyChanged();
                  },
                  onScaleStart: (details) {
                    _stopAnimation();
                    final pos = details.localFocalPoint;

                    if (widget.currentDrawingTool == DrawingTool.none) {
                      // A press on a pane's edge resizes it; one on its legend
                      // picks the pane up. Both are measured from where the
                      // pointer went down, not from where the drag was
                      // recognised.
                      final pressed = _pointerDown ?? pos;
                      final edge = _paneEdgeAt(pressed);
                      if (edge != null) {
                        _resizingPane = edge;
                        return;
                      }
                      final grab = _paneGrabAt(pressed);
                      if (grab != null) {
                        _reorderingPane = grab;
                        _reorderDelta = 0;
                        notifyChanged();
                        return;
                      }
                    }

                    if (widget.currentDrawingTool != DrawingTool.none) {
                      // A drag that begins after the first point belongs to the
                      // point still to come, so the anchor is left alone.
                      if (!_awaitingSecondPoint && !_startDraft(pos)) {
                        // Nowhere to anchor: drop the preview and let the drag
                        // scroll the chart as usual.
                        _resetDraft();
                      }
                    } else {
                      _trySelectLine(pos);
                      _onDragChanged(true);
                    }
                    notifyChanged();
                  },
                  onScaleUpdate: (details) {
                    if (isLongPress) return;

                    final resizing = _resizingPane;
                    if (resizing != null) {
                      _resizePane(resizing, details.focalPointDelta.dy);
                      return;
                    }
                    if (_reorderingPane != null) {
                      _reorderDelta += details.focalPointDelta.dy;
                      notifyChanged();
                      return;
                    }

                    if (details.scale != 1.0) {
                      // Zoom
                      mScaleX = (_lastScale * details.scale).clamp(0.1, 3.0);
                      notifyChanged();
                      return;
                    }

                    // Pan (drag)
                    final pos = details.localFocalPoint;
                    if (_isDrawing) {
                      _extendDraft(pos);
                    } else if (isDraggingHandle) {
                      _applyHandleDrag(pos);
                    } else {
                      mScrollX += details.focalPointDelta.dx / mScaleX;
                      mScrollX = mScrollX.clamp(
                        0.0,
                        BaseChartPainter.maxScrollX,
                      );
                      notifyChanged();
                    }
                  },
                  onScaleEnd: (details) {
                    if (_resizingPane != null) {
                      _resizingPane = null;
                      notifyChanged();
                      return;
                    }
                    if (_reorderingPane != null) {
                      _finishPaneReorder();
                      return;
                    }

                    if (_isDrawing) {
                      // Letting go without a far end keeps the anchor on the
                      // chart: the next tap finishes the line, so a press that
                      // wandered a pixel or two costs nothing. A freehand
                      // stroke is the exception — one that never moved is not a
                      // stroke at all.
                      if (!_draftIsIncomplete) {
                        _commitDraft();
                      } else if (_draft is FreehandDrawing) {
                        _resetDraft();
                      } else {
                        _awaitingSecondPoint = true;
                      }
                    }

                    if (isDraggingHandle) {
                      isDraggingHandle = false;
                      _notifySelectedChanged();
                      _onDragChanged(false);
                    }

                    isScale = false;
                    _lastScale = mScaleX;

                    if (!_isDrawing && !isDraggingHandle) {
                      final velocity = details.velocity.pixelsPerSecond.dx;
                      _onFling(velocity);
                    } else {
                      _onDragChanged(false);
                    }

                    notifyChanged();
                  },
                  child: Stack(
                    children: [
                      RepaintBoundary(
                        key: _paintKey,
                        child: CustomPaint(
                          size: Size.fromHeight(baseDimension.mDisplayHeight),
                          painter: painter,
                        ),
                      ),
                      if (widget.showInfoDialog) _buildInfoDialog(),
                      // The editor is for finished lines; it would only be in
                      // the way of one still being placed.
                      if (!_isDrawing &&
                          !_isPreviewing &&
                          _getSelectedLine() != null)
                        _buildDrawingToolbar(),
                    ],
                  ),
                ),
              ),
            ),
            // Touch platforms pinch to zoom; everything else gets the
            // slider. (`!isIOS || !isAndroid` was always true, so the slider
            // used to render on mobile too.)
            if (kIsWeb ||
                (defaultTargetPlatform != TargetPlatform.iOS &&
                    defaultTargetPlatform != TargetPlatform.android))
              _buildScaleX(),
            if (widget.showScrollToNowButton && !isChartAtRightEdge)
              _buildScrollToNowButton(),
          ],
        );
      },
    );
  }

  bool _isInChartArea(Offset pos) => painter.mMainRect.contains(pos);

  // ── Pane ergonomics ──────────────────────────────────────────────────────

  /// Which indicator pane's lower edge is within reach of [pos], if any.
  int? _paneEdgeAt(Offset pos) {
    if (!widget.resizablePanes) return null;
    final tolerance = widget.chartStyle.paneResizeTolerance;
    for (var i = 0; i < painter.mSecondaryRectList.length; i++) {
      final rect = painter.mSecondaryRectList[i].mRect;
      if ((pos.dy - rect.bottom).abs() <= tolerance) return i;
    }
    return null;
  }

  /// Which indicator pane's legend strip [pos] landed on, if any.
  ///
  /// That strip is the pane's grab handle: it is the one part of a pane with no
  /// values under it.
  int? _paneGrabAt(Offset pos) {
    if (!widget.reorderablePanes) return null;
    final grab = widget.chartStyle.paneGrabHeight;
    for (var i = 0; i < painter.mSecondaryRectList.length; i++) {
      final top =
          painter.mSecondaryRectList[i].mRect.top - painter.mChildPadding;
      if (pos.dy >= top && pos.dy <= top + grab) return i;
    }
    return null;
  }

  /// Makes pane [index] taller or shorter by [delta].
  void _resizePane(int index, double delta) {
    final heights = [..._effectivePaneHeights];
    if (index < 0 || index >= heights.length) return;

    heights[index] = (heights[index] + delta).clamp(
      widget.chartStyle.minPaneHeight,
      widget.chartStyle.maxPaneHeight,
    );
    _paneHeights = heights;
    notifyChanged();
  }

  /// Works out where the pane being dragged was dropped, and reports the move.
  void _finishPaneReorder() {
    final from = _reorderingPane;
    _reorderingPane = null;
    if (from == null) {
      _reorderDelta = 0;
      return;
    }

    final heights = _effectivePaneHeights;
    final height = from < heights.length
        ? heights[from]
        : BaseDimension.secondaryPaneHeight;
    final steps = height <= 0 ? 0 : (_reorderDelta / height).round();
    final to = (from + steps).clamp(0, math.max(0, heights.length - 1)).toInt();
    _reorderDelta = 0;

    if (to != from) widget.onReorderPane?.call(from, to);
    notifyChanged();
  }

  /// The cursor for wherever the mouse is resting.
  MouseCursor get _hoverCursor {
    if (widget.currentDrawingTool != DrawingTool.none) {
      return SystemMouseCursors.precise;
    }
    final at = _lastHoverPosition;
    if (at == null) return MouseCursor.defer;
    if (_paneEdgeAt(at) != null) return SystemMouseCursors.resizeUpDown;
    if (_paneGrabAt(at) != null) return SystemMouseCursors.grab;
    return MouseCursor.defer;
  }

  /// Opens, moves or dismisses the tap-driven readout.
  ///
  /// Only runs when [KChartWidget.isTapShowInfoDialog] is set; a tap that
  /// selected a line belongs to the line, not the readout.
  void _handleReadoutTap(Offset pos) {
    if (!widget.isTapShowInfoDialog || _getSelectedLine() != null) {
      if (isOnTap) {
        isOnTap = false;
        _closeInfoWindow();
      }
      return;
    }

    // Tapping the readout's own candle again puts it away.
    final samePlace = isOnTap && (pos.dx - mSelectX).abs() < 2;
    isOnTap = !samePlace;
    if (!isOnTap) {
      _closeInfoWindow();
      return;
    }
    mSelectX = pos.dx;
    mSelectY = pos.dy.clamp(painter.mMainRect.top, painter.mMainRect.bottom);
  }

  /// The last thing the info dialog was told, so a repeat can be dropped.
  InfoWindowEntity? _lastInfoWindow;

  /// Tells the info dialog which candle the crosshair is on.
  ///
  /// Only speaks up when something has actually changed; see
  /// `ChartPainter.emitInfoWindow`.
  void _emitInfoWindow(InfoWindowEntity? entity) {
    final last = _lastInfoWindow;
    if (identical(last?.kLineEntity, entity?.kLineEntity) &&
        last?.isLeft == entity?.isLeft) {
      return;
    }
    _lastInfoWindow = entity;
    if (!mInfoWindowStream.isClosed) mInfoWindowStream.sink.add(entity);
  }

  void _closeInfoWindow() => _emitInfoWindow(null);

  void _cancelDrawing() {
    _resetDraft();
    notifyChanged();
  }

  /// Throws away the line being placed, without asking for a repaint.
  void _resetDraft() {
    _draft = null;
    _isDrawing = false;
    _awaitingSecondPoint = false;
    _isPreviewing = false;
  }

  // ── Placing a new line ───────────────────────────────────────────────────

  /// Where on the chart [pos] anchors a drawing, or null when it is off the
  /// data.
  ///
  /// Points land on candles, so a line drawn today sits on the same candles
  /// tomorrow. With [KChartWidget.magnetMode] on, the price snaps to a nearby
  /// open, high, low or close as well.
  ({DateTime time, double price})? _anchorAt(Offset pos) {
    final candles = widget.candles;
    if (candles == null || candles.isEmpty) return null;
    final index = painter.calculateSelectedX(pos.dx);
    if (index < 0 || index >= candles.length) return null;
    final time = candles[index].dateTime;
    if (time == null) return null;

    final price = painter.calculatePrice(pos.dy);
    return (
      time: time,
      price: widget.magnetMode
          ? _magnetPrice(candles[index], pos.dy, price)
          : price,
    );
  }

  /// The candle price nearest to [y], or [fallback] when none is close enough.
  double _magnetPrice(KLineEntity candle, double y, double fallback) {
    var best = fallback;
    var bestDistance = widget.drawingStyle.magnetSnapDistance;
    for (final value in [candle.open, candle.high, candle.low, candle.close]) {
      final distance = (painter.getMainY(value) - y).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = value;
      }
    }
    return best;
  }

  /// Places the first point of a new drawing at [pos].
  ///
  /// Returns false when [pos] is not somewhere a drawing can be anchored, or
  /// when the tool has nothing to show until a point lands, leaving the tool
  /// armed and waiting for a better spot.
  bool _startDraft(Offset pos, {bool preview = false}) {
    if (!_isInChartArea(pos)) return false;
    final anchor = _anchorAt(pos);
    if (anchor == null) return false;

    final style = widget.drawingStyle;
    final title = anchor.price.toStringAsFixed(widget.fixedLength);

    // A two-point drawing has nothing to preview: until its first point lands
    // there is no shape yet, only a cursor.
    final ChartLine? draft = switch (widget.currentDrawingTool) {
      DrawingTool.none => null,
      DrawingTool.horizontal => HorizontalLine(
        price: anchor.price,
        title: title,
      ),
      DrawingTool.horizontalRay => HorizontalLine(
        price: anchor.price,
        startTime: anchor.time,
        title: title,
      ),
      DrawingTool.vertical => VerticalLine(
        time: anchor.time,
        title: painter.getDate(anchor.time),
      ),
      _ when preview => null,
      DrawingTool.trend => TrendLine(time1: anchor.time, price1: anchor.price),
      DrawingTool.ray => TrendLine(
        time1: anchor.time,
        price1: anchor.price,
        extend: LineExtension.right,
      ),
      DrawingTool.extendedLine => TrendLine(
        time1: anchor.time,
        price1: anchor.price,
        extend: LineExtension.both,
      ),
      DrawingTool.arrow => TrendLine(
        time1: anchor.time,
        price1: anchor.price,
        arrow: true,
      ),
      DrawingTool.rectangle => RectangleDrawing(
        time1: anchor.time,
        price1: anchor.price,
        fillOpacity: style.rectangleFillOpacity,
      ),
      DrawingTool.ellipse => EllipseDrawing(
        time1: anchor.time,
        price1: anchor.price,
        fillOpacity: style.shapeFillOpacity,
      ),
      DrawingTool.triangle => TriangleDrawing(
        time1: anchor.time,
        price1: anchor.price,
        fillOpacity: style.shapeFillOpacity,
      ),
      DrawingTool.fibRetracement => FibRetracement(
        time1: anchor.time,
        price1: anchor.price,
        levels: List<double>.of(style.fibLevels),
      ),
      DrawingTool.measure => MeasureDrawing(
        time1: anchor.time,
        price1: anchor.price,
        fillOpacity: style.measureFillOpacity,
      ),
      DrawingTool.channel => ParallelChannel(
        time1: anchor.time,
        price1: anchor.price,
        fillOpacity: style.channelFillOpacity,
      ),
      DrawingTool.position => PositionDrawing(
        time1: anchor.time,
        price1: anchor.price,
        fillOpacity: style.positionFillOpacity,
        profitColor: widget.chartColors.upColor,
        lossColor: widget.chartColors.dnColor,
      ),
      DrawingTool.text => TextAnnotation(
        time: anchor.time,
        price: anchor.price,
      ),
      DrawingTool.brush => FreehandDrawing(
        points: [(time: anchor.time, price: anchor.price)],
      ),
    };
    if (draft == null) return false;

    _draft = draft;
    _selected = null;
    _isPreviewing = preview;
    _isDrawing = !preview;
    return true;
  }

  /// Moves the free end of the drawing in progress to [pos].
  void _extendDraft(Offset pos) {
    final anchor = _anchorAt(pos);
    if (anchor == null) return;

    switch (_draft) {
      case null:
        return;
      case HorizontalLine(:final isRay) && final line:
        line
          ..price = anchor.price
          ..title = anchor.price.toStringAsFixed(widget.fixedLength);
        // A ray only follows the pointer sideways while it is a preview; once
        // it has been placed, its start stays where the user put it.
        if (isRay && _isPreviewing) line.startTime = anchor.time;
      case VerticalLine line:
        line
          ..time = anchor.time
          ..title = painter.getDate(anchor.time);
      case TextAnnotation note:
        note
          ..time = anchor.time
          ..price = anchor.price;
      case FreehandDrawing stroke:
        stroke.extendTo((time: anchor.time, price: anchor.price));
      case ThreePointDrawing shape when shape.hasSecondPoint:
        // The base line has landed, so this is the point that finishes the
        // shape: the parallel, the stop, the last corner.
        shape
          ..time3 = anchor.time
          ..price3 = anchor.price;
      case TwoPointDrawing shape:
        shape
          ..time2 = anchor.time
          ..price2 = anchor.price;
    }
    notifyChanged();
  }

  /// True while the drawing in progress still needs a point.
  bool get _draftIsIncomplete {
    final draft = _draft;
    if (draft is TwoPointDrawing) return !draft.isComplete;
    if (draft is FreehandDrawing) return !draft.isComplete;
    return false;
  }

  /// Hands the finished drawing to the host and leaves it selected, the way
  /// the editing toolbar expects to find it.
  void _commitDraft() {
    final draft = _draft;
    if (draft == null || _draftIsIncomplete) return;

    _draft = null;
    _isDrawing = false;
    _awaitingSecondPoint = false;
    _isPreviewing = false;
    // Reported before it is selected: with a controller, a drawing has to be
    // one of its own before it can be the one it has selected.
    _notifyLineChanged(draft);
    _selected = widget.selectAfterDrawing ? draft : null;
  }

  /// Handles a tap while a drawing tool is armed.
  ///
  /// One tap is a whole horizontal or vertical line; a trend line takes the
  /// first tap as its anchor and the next one as its far end.
  void _handleDrawingTap(Offset pos) {
    if (_awaitingSecondPoint) {
      _extendDraft(pos);
      if (!_draftIsIncomplete) _commitDraft();
      return;
    }

    if (!_startDraft(pos)) return;
    if (_draftIsIncomplete) {
      _awaitingSecondPoint = true;
    } else {
      _commitDraft();
    }
  }

  /// Trails an armed tool along with the mouse.
  ///
  /// Before anything is placed this previews where a line would land; between
  /// the two points of a trend line it rubber-bands the far end.
  void _handleHover(Offset pos) {
    if (_lastHoverPosition == pos) return;
    _lastHoverPosition = pos;

    if (widget.currentDrawingTool == DrawingTool.none) {
      _updateHoverCrosshair(pos);
      return;
    }

    if (_awaitingSecondPoint) {
      if (_isInChartArea(pos)) _extendDraft(pos);
      return;
    }
    if (_isDrawing) return;

    if (!_isInChartArea(pos)) {
      if (_isPreviewing) _cancelDrawing();
      return;
    }
    if (_isPreviewing) {
      _extendDraft(pos);
    } else if (_startDraft(pos, preview: true)) {
      notifyChanged();
    }
  }

  /// Puts the crosshair under a resting mouse.
  ///
  /// A press already owns the crosshair, and so does a drawing being placed, so
  /// hovering only speaks up when neither is happening.
  void _updateHoverCrosshair(Offset pos) {
    if (!widget.crosshairOnHover || isLongPress || isDraggingHandle) return;

    // The crosshair reads the volume and indicator panes too, so anywhere with
    // something to read counts as over the chart.
    if (painter.getCrossArea(pos.dy) == CrossArea.none) {
      _clearHoverCrosshair();
      return;
    }

    _isHovering = true;
    mSelectX = pos.dx;
    mSelectY = pos.dy;
    notifyChanged();
  }

  void _clearHoverCrosshair() {
    if (!_isHovering) return;
    _isHovering = false;
    _closeInfoWindow();
    notifyChanged();
  }

  void _trySelectLine(Offset pos) {
    isDraggingHandle = false;
    draggingAnchor = null;

    final candles = widget.candles;
    if (candles == null || candles.isEmpty) {
      _deselectAll();
      return;
    }

    // Newest first, so a drawing laid over another is the one that a tap in
    // the overlap picks up.
    for (final line in _drawings.reversed) {
      if (line.hidden) continue;
      final anchor = _hitDrawing(pos, line);
      if (anchor == null) continue;
      _select(pos, line, anchor: anchor);
      return;
    }

    _deselectAll();
  }

  /// Which part of [line] is under [pos]: 1, 2 or 3 for one of its anchors, 0
  /// for the drawing itself, or null when the tap missed it.
  int? _hitDrawing(Offset pos, ChartLine line) {
    final tolerance = widget.drawingStyle.hitTestTolerance;
    final handleTolerance = widget.drawingStyle.handleHitTestTolerance;

    switch (line) {
      case HorizontalLine():
        if ((pos.dy - painter.getMainY(line.price)).abs() >= tolerance) {
          return null;
        }
        // A ray only exists to the right of where it starts.
        final start = painter.horizontalRayStartX(line);
        if (start != null && pos.dx < start - tolerance) return null;
        return 0;

      case VerticalLine():
        final x = _canvasX(line.time);
        return x != null && (pos.dx - x).abs() < tolerance ? 0 : null;

      case TextAnnotation():
        // A note is a small target, so it answers to whichever tolerance is the
        // more forgiving.
        final at = _canvasPoint(line.time, line.price);
        final reach = math.max(tolerance, handleTolerance);
        return at != null && (pos - at).distance < reach ? 0 : null;

      case FreehandDrawing():
        return _hitFreehand(pos, line, tolerance) ? 0 : null;

      case TwoPointDrawing():
        return _hitTwoPoint(pos, line);

      default:
        return null;
    }
  }

  /// Whether [pos] lands on any part of a freehand stroke.
  bool _hitFreehand(Offset pos, FreehandDrawing stroke, double tolerance) {
    Offset? previous;
    for (final point in stroke.points) {
      final at = _canvasPoint(point.time, point.price);
      if (at == null) continue;
      if (previous != null &&
          _distanceToSegment(pos, previous, at) < tolerance) {
        return true;
      }
      previous = at;
    }
    return false;
  }

  /// Which part of [shape] is under [pos]: 1, 2 or 3 for an anchor, 0 for the
  /// shape itself, or null when the tap missed it.
  int? _hitTwoPoint(Offset pos, TwoPointDrawing shape) {
    final tolerance = widget.drawingStyle.hitTestTolerance;
    final handleTolerance = widget.drawingStyle.handleHitTestTolerance;

    final p1 = _canvasPoint(shape.time1, shape.price1);
    if (p1 == null) return null;

    // A half-placed shape only has its first anchor to grab.
    if (!shape.hasSecondPoint) {
      return (pos - p1).distance < handleTolerance ? 1 : null;
    }

    final p2 = _canvasPoint(shape.time2, shape.price2);
    if (p2 == null) return null;
    final p3 = shape is ThreePointDrawing
        ? _canvasPoint(shape.time3, shape.price3)
        : null;

    // Near an anchor grabs the nearest one; anywhere else on the shape picks
    // the whole thing up.
    ({int anchor, double distance})? nearest;
    for (final (anchor, point) in [(1, p1), (2, p2), if (p3 != null) (3, p3)]) {
      final distance = (pos - point).distance;
      if (distance >= handleTolerance) continue;
      if (nearest == null || distance < nearest.distance) {
        nearest = (anchor: anchor, distance: distance);
      }
    }
    if (nearest != null) return nearest.anchor;

    return _hitShapeBody(pos, shape, p1, p2, p3, tolerance) ? 0 : null;
  }

  /// Whether [pos] lands on the body of [shape] — its stroke, its outline or
  /// one of its levels, never the empty space they enclose.
  bool _hitShapeBody(
    Offset pos,
    TwoPointDrawing shape,
    Offset p1,
    Offset p2,
    Offset? p3,
    double tolerance,
  ) {
    switch (shape) {
      case TrendLine(extend: LineExtension.none):
        return _distanceToSegment(pos, p1, p2) < tolerance;

      case TrendLine(:final extend):
        // A ray and an extended line are grabbable along everything they
        // actually draw, which runs off the side of the chart.
        final size = Size(mWidth, mHeight);
        final from = extend == LineExtension.both
            ? painter.extendPoint(p2, p1, size)
            : p1;
        return _distanceToSegment(
              pos,
              from,
              painter.extendPoint(p1, p2, size),
            ) <
            tolerance;

      case RectangleDrawing() || MeasureDrawing():
        return _hitRectEdges(pos, Rect.fromPoints(p1, p2), tolerance);

      case EllipseDrawing():
        return _hitOval(pos, Rect.fromPoints(p1, p2), tolerance);

      case TriangleDrawing():
        final corners = p3 == null
            ? [(p1, p2)]
            : [(p1, p2), (p2, p3), (p3, p1)];
        return corners.any(
          (edge) => _distanceToSegment(pos, edge.$1, edge.$2) < tolerance,
        );

      case ParallelChannel channel:
        final size = Size(mWidth, mHeight);
        final baseTo = channel.extend ? painter.extendPoint(p1, p2, size) : p2;
        if (_distanceToSegment(pos, p1, baseTo) < tolerance) return true;

        final offset = channel.offset;
        if (offset == null) return false;
        final parallel1 = Offset(
          p1.dx,
          painter.getMainY(channel.price1 + offset),
        );
        final parallel2 = Offset(
          p2.dx,
          painter.getMainY((channel.price2 ?? channel.price1) + offset),
        );
        final parallelTo = channel.extend
            ? painter.extendPoint(parallel1, parallel2, size)
            : parallel2;
        return _distanceToSegment(pos, parallel1, parallelTo) < tolerance;

      case PositionDrawing position:
        // A position is a block: anywhere inside it, or on the entry line,
        // picks it up.
        final left = math.min(p1.dx, p2.dx);
        final right = math.max(p1.dx, p2.dx);
        if (pos.dx < left - tolerance || pos.dx > right + tolerance) {
          return false;
        }
        final stop = position.stopPrice;
        final top = math.min(
          p1.dy,
          math.min(p2.dy, stop == null ? p1.dy : painter.getMainY(stop)),
        );
        final bottom = math.max(
          p1.dy,
          math.max(p2.dy, stop == null ? p1.dy : painter.getMainY(stop)),
        );
        return pos.dy >= top - tolerance && pos.dy <= bottom + tolerance;

      case FibRetracement fib:
        if (pos.dx < math.min(p1.dx, p2.dx) - tolerance) return false;
        return fib.levels.any((ratio) {
          final price = fib.priceAt(ratio);
          return price != null &&
              (pos.dy - painter.getMainY(price)).abs() < tolerance;
        });

      case TwoPointDrawing():
        return _distanceToSegment(pos, p1, p2) < tolerance;
    }
  }

  /// Whether [pos] lands on one of [rect]'s four edges.
  static bool _hitRectEdges(Offset pos, Rect rect, double tolerance) {
    return [
      (rect.topLeft, rect.topRight),
      (rect.topRight, rect.bottomRight),
      (rect.bottomRight, rect.bottomLeft),
      (rect.bottomLeft, rect.topLeft),
    ].any((edge) => _distanceToSegment(pos, edge.$1, edge.$2) < tolerance);
  }

  /// Whether [pos] lands on the outline of the oval inside [rect].
  ///
  /// Measured in the oval's own stretched space, then scaled back by its
  /// shorter radius, which keeps a long flat ellipse as grabbable as a round
  /// one.
  static bool _hitOval(Offset pos, Rect rect, double tolerance) {
    final rx = rect.width / 2;
    final ry = rect.height / 2;
    if (rx <= 0 || ry <= 0) return false;

    final dx = (pos.dx - rect.center.dx) / rx;
    final dy = (pos.dy - rect.center.dy) / ry;
    final radius = math.sqrt(dx * dx + dy * dy);
    return ((radius - 1).abs() * math.min(rx, ry)) < tolerance;
  }

  /// Where a candle sits on the canvas, or null when it is not in the data.
  double? _canvasX(DateTime time) {
    final candles = widget.candles;
    if (candles == null) return null;
    final index = candles.indexWhere((e) => e.dateTime == time);
    if (index == -1) return null;
    return painter.translateXtoX(painter.getX(index));
  }

  /// Where an anchor sits on the canvas, or null when its candle is gone.
  Offset? _canvasPoint(DateTime? time, double? price) {
    final candles = widget.candles;
    if (candles == null || time == null || price == null) return null;
    final index = candles.indexWhere((e) => e.dateTime == time);
    if (index == -1) return null;
    return Offset(
      painter.translateXtoX(painter.getX(index)),
      painter.getMainY(price),
    );
  }

  /// Selects one drawing, clearing the last, and arms it for dragging from
  /// [pos] — the point that picked it, whether that was a tap, a long press or
  /// the start of a drag.
  void _select(Offset pos, ChartLine line, {int? anchor}) {
    setState(() {
      _selected = line;
      draggingAnchor = anchor;
      isDraggingHandle = true;
    });
    _beginHandleDrag(pos);
  }

  /// Shortest distance from [point] to the segment [a]–[b].
  static double _distanceToSegment(Offset point, Offset a, Offset b) {
    final ab = b - a;
    final lengthSquared = ab.distanceSquared;
    if (lengthSquared == 0) return (point - a).distance;

    final ap = point - a;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / lengthSquared).clamp(0.0, 1.0);
    return (point - (a + ab * t)).distance;
  }

  /// Remembers where a drag began, so a whole drawing can be shifted.
  void _beginHandleDrag(Offset pos) {
    final candles = widget.candles;
    if (candles == null || candles.isEmpty) return;

    _dragStart = (
      index: painter.calculateSelectedX(pos.dx),
      price: painter.calculatePrice(pos.dy),
    );
    _dragOrigin = _anchorsOf(_selected);
  }

  /// Every anchor of [line], as candle indices and prices.
  ///
  /// This is what a whole-shape drag shifts: one list, whether the drawing has
  /// two anchors, three, or a hundred points of freehand.
  List<({int index, double price})>? _anchorsOf(ChartLine? line) {
    final candles = widget.candles;
    if (candles == null || line == null) return null;

    int? indexOf(DateTime? time) {
      if (time == null) return null;
      final index = candles.indexWhere((e) => e.dateTime == time);
      return index == -1 ? null : index;
    }

    switch (line) {
      case FreehandDrawing stroke:
        final anchors = <({int index, double price})>[];
        for (final point in stroke.points) {
          final index = indexOf(point.time);
          if (index == null) return null;
          anchors.add((index: index, price: point.price));
        }
        return anchors;
      case TwoPointDrawing shape:
        final i1 = indexOf(shape.time1);
        if (i1 == null) return null;
        final anchors = [(index: i1, price: shape.price1)];

        final i2 = indexOf(shape.time2);
        final p2 = shape.price2;
        if (i2 == null || p2 == null) return anchors;
        anchors.add((index: i2, price: p2));

        if (shape is! ThreePointDrawing) return anchors;
        final i3 = indexOf(shape.time3);
        final p3 = shape.price3;
        if (i3 == null || p3 == null) return anchors;
        return [...anchors, (index: i3, price: p3)];
      default:
        return null;
    }
  }

  /// Writes [anchors] back onto [line], in the order [_anchorsOf] read them.
  void _writeAnchors(
    ChartLine line,
    List<({int index, double price})> anchors,
    List<KLineEntity> candles,
  ) {
    DateTime? timeAt(int index) =>
        index < 0 || index >= candles.length ? null : candles[index].dateTime;

    switch (line) {
      case FreehandDrawing stroke:
        final moved = <FreehandPoint>[];
        for (final anchor in anchors) {
          final time = timeAt(anchor.index);
          if (time == null) return;
          moved.add((time: time, price: anchor.price));
        }
        stroke.points = moved;
      case TwoPointDrawing shape:
        final time1 = timeAt(anchors[0].index);
        if (time1 == null) return;
        shape
          ..time1 = time1
          ..price1 = anchors[0].price;

        if (anchors.length < 2) return;
        final time2 = timeAt(anchors[1].index);
        if (time2 == null) return;
        shape
          ..time2 = time2
          ..price2 = anchors[1].price;

        if (shape is! ThreePointDrawing || anchors.length < 3) return;
        final time3 = timeAt(anchors[2].index);
        if (time3 == null) return;
        shape
          ..time3 = time3
          ..price3 = anchors[2].price;
      default:
        return;
    }
  }

  /// Moves the selected drawing to follow the pointer at [pos].
  void _applyHandleDrag(Offset pos) {
    final candles = widget.candles;
    final line = _getSelectedLine();
    if (candles == null || candles.isEmpty || line == null || line.locked) {
      return;
    }

    final index = painter.calculateSelectedX(pos.dx);
    if (index < 0 || index >= candles.length) return;
    final time = candles[index].dateTime;
    if (time == null) return;
    final price = painter.calculatePrice(pos.dy);

    switch (line) {
      case HorizontalLine():
        // A title the user never customised tracks the price it was named for.
        if (line.title == line.price.toStringAsFixed(widget.fixedLength)) {
          line.title = price.toStringAsFixed(widget.fixedLength);
        }
        line.price = price;
        // Dragging a ray carries its start along with it.
        if (line.isRay) line.startTime = time;
      case VerticalLine():
        if (line.title == painter.getDate(line.time)) {
          line.title = painter.getDate(time);
        }
        line.time = time;
      case TextAnnotation():
        line
          ..time = time
          ..price = price;
      case FreehandDrawing():
        _dragWholeDrawing(line, candles, index, price);
      case TwoPointDrawing():
        _dragShape(line, candles, index, time, price);
    }
    notifyChanged();
  }

  /// Drags one anchor of [shape], or the whole shape when the grab landed on
  /// its body.
  void _dragShape(
    TwoPointDrawing shape,
    List<KLineEntity> candles,
    int index,
    DateTime time,
    double price,
  ) {
    switch (draggingAnchor) {
      case 1:
        shape
          ..time1 = time
          ..price1 = price;
      case 2:
        shape
          ..time2 = time
          ..price2 = price;
      case 3:
        if (shape is! ThreePointDrawing) return;
        shape
          ..time3 = time
          ..price3 = price;
      case 0:
        _dragWholeDrawing(shape, candles, index, price);
    }
  }

  /// Shifts every anchor of [line] by the same number of candles and the same
  /// amount of price, stopping once either end reaches the edge of the data.
  void _dragWholeDrawing(
    ChartLine line,
    List<KLineEntity> candles,
    int index,
    double price,
  ) {
    final start = _dragStart;
    final origin = _dragOrigin;
    if (start == null || origin == null || origin.isEmpty) return;

    var lowest = origin.first.index;
    var highest = origin.first.index;
    for (final anchor in origin) {
      lowest = math.min(lowest, anchor.index);
      highest = math.max(highest, anchor.index);
    }

    final shift = (index - start.index).clamp(
      -lowest,
      candles.length - 1 - highest,
    );
    final priceShift = price - start.price;

    _writeAnchors(line, [
      for (final anchor in origin)
        (index: anchor.index + shift, price: anchor.price + priceShift),
    ], candles);
  }

  void _stopAnimation({bool needNotify = true}) {
    if (_controller != null && _controller!.isAnimating) {
      _controller!.stop();
      _onDragChanged(false);
      if (needNotify) notifyChanged();
    }
  }

  void _onDragChanged(bool isOnDrag) {
    isDrag = isOnDrag;
    widget.isOnDrag?.call(isDrag);
  }

  void _onFling(double velocity) {
    _controller = AnimationController(
      duration: Duration(milliseconds: widget.flingTime),
      vsync: this,
    );
    aniX =
        Tween<double>(
          begin: mScrollX,
          end: velocity * widget.flingRatio + mScrollX,
        ).animate(
          CurvedAnimation(parent: _controller!.view, curve: widget.flingCurve),
        );

    aniX!.addListener(() {
      mScrollX = aniX!.value.clamp(0.0, BaseChartPainter.maxScrollX);
      notifyChanged();
    });

    aniX!.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        _onDragChanged(false);
        notifyChanged();
      }
    });

    _controller!.forward();
  }

  void notifyChanged() {
    setState(() {});
    widget.controller?.hostChanged();
  }

  // ── Driving the chart from outside ───────────────────────────────────────

  /// Wraps the painted chart, so it can be captured without the controls that
  /// float over it.
  final GlobalKey _paintKey = GlobalKey();

  @override
  double get chartScale => mScaleX;

  @override
  void setChartScale(double scale) {
    final clamped = scale.clamp(0.1, 3.0);
    if (clamped == mScaleX) return;
    mScaleX = clamped;
    _lastScale = clamped;
    notifyChanged();
  }

  @override
  bool get isChartAtRightEdge => mScrollX <= 0.5;

  @override
  void scrollChartToNow({bool animated = true}) {
    _stopAnimation(needNotify: false);
    if (!animated || mScrollX <= 0) {
      mScrollX = 0;
      notifyChanged();
      return;
    }

    final controller = AnimationController(
      duration: Duration(milliseconds: widget.flingTime),
      vsync: this,
    );
    _controller = controller;
    final animation = Tween<double>(begin: mScrollX, end: 0).animate(
      CurvedAnimation(parent: controller.view, curve: widget.flingCurve),
    );
    aniX = animation;
    animation.addListener(() {
      mScrollX = animation.value.clamp(0.0, BaseChartPainter.maxScrollX);
      notifyChanged();
    });
    controller.forward();
  }

  @override
  Future<Uint8List?> captureChart({double pixelRatio = 3}) async {
    final boundary =
        _paintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Widget _buildInfoDialog() {
    return StreamBuilder<InfoWindowEntity?>(
      stream: mInfoWindowStream.stream,
      builder: (context, snapshot) {
        if ((!isLongPress && !isOnTap) ||
            !snapshot.hasData ||
            snapshot.data?.kLineEntity == null) {
          return const SizedBox.shrink();
        }
        final entity = snapshot.data!.kLineEntity;
        // Never wider than the chart itself, whatever the caller asked for.
        final maxWidth = math.min(
          widget.infoDialogMaxWidth,
          math.max(widget.infoDialogWidth, mWidth - 20),
        );
        return Positioned(
          top: 10,
          left: snapshot.data!.isLeft ? 10.0 : null,
          right: snapshot.data!.isLeft ? null : 10.0,
          child:
              widget.infoDialogBuilder?.call(
                context,
                snapshot.data?.kLinePreviousEntity,
                entity,
              ) ??
              PopupInfoView(
                entity: entity,
                width: widget.infoDialogWidth,
                maxWidth: maxWidth,
                chartColors: widget.chartColors,
                chartTranslations: widget.chartTranslations,
                materialInfoDialog: widget.materialInfoDialog,
                timeFormat: widget.timeFormat,
                fixedLength: widget.fixedLength,
                livePrice: widget.candles?.last.close,
              ),
        );
      },
    );
  }

  Widget _buildScaleX() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: Listener(
          onPointerMove: (event) {
            if (event.delta.dx.isNegative) {
              mScaleX += 0.005;
            } else {
              mScaleX -= 0.005;
            }
            mScaleX = mScaleX.clamp(0.5, 2.2);
            setState(() {});
          },
          child: Container(height: 20, color: Colors.transparent),
        ),
      ),
    );
  }

  /// The button that jumps back to the live candle, shown only while the chart
  /// is scrolled away from it.
  Widget _buildScrollToNowButton() {
    final colors = widget.chartColors;
    return Positioned(
      right: 10,
      bottom: 28,
      child: Tooltip(
        message: widget.chartTranslations.jumpToNow,
        child: Material(
          color: colors.bgColor.withValues(alpha: .92),
          shape: const CircleBorder(),
          elevation: 2,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => scrollChartToNow(),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.keyboard_double_arrow_right_rounded,
                size: 18,
                color: colors.defaultTextColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawingToolbar() {
    final selected = _getSelectedLine();
    if (selected == null) return const SizedBox.shrink();

    return Positioned(
      left: _toolbarOffset.dx,
      top: _toolbarOffset.dy,
      child: DrawingToolbar(
        line: selected,
        style: widget.drawingStyle,
        translations: widget.chartTranslations.drawing,
        chartColors: widget.chartColors,
        onChanged: notifyChanged,
        onCommitted: () => _notifyLineChanged(selected),
        onDelete: _deleteSelected,
        onDone: _deselectAll,
        onMoved: widget.drawingStyle.toolbarDraggable ? _moveToolbar : null,
      ),
    );
  }
}
