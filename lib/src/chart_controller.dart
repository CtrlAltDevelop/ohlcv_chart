import 'package:flutter/foundation.dart';

import 'entity/k_line_entity.dart';
import 'visible_range.dart';

/// What a [KChartController] needs the chart to be able to do.
///
/// Implemented by `KChartWidget`'s state; there is nothing here for an app to
/// implement itself.
abstract interface class KChartHost {
  /// How far the chart is zoomed in.
  double get chartScale;

  /// Zooms the chart to [scale].
  void setChartScale(double scale);

  /// Scrolls back to the newest candle.
  void scrollChartToNow({required bool animated});

  /// Whether the newest candle is in view.
  bool get isChartAtRightEdge;

  /// The candle area as a PNG.
  Future<Uint8List?> captureChart({required double pixelRatio});

  /// How far the price axis is stretched away from the window it would fit.
  double get chartPriceZoom;

  /// Stretches the price axis to [zoom], within the range the chart allows.
  void setChartPriceZoom(double zoom);

  /// Fits the price axis back to the window.
  void resetChartPriceScale();

  /// Which candles the chart is showing, or null when it is showing none.
  ChartVisibleRange? get chartVisibleRange;

  /// Shows the candles from [firstIndex] to [lastIndex], both inclusive.
  ///
  /// Reports whether it could: a chart that has not been laid out yet, or one
  /// with no candles, cannot be moved anywhere.
  bool showChartRange(int firstIndex, int lastIndex);

  /// Puts the candle at [index] in the middle of the window, keeping the zoom.
  bool scrollChartTo(int index, {required bool animated});

  /// Zooms out until every candle fits, and scrolls to the newest.
  bool fitChartToData();

  /// Which candle the crosshair is on, or null when there is none up.
  int? get chartCrosshairIndex;

  /// What price the crosshair sits at, or null when there is none up.
  double? get chartCrosshairPrice;

  /// Puts the crosshair on the candle at [index], or takes it down for null.
  ///
  /// [price] sets how high up it sits; left off, it rests mid-pane.
  void showChartCrosshair(int? index, {double? price});

  /// How far the price axis is shifted from where it would sit.
  double get chartPricePan;

  /// Shifts the price axis to [pan], within the range the chart allows.
  void setChartPricePan(double pan);
}

/// Drives a chart from outside it: where it is scrolled, how far it is zoomed,
/// and what it looks like as an image.
///
/// Hand one to `KChartWidget.controller` and hold on to it:
///
/// ```dart
/// final chart = KChartController();
///
/// // …
/// chart.scrollToNow();                   // jump back to the live candle
/// chart.zoomIn();
/// final png = await chart.capture();     // share or save the chart
/// ```
///
/// It is a [ChangeNotifier], so a button that should only be live while the
/// chart is scrolled away from now can listen for [isAtRightEdge] changing.
class KChartController extends ChangeNotifier {
  KChartHost? _host;

  /// Whether a chart is currently listening.
  ///
  /// Every method below does nothing while nothing is attached, so a controller
  /// used before its chart is built — or after it is disposed — is harmless.
  bool get isAttached => _host != null;

  /// Called by the chart as it is built.
  void attach(KChartHost host) {
    if (identical(_host, host)) return;
    _host = host;
    notifyListeners();
  }

  /// Called by the chart as it goes away.
  void detach(KChartHost host) {
    if (!identical(_host, host)) return;
    _host = null;
    notifyListeners();
  }

  /// Called by the chart when it has been scrolled or zoomed.
  void hostChanged() => notifyListeners();

  /// How far the chart is zoomed in; 1 is the natural candle width.
  double get scale => _host?.chartScale ?? 1.0;

  /// Zooms to [value], within the range the chart allows.
  void zoomTo(double value) => _host?.setChartScale(value);

  /// Zooms in by [step].
  void zoomIn([double step = 0.2]) => zoomTo(scale + step);

  /// Zooms out by [step].
  void zoomOut([double step = 0.2]) => zoomTo(scale - step);

  /// Whether the newest candle is in view.
  bool get isAtRightEdge => _host?.isChartAtRightEdge ?? true;

  /// Scrolls back to the newest candle.
  void scrollToNow({bool animated = true}) =>
      _host?.scrollChartToNow(animated: animated);

  /// The candle area as PNG bytes, or null when there is no chart to capture.
  ///
  /// The image holds the chart itself — candles, indicators, drawings — and not
  /// the line editor or any other control floating over it.
  Future<Uint8List?> capture({double pixelRatio = 3}) async =>
      _host?.captureChart(pixelRatio: pixelRatio);

  /// How far the price axis is stretched away from the window it would fit.
  ///
  /// 1 is the fitted range, which is where a chart starts and what
  /// [resetPriceScale] returns it to. Above 1 the same prices take more room
  /// and the candles are taller; below 1 the window opens out.
  double get priceZoom => _host?.chartPriceZoom ?? 1.0;

  /// Stretches the price axis to [value], within the range the chart allows.
  void setPriceZoom(double value) => _host?.setChartPriceZoom(value);

  /// Stretches the axis by [step], as dragging up its labels does.
  void stretchPrice([double step = 0.2]) => setPriceZoom(priceZoom + step);

  /// Compresses the axis by [step], as dragging down its labels does.
  void compressPrice([double step = 0.2]) => setPriceZoom(priceZoom - step);

  /// Fits the price axis back to the window, undoing any stretch or shift.
  ///
  /// The same thing a double-tap on the axis does.
  void resetPriceScale() => _host?.resetChartPriceScale();

  // ── The visible window ───────────────────────────────────────────────────

  /// Which candles the chart is showing, or null when there is nothing to show.
  ///
  /// Null until the chart has been laid out, so read it after the first frame —
  /// or listen for it through `KChartWidget.onVisibleRangeChanged`, which is
  /// what a "bars on screen" readout or a linked second chart wants.
  ChartVisibleRange? get visibleRange => _host?.chartVisibleRange;

  /// Shows the candles from [firstIndex] to [lastIndex], both inclusive.
  ///
  /// Zooms and scrolls together, so the window ends up holding exactly those
  /// candles — as near as the chart's zoom limits allow. Reports whether it
  /// could move at all.
  bool showRange(int firstIndex, int lastIndex) =>
      _host?.showChartRange(firstIndex, lastIndex) ?? false;

  /// Shows the candles between [from] and [to], by time.
  ///
  /// The window is widened to the candles either side where the two instants
  /// fall between candles, so what was asked for is always covered. Reports
  /// whether there were candles in that span to show.
  bool showTimeRange(List<KLineEntity> candles, DateTime from, DateTime to) {
    final range = indexRangeCovering(candles, from, to);
    return range == null ? false : showRange(range.$1, range.$2);
  }

  /// Puts the candle at [index] in the middle of the window.
  ///
  /// Keeps the zoom, so this scrolls rather than resizing the window.
  bool goToIndex(int index, {bool animated = true}) =>
      _host?.scrollChartTo(index, animated: animated) ?? false;

  /// Puts the candle at or nearest to [time] in the middle of the window.
  ///
  /// Reports whether there was a candle to go to.
  bool goToDate(
    List<KLineEntity> candles,
    DateTime time, {
    bool animated = true,
  }) {
    final index = indexNearest(candles, time);
    return index == null ? false : goToIndex(index, animated: animated);
  }

  /// Zooms out until every candle fits, and scrolls to the newest.
  ///
  /// Stops at the chart's own zoom-out limit, so a very long history may still
  /// not fit in one window.
  bool fitAll() => _host?.fitChartToData() ?? false;

  // ── The crosshair ────────────────────────────────────────────────────────

  /// Which candle the crosshair is on, or null when there is none up.
  ///
  /// A crosshair put up from here reads as one hovered rather than one held
  /// down, so it does not fight a press the user is making on the chart
  /// itself. Listen for it through `KChartWidget.onCrosshairChanged`.
  int? get crosshairIndex => _host?.chartCrosshairIndex;

  /// Puts the crosshair on the candle at [index], or takes it down for null.
  ///
  /// The index is clamped to the candles in view, so a crosshair pushed from a
  /// chart scrolled elsewhere lands at the near edge rather than vanishing.
  ///
  /// [price] sets how high up it sits. Left off, it rests mid-pane — which is
  /// what a chart of a different instrument wants, having no price in common
  /// with the one the pointer is over.
  void showCrosshair(int? index, {double? price}) =>
      _host?.showChartCrosshair(index, price: price);

  /// What price the crosshair sits at, or null when there is none up.
  double? get crosshairPrice => _host?.chartCrosshairPrice;

  /// Takes the crosshair down.
  void hideCrosshair() => showCrosshair(null);

  /// How far the price axis is shifted from where it would sit.
  ///
  /// 0 is unshifted, which is where a chart starts and what [resetPriceScale]
  /// returns it to. Dragging the axis moves this.
  double get pricePan => _host?.chartPricePan ?? 0;

  /// Shifts the price axis to [value], within the range the chart allows.
  void setPricePan(double value) => _host?.setChartPricePan(value);
}

/// The candles in [candles] that cover [from] to [to], as an index pair.
///
/// Widened outwards where the instants fall between candles, so the span asked
/// for is always covered. Null where there are no candles, or where the span
/// falls entirely outside them.
(int, int)? indexRangeCovering(
  List<KLineEntity> candles,
  DateTime from,
  DateTime to,
) {
  if (candles.isEmpty) return null;
  final start = from.isAfter(to) ? to : from;
  final end = from.isAfter(to) ? from : to;

  var first = -1;
  var last = -1;
  for (var i = 0; i < candles.length; i++) {
    final time = candles[i].dateTime;
    if (time == null) continue;
    // The last candle at or before the start, widening outwards.
    if (!time.isAfter(start)) first = i;
    if (!time.isAfter(end)) last = i;
    if (time.isAfter(end) && first == -1 && last == -1) break;
  }

  // A span that starts before the data still shows what there is of it.
  if (first == -1 && last == -1) {
    final firstTime = candles.first.dateTime;
    if (firstTime == null || firstTime.isAfter(end)) return null;
    return (0, candles.length - 1);
  }
  if (first == -1) first = 0;
  if (last == -1) last = first;
  return (first, last);
}

/// The candle in [candles] closest in time to [time], or null when there are
/// none with a time at all.
int? indexNearest(List<KLineEntity> candles, DateTime time) {
  int? best;
  Duration? closest;
  for (var i = 0; i < candles.length; i++) {
    final at = candles[i].dateTime;
    if (at == null) continue;
    final gap = at.difference(time).abs();
    if (closest == null || gap < closest) {
      closest = gap;
      best = i;
    }
  }
  return best;
}
