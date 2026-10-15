import 'dart:ui' show PointerDeviceKind;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

final _t0 = DateTime.utc(2026, 9, 1);

List<LatencySample> _samples() => [
  for (var i = 0; i < 12; i++)
    LatencySample(
      time: _t0.add(Duration(minutes: i * 5)),
      p50: 400.0 + i * 5,
      p95: 900.0 + (i == 5 ? 700 : 0) + i * 10,
      p99: 1500.0 + (i == 5 ? 1500 : 0) + i * 20,
    ),
];

void main() {
  group('breaches', () {
    test('are the intervals whose percentile is over the objective', () {
      expect(sloBreaches(_samples(), 1200), [5]);
    });

    test('follow the percentile the objective is set on', () {
      expect(
        sloBreaches(_samples(), 1200, percentile: LatencyPercentile.p99),
        hasLength(12),
      );
      expect(
        sloBreaches(_samples(), 1200, percentile: LatencyPercentile.p50),
        isEmpty,
      );
    });

    test('a value that is not a number is not a breach', () {
      final samples = [
        LatencySample(time: _t0, p50: 1, p95: double.nan, p99: 3),
      ];

      expect(sloBreaches(samples, 0.5), isEmpty);
      expect(sloBreaches(const [], 100), isEmpty);
    });

    test('an interval exactly on the objective is within it', () {
      final samples = [LatencySample(time: _t0, p50: 1, p95: 1000, p99: 2)];

      expect(sloBreaches(samples, 1000), isEmpty);
    });
  });

  group('the widget', () {
    Widget host(Widget chart) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 400, height: 300, child: chart)),
    );

    testWidgets('reports a sample and whether it broke the objective', (
      tester,
    ) async {
      LatencyTouchDetails? touched;
      await tester.pumpWidget(
        host(
          LatencyBandChart(
            samples: _samples(),
            slo: 1200,
            onTouch: (d) => touched = d,
          ),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      final origin = tester.getTopLeft(find.byType(LatencyBandChart));
      // Sample 5 of 12, over a plot from 52 to 400 px.
      await gesture.moveTo(origin + Offset(52 + (400 - 52) * 5 / 11, 100));

      expect(touched, isNotNull);
      expect(touched!.index, 5);
      expect(touched!.breached, isTrue);

      await gesture.moveTo(origin + Offset(52 + (400 - 52) * 2 / 11, 100));
      expect(touched!.index, 2);
      expect(touched!.breached, isFalse);
    });

    testWidgets('draws logarithmic, with no objective', (tester) async {
      await tester.pumpWidget(
        host(LatencyBandChart(samples: _samples(), logY: true)),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('survives no samples, one sample and bad values', (
      tester,
    ) async {
      await tester.pumpWidget(host(const LatencyBandChart(samples: [])));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        host(
          LatencyBandChart(
            samples: [LatencySample(time: _t0, p50: 1, p95: 2, p99: 3)],
            slo: 2.5,
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        host(
          LatencyBandChart(
            samples: [
              LatencySample(time: _t0, p50: double.nan, p95: 2, p99: 3),
              LatencySample(
                time: _t0.add(const Duration(minutes: 1)),
                p50: 1,
                p95: double.infinity,
                p99: 3,
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
