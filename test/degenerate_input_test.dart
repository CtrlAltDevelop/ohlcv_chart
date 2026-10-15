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
      for (final (label, width, height) in const [
        ('300x200', 300.0, 200.0),
        ('1x1', 1.0, 1.0),
        ('0x0', 0.0, 0.0),
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
