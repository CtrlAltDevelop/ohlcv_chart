/// The part every plot-style chart repeats: a box that finds its own size, an
/// entry animation, a pointer that is turned into one hit, and a tooltip
/// placed beside it.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../renderer/text_painter_cache.dart';
import 'xy_plot.dart';

/// Paints the chart for a [PlotScaffold].
///
/// [plot] is the area the chart draws in, [animation] how far the entry
/// animation has got (0 to 1), and [hovered] what the pointer is over, or null.
typedef PlotPainterBuilder<T extends Object> =
    CustomPainter Function(
      Rect plot,
      double animation,
      TextPainterCache text,
      T? hovered,
    );

/// A box that holds a chart's plot, its hover and its tooltip.
///
/// The chart supplies how to paint, and what a pointer at a place is over; this
/// does the sizing, the animation and the touch plumbing every chart of the
/// kind would otherwise write out again.
class PlotScaffold<T extends Object> extends StatefulWidget {
  /// Creates a scaffold.
  const PlotScaffold({
    super.key,
    required this.restartKey,
    required this.painter,
    required this.hitTest,
    required this.keyOf,
    this.anchorOf,
    this.tooltipBuilder,
    this.onTouch,
    this.animationDuration = Duration.zero,
    this.animationCurve = Curves.easeOutCubic,
    this.animateOnMount = true,
    this.padding = EdgeInsets.zero,
    this.insets = EdgeInsets.zero,
    this.backgroundColor,
    this.defaultHeight = 260,
    this.tooltipMargin = 10,
    this.semanticLabel,
  });

  /// A value that changes when — and only when — the data does, so the entry
  /// animation runs again for new numbers and not for the same ones in a new
  /// list. Usually `Object.hashAll` of the data.
  final Object restartKey;

  /// Paints the chart.
  final PlotPainterBuilder<T> painter;

  /// What the pointer at [Offset] is over, in the plot [Rect]; null for
  /// nothing.
  final T? Function(Offset local, Rect plot) hitTest;

  /// What identifies a hit, so a pointer moving within one thing reports once.
  final Object Function(T hit) keyOf;

  /// Where a hit is, for placing its tooltip; null puts none.
  final Rect Function(T hit, Rect plot)? anchorOf;

  /// Builds a card for a hit; null shows none.
  final Widget? Function(BuildContext context, T hit)? tooltipBuilder;

  /// Called as the pointer moves over things, and with null as it leaves.
  final ValueChanged<T?>? onTouch;

  /// How long the entry animation takes; zero draws at once.
  final Duration animationDuration;

  /// The easing of [animationDuration].
  final Curve animationCurve;

  /// Whether the first build animates.
  final bool animateOnMount;

  /// Space kept clear around the chart.
  final EdgeInsets padding;

  /// Room inside [padding] taken by axes and titles, so the plot is smaller
  /// than the box by this much on each side.
  final EdgeInsets insets;

  /// Painted behind the whole chart.
  final Color? backgroundColor;

  /// The height taken in a box that sets none.
  final double defaultHeight;

  /// How far the tooltip sits from what it is about.
  final double tooltipMargin;

  /// What a screen reader announces.
  final String? semanticLabel;

  @override
  State<PlotScaffold<T>> createState() => _PlotScaffoldState<T>();
}

class _PlotScaffoldState<T extends Object> extends State<PlotScaffold<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 96);
  T? _hovered;
  Object? _hoveredKey;
  Rect _plot = Rect.zero;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
      value: 1,
    )..addListener(() => setState(() {}));
    if (widget.animateOnMount && widget.animationDuration > Duration.zero) {
      _animation.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(PlotScaffold<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
    if (oldWidget.restartKey != widget.restartKey) {
      _hovered = null;
      _hoveredKey = null;
      if (widget.animationDuration > Duration.zero) {
        _animation.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _animation.dispose();
    super.dispose();
  }

  void _handle(Offset local) {
    final hit = widget.hitTest(local, _plot);
    final key = hit == null ? null : widget.keyOf(hit);
    if (key == _hoveredKey) return;
    setState(() {
      _hovered = hit;
      _hoveredKey = key;
    });
    widget.onTouch?.call(hit);
  }

  void _leave() {
    if (_hoveredKey == null) return;
    setState(() {
      _hovered = null;
      _hoveredKey = null;
    });
    widget.onTouch?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.animationCurve.transform(_animation.value);

    Widget chart = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.maybeSizeOf(context)?.width ?? 300;
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : widget.defaultHeight;
        final box = widget.padding.deflateRect(
          Offset.zero & Size(width, height),
        );
        final inset = widget.insets;
        _plot = Rect.fromLTRB(
          box.left + inset.left,
          box.top + inset.top,
          math.max(box.left + inset.left, box.right - inset.right),
          math.max(box.top + inset.top, box.bottom - inset.bottom),
        );

        final hovered = _hovered;
        final anchor = widget.anchorOf;
        final builder = widget.tooltipBuilder;
        final tooltip = hovered == null || builder == null
            ? null
            : builder(context, hovered);

        return SizedBox(
          width: width,
          height: height,
          child: MouseRegion(
            onHover: (e) => _handle(e.localPosition),
            onExit: (_) => _leave(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _handle(d.localPosition),
              onTapUp: (_) => _leave(),
              onTapCancel: _leave,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: widget.painter(_plot, t, _text, hovered),
                    ),
                  ),
                  if (tooltip != null && hovered != null && anchor != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomSingleChildLayout(
                          delegate: XyTooltipLayout(
                            anchor: anchor(hovered, _plot),
                            margin: widget.tooltipMargin,
                          ),
                          child: tooltip,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );

    final label = widget.semanticLabel;
    if (label != null) {
      chart = Semantics(container: true, label: label, child: chart);
    }
    return chart;
  }
}

/// A painter that repaints whenever it is replaced.
///
/// The scaffold builds a new painter for every frame it changes on, so a
/// comparison of fields would only repeat the scaffold's own bookkeeping.
abstract class PlotPainter extends CustomPainter {
  /// Creates a painter over [plot].
  PlotPainter({
    required this.plot,
    required this.animation,
    required this.text,
    this.backgroundColor,
  });

  /// Where the chart is drawn.
  final Rect plot;

  /// How far the entry animation has got, from 0 to 1.
  final double animation;

  /// Where labels are laid out.
  final TextPainterCache text;

  /// Painted behind everything.
  final Color? backgroundColor;

  /// Paints the chart itself; [size] is the whole box.
  void paintPlot(Canvas canvas, Size size);

  @override
  void paint(Canvas canvas, Size size) {
    final background = backgroundColor;
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
    }
    if (plot.width <= 0 || plot.height <= 0) return;
    paintPlot(canvas, size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
