import 'dart:ui' show PointerDeviceKind;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

List<TrainingPoint> _points(List<double> values) => [
  for (var i = 0; i < values.length; i++) TrainingPoint(i * 100.0, values[i]),
];

void main() {
  group('smoothing', () {
    test('a weight of zero leaves the values alone', () {
      expect(smoothValues([3, 1, 2], 0), [3, 1, 2]);
    });

    test('the first reading is not dragged toward zero', () {
      final out = smoothValues([10, 10, 10, 10], 0.9);

      for (final v in out) {
        expect(v, closeTo(10, 1e-9));
      }
    });

    test('a spike is spread, not erased', () {
      final out = smoothValues([1, 1, 1, 9, 1, 1], 0.8);

      expect(out[3]!, lessThan(9));
      expect(out[3]!, greaterThan(1));
      expect(out[4]!, greaterThan(1));
    });

    test(
      'a value that is not a number is skipped, and the average goes on',
      () {
        final out = smoothValues([2, double.nan, 2], 0.5);

        expect(out[1], isNull);
        expect(out[2], closeTo(2, 1e-9));
      },
    );

    test('a weight outside 0..1 is held to the range', () {
      expect(smoothValues([4, 4], -1), [4, 4]);
      expect(smoothValues([4, 4], 5).every((v) => v!.isFinite), isTrue);
      expect(smoothValues(const [], 0.5), isEmpty);
    });
  });

  group('the best checkpoint', () {
    test('is the lowest loss, or the highest accuracy', () {
      expect(bestIndex([3, 1, 2]), 1);
      expect(bestIndex([3, 1, 2], lowerIsBetter: false), 0);
    });

    test('skips values that are not finite, and may be none', () {
      expect(bestIndex([double.nan, 5, double.infinity]), 1);
      expect(bestIndex([double.nan]), isNull);
      expect(bestIndex(const []), isNull);
    });

    test('the first of equals wins', () {
      expect(bestIndex([2, 1, 1]), 1);
    });
  });

  group('divergence', () {
    test('a loss that climbs past a multiple of its lowest', () {
      expect(divergenceIndex([2.0, 1.5, 1.0, 1.1, 4.0, 9.0]), 4);
    });

    test('a loss that becomes NaN after training', () {
      expect(divergenceIndex([2.0, 1.0, double.nan, 1.0]), 2);
    });

    test('a healthy curve never diverges', () {
      expect(divergenceIndex([3.0, 2.5, 2.0, 2.2, 1.9]), isNull);
      expect(divergenceIndex(const []), isNull);
    });

    test('NaN before any real value is not a divergence', () {
      expect(divergenceIndex([double.nan, 2.0, 1.0]), isNull);
    });

    test('the factor is the caller\'s to set', () {
      expect(divergenceIndex([1.0, 1.6], factor: 1.5), 1);
      expect(divergenceIndex([1.0, 1.6], factor: 2), isNull);
    });
  });

  group('the widget', () {
    Widget host(Widget chart) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 400, height: 300, child: chart)),
    );

    testWidgets('reports every run\'s reading at the touched step', (
      tester,
    ) async {
      TrainingTouchDetails? touched;
      await tester.pumpWidget(
        host(
          TrainingCurveChart(
            runs: [
              TrainingRun(label: 'train', points: _points([3, 2, 1.5, 1.2, 1])),
              TrainingRun(
                label: 'val',
                points: _points([3.2, 2.4, 2, 1.9, 1.95]),
                dashed: true,
              ),
            ],
            gapBetween: (0, 1),
            onTouch: (d) => touched = d,
          ),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      final origin = tester.getTopLeft(find.byType(TrainingCurveChart));
      // Half way along the plot: past the 48 px axis, over steps 0..400.
      await gesture.moveTo(origin + const Offset(48 + (400 - 48) / 2, 120));

      expect(touched, isNotNull);
      expect(touched!.step, 200);
      expect(touched!.readings, hasLength(2));
      expect(touched!.readings[0].point?.value, 1.5);
      expect(touched!.readings[1].point?.value, 2);

      await gesture.moveTo(origin + const Offset(2, 2));
      expect(touched, isNull);
    });

    testWidgets('draws smoothed, logarithmic, and with a diverged run', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          TrainingCurveChart(
            runs: [
              TrainingRun(
                label: 'ok',
                points: _points([10, 3, 1, 0.3, 0.1, 0.05]),
              ),
              TrainingRun(
                label: 'blew up',
                points: _points([10, 3, 1, 0.5, 8, double.nan]),
              ),
            ],
            smoothing: 0.6,
            logY: true,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('survives no runs, empty runs and a single point', (
      tester,
    ) async {
      await tester.pumpWidget(host(const TrainingCurveChart(runs: [])));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        host(
          const TrainingCurveChart(
            runs: [
              TrainingRun(label: 'a', points: []),
              TrainingRun(label: 'b', points: [TrainingPoint(0, 1)]),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
