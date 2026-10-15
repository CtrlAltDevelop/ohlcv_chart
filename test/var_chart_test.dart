import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

/// One hundred returns, -0.50 to +0.49 in steps of 0.01.
List<double> _hundred() => [for (var i = 0; i < 100; i++) (i - 50) / 100];

void main() {
  group('value at risk', () {
    test('is the return only a fraction of the history fell below', () {
      final risk = ValueAtRisk.fromReturns(_hundred(), confidence: 0.95);

      // The 5th percentile of -0.50..0.49 by interpolation.
      expect(risk.valueAtRisk, closeTo(-0.5 + 0.05 * 99 / 100, 1e-9));
      expect(risk.count, 100);
      expect(risk.worst, -0.5);
      expect(risk.mean, closeTo(-0.005, 1e-9));
    });

    test('expected shortfall is the average of the tail, never above it', () {
      final risk = ValueAtRisk.fromReturns(_hundred(), confidence: 0.95);

      expect(risk.expectedShortfall, lessThanOrEqualTo(risk.valueAtRisk));
      // The five returns -0.50 .. -0.46 sit at or below the threshold.
      expect(risk.expectedShortfall, closeTo(-0.48, 1e-9));
    });

    test('a higher confidence reaches further into the tail', () {
      final at95 = ValueAtRisk.fromReturns(_hundred(), confidence: 0.95);
      final at99 = ValueAtRisk.fromReturns(_hundred(), confidence: 0.99);

      expect(at99.valueAtRisk, lessThan(at95.valueAtRisk));
      expect(at99.expectedShortfall, lessThanOrEqualTo(at95.expectedShortfall));
    });

    test('skips what is not a number, and says zero for nothing', () {
      final risk = ValueAtRisk.fromReturns(const [
        double.nan,
        -0.1,
        double.infinity,
        0.1,
      ]);
      expect(risk.count, 2);

      final empty = ValueAtRisk.fromReturns(const []);
      expect(empty.count, 0);
      expect(empty.valueAtRisk, 0);
      expect(empty.expectedShortfall, 0);
    });

    test('one return is its own value at risk', () {
      final risk = ValueAtRisk.fromReturns(const [-0.02]);

      expect(risk.valueAtRisk, -0.02);
      expect(risk.expectedShortfall, -0.02);
      expect(risk.standardDeviation, 0);
    });

    test('the standard deviation is the sample one', () {
      final risk = ValueAtRisk.fromReturns(const [1, 2, 3, 4]);

      expect(risk.standardDeviation, closeTo(1.2909944487, 1e-9));
    });
  });

  group('the bins', () {
    test('those in the tail carry the tail colour', () {
      const tail = Color(0xFFFF0000);
      final bins = varBins(
        _hundred(),
        valueAtRisk: -0.45,
        tailColor: tail,
        binWidth: 0.1,
      );

      expect(bins.first.color, tail);
      expect(bins.last.color, isNull);
      final tinted = bins.where((b) => b.color == tail).length;
      expect(tinted, inInclusiveRange(1, 2));
    });
  });

  group('the widget', () {
    Widget host(Widget chart, {double height = 300}) => MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 400, height: height, child: chart),
      ),
    );

    testWidgets('writes the figures and draws a histogram', (tester) async {
      await tester.pumpWidget(host(VarChart(returns: _hundred())));

      expect(find.byType(HistogramChart), findsOneWidget);
      expect(find.text('VaR 95%'), findsOneWidget);
      expect(find.text('CVaR 95%'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('showStats: false leaves only the histogram', (tester) async {
      await tester.pumpWidget(
        host(VarChart(returns: _hundred(), showStats: false)),
      );

      expect(find.text('VaR 95%'), findsNothing);
      expect(find.byType(HistogramChart), findsOneWidget);
    });

    testWidgets('a box too short for the figures drops them', (tester) async {
      await tester.pumpWidget(host(VarChart(returns: _hundred()), height: 90));

      expect(find.text('VaR 95%'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('survives no returns', (tester) async {
      await tester.pumpWidget(host(const VarChart(returns: [])));

      expect(tester.takeException(), isNull);
    });
  });
}
