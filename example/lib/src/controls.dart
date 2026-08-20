import 'package:flutter/material.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

import 'demo_state.dart';
import 'indicator_sheet.dart';

/// The demo's control panel: one row per `KChartWidget` argument, grouped by
/// what it affects.
class Controls extends StatelessWidget {
  /// Creates the panel over [state].
  const Controls({required this.state, super.key});

  /// The demo's settings.
  final DemoState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        _Section(
          title: 'Drawing tools',
          subtitle: 'Pick a tool, then tap the chart — or drag',
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tool in DrawingTool.values)
                  ChoiceChip(
                    label: Text(_toolName(tool)),
                    selected: state.tool == tool,
                    onSelected: (_) => state.update(() => state.tool = tool),
                  ),
              ],
            ),
            _Toggle(
              label: 'Magnet',
              subtitle: 'Snap new points to the nearest open, high, low, close',
              value: state.magnetMode,
              onChanged: (v) => state.update(() => state.magnetMode = v),
            ),
            _Toggle(
              label: 'Branded editor',
              subtitle: 'A vertical toolbar with a house palette',
              value: state.brandedToolbar,
              onChanged: (v) => state.update(() => state.brandedToolbar = v),
            ),
            _Toggle(
              label: 'Keep the tool armed',
              subtitle: 'Draw several in a row; leaves the editor closed',
              value: state.keepToolArmed,
              onChanged: (v) => state.update(() => state.keepToolArmed = v),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${state.drawingCount} drawn',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Undo (⌘Z on the chart)',
                  onPressed: state.drawings.canUndo
                      ? () => state.drawings.undo()
                      : null,
                  icon: const Icon(Icons.undo_rounded, size: 18),
                ),
                IconButton(
                  tooltip: 'Redo (⇧⌘Z)',
                  onPressed: state.drawings.canRedo
                      ? () => state.drawings.redo()
                      : null,
                  icon: const Icon(Icons.redo_rounded, size: 18),
                ),
                TextButton.icon(
                  onPressed: state.drawingCount == 0
                      ? null
                      : state.drawings.clear,
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  label: const Text('Clear'),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Persist the layout as JSON',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: state.drawingCount == 0 ? null : state.saveLayout,
                  child: const Text('Save'),
                ),
                TextButton(
                  onPressed: state.savedLayout == null
                      ? null
                      : state.loadLayout,
                  child: const Text('Restore'),
                ),
              ],
            ),
          ],
        ),
        _Section(
          title: 'Indicators',
          subtitle:
              'Add as many as you like — ATR(8), ATR(14) and ATR(20) '
              'are three panes',
          children: [
            _IndicatorList(state: state),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: () async {
                  final indicator = await IndicatorSheet.show(
                    context,
                    theme: state.colors,
                  );
                  if (indicator != null) state.addIndicator(indicator);
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add indicator'),
              ),
            ),
          ],
        ),
        _Section(
          title: 'Main chart',
          children: [
            _Choice<ChartType>(
              label: 'Type',
              value: state.chartType,
              options: const {
                ChartType.candles: 'candles',
                ChartType.bars: 'bars',
                ChartType.line: 'line',
                ChartType.area: 'area',
                ChartType.baseline: 'base',
              },
              onChanged: (v) => state.update(() => state.chartType = v),
            ),
            _Choice<Aggregation>(
              label: 'Candles',
              value: state.aggregation,
              options: const {
                Aggregation.none: 'raw',
                Aggregation.heikinAshi: 'HA',
                Aggregation.renko: 'renko',
              },
              onChanged: (v) => state.update(() => state.aggregation = v),
            ),
            _Choice<PriceAxisScale>(
              label: 'Price axis',
              value: state.priceAxisScale,
              options: const {
                PriceAxisScale.linear: 'linear',
                PriceAxisScale.logarithmic: 'log',
                PriceAxisScale.percentage: '%',
              },
              onChanged: (v) => state.update(() => state.priceAxisScale = v),
            ),
            _Toggle(
              label: 'Hollow rising candles',
              value: state.hollowCandles,
              onChanged: (v) => state.update(() => state.hollowCandles = v),
            ),
            _Toggle(
              label: 'Volume pane',
              value: !state.volHidden,
              onChanged: (v) => state.update(() => state.volHidden = !v),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Zoom and capture through KChartController',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Zoom out',
                  onPressed: state.chart.zoomOut,
                  icon: const Icon(Icons.zoom_out_rounded, size: 18),
                ),
                IconButton(
                  tooltip: 'Zoom in',
                  onPressed: state.chart.zoomIn,
                  icon: const Icon(Icons.zoom_in_rounded, size: 18),
                ),
                IconButton(
                  tooltip: 'Capture as PNG',
                  onPressed: () => _showCapture(context, state),
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                ),
              ],
            ),
          ],
        ),
        _Section(
          title: 'Panes',
          subtitle:
              'Drag a pane\'s lower edge to resize it, its legend to '
              'move it',
          children: [
            _Toggle(
              label: 'Resizable',
              value: state.resizablePanes,
              onChanged: (v) => state.update(() => state.resizablePanes = v),
            ),
            _Toggle(
              label: 'Reorderable',
              value: state.reorderablePanes,
              onChanged: (v) => state.update(() => state.reorderablePanes = v),
            ),
          ],
        ),
        _Section(
          title: 'Axes and markers',
          children: [
            _Toggle(
              label: 'Grid',
              value: !state.hideGrid,
              onChanged: (v) => state.update(() => state.hideGrid = !v),
            ),
            _Toggle(
              label: 'Price axis on the right',
              value: state.axisOnRight,
              onChanged: (v) => state.update(() => state.axisOnRight = v),
            ),
            _Toggle(
              label: 'Now price and countdown',
              value: state.showNowPrice,
              onChanged: (v) => state.update(() => state.showNowPrice = v),
            ),
            _Toggle(
              label: 'TP / SL markers',
              subtitle: 'SignalEntity tags pinned to a price',
              value: state.showSignals,
              onChanged: (v) => state.update(() => state.showSignals = v),
            ),
            _Toggle(
              label: 'OHLC legend',
              subtitle: 'Reads out the candle under the crosshair',
              value: state.showOhlcLegend,
              onChanged: (v) => state.update(() => state.showOhlcLegend = v),
            ),
            _Toggle(
              label: 'Crosshair follows the mouse',
              subtitle: 'No long press needed on a desktop',
              value: state.crosshairOnHover,
              onChanged: (v) => state.update(() => state.crosshairOnHover = v),
            ),
            _Toggle(
              label: 'Day dividers',
              value: state.sessionDividers,
              onChanged: (v) => state.update(() => state.sessionDividers = v),
            ),
            _Choice<int>(
              label: 'Time zone',
              value: state.timeZoneOffset.inMinutes,
              options: const {0: 'UTC', 330: '+5:30', -300: '-5'},
              onChanged: (v) => state.update(
                () => state.timeZoneOffset = Duration(minutes: v),
              ),
            ),
            _Choice<int>(
              label: 'Decimals',
              value: state.fixedLength,
              options: const {0: '0', 2: '2', 4: '4'},
              onChanged: (v) => state.update(() => state.fixedLength = v),
            ),
          ],
        ),
        _Section(
          title: 'Readout',
          children: [
            _Toggle(
              label: 'Long-press readout',
              value: state.showInfoDialog,
              onChanged: (v) => state.update(() => state.showInfoDialog = v),
            ),
            _Toggle(
              label: 'Also open it on tap',
              value: state.tapShowsInfoDialog,
              onChanged: (v) =>
                  state.update(() => state.tapShowsInfoDialog = v),
            ),
            _Toggle(
              label: 'Material styling',
              value: state.materialInfoDialog,
              onChanged: (v) =>
                  state.update(() => state.materialInfoDialog = v),
            ),
            _Toggle(
              label: 'Custom builder',
              subtitle: 'Replaces the built-in card',
              value: state.customInfoDialog,
              onChanged: (v) => state.update(() => state.customInfoDialog = v),
            ),
          ],
        ),
        _Section(
          title: 'Feed',
          children: [
            _Toggle(
              label: 'Live ticks',
              subtitle: 'Walks the last candle and rolls it over',
              value: state.live,
              onChanged: state.setLive,
            ),
            Text(
              'Scroll past the oldest candle to trigger onLoadMore'
              '${state.loadedPages == 0 ? '' : ' — ${state.loadedPages} page(s) in'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        _Section(
          title: 'Theme and language',
          children: [
            _Toggle(
              label: 'Dark palette',
              value: state.dark,
              onChanged: (v) => state.update(() => state.dark = v),
            ),
            _Toggle(
              label: 'Deutsch',
              subtitle: 'ChartTranslations and DrawingTranslations',
              value: state.german,
              onChanged: (v) => state.update(() => state.german = v),
            ),
          ],
        ),
      ],
    );
  }

  /// Captures the chart and shows the PNG the controller handed back.
  static Future<void> _showCapture(
    BuildContext context,
    DemoState state,
  ) async {
    final bytes = await state.capture();
    if (bytes == null || !context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('KChartController.capture()'),
        content: SizedBox(width: 520, child: Image.memory(bytes)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static String _toolName(DrawingTool tool) => switch (tool) {
    DrawingTool.none => 'select',
    DrawingTool.horizontal => 'horizontal',
    DrawingTool.horizontalRay => 'h. ray',
    DrawingTool.vertical => 'vertical',
    DrawingTool.trend => 'trend',
    DrawingTool.ray => 'ray',
    DrawingTool.extendedLine => 'extended',
    DrawingTool.arrow => 'arrow',
    DrawingTool.rectangle => 'rectangle',
    DrawingTool.ellipse => 'ellipse',
    DrawingTool.triangle => 'triangle',
    DrawingTool.fibRetracement => 'fib',
    DrawingTool.measure => 'measure',
    DrawingTool.channel => 'channel',
    DrawingTool.position => 'position',
    DrawingTool.text => 'note',
    DrawingTool.brush => 'brush',
  };
}

/// The indicators on the chart: tap one to edit it, or drop it.
class _IndicatorList extends StatelessWidget {
  const _IndicatorList({required this.state});

  final DemoState state;

  @override
  Widget build(BuildContext context) {
    if (state.indicators.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'No indicators — the chart draws candles alone.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final indicator in state.indicators)
            InputChip(
              avatar: CircleAvatar(
                backgroundColor: indicator.colorFor(0, state.colors),
                radius: 8,
              ),
              label: Text(indicator.label),
              onPressed: () async {
                final edited = await IndicatorSheet.show(
                  context,
                  theme: state.colors,
                  existing: indicator,
                );
                if (edited == null) return;
                // Editing the settings makes it a different indicator, so the
                // old one goes and `upsert` places the new one.
                if (edited != indicator) state.removeIndicator(indicator);
                state.addIndicator(edited);
              },
              onDeleted: () => state.removeIndicator(indicator),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.subtitle});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(subtitle!, style: theme.textTheme.bodySmall),
            ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
      value: value,
      onChanged: onChanged,
      dense: true,
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    // The options wrap rather than sitting in a row of segments: the panel is
    // narrow, and some of these have five of them.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final entry in options.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: entry.key == value,
                  onSelected: (_) => onChanged(entry.key),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
