import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'chart_controller.dart';
import 'chart_style.dart';
import 'entity/k_line_entity.dart';

/// A slim chart of the whole history, with the visible window marked on it.
///
/// The main chart shows a window onto the candles; this shows where that window
/// is, and moves it. Drag the lit part to scrub through the history, drag
/// either edge to widen or narrow it, or tap anywhere to jump there — all of it
/// through the same [KChartController] the chart is driven by, so the two never
/// disagree about where they are.
///
/// ```dart
/// final chart = KChartController();
///
/// Column(
///   children: [
///     Expanded(child: KChartWidget(candles, colors, controller: chart, /* … */)),
///     ChartOverview(candles, controller: chart, colors: colors),
///   ],
/// );
/// ```
///
/// Hand it the same list the chart has. It draws the closes, so a history too
/// long to fit in the main window still reads as a shape at a glance, and it
/// costs one line per pixel column rather than a candle each.
class ChartOverview extends StatefulWidget {
  /// Creates an overview of [candles], driving [controller].
  const ChartOverview(
    this.candles, {
    required this.controller,
    this.colors,
    this.height = 56,
    this.handleWidth = 10,
    this.padding = const EdgeInsets.symmetric(vertical: 6),
    super.key,
  });

  /// The whole history — the same list the chart was given.
  final List<KLineEntity> candles;

  /// The controller the chart is driven by.
  final KChartController controller;

  /// Where the colours come from; a default set when null.
  final ChartColors? colors;

  /// How tall the strip is.
  final double height;

  /// How near an edge of the window a grab counts as a resize.
  ///
  /// Below this the drag moves the window instead, so a narrow window is still
  /// draggable rather than being all handle.
  final double handleWidth;

  /// Room left above and below the line, so it does not touch the edges.
  final EdgeInsets padding;

  @override
  State<ChartOverview> createState() => _ChartOverviewState();
}

class _ChartOverviewState extends State<ChartOverview> {
  /// What a drag in progress is doing.
  _Grab _grab = _Grab.none;

  /// Where the window was when the drag began, so a pan keeps its width.
  int _grabFirst = 0;
  int _grabLast = 0;

  /// Where the pointer went down, in candles.
  double _grabAt = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);

    // A chart has no window until it has laid itself out, and laying out is not
    // something it notifies about — it only speaks up once something moves it.
    // Without a look after the first frame the strip would draw the history
    // with no window lit on it until the user happened to scroll.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(ChartOverview old) {
    super.didUpdateWidget(old);
    if (!identical(old.controller, widget.controller)) {
      old.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  /// Whether a repaint is already waiting on the end of this frame.
  bool _pending = false;

  void _onControllerChanged() {
    if (!mounted || _pending) return;
    _pending = true;

    // Always after the frame, for two reasons that pull the same way. A chart
    // notifies while it is building — attaching does it, and so does every
    // scroll — and marking a sibling dirty mid-build is an error. And a chart
    // told to show a new window has not laid it out yet when it notifies, so
    // reading the window now would read the one it is about to leave, and
    // nothing would come along afterwards to correct it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pending = false;
      if (mounted) setState(() {});
    });
    // A notification does not always come with a frame of its own.
    WidgetsBinding.instance.scheduleFrame();
  }

  /// The candle a point [x] pixels across a strip [width] wide falls on.
  double _indexAt(double x, double width) {
    if (widget.candles.length < 2 || width <= 0) return 0;
    final span = widget.candles.length - 1;
    return (x / width * span).clamp(0, span.toDouble());
  }

  /// Where the candle at [index] sits across a strip [width] wide.
  double _xOf(num index, double width) {
    if (widget.candles.length < 2 || width <= 0) return 0;
    return index / (widget.candles.length - 1) * width;
  }

  void _onDown(Offset position, double width) {
    final range = widget.controller.visibleRange;
    if (range == null) return;

    _grabFirst = range.firstIndex;
    _grabLast = range.lastIndex;
    _grabAt = _indexAt(position.dx, width);

    final left = _xOf(_grabFirst, width);
    final right = _xOf(_grabLast, width);
    final half = widget.handleWidth / 2;

    if ((position.dx - left).abs() <= half) {
      _grab = _Grab.left;
    } else if ((position.dx - right).abs() <= half) {
      _grab = _Grab.right;
    } else if (position.dx > left && position.dx < right) {
      _grab = _Grab.window;
    } else {
      // A tap outside the window centres it there, then keeps panning.
      _grab = _Grab.window;
      final span = _grabLast - _grabFirst;
      final centre = _grabAt.round();
      _grabFirst = centre - span ~/ 2;
      _grabLast = _grabFirst + span;
      _grabAt = centre.toDouble();
      _show(_grabFirst, _grabLast);
    }
  }

  void _onMove(Offset position, double width) {
    if (_grab == _Grab.none) return;
    final at = _indexAt(position.dx, width);

    switch (_grab) {
      case _Grab.window:
        final shift = (at - _grabAt).round();
        _show(_grabFirst + shift, _grabLast + shift);
      case _Grab.left:
        _show(at.round(), _grabLast);
      case _Grab.right:
        _show(_grabFirst, at.round());
      case _Grab.none:
        return;
    }
  }

  /// Moves the chart's window to [first]–[last], keeping it inside the data.
  ///
  /// A pan that would run off either end slides back rather than shrinking, so
  /// dragging to the edge keeps the window the width it was.
  void _show(int first, int last) {
    final total = widget.candles.length;
    if (total == 0) return;

    var from = first;
    var to = last;
    if (_grab == _Grab.window) {
      final span = to - from;
      if (from < 0) {
        from = 0;
        to = math.min(span, total - 1);
      }
      if (to > total - 1) {
        to = total - 1;
        from = math.max(0, to - span);
      }
    } else {
      from = from.clamp(0, total - 1);
      to = to.clamp(0, total - 1);
      // An edge dragged past the other one takes it with it rather than
      // inverting the window.
      if (from > to) (from, to) = (to, from);
    }

    widget.controller.showRange(from, to);
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors ?? ChartColors();
    final range = widget.controller.visibleRange;

    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragDown: (d) => _onDown(d.localPosition, width),
            onHorizontalDragUpdate: (d) => _onMove(d.localPosition, width),
            onHorizontalDragEnd: (_) => _grab = _Grab.none,
            onHorizontalDragCancel: () => _grab = _Grab.none,
            onTapDown: (d) => _onDown(d.localPosition, width),
            onTapUp: (_) => _grab = _Grab.none,
            child: CustomPaint(
              size: Size(width, widget.height),
              painter: _OverviewPainter(
                candles: widget.candles,
                colors: colors,
                firstVisible: range?.firstIndex,
                lastVisible: range?.lastIndex,
                padding: widget.padding,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// What a drag on the strip is moving.
enum _Grab { none, window, left, right }

/// Draws the history as a filled line, with everything outside the window
/// washed over.
class _OverviewPainter extends CustomPainter {
  const _OverviewPainter({
    required this.candles,
    required this.colors,
    required this.firstVisible,
    required this.lastVisible,
    required this.padding,
  });

  final List<KLineEntity> candles;
  final ChartColors colors;
  final int? firstVisible;
  final int? lastVisible;
  final EdgeInsets padding;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = colors.bgColor);
    if (candles.length < 2 || size.width <= 0) return;

    var low = double.maxFinite;
    var high = -double.maxFinite;
    for (final candle in candles) {
      low = math.min(low, candle.close);
      high = math.max(high, candle.close);
    }
    // A flat history has no range to scale by; it draws down the middle.
    final span = high - low;
    final top = padding.top;
    final usable = math.max(1.0, size.height - padding.vertical);

    double yOf(double close) => span <= 0
        ? top + usable / 2
        : top + usable - (close - low) / span * usable;
    double xOf(int index) => index / (candles.length - 1) * size.width;

    final line = Path()..moveTo(0, yOf(candles.first.close));
    for (var i = 1; i < candles.length; i++) {
      line.lineTo(xOf(i), yOf(candles[i].close));
    }

    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas
      ..drawPath(area, Paint()..color = colors.lineFillColor)
      ..drawPath(
        line,
        Paint()
          ..color = colors.kLineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

    final first = firstVisible;
    final last = lastVisible;
    if (first == null || last == null) return;

    final left = xOf(first.clamp(0, candles.length - 1));
    final right = xOf(last.clamp(0, candles.length - 1));

    // Wash over what is not on screen, so the window reads as the lit part.
    //
    // The wash is the background's own colour, which on a dark theme is dark
    // over dark and barely tells — so the window is *also* lifted by a tint of
    // its own and bracketed by two bright edges. Between the three it reads
    // whichever way round the theme runs.
    final scrim = Paint()..color = colors.bgColor.withValues(alpha: 0.72);
    if (left > 0) {
      canvas.drawRect(Rect.fromLTRB(0, 0, left, size.height), scrim);
    }
    if (right < size.width) {
      canvas.drawRect(Rect.fromLTRB(right, 0, size.width, size.height), scrim);
    }

    final window = Rect.fromLTRB(left, 0, right, size.height);
    canvas
      ..drawRect(
        window,
        Paint()..color = colors.kLineColor.withValues(alpha: 0.14),
      )
      ..drawRect(
        window,
        Paint()
          ..color = colors.defaultTextColor.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

    // The two edges are what a drag resizes, so they are drawn heavier.
    final handle = Paint()
      ..color = colors.defaultTextColor
      ..strokeWidth = 2.5;
    canvas
      ..drawLine(Offset(left, 0), Offset(left, size.height), handle)
      ..drawLine(Offset(right, 0), Offset(right, size.height), handle);
  }

  @override
  bool shouldRepaint(_OverviewPainter old) =>
      old.firstVisible != firstVisible ||
      old.lastVisible != lastVisible ||
      old.candles.length != candles.length ||
      !identical(old.candles, candles) ||
      old.colors != colors;
}
