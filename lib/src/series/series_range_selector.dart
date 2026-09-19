import 'dart:math' as math;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/widgets.dart';

import 'series_axis.dart';
import 'series_chart.dart';
import 'series_data.dart';

/// A stretch of x, from [start] to [end].
@immutable
class SeriesWindow {
  /// Creates the window [start]–[end].
  const SeriesWindow(this.start, this.end);

  /// The first x in the window.
  final double start;

  /// The last x in the window.
  final double end;

  /// How much x the window covers.
  double get span => end - start;

  @override
  bool operator ==(Object other) =>
      other is SeriesWindow && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'SeriesWindow($start, $end)';
}

/// A small chart of a whole series with a window over it that can be dragged
/// and resized — the strip under a chart that shows only part of its data.
///
/// Drag inside the window to move it, or drag either handle to move that edge.
/// The window itself is yours: show it on the main chart through its `minX`
/// and `maxX`, and keep the one [onChanged] reports.
///
/// ```dart
/// SeriesChart(series: series, minX: window.start - .5, maxX: window.end + .5);
/// SeriesRangeSelector(
///   series: series,
///   window: window,
///   minSpan: 4,
///   onChanged: (next) => setState(() => window = next),
/// );
/// ```
class SeriesRangeSelector extends StatefulWidget {
  /// Creates a range selector over [series].
  const SeriesRangeSelector({
    super.key,
    required this.series,
    required this.window,
    required this.onChanged,
    this.minSpan = 1,
    this.height = 52,
    this.xPadding = 0.5,
    this.border = const BorderSide(color: seriesGridColor),
    this.maskColor = const Color(0x99000000),
    this.windowBorderColor = const Color(0xFF909196),
    this.handleColor = const Color(0xFFFFFFFF),
    this.handleBorderColor = const Color(0xFF909196),
    this.handleGripColor = const Color(0xFF909196),
  });

  /// The whole data set, drawn small.
  final List<PlotSeries> series;

  /// The part of it the main chart shows.
  final SeriesWindow window;

  /// Called with the new window while it is dragged.
  final ValueChanged<SeriesWindow> onChanged;

  /// The narrowest the window may be made, in x units.
  final double minSpan;

  /// The selector's height.
  final double height;

  /// Room either side of the data, in x units.
  final double xPadding;

  /// A line around the small chart; null draws none.
  final BorderSide? border;

  /// Shade over the parts outside the window.
  final Color maskColor;

  /// Lines along the top and bottom of the window.
  final Color windowBorderColor;

  /// Handle fill.
  final Color handleColor;

  /// Handle outline.
  final Color handleBorderColor;

  /// The two grip lines on each handle.
  final Color handleGripColor;

  @override
  State<SeriesRangeSelector> createState() => _SeriesRangeSelectorState();
}

class _SeriesRangeSelectorState extends State<SeriesRangeSelector> {
  static const double _handleWidth = 10;
  static const double _handleHitWidth = 28;

  /// The window as it was when the current drag began, and where the finger
  /// was then. Every update is measured from here rather than added up from
  /// deltas, so the drag neither loses its slop nor drifts from the finger.
  SeriesWindow? _dragFrom;
  double _dragOrigin = 0;

  void _begin(DragStartDetails details) {
    _dragFrom = widget.window;
    _dragOrigin = details.globalPosition.dx;
  }

  void _end([Object? _]) => _dragFrom = null;

  @override
  Widget build(BuildContext context) {
    var low = double.infinity;
    var high = double.negativeInfinity;
    for (final s in widget.series) {
      for (final p in s.points) {
        low = math.min(low, p.x);
        high = math.max(high, p.x);
      }
    }
    if (!(high > low)) return SizedBox(height: widget.height);

    final domainStart = low - widget.xPadding;
    final domainEnd = high + widget.xPadding;
    final domain = domainEnd - domainStart;
    final minSpan = math.min(widget.minSpan, high - low);

    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          double px(double x) => (x - domainStart) / domain * width;

          GestureDragUpdateCallback drag(
            SeriesWindow Function(SeriesWindow from, double units) move,
          ) => (details) {
            // A selector with no width has nothing to measure a drag against.
            if (width <= 0) return;
            final from = _dragFrom ?? widget.window;
            final units =
                (details.globalPosition.dx - _dragOrigin) / width * domain;
            final next = move(from, units);
            if (next != widget.window) widget.onChanged(next);
          };

          final pan = drag((from, units) {
            final span = from.span;
            final start = (from.start + units)
                .clamp(low, math.max(low, high - span))
                .toDouble();
            return SeriesWindow(start, start + span);
          });
          final moveStart = drag((from, units) {
            final start = (from.start + units)
                .clamp(low, math.max(low, from.end - minSpan))
                .toDouble();
            return SeriesWindow(start, from.end);
          });
          final moveEnd = drag((from, units) {
            final end = (from.end + units)
                .clamp(math.min(from.start + minSpan, high), high)
                .toDouble();
            return SeriesWindow(from.start, end);
          });

          final startPx = px(widget.window.start);
          final endPx = px(widget.window.end);

          return Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: SeriesChart(
                    series: widget.series,
                    xAxis: SeriesXAxis.hidden,
                    yAxis: SeriesYAxis.hidden,
                    grid: SeriesGrid.none,
                    border: widget.border,
                    minX: domainStart,
                    maxX: domainEnd,
                    yPadding: 0.05,
                    touch: null,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: math.max(0, startPx),
                child: ColoredBox(color: widget.maskColor),
              ),
              Positioned(
                left: endPx,
                top: 0,
                bottom: 0,
                right: 0,
                child: ColoredBox(color: widget.maskColor),
              ),
              Positioned(
                left: startPx,
                top: 0,
                bottom: 0,
                width: math.max(0, endPx - startPx),
                child: _draggable(
                  onUpdate: pan,
                  cursor: SystemMouseCursors.grab,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.symmetric(
                        horizontal: BorderSide(color: widget.windowBorderColor),
                      ),
                    ),
                  ),
                ),
              ),
              _handle(startPx, moveStart),
              _handle(endPx, moveEnd),
            ],
          );
        },
      ),
    );
  }

  Widget _draggable({
    required GestureDragUpdateCallback onUpdate,
    required MouseCursor cursor,
    required Widget child,
  }) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    dragStartBehavior: DragStartBehavior.down,
    onHorizontalDragStart: _begin,
    onHorizontalDragUpdate: onUpdate,
    onHorizontalDragEnd: _end,
    onHorizontalDragCancel: _end,
    child: MouseRegion(cursor: cursor, child: child),
  );

  Widget _handle(
    double centre,
    GestureDragUpdateCallback onUpdate,
  ) => Positioned(
    left: centre - _handleHitWidth / 2,
    top: 0,
    bottom: 0,
    width: _handleHitWidth,
    child: _draggable(
      onUpdate: onUpdate,
      cursor: SystemMouseCursors.resizeLeftRight,
      child: Center(
        child: Container(
          width: _handleWidth,
          height: 22,
          decoration: BoxDecoration(
            color: widget.handleColor,
            border: Border.all(color: widget.handleBorderColor),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 1, height: 10, color: widget.handleGripColor),
              const SizedBox(width: 2),
              Container(width: 1, height: 10, color: widget.handleGripColor),
            ],
          ),
        ),
      ),
    ),
  );
}
