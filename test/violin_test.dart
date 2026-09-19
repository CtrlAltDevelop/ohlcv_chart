import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

List<double> _normal({double mean = 0, double deviation = 1, int n = 300}) {
  final random = math.Random(7);
  return [
    for (var i = 0; i < n; i++)
      mean +
          deviation *
              math.sqrt(-2 * math.log(random.nextDouble() + 1e-12)) *
              math.cos(2 * math.pi * random.nextDouble()),
  ];
}

void main() {
  group('the density', () {
    test('peaks where the samples are', () {
      final curve = kernelDensity(_normal(mean: 10, deviation: 2));
      var peakAt = 0;
      for (var i = 1; i < curve.densities.length; i++) {
        if (curve.densities[i] > curve.densities[peakAt]) peakAt = i;
      }
      expect(curve.valueAt(peakAt), closeTo(10, 1));
    });

    test('it is a density: it integrates to about one', () {
      final curve = kernelDensity(_normal(), points: 256);
      final step = (curve.max - curve.min) / (curve.densities.length - 1);
      final area = curve.densities.fold<double>(0, (a, b) => a + b) * step;
      expect(area, closeTo(1, 0.05));
    });

    test('the tails close past the outermost samples', () {
      final samples = _normal();
      final curve = kernelDensity(samples);
      expect(curve.min, lessThan(samples.reduce(math.min)));
      expect(curve.max, greaterThan(samples.reduce(math.max)));
      expect(curve.densities.first, lessThan(curve.peak / 4));
    });

    test('a wider bandwidth flattens the curve', () {
      final samples = _normal();
      final tight = kernelDensity(samples, bandwidth: 0.2);
      final loose = kernelDensity(samples, bandwidth: 2);
      expect(loose.peak, lessThan(tight.peak));
    });

    test('samples all alike still have a shape to draw', () {
      final curve = kernelDensity(const [5, 5, 5, 5]);
      expect(curve.isEmpty, false);
      expect(curve.peak, greaterThan(0));
    });

    test('nothing at all is empty', () {
      expect(kernelDensity(const []).isEmpty, true);
      expect(kernelDensity(const [double.nan]).isEmpty, true);
    });
  });

  group('the layout', () {
    final series = [
      ViolinSeries(label: 'Trend', samples: _normal(mean: 0)),
      ViolinSeries(label: 'Revert', samples: _normal(mean: 4, deviation: 0.5)),
    ];

    test('violins sit side by side, values running up the chart', () {
      final layout = layOutViolin(series, size: const Size(400, 200));
      expect(layout.series, hasLength(2));
      expect(
        layout.series[0].bandRect.right,
        closeTo(layout.series[1].bandRect.left, 1e-9),
      );
      expect(
        layout.positionOf(layout.max),
        lessThan(layout.positionOf(layout.min)),
      );
    });

    test('a ridgeline stacks down the chart and overlaps', () {
      final layout = layOutViolin(
        series,
        size: const Size(400, 200),
        shape: ViolinShape.ridgeline,
        overlap: 0.5,
      );
      expect(
        layout.series[1].bandRect.top,
        greaterThan(layout.series[0].bandRect.top),
      );
      expect(
        layout.series[1].bandRect.top,
        lessThan(layout.series[0].bandRect.bottom),
      );
      // Values run across a ridgeline, not up it.
      expect(
        layout.positionOf(layout.max),
        greaterThan(layout.positionOf(layout.min)),
      );
    });

    test('shapes share one scale, so their areas compare', () {
      final layout = layOutViolin(series, size: const Size(400, 200));
      // The tight distribution is the taller peak, so it is the wider violin.
      expect(
        layout.series[1].outline.getBounds().width,
        greaterThan(layout.series[0].outline.getBounds().width),
      );
    });

    test('the quartiles sit inside the violin', () {
      final layout = layOutViolin(series, size: const Size(400, 200));
      final laid = layout.series.first;
      expect(laid.boxRect, isNotNull);
      expect(
        laid.medianAt.dy,
        closeTo(layout.positionOf(laid.stats.median), 1e-9),
      );
      expect(laid.whiskerTo.dy, lessThan(laid.whiskerFrom.dy));
    });

    test('a ridgeline has no quartile box', () {
      final layout = layOutViolin(
        series,
        size: const Size(400, 200),
        shape: ViolinShape.ridgeline,
      );
      expect(layout.series.first.boxRect, isNull);
    });

    test('progress grows the shapes out of their centre', () {
      final half = layOutViolin(
        series,
        size: const Size(400, 200),
        progress: 0.5,
      );
      final full = layOutViolin(series, size: const Size(400, 200));
      expect(
        half.series.first.outline.getBounds().width,
        closeTo(full.series.first.outline.getBounds().width / 2, 1),
      );
    });

    test('nothing to show lays out nothing', () {
      expect(layOutViolin(const [], size: const Size(400, 200)).isEmpty, true);
      expect(layOutViolin(series, size: Size.zero).isEmpty, true);
      expect(
        layOutViolin(const [
          ViolinSeries(label: 'a', samples: []),
        ], size: const Size(400, 200)).isEmpty,
        true,
      );
    });

    test('a point finds the series under it', () {
      final layout = layOutViolin(series, size: const Size(400, 200));
      expect(layout.seriesAt(layout.series[1].bandRect.center)?.index, 1);
      expect(layout.seriesAt(const Offset(-10, -10)), isNull);
    });
  });

  group('the widget', () {
    testWidgets('draws and reports the series under the finger', (
      tester,
    ) async {
      ViolinSeries? touched;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 200,
              child: ViolinChart(
                series: [
                  ViolinSeries(label: 'Trend', samples: _normal()),
                  ViolinSeries(label: 'Revert', samples: _normal(mean: 3)),
                ],
                onSeriesTap: (series) => touched = series ?? touched,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(ViolinChart), findsOneWidget);

      final box = tester.getRect(find.byType(ViolinChart));
      final gesture = await tester.startGesture(
        Offset(box.right - 60, box.center.dy),
      );
      await tester.pump();
      expect(touched?.label, 'Revert');
      await gesture.up();
      await tester.pump();
    });

    testWidgets('takes its default height in an unbounded box', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ViolinChart(
                series: [ViolinSeries(label: 'a', samples: _normal())],
                defaultHeight: 180,
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(ViolinChart)).height, 180);
    });

    testWidgets('grows the shapes out over time', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 200,
              child: ViolinChart(
                series: [ViolinSeries(label: 'a', samples: _normal())],
                shape: ViolinShape.ridgeline,
                animationDuration: const Duration(milliseconds: 200),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
