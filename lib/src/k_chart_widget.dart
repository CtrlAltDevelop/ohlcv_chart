import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'chart_controller.dart';
import 'chart_event.dart';
import 'chart_menu.dart';
import 'visible_range.dart';
import 'comparison.dart';
import 'replay_controller.dart';
import 'trading.dart';
import 'chart_style.dart';
import 'chart_translations.dart';
import 'chart_type.dart';
import 'components/popup_info_view.dart';
import 'drawing/drawing_controller.dart';
import 'drawing/drawing_coordinates.dart';
import 'drawing/drawing_style.dart';
import 'drawing/drawing_template.dart';
import 'drawing/drawing_toolbar.dart';
import 'drawing/shape_geometry.dart';
import 'entity/callout_drawing.dart';
import 'entity/candle_entity.dart';
import 'entity/drawing_codec.dart';
import 'entity/ellipse_drawing.dart';
import 'entity/fib_drawings.dart';
import 'entity/fib_retracement.dart';
import 'entity/freehand_drawing.dart';
import 'entity/gann_drawings.dart';
import 'entity/horizontal_line.dart';
import 'entity/info_window_entity.dart';
import 'entity/k_line_entity.dart';
import 'entity/line.dart';
import 'entity/measure_drawing.dart';
import 'entity/multi_point_drawing.dart';
import 'entity/parallel_channel.dart';
import 'entity/pitchfork_drawing.dart';
import 'entity/position_drawing.dart';
import 'entity/range_drawings.dart';
import 'entity/rectangle_drawing.dart';
import 'entity/regression_channel.dart';
import 'entity/signal_entity.dart';
import 'entity/text_annotation.dart';
import 'entity/trend_line.dart';
import 'entity/triangle_drawing.dart';
import 'entity/two_point_drawing.dart';
import 'entity/vertical_lines.dart';
import 'indicators/indicator.dart';
import 'indicators/indicator_cache.dart';
import 'indicators/resolved_indicator.dart';
import 'price_axis_scale.dart';
import 'renderer/base_chart_painter.dart';
import 'renderer/base_dimension.dart';
import 'renderer/candle_index.dart';
import 'renderer/chart_painter.dart';
import 'renderer/main_renderer.dart';
import 'renderer/text_painter_cache.dart';
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

  /// The next three taps place a [PitchforkDrawing]: the pivot, then the swing
  /// either side of it.
  pitchfork,

  /// The next two taps place a [GannFan]: the pivot, then the `1×1`.
  gannFan,

  /// The next two taps place opposite corners of a [GannBox].
  gannBox,

  /// The next three taps place a [FibExtension]: the impulse, then where the
  /// retracement ended.
  fibExtension,

  /// The next two taps place the swing a [FibFan] spreads over.
  fibFan,

  /// The next two taps place the unit span of a [FibTimeZones].
  fibTimeZones,

  /// The next two taps place the stretch a [RegressionChannel] is fitted over.
  regressionTrend,

  /// The next five taps place the X, A, B, C and D of an [XabcdDrawing].
  xabcd,

  /// The next two taps place the levels a [PriceRangeDrawing] brackets.
  priceRange,

  /// The next two taps place the span a [DateRangeDrawing] brackets.
  dateRange,

  /// The next two taps place a [CalloutDrawing]: what it points at, then where
  /// the box sits.
  callout,

  /// Taps lay down the legs of a [PathDrawing], one after another, until it is
  /// finished with a double-tap or by disarming the tool.
  path,

  /// The next tap plants a [FlagDrawing].
  flag,
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

/// Sizes the watermark to `ChartStyle.watermarkScale` of the candle area's
/// shorter side and places it by `ChartStyle.watermarkAlignment`, measuring
/// that area the way [painter] lays it out.
class _WatermarkLayout extends SingleChildLayoutDelegate {
  _WatermarkLayout(this.painter);

  final ChartPainter painter;

  Rect _area(Size size) {
    // The same layout the painter runs when it paints this size, so the
    // watermark and the candles agree on where the candle area is.
    painter.layout(size);
    return painter.mMainRect;
  }

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final area = _area(constraints.biggest);
    final width = math.max(
      0.0,
      math.min(area.width, area.height) * painter.chartStyle.watermarkScale,
    );
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: math.max(0.0, area.height),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) => painter
      .chartStyle
      .watermarkAlignment
      .inscribe(childSize, painter.mMainRect)
      .topLeft;

  @override
  bool shouldRelayout(_WatermarkLayout oldDelegate) =>
      !identical(oldDelegate.painter, painter);
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
///   timeFrame: const Duration(minutes: 15),
///   indicators: [MaIndicator(period: 20), MacdIndicator()],
/// );
/// ```
class KChartWidget extends StatefulWidget {
  /// Creates a candlestick chart over [candles], coloured by [chartColors].
  const KChartWidget(
    this.candles,
    this.chartColors, {
    this.isTrendLine = false,
    this.watermark,
    this.timeFrame,
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
    this.priceScaleDrag = true,
    this.scrollEnabled = true,
    this.zoomEnabled = true,
    this.replay,
    this.enableKeyboardShortcuts = true,
    this.crosshairOnHover = true,
    this.showOhlcLegend = false,
    this.priceAxisScale = PriceAxisScale.linear,
    this.secondaryPriceAxisScale,
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
    this.onDrawingAlert,
    this.comparisons = const [],
    this.session,
    this.candleColor,
    this.invertPriceAxis = false,
    this.showAverageClose = false,
    this.showHighLowOnAxis = false,
    this.orders = const [],
    this.positions = const [],
    this.onOrderDragged,
    this.onOrderMoved,
    this.onOrderTapped,
    this.onPositionTapped,
    this.onIndicatorAlert,
    this.events = const [],
    this.onEventTapped,
    this.onVisibleRangeChanged,
    this.onCrosshairChanged,
    this.showContextMenu = true,
    this.contextMenuBuilder,
    this.showDrawingCoordinates = true,
    this.selectAfterDrawing = true,
    this.volHidden = false,
    this.isLine = false,
    this.isTapShowInfoDialog = false,
    this.hideGrid = false,
    this.showNowPrice = true,
    this.showInfoDialog = true,
    this.lockPriceScale = false,
    this.lockedScaleFollowsPrice = false,
    this.materialInfoDialog = true,
    this.chartStyle = const ChartStyle(),
    this.drawingStyle = const DrawingStyle(),
    this.chartTranslations = const ChartTranslations(),
    this.timeFormat = TimeFormat.YEAR_MONTH_DAY,
    this.infoDialogBuilder,
    this.dateFormatter,
    this.priceFormatter,
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

  /// Snaps drawing anchors to the nearest open, high, low or close.
  ///
  /// A point only snaps when a candle's price is within
  /// [DrawingStyle.magnetSnapDistance] pixels of the pointer; further away it
  /// lands wherever the pointer is.
  ///
  /// This covers an anchor dragged after the fact as much as one being placed,
  /// which is how a line already drawn is pinned onto a wick. Dragging a
  /// drawing by its body is deliberately not snapped: it moves by the distance
  /// the pointer has travelled, and snapping one end of that measurement would
  /// shift the shape by the difference rather than move it.
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

  /// Called when the newest candle crosses a horizontal level with `alert` set.
  ///
  /// Fires once per crossing — the level's own side of the market has to change
  /// before it fires again — and carries the candle that did the crossing. For
  /// the other shapes that can be alerted on, use [onDrawingAlert].
  final void Function(HorizontalLine line, KLineEntity candle)? onAlertCrossed;

  /// Called when the newest candle crosses any alerting drawing's level.
  ///
  /// Every `AlertingDrawing` with `alert` set is watched — a horizontal level, a
  /// trend line, either side of a channel, each level of a retracement — and the
  /// price that was crossed comes along with the drawing and the candle, since a
  /// drawing may have several. Fires once per crossing per level.
  ///
  /// A horizontal level reports through both this and [onAlertCrossed], so an
  /// app written against the older callback carries on working.
  final void Function(ChartLine line, KLineEntity candle, double level)?
  onDrawingAlert;

  /// The regular trading session, in the zone the chart is showing.
  ///
  /// Set it and the candles outside it — the pre-market and after-hours
  /// stretches — are washed behind, so what is on screen says which of it is the
  /// regular session and which is not. Coloured from
  /// `ChartColors.extendedHoursColor`.
  final TradingSession? session;

  /// A colour of your own for the bar at an index, or null for the usual one.
  ///
  /// Asked about every candle, bar and column drawn, so a bar can be picked out
  /// for whatever reason: inside a session, above an average, part of a pattern.
  /// Returning null leaves the up or down colour it would have had.
  final Color? Function(CandleEntity candle, int index)? candleColor;

  /// Whether the price axis runs the other way, with higher prices lower down.
  ///
  /// What a chart of a yield, a spread or anything else read inversely wants —
  /// and what a trader who thinks in the other direction reaches for. Everything
  /// on the chart follows: the candles, the drawings, the crosshair and the
  /// orders all read off the same flipped axis, and a rising candle is still
  /// coloured as one.
  final bool invertPriceAxis;

  /// Whether the average close over the visible window is drawn as a level.
  ///
  /// Panning moves it, since it describes the window rather than the whole
  /// history. Coloured from `ChartColors.avgColor`.
  final bool showAverageClose;

  /// Whether the window's high and low are tagged on the price axis.
  ///
  /// The leader lines already mark which candle set each extreme; this says what
  /// to read them off the axis as.
  final bool showHighLowOnAxis;

  /// Working orders drawn across the candles.
  ///
  /// Each is a line the full width of the chart, tagged on the axis side. Where
  /// `ChartOrder.draggable` is set and [onOrderMoved] is given, the line can be
  /// dragged to a new price — which is how an order is modified from the chart.
  final List<ChartOrder> orders;

  /// Open positions drawn at their average entry.
  final List<ChartPosition> positions;

  /// Called while an order's line is being dragged.
  ///
  /// Fires on every move with the price the line is currently being held at, so
  /// a readout can follow it. The move is not final until [onOrderMoved].
  final void Function(ChartOrder order, double price)? onOrderDragged;

  /// Called when an order's line is let go at a new price.
  ///
  /// Where the amendment goes. The chart does not change the order itself: hand
  /// back a new list with the new price and it will be drawn there.
  final void Function(ChartOrder order, double price)? onOrderMoved;

  /// Called when an order's line is tapped rather than dragged.
  final ValueChanged<ChartOrder>? onOrderTapped;

  /// Called when a position's line is tapped.
  final ValueChanged<ChartPosition>? onPositionTapped;

  /// Called when the newest candle's indicator value crosses one of its alerts.
  ///
  /// Every `IndicatorAlert` on every indicator is watched — an RSI going over
  /// 70, a MACD histogram turning positive — and reported once per crossing,
  /// with the value that did the crossing. The value has to come back through
  /// the level before it fires again.
  final void Function(
    Indicator indicator,
    IndicatorAlert alert,
    KLineEntity candle,
    double value,
  )?
  onIndicatorAlert;

  /// Things that happened to the instrument, marked under the candles.
  ///
  /// Each is drawn as a small badge below the candle area, at the candle nearest
  /// its own time — so it says when something happened without covering the
  /// price it happened at. `ChartStyle.eventMarkRadius` sizes the badges, and
  /// setting it to zero leaves the events on the chart for a panel of your own
  /// to list without drawing anything.
  final List<ChartEvent> events;

  /// Called when the user taps an event's badge.
  ///
  /// Where a panel, a tooltip or a link to the filing goes.
  final ValueChanged<ChartEvent>? onEventTapped;

  /// Called whenever the candles in view change.
  ///
  /// Fires after the frame that changed them, so a host that rebuilds in answer
  /// is not asked to do so mid-build, and only when the range is actually
  /// different — scrolling within one candle reports nothing. What a "bars on
  /// screen" readout, a linked second chart, or a feed that loads history on
  /// demand listens to.
  final ValueChanged<ChartVisibleRange>? onVisibleRangeChanged;

  /// Called with the candle the crosshair moved onto, or null as it goes.
  ///
  /// Fires after the frame that moved it, on the same terms as
  /// [onVisibleRangeChanged], and only when the candle is actually different —
  /// sliding the pointer within one candle reports nothing. What a linked
  /// second chart listens to, through `ChartLink` or by hand.
  final ValueChanged<int?>? onCrosshairChanged;

  /// Instruments drawn over the candles for comparison.
  ///
  /// Each is drawn as a line, rebased by default so it starts where the main
  /// series does at the left edge of the window — which is how relative
  /// performance is read. Points are matched to candles by time, so a compared
  /// instrument on a different bar still lines up.
  final List<ComparisonSeries> comparisons;

  /// Whether a right-click opens a menu on the chart.
  ///
  /// The menu offered depends on what was clicked: a drawing gets its own
  /// actions — coordinates, duplicate, restack, lock, hide, alert, delete —
  /// and empty chart gets the ones that apply to the chart itself.
  final bool showContextMenu;

  /// Builds the right-click menu, given what was clicked.
  ///
  /// The request carries what the chart would have shown as `defaults`, so
  /// returning them with something appended adds an item and returning a list
  /// of your own replaces the menu. An empty list shows no menu at all.
  final ChartMenuBuilder? contextMenuBuilder;

  /// Whether the line editor offers a button that opens the coordinates dialog.
  ///
  /// The dialog reads out every anchor of the selected drawing and lets each
  /// one be typed in exactly, which is how a level placed by hand is tidied up
  /// afterwards.
  final bool showDrawingCoordinates;

  /// Whether a drawing the user has just finished is left selected, with the
  /// editor open on it.
  ///
  /// Turn it off to draw several of something without dismissing an editor
  /// between each one.
  final bool selectAfterDrawing;

  /// Duration of one candle, which the current-price tag counts down to.
  ///
  /// Null — the default — draws the current-price line and tag without a
  /// countdown, since nothing else is known about when the candle closes.
  final Duration? timeFrame;

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

  /// Lets the user scroll the chart sideways.
  ///
  /// Off, the window stays where it is: a drag neither slides it nor flings it,
  /// and [onLoadMore] is never asked for more candles, since no edge is ever
  /// reached. What is drawn is still whatever the window holds, so a chart that
  /// is meant to show one fixed stretch — a session, a day — wants its candles
  /// to fit the box: see `ChartStyle.pointWidth`.
  ///
  /// The controller is unaffected, the way [priceScaleDrag] leaves it: a chart
  /// the user cannot scroll can still be scrolled from your own code.
  final bool scrollEnabled;

  /// Lets the user zoom the chart in and out.
  ///
  /// Off, pinching does nothing and the zoom slider — which is only ever shown
  /// on the web and on desktop, where there is no pinch — is left off too.
  ///
  /// Worth turning off alongside [scrollEnabled] for a chart meant to sit
  /// still: zooming out makes the candles narrower, which leaves the window
  /// with room to scroll into and so hands back the scrolling that
  /// [scrollEnabled] took away.
  ///
  /// The controller is unaffected, so `zoomIn`, `zoomOut` and `setChartScale`
  /// still work.
  final bool zoomEnabled;

  /// Opens the info dialog on tap as well as on long press.
  final bool isTapShowInfoDialog;

  /// Hides the background grid.
  final bool hideGrid;

  /// Draws the current price line and its countdown to the candle close.
  final bool showNowPrice;

  /// Enables the long-press info dialog.
  final bool showInfoDialog;

  /// Holds the price axis at one range instead of refitting it to the window.
  ///
  /// The axis fits whatever candles are on screen by default, so scrolling
  /// rescales it and every number on it changes as the window moves. Locked,
  /// it keeps the range it had when the lock took hold: the candles move under
  /// a scale that stays put, which is what reading a level off the axis while
  /// scrolling needs.
  ///
  /// The scale can still be dragged and zoomed, from the locked range rather
  /// than the window's, and `KChartController.resetPriceScale` hands the axis
  /// back to the chart — which refits it to the window and locks it there
  /// again.
  ///
  /// The range is held until it is reset, so a chart that switches to another
  /// instrument should reset it: a range from one instrument means nothing on
  /// another. Paging in history and live ticks need nothing, which is the
  /// point — they are what the lock is there to sit still through.
  final bool lockPriceScale;

  /// Widens a locked range rather than letting the newest candle fall off it.
  ///
  /// A locked axis holds the range it was given, so a market that trades past
  /// that range walks off the top or the bottom of the chart. With this set the
  /// range grows just enough to keep the newest candle on screen, and never
  /// shrinks back or refits to the window — so the axis still sits still while
  /// scrolling, which is what the lock is for.
  ///
  /// Only the newest candle counts, and only while it is in view. Scrolling
  /// back through history moves the window over candles the locked range need
  /// not cover, and growing the axis to swallow them would undo the lock a
  /// little at a time.
  ///
  /// Does nothing unless [lockPriceScale] is set.
  final bool lockedScaleFollowsPrice;

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

  /// Writes the prices the price axis and its readouts show, in place of the
  /// plain decimals [fixedLength] gives.
  ///
  /// Covers the axis labels, the crosshair's price label, the current-price tag
  /// and the signal tags — everywhere the chart says what a price is. Use it
  /// for a currency, a thousands separator, or a tick size the decimals alone
  /// do not carry.
  ///
  /// An axis that reads out a move rather than a price — [PriceAxisScale
  /// .percentage], [PriceAxisScale.indexedTo100] — writes that move itself and
  /// does not ask.
  final String Function(double price)? priceFormatter;

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

  /// Enables the drawing tools and their edit panel. Off by default.
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

  /// A second axis down the other side of the candles, reading the same prices
  /// another way — `PriceAxisScale.percentage` for the change since the oldest
  /// candle in view, next to the prices themselves.
  ///
  /// It marks its own round values rather than labelling the price axis's, so
  /// a percentage axis reads +2%, +4%, +6% and not whatever percentages the
  /// round prices happen to work out at. The grid stays ruled by the price
  /// axis: a second set of lines over one set of candles would say nothing the
  /// second set of labels does not.
  ///
  /// The crosshair, the current-price tag and the rest of the readouts follow
  /// [priceAxisScale]; the second axis is an axis, not a second voice for
  /// everything the chart says.
  ///
  /// `ChartStyle.secondaryPriceAxisWidth` is the gutter it is given, on the
  /// side [verticalTextAlignment] left free. Null — the default — leaves the
  /// chart with the one axis it has always had.
  final PriceAxisScale? secondaryPriceAxisScale;

  /// Whether dragging the price axis stretches it.
  ///
  /// The axis fits the window by default, so the candles always fill the
  /// height. Dragging up the strip the price labels sit in — its width is
  /// [ChartStyle.priceScaleGripWidth] — compresses the range and flattens the
  /// candles; dragging down stretches it. Once the scale is being held that
  /// way, a vertical drag anywhere on the candles slides the window up and
  /// down, and a double-tap on the axis hands it back to the chart. It is the
  /// [controller] that can do all three from code.
  ///
  /// Off, the axis always fits the window and a drag on the labels pans the
  /// chart like any other.
  final bool priceScaleDrag;

  /// Plays the candles back from a point in the past, one at a time.
  ///
  /// While one is replaying the chart draws only as far as
  /// [ChartReplayController.position] — candles, indicators, the now-price
  /// line and everything read out of them — so what is on screen is what was
  /// known at that moment. Drawings are left alone: a line placed on a candle
  /// still to arrive simply waits for it.
  ///
  /// Left null the chart always shows the whole series.
  final ChartReplayController? replay;

  /// Reads the candle out above the chart: date, open, high, low, close, the
  /// move over it and its volume.
  ///
  /// Follows the crosshair, falling back to the newest candle, and takes one
  /// legend row of its own above the indicator legends. Its wording comes from
  /// [chartTranslations].
  final bool showOhlcLegend;

  /// Empty space kept to the right of the newest candle.
  final double xFrontPadding;

  /// A watermark drawn faintly over the candle area — an `Image.asset`, an
  /// icon, a line of text, any widget.
  ///
  /// It is painted in one colour, [ChartColors.effectiveWatermarkColor], so a
  /// full-colour logo reads as a quiet silhouette; `ChartStyle.watermarkScale`
  /// sets its width and `ChartStyle.watermarkAlignment` where it sits. It takes
  /// no touches. Null — the default — draws none.
  final Widget? watermark;

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
  /// What the info dialog is reading out, or null when it has nothing to say.
  ///
  /// Broadcast on both counts that matter here. The dialog is only in the tree
  /// while [KChartWidget.showInfoDialog] is set, so its subscription comes and
  /// goes with that flag; a single-subscription stream refused the second
  /// listen and threw as the dialog was remounted. And delivery stays
  /// asynchronous, which a plain notifier would not be — the painter emits
  /// from inside paint, so telling the dialog synchronously would schedule a
  /// build during the frame.
  final StreamController<InfoWindowEntity?> mInfoWindowStream =
      StreamController<InfoWindowEntity?>.broadcast();

  /// The drawings the chart is painting, from the controller when there is one
  /// and from the per-kind lists otherwise.
  List<ChartLine> _drawings = const [];

  /// The drawing the editing toolbar is open on, when the chart is keeping
  /// track of that itself.
  ///
  /// With a [KChartWidget.drawingController] the selection lives there instead,
  /// so a drawing manager and the chart agree on what is selected.
  ChartLine? _localSelection;

  /// The drawings selected alongside [_selected], when there is no controller.
  final List<ChartLine> _localAlsoSelected = [];

  /// What the last copy put on the clipboard, when there is no controller.
  List<ChartLine> _localClipboard = const [];

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
      _localAlsoSelected.clear();
      return;
    }
    controller.select(line);
  }

  /// Every selected drawing, the one the editor is open on last.
  List<ChartLine> get _selection {
    final controller = widget.drawingController;
    if (controller != null) return controller.selection;
    return [..._localAlsoSelected, if (_localSelection case final v?) v];
  }

  /// Adds [line] to the selection, or takes it out if it is already in.
  ///
  /// What a shift- or ⌘-click does, so several drawings can be moved, restyled
  /// or deleted at once.
  void _toggleSelection(ChartLine line) {
    final controller = widget.drawingController;
    if (controller != null) {
      controller.toggleSelection(line);
      return;
    }

    if (identical(_localSelection, line)) {
      _localSelection = _localAlsoSelected.isEmpty
          ? null
          : _localAlsoSelected.removeLast();
      return;
    }
    if (_localAlsoSelected.any((candidate) => identical(candidate, line))) {
      _localAlsoSelected.removeWhere((candidate) => identical(candidate, line));
      return;
    }
    final was = _localSelection;
    if (was != null) _localAlsoSelected.add(was);
    _localSelection = line;
  }

  /// Selects every drawing on the chart.
  void _selectAll() {
    final drawings = _drawings.where((line) => !line.hidden).toList();
    if (drawings.isEmpty) return;

    final controller = widget.drawingController;
    if (controller != null) {
      controller.selectMany(drawings);
    } else {
      _localSelection = drawings.last;
      _localAlsoSelected
        ..clear()
        ..addAll(drawings.take(drawings.length - 1));
    }
    setState(() {});
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

  /// How far the price axis is stretched away from the window it would fit,
  /// and how far it is shifted; 1 and 0 hand the axis back to the chart.
  double _priceZoom = 1.0;
  double _pricePan = 0.0;

  /// The range a locked price axis is held at, or null while it is free.
  ///
  /// Taken from the axis as it was last fitted, so turning the lock on holds
  /// the chart exactly where the user was already looking.
  (double, double)? _lockedPriceRange;

  /// Whether the price axis is being held where the user put it.
  bool get _priceScaleIsManual => _priceZoom != 1.0 || _pricePan != 0.0;
  double mSelectX = 0.0;
  double mSelectY = 0.0;
  double mHeight = 0;
  double mWidth = 0;
  AnimationController? _controller;
  Animation<double>? aniX;
  Timer? _countdownTimer;

  late Offset _toolbarOffset;

  /// The height of each indicator pane, once the user has dragged one.
  ///
  /// Empty until then, and thrown away whenever the panes change, so a new
  /// indicator never inherits a height meant for a different one.
  List<double> _paneHeights = const [];

  /// True while a drag that began on the price labels is stretching the axis.
  bool _scalingPrice = false;

  /// When the price scale was last tapped, for spotting a double-tap.
  DateTime? _lastPriceScaleTap;

  /// When and where a drawing tap last landed, for spotting the double-tap
  /// that finishes an open-ended shape.
  ({DateTime at, Offset pos})? _lastDrawingTap;

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

  /// Where everything else in the selection started, so dragging one drawing
  /// of several carries the rest along with it.
  Map<ChartLine, List<({int index, double price})>> _dragOthers = const {};

  late ChartPainter painter;

  /// Whether [painter] has been built yet.
  ///
  /// It is `late` and assigned during build, so reading it before the first
  /// frame throws rather than answering. Everything reachable from outside the
  /// widget — the `KChartHost` members a controller calls — has to ask this
  /// first, because a caller can hold a controller before its chart has ever
  /// been laid out: two linked charts do exactly that, the first one's build
  /// asking the second where it is looking.
  bool _painterBuilt = false;

  /// Whether the chart has been laid out and can answer about its window.
  bool get _laidOut => _painterBuilt && painter.hasLayout;

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
    _syncCountdownTimer();
    _resolveIndicators();
    widget.drawingController?.addListener(_onDrawingsChanged);
    widget.replay?.addListener(_onReplayChanged);
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
      _dragOthers = const {};
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
  /// Whether the keyboard focus is in an editable text field.
  static bool get _isEditingText {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    return context.widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (!_isDrawing && !_isPreviewing) return false;
      _cancelDrawing();
      return true;
    }

    // A key typed into a text field — the editor's own label field, or any
    // field of the host app's — belongs to that field, not to the drawings.
    if (_isEditingText) return false;

    if (!widget.enableKeyboardShortcuts || !widget.isTrendLine) return false;

    if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_selection.every((line) => line.locked)) return false;
      _deleteSelected();
      return true;
    }

    if (!_isCommandPressed) return false;

    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final shift =
        keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight);

    // ⌘A selects everything drawn, and works with or without a controller.
    if (event.logicalKey == LogicalKeyboardKey.keyA) {
      if (_drawings.every((line) => line.hidden)) return false;
      _selectAll();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyC) {
      return copySelection();
    }
    if (event.logicalKey == LogicalKeyboardKey.keyV) {
      return pasteDrawings();
    }
    if (event.logicalKey == LogicalKeyboardKey.keyD) {
      return duplicateSelection();
    }

    final controller = widget.drawingController;
    if (controller == null) return false;

    if (event.logicalKey == LogicalKeyboardKey.keyZ) {
      return shift ? controller.redo() : controller.undo();
    }
    if (event.logicalKey == LogicalKeyboardKey.keyY) {
      return controller.redo();
    }
    // ⌘] and ⌘[ walk the stack, with shift going all the way.
    if (event.logicalKey == LogicalKeyboardKey.bracketRight) {
      return shift ? bringSelectionToFront() : bringSelectionForward();
    }
    if (event.logicalKey == LogicalKeyboardKey.bracketLeft) {
      return shift ? sendSelectionToBack() : sendSelectionBackward();
    }
    return false;
  }

  // ── Copying, pasting and restacking a selection ──────────────────────────

  /// Whether there is anything to [pasteDrawings].
  bool get canPasteDrawings =>
      widget.drawingController?.canPaste ?? _localClipboard.isNotEmpty;

  /// Copies every selected drawing, and reports whether there was one.
  ///
  /// With a controller the copies live on it, so a paste survives this chart
  /// being rebuilt; without one they are kept here.
  bool copySelection() {
    final selection = _selection;
    if (selection.isEmpty) return false;

    final controller = widget.drawingController;
    if (controller != null) {
      controller.copyToClipboard(selection);
    } else {
      _localClipboard = [for (final line in selection) copyDrawing(line)];
    }
    return true;
  }

  /// Pastes whatever was copied, nudged clear of the original, and reports
  /// whether there was anything to paste.
  bool pasteDrawings() {
    final controller = widget.drawingController;
    final pasted = controller != null
        ? controller.paste()
        : [for (final line in _localClipboard) copyDrawing(line)];
    if (pasted.isEmpty) return false;

    _nudge(pasted);
    if (controller == null) {
      _localAlsoSelected
        ..clear()
        ..addAll(pasted.take(pasted.length - 1));
      _localSelection = pasted.last;
    }
    for (final line in pasted) {
      _notifyLineChanged(line);
    }
    setState(() {});
    return true;
  }

  /// Copies every selected drawing in place, nudged clear of the original.
  ///
  /// The copies end up selected, so the next drag moves them rather than what
  /// they were copied from. Reports whether there was anything to duplicate.
  bool duplicateSelection() {
    final selection = _selection;
    if (selection.isEmpty) return false;

    final controller = widget.drawingController;
    final copies = controller != null
        ? controller.duplicate(selection)
        : [for (final line in selection) copyDrawing(line)];
    if (copies.isEmpty) return false;

    _nudge(copies);
    if (controller == null) {
      _localAlsoSelected
        ..clear()
        ..addAll(copies.take(copies.length - 1));
      _localSelection = copies.last;
    }
    for (final line in copies) {
      _notifyLineChanged(line);
    }
    setState(() {});
    return true;
  }

  /// Shifts [lines] a few candles on and a little down, so a copy lands beside
  /// what it was copied from rather than exactly on top of it.
  void _nudge(Iterable<ChartLine> lines) {
    final candles = _candlesInPlay;
    if (candles == null || candles.isEmpty) return;

    // A few candles across and a fraction of the visible range down: enough to
    // see and to grab, without moving the copy somewhere meaningless.
    const across = 3;
    final down =
        (painter.mMainRenderer.maxValue - painter.mMainRenderer.minValue) *
        0.03;

    for (final line in lines) {
      final anchors = _anchorsOf(line);
      if (anchors == null || anchors.isEmpty) continue;

      var highest = anchors.first.index;
      for (final anchor in anchors) {
        highest = math.max(highest, anchor.index);
      }
      // Nowhere to move to at the right-hand edge, so the copy goes left.
      final shift = highest + across < candles.length ? across : -across;

      _writeAnchors(line, [
        for (final anchor in anchors)
          (
            index: (anchor.index + shift).clamp(0, candles.length - 1),
            price: anchor.price - down,
          ),
      ], candles);
    }
  }

  /// Moves the selection to the top of the stack; reports whether it moved.
  bool bringSelectionToFront() =>
      _restackSelection((c, l) => c.bringToFront(l));

  /// Moves the selection to the bottom of the stack; reports whether it moved.
  ///
  /// Walked in reverse so a selection of several keeps its own order.
  bool sendSelectionToBack() =>
      _restackSelection((c, l) => c.sendToBack(l), reverse: true);

  /// Moves the selection one place up the stack; reports whether it moved.
  bool bringSelectionForward() =>
      _restackSelection((c, l) => c.bringForward(l), reverse: true);

  /// Moves the selection one place down the stack; reports whether it moved.
  bool sendSelectionBackward() =>
      _restackSelection((c, l) => c.sendBackward(l));

  /// Applies [move] to every selected drawing, and reports whether any moved.
  bool _restackSelection(
    bool Function(ChartDrawingController controller, ChartLine line) move, {
    bool reverse = false,
  }) {
    final controller = widget.drawingController;
    if (controller == null) return false;

    final selection = reverse ? _selection.reversed.toList() : _selection;
    if (selection.isEmpty) return false;

    var moved = false;
    for (final line in selection) {
      if (move(controller, line)) moved = true;
    }
    if (moved) setState(() {});
    return moved;
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

  /// Holds the indicator values between frames.
  ///
  /// A tick moves the newest candle and nothing else, so each indicator is given
  /// the chance to extend the series it already has rather than recompute the
  /// whole history — see [IndicatorCache].
  final IndicatorCache _indicatorCache = IndicatorCache();

  /// Turns the timestamp a drawing is anchored to back into a candle index.
  ///
  /// Kept for the chart's life so the lookup is built once per series rather
  /// than walked once per anchor per frame — see [CandleIndex].
  final CandleIndex _candleIndex = CandleIndex();

  /// Holds the chart's labels laid out between frames, for the same reason.
  final TextPainterCache _textCache = TextPainterCache();

  /// Bumped to redraw the crosshair layer on its own.
  ///
  /// A pointer moving over the chart changes only what that layer draws, so it
  /// is repainted directly rather than through `setState` — which would rebuild
  /// the whole chart and repaint every candle for a mouse move.
  final ValueNotifier<int> _crosshairRepaint = ValueNotifier<int>(0);

  /// Repaints the now-price, high/low and signal layer on its own, which is all
  /// the countdown ticking over needs.
  final ValueNotifier<int> _marksRepaint = ValueNotifier<int>(0);

  /// The cursor the last build handed the [MouseRegion].
  ///
  /// The cursor is chosen from where the pointer is, so moving between the
  /// chart, a pane edge and the price scale changes it — and that needs a
  /// rebuild, unlike the crosshair itself.
  MouseCursor _appliedCursor = MouseCursor.defer;

  /// Redraws the crosshair layer, without rebuilding the chart.
  ///
  /// The painter is kept and its pointer-driven fields are moved on in place,
  /// so the candles, the indicators and every label stay exactly as they were
  /// drawn — the only thing redrawn is the layer the crosshair lives on.
  void _repaintCrosshair() {
    if (!_painterBuilt) {
      notifyChanged();
      return;
    }

    // A cursor change is a rebuild, since the cursor is chosen in build.
    if (_hoverCursor != _appliedCursor) {
      notifyChanged();
      return;
    }

    painter
      ..selectX = mSelectX
      ..selectY = mSelectY
      ..isHovering = _isHovering
      ..isOnTap = isOnTap
      ..isLongPress = isLongPress
      ..suppressCrosshair = _isDrawing || isDraggingHandle;

    _crosshairRepaint.value++;
    _reportCrosshair();
    widget.controller?.hostChanged();
  }

  /// What the last resolution was computed from, so a rebuild that changes
  /// neither the candles nor the indicators reuses it.
  ({int length, Object? last, DateTime? time})? _resolvedFrom;

  /// The indicator instances the last resolution was computed from.
  ///
  /// Compared by identity rather than equality: two indicators of one kind with
  /// the same settings are equal whatever colours they carry, and a recolour
  /// still has to be redrawn.
  List<Indicator> _resolvedIndicators = const [];

  /// The compared instruments, lined up against the candles.
  List<ResolvedComparison> _resolvedComparisons = const [];

  /// The comparisons the last alignment was built from, compared by value so a
  /// host that rebuilds its list every frame is not realigned every frame.
  List<ComparisonSeries> _resolvedComparisonsFrom = const [];

  /// The events, lined up against the candles they mark.
  List<ResolvedEvent> _resolvedEvents = const [];

  /// The events the last alignment was built from, compared by value for the
  /// same reason.
  List<ChartEvent> _resolvedEventsFrom = const [];

  /// The candles the chart is actually drawing.
  ///
  /// The whole series, unless a replay is holding it at an earlier candle. The
  /// slice is cached: it is asked for several times a frame, and copying the
  /// list each time would cost more than the replay itself.
  List<KLineEntity>? get _candlesInPlay {
    final all = widget.candles;
    final replay = widget.replay;
    if (replay != null) replay.reportLength(all?.length ?? 0);
    if (all == null || replay == null || !replay.isActive) return all;

    final count = replay.position!.clamp(1, all.length);
    if (count >= all.length) return all;
    if (identical(_replaySource, all) && _replayCount == count) {
      return _replayView;
    }

    _replaySource = all;
    _replayCount = count;
    return _replayView = all.sublist(0, count);
  }

  List<KLineEntity>? _replaySource;
  List<KLineEntity>? _replayView;
  int? _replayCount;

  /// Repaints when the replay moves, and keeps it told how long the series is.
  void _onReplayChanged() {
    if (mounted) setState(() {});
  }

  ({int length, Object? last, DateTime? time}) get _candleFingerprint {
    final candles = _candlesInPlay;
    final last = candles == null || candles.isEmpty ? null : candles.last;
    return (
      length: candles?.length ?? 0,
      // Every price and the volume, not only the close: a trade at the same
      // price still moves the volume, and a wick that comes back moves the high.
      last: last == null
          ? null
          : (last.open, last.high, last.low, last.close, last.vol),
      time: last?.dateTime,
    );
  }

  void _resolveIndicators() {
    _resolved = resolveIndicators(
      widget.indicators,
      _candlesInPlay,
      cache: _indicatorCache,
    );
    _resolvedComparisons = resolveComparisons(
      _candlesInPlay ?? const [],
      widget.comparisons,
    );
    // Lining events up means handing over every candle's timestamp, which is a
    // list as long as the history — built afresh every time a tick moves the
    // newest candle. A chart with no events has nothing to line up.
    _resolvedEvents = widget.events.isEmpty
        ? const <ResolvedEvent>[]
        : resolveEvents([
            for (final candle in _candlesInPlay ?? const <KLineEntity>[])
              candle.dateTime,
          ], widget.events);
    _resolvedEventsFrom = List<ChartEvent>.of(widget.events);
    _resolvedFrom = _candleFingerprint;
    _resolvedIndicators = List<Indicator>.of(widget.indicators);
    _resolvedComparisonsFrom = List<ComparisonSeries>.of(widget.comparisons);
  }

  bool get _indicatorsAreStale {
    final current = widget.indicators;
    if (current.length != _resolvedIndicators.length) return true;
    for (var i = 0; i < current.length; i++) {
      if (!identical(current[i], _resolvedIndicators[i])) return true;
    }
    return _comparisonsAreStale;
  }

  bool get _comparisonsAreStale {
    final current = widget.comparisons;
    if (current.length != _resolvedComparisonsFrom.length) return true;
    for (var i = 0; i < current.length; i++) {
      // Compared by value, not by identity: a host that rebuilds its list every
      // frame would otherwise realign the whole series every frame too.
      if (current[i] != _resolvedComparisonsFrom[i]) return true;
    }
    return _eventsAreStale;
  }

  bool get _eventsAreStale {
    final current = widget.events;
    if (current.length != _resolvedEventsFrom.length) return true;
    for (var i = 0; i < current.length; i++) {
      if (current[i] != _resolvedEventsFrom[i]) return true;
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
    if (widget.showNowPrice && widget.timeFrame != null) {
      // Only the countdown moves, so only the layer it is drawn on repaints: a
      // rebuild here would draw every candle again once a second.
      _countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) _marksRepaint.value++;
      });
    } else {
      _countdownTimer?.cancel();
      _countdownTimer = null;
    }
  }

  @override
  void didUpdateWidget(covariant KChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showNowPrice != widget.showNowPrice ||
        (oldWidget.timeFrame == null) != (widget.timeFrame == null)) {
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
    if (oldWidget.replay != widget.replay) {
      oldWidget.replay?.removeListener(_onReplayChanged);
      widget.replay?.addListener(_onReplayChanged);
    }
    if (!identical(oldWidget.candles, widget.candles)) _resolveIndicators();
    if (oldWidget.lockPriceScale && !widget.lockPriceScale) {
      // Unlocked, the axis goes back to fitting the window.
      _lockedPriceRange = null;
    }
    if (oldWidget.currentDrawingTool != widget.currentDrawingTool) {
      // Picking a different tool abandons whatever the last one had started —
      // except an open-ended shape, which is finished rather than lost, since
      // disarming the tool is one of the two ways to say it is done. The
      // rebuild is already under way, so no setState here.
      if (_draft case MultiPointDrawing(pointCount: null)) {
        _finishOpenDraft();
      } else {
        _resetDraft();
      }
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    widget.drawingController?.removeListener(_onDrawingsChanged);
    widget.replay?.removeListener(_onReplayChanged);
    widget.controller?.detach(this);
    _countdownTimer?.cancel();
    mInfoWindowStream.close();
    _controller?.dispose();
    _crosshairRepaint.dispose();
    _marksRepaint.dispose();
    super.dispose();
  }

  ChartLine? _getSelectedLine() => _selected;

  void _deselectAll() {
    setState(() {
      _localAlsoSelected.clear();
      _selected = null;
      isDraggingHandle = false;
      draggingAnchor = null;
      _dragStart = null;
      _dragOrigin = null;
      _dragOthers = const {};
    });
  }

  /// Deletes every selected drawing, reporting each one.
  ///
  /// One undoable step when there is a controller, however many were selected,
  /// so undo puts the whole selection back rather than one drawing at a time.
  void _deleteSelected() {
    final selection = [
      for (final line in _selection)
        if (!line.locked) line,
    ];
    if (selection.isEmpty) return;

    widget.drawingController?.removeAll(selection);
    for (final line in selection) {
      widget.onRemoveDrawing?.call(line);
      if (line is HorizontalLine) widget.onRemoveHorizontalLine?.call(line);
      if (line is VerticalLine) widget.onRemoveVerticalLine?.call(line);
      if (line is TrendLine) widget.onRemoveTrendLine?.call(line);
      if (line is RectangleDrawing) widget.onRemoveRectangle?.call(line);
      if (line is FibRetracement) widget.onRemoveFibRetracement?.call(line);
    }
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
      _resolved.legendRowCount +
      (widget.showOhlcLegend ? 1 : 0) +
      // The comparisons read out on a row of their own.
      (widget.comparisons.isEmpty ? 0 : 1);

  /// Which side of each alerting level the market was last seen on, so one
  /// crossing is reported once.
  ///
  /// Keyed by the drawing and the level within it, because a retracement or a
  /// channel has several levels at once and each is crossed on its own.
  final Map<(AlertingDrawing, int), bool> _alertSides =
      <(AlertingDrawing, int), bool>{};

  /// The order being dragged, and the price the pointer is holding it at.
  ({ChartOrder order, double price})? _draggingOrder;

  /// The orders as drawn: the one being dragged moved to where it is held.
  ///
  /// So the line follows the finger before the host has said anything about the
  /// move, and snaps back if the host declines it.
  List<ChartOrder> get _ordersInPlay {
    final dragging = _draggingOrder;
    if (dragging == null) return widget.orders;
    return [
      for (final order in widget.orders)
        if (order.id == dragging.order.id)
          order.movedTo(dragging.price)
        else
          order,
    ];
  }

  /// Picks up the order under [pos], and reports whether there was one.
  bool _grabOrder(Offset pos) {
    if (widget.onOrderMoved == null || !painter.hasLayout) return false;

    final order = painter.orderAt(pos);
    if (order == null) return false;
    setState(() {
      _draggingOrder = (order: order, price: order.price);
    });
    return true;
  }

  /// Moves the order being dragged to the price under [pos].
  void _dragOrder(Offset pos) {
    final dragging = _draggingOrder;
    if (dragging == null) return;

    final price = painter.calculatePrice(pos.dy);
    setState(() {
      _draggingOrder = (order: dragging.order, price: price);
    });
    widget.onOrderDragged?.call(dragging.order, price);
  }

  /// Lets the dragged order go, reporting where it landed.
  void _releaseOrder() {
    final dragging = _draggingOrder;
    if (dragging == null) return;

    setState(() => _draggingOrder = null);
    // Only a move worth reporting: a press that went nowhere is a tap, and is
    // reported as one.
    if (dragging.price == dragging.order.price) {
      widget.onOrderTapped?.call(dragging.order);
      return;
    }
    widget.onOrderMoved?.call(dragging.order, dragging.price);
  }

  /// Reports a tap on an order or a position line, and whether there was one.
  bool _handleTradingTap(Offset pos) {
    if (!painter.hasLayout) return false;

    final order = painter.orderAt(pos);
    if (order != null && widget.onOrderTapped != null) {
      widget.onOrderTapped!.call(order);
      return true;
    }
    final position = painter.positionAt(pos);
    if (position != null && widget.onPositionTapped != null) {
      widget.onPositionTapped!.call(position);
      return true;
    }
    return false;
  }

  /// The window last reported through `onVisibleRangeChanged`.
  ChartVisibleRange? _reportedRange;

  /// Whether a report is already waiting for this frame to finish.
  bool _rangeReportPending = false;

  /// Which side of each indicator alert the value was last seen on.
  ///
  /// Keyed by the indicator and the alert, so several alerts on one indicator
  /// are each crossed on their own.
  final Map<(Indicator, IndicatorAlert), bool> _indicatorAlertSides =
      <(Indicator, IndicatorAlert), bool>{};

  /// Reports any indicator alert [last] has crossed.
  void _checkIndicatorAlerts(KLineEntity last) {
    final report = widget.onIndicatorAlert;
    final index = (_candlesInPlay?.length ?? 0) - 1;
    if (index < 0) return;

    final crossed = <(Indicator, IndicatorAlert, double)>[];
    final seen = <(Indicator, IndicatorAlert)>{};

    for (final resolved in [..._resolved.overlays, ..._resolved.panes]) {
      for (final alert in resolved.indicator.alerts) {
        final value = resolved.valueAt(alert.line, index);
        if (value == null || !value.isFinite) continue;

        final key = (resolved.indicator, alert);
        seen.add(key);
        final above = value >= alert.level;
        final before = _indicatorAlertSides[key];
        _indicatorAlertSides[key] = above;
        // The first sighting sets the side; only a change from it is a
        // crossing.
        if (before != null && before != above) {
          crossed.add((resolved.indicator, alert, value));
        }
      }
    }

    _indicatorAlertSides.removeWhere((key, _) => !seen.contains(key));
    if (report == null || crossed.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final (indicator, alert, value) in crossed) {
        report(indicator, alert, last, value);
      }
    });
  }

  /// Arranges for the window to be reported once this frame is painted.
  ///
  /// Which candles are in view is worked out while painting, so the range is not
  /// known until the frame is done — and a host that rebuilds in answer must not
  /// be asked to do so mid-build either. Both of which the post-frame callback
  /// takes care of.
  void _reportVisibleRange() {
    if (widget.onVisibleRangeChanged == null || _rangeReportPending) return;
    _rangeReportPending = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rangeReportPending = false;
      if (!mounted) return;

      final report = widget.onVisibleRangeChanged;
      final range = chartVisibleRange;
      // Only a range that is actually different: scrolling within one candle
      // moves the chart without changing what is on it.
      if (report == null || range == null || range == _reportedRange) return;
      _reportedRange = range;
      report(range);
    });
  }

  /// The candle last reported through `onCrosshairChanged`.
  int? _reportedCrosshair;

  /// Whether that report has been made at least once.
  ///
  /// Told apart from "reported null", so a chart that starts with no crosshair
  /// does not announce one going away that was never there.
  bool _crosshairEverReported = false;

  /// Whether a crosshair report is already waiting for this frame to finish.
  bool _crosshairReportPending = false;

  /// Reports where the crosshair has moved to.
  ///
  /// Left until the frame is done for the same two reasons as
  /// [_reportVisibleRange]: which candle is under it is worked out while
  /// painting, and a host that rebuilds in answer must not be asked to
  /// mid-build.
  void _reportCrosshair() {
    if (widget.onCrosshairChanged == null || _crosshairReportPending) return;
    _crosshairReportPending = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _crosshairReportPending = false;
      if (!mounted) return;

      final report = widget.onCrosshairChanged;
      if (report == null) return;

      final index = chartCrosshairIndex;
      // Sliding within one candle moves the crosshair without changing what it
      // is pointing at.
      if (_crosshairEverReported && index == _reportedCrosshair) return;
      _crosshairEverReported = true;
      _reportedCrosshair = index;
      report(index);
    });
  }

  /// Reports any alerting level the newest candle has crossed.
  ///
  /// Called from build, so the report itself is left until the frame is done: a
  /// host that rebuilds in answer to it must not be asked to do so mid-build.
  void _checkAlerts() {
    final candles = _candlesInPlay;
    if (candles == null || candles.isEmpty) return;

    final last = candles.last;
    final at = last.dateTime;
    if (at == null) return;

    final crossed = <(AlertingDrawing, double)>[];

    // Sweeping the drawings costs a list and a set, and this runs on every
    // build — every hover, every frame of a pan. A chart with nothing armed
    // gets neither. The sides already recorded matter too: they have to be
    // cleared when the drawing that set them is disarmed or deleted.
    final armed = _drawings.any(
      (line) => line is AlertingDrawing && line.alert,
    );
    if (armed || _alertSides.isNotEmpty) {
      final seen = <(AlertingDrawing, int)>{};

      for (final line in _drawings.whereType<AlertingDrawing>()) {
        if (!line.alert) continue;

        final levels = line.alertLevelsAt(at);
        for (final (index, level) in levels.indexed) {
          final key = (line, index);
          seen.add(key);

          final above = last.close >= level;
          final before = _alertSides[key];
          _alertSides[key] = above;
          // The first sighting sets the side; only a change from it is a
          // crossing.
          if (before != null && before != above) crossed.add((line, level));
        }
      }

      _alertSides.removeWhere((key, _) => !seen.contains(key));
    }

    _checkIndicatorAlerts(last);

    final reportLevel = widget.onAlertCrossed;
    final reportDrawing = widget.onDrawingAlert;
    if (crossed.isEmpty) return;
    if (reportLevel == null && reportDrawing == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final (line, level) in crossed) {
        // A horizontal level reports through both, so an app written against
        // the older callback carries on working unchanged.
        if (line is HorizontalLine) reportLevel?.call(line, last);
        reportDrawing?.call(line, last, level);
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
    if (_candlesInPlay != null && _candlesInPlay!.isEmpty) {
      mScrollX = mSelectX = 0.0;
      mScaleX = 1.0;
    }

    _refreshIndicatorsIfStale();
    _collectDrawings();
    _checkAlerts();
    _reportVisibleRange();
    _reportCrosshair();

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

        // Taken from the axis as it stands, which is last frame's fit: this
        // runs before the painter for this frame is made, so the range
        // captured is the one the user is already looking at. Held in a field
        // rather than pushed through setState because it is read straight
        // away, by the painter built just below.
        if (!widget.lockPriceScale) {
          _lockedPriceRange = null;
        } else if (_lockedPriceRange == null && _laidOut) {
          final min = painter.mMainMinValue;
          final max = painter.mMainMaxValue;
          if (min.isFinite && max.isFinite && max > min) {
            _lockedPriceRange = (min, max);
          }
        } else if (widget.lockedScaleFollowsPrice &&
            _lockedPriceRange != null) {
          _lockedPriceRange = _rangeFollowingPrice(_lockedPriceRange!);
        }

        _painterBuilt = true;
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
          candles: _candlesInPlay,
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
          comparisons: _resolvedComparisons,
          events: _resolvedEvents,
          orders: _ordersInPlay,
          openPositions: widget.positions,
          volHidden: widget.volHidden,
          // "Drawn as a line" is what this decides — whether the high-low
          // extremes are marked, and whether the overlays and their legends
          // have anything to sit over. An HLC area and a column chart both
          // show a range per bar, so they are not lines for that purpose.
          isLine: switch (_chartType) {
            ChartType.line ||
            ChartType.area ||
            ChartType.baseline ||
            ChartType.stepLine => true,
            ChartType.candles ||
            ChartType.bars ||
            ChartType.hlcArea ||
            ChartType.columns => false,
          },
          chartType: _chartType,
          baselinePrice: widget.baselinePrice,
          session: widget.session,
          candleColor: widget.candleColor,
          invertPriceAxis: widget.invertPriceAxis,
          showAverageClose: widget.showAverageClose,
          showHighLowOnAxis: widget.showHighLowOnAxis,
          timeZoneOffset: widget.timeZoneOffset,
          highlightedPane: _reorderingPane,
          hideGrid: widget.hideGrid,
          showNowPrice: widget.showNowPrice,
          fixedLength: widget.fixedLength,
          verticalTextAlignment: widget.verticalTextAlignment,
          dateFormatter: widget.dateFormatter,
          priceFormatter: widget.priceFormatter,
          draftLine: _draft,
          selectedLine: _selected,
          selectedLines: _selection,
          drawingStyle: widget.drawingStyle,
          chartTranslations: widget.chartTranslations,
          showOhlcLegend: widget.showOhlcLegend,
          priceAxisScale: widget.priceAxisScale,
          secondaryPriceAxisScale: widget.secondaryPriceAxisScale,
          priceZoom: _priceZoom,
          pricePan: _pricePan,
          fixedPriceMin: _lockedPriceRange?.$1,
          fixedPriceMax: _lockedPriceRange?.$2,
          candleIndex: _candleIndex,
          textCache: _textCache,
        );
        painter.marksOnOwnLayer = true;

        return Stack(
          children: [
            MouseRegion(
              opaque: false,
              cursor: _appliedCursor = _hoverCursor,
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
                  onSecondaryTapUp: (details) => _openContextMenu(
                    details.localPosition,
                    details.globalPosition,
                  ),
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

                    if (_handlePriceScaleTap(pos)) {
                      notifyChanged();
                      return;
                    }

                    // An event badge sits below the candles and is a small
                    // target, so it is offered the tap before anything else
                    // reads it as a selection or a drawing point.
                    if (_handleEventTap(pos)) return;
                    if (widget.currentDrawingTool == DrawingTool.none &&
                        _handleTradingTap(pos)) {
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
                      // Only the crosshair follows the finger, so only its
                      // layer is redrawn, the same as for a hovering mouse.
                      mSelectX = details.localPosition.dx;
                      mSelectY = details.localPosition.dy;
                      _repaintCrosshair();
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
                      // A drag that begins on the price labels stretches the
                      // axis instead of scrolling the chart.
                      if (_isOnPriceScale(pressed)) {
                        _scalingPrice = true;
                        return;
                      }
                      // One that begins on a working order's line moves the
                      // order, which is how it is amended from the chart.
                      if (_grabOrder(pressed)) return;
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
                    if (_scalingPrice) {
                      _zoomPriceScale(details.focalPointDelta.dy);
                      return;
                    }
                    if (_draggingOrder != null) {
                      _dragOrder(details.localFocalPoint);
                      return;
                    }

                    if (details.scale != 1.0) {
                      // Zoom. A pinch on a chart that cannot be zoomed is not
                      // a scroll either, so it is dropped rather than falling
                      // through to the pan below.
                      if (!widget.zoomEnabled) return;
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
                      if (widget.scrollEnabled) {
                        mScrollX += details.focalPointDelta.dx / mScaleX;
                        mScrollX = mScrollX.clamp(
                          0.0,
                          BaseChartPainter.maxScrollX,
                        );
                        _maybeLoadMore();
                      }
                      // Only once the axis is already being held: while it
                      // fits the window there is nothing to slide.
                      if (widget.priceScaleDrag && _priceScaleIsManual) {
                        _panPriceScale(details.focalPointDelta.dy);
                      }
                      notifyChanged();
                    }
                  },
                  onScaleEnd: (details) {
                    if (_scalingPrice) {
                      _scalingPrice = false;
                      return;
                    }
                    if (_draggingOrder != null) {
                      _releaseOrder();
                      return;
                    }
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

                    if (!_isDrawing &&
                        !isDraggingHandle &&
                        widget.scrollEnabled) {
                      final velocity = details.velocity.pixelsPerSecond.dx;
                      _onFling(velocity);
                    } else {
                      _onDragChanged(false);
                    }

                    notifyChanged();
                  },
                  child: Stack(
                    children: [
                      // Two layers, each behind its own boundary: the chart,
                      // which only has to be drawn again when what it is drawn
                      // from changes, and the crosshair over it, which follows
                      // the pointer. A mouse moving across the chart repaints
                      // the second and leaves the first alone.
                      RepaintBoundary(
                        key: _paintKey,
                        child: Stack(
                          children: [
                            RepaintBoundary(
                              child: CustomPaint(
                                size: Size.fromHeight(
                                  baseDimension.mDisplayHeight,
                                ),
                                painter: painter,
                              ),
                            ),
                            // The now-price, high/low and signal marks, apart
                            // so the countdown can tick without the candles
                            // under it being drawn again.
                            RepaintBoundary(
                              child: CustomPaint(
                                size: Size.fromHeight(
                                  baseDimension.mDisplayHeight,
                                ),
                                painter: ChartMarksPainter(
                                  painter,
                                  repaint: _marksRepaint,
                                ),
                              ),
                            ),
                            if (widget.watermark case final watermark?)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: RepaintBoundary(
                                    child: CustomSingleChildLayout(
                                      delegate: _WatermarkLayout(painter),
                                      child: ColorFiltered(
                                        colorFilter: ColorFilter.mode(
                                          widget
                                              .chartColors
                                              .effectiveWatermarkColor,
                                          BlendMode.srcIn,
                                        ),
                                        child: watermark,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            RepaintBoundary(
                              child: CustomPaint(
                                size: Size.fromHeight(
                                  baseDimension.mDisplayHeight,
                                ),
                                painter: ChartOverlayPainter(
                                  painter,
                                  repaint: _crosshairRepaint,
                                ),
                              ),
                            ),
                          ],
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
            if (widget.zoomEnabled &&
                (kIsWeb ||
                    (defaultTargetPlatform != TargetPlatform.iOS &&
                        defaultTargetPlatform != TargetPlatform.android)))
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
    if (_isOnPriceScale(at)) return SystemMouseCursors.resizeUpDown;
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
    _lastDrawingTap = null;
  }

  /// Whether the tap at [pos] repeats the last one — same place, soon after.
  ///
  /// Recognised by hand rather than with [GestureDetector.onDoubleTap], which
  /// would hold every other tap on the chart back until it knew no second one
  /// was coming. Place matters as much as timing: tapping along a path lands
  /// leg after leg however fast it is done, and only tapping twice in the one
  /// spot says the shape is finished — within a finger's width of it, which is
  /// what [kDoubleTapTouchSlop] measures.
  bool _isRepeatTap(Offset pos) {
    final last = _lastDrawingTap;
    _lastDrawingTap = (at: DateTime.now(), pos: pos);
    if (last == null) return false;
    if ((pos - last.pos).distance > kDoubleTapTouchSlop) return false;
    if (DateTime.now().difference(last.at) > kDoubleTapTimeout) return false;
    _lastDrawingTap = null;
    return true;
  }

  /// Finishes a shape that takes as many points as it is given.
  ///
  /// The last anchor is the one that was following the pointer, so it is
  /// dropped rather than kept: it lands where the finishing tap did, on top of
  /// the leg just placed. A shape left with too little to draw is thrown away.
  void _finishOpenDraft() {
    if (_draft case MultiPointDrawing shape) {
      if (shape.points.length > shape.minimumPoints) shape.points.removeLast();
      if (!shape.isComplete) {
        _cancelDrawing();
        return;
      }
      _commitDraft();
      return;
    }
    _cancelDrawing();
  }

  // ── Placing a new line ───────────────────────────────────────────────────

  /// Where on the chart [pos] anchors a drawing, or null when it is off the
  /// data.
  ///
  /// Points land on candles, so a line drawn today sits on the same candles
  /// tomorrow. With [KChartWidget.magnetMode] on, the price snaps to a nearby
  /// open, high, low or close as well.
  ({DateTime time, double price})? _anchorAt(Offset pos) {
    final candles = _candlesInPlay;
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
      DrawingTool.flag => FlagDrawing(time: anchor.time, price: anchor.price),
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
      DrawingTool.pitchfork => PitchforkDrawing(
        time1: anchor.time,
        price1: anchor.price,
        fillOpacity: style.channelFillOpacity,
      ),
      DrawingTool.gannFan => GannFan(time1: anchor.time, price1: anchor.price),
      DrawingTool.gannBox => GannBox(
        time1: anchor.time,
        price1: anchor.price,
        fillOpacity: style.shapeFillOpacity / 2,
      ),
      DrawingTool.fibExtension => FibExtension(
        time1: anchor.time,
        price1: anchor.price,
      ),
      DrawingTool.fibFan => FibFan(time1: anchor.time, price1: anchor.price),
      DrawingTool.fibTimeZones => FibTimeZones(
        time1: anchor.time,
        price1: anchor.price,
      ),
      DrawingTool.regressionTrend => RegressionChannel(
        time1: anchor.time,
        price1: anchor.price,
        fillOpacity: style.channelFillOpacity,
      ),
      DrawingTool.priceRange => PriceRangeDrawing(
        time1: anchor.time,
        price1: anchor.price,
        fillOpacity: style.measureFillOpacity,
      ),
      DrawingTool.dateRange => DateRangeDrawing(
        time1: anchor.time,
        price1: anchor.price,
        fillOpacity: style.measureFillOpacity,
      ),
      DrawingTool.callout => CalloutDrawing(
        time1: anchor.time,
        price1: anchor.price,
      ),
      // A multi-point shape starts with its first anchor landed and a second
      // one following the pointer, so it rubber-bands like every other shape.
      DrawingTool.xabcd => XabcdDrawing(
        points: [
          (time: anchor.time, price: anchor.price),
          (time: anchor.time, price: anchor.price),
        ],
        fillOpacity: style.shapeFillOpacity,
      ),
      DrawingTool.path => PathDrawing(
        points: [
          (time: anchor.time, price: anchor.price),
          (time: anchor.time, price: anchor.price),
        ],
        fillOpacity: style.shapeFillOpacity,
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
      case MultiPointDrawing shape:
        // Only the last anchor follows the pointer; the ones already tapped
        // stay where they were put.
        shape.moveLastTo((time: anchor.time, price: anchor.price));
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
    // A path is complete from its second point on but still takes more, so it
    // is finished by the user rather than by counting.
    if (draft is MultiPointDrawing) {
      return !draft.isComplete || draft.pointCount == null;
    }
    return false;
  }

  /// Hands the finished drawing to the host and leaves it selected, the way
  /// the editing toolbar expects to find it.
  void _commitDraft() {
    final draft = _draft;
    if (draft == null) return;
    // An open-ended shape is never "not incomplete", so it is judged on
    // whether it has enough points instead.
    if (draft is MultiPointDrawing) {
      if (!draft.isComplete) return;
    } else if (_draftIsIncomplete) {
      return;
    }

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
      // A second tap in the same place finishes an open-ended shape, which is
      // the only way a path knows it has all the legs it is getting.
      if (_draft case MultiPointDrawing(
        pointCount: null,
      ) when _isRepeatTap(pos)) {
        _finishOpenDraft();
        return;
      }
      _extendDraft(pos);
      // A multi-point shape lands the anchor the pointer was carrying and
      // starts another one, rather than finishing on the second tap.
      if (_draft case MultiPointDrawing shape) {
        if (shape.acceptsMorePoints) {
          shape.addPoint(shape.points.last);
          notifyChanged();
          return;
        }
        _commitDraft();
        return;
      }
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
    _repaintCrosshair();
  }

  void _clearHoverCrosshair() {
    if (!_isHovering) return;
    _isHovering = false;
    _closeInfoWindow();
    _repaintCrosshair();
  }

  void _trySelectLine(Offset pos) {
    isDraggingHandle = false;
    draggingAnchor = null;

    final candles = _candlesInPlay;
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
      // Shift or ⌘ adds to the selection instead of replacing it, so several
      // drawings can be moved, restyled or deleted together.
      if (_isSelectionModifierPressed) {
        setState(() => _toggleSelection(line));
        return;
      }
      _select(pos, line, anchor: anchor);
      return;
    }

    // A modifier-click on empty space keeps whatever was selected: it was
    // meant to add to a selection, not to throw one away.
    if (!_isSelectionModifierPressed) _deselectAll();
  }

  /// Whether a key that means "add to the selection" is down.
  bool get _isSelectionModifierPressed {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight) ||
        _isCommandPressed;
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

      case FlagDrawing():
        // The flag flies above the point it is planted on, so the whole staff
        // and pennant answer, not just the foot.
        final foot = _canvasPoint(line.time, line.price);
        if (foot == null) return null;
        final top = foot.translate(0, -line.staffHeight);
        return _distanceToSegment(pos, foot, top) <
                math.max(tolerance, handleTolerance)
            ? 0
            : null;

      case FreehandDrawing():
        return _hitFreehand(pos, line, tolerance) ? 0 : null;

      case MultiPointDrawing():
        return _hitMultiPoint(pos, line);

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

  /// Which part of [shape] is under [pos]: the anchor's place in the list
  /// counting from one, 0 for one of its legs, or null when the tap missed it.
  int? _hitMultiPoint(Offset pos, MultiPointDrawing shape) {
    final tolerance = widget.drawingStyle.hitTestTolerance;
    final handleTolerance = widget.drawingStyle.handleHitTestTolerance;

    final points = <Offset?>[
      for (final point in shape.points) _canvasPoint(point.time, point.price),
    ];

    ({int anchor, double distance})? nearest;
    for (var i = 0; i < points.length; i++) {
      final at = points[i];
      if (at == null) continue;
      final distance = (pos - at).distance;
      if (distance >= handleTolerance) continue;
      if (nearest == null || distance < nearest.distance) {
        nearest = (anchor: i + 1, distance: distance);
      }
    }
    if (nearest != null) return nearest.anchor;

    // Every leg in turn, and the closing one where the shape is closed: a tap
    // inside a polygon does not pick it up, only one on an edge.
    final legs = <(Offset, Offset)>[];
    for (var i = 1; i < points.length; i++) {
      final from = points[i - 1];
      final to = points[i];
      if (from != null && to != null) legs.add((from, to));
    }
    final closes = switch (shape) {
      PathDrawing(:final closed) => closed,
      XabcdDrawing() => true,
      _ => false,
    };
    if (closes && points.length > 2) {
      final first = points.first;
      final last = points.last;
      if (first != null && last != null) legs.add((last, first));
    }
    // A harmonic pattern is read as the two triangles XAB and BCD, so those
    // chords are part of it too.
    if (shape is XabcdDrawing && points.length >= 3) {
      void chord(int from, int to) {
        if (from >= points.length || to >= points.length) return;
        final a = points[from];
        final b = points[to];
        if (a != null && b != null) legs.add((a, b));
      }

      chord(0, 2);
      chord(2, 4);
    }

    return legs.any(
          (leg) => _distanceToSegment(pos, leg.$1, leg.$2) < tolerance,
        )
        ? 0
        : null;
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

      case GannBox box:
        final rect = Rect.fromPoints(p1, p2);
        if (_hitRectEdges(pos, rect, tolerance)) return true;
        final rules = gannBoxRules(rect, box.ratios);
        if (rules.horizontals.any((y) => (pos.dy - y).abs() < tolerance)) {
          return rect.left - tolerance <= pos.dx &&
              pos.dx <= rect.right + tolerance;
        }
        if (rules.verticals.any((x) => (pos.dx - x).abs() < tolerance)) {
          return rect.top - tolerance <= pos.dy &&
              pos.dy <= rect.bottom + tolerance;
        }
        return box.showDiagonals &&
            (_distanceToSegment(pos, rect.topLeft, rect.bottomRight) <
                    tolerance ||
                _distanceToSegment(pos, rect.bottomLeft, rect.topRight) <
                    tolerance);

      case GannFan fan:
        final size = Size(mWidth, mHeight);
        return fan.ratios.any((ratio) {
          final through = gannRayThrough(p1, p2, ratio);
          if (through == p1) return false;
          return _distanceToSegment(
                pos,
                p1,
                painter.extendPoint(p1, through, size),
              ) <
              tolerance;
        });

      case FibFan fan:
        final size = Size(mWidth, mHeight);
        return fan.levels.any((level) {
          final through = fibFanRayThrough(p1, p2, level);
          if (through == p1) return false;
          return _distanceToSegment(
                pos,
                p1,
                painter.extendPoint(p1, through, size),
              ) <
              tolerance;
        });

      case FibTimeZones zones:
        return zones.levels.any(
          (level) => (pos.dx - fibTimeZoneX(p1, p2, level)).abs() < tolerance,
        );

      case FibExtension extension:
        if (p3 == null) return _distanceToSegment(pos, p1, p2) < tolerance;
        if (pos.dx < math.min(p1.dx, p3.dx) - tolerance) return false;
        return extension.levels.any((ratio) {
          final price = extension.priceAt(ratio);
          return price != null &&
              (pos.dy - painter.getMainY(price)).abs() < tolerance;
        });

      case PitchforkDrawing fork:
        if (p3 == null) return _distanceToSegment(pos, p1, p2) < tolerance;
        final size = Size(mWidth, mHeight);
        final geometry = pitchforkGeometry(p1, p2, p3, fork.kind, fork.levels);
        final run = geometry.median - geometry.handle;
        for (final tine in geometry.tines) {
          for (final start in [tine.upper, tine.lower]) {
            final from = tine.level == 0 ? geometry.handle : start;
            final to = from + run;
            if (from == to) continue;
            if (_distanceToSegment(
                  pos,
                  from,
                  painter.extendPoint(from, to, size),
                ) <
                tolerance) {
              return true;
            }
          }
        }
        return false;

      case RegressionChannel regression:
        final fit = _regressionFit(regression);
        if (fit == null) return _distanceToSegment(pos, p1, p2) < tolerance;
        final size = Size(mWidth, mHeight);
        final left = Offset(p1.dx, painter.getMainY(fit.startPrice));
        final right = Offset(p2.dx, painter.getMainY(fit.endPrice));
        final band = regression.showBands
            ? [-regression.deviations, 0.0, regression.deviations]
            : [0.0];
        return band.any((multiple) {
          final shift = multiple * fit.deviation;
          final from = Offset(
            left.dx,
            painter.getMainY(fit.startPrice + shift),
          );
          final to = Offset(right.dx, painter.getMainY(fit.endPrice + shift));
          final end = regression.extend
              ? painter.extendPoint(from, to, size)
              : to;
          return _distanceToSegment(pos, from, end) < tolerance;
        });

      case PriceRangeDrawing():
        final rect = Rect.fromPoints(p1, p2);
        return (pos.dy - rect.top).abs() < tolerance ||
            (pos.dy - rect.bottom).abs() < tolerance ||
            _distanceToSegment(
                  pos,
                  Offset(rect.center.dx, rect.top),
                  Offset(rect.center.dx, rect.bottom),
                ) <
                tolerance;

      case DateRangeDrawing():
        final rect = Rect.fromPoints(p1, p2);
        return (pos.dx - rect.left).abs() < tolerance ||
            (pos.dx - rect.right).abs() < tolerance ||
            _distanceToSegment(
                  pos,
                  Offset(rect.left, rect.center.dy),
                  Offset(rect.right, rect.center.dy),
                ) <
                tolerance;

      case TwoPointDrawing():
        return _distanceToSegment(pos, p1, p2) < tolerance;
    }
  }

  /// The least-squares fit [regression] describes, or null when its anchors no
  /// longer sit on candles that are loaded.
  RegressionFit? _regressionFit(RegressionChannel regression) {
    final candles = _candlesInPlay;
    final end = regression.time2;
    if (candles == null || end == null) return null;

    final from = candles.indexWhere((e) => e.dateTime == regression.time1);
    final to = candles.indexWhere((e) => e.dateTime == end);
    if (from == -1 || to == -1) return null;
    return fitRegression(candles, from, to);
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
    final candles = _candlesInPlay;
    if (candles == null) return null;
    final index = candles.indexWhere((e) => e.dateTime == time);
    if (index == -1) return null;
    return painter.translateXtoX(painter.getX(index));
  }

  /// Where an anchor sits on the canvas, or null when its candle is gone.
  Offset? _canvasPoint(DateTime? time, double? price) {
    final candles = _candlesInPlay;
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
    final candles = _candlesInPlay;
    if (candles == null || candles.isEmpty) return;

    _dragStart = (
      index: painter.calculateSelectedX(pos.dx),
      price: painter.calculatePrice(pos.dy),
    );
    _dragOrigin = _anchorsOf(_selected);
    // Where every other selected drawing started, so dragging one of a
    // selection carries the rest along with it.
    final others = <ChartLine, List<({int index, double price})>>{};
    for (final line in _selection) {
      if (identical(line, _selected) || line.locked) continue;
      final anchors = _anchorsOf(line);
      if (anchors != null && anchors.isNotEmpty) others[line] = anchors;
    }
    _dragOthers = others;
  }

  /// Every anchor of [line], as candle indices and prices.
  ///
  /// This is what a whole-shape drag shifts: one list, whether the drawing has
  /// two anchors, three, or a hundred points of freehand.
  List<({int index, double price})>? _anchorsOf(ChartLine? line) {
    final candles = _candlesInPlay;
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
      case MultiPointDrawing shape:
        final anchors = <({int index, double price})>[];
        for (final point in shape.points) {
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
      case MultiPointDrawing shape:
        final moved = <DrawingPoint>[];
        for (final anchor in anchors) {
          final time = timeAt(anchor.index);
          if (time == null) return;
          moved.add((time: time, price: anchor.price));
        }
        shape.points = moved;
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
    final candles = _candlesInPlay;
    final line = _getSelectedLine();
    if (candles == null || candles.isEmpty || line == null || line.locked) {
      return;
    }

    final index = painter.calculateSelectedX(pos.dx);
    if (index < 0 || index >= candles.length) return;
    final time = candles[index].dateTime;
    if (time == null) return;
    final price = painter.calculatePrice(pos.dy);

    // Magnet mode snaps an anchor being placed onto a nearby open, high, low
    // or close — which is most of the point of dragging one. A drag of a whole
    // drawing keeps the raw price: it moves by the distance the pointer has
    // travelled since `_beginHandleDrag` recorded it, and snapping one end of
    // that measurement would jump the shape by the difference.
    final snapped = widget.magnetMode
        ? _magnetPrice(candles[index], pos.dy, price)
        : price;

    switch (line) {
      case HorizontalLine():
        // A title the user never customised tracks the price it was named for.
        if (line.title == line.price.toStringAsFixed(widget.fixedLength)) {
          line.title = snapped.toStringAsFixed(widget.fixedLength);
        }
        line.price = snapped;
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
          ..price = snapped;
      case FreehandDrawing():
        _dragWholeDrawing(line, candles, index, price);
      case MultiPointDrawing shape:
        // Anchors are numbered from one, so anchor 0 means the body was
        // grabbed and the whole shape moves.
        final anchor = draggingAnchor;
        if (anchor == null || anchor == 0 || anchor > shape.points.length) {
          _dragWholeDrawing(line, candles, index, price);
        } else {
          shape.points[anchor - 1] = (time: time, price: snapped);
        }
      case TwoPointDrawing():
        _dragShape(line, candles, index, time, price, snapped);
    }
    notifyChanged();
  }

  /// Drags one anchor of [shape], or the whole shape when the grab landed on
  /// its body.
  /// [price] is where the pointer is; [snapped] is that price pulled onto a
  /// nearby candle value under magnet mode. An anchor takes the snapped one, a
  /// whole-shape move the raw one — see [_applyHandleDrag].
  void _dragShape(
    TwoPointDrawing shape,
    List<KLineEntity> candles,
    int index,
    DateTime time,
    double price,
    double snapped,
  ) {
    switch (draggingAnchor) {
      case 1:
        shape
          ..time1 = time
          ..price1 = snapped;
      case 2:
        shape
          ..time2 = time
          ..price2 = snapped;
      case 3:
        if (shape is! ThreePointDrawing) return;
        shape
          ..time3 = time
          ..price3 = snapped;
      case 0:
        _dragWholeDrawing(shape, candles, index, price);
    }
  }

  /// Shifts every anchor of [line] — and of anything else selected with it — by
  /// the same number of candles and the same amount of price.
  ///
  /// Stops once any of them reaches the edge of the data, so a selection keeps
  /// its shape rather than bunching up against the end.
  void _dragWholeDrawing(
    ChartLine line,
    List<KLineEntity> candles,
    int index,
    double price,
  ) {
    final start = _dragStart;
    final origin = _dragOrigin;
    if (start == null || origin == null || origin.isEmpty) return;

    final moving = <ChartLine, List<({int index, double price})>>{
      line: origin,
      ..._dragOthers,
    };

    var lowest = origin.first.index;
    var highest = origin.first.index;
    for (final anchors in moving.values) {
      for (final anchor in anchors) {
        lowest = math.min(lowest, anchor.index);
        highest = math.max(highest, anchor.index);
      }
    }

    final shift = (index - start.index).clamp(
      -lowest,
      candles.length - 1 - highest,
    );
    final priceShift = price - start.price;

    for (final entry in moving.entries) {
      _writeAnchors(entry.key, [
        for (final anchor in entry.value)
          (index: anchor.index + shift, price: anchor.price + priceShift),
      ], candles);
    }
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

  /// A fresh controller for a scroll animation, disposing the one it replaces.
  ///
  /// Every fling and every animated scroll gets its own, and without this the
  /// old ones — each holding a ticker — would pile up for the life of the chart.
  AnimationController _replaceScrollController() {
    _controller?.dispose();
    return _controller = AnimationController(
      duration: Duration(milliseconds: widget.flingTime),
      vsync: this,
    );
  }

  void _onFling(double velocity) {
    _controller = _replaceScrollController();
    aniX =
        Tween<double>(
          begin: mScrollX,
          end: velocity * widget.flingRatio + mScrollX,
        ).animate(
          CurvedAnimation(parent: _controller!.view, curve: widget.flingCurve),
        );

    aniX!.addListener(() {
      mScrollX = aniX!.value.clamp(0.0, BaseChartPainter.maxScrollX);
      _maybeLoadMore();
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

  /// Which edge [onLoadMore] has already been told about, so it is asked once
  /// per arrival rather than on every frame the drag spends pinned there.
  ///
  /// Cleared as soon as the chart comes away from that edge, so scrolling back
  /// out and in asks again.
  bool? _loadMoreEdgeNotified;

  /// Asks the host to page in more candles when the scroll lands on an edge.
  ///
  /// `mScrollX` is clamped to `[0, maxScrollX]`, so those two bounds *are* the
  /// edges: 0 is the newest candle and `maxScrollX` the oldest. The flag
  /// [KChartWidget.onLoadMore] is given follows that — true at the right.
  void _maybeLoadMore() {
    final callback = widget.onLoadMore;
    if (callback == null) return;

    // Nothing to page towards until the data has been laid out at least once;
    // before that both bounds are 0 and every edge looks like both edges.
    final maxScroll = BaseChartPainter.maxScrollX;
    if (maxScroll <= 0) return;

    final bool? edge = switch (mScrollX) {
      <= 0.0 => true,
      _ when mScrollX >= maxScroll => false,
      _ => null,
    };

    if (edge == null) {
      _loadMoreEdgeNotified = null;
      return;
    }
    if (_loadMoreEdgeNotified == edge) return;
    _loadMoreEdgeNotified = edge;
    callback(edge);
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

    final controller = _replaceScrollController();
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
  double get chartPriceZoom => _priceZoom;

  @override
  void setChartPriceZoom(double zoom) {
    final clamped = zoom.clamp(0.2, 10.0);
    if (clamped == _priceZoom) return;
    setState(() => _priceZoom = clamped);
    widget.controller?.hostChanged();
  }

  @override
  void resetChartPriceScale() {
    resetPriceScale();
    widget.controller?.hostChanged();
  }

  // ── The visible window ───────────────────────────────────────────────────

  @override
  ChartVisibleRange? get chartVisibleRange {
    final candles = _candlesInPlay;
    if (candles == null || candles.isEmpty || !_laidOut) return null;
    return ChartVisibleRange.of(
      candles,
      painter.mStartIndex,
      painter.mStopIndex,
    );
  }

  /// How far the chart could be scrolled at [scale], in data units.
  ///
  /// Worked out here rather than read off the painter, because moving the window
  /// means choosing a scale and a scroll together and the painter only knows
  /// about the scale it last painted at.
  double _maxScrollAt(double scale) {
    final reach =
        -painter.mDataLen +
        painter.mWidth / scale -
        painter.mPointWidth / 2 -
        widget.xFrontPadding;
    return reach >= 0 ? 0.0 : -reach;
  }

  @override
  bool showChartRange(int firstIndex, int lastIndex) {
    final candles = _candlesInPlay;
    if (candles == null || candles.isEmpty || !_laidOut) return false;

    final from = math.min(firstIndex, lastIndex).clamp(0, candles.length - 1);
    final to = math.max(firstIndex, lastIndex).clamp(0, candles.length - 1);
    final wanted = (to - from + 1) * painter.mPointWidth;
    if (wanted <= 0) return false;

    // The window is as wide as the candles asked for, within the zoom the chart
    // allows — so a range too narrow or too wide to reach is shown as near as
    // it can be.
    final scale = (painter.mWidth / wanted).clamp(0.1, 3.0);
    final scroll =
        (_maxScrollAt(scale) -
                (from * painter.mPointWidth + painter.mPointWidth / 2))
            .clamp(0.0, _maxScrollAt(scale));

    _stopAnimation(needNotify: false);
    mScaleX = scale;
    _lastScale = scale;
    mScrollX = scroll;
    notifyChanged();
    return true;
  }

  @override
  bool scrollChartTo(int index, {bool animated = true}) {
    final candles = _candlesInPlay;
    if (candles == null || candles.isEmpty || !_laidOut) return false;

    final target = index.clamp(0, candles.length - 1);
    // Centred, so the candle asked for is the middle of the window rather than
    // its left edge.
    final half = painter.mWidth / mScaleX / 2;
    final centre = target * painter.mPointWidth + painter.mPointWidth / 2;
    final max = _maxScrollAt(mScaleX);
    final scroll = (max - centre + half).clamp(0.0, max);

    _stopAnimation(needNotify: false);
    if (!animated) {
      mScrollX = scroll;
      notifyChanged();
      return true;
    }
    _animateScrollTo(scroll);
    return true;
  }

  @override
  bool fitChartToData() {
    final candles = _candlesInPlay;
    if (candles == null || candles.isEmpty || !_laidOut) return false;
    return showChartRange(0, candles.length - 1);
  }

  @override
  int? get chartCrosshairIndex {
    if (!isLongPress && !_isHovering) return null;
    final candles = _candlesInPlay;
    if (candles == null || candles.isEmpty || !_laidOut) return null;
    return painter.calculateSelectedX(mSelectX);
  }

  @override
  double? get chartCrosshairPrice {
    if (!isLongPress && !_isHovering) return null;
    final candles = _candlesInPlay;
    if (candles == null || candles.isEmpty || !_laidOut) return null;
    return painter.calculatePrice(mSelectY);
  }

  @override
  double get chartPricePan => _pricePan;

  @override
  void setChartPricePan(double pan) {
    final clamped = pan.clamp(-5.0, 5.0);
    if (clamped == _pricePan) return;
    setState(() => _pricePan = clamped);
    widget.controller?.hostChanged();
  }

  @override
  void showChartCrosshair(int? index, {double? price}) {
    if (index == null) {
      if (!isLongPress && !_isHovering) return;
      isLongPress = false;
      _isHovering = false;
      _closeInfoWindow();
      notifyChanged();
      return;
    }

    final candles = _candlesInPlay;
    if (candles == null || candles.isEmpty || !_laidOut) return;

    // Only the candles on screen have an x to sit at; a crosshair pushed from
    // a chart scrolled elsewhere rests at the near edge rather than vanishing.
    final at = index.clamp(painter.mStartIndex, painter.mStopIndex);
    final x = painter.translateXtoX(painter.getX(at));

    // A price of its own where one was given, and mid-pane otherwise — which
    // is what a chart of another instrument wants, having no price in common
    // with the one the pointer is over. Either way it stays in the pane.
    final middle = (painter.mMainRect.top + painter.mMainRect.bottom) / 2;
    final y = price == null
        ? middle
        : painter
              .getMainY(price)
              .clamp(painter.mMainRect.top, painter.mMainRect.bottom);

    // A crosshair put up from outside reads as a hover, not as a press, so it
    // does not take a held finger's place or leave one behind when it goes.
    if (_isHovering &&
        (mSelectX - x).abs() < 0.5 &&
        (mSelectY - y).abs() < 0.5) {
      return;
    }

    _isHovering = true;
    mSelectX = x;
    mSelectY = y;
    notifyChanged();
  }

  /// Slides the window to [scroll] over the fling duration.
  void _animateScrollTo(double scroll) {
    final controller = _replaceScrollController();
    final animation = Tween<double>(begin: mScrollX, end: scroll).animate(
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
        final info = snapshot.data;
        if ((!isLongPress && !isOnTap) || info == null) {
          return const SizedBox.shrink();
        }
        final entity = info.kLineEntity;
        // Never wider than the chart itself, whatever the caller asked for.
        final maxWidth = math.min(
          widget.infoDialogMaxWidth,
          math.max(widget.infoDialogWidth, mWidth - 20),
        );
        return Positioned(
          top: 10,
          left: info.isLeft ? 10.0 : null,
          right: info.isLeft ? null : 10.0,
          child:
              widget.infoDialogBuilder?.call(
                context,
                info.kLinePreviousEntity,
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
                livePrice: _candlesInPlay?.last.close,
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

  // ── The price scale ──────────────────────────────────────────────────────

  /// Stretches or compresses the price axis by a drag of [delta] pixels.
  ///
  /// Dragging down stretches the range, which makes the candles taller;
  /// dragging up compresses it. The step is a fraction of the candle area's
  /// height, so the same drag does the same thing on a phone and a desktop.
  void _zoomPriceScale(double delta) {
    final height = painter.mMainRect.height;
    if (height <= 0) return;

    setState(() {
      _priceZoom = (_priceZoom * (1 + delta / height)).clamp(0.2, 10.0);
    });
    widget.controller?.hostChanged();
  }

  /// Slides the price window by a drag of [delta] pixels.
  void _panPriceScale(double delta) {
    final height = painter.mMainRect.height;
    if (height <= 0 || delta == 0) return;

    // The window is measured in fractions of the range on show, and the range
    // itself shrinks as the axis is stretched, so the shift has to be scaled
    // by the zoom to keep a drag tracking the pointer.
    _pricePan = (_pricePan + delta / height / _priceZoom).clamp(-5.0, 5.0);
  }

  /// [range] grown to cover the newest candle, for a locked axis that is not
  /// meant to let the market trade off the top or the bottom of it.
  ///
  /// Only ever grows, and only for the newest candle while it is in view: the
  /// window moving over older candles is exactly what the lock is there to sit
  /// still through.
  (double, double) _rangeFollowingPrice((double, double) range) {
    final data = _candlesInPlay;
    if (data == null || data.isEmpty || !_laidOut) return range;
    // Off to the right of the window, the newest candle is not what the user is
    // looking at, so the axis has no reason to move for it. Asked of the
    // painter as it stands, which is last frame's window over last frame's
    // candles — so a tick that has just arrived is measured against a window
    // that was at the end of the series, not made to wait a frame for one.
    if (painter.mStopIndex < painter.mItemCount - 1) return range;

    final last = data.last;
    final low = last.low;
    final high = last.high;
    if (!low.isFinite || !high.isFinite) return range;

    return (math.min(range.$1, low), math.max(range.$2, high));
  }

  /// Hands the price axis back to the chart, which fits it to the window.
  void resetPriceScale() {
    // A locked axis has something to reset even at zoom 1: the range it is
    // being held at. Clearing it refits the axis to the window, and the next
    // build locks it there.
    if (!_priceScaleIsManual && _lockedPriceRange == null) return;
    setState(() {
      _priceZoom = 1.0;
      _pricePan = 0.0;
      _lockedPriceRange = null;
    });
    widget.controller?.hostChanged();
  }

  /// Whether [pos] landed on the strip of the candle area the price labels
  /// sit in, which is the part that drags the scale.
  ///
  /// Measured in from whichever side the labels are on, and never wider than
  /// half the chart, so a narrow chart is still mostly candles.
  bool _isOnPriceScale(Offset pos) {
    if (!widget.priceScaleDrag || !painter.hasLayout) return false;
    if (widget.currentDrawingTool != DrawingTool.none) return false;

    final grip = widget.chartStyle.priceScaleGripWidth.clamp(
      0.0,
      painter.mMainRect.width / 2,
    );
    if (grip <= 0) return false;

    // The gutter is the axis, so pressing the labels themselves grabs the
    // scale; the grip is measured in from there.
    final onLeft = widget.verticalTextAlignment == VerticalTextAlignment.left;
    final gutter = painter.priceAxisGutter;
    final rect = painter.mMainRect;
    final area = Rect.fromLTRB(
      onLeft ? rect.left - gutter : rect.left,
      rect.top,
      onLeft ? rect.right : rect.right + gutter,
      rect.bottom,
    );
    if (!area.contains(pos)) return false;

    return onLeft
        ? pos.dx <= area.left + grip + gutter
        : pos.dx >= area.right - grip - gutter;
  }

  /// Handles a tap on the price scale, and reports whether it was one.
  ///
  /// A second tap in the same place fits the axis back to the window, which is
  /// what a double-click on the axis does elsewhere. Recognised by hand rather
  /// than with a [GestureDetector.onDoubleTap], which would hold every other
  /// tap on the chart back until it knew no second one was coming.
  bool _handlePriceScaleTap(Offset pos) {
    if (!_isOnPriceScale(pos)) return false;

    final last = _lastPriceScaleTap;
    final now = DateTime.now();
    _lastPriceScaleTap = now;

    if (last != null && now.difference(last) <= kDoubleTapTimeout) {
      _lastPriceScaleTap = null;
      resetPriceScale();
    }
    return true;
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

    final selection = _selection;
    return Positioned(
      left: _toolbarOffset.dx,
      top: _toolbarOffset.dy,
      child: DrawingToolbar(
        line: selected,
        style: widget.drawingStyle,
        translations: widget.chartTranslations.drawing,
        chartColors: widget.chartColors,
        selectionLength: selection.length,
        onChanged: () {
          _shareStyleAcrossSelection(selected);
          notifyChanged();
        },
        onCommitted: () {
          for (final line in selection) {
            _notifyLineChanged(line);
          }
        },
        onDelete: _deleteSelected,
        onDone: _deselectAll,
        onMoved: widget.drawingStyle.toolbarDraggable ? _moveToolbar : null,
        onEditCoordinates: widget.showDrawingCoordinates
            ? () => _openCoordinates(selected)
            : null,
      ),
    );
  }

  /// Puts the edited drawing's look on everything else selected with it.
  ///
  /// The editor is open on one drawing but the selection may be several, and a
  /// user who selected five lines to recolour means all five. Only the shared
  /// look travels — a retracement's levels and a channel's offset stay its own.
  void _shareStyleAcrossSelection(ChartLine edited) {
    final selection = _selection;
    if (selection.length < 2) return;

    final template = DrawingTemplate.of(edited);
    for (final line in selection) {
      if (identical(line, edited) || line.locked) continue;
      template.applyTo(line);
    }
  }

  /// Reports an event whose badge is under [pos], and whether one was.
  ///
  /// Only when the host is listening: without a callback there is nothing for a
  /// tap on a badge to do, so it falls through to whatever else wanted it.
  bool _handleEventTap(Offset pos) {
    final report = widget.onEventTapped;
    if (report == null || !painter.hasLayout) return false;

    final event = painter.eventAt(pos);
    if (event == null) return false;
    report(event);
    return true;
  }

  // ── The right-click menu ─────────────────────────────────────────────────

  /// Opens the right-click menu for a click at [local], on screen at [global].
  Future<void> _openContextMenu(Offset local, Offset global) async {
    if (!widget.showContextMenu && widget.contextMenuBuilder == null) return;
    if (!_isInChartArea(local)) return;

    // A right-click on a drawing selects it first, so the menu's actions and
    // what is highlighted on the chart agree. One already selected is left as
    // it is, so a menu opened on a selection of several acts on all of them.
    final drawing = _drawingAt(local);
    if (drawing != null && !_selection.any((l) => identical(l, drawing))) {
      setState(() => _selected = drawing);
    } else if (drawing == null) {
      // Cancels a half-placed drawing rather than leaving it hanging behind
      // the menu.
      if (_isDrawing || _isPreviewing) _cancelDrawing();
    }

    final candles = _candlesInPlay;
    final index = candles == null || candles.isEmpty
        ? -1
        : painter.calculateSelectedX(local.dx);
    final candle = index < 0 || index >= (candles?.length ?? 0)
        ? null
        : candles![index];

    final defaults = drawing == null
        ? _chartMenuEntries()
        : _drawingMenuEntries(drawing);
    final entries =
        widget.contextMenuBuilder?.call((
          position: local,
          drawing: drawing,
          candle: candle,
          price: candles == null ? null : painter.calculatePrice(local.dy),
          defaults: defaults,
        )) ??
        (widget.showContextMenu ? defaults : const <ChartMenuEntry>[]);

    if (!mounted) return;
    await showChartMenu(context: context, position: global, entries: entries);
  }

  /// The drawing under [pos], or null when the click landed on empty chart.
  ChartLine? _drawingAt(Offset pos) {
    // Newest first, so the one painted on top is the one the menu is about.
    for (final line in _drawings.reversed) {
      if (line.hidden) continue;
      if (_hitDrawing(pos, line) != null) return line;
    }
    return null;
  }

  /// What the menu offers for a click on empty chart.
  List<ChartMenuEntry> _chartMenuEntries() {
    final text = widget.chartTranslations.drawing;
    final drawn = _drawings.where((line) => !line.hidden).isNotEmpty;

    return [
      ChartMenuItem(
        label: text.paste,
        icon: Icons.content_paste_rounded,
        enabled: canPasteDrawings,
        onSelected: pasteDrawings,
      ),
      ChartMenuItem(
        label: text.selectAllDrawings,
        icon: Icons.select_all_rounded,
        enabled: drawn,
        onSelected: _selectAll,
      ),
      const ChartMenuDivider(),
      ChartMenuItem(
        label: text.resetPriceScale,
        icon: Icons.height_rounded,
        enabled: _priceZoom != 1 || _pricePan != 0,
        onSelected: resetPriceScale,
      ),
      ChartMenuItem(
        label: text.scrollToNow,
        icon: Icons.last_page_rounded,
        enabled: !isChartAtRightEdge,
        onSelected: scrollChartToNow,
      ),
      const ChartMenuDivider(),
      ChartMenuItem(
        label: text.undo,
        icon: Icons.undo_rounded,
        enabled: widget.drawingController?.canUndo ?? false,
        onSelected: () => widget.drawingController?.undo(),
      ),
      ChartMenuItem(
        label: text.redo,
        icon: Icons.redo_rounded,
        enabled: widget.drawingController?.canRedo ?? false,
        onSelected: () => widget.drawingController?.redo(),
      ),
      ChartMenuItem(
        label: text.clearAll,
        icon: Icons.delete_sweep_outlined,
        enabled: drawn,
        destructive: true,
        onSelected: _clearAllDrawings,
      ),
    ];
  }

  /// What the menu offers for a click on [line].
  ///
  /// The actions apply to the whole selection where there is one, so a menu
  /// opened on one of several restacks or deletes them all.
  List<ChartMenuEntry> _drawingMenuEntries(ChartLine line) {
    final text = widget.chartTranslations.drawing;
    final controller = widget.drawingController;
    final selection = _selection;
    final several = selection.length > 1;

    return [
      ChartMenuItem(
        label: text.editCoordinates,
        icon: Icons.straighten_rounded,
        // One drawing's anchors at a time: there is no sensible form over
        // several drawings' worth of them.
        enabled: !several && !line.locked,
        onSelected: () => _openCoordinates(line),
      ),
      ChartMenuItem(
        label: text.duplicate,
        icon: Icons.content_copy_rounded,
        onSelected: duplicateSelection,
      ),
      ChartMenuItem(
        label: text.copy,
        icon: Icons.copy_all_rounded,
        onSelected: copySelection,
      ),
      const ChartMenuDivider(),
      ChartMenuItem(
        label: text.bringToFront,
        icon: Icons.flip_to_front_rounded,
        enabled: controller != null,
        onSelected: bringSelectionToFront,
      ),
      ChartMenuItem(
        label: text.sendToBack,
        icon: Icons.flip_to_back_rounded,
        enabled: controller != null,
        onSelected: sendSelectionToBack,
      ),
      const ChartMenuDivider(),
      if (line is AlertingDrawing)
        ChartMenuItem(
          label: line.alert ? text.clearAlert : text.alert,
          checked: line.alert,
          onSelected: () => _setForSelection(
            (target) =>
                target is AlertingDrawing ? target.alert = !line.alert : null,
          ),
        ),
      ChartMenuItem(
        label: line.locked ? text.unlock : text.lock,
        checked: line.locked,
        onSelected: () =>
            _setForSelection((target) => target.locked = !line.locked),
      ),
      ChartMenuItem(
        label: line.hidden ? text.show : text.hide,
        checked: line.hidden,
        onSelected: () =>
            _setForSelection((target) => target.hidden = !line.hidden),
      ),
      const ChartMenuDivider(),
      ChartMenuItem(
        label: text.delete,
        icon: Icons.delete_outline_rounded,
        destructive: true,
        onSelected: _deleteSelected,
      ),
    ];
  }

  /// Runs [change] over every selected drawing, then saves and repaints.
  ///
  /// The new value is taken from the drawing the menu was opened on, so a
  /// selection of several ends up agreeing rather than each one flipping to
  /// whatever it was not.
  void _setForSelection(void Function(ChartLine line) change) {
    for (final line in _selection) {
      change(line);
      _notifyLineChanged(line);
    }
    setState(() {});
  }

  /// Removes every drawing, reporting each one.
  void _clearAllDrawings() {
    final drawn = [..._drawings];
    widget.drawingController?.clear();
    for (final line in drawn) {
      widget.onRemoveDrawing?.call(line);
    }
    _deselectAll();
  }

  /// Opens the dialog that shows and edits [line]'s exact anchors.
  Future<void> _openCoordinates(ChartLine line) async {
    final candles = _candlesInPlay;
    if (candles == null || candles.isEmpty) return;

    final changed = await showDrawingCoordinatesDialog(
      context: context,
      line: line,
      candles: candles,
      translations: widget.chartTranslations.drawing,
      fixedLength: widget.fixedLength,
    );
    if (!changed || !mounted) return;

    _notifyLineChanged(line);
    setState(() {});
  }
}
