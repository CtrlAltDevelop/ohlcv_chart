import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'chart_style.dart';
import 'chart_translations.dart';
import 'components/popup_info_view.dart';
import 'entity/horizontal_line.dart';
import 'entity/info_window_entity.dart';
import 'entity/k_line_entity.dart';
import 'entity/line.dart';
import 'entity/signal_entity.dart';
import 'entity/trend_line.dart';
import 'entity/vertical_lines.dart';
import 'renderer/base_chart_painter.dart';
import 'renderer/base_dimension.dart';
import 'renderer/chart_painter.dart';
import 'renderer/main_renderer.dart';
import 'utils/date_format_util.dart';

/// An overlay drawn on top of the candles in the main chart area.
enum MainState {
  /// Moving averages, one line per period in `maDayList`.
  MA,

  /// Bollinger bands.
  BOLL,

  /// Parabolic SAR dots.
  SAR,
}

/// An indicator rendered in its own pane below the main chart.
///
/// Every selected state gets its own stacked pane.
enum SecondaryState {
  /// Moving average convergence divergence, with histogram.
  MACD,

  /// Stochastic oscillator.
  KDJ,

  /// Relative strength index.
  RSI,

  /// Williams %R.
  WR,

  /// Commodity channel index.
  CCI,
}

/// The drawing mode the chart is currently in.
///
/// Anything other than [none] makes the next tap place a line instead of
/// moving the crosshair.
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
///   mainStateLi: const {MainState.MA},
///   secondaryStateLi: const {SecondaryState.MACD},
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
    this.mainStateLi = const <MainState>{},
    this.secondaryStateLi = const <SecondaryState>{},
    this.currentDrawingTool = DrawingTool.none,
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
    this.chartTranslations = const ChartTranslations(),
    this.timeFormat = TimeFormat.YEAR_MONTH_DAY,
    this.infoDialogBuilder,
    this.dateFormatter,
    this.onLoadMore,
    this.fixedLength = 2,
    this.maDayList = const [5, 10, 20],
    this.flingTime = 600,
    this.flingRatio = 0.5,
    this.flingCurve = Curves.decelerate,
    this.isOnDrag,
    this.verticalTextAlignment = VerticalTextAlignment.left,
    this.mBaseHeight = 360,
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

  /// Overlays drawn on the main chart. Empty draws candles alone.
  final Set<MainState> mainStateLi;

  /// Indicators to stack below the main chart, one pane each.
  final Set<SecondaryState> secondaryStateLi;

  /// The active drawing mode; see [DrawingTool].
  final DrawingTool currentDrawingTool;

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

  /// Height of the main chart area, before sub-chart panes are added.
  final double mBaseHeight;

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

  /// Moving-average periods, matching what [DataUtil.calculate] was given.
  final List<int> maDayList;

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
  Offset? _editPanelOffset;

  late ChartPainter painter;
  double _lastScale = 1.0;
  bool isScale = false;
  bool isDrag = false;
  bool isLongPress = false;
  bool isOnTap = false;
  bool isDraggingHandle = false;
  int? draggingTrendEnd;

  final List<Color> presetColors = [
    Colors.yellow,
    Colors.white,
    Colors.black,
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.orange,
    Colors.cyan,
  ];

  final List<double> presetThickness = [1.0, 2.0, 3.0, 4.0, 5.0];

  @override
  void initState() {
    super.initState();
    _editPanelOffset = const Offset(16, 40);
    _loadWatermark();
    _syncCountdownTimer();
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
  }

  @override
  void dispose() {
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
    });
  }

  void _deleteSelected() {
    final line = _getSelectedLine();
    if (line is HorizontalLine) widget.onRemoveHorizontalLine?.call(line);
    if (line is VerticalLine) widget.onRemoveVerticalLine?.call(line);
    if (line is TrendLine) widget.onRemoveTrendLine?.call(line);
    _deselectAll();
  }

  void _showColorPicker() {
    final selected = _getSelectedLine();
    if (selected == null) return;

    showDialog<void>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Color'),
        children: presetColors
            .map(
              (color) => SimpleDialogOption(
                onPressed: () {
                  setState(() => selected.color = color);
                  Navigator.pop(context);
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  void _showThicknessPicker() {
    final selected = _getSelectedLine();
    if (selected == null) return;

    showDialog<void>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Line Thickness'),
        children: presetThickness
            .map(
              (t) => SimpleDialogOption(
                onPressed: () {
                  setState(() => selected.thickness = t);
                  Navigator.pop(context);
                },
                child: Text(t.toStringAsFixed(1)),
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.candles != null && widget.candles!.isEmpty) {
      mScrollX = mSelectX = 0.0;
      mScaleX = 1.0;
    }

    final baseDimension = BaseDimension(
      mBaseHeight: widget.mBaseHeight,
      volHidden: widget.volHidden,
      secondaryStateLi: widget.secondaryStateLi,
      mainStateLi: widget.mainStateLi,
    );

    painter = ChartPainter(
      widget.chartStyle,
      widget.chartColors,
      isDrawing: _isDrawing,
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
      isTapShowInfoDialog: widget.isTapShowInfoDialog,
      mainStateLi: widget.mainStateLi,
      volHidden: widget.volHidden,
      secondaryStateLi: widget.secondaryStateLi,
      isLine: widget.isLine,
      hideGrid: widget.hideGrid,
      showNowPrice: widget.showNowPrice,
      fixedLength: widget.fixedLength,
      maDayList: widget.maDayList,
      verticalTextAlignment: widget.verticalTextAlignment,
      dateFormatter: widget.dateFormatter,
      watermarkPicture: _watermarkPicture,
      selectedHorizontal: selectedHorizontal,
      selectedVertical: selectedVertical,
      selectedTrend: selectedTrend,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        mHeight = constraints.maxHeight;
        mWidth = constraints.maxWidth;

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
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  if (isLongPress) {
                    isLongPress = false;
                    mInfoWindowStream.sink.add(null);
                  }

                  final pos = details.localPosition;

                  if (widget.currentDrawingTool == DrawingTool.none) {
                    _trySelectLine(pos);
                  }

                  if (!_isInChartArea(pos)) {
                    _cancelDrawing();
                    return;
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
                  if (isDraggingHandle && _getSelectedLine()?.locked == false) {
                    final pos = details.localPosition;
                    final price = painter.calculatePrice(pos.dy);
                    final index = painter.calculateSelectedX(pos.dx);
                    final time = widget.candles![index].dateTime!;

                    if (selectedHorizontal != null) {
                      selectedHorizontal!.price = price;
                    } else if (selectedVertical != null) {
                      selectedVertical!.time = time;
                    } else if (selectedTrend != null &&
                        draggingTrendEnd != null) {
                      if (draggingTrendEnd == 1) {
                        selectedTrend!.time1 = time;
                        selectedTrend!.price1 = price;
                      } else {
                        selectedTrend!.time2 = time;
                        selectedTrend!.price2 = price;
                      }
                    }

                    // Removed auto-scroll for vertical and trend lines as per issue 2

                    notifyChanged();
                  } else if (widget.currentDrawingTool == DrawingTool.none) {
                    mSelectX = details.localPosition.dx;
                    mSelectY = details.localPosition.dy;
                    notifyChanged();
                  }
                },
                onLongPressEnd: (_) {
                  isLongPress = false;
                  notifyChanged();
                },
                onScaleStart: (details) {
                  _stopAnimation();
                  final pos = details.localFocalPoint;
                  if (widget.currentDrawingTool != DrawingTool.none) {
                    if (!_isInChartArea(pos)) return;
                    final index = painter.calculateSelectedX(pos.dx);
                    if (index < 0 || index >= widget.candles!.length) return;
                    final time = widget.candles![index].dateTime!;
                    final price = painter.calculatePrice(pos.dy);
                    if (widget.currentDrawingTool == DrawingTool.horizontal) {
                      selectedHorizontal = HorizontalLine(
                        price: price,
                        title: price.toStringAsFixed(widget.fixedLength),
                      );
                    } else if (widget.currentDrawingTool ==
                        DrawingTool.vertical) {
                      selectedVertical = VerticalLine(
                        time: time,
                        title: painter.getDate(time),
                      );
                    } else if (widget.currentDrawingTool == DrawingTool.trend) {
                      tempTrendLine = TrendLine(time1: time, price1: price);
                    }
                    _isDrawing = true;
                  } else {
                    _trySelectLine(pos);
                    if (_getSelectedLine() != null) {
                      isDraggingHandle = true;
                      _onDragChanged(true);
                    } else {
                      _onDragChanged(true);
                    }
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
                    final index = painter.calculateSelectedX(pos.dx);
                    if (index < 0 || index >= widget.candles!.length) return;
                    final time = widget.candles![index].dateTime!;
                    final price = painter.calculatePrice(pos.dy);
                    if (widget.currentDrawingTool == DrawingTool.horizontal) {
                      selectedHorizontal!.price = price;
                      selectedHorizontal!.title = price.toStringAsFixed(
                        widget.fixedLength,
                      );
                    } else if (widget.currentDrawingTool ==
                        DrawingTool.vertical) {
                      selectedVertical!.time = time;
                      selectedVertical!.title = painter.getDate(time);
                    } else if (widget.currentDrawingTool == DrawingTool.trend) {
                      tempTrendLine!.time2 = time;
                      tempTrendLine!.price2 = price;
                    }
                    notifyChanged();
                  } else if (isDraggingHandle &&
                      _getSelectedLine()?.locked == false) {
                    final price = painter.calculatePrice(pos.dy);
                    final index = painter.calculateSelectedX(pos.dx);
                    final time = widget.candles![index].dateTime!;

                    if (selectedHorizontal != null) {
                      selectedHorizontal!.price = price;
                    } else if (selectedVertical != null) {
                      selectedVertical!.time = time;
                    } else if (selectedTrend != null &&
                        draggingTrendEnd != null) {
                      if (draggingTrendEnd == 1) {
                        selectedTrend!.time1 = time;
                        selectedTrend!.price1 = price;
                      } else {
                        selectedTrend!.time2 = time;
                        selectedTrend!.price2 = price;
                      }
                    }
                    // Removed auto-scroll for vertical and trend lines as per issue 2
                    notifyChanged();
                  } else {
                    mScrollX += details.focalPointDelta.dx / mScaleX;
                    mScrollX = mScrollX.clamp(0.0, BaseChartPainter.maxScrollX);
                    notifyChanged();
                  }
                },
                onScaleEnd: (details) {
                  if (_isDrawing) {
                    if (widget.currentDrawingTool == DrawingTool.horizontal) {
                      widget.onAddHorizontalLine?.call(selectedHorizontal!);
                    } else if (widget.currentDrawingTool ==
                        DrawingTool.vertical) {
                      widget.onAddVerticalLine?.call(selectedVertical!);
                    } else if (widget.currentDrawingTool == DrawingTool.trend) {
                      if (tempTrendLine!.time2 == null) {
                        _cancelDrawing();
                      } else {
                        final newLine = TrendLine(
                          time1: tempTrendLine!.time1,
                          price1: tempTrendLine!.price1,
                          time2: tempTrendLine!.time2,
                          price2: tempTrendLine!.price2,
                          color: tempTrendLine!.color,
                          thickness: tempTrendLine!.thickness,
                        );
                        widget.onAddTrendLine?.call(newLine);
                        selectedTrend = newLine;
                        tempTrendLine = null;
                      }
                    }
                    _isDrawing = false;
                  }

                  if (isDraggingHandle) {
                    isDraggingHandle = false;
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
                    if (_getSelectedLine() != null) _buildEditPanel(),
                  ],
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

  void _cancelDrawing() {
    tempTrendLine = null;
    selectedHorizontal = null;
    selectedVertical = null;
    _isDrawing = false;
    notifyChanged();
  }

  void _trySelectLine(Offset pos) {
    isDraggingHandle = false;
    draggingTrendEnd = null;

    for (final line in widget.horizontalLines) {
      final y = painter.getMainY(line.price);
      if ((pos.dy - y).abs() < 20) {
        selectedHorizontal = line;
        selectedVertical = null;
        selectedTrend = null;
        isDraggingHandle = true;
        setState(() {});
        return;
      }
    }

    for (final line in widget.verticalLines) {
      final index = widget.candles!.indexWhere((e) => e.dateTime == line.time);
      if (index == -1) continue;
      final x = painter.getX(index);
      if ((pos.dx - painter.translateXtoX(x)).abs() < 20) {
        selectedVertical = line;
        selectedHorizontal = null;
        selectedTrend = null;
        isDraggingHandle = true;
        setState(() {});
        return;
      }
    }

    for (final line in widget.trendLines) {
      final i1 = widget.candles!.indexWhere((e) => e.dateTime == line.time1);
      if (i1 == -1) continue;
      final p1 = Offset(
        painter.translateXtoX(painter.getX(i1)),
        painter.getMainY(line.price1),
      );
      final dist1 = (pos - p1).distance;
      if (line.time2 != null) {
        final i2 = widget.candles!.indexWhere((e) => e.dateTime == line.time2);
        if (i2 == -1) continue;
        final p2 = Offset(
          painter.translateXtoX(painter.getX(i2)),
          painter.getMainY(line.price2!),
        );
        final dist2 = (pos - p2).distance;
        if (dist1 < 40 || dist2 < 40) {
          selectedTrend = line;
          selectedHorizontal = null;
          selectedVertical = null;
          draggingTrendEnd = dist1 < dist2 ? 1 : 2;
          isDraggingHandle = true;
          setState(() {});
          return;
        }
      } else if (dist1 < 40) {
        selectedTrend = line;
        selectedHorizontal = null;
        selectedVertical = null;
        draggingTrendEnd = 1;
        isDraggingHandle = true;
        setState(() {});
        return;
      }
    }

    _deselectAll();
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
        const dialogWidth = 130.0;
        return Positioned(
          width: dialogWidth,
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
                width: dialogWidth,
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

  Widget _buildEditPanel() {
    final selected = _getSelectedLine();
    if (selected == null) return const SizedBox.shrink();

    return Positioned(
      left: _editPanelOffset?.dx ?? 20,
      top: _editPanelOffset?.dy ?? 60,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: widget.chartColors.bgColor.withAlpha(240),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withAlpha(40), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(80),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _editPanelOffset =
                      (_editPanelOffset ?? Offset.zero) + details.delta;
                });
              },
              child: const Icon(Icons.drag_indicator_rounded),
            ),
            _buildActionButton(
              icon: Icons.line_weight,
              onPressed: _showThicknessPicker,
            ),
            _buildActionButton(
              icon: Icons.palette,
              onPressed: _showColorPicker,
            ),
            _buildActionButton(
              icon: selected.isDashed ? Icons.border_clear : Icons.border_style,
              onPressed: () =>
                  setState(() => selected.isDashed = !selected.isDashed),
            ),
            if (selected is TrendLine)
              _buildActionButton(
                icon: selected.showLabel
                    ? Icons.visibility
                    : Icons.visibility_off,
                onPressed: () =>
                    setState(() => selected.showLabel = !selected.showLabel),
              ),
            if (selected is HorizontalLine || selected is VerticalLine)
              _buildActionButton(
                icon: selected.showLabel
                    ? Icons.visibility
                    : Icons.visibility_off,
                onPressed: () =>
                    setState(() => selected.showLabel = !selected.showLabel),
              ),
            _buildActionButton(
              icon: selected.locked ? Icons.lock : Icons.lock_open,
              onPressed: () =>
                  setState(() => selected.locked = !selected.locked),
            ),
            _buildActionButton(
              icon: Icons.delete_outline_rounded,
              onPressed: _deleteSelected,
              color: Colors.redAccent,
            ),
            _buildActionButton(
              icon: Icons.check_circle_outline_rounded,
              onPressed: _deselectAll,
              color: Colors.greenAccent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return IconButton(
      icon: Icon(icon, size: 22),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      onPressed: onPressed,
    );
  }
}
