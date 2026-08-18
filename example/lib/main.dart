import 'package:flutter/material.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

import 'market_data.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ohlcv_chart',
      theme: ThemeData.dark(),
      home: const ChartPage(),
    );
  }
}

class ChartPage extends StatefulWidget {
  const ChartPage({super.key});

  @override
  State<ChartPage> createState() => _ChartPageState();
}

class _ChartPageState extends State<ChartPage> {
  final List<KLineEntity> _candles = MarketData.candles();

  final Set<MainState> _mainStates = {MainState.MA};
  final Set<SecondaryState> _secondaryStates = {SecondaryState.MACD};

  final List<TrendLine> _trendLines = [];
  final List<HorizontalLine> _horizontalLines = [];
  final List<VerticalLine> _verticalLines = [];

  DrawingTool _tool = DrawingTool.none;
  bool _isLine = false;
  bool _showDepth = false;

  // A dark palette to match ThemeData.dark(); ChartColors defaults to light.
  final ChartColors _colors = ChartColors(
    bgColor: const Color(0xFF161A1E),
    defaultTextColor: const Color(0xFF8A8F99),
    gridColor: const Color(0xFF23272E),
    upColor: const Color(0xFF12B886),
    dnColor: const Color(0xFFFA5252),
  );

  @override
  Widget build(BuildContext context) {
    final lastClose = _candles.last.close;
    final (bids, asks) = MarketData.orderBook(lastClose);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ohlcv_chart'),
        actions: [
          IconButton(
            tooltip: _showDepth ? 'Show candles' : 'Show depth',
            icon: Icon(_showDepth ? Icons.candlestick_chart : Icons.area_chart),
            onPressed: () => setState(() => _showDepth = !_showDepth),
          ),
        ],
      ),
      body: _showDepth
          ? Center(child: DepthChart(bids, asks, baseUnit: 2, quoteUnit: 0))
          : Column(
              children: [
                Expanded(
                  child: KChartWidget(
                    _candles,
                    _colors,
                    isTrendLine: true,
                    watermarkAssetPath: 'assets/watermark.svg',
                    timeFrame: MarketData.timeFrame,
                    isLine: _isLine,
                    mainStateLi: _mainStates,
                    secondaryStateLi: _secondaryStates,
                    currentDrawingTool: _tool,
                    trendLines: _trendLines,
                    horizontalLines: _horizontalLines,
                    verticalLines: _verticalLines,
                    timeFormat: TimeFormat.YEAR_MONTH_DAY_WITH_HOUR,
                    fixedLength: 2,
                    // Placing a line leaves drawing mode, matching how most
                    // trading apps behave.
                    onAddTrendLine: (line) => setState(() {
                      _trendLines
                        ..remove(line)
                        ..add(line);
                      _tool = DrawingTool.none;
                    }),
                    onAddHorizontalLine: (line) => setState(() {
                      _horizontalLines
                        ..remove(line)
                        ..add(line);
                      _tool = DrawingTool.none;
                    }),
                    onAddVerticalLine: (line) => setState(() {
                      _verticalLines
                        ..remove(line)
                        ..add(line);
                      _tool = DrawingTool.none;
                    }),
                    onRemoveTrendLine: (line) =>
                        setState(() => _trendLines.remove(line)),
                    onRemoveHorizontalLine: (line) =>
                        setState(() => _horizontalLines.remove(line)),
                    onRemoveVerticalLine: (line) =>
                        setState(() => _verticalLines.remove(line)),
                  ),
                ),
                _Controls(
                  mainStates: _mainStates,
                  secondaryStates: _secondaryStates,
                  tool: _tool,
                  isLine: _isLine,
                  onToggleMain: (state) => setState(() {
                    _mainStates.contains(state)
                        ? _mainStates.remove(state)
                        : _mainStates.add(state);
                  }),
                  onToggleSecondary: (state) => setState(() {
                    _secondaryStates.contains(state)
                        ? _secondaryStates.remove(state)
                        : _secondaryStates.add(state);
                  }),
                  onToolChanged: (tool) => setState(() => _tool = tool),
                  onLineModeChanged: (value) =>
                      setState(() => _isLine = value),
                ),
              ],
            ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.mainStates,
    required this.secondaryStates,
    required this.tool,
    required this.isLine,
    required this.onToggleMain,
    required this.onToggleSecondary,
    required this.onToolChanged,
    required this.onLineModeChanged,
  });

  final Set<MainState> mainStates;
  final Set<SecondaryState> secondaryStates;
  final DrawingTool tool;
  final bool isLine;
  final ValueChanged<MainState> onToggleMain;
  final ValueChanged<SecondaryState> onToggleSecondary;
  final ValueChanged<DrawingTool> onToolChanged;
  final ValueChanged<bool> onLineModeChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final state in MainState.values)
                FilterChip(
                  label: Text(state.name),
                  selected: mainStates.contains(state),
                  onSelected: (_) => onToggleMain(state),
                ),
              FilterChip(
                label: const Text('Line'),
                selected: isLine,
                onSelected: onLineModeChanged,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final state in SecondaryState.values)
                FilterChip(
                  label: Text(state.name),
                  selected: secondaryStates.contains(state),
                  onSelected: (_) => onToggleSecondary(state),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final option in DrawingTool.values)
                ChoiceChip(
                  label: Text(option.name),
                  selected: tool == option,
                  onSelected: (_) => onToolChanged(option),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
