import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

const _results = [2.0, -1.0, -1.0, 3.0, -0.5, 0.0];

void main() {
  group('R multiples', () {
    test('profit over risk, skipping trades with no risk', () {
      expect(rMultiplesFrom([200, -50, 10], [100, 50, 0]), [2, -1]);
    });

    test('the statistics add up', () {
      final stats = RMultipleStats.fromResults(_results);
      expect(stats.count, 6);
      expect(stats.wins, 2);
      expect(stats.losses, 3);
      expect(stats.winRate, closeTo(1 / 3, 1e-9));
      expect(stats.total, 2.5);
      expect(stats.expectancy, closeTo(2.5 / 6, 1e-9));
      expect(stats.averageWin, 2.5);
      expect(stats.averageLoss, closeTo(-2.5 / 3, 1e-9));
      expect(stats.largestWin, 3);
      expect(stats.largestLoss, -1);
      expect(stats.profitFactor, 2);
    });

    test('spread and SQN follow the sample standard deviation', () {
      final stats = RMultipleStats.fromResults(const [1, -1, 1, -1]);
      expect(stats.expectancy, 0);
      expect(stats.standardDeviation, closeTo(1.1547, 1e-4));
      expect(stats.sqn, 0);

      final steady = RMultipleStats.fromResults(const [1, 2, 3]);
      expect(steady.sqn, closeTo(2 / 1 * 1.7320508, 1e-6));
    });

    test('no losses gives an infinite profit factor, nothing gives zeros', () {
      expect(
        RMultipleStats.fromResults(const [1, 2]).profitFactor,
        double.infinity,
      );
      final none = RMultipleStats.fromResults(const [double.nan]);
      expect(none.count, 0);
      expect(none.winRate, 0);
      expect(none.profitFactor, 0);
      expect(none.sqn, 0);
    });

    test('bins split at zero and take in the edges', () {
      final bins = rMultipleBins(_results, binWidth: 1);
      expect(bins.first.from, -1);
      expect(bins.last.to, 4);
      expect(bins.any((b) => b.from < 0 && b.to > 0), isFalse);
      expect([for (final b in bins) b.count], [3, 1, 0, 1, 1]);
      expect(rMultipleBins(const []), isEmpty);
      expect(rMultipleBins(_results, binWidth: 0), isEmpty);
    });
  });

  group('the widget', () {
    testWidgets('shows the statistics and the histogram', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [RMultipleChart(results: _results, semanticLabel: 'R')],
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(RMultipleChart)).height, 260);
      expect(find.byType(HistogramChart), findsOneWidget);
      expect(find.text('Expectancy'), findsOneWidget);
      expect(find.text('+0.42R'), findsOneWidget);
      expect(find.text('33.3%'), findsOneWidget);
      expect(find.text('2.00'), findsOneWidget);
    });

    testWidgets('takes its own figures, or none', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RMultipleChart(
              results: _results,
              statsBuilder: (s) => [RMultipleStat('Best', '${s.largestWin}')],
            ),
          ),
        ),
      );
      expect(find.text('Best'), findsOneWidget);
      expect(find.text('Expectancy'), findsNothing);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: RMultipleChart(results: [], showStats: false)),
        ),
      );
      expect(find.text('Trades'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
