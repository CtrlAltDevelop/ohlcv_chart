import 'package:flutter/material.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

import 'demo_state.dart';
import 'market_data.dart';

/// The market-depth demo, with its own colours, geometry and labels.
class DepthPage extends StatelessWidget {
  /// Creates the depth demo over [state].
  const DepthPage({required this.state, super.key});

  /// The demo's settings, shared with the candlestick page.
  final DemoState state;

  static String _modeName(DepthChartMode mode) => switch (mode) {
    DepthChartMode.cumulative => 'curve',
    DepthChartMode.histogram => 'bars',
    DepthChartMode.combined => 'both',
    DepthChartMode.ladder => 'ladder',
  };

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final mid = state.candles.last.close;
        final (bids, asks) = MarketData.orderBook(mid);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Text(
                    'Order book',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const Spacer(),
                  Text(
                    'mid ${mid.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: DepthChart(
                  bids,
                  asks,
                  baseUnit: 2,
                  quoteUnit: 0,
                  mode: state.depthMode,
                  scale: state.depthScale,
                  zoom: state.depthZoom,
                  showRatioBar: state.depthRatioBar,
                  chartColors: state.depthColors,
                  chartTranslations: state.depthTranslations,
                  chartStyle: const DepthChartStyle(
                    lineWidth: 1.4,
                    dotRadius: 4,
                    padding: 8,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final mode in DepthChartMode.values)
                    ChoiceChip(
                      label: Text(_modeName(mode)),
                      selected: state.depthMode == mode,
                      onSelected: (_) =>
                          state.update(() => state.depthMode = mode),
                    ),
                ],
              ),
            ),
            if (state.depthMode != DepthChartMode.ladder)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final scale in DepthScale.values)
                      ChoiceChip(
                        label: Text(scale.name),
                        selected: state.depthScale == scale,
                        onSelected: (_) =>
                            state.update(() => state.depthScale = scale),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final zoom in const <double?>[null, 0.05, 0.02, 0.01])
                    ChoiceChip(
                      label: Text(
                        zoom == null
                            ? 'whole book'
                            : '±${(zoom * 100).toStringAsFixed(0)}%',
                      ),
                      selected: state.depthZoom == zoom,
                      onSelected: (_) =>
                          state.update(() => state.depthZoom = zoom),
                    ),
                  FilterChip(
                    label: const Text('ratio bar'),
                    selected: state.depthRatioBar,
                    onSelected: (on) =>
                        state.update(() => state.depthRatioBar = on),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                state.depthMode == DepthChartMode.ladder
                    ? 'Every level as numbers, with a bar behind each row.'
                    : 'Long-press the chart for the price, the running total '
                          'and the size resting on the rung under your finger.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        );
      },
    );
  }
}
