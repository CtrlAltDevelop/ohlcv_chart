import 'package:flutter/material.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

import 'controls.dart';
import 'demo_state.dart';
import 'market_data.dart';

/// The candlestick demo: the chart itself, a status bar and every switch the
/// package exposes.
class ChartPage extends StatelessWidget {
  /// Creates the candlestick demo over [state].
  const ChartPage({required this.state, super.key});

  /// The demo's settings.
  final DemoState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final chart = Column(
          children: [
            Expanded(child: _Chart(state: state)),
            _StatusBar(state: state),
          ],
        );

        // Wide windows put the controls beside the chart; narrow ones stack
        // them underneath, which is also how the chart itself is meant to be
        // laid out — it fills whatever box you give it.
        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 900) {
              return Column(
                children: [
                  SizedBox(height: constraints.maxHeight * 0.62, child: chart),
                  const Divider(height: 1),
                  Expanded(child: Controls(state: state)),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: chart),
                const VerticalDivider(width: 1),
                // The drawing manager is a plain widget: here it sits in a
                // side panel above the rest of the controls.
                SizedBox(
                  width: 320,
                  child: Column(
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight * 0.4,
                        ),
                        child: DrawingManager(
                          controller: state.drawings,
                          style: state.drawingStyle,
                          translations: state.translations.drawing,
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(child: Controls(state: state)),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _Chart extends StatelessWidget {
  const _Chart({required this.state});

  final DemoState state;

  @override
  Widget build(BuildContext context) {
    return KChartWidget(
      state.candles,
      state.colors,
      // Drawing tools stay enabled so a line can be selected and restyled at
      // any time; `tool` decides what the next tap or drag places.
      isTrendLine: true,
      watermarkAssetPath: 'assets/watermark.svg',
      timeFrame: MarketData.timeFrame,
      chartStyle: state.style,
      lockPriceScale: state.lockPriceScale,
      scrollEnabled: state.scrollEnabled,
      zoomEnabled: state.zoomEnabled,
      drawingStyle: state.drawingStyle,
      chartTranslations: state.translations,
      currentDrawingTool: state.tool,
      magnetMode: state.magnetMode,
      indicators: state.indicators,
      comparisons: state.comparisons,
      onVisibleRangeChanged: state.onVisibleRangeChanged,
      events: state.events,
      onEventTapped: state.onEventTapped,
      onIndicatorAlert: state.onIndicatorAlert,
      orders: state.orders,
      positions: state.positions,
      onOrderDragged: state.onOrderDragged,
      onOrderMoved: state.onOrderMoved,
      onOrderTapped: state.onOrderTapped,
      onPositionTapped: state.onPositionTapped,
      controller: state.chart,
      drawingController: state.drawings,
      chartType: state.chartType,
      priceAxisScale: state.priceAxisScale,
      session: state.tradingSession,
      candleColor: state.candleColor,
      invertPriceAxis: state.invertPriceAxis,
      showAverageClose: state.showAverageClose,
      showHighLowOnAxis: state.showHighLowOnAxis,
      priceScaleDrag: state.priceScaleDrag,
      replay: state.replay,
      showOhlcLegend: state.showOhlcLegend,
      crosshairOnHover: state.crosshairOnHover,
      timeZoneOffset: state.timeZoneOffset,
      resizablePanes: state.resizablePanes,
      reorderablePanes: state.reorderablePanes,
      onReorderPane: state.reorderPane,
      selectAfterDrawing: !state.keepToolArmed,
      hideGrid: state.hideGrid,
      volHidden: state.volHidden,
      showNowPrice: state.showNowPrice,
      showInfoDialog: state.showInfoDialog,
      isTapShowInfoDialog: state.tapShowsInfoDialog,
      materialInfoDialog: state.materialInfoDialog,
      verticalTextAlignment: state.axisOnRight
          ? VerticalTextAlignment.right
          : VerticalTextAlignment.left,
      fixedLength: state.fixedLength,
      timeFormat: TimeFormat.YEAR_MONTH_DAY_WITH_HOUR,
      dateFormatter: state.customDateFormat ? state.formatDate : null,
      baselinePrice: state.baselinePrice,
      xFrontPadding: state.frontPadding,
      showScrollToNowButton: state.scrollToNowButton,
      enableKeyboardShortcuts: state.keyboardShortcuts,
      signals: state.signals,
      // The drawings themselves live in the controller, so all that is left
      // here is to hear about them.
      onAddDrawing: state.noteSaved,
      onRemoveDrawing: state.noteRemoved,
      onAlertCrossed: state.noteAlert,
      onLoadMore: (isRight) {
        if (!isRight) state.loadOlder();
      },
      infoDialogBuilder: state.customInfoDialog ? _customReadout : null,
      // `mBaseHeight` is left unset, so the candles take whatever height the
      // panes below them do not need.
    );
  }

  /// Replaces the built-in readout with anything you like.
  static Widget? _customReadout(
    BuildContext context,
    KLineEntity? previous,
    KLineEntity? candle,
  ) {
    if (candle == null) return null;
    final change = candle.close - candle.open;
    final up = change >= 0;

    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              candle.close.toStringAsFixed(2),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${up ? '▲' : '▼'} ${change.abs().toStringAsFixed(2)}',
              style: TextStyle(
                color: up ? const Color(0xFF26A69A) : const Color(0xFFEF5350),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'custom infoDialogBuilder',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.state});

  final DemoState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = state.candles.last;
    final change = last.close - last.open;
    final up = change >= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Row(
        children: [
          Text(
            'BTC/USDT',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            last.close.toStringAsFixed(state.fixedLength),
            style: theme.textTheme.labelLarge?.copyWith(
              color: up ? const Color(0xFF26A69A) : const Color(0xFFEF5350),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 6),
          if (state.live)
            const _LiveDot()
          else
            Text('paused', style: theme.textTheme.labelSmall),
          const Spacer(),
          Flexible(
            child: Text(
              state.status,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: Color(0xFF26A69A),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text('live', style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
