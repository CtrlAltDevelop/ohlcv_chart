import 'package:flutter/foundation.dart';

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
}
