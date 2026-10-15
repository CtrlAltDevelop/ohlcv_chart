import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

/// The numbers every chart is fed in turn: nothing, one, and the kinds a real
/// feed produces on a bad day.
final Map<String, List<double>> _inputs = {
  'empty': [],
  'one': [5],
  'zeros': [0, 0, 0],
  'same': [7, 7, 7, 7],
  'negative': [-3, -1, -2],
  'mixed': [3, -2, 0, 5, -7, 1],
  'nan': [double.nan, 1, 2, double.nan],
  'infinite': [double.infinity, 1, double.negativeInfinity, 2],
  'huge': [1e300, -1e300, 1e300],
  'tiny': [1e-300, 2e-300, 3e-300],
};

DateTime _at(int i) => DateTime.utc(2024).add(Duration(days: i));

List<KLineEntity> _candles(List<double> v) => [
  for (var i = 0; i < v.length; i++)
    KLineEntity.fromCustom(
      open: v[i],
      high: v[i] + 1,
      low: v[i] - 1,
      close: v[i],
      vol: v[i].abs(),
      dateTime: _at(i),
    ),
];

typedef _Build = Widget Function(List<double> v);

final Map<String, _Build> _charts = {
  'BubbleChart': (v) => BubbleChart(
    points: [
      for (var i = 0; i < v.length; i++)
        BubblePoint(x: i.toDouble(), y: v[i], size: v[i]),
    ],
  ),
  'BulletChart': (v) => BulletChart(
    rows: [
      for (final x in v) BulletRow(label: 'a', value: x, target: x, max: x),
    ],
  ),
  'CalendarChart': (v) => CalendarChart(
    days: [
      for (var i = 0; i < v.length; i++) CalendarDay(date: _at(i), value: v[i]),
    ],
  ),
  'ChordChart': (v) => ChordChart(
    nodes: const [
      ChordNode(label: 'A'),
      ChordNode(label: 'B'),
    ],
    flows: [
      for (final x in v) ...[
        ChordFlow(from: 'A', to: 'B', value: x),
        ChordFlow(from: 'B', to: 'A', value: x),
        ChordFlow(from: 'A', to: 'A', value: x),
        ChordFlow(from: 'A', to: 'missing', value: x),
      ],
    ],
  ),
  'CumulativeDeltaChart': (v) => CumulativeDeltaChart(
    bars: [
      for (var i = 0; i < v.length; i++)
        DeltaBar(time: _at(i), delta: v[i], price: v[i]),
    ],
  ),
  'BoxPlotChart': (v) =>
      BoxPlotChart(entries: [BoxPlotEntry.fromSamples(v, label: 'a')]),
  'HistogramChart': (v) => HistogramChart(bins: histogramBins(v)),
  'RMultipleChart': (v) => RMultipleChart(results: v),
  'VarChart': (v) => VarChart(returns: v, confidence: 0.9),
  'MaeMfeChart': (v) => MaeMfeChart(
    trades: [
      for (final x in v) TradeExcursion(pnl: x, mae: x.abs(), mfe: x.abs() * 2),
    ],
    xReferenceLines: const [1],
  ),
  'DumbbellChart': (v) => DumbbellChart(
    rows: [for (final x in v) DumbbellRow(label: 'a', from: x, to: x * 2)],
  ),
  'EquityCurveChart': (v) => EquityCurveChart(
    points: [
      for (var i = 0; i < v.length; i++)
        EquityPoint(time: _at(i), equity: v[i]),
    ],
  ),
  'MonteCarloChart': (v) =>
      MonteCarloChart(result: runMonteCarlo(v, pathCount: 20, steps: 10)),
  'FootprintChart': (v) => FootprintChart(
    tickSize: 1,
    bars: [
      for (var i = 0; i < v.length; i++)
        FootprintBar(
          time: _at(i),
          open: v[i],
          high: v[i] + 1,
          low: v[i] - 1,
          close: v[i],
          levels: [
            FootprintLevel(price: v[i], bidVolume: v[i], askVolume: v[i]),
          ],
        ),
    ],
  ),
  'FunnelChart': (v) => FunnelChart(
    stages: [for (final x in v) FunnelStage(value: x, label: 'a')],
  ),
  'GaugeChart': (v) => GaugeChart(value: v.isEmpty ? 0 : v.first),
  'HeatmapChart': (v) => HeatmapChart(
    cells: [
      for (var i = 0; i < v.length; i++)
        HeatmapCell(x: i, y: i % 2, value: v[i]),
    ],
  ),
  'SeasonalityChart': (v) => SeasonalityChart(
    samples: [
      for (var i = 0; i < v.length; i++)
        SeasonalSample(time: _at(i * 40), value: v[i]),
    ],
  ),
  'LiquidityMapChart': (v) => LiquidityMapChart(
    bins: [
      for (var i = 0; i < v.length; i++)
        LiquidityBin(
          from: i.toDouble(),
          to: i + 1.0,
          longSize: v[i],
          shortSize: v[i],
          levels: [
            LiquidityLevel(
              price: i + 0.5,
              size: v[i],
              side: LiquiditySide.long,
            ),
          ],
        ),
    ],
  ),
  'MarimekkoChart': (v) => MarimekkoChart(
    columns: [
      for (final x in v)
        MarimekkoColumn(
          label: 'a',
          cells: [MarimekkoCell(label: 'b', value: x)],
        ),
    ],
  ),
  'OpenInterestChart': (v) => OpenInterestChart(
    points: [
      for (var i = 0; i < v.length; i++)
        OpenInterestPoint(
          time: i,
          openInterest: v[i],
          funding: v[i],
          price: v[i],
        ),
    ],
  ),
  'OptionPayoffChart': (v) => OptionPayoffChart(
    legs: [
      for (final x in v)
        OptionLeg(kind: OptionKind.call, strike: x, premium: x),
    ],
  ),
  'PairSpreadChart': (v) => PairSpreadChart(
    points: [
      for (var i = 0; i < v.length; i++)
        PairPoint(time: _at(i), a: v[i], b: v[v.length - 1 - i]),
    ],
  ),
  'ParallelChart': (v) => ParallelChart(
    axes: const [
      ParallelAxis(label: 'x'),
      ParallelAxis(label: 'y'),
    ],
    lines: [
      for (final x in v) ParallelLine(label: 'a', values: [x, x * 2]),
    ],
  ),
  'PieChart': (v) =>
      PieChart(sections: [for (final x in v) PieSection(value: x)]),
  'MarketProfileChart': (v) =>
      MarketProfileChart(profile: buildMarketProfile(_candles(v))),
  'RadarChart': (v) => RadarChart(
    features: const ['a', 'b', 'c'],
    series: [RadarSeries(values: v)],
  ),
  'SankeyChart': (v) => SankeyChart(
    nodes: const [
      SankeyNode(id: 'a'),
      SankeyNode(id: 'b'),
      SankeyNode(id: 'c'),
    ],
    links: [
      for (final x in v) ...[
        SankeyLink(source: 'a', target: 'b', value: x),
        SankeyLink(source: 'b', target: 'c', value: x),
        SankeyLink(source: 'c', target: 'a', value: x),
        SankeyLink(source: 'a', target: 'a', value: x),
      ],
    ],
  ),
  'SeriesChart': (v) => SeriesChart(
    series: [
      LineSeries(
        points: [
          for (var i = 0; i < v.length; i++) SeriesPoint(i.toDouble(), v[i]),
        ],
      ),
      BarSeries(
        points: [
          for (var i = 0; i < v.length; i++) SeriesPoint(i.toDouble(), v[i]),
        ],
      ),
      ScatterSeries(
        points: [
          for (var i = 0; i < v.length; i++) SeriesPoint(i.toDouble(), v[i]),
        ],
      ),
    ],
  ),
  'SlopeChart': (v) => SlopeChart(
    series: [
      for (final x in v) SlopeSeries(label: 'a', values: [x, -x]),
    ],
  ),
  'SparklineGrid': (v) => SparklineGrid(
    tiles: [SparklineTile(label: 'a', values: v)],
  ),
  'StreamChart': (v) => StreamChart(
    series: [StreamSeries(label: 'a', values: v)],
  ),
  'SunburstChart': (v) => SunburstChart(
    items: [
      TreemapItem.group(
        label: 'g',
        children: [for (final x in v) TreemapItem(value: x, label: 'a')],
      ),
    ],
  ),
  'TreemapChart': (v) => TreemapChart(
    items: [
      TreemapItem.group(
        label: 'g',
        children: [for (final x in v) TreemapItem(value: x, label: 'a')],
      ),
      for (final x in v) TreemapItem(value: x, label: 'b'),
    ],
  ),
  'TradeTimelineChart': (v) => TradeTimelineChart(
    trades: [
      for (var i = 0; i < v.length; i++)
        TimelineTrade(
          entryTime: _at(i),
          exitTime: i.isEven ? _at(i + 1) : null,
          pnl: v[i],
          side: TradeSide.buy,
          lane: 'x',
        ),
    ],
  ),
  'ViolinChart': (v) => ViolinChart(
    series: [ViolinSeries(label: 'a', samples: v)],
  ),
  'VolatilityCurveChart': (v) => VolatilityCurveChart(
    slices: [
      VolatilitySlice(
        points: [
          for (var i = 0; i < v.length; i++)
            VolatilityPoint(x: i.toDouble(), volatility: v[i]),
        ],
      ),
    ],
  ),
  'VolatilitySurfaceChart': (v) => VolatilitySurfaceChart(
    strikes: [for (var i = 0; i < v.length; i++) 90.0 + i * 5],
    expiries: const ['1M', '3M'],
    volatilities: [v, v.reversed.toList()],
    spot: 100,
  ),
  'EfficientFrontierChart': (v) => EfficientFrontierChart(
    points: [
      for (var i = 0; i < v.length; i++)
        PortfolioPoint(risk: v[i].abs(), expectedReturn: v[v.length - 1 - i]),
    ],
    current: PortfolioPoint(risk: v.isEmpty ? 0 : v.first, expectedReturn: 1),
    riskFreeRate: 0.01,
  ),
  'FuturesCurveChart': (v) => FuturesCurveChart(
    curves: [
      FuturesCurve(
        label: 'now',
        contracts: [
          for (var i = 0; i < v.length; i++)
            FuturesContract(label: 'M$i', price: v[i]),
        ],
      ),
      FuturesCurve(
        label: 'then',
        dashed: true,
        contracts: [
          for (var i = 0; i < v.length; i++)
            FuturesContract(label: 'M$i', price: v[v.length - 1 - i]),
        ],
      ),
    ],
  ),
  'ActivityClockChart': (v) => ActivityClockChart(
    samples: [
      for (var i = 0; i < v.length; i++)
        SeasonalSample(
          time: DateTime.utc(2024).add(Duration(hours: i * 7)),
          value: v[i],
        ),
    ],
    aggregate: SeasonalityAggregate.sum,
  ),
  'TrainingCurveChart': (v) => TrainingCurveChart(
    runs: [
      TrainingRun(
        label: 'train',
        points: [
          for (var i = 0; i < v.length; i++) TrainingPoint(i * 10.0, v[i]),
        ],
      ),
      TrainingRun(
        label: 'val',
        dashed: true,
        points: [
          for (var i = 0; i < v.length; i++)
            TrainingPoint(i * 10.0, v[v.length - 1 - i]),
        ],
      ),
    ],
    smoothing: 0.7,
    gapBetween: (0, 1),
  ),
  'TrainingCurveChart (log)': (v) => TrainingCurveChart(
    runs: [
      TrainingRun(
        label: 'loss',
        points: [
          for (var i = 0; i < v.length; i++) TrainingPoint(i.toDouble(), v[i]),
        ],
      ),
    ],
    logY: true,
    lowerIsBetter: false,
  ),
  'ScalingLawChart': (v) => ScalingLawChart(
    points: [
      for (var i = 0; i < v.length; i++)
        ScalingPoint(scale: 1e18 * (i + 1), loss: v[i], label: 'm$i'),
    ],
    extrapolateTo: 1e24,
    targetLoss: 1.5,
  ),
  'ScalingLawChart (fit from)': (v) => ScalingLawChart(
    points: [
      for (var i = 0; i < v.length; i++)
        ScalingPoint(scale: v[i], loss: v[v.length - 1 - i].abs() + 1),
    ],
    fitFrom: 0.5,
  ),
  'SweepChart': (v) => SweepChart(
    trials: [
      for (var i = 0; i < v.length; i++)
        SweepTrial(x: (i % 3).toDouble(), y: (i ~/ 3).toDouble(), score: v[i]),
    ],
  ),
  'SweepChart (higher is better)': (v) => SweepChart(
    lowerIsBetter: false,
    showMarginals: false,
    trials: [
      for (var i = 0; i < v.length; i++)
        SweepTrial(x: v[i], y: v[v.length - 1 - i], score: v[i]),
    ],
  ),
  'TrainingTimelineChart': (v) => TrainingTimelineChart(
    jobs: [
      for (var i = 0; i < v.length; i++)
        TrainingJob(
          name: 'j$i',
          node: 'n${i % 2}',
          start: DateTime.utc(2026).add(Duration(hours: i * 2)),
          end: i.isEven
              ? DateTime.utc(2026).add(Duration(hours: i * 2 + 3))
              : null,
          status: JobStatus.values[i % JobStatus.values.length],
        ),
    ],
  ),
  'BenchmarkMatrixChart': (v) => BenchmarkMatrixChart(
    models: [for (var i = 0; i < v.length; i++) 'm$i'],
    benchmarks: const ['a', 'b'],
    scores: [
      for (var i = 0; i < v.length; i++) [v[i], v[v.length - 1 - i]],
    ],
    lowerIsBetter: const {1},
  ),
  'ModelParetoChart': (v) => ModelParetoChart(
    models: [
      for (var i = 0; i < v.length; i++)
        ModelPoint(
          name: 'm$i',
          cost: v[i],
          score: v[v.length - 1 - i],
          size: v[i].abs(),
          group: i.isEven ? 'a' : 'b',
        ),
    ],
  ),
  'ModelParetoChart (linear)': (v) => ModelParetoChart(
    logCost: false,
    labelAll: true,
    models: [
      for (var i = 0; i < v.length; i++)
        ModelPoint(name: 'm$i', cost: v[i], score: v[i]),
    ],
  ),
  'LatencyBandChart': (v) => LatencyBandChart(
    slo: 1,
    samples: [
      for (var i = 0; i < v.length; i++)
        LatencySample(
          time: DateTime.utc(2026).add(Duration(minutes: i)),
          p50: v[i],
          p95: v[i] + 1,
          p99: v[i] + 2,
        ),
    ],
  ),
  'LatencyBandChart (log)': (v) => LatencyBandChart(
    logY: true,
    sloPercentile: LatencyPercentile.p99,
    slo: 10,
    samples: [
      for (var i = 0; i < v.length; i++)
        LatencySample(
          time: DateTime.utc(2026).add(Duration(hours: i * 20)),
          p50: v[i],
          p95: v[v.length - 1 - i],
          p99: v[i].abs() * 3,
        ),
    ],
  ),
  'TokenUsageChart': (v) => TokenUsageChart(
    buckets: [
      for (var i = 0; i < v.length; i++)
        UsageBucket(
          time: DateTime.utc(2026).add(Duration(days: i)),
          inputTokens: v[i],
          outputTokens: v[v.length - 1 - i],
          cachedTokens: v[i].abs(),
          cost: v[i],
        ),
    ],
  ),
  'TokenUsageChart (no cost)': (v) => TokenUsageChart(
    showCost: false,
    buckets: [
      for (var i = 0; i < v.length; i++)
        UsageBucket(
          time: DateTime.utc(2026).add(Duration(hours: i)),
          inputTokens: v[i],
        ),
    ],
  ),
  'EvalBreakdownChart': (v) => EvalBreakdownChart(
    threshold: 0.8,
    categories: [
      for (var i = 0; i < v.length; i++)
        EvalCategory(
          name: 'c$i',
          passed: v[i].isFinite ? v[i].abs().round().clamp(0, 1000) : 0,
          failed: i,
          skipped: i % 2,
        ),
    ],
  ),
  'TokenHeatmap': (v) => TokenHeatmap(
    showSummary: true,
    tokens: [
      for (var i = 0; i < v.length; i++)
        TokenScore(i % 3 == 0 ? ' tok$i\n' : ' tok$i', v[i]),
    ],
  ),
  'TokenHeatmap (every option)': (v) => TokenHeatmap(
    showSummary: true,
    showStrip: true,
    showWhitespace: true,
    highlightTop: 3,
    focusAbove: 0.5,
    selectedIndex: 1,
    tokens: [
      for (var i = 0; i < v.length; i++)
        TokenScore(
          i % 4 == 0 ? '\n' : ' tok$i',
          v[i],
          probability: v[i].isFinite ? 0.25 : null,
          alternatives: const [TokenAlternative(' other', 0.1)],
        ),
    ],
  ),
  'TokenHeatmap (long)': (v) => TokenHeatmap(
    tokens: [
      for (var i = 0; i < 400; i++)
        TokenScore(' w$i', v.isEmpty ? 0 : v[i % v.length]),
    ],
  ),
  'WaffleChart': (v) => WaffleChart(
    slices: [
      for (final x in v)
        WaffleSlice(label: 'a', value: x, color: const Color(0xFF00FF00)),
    ],
  ),
  'WaterfallChart': (v) => WaterfallChart(
    steps: [for (final x in v) WaterfallStep(value: x, label: 'a')],
  ),
  'BookHeatmapChart': (v) => BookHeatmapChart(
    tickSize: 1,
    snapshots: [
      for (var i = 0; i < v.length; i++)
        BookSnapshot(
          time: _at(i),
          mid: v[i],
          levels: [
            BookLevel(price: v[i], size: v[i], side: BookSide.bid),
            BookLevel(price: v[i] + 1, size: v[i], side: BookSide.ask),
          ],
        ),
    ],
  ),
  'DepthChart': (v) => DepthChart(
    [for (final x in v) DepthEntity(x, x.abs())],
    [for (final x in v) DepthEntity(x + 1, x.abs())],
  ),
  'KChartWidget': (v) {
    final data = _candles(v);
    DataUtil.calculate(data);
    return KChartWidget(
      data,
      ChartColors(),
      isTrendLine: false,
      timeFrame: const Duration(minutes: 15),
      indicators: [
        MaIndicator(),
        BollIndicator(),
        MacdIndicator(),
        RsiIndicator(),
        KdjIndicator(),
        SupertrendIndicator(),
        IchimokuIndicator(),
        ZigZagIndicator(),
        VolumeProfileIndicator(),
      ],
    );
  },
};

void main() {
  for (final MapEntry(key: name, value: build) in _charts.entries) {
    for (final MapEntry(key: input, value: values) in _inputs.entries) {
      for (final (label, width, height) in [
        ('300x200', 300.0, 200.0),
        ('1x1', 1.0, 1.0),
        ('0x0', 0.0, 0.0),
        // Boxes of other shapes, where a label or a legend can run out of
        // room: small, narrow and tall, short and wide. Overflow is an error
        // here, so a chart that does not fit its box fails. Three kinds of
        // data are enough to move the labels about.
        if (const {'mixed', 'one', 'huge'}.contains(input)) ...[
          ('120x90', 120.0, 90.0),
          ('60x300', 60.0, 300.0),
          ('200x400', 200.0, 400.0),
          ('800x100', 800.0, 100.0),
          ('360x240', 360.0, 240.0),
        ],
      ]) {
        testWidgets('$name survives $input data in a $label box', (
          tester,
        ) async {
          final errors = <FlutterErrorDetails>[];
          final original = FlutterError.onError;
          FlutterError.onError = errors.add;
          String report() => errors
              .map(
                (e) =>
                    '${e.exception}\n'
                    '${e.stack.toString().split('\n').take(7).join('\n')}',
              )
              .join('\n---\n');

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: build(values),
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 400));
          FlutterError.onError = original;
          expect(errors, isEmpty, reason: report());

          FlutterError.onError = errors.add;
          // A touch in the middle must not throw either.
          final gesture = await tester.startGesture(
            Offset(400 - width / 2 + math.min(width, 5), 300),
          );
          await tester.pump();
          await gesture.up();
          await tester.pump();
          FlutterError.onError = original;
          expect(errors, isEmpty, reason: report());
        });
      }
    }
  }
}
