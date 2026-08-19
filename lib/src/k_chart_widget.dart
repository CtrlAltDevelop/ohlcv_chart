import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'chart_style.dart';
import 'chart_translations.dart';
import 'components/popup_info_view.dart';
import 'drawing/drawing_style.dart';
import 'drawing/drawing_toolbar.dart';
import 'entity/horizontal_line.dart';
import 'entity/info_window_entity.dart';
import 'entity/k_line_entity.dart';
import 'entity/line.dart';
import 'entity/signal_entity.dart';
import 'entity/trend_line.dart';
import 'entity/vertical_lines.dart';
import 'indicators/indicator.dart';
import 'indicators/resolved_indicator.dart';
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

  /// The next tap places a [HorizontalLine].
  horizontal,

  /// The next tap places a [VerticalLine].
  vertical,

  /// The next two taps place the ends of a [TrendLine].
  trend,
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
    this.indicators = const <Indicator>[],
    this.currentDrawingTool = DrawingTool.none,
    this.magnetMode = false,
    this.onAddTrendLine,
    this.onAddHorizontalLine,
    this.onAddVerticalLine,
    this.onRemoveTrendLine,
    this.onRemoveHorizontalLine,
    this.onRemoveVerticalLine,
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

  /// The active drawing mode; see [DrawingTool].
  final DrawingTool currentDrawingTool;

  /// Snaps points being placed to the nearest open, high, low or close.
  ///
  /// A point only snaps when a candle's price is within
  /// [DrawingStyle.magnetSnapDistance] pixels of the pointer; further away it
  /// lands wherever the pointer is.
  final bool magnetMode;

  /// Called when the user finishes drawing or edits a trend line.
  final ValueChanged<TrendLine>? onAddTrendLine;

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

  /// Duration of one candle, used to place lines and count down the close.
  final Duration timeFrame;

  /// Draws a filled close-price line instead of candles.
  final bool isLine;

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
    with TickerProviderStateMixin {
  final StreamController<InfoWindowEntity?> mInfoWindowStream =
      StreamController<InfoWindowEntity?>();

  HorizontalLine? selectedHorizontal;
  VerticalLine? selectedVertical;
  TrendLine? selectedTrend;
  TrendLine? tempTrendLine;

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

  /// Where the pointer was, and what the line looked like, when a drag on a
  /// selected line began. Lets a trend line move as a whole.
  ({int index, double price})? _dragStart;
  ({int i1, double p1, int? i2, double? p2})? _dragOrigin;

  late ChartPainter painter;
  double _lastScale = 1.0;
  bool isScale = false;
  bool isDrag = false;
  bool isLongPress = false;
  bool isOnTap = false;
  bool isDraggingHandle = false;
  int? draggingTrendEnd;

  @override
  void initState() {
    super.initState();
    _toolbarOffset = widget.drawingStyle.toolbarInitialOffset;
    _loadWatermark();
    _syncCountdownTimer();
    _resolveIndicators();
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  /// Lets Escape throw away whatever is being drawn, wherever the focus is.
  ///
  /// Only claims the key while a drawing is actually in progress, so it never
  /// swallows an Escape the host wanted for a dialog of its own.
  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.escape) return false;
    if (!_isDrawing && !_isPreviewing) return false;
    _cancelDrawing();
    return true;
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
    _countdownTimer?.cancel();
    mInfoWindowStream.close();
    _controller?.dispose();
    super.dispose();
  }

  ChartLine? _getSelectedLine() =>
      selectedHorizontal ?? selectedVertical ?? selectedTrend;

  void _deselectAll() {
    setState(() {
      selectedHorizontal = null;
      selectedVertical = null;
      selectedTrend = null;
      isDraggingHandle = false;
      draggingTrendEnd = null;
      _dragStart = null;
      _dragOrigin = null;
    });
  }

  void _deleteSelected() {
    final line = _getSelectedLine();
    if (line is HorizontalLine) widget.onRemoveHorizontalLine?.call(line);
    if (line is VerticalLine) widget.onRemoveVerticalLine?.call(line);
    if (line is TrendLine) widget.onRemoveTrendLine?.call(line);
    _deselectAll();
  }

  /// Reports an edited line through the matching `onAdd*` callback, which is
  /// where a host persists it.
  void _notifyLineChanged(ChartLine line) {
    switch (line) {
      case HorizontalLine():
        widget.onAddHorizontalLine?.call(line);
      case VerticalLine():
        widget.onAddVerticalLine?.call(line);
      case TrendLine():
        widget.onAddTrendLine?.call(line);
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
            legendRowCount: _resolved.legendRowCount,
          ),
    );
  }

  /// Candle height used when the box does not constrain its height at all.
  static const double _unboundedBaseHeight = 360;

  @override
  Widget build(BuildContext context) {
    if (widget.candles != null && widget.candles!.isEmpty) {
      mScrollX = mSelectX = 0.0;
      mScaleX = 1.0;
    }

    _refreshIndicatorsIfStale();

    return LayoutBuilder(
      builder: (context, constraints) {
        mHeight = constraints.maxHeight;
        mWidth = constraints.maxWidth;

        final baseDimension = BaseDimension(
          mBaseHeight: _resolveBaseHeight(constraints.maxHeight),
          volHidden: widget.volHidden,
          paneCount: _resolved.panes.length,
          legendRowCount: _resolved.legendRowCount,
        );

        painter = ChartPainter(
          widget.chartStyle,
          widget.chartColors,
          isDrawing: _isDrawing || _isPreviewing,
          currentDrawingTool: widget.currentDrawingTool,
          showLiveVerticalPreview:
              _isDrawing && widget.currentDrawingTool == DrawingTool.vertical,
          showLiveHorizontalPreview:
              _isDrawing && widget.currentDrawingTool == DrawingTool.horizontal,
          baseDimension: baseDimension,
          trendLines: widget.trendLines,
          horizontalLines: widget.horizontalLines,
          verticalLines: widget.verticalLines,
          signals: widget.signals,
          timeFrame: widget.timeFrame,
          sink: mInfoWindowStream.sink,
          xFrontPadding: widget.xFrontPadding,
          isTrendLine: widget.isTrendLine,
          selectY: mSelectY,
          tempTrendLine: tempTrendLine,
          candles: widget.candles,
          scaleX: mScaleX,
          scrollX: mScrollX,
          selectX: mSelectX,
          isLongPress: isLongPress,
          isOnTap: isOnTap,
          suppressCrosshair: _isDrawing || isDraggingHandle,
          isTapShowInfoDialog: widget.isTapShowInfoDialog,
          overlays: _resolved.overlays,
          panes: _resolved.panes,
          volHidden: widget.volHidden,
          isLine: widget.isLine,
          hideGrid: widget.hideGrid,
          showNowPrice: widget.showNowPrice,
          fixedLength: widget.fixedLength,
          verticalTextAlignment: widget.verticalTextAlignment,
          dateFormatter: widget.dateFormatter,
          watermarkPicture: _watermarkPicture,
          selectedHorizontal: selectedHorizontal,
          selectedVertical: selectedVertical,
          selectedTrend: selectedTrend,
          drawingStyle: widget.drawingStyle,
        );

        return Stack(
          children: [
            Listener(
              onPointerMove: (event) {
                if (_isDrawing &&
                    widget.currentDrawingTool == DrawingTool.trend &&
                    tempTrendLine != null) {
                  mSelectX = event.localPosition.dx;
                  mSelectY = event.localPosition.dy;
                  notifyChanged();
                }
              },
              child: MouseRegion(
                opaque: false,
                cursor: widget.currentDrawingTool == DrawingTool.none
                    ? MouseCursor.defer
                    : SystemMouseCursors.precise,
                onHover: (event) => _handleHover(event.localPosition),
                onExit: (_) {
                  if (_isPreviewing) _cancelDrawing();
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    if (isLongPress) {
                      isLongPress = false;
                      mInfoWindowStream.sink.add(null);
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
                    if (_isDrawing) {
                      // Letting go without a far end keeps the anchor on the
                      // chart: the next tap finishes the line, so a press that
                      // wandered a pixel or two costs nothing.
                      if (_draftIsIncomplete) {
                        _awaitingSecondPoint = true;
                      } else {
                        _commitDraft();
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
                      CustomPaint(
                        size: Size.fromHeight(baseDimension.mDisplayHeight),
                        painter: painter,
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
          ],
        );
      },
    );
  }

  bool _isInChartArea(Offset pos) => painter.mMainRect.contains(pos);

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

  void _closeInfoWindow() {
    if (!mInfoWindowStream.isClosed) mInfoWindowStream.sink.add(null);
  }

  void _cancelDrawing() {
    _resetDraft();
    notifyChanged();
  }

  /// Throws away the line being placed, without asking for a repaint.
  void _resetDraft() {
    tempTrendLine = null;
    selectedHorizontal = null;
    selectedVertical = null;
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
  /// Returns false when [pos] is not somewhere a line can be anchored, leaving
  /// the tool armed and waiting for a better spot.
  bool _startDraft(Offset pos, {bool preview = false}) {
    if (!_isInChartArea(pos)) return false;
    final anchor = _anchorAt(pos);
    if (anchor == null) return false;

    switch (widget.currentDrawingTool) {
      case DrawingTool.none:
        return false;
      case DrawingTool.horizontal:
        selectedHorizontal = HorizontalLine(
          price: anchor.price,
          title: anchor.price.toStringAsFixed(widget.fixedLength),
        );
        selectedVertical = null;
        selectedTrend = null;
      case DrawingTool.vertical:
        selectedVertical = VerticalLine(
          time: anchor.time,
          title: painter.getDate(anchor.time),
        );
        selectedHorizontal = null;
        selectedTrend = null;
      case DrawingTool.trend:
        if (preview) return false; // Nothing to show until a point lands.
        tempTrendLine = TrendLine(time1: anchor.time, price1: anchor.price);
        selectedHorizontal = null;
        selectedVertical = null;
        selectedTrend = null;
    }

    _isPreviewing = preview;
    _isDrawing = !preview;
    return true;
  }

  /// Moves the free end of the drawing in progress to [pos].
  void _extendDraft(Offset pos) {
    final anchor = _anchorAt(pos);
    if (anchor == null) return;

    switch (widget.currentDrawingTool) {
      case DrawingTool.none:
        return;
      case DrawingTool.horizontal:
        selectedHorizontal!
          ..price = anchor.price
          ..title = anchor.price.toStringAsFixed(widget.fixedLength);
      case DrawingTool.vertical:
        selectedVertical!
          ..time = anchor.time
          ..title = painter.getDate(anchor.time);
      case DrawingTool.trend:
        tempTrendLine!
          ..time2 = anchor.time
          ..price2 = anchor.price;
    }
    notifyChanged();
  }

  /// True while the drawing in progress still needs a point.
  bool get _draftIsIncomplete =>
      widget.currentDrawingTool == DrawingTool.trend &&
      tempTrendLine?.time2 == null;

  /// Hands the finished drawing to the host and leaves it selected, the way
  /// the editing toolbar expects to find it.
  void _commitDraft() {
    switch (widget.currentDrawingTool) {
      case DrawingTool.none:
        return;
      case DrawingTool.horizontal:
        if (selectedHorizontal == null) return;
        widget.onAddHorizontalLine?.call(selectedHorizontal!);
      case DrawingTool.vertical:
        if (selectedVertical == null) return;
        widget.onAddVerticalLine?.call(selectedVertical!);
      case DrawingTool.trend:
        final draft = tempTrendLine;
        if (draft?.time2 == null) return;
        final line = TrendLine(
          time1: draft!.time1,
          price1: draft.price1,
          time2: draft.time2,
          price2: draft.price2,
          color: draft.color,
          thickness: draft.thickness,
        );
        widget.onAddTrendLine?.call(line);
        selectedTrend = line;
        tempTrendLine = null;
    }

    _isDrawing = false;
    _awaitingSecondPoint = false;
    _isPreviewing = false;
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
    if (widget.currentDrawingTool == DrawingTool.none) return;

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

  void _trySelectLine(Offset pos) {
    isDraggingHandle = false;
    draggingTrendEnd = null;

    final candles = widget.candles;
    if (candles == null || candles.isEmpty) {
      _deselectAll();
      return;
    }

    final tolerance = widget.drawingStyle.hitTestTolerance;
    final handleTolerance = widget.drawingStyle.handleHitTestTolerance;

    for (final line in widget.horizontalLines) {
      if ((pos.dy - painter.getMainY(line.price)).abs() < tolerance) {
        _select(pos, horizontal: line);
        return;
      }
    }

    for (final line in widget.verticalLines) {
      final index = candles.indexWhere((e) => e.dateTime == line.time);
      if (index == -1) continue;
      final x = painter.translateXtoX(painter.getX(index));
      if ((pos.dx - x).abs() < tolerance) {
        _select(pos, vertical: line);
        return;
      }
    }

    for (final line in widget.trendLines) {
      final i1 = candles.indexWhere((e) => e.dateTime == line.time1);
      if (i1 == -1) continue;
      final p1 = Offset(
        painter.translateXtoX(painter.getX(i1)),
        painter.getMainY(line.price1),
      );
      final distance1 = (pos - p1).distance;

      // A half-drawn line only has its first anchor to grab.
      if (line.time2 == null || line.price2 == null) {
        if (distance1 >= handleTolerance) continue;
        _select(pos, trend: line, end: 1);
        return;
      }

      final i2 = candles.indexWhere((e) => e.dateTime == line.time2);
      if (i2 == -1) continue;
      final p2 = Offset(
        painter.translateXtoX(painter.getX(i2)),
        painter.getMainY(line.price2!),
      );
      final distance2 = (pos - p2).distance;

      // Near an end grabs that end; anywhere else along the stroke picks the
      // whole line up.
      if (distance1 < handleTolerance || distance2 < handleTolerance) {
        _select(pos, trend: line, end: distance1 <= distance2 ? 1 : 2);
        return;
      }
      if (_distanceToSegment(pos, p1, p2) < tolerance) {
        _select(pos, trend: line, end: 0);
        return;
      }
    }

    _deselectAll();
  }

  /// Selects one line, clearing the others, and arms it for dragging from
  /// [pos] — the point that picked it, whether that was a tap, a long press or
  /// the start of a drag.
  void _select(
    Offset pos, {
    HorizontalLine? horizontal,
    VerticalLine? vertical,
    TrendLine? trend,
    int? end,
  }) {
    setState(() {
      selectedHorizontal = horizontal;
      selectedVertical = vertical;
      selectedTrend = trend;
      draggingTrendEnd = end;
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

  /// Remembers where a drag began, so a whole trend line can be shifted.
  void _beginHandleDrag(Offset pos) {
    final candles = widget.candles;
    if (candles == null || candles.isEmpty) return;

    _dragStart = (
      index: painter.calculateSelectedX(pos.dx),
      price: painter.calculatePrice(pos.dy),
    );

    final trend = selectedTrend;
    if (trend == null) {
      _dragOrigin = null;
      return;
    }
    _dragOrigin = (
      i1: candles.indexWhere((e) => e.dateTime == trend.time1),
      p1: trend.price1,
      i2: trend.time2 == null
          ? null
          : candles.indexWhere((e) => e.dateTime == trend.time2),
      p2: trend.price2,
    );
  }

  /// Moves the selected line to follow the pointer at [pos].
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
      case VerticalLine():
        if (line.title == painter.getDate(line.time)) {
          line.title = painter.getDate(time);
        }
        line.time = time;
      case TrendLine():
        _dragTrendLine(line, candles, index, time, price);
    }
    notifyChanged();
  }

  void _dragTrendLine(
    TrendLine line,
    List<KLineEntity> candles,
    int index,
    DateTime time,
    double price,
  ) {
    switch (draggingTrendEnd) {
      case 1:
        line.time1 = time;
        line.price1 = price;
      case 2:
        line.time2 = time;
        line.price2 = price;
      case 0:
        final start = _dragStart;
        final origin = _dragOrigin;
        final i2 = origin?.i2;
        if (start == null || origin == null || i2 == null) return;

        // Shift both ends by the same number of candles and the same amount of
        // price, stopping once either end reaches the edge of the data.
        final lowest = math.min(origin.i1, i2);
        final highest = math.max(origin.i1, i2);
        final shift = (index - start.index).clamp(
          -lowest,
          candles.length - 1 - highest,
        );
        final time1 = candles[origin.i1 + shift].dateTime;
        final time2 = candles[i2 + shift].dateTime;
        if (time1 == null || time2 == null) return;

        final priceShift = price - start.price;
        line.time1 = time1;
        line.price1 = origin.p1 + priceShift;
        line.time2 = time2;
        line.price2 = (origin.p2 ?? origin.p1) + priceShift;
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

  void notifyChanged() => setState(() {});

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
