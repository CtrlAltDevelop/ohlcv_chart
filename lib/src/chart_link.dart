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
/// means here. The crosshair is not: it is the chart's own gesture state and
/// has no callback to hang this on.
///
/// The price axis is deliberately left alone too. Two instruments at different
/// prices share no sensible vertical scale, and forcing one would leave a chart
/// showing a flat line off the top of its pane.
class ChartLink {
  /// Creates a link with no charts on it yet.
  ChartLink();

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
    void listener() => _spreadFrom(controller);
    _following[controller] = listener;
    controller.addListener(listener);
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
    final range = source.visibleRange;
    if (range == null) return;

    _applying = true;
    try {
      for (final other in _following.keys) {
        if (identical(other, source)) continue;
        final current = other.visibleRange;
        // Already there: moving it again would only churn a repaint.
        if (current != null &&
            current.firstIndex == range.firstIndex &&
            current.lastIndex == range.lastIndex) {
          continue;
        }
        other.showRange(range.firstIndex, range.lastIndex);
      }
    } finally {
      _applying = false;
    }
  }
}
