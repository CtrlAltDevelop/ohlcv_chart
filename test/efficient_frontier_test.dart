import 'dart:ui' show PointerDeviceKind;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

const _points = [
  PortfolioPoint(risk: 0.10, expectedReturn: 0.04, label: 'bonds'),
  PortfolioPoint(risk: 0.12, expectedReturn: 0.03, label: 'beaten'),
  PortfolioPoint(risk: 0.16, expectedReturn: 0.08, label: 'mix'),
  PortfolioPoint(risk: 0.22, expectedReturn: 0.09, label: 'stocks'),
  PortfolioPoint(risk: 0.30, expectedReturn: 0.085, label: 'also beaten'),
];

void main() {
  group('the frontier', () {
    test('keeps the portfolios nothing beats, by rising risk', () {
      expect(efficientFrontierIndices(_points), [0, 2, 3]);
    });

    test('at the same risk only the larger return counts', () {
      final frontier = efficientFrontierIndices(const [
        PortfolioPoint(risk: 0.1, expectedReturn: 0.02),
        PortfolioPoint(risk: 0.1, expectedReturn: 0.05),
        PortfolioPoint(risk: 0.2, expectedReturn: 0.06),
      ]);

      expect(frontier, [1, 2]);
    });

    test('skips what is not a number', () {
      final frontier = efficientFrontierIndices(const [
        PortfolioPoint(risk: double.nan, expectedReturn: 0.5),
        PortfolioPoint(risk: 0.1, expectedReturn: double.infinity),
        PortfolioPoint(risk: 0.1, expectedReturn: 0.03),
      ]);

      expect(frontier, [2]);
      expect(efficientFrontierIndices(const []), isEmpty);
    });
  });

  group('the markers', () {
    test('the best Sharpe ratio is above the risk-free rate', () {
      // 0.04/0.10 = 0.4, 0.08/0.16 = 0.5, 0.09/0.22 = 0.41.
      expect(maxSharpeIndex(_points), 2);
      // With a 3% risk-free rate: 0.1, 0.31, 0.27.
      expect(maxSharpeIndex(_points, riskFree: 0.03), 2);
      // Adding a large constant to every return favours the low-risk end.
      expect(maxSharpeIndex(_points, riskFree: -1), 0);
    });

    test('there is none without any risk to measure against', () {
      expect(
        maxSharpeIndex(const [PortfolioPoint(risk: 0, expectedReturn: 0.1)]),
        isNull,
      );
      expect(maxSharpeIndex(const []), isNull);
    });

    test('the least risky portfolio, the larger return breaking a tie', () {
      expect(minRiskIndex(_points), 0);
      expect(
        minRiskIndex(const [
          PortfolioPoint(risk: 0.1, expectedReturn: 0.02),
          PortfolioPoint(risk: 0.1, expectedReturn: 0.05),
        ]),
        1,
      );
      expect(minRiskIndex(const []), isNull);
    });

    test('sharpe needs a positive risk', () {
      expect(
        const PortfolioPoint(risk: 0.2, expectedReturn: 0.1).sharpe(0.02),
        closeTo(0.4, 1e-9),
      );
      expect(
        const PortfolioPoint(risk: 0, expectedReturn: 0.1).sharpe(),
        isNull,
      );
    });
  });

  test('the range starts risk at zero and holds the risk-free rate', () {
    final range = frontierRange(_points, riskFree: 0.0);

    expect(range.minRisk, 0);
    expect(range.maxRisk, greaterThan(0.30));
    expect(range.minReturn, lessThanOrEqualTo(0));
    expect(range.maxReturn, greaterThan(0.09));
  });

  group('the widget', () {
    Widget host(Widget chart) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 400, height: 300, child: chart)),
    );

    testWidgets('names the best and the least risky portfolio by role', (
      tester,
    ) async {
      FrontierTouchDetails? touched;
      await tester.pumpWidget(
        host(
          EfficientFrontierChart(
            points: _points,
            riskFreeRate: 0.0,
            current: const PortfolioPoint(risk: 0.2, expectedReturn: 0.05),
            onTouch: (d) => touched = d,
          ),
        ),
      );

      final range = frontierRange([
        ..._points,
        const PortfolioPoint(risk: 0.2, expectedReturn: 0.05),
      ]);
      Offset at(PortfolioPoint p) => Offset(
        44 + p.risk / range.maxRisk * (400 - 44),
        (300 - 32) -
            (p.expectedReturn - range.minReturn) /
                (range.maxReturn - range.minReturn) *
                (300 - 32),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      final origin = tester.getTopLeft(find.byType(EfficientFrontierChart));

      await gesture.moveTo(origin + at(_points[2]));
      expect(touched?.dot.role, FrontierRole.maxSharpe);
      expect(touched?.point.label, 'mix');
      expect(touched?.sharpe, closeTo(0.5, 1e-9));

      await gesture.moveTo(origin + at(_points[0]));
      expect(touched?.dot.role, FrontierRole.minRisk);

      await gesture.moveTo(origin + at(_points[1]));
      expect(touched?.dot.role, FrontierRole.portfolio);

      await gesture.moveTo(
        origin + at(const PortfolioPoint(risk: 0.2, expectedReturn: 0.05)),
      );
      expect(touched?.dot.role, FrontierRole.current);
    });

    testWidgets('survives no portfolios', (tester) async {
      await tester.pumpWidget(host(const EfficientFrontierChart(points: [])));

      expect(tester.takeException(), isNull);
    });
  });
}
