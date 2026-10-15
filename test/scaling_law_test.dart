import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

/// Points exactly on loss = 8 × scale^-0.05, over six decades.
List<ScalingPoint> _law() => [
  for (var e = 18; e <= 23; e++)
    ScalingPoint(
      scale: math.pow(10.0, e).toDouble(),
      loss: 8 * math.pow(math.pow(10.0, e), -0.05).toDouble(),
      label: '1e$e',
    ),
];

void main() {
  group('the fit', () {
    test('recovers the law the points lie on', () {
      final fit = fitPowerLaw(_law())!;

      expect(fit.exponent, closeTo(-0.05, 1e-9));
      expect(fit.coefficient, closeTo(8, 1e-6));
      expect(fit.rSquared, closeTo(1, 1e-9));
      expect(fit.logResidual, closeTo(0, 1e-9));
      expect(fit.count, 6);
    });

    test('predicts a loss at a scale, and a scale for a loss', () {
      final fit = fitPowerLaw(_law())!;

      expect(fit.predict(1e24), closeTo(8 * math.pow(1e24, -0.05), 1e-6));
      final scale = fit.scaleFor(2.0)!;
      expect(fit.predict(scale), closeTo(2.0, 1e-9));
    });

    test('noisy points give a worse fit, with a residual', () {
      final noisy = [
        for (var i = 0; i < _law().length; i++)
          ScalingPoint(
            scale: _law()[i].scale,
            loss: _law()[i].loss * (i.isEven ? 1.1 : 0.9),
          ),
      ];
      final fit = fitPowerLaw(noisy)!;

      expect(fit.rSquared, lessThan(1));
      expect(fit.logResidual, greaterThan(0.02));
    });

    test('needs two points at two scales', () {
      expect(fitPowerLaw(const []), isNull);
      expect(fitPowerLaw(const [ScalingPoint(scale: 10, loss: 2)]), isNull);
      expect(
        fitPowerLaw(const [
          ScalingPoint(scale: 10, loss: 2),
          ScalingPoint(scale: 10, loss: 3),
        ]),
        isNull,
      );
    });

    test('skips points a logarithm cannot take', () {
      final fit = fitPowerLaw([
        ..._law(),
        const ScalingPoint(scale: 0, loss: 3),
        const ScalingPoint(scale: 1e20, loss: -1),
        const ScalingPoint(scale: double.nan, loss: 3),
        const ScalingPoint(scale: 1e20, loss: double.infinity),
      ])!;

      expect(fit.count, 6);
    });

    test('a flat line has no scale that reaches a different loss', () {
      final fit = fitPowerLaw(const [
        ScalingPoint(scale: 10, loss: 2),
        ScalingPoint(scale: 100, loss: 2),
      ])!;

      expect(fit.exponent, closeTo(0, 1e-12));
      expect(fit.scaleFor(1), isNull);
    });
  });

  group('the widget', () {
    Widget host(Widget chart) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 400, height: 300, child: chart)),
    );

    testWidgets('reports a point and how far it is above the fit', (
      tester,
    ) async {
      ScalingTouchDetails? touched;
      final points = [
        ..._law().take(5),
        // The last model is 10% worse than the law predicts.
        ScalingPoint(
          scale: 1e23,
          loss: 8 * math.pow(1e23, -0.05) * 1.1,
          label: 'off',
        ),
      ];
      await tester.pumpWidget(
        host(
          ScalingLawChart(
            points: points,
            fitFrom: 1e18,
            showLabels: false,
            onTouch: (d) => touched = d,
          ),
        ),
      );

      // Find the point by sweeping the right edge of the plot, where the
      // largest model sits.
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      final origin = tester.getTopLeft(find.byType(ScalingLawChart));
      for (var y = 5.0; y < 250 && touched == null; y += 3) {
        await gesture.moveTo(origin + Offset(380, y));
      }

      expect(touched, isNotNull);
      expect(touched!.point.label, 'off');
      expect(touched!.ratio, isNotNull);
    });

    testWidgets('draws a target, an extrapolation and no fit', (tester) async {
      await tester.pumpWidget(
        host(
          ScalingLawChart(points: _law(), extrapolateTo: 1e26, targetLoss: 1.5),
        ),
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        host(const ScalingLawChart(points: [], targetLoss: 2)),
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        host(
          const ScalingLawChart(
            points: [ScalingPoint(scale: 1e20, loss: 2)],
            extrapolateTo: 1e22,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
