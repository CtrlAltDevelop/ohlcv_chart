import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

final _samples = [
  SeasonalSample(time: DateTime(2025, 1, 5), value: 0.1),
  SeasonalSample(time: DateTime(2025, 1, 20), value: -0.05),
  SeasonalSample(time: DateTime(2026, 1, 10), value: 0.02),
  SeasonalSample(time: DateTime(2026, 3, 1), value: 0.03),
];

void main() {
  group('aggregates', () {
    const values = [0.1, -0.05, 0.02, 0.03];

    test('each makes the samples into one number', () {
      double? of(SeasonalityAggregate a) => seasonalAggregate(values, a);
      expect(
        of(SeasonalityAggregate.compound),
        closeTo(1.1 * 0.95 * 1.02 * 1.03 - 1, 1e-12),
      );
      expect(of(SeasonalityAggregate.sum), closeTo(0.1, 1e-12));
      expect(of(SeasonalityAggregate.mean), closeTo(0.025, 1e-12));
      expect(of(SeasonalityAggregate.median), closeTo(0.025, 1e-12));
      expect(of(SeasonalityAggregate.winRate), 0.75);
      expect(of(SeasonalityAggregate.count), 4);
      expect(
        seasonalAggregate(const [3, 1, 2], SeasonalityAggregate.median),
        2,
      );
      expect(seasonalAggregate(const [], SeasonalityAggregate.mean), isNull);
    });

    test('returns come from consecutive prices', () {
      final returns = seasonalReturnsFromPrices(
        [DateTime(2026), DateTime(2026, 1, 2), DateTime(2026, 1, 3)],
        [100, 110, 99],
      );
      expect(returns.length, 2);
      expect(returns[0].time, DateTime(2026, 1, 2));
      expect(returns[0].value, closeTo(0.1, 1e-12));
      expect(returns[1].value, closeTo(-0.1, 1e-12));
    });
  });

  group('the table', () {
    test('month by year chains each month, every year between included', () {
      final table = seasonalityTable([
        ..._samples,
        SeasonalSample(time: DateTime(2028, 6, 1), value: 0.01),
      ]);
      expect(table.rowLabels, ['2025', '2026', '2027', '2028']);
      expect(table.columnLabels.first, 'Jan');
      expect(table.values[0][0], closeTo(0.045, 1e-12));
      expect(table.values[1][2], closeTo(0.03, 1e-12));
      expect(table.values[0][2], isNull);
      expect(table.counts[0][0], 2);
      expect(table.values[2].every((v) => v == null), isTrue);
    });

    test('rows sum up whole, columns average their squares', () {
      final table = seasonalityTable(_samples);
      expect(table.rowSummary[0], closeTo(0.045, 1e-12));
      expect(table.rowSummary[1], closeTo(1.02 * 1.03 - 1, 1e-12));
      expect(table.columnSummary[0], closeTo(0.0325, 1e-12));
      expect(table.columnSummary[1], isNull);
    });

    test('weekday by hour puts Monday first', () {
      final table = seasonalityTable(
        [
          SeasonalSample(time: DateTime(2026, 9, 14, 9), value: 1),
          SeasonalSample(time: DateTime(2026, 9, 20, 23), value: 2),
        ],
        grid: SeasonalityGrid.weekdayByHour,
        aggregate: SeasonalityAggregate.sum,
        weekdayLabels: const ['M'],
      );
      expect(table.rowCount, 7);
      expect(table.columnCount, 24);
      expect(table.rowLabels.take(2), ['M', '2']);
      expect(table.values[0][9], 1);
      expect(table.values[6][23], 2);
    });

    test('weekday by month crosses the two', () {
      final table = seasonalityTable(
        _samples,
        grid: SeasonalityGrid.weekdayByMonth,
        aggregate: SeasonalityAggregate.count,
      );
      expect(table.columnCount, 12);
      // 5 January 2025 was a Sunday.
      expect(table.counts[6][0], 1);
      expect(table.values[6][0], 1);
    });

    test('nothing to gather is an empty year grid', () {
      final table = seasonalityTable(const []);
      expect(table.rowCount, 0);
      expect(table.columnCount, 12);
    });
  });

  group('the widget', () {
    testWidgets('builds a heatmap with summaries and reports touches', (
      tester,
    ) async {
      SeasonalityTouchDetails? touched;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SeasonalityChart(
                  samples: _samples,
                  onTouch: (d) => touched = d,
                  tooltipBuilder: (context, d) =>
                      Text('card ${d.rowLabel} ${d.columnLabel}'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(SeasonalityChart)).height, 260);
      final heatmap = tester.widget<HeatmapChart>(find.byType(HeatmapChart));
      expect(heatmap.columns, 13);
      expect(heatmap.rows, 3);
      expect(heatmap.minValue, closeTo(-0.0506, 1e-4));
      expect(heatmap.maxValue, closeTo(0.0506, 1e-4));
      expect(heatmap.labelBuilder!(heatmap.cells.first), '+4.5%');

      final chart = tester.getRect(find.byType(HeatmapChart));
      // The bottom-right square: the summary row and column meet there.
      final gesture = await tester.startGesture(
        chart.bottomRight - const Offset(8, 36),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(touched?.isRowSummary, isTrue);
      expect(touched?.isColumnSummary, isTrue);
      expect(touched?.rowLabel, 'Avg');
      expect(touched?.columnLabel, 'Total');
      expect(find.text('card Avg Total'), findsOneWidget);
      await gesture.up();
      await tester.pump();
    });

    testWidgets('win rates centre on a half, counts start at zero', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SeasonalityChart(
              samples: _samples,
              grid: SeasonalityGrid.weekdayByHour,
              aggregate: SeasonalityAggregate.winRate,
              showColumnSummary: false,
            ),
          ),
        ),
      );
      var heatmap = tester.widget<HeatmapChart>(find.byType(HeatmapChart));
      expect(heatmap.minValue, 0);
      expect(heatmap.maxValue, 1);
      expect(heatmap.rows, 7);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SeasonalityChart(
              samples: _samples,
              aggregate: SeasonalityAggregate.count,
              showRowSummary: false,
            ),
          ),
        ),
      );
      heatmap = tester.widget<HeatmapChart>(find.byType(HeatmapChart));
      expect(heatmap.minValue, 0);
      expect(heatmap.columns, 12);
      expect(tester.takeException(), isNull);
    });
  });
}
