import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

import 'test_utils.dart';

/// A parent that rebuilds its chart from a fresh list every time [version]
/// moves, the way an app does when it makes its data inside `build`.
Widget _host(ValueNotifier<int> version, Widget Function(int version) chart) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 300,
        child: ValueListenableBuilder<int>(
          valueListenable: version,
          builder: (context, value, _) => chart(value),
        ),
      ),
    ),
  );
}

const _duration = Duration(milliseconds: 300);

/// Pumps [chart] to rest, then rebuilds it with [next], and says whether that
/// set an animation going.
Future<bool> _animatesOnRebuild(
  WidgetTester tester,
  Widget Function(int version) chart, {
  required int next,
}) async {
  final version = ValueNotifier<int>(0);
  addTearDown(version.dispose);
  await tester.pumpWidget(_host(version, chart));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
  expect(tester.hasRunningAnimations, isFalse, reason: 'it settled');

  version.value = next;
  await tester.pump();
  return tester.hasRunningAnimations;
}

void main() {
  // `version` only decides which numbers go into the list. 0 and 1 make the
  // same values in a new list; 2 makes different ones.
  double value(int version, int i) => (version == 2 ? 50 : 0) + i * 3.0 - 10;

  final charts = <String, Widget Function(int version)>{
    'CumulativeDeltaChart': (v) => CumulativeDeltaChart(
      animationDuration: _duration,
      bars: [
        for (var i = 0; i < 8; i++)
          DeltaBar(
            time: DateTime.utc(2024, 1, 1 + i),
            delta: value(v, i),
            price: 100 + i.toDouble(),
          ),
      ],
    ),
    'WaterfallChart': (v) => WaterfallChart(
      animationDuration: _duration,
      steps: [
        for (var i = 0; i < 6; i++)
          WaterfallStep(value: value(v, i), label: 'step $i'),
      ],
    ),
    'TreemapChart': (v) => TreemapChart(
      animationDuration: _duration,
      items: [
        for (var i = 1; i < 6; i++)
          TreemapItem(value: value(v, i).abs() + 1, label: 'item $i'),
      ],
    ),
    'PieChart': (v) => PieChart(
      animationDuration: _duration,
      sections: [
        for (var i = 1; i < 5; i++)
          PieSection(
            value: value(v, i).abs() + 1,
            // A widget made inline is new on every build.
            badge: const SizedBox(width: 4, height: 4),
          ),
      ],
    ),
    'HeatmapChart': (v) => HeatmapChart(
      animationDuration: _duration,
      cells: [
        for (var i = 0; i < 6; i++) HeatmapCell(x: i, y: 0, value: value(v, i)),
      ],
    ),
    'ParallelChart': (v) => ParallelChart(
      animationDuration: _duration,
      // An inline closure, new on every build.
      axes: [
        ParallelAxis(label: 'a', formatter: (x) => x.toStringAsFixed(1)),
        ParallelAxis(label: 'b', formatter: (x) => '$x'),
      ],
      lines: [
        for (var i = 0; i < 4; i++)
          ParallelLine(label: 'l$i', values: [value(v, i), value(v, i + 1)]),
      ],
    ),
    'BoxPlotChart': (v) => BoxPlotChart(
      animationDuration: _duration,
      entries: [
        BoxPlotEntry.fromSamples([
          for (var i = 0; i < 12; i++) value(v, i),
        ], label: 'a'),
      ],
    ),
    'MonteCarloChart': (v) => MonteCarloChart(
      animationDuration: _duration,
      result: runMonteCarlo(
        [for (var i = 0; i < 10; i++) value(v, i) / 100],
        pathCount: 30,
        seed: 7,
      ),
    ),
    'MarketProfileChart': (v) => MarketProfileChart(
      animationDuration: _duration,
      profile: buildMarketProfile([
        for (var i = 0; i < 20; i++)
          candle(100 + value(v, i), high: 102 + value(v, i), minute: i),
      ], tickSize: 1),
    ),
  };

  for (final entry in charts.entries) {
    testWidgets('${entry.key} keeps still when rebuilt with the same data', (
      tester,
    ) async {
      expect(await _animatesOnRebuild(tester, entry.value, next: 1), isFalse);
    });

    testWidgets('${entry.key} animates when the data changes', (tester) async {
      expect(await _animatesOnRebuild(tester, entry.value, next: 2), isTrue);
    });
  }
}
