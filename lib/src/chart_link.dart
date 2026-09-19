import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'chart_controller.dart';

/// Keeps several charts looking at the same stretch of history.
///
/// Add each chart's [KChartController] and whichever one the user scrolls or
/// zooms carries the rest with it — for an instrument above its volume study,
/// or two instruments stacked to be compared over the same window.
///
/// ```dart
/// final price = KChartController();
/// final volume = KChartController();
/// final link = ChartLink()..add(price)..add(volume);
///
/// // …
///
/// @override
/// void dispose() {
///   link.dispose();
///   super.dispose();
/// }
/// ```
///
/// There is no leader: any chart the user moves becomes the one being followed
/// for as long as it is moving. A window pushed onto a chart is clamped to the
/// candles it actually has, so linking charts over histories of different
/// lengths lines them up as far as they overlap rather than refusing.
///
/// ## What is linked, and what is not
///
/// The visible window — which candles are on screen — and with it the zoom,
/// since showing the same number of candles across the same width is what zoom
/// means here.
///
/// The crosshair too, by candle rather than by pixel, so charts at different
/// widths still point at the same bar. Turn it off with `crosshair: false` for
/// charts that should scroll together but be read separately. A crosshair
/// pushed onto a chart reads as one hovered rather than one held down, so it
/// never takes the place of a press the user is making themselves.
///
/// ## The two that are off by default
///
/// [crosshairPrice] carries how high up the crosshair sits, and [priceScale]
/// carries the stretch and shift of the price axis. Both are only meaningful
/// between charts of **the same instrument**: two instruments at different
/// prices share no vertical scale, and forcing one leaves a chart drawing a
/// flat line off the top of its pane. Turn them on for a chart shown twice —
/// the same market at two zooms, say — and leave them off otherwise.
///
/// [ChartLink.all] turns on everything, for exactly that case.
class ChartLink {
  /// Creates a link with no charts on it yet.
  ///
  /// [window] carries the visible window and its zoom, and [crosshair] the
  /// candle the crosshair is on; both are on by default and are safe between
  /// any two charts. [crosshairPrice] and [priceScale] carry the vertical, and
  /// suit only charts of the same instrument — see the note above.
  ChartLink({
    this.window = true,
    this.crosshair = true,
    this.crosshairPrice = false,
    this.priceScale = false,
  });

  /// A link that carries everything, for charts of the same instrument.
  ChartLink.all()
    : window = true,
      crosshair = true,
      crosshairPrice = true,
      priceScale = true;

  /// Whether the visible window is carried between charts.
  final bool window;

  /// Whether the candle the crosshair is on is carried between charts.
  final bool crosshair;

  /// Whether the price the crosshair sits at is carried too.
  ///
  /// Does nothing while [crosshair] is off, there being no crosshair to place.
  final bool crosshairPrice;

  /// Whether the price axis's stretch and shift are carried between charts.
  final bool priceScale;

  final Map<KChartController, void Function()> _following = {};

  /// Guards against the push back: moving the others notifies them, and their
  /// notification would otherwise move this one straight back.
  bool _applying = false;

  /// The controllers being kept in step.
  List<KChartController> get controllers => List.unmodifiable(_following.keys);

  /// How many charts are linked.
  int get length => _following.length;

  /// Adds [controller], if it is not already on the link.
  void add(KChartController controller) {
    if (_following.containsKey(controller)) return;
    void listener() => _whenSafe(() => _spreadFrom(controller));
    _following[controller] = listener;
    controller.addListener(listener);
  }

  /// Runs [work] once the frame in flight is done.
  static void _afterFrame(void Function() work) =>
      WidgetsBinding.instance.addPostFrameCallback((_) => work());

  /// Runs [work] now, or after this frame if one is being built.
  ///
  /// A chart notifies its controller while it is building — attaching does it,
  /// and so does every scroll — and moving another chart from there would mark
  /// it dirty mid-build, which is an error. A frame's delay is invisible;
  /// throwing is not.
  static void _whenSafe(void Function() work) {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => work());
      return;
    }
    work();
  }

  /// Takes [controller] off the link, answering whether it was on it.
  bool remove(KChartController controller) {
    final listener = _following.remove(controller);
    if (listener == null) return false;
    controller.removeListener(listener);
    return true;
  }

  /// Stops listening to every chart.
  ///
  /// Call this from the `dispose` of whatever owns the link. The controllers
  /// themselves are left alone — they belong to whoever made them.
  void dispose() {
    for (final entry in _following.entries) {
      entry.key.removeListener(entry.value);
    }
    _following.clear();
  }

  /// Puts every other chart on [source]'s window, now.
  ///
  /// Useful once after the first frame, when a chart built later should join
  /// the others where they already are rather than waiting for a scroll.
  /// Answers whether there was a window to spread.
  bool syncFrom(KChartController source) {
    final range = source.visibleRange;
    if (range == null) return false;
    _spreadFrom(source);
    return true;
  }

  void _spreadFrom(KChartController source) {
    if (_applying) return;

    final range = window ? source.visibleRange : null;
    final at = crosshair ? source.crosshairIndex : null;
    final price = crosshairPrice ? source.crosshairPrice : null;
    // A crosshair that has just gone needs pushing as much as one that arrived,
    // so "nothing to say" is only when no half is being carried at all.
    if (range == null && !crosshair && !priceScale) return;

    _applying = true;
    try {
      for (final other in _following.keys) {
        if (identical(other, source)) continue;

        var movedWindow = false;
        if (range != null) {
          final current = other.visibleRange;
          // Already there: moving it again would only churn a repaint.
          if (current == null ||
              current.firstIndex != range.firstIndex ||
              current.lastIndex != range.lastIndex) {
            other.showRange(range.firstIndex, range.lastIndex);
            movedWindow = true;
          }
        }

        if (priceScale) {
          // Both setters ignore a value they already hold, so there is no
          // repaint to save by checking first.
          other
            ..setPriceZoom(source.priceZoom)
            ..setPricePan(source.pricePan);
        }

        if (!crosshair) continue;
        if (other.crosshairIndex == at &&
            (!crosshairPrice || other.crosshairPrice == price)) {
          continue;
        }

        if (movedWindow) {
          // A chart lands its new window on the next frame, and until it does
          // it still believes the old one — so a crosshair placed now would be
          // clamped into the stretch it was showing a moment ago, and stick
          // there. Waiting a frame puts it on the candle actually asked for.
          _afterFrame(() {
            if (_following.containsKey(other)) {
              other.showCrosshair(at, price: price);
            }
          });
        } else {
          other.showCrosshair(at, price: price);
        }
      }
    } finally {
      _applying = false;
    }
  }
}
