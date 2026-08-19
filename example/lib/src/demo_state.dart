import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

import 'chart_theme.dart';
import 'market_data.dart';

/// Which line the drawing palette is currently placing.
///
/// Mirrors `DrawingTool`, plus the package's own `none`.
typedef Tool = DrawingTool;

/// Every switch the demo exposes, in one listenable place.
///
/// The demo mutates fields directly and calls [update], which keeps the widget
/// tree small enough to read as documentation for the package's own API.
class DemoState extends ChangeNotifier {
  DemoState() {
    _candles = MarketData.candles();
    horizontalLines.add(
      HorizontalLine(
        price: _candles[_candles.length - 30].close,
        title: 'entry',
        color: const Color(0xFF4DABF7),
        style: LineStyle.dashed,
        showLabel: true,
      ),
    );
  }

  late List<KLineEntity> _candles;

  /// The candles handed to the chart, oldest first.
  List<KLineEntity> get candles => _candles;

  // ── Appearance ──────────────────────────────────────────────────────────
  bool dark = true;
  bool hollowCandles = false;
  bool isLine = false;
  bool hideGrid = false;
  bool volHidden = false;
  bool showNowPrice = true;
  bool axisOnRight = false;
  bool german = false;
  int fixedLength = 2;

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
  final List<TrendLine> trendLines = [];
  final List<HorizontalLine> horizontalLines = [];
  final List<VerticalLine> verticalLines = [];

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

  /// Geometry for the current candle style.
  ChartStyle get style => hollowCandles ? ChartTheme.hollow : ChartTheme.filled;

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
            delete: 'Löschen',
            done: 'Fertig',
            move: 'Werkzeugleiste verschieben',
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
    final last = _candles.last.close;
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

  /// Stores a line the user just drew or edited, replacing any earlier copy.
  void saveLine(ChartLine line) {
    switch (line) {
      case HorizontalLine():
        horizontalLines
          ..remove(line)
          ..add(line);
      case VerticalLine():
        verticalLines
          ..remove(line)
          ..add(line);
      case TrendLine():
        trendLines
          ..remove(line)
          ..add(line);
    }
    // Most trading apps drop out of placement mode once a line lands.
    tool = DrawingTool.none;
    status = '${_name(line)} saved — tap it to restyle';
    notifyListeners();
  }

  /// Forgets a line the user deleted from the editing toolbar.
  void removeLine(ChartLine line) {
    trendLines.remove(line);
    horizontalLines.remove(line);
    verticalLines.remove(line);
    status = '${_name(line)} removed';
    notifyListeners();
  }

  /// Removes every drawn line.
  void clearLines() {
    trendLines.clear();
    horizontalLines.clear();
    verticalLines.clear();
    status = 'Drawings cleared';
    notifyListeners();
  }

  /// How many lines are currently drawn.
  int get drawingCount =>
      trendLines.length + horizontalLines.length + verticalLines.length;

  static String _name(ChartLine line) => switch (line) {
    HorizontalLine() => 'Horizontal line',
    VerticalLine() => 'Vertical line',
    TrendLine() => 'Trend line',
    _ => 'Line',
  };

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
