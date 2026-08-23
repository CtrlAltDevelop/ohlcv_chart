import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

import 'chart_theme.dart';
import 'market_data.dart';

/// Which line the drawing palette is currently placing.
///
/// Mirrors `DrawingTool`, plus the package's own `none`.
typedef Tool = DrawingTool;

/// How the demo rewrites the candles before drawing them.
enum Aggregation {
  /// The candles as they came.
  none,

  /// Averaged with the candle before, through `CandleTransforms.heikinAshi`.
  heikinAshi,

  /// Laid out as bricks, through `CandleTransforms.renko`.
  renko,
}

/// Every switch the demo exposes, in one listenable place.
///
/// The demo mutates fields directly and calls [update], which keeps the widget
/// tree small enough to read as documentation for the package's own API.
class DemoState extends ChangeNotifier {
  DemoState() {
    _candles = MarketData.candles();
    drawings.save(
      HorizontalLine(
        price: _candles[_candles.length - 30].close,
        title: 'entry',
        color: const Color(0xFF4DABF7),
        style: LineStyle.dashed,
        showLabel: true,
        alert: true,
      ),
    );
    drawings.clearHistory();
    drawings.addListener(notifyListeners);
    replay.addListener(notifyListeners);
  }

  late List<KLineEntity> _candles;

  /// The candles handed to the chart, oldest first.
  ///
  /// Heikin-Ashi and Renko are transforms of the data rather than ways of
  /// drawing it, so they happen here — and the result is cached, because the
  /// chart asks for it on every build.
  List<KLineEntity> get candles {
    if (aggregation == Aggregation.none) return _candles;
    final cached = _aggregated;
    if (cached != null &&
        _aggregatedFrom == aggregation &&
        _aggregatedLength == _candles.length &&
        _aggregatedLast == _candles.last.close) {
      return cached;
    }

    final transformed = switch (aggregation) {
      Aggregation.none => _candles,
      Aggregation.heikinAshi => CandleTransforms.heikinAshi(_candles),
      Aggregation.renko => CandleTransforms.renko(
        _candles,
        brickSize:
            CandleTransforms.atrBrickSize(_candles) ??
            _candles.last.close * 0.005,
      ),
    };
    // The transform hands back plain candles, so the indicators have to be
    // computed over them again.
    DataUtil.calculate(transformed);

    _aggregated = transformed;
    _aggregatedFrom = aggregation;
    _aggregatedLength = _candles.length;
    _aggregatedLast = _candles.last.close;
    return transformed;
  }

  List<KLineEntity>? _aggregated;
  Aggregation? _aggregatedFrom;
  int? _aggregatedLength;
  double? _aggregatedLast;

  // ── Appearance ──────────────────────────────────────────────────────────
  bool dark = true;
  bool hollowCandles = false;
  bool hideGrid = false;
  bool volHidden = false;
  bool showNowPrice = true;
  bool axisOnRight = false;
  bool german = false;
  int fixedLength = 2;

  /// What the candle area draws for each candle.
  ChartType chartType = ChartType.candles;

  /// How the price axis is spaced and read out.
  PriceAxisScale priceAxisScale = PriceAxisScale.linear;

  /// How the candles are rewritten before they are drawn.
  Aggregation aggregation = Aggregation.none;

  /// Whether the candle's values are read out above the chart.
  bool showOhlcLegend = true;

  /// Whether a resting mouse carries the crosshair.
  bool crosshairOnHover = true;

  /// Whether each day starts with a divider.
  bool sessionDividers = false;

  /// Which zone the chart shows its dates in.
  Duration timeZoneOffset = Duration.zero;

  /// Whether an indicator pane can be dragged taller or shorter.
  bool resizablePanes = true;

  /// Whether an indicator pane can be dragged up or down the stack.
  bool reorderablePanes = true;

  /// Whether dragging the price labels stretches the axis.
  bool priceScaleDrag = true;

  /// Whether the button back to the newest candle appears once the chart is
  /// scrolled away from it.
  bool scrollToNowButton = true;

  /// Whether the chart itself handles undo, redo and delete.
  bool keyboardShortcuts = true;

  /// Whether the baseline chart washes towards a fixed price rather than the
  /// oldest close in view.
  bool pinnedBaseline = false;

  /// Whether the demo formats the date axis instead of the chart.
  bool customDateFormat = false;

  /// Empty space kept to the right of the newest candle.
  double frontPadding = 80;

  /// The level a [ChartType.baseline] chart is washed towards, or null to let
  /// the chart use the oldest close in view.
  double? get baselinePrice =>
      pinnedBaseline && candles.isNotEmpty ? candles.first.close : null;

  /// A date axis of the demo's own, wired to `KChartWidget.dateFormatter`.
  ///
  /// The chart hands over the candle and a flag marking the long form the
  /// crosshair wants; the time zone is ours to apply, since the formatter is
  /// given the candle as it came.
  String formatDate(KLineEntity candle, bool longForm) {
    final time = candle.dateTime?.add(timeZoneOffset);
    if (time == null) return '';
    final clock =
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
    if (!longForm) return clock;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${time.day} ${months[time.month - 1]} $clock';
  }

  // ── Indicators ──────────────────────────────────────────────────────────

  /// The configured indicators, in the order they were added.
  ///
  /// Several of one kind is the point: three ATRs with different periods are
  /// three panes, and each carries its own colours.
  final List<Indicator> indicators = [
    MaIndicator(period: 5),
    MaIndicator(period: 10),
    MaIndicator(period: 20),
    MacdIndicator(),
  ];

  // ── Depth chart ─────────────────────────────────────────────────────────

  /// Which picture of the order book the depth tab draws.
  DepthChartMode depthMode = DepthChartMode.cumulative;

  /// How the depth chart spaces its volume axis.
  DepthScale depthScale = DepthScale.linear;

  /// How far either side of the mid the depth chart looks, or null for all.
  double? depthZoom;

  // ── Drawing ─────────────────────────────────────────────────────────────
  DrawingTool tool = DrawingTool.none;
  bool magnetMode = false;
  bool brandedToolbar = false;

  /// Whether the palette stays armed after a drawing lands, so several of the
  /// same kind can be placed one after another.
  bool keepToolArmed = false;

  /// Every drawing on the chart, and its undo history.
  final ChartDrawingController drawings = ChartDrawingController();

  /// Drives the chart itself: zoom, scroll and capture.
  final KChartController chart = KChartController();

  /// Plays the candles back from a point in the past.
  final ChartReplayController replay = ChartReplayController();

  /// The last layout saved with [saveLayout].
  String? savedLayout;

  // ── Markers and readouts ────────────────────────────────────────────────
  bool showSignals = true;
  bool showInfoDialog = true;
  bool tapShowsInfoDialog = false;
  bool materialInfoDialog = true;
  bool customInfoDialog = false;

  // ── Live feed ───────────────────────────────────────────────────────────
  bool live = false;
  Timer? _ticker;
  final Random _random = Random(11);

  /// The most recent thing the chart told the demo, shown in the status bar.
  String status = 'Long-press the chart for the readout';

  /// How many candles have been pulled in by `onLoadMore`.
  int loadedPages = 0;
  bool _loadingMore = false;

  /// Applies [mutate] and rebuilds everything listening.
  void update(VoidCallback mutate) {
    mutate();
    notifyListeners();
  }

  // ── Derived configuration for the chart ─────────────────────────────────

  /// Palette for the current brightness.
  ChartColors get colors =>
      dark ? ChartTheme.darkColors() : ChartTheme.lightColors();

  /// Geometry for the current candle style, plus the session dividers.
  ChartStyle get style {
    final base = hollowCandles ? ChartTheme.hollow : ChartTheme.filled;
    return base.copyWith(showSessionDividers: sessionDividers);
  }

  /// The line editor's configuration.
  DrawingStyle get drawingStyle =>
      brandedToolbar ? ChartTheme.brandedDrawing : ChartTheme.defaultDrawing;

  /// Depth-chart palette for the current brightness.
  DepthChartColors get depthColors =>
      dark ? ChartTheme.darkDepth : ChartTheme.lightDepth;

  /// Chart labels, including the drawing editor's, in the chosen language.
  ChartTranslations get translations => german
      ? const ChartTranslations(
          date: 'Datum',
          open: 'Eröffnung',
          high: 'Hoch',
          low: 'Tief',
          close: 'Schluss',
          changeAmount: 'Änderung',
          change: 'Änderung%',
          changeLive: 'Änderung% live',
          amount: 'Umsatz',
          vol: 'Volumen',
          jumpToNow: 'Zur letzten Kerze',
          drawing: DrawingTranslations(
            color: 'Farbe',
            opacity: 'Deckkraft',
            thickness: 'Stärke',
            lineStyle: 'Stil',
            solid: 'Durchgezogen',
            dashed: 'Gestrichelt',
            dotted: 'Gepunktet',
            label: 'Beschriftung',
            labelHint: 'Text',
            showLabel: 'Beschriftung zeigen',
            hideLabel: 'Beschriftung ausblenden',
            lock: 'Sperren',
            unlock: 'Entsperren',
            fill: 'Füllung',
            alert: 'Alarm setzen',
            clearAlert: 'Alarm entfernen',
            delete: 'Löschen',
            done: 'Fertig',
            move: 'Werkzeugleiste verschieben',
            drawings: 'Zeichnungen',
            noDrawings: 'Noch nichts gezeichnet',
            undo: 'Zurück',
            redo: 'Vor',
            clearAll: 'Alle löschen',
            show: 'Zeigen',
            hide: 'Ausblenden',
            horizontalLineName: 'Horizontale Linie',
            horizontalRayName: 'Horizontaler Strahl',
            verticalLineName: 'Vertikale Linie',
            trendLineName: 'Trendlinie',
            rayName: 'Strahl',
            extendedLineName: 'Verlängerte Linie',
            arrowName: 'Pfeil',
            rectangleName: 'Rechteck',
            ellipseName: 'Ellipse',
            triangleName: 'Dreieck',
            fibRetracementName: 'Fibonacci',
            measureName: 'Messung',
            channelName: 'Parallelkanal',
            longPositionName: 'Long-Position',
            shortPositionName: 'Short-Position',
            textName: 'Notiz',
            freehandName: 'Freihand',
            drawingName: 'Zeichnung',
          ),
        )
      : const ChartTranslations();

  /// Depth-chart labels in the chosen language.
  DepthChartTranslations get depthTranslations => german
      ? const DepthChartTranslations(price: 'Preis', amount: 'Menge')
      : const DepthChartTranslations();

  /// Take-profit, stop-loss and liquidation markers over the candles.
  List<SignalEntity> get signals {
    if (!showSignals) return const [];
    final last = candles.last.close;
    return [
      SignalEntity(title: 'TP', price: last * 1.045, color: colors.upColor),
      SignalEntity(
        title: 'SL',
        price: last * 0.965,
        color: colors.dnColor,
        useDash: true,
      ),
    ];
  }

  // ── Data mutation ───────────────────────────────────────────────────────

  /// Starts or stops the simulated feed, which walks the newest candle's close
  /// and rolls a fresh candle over every time frame.
  void setLive(bool value) {
    live = value;
    _ticker?.cancel();
    _ticker = value
        ? Timer.periodic(const Duration(milliseconds: 700), (_) => _tick())
        : null;
    notifyListeners();
  }

  void _tick() {
    final last = _candles.last;
    final drift = (_random.nextDouble() - 0.5) * 260;
    last.close = (last.close + drift).clamp(1000.0, 1e6);
    last.high = max(last.high, last.close);
    last.low = min(last.low, last.close);
    last.vol += _random.nextDouble() * 6;

    final openedAt = last.dateTime;
    if (openedAt != null &&
        DateTime.now().difference(openedAt) > MarketData.timeFrame) {
      _candles.add(
        KLineEntity.fromCustom(
          open: last.close,
          high: last.close,
          low: last.close,
          close: last.close,
          vol: 1,
          dateTime: openedAt.add(MarketData.timeFrame),
        ),
      );
    }

    // Indicators are plain fields on the candles, so they need recomputing
    // whenever the data changes.
    DataUtil.calculate(_candles);
    notifyListeners();
  }

  /// Prepends a page of older candles, as a paginating app would.
  Future<void> loadOlder() async {
    if (_loadingMore) return;
    _loadingMore = true;
    status = 'Loading older candles…';
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 400));
    _candles = MarketData.olderThan(_candles, count: 80);
    DataUtil.calculate(_candles);
    loadedPages++;
    status = 'Loaded ${_candles.length} candles';
    _loadingMore = false;
    notifyListeners();
  }

  /// Adds [indicator], or restyles the equal one already on the chart.
  ///
  /// `upsert` is what stops a second ATR(14) stacking up behind the first: an
  /// indicator is identified by its type and settings, so re-adding one with a
  /// new colour edits the pane that is already there.
  void addIndicator(Indicator indicator) {
    final replaced = indicators.upsert(indicator);
    status = replaced
        ? '${indicator.label} updated'
        : '${indicator.label} added';
    notifyListeners();
  }

  /// Takes [indicator] off the chart.
  void removeIndicator(Indicator indicator) {
    indicators.remove(indicator);
    status = '${indicator.label} removed';
    notifyListeners();
  }

  /// Moves the pane at [from] to [to], which is what the chart reports when one
  /// is dragged up or down the stack.
  void reorderPane(int from, int to) {
    // The panes are the indicators that are not overlays, in order, so the
    // move has to be mapped back onto the full list.
    final paneIndices = [
      for (var i = 0; i < indicators.length; i++)
        if (indicators[i].placement != IndicatorPlacement.overlay) i,
    ];
    if (from >= paneIndices.length || to >= paneIndices.length) return;

    final indicator = indicators.removeAt(paneIndices[from]);
    indicators.insert(paneIndices[to], indicator);
    status = '${indicator.label} moved';
    notifyListeners();
  }

  // ── Drawings ────────────────────────────────────────────────────────────

  /// Notes a drawing the user just placed or edited.
  ///
  /// The chart has already written it to [drawings]; all that is left is to say
  /// so, and to put the palette away unless the user asked to keep drawing.
  void noteSaved(ChartLine line) {
    if (!keepToolArmed) tool = DrawingTool.none;
    status = '${translations.drawing.nameOf(line)} saved — tap it to restyle';
    notifyListeners();
  }

  /// Notes a drawing the user deleted.
  void noteRemoved(ChartLine line) {
    status = '${translations.drawing.nameOf(line)} removed';
    notifyListeners();
  }

  /// Notes a level the market has just crossed.
  void noteAlert(HorizontalLine line, KLineEntity candle) {
    status =
        'Alert: ${line.title ?? line.price.toStringAsFixed(fixedLength)} '
        'crossed at ${candle.close.toStringAsFixed(fixedLength)}';
    notifyListeners();
  }

  /// How many drawings are currently on the chart.
  int get drawingCount => drawings.length;

  /// Saves the layout as JSON, the way an app would put it in storage.
  void saveLayout() {
    savedLayout = jsonEncode(drawings.toJson());
    status = 'Layout saved — ${savedLayout!.length} bytes of JSON';
    notifyListeners();
  }

  /// Puts a saved layout back, as one undoable step.
  void loadLayout() {
    final saved = savedLayout;
    if (saved == null) return;
    drawings.load(jsonDecode(saved) as Map<String, dynamic>);
    status = 'Layout restored from JSON';
    notifyListeners();
  }

  /// The chart as a PNG, for sharing or saving.
  Future<Uint8List?> capture() async {
    final bytes = await chart.capture();
    status = bytes == null
        ? 'Nothing to capture yet'
        : 'Captured ${(bytes.length / 1024).round()} KiB of PNG';
    notifyListeners();
    return bytes;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    drawings
      ..removeListener(notifyListeners)
      ..dispose();
    chart.dispose();
    replay
      ..removeListener(notifyListeners)
      ..dispose();
    super.dispose();
  }
}
