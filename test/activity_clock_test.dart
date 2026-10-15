import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

void main() {
  group('the layout', () {
    const bounds = Rect.fromLTWH(0, 0, 200, 200);

    test('has a segment per ring and hour', () {
      final segments = layOutClock(7, 24, bounds);

      expect(segments, hasLength(7 * 24));
    });

    test('the dial is the largest circle in the box, centred', () {
      final segments = layOutClock(
        7,
        24,
        const Rect.fromLTWH(0, 0, 300, 200),
        innerFraction: 0,
        ringGap: 0,
      );

      final outer = segments.map((s) => s.outerRadius).reduce(math.max);
      expect(outer, closeTo(100, 1e-9));
    });

    test('hours run clockwise from twelve o\'clock', () {
      final segments = layOutClock(1, 24, bounds, angleGap: 0);

      expect(segments.first.startAngle, closeTo(-math.pi / 2, 1e-9));
      // Hour 6 starts at three o'clock, angle 0.
      expect(segments[6].startAngle, closeTo(0, 1e-9));
      // Hour 12 starts at six o'clock.
      expect(segments[12].startAngle, closeTo(math.pi / 2, 1e-9));
    });

    test('rings run outward, none overlapping', () {
      final segments = layOutClock(7, 24, bounds, ringGap: 2);
      final rings = [
        for (var r = 0; r < 7; r++) segments.firstWhere((s) => s.row == r),
      ];

      for (var r = 1; r < 7; r++) {
        expect(
          rings[r].innerRadius,
          greaterThanOrEqualTo(rings[r - 1].outerRadius),
        );
      }
    });

    test('nothing, or no room, lays nothing out', () {
      expect(layOutClock(0, 24, bounds), isEmpty);
      expect(layOutClock(7, 0, bounds), isEmpty);
      expect(layOutClock(7, 24, Rect.zero), isEmpty);
    });
  });

  group('hit testing', () {
    final segments = layOutClock(
      2,
      4,
      const Rect.fromLTWH(0, 0, 200, 200),
      innerFraction: 0.2,
      ringGap: 0,
      angleGap: 0,
    );
    const center = Offset(100, 100);

    test('a point finds the ring and hour it is in', () {
      // Just right of twelve o'clock, on the inner ring: hour 0.
      final top = clockSegmentAt(segments, center, const Offset(110, 70));
      expect(top?.row, 0);
      expect(top?.column, 0);

      // Three to six o'clock, on the outer ring: hour 1.
      final right = clockSegmentAt(segments, center, const Offset(180, 110));
      expect(right?.row, 1);
      expect(right?.column, 1);

      // Six to nine, inner ring: hour 2.
      final bottom = clockSegmentAt(segments, center, const Offset(90, 140));
      expect(bottom?.row, 0);
      expect(bottom?.column, 2);

      // Nine to twelve, outer ring: hour 3.
      final left = clockSegmentAt(segments, center, const Offset(20, 90));
      expect(left?.row, 1);
      expect(left?.column, 3);
    });

    test('the hole and the outside are nothing', () {
      expect(clockSegmentAt(segments, center, center), isNull);
      expect(clockSegmentAt(segments, center, const Offset(2, 2)), isNull);
      expect(clockSegmentAt(const [], center, center), isNull);
    });
  });

  group('the widget', () {
    final samples = [
      // Monday 2024-01-01 at 09:00 and 10:00; Tuesday at 14:00.
      SeasonalSample(time: DateTime.utc(2024, 1, 1, 9), value: 2),
      SeasonalSample(time: DateTime.utc(2024, 1, 1, 9, 30), value: 4),
      SeasonalSample(time: DateTime.utc(2024, 1, 1, 10), value: -1),
      SeasonalSample(time: DateTime.utc(2024, 1, 2, 14), value: 5),
    ];

    Widget host(Widget chart) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 400, height: 400, child: chart)),
    );

    testWidgets('reports the weekday, hour, value and count of a touch', (
      tester,
    ) async {
      ActivityClockTouchDetails? touched;
      await tester.pumpWidget(
        host(
          ActivityClockChart(
            samples: samples,
            hourLabelStep: 0,
            showWeekdayLabels: false,
            onTouch: (d) => touched = d,
          ),
        ),
      );

      // The dial: 400 box less 20 px of label margin all round: radius 180,
      // centre (200, 200). Hour 9 is 9/24 of the way round from twelve.
      const radius = 180.0;
      const inner = radius * 0.28;
      const pitch = (radius - inner) / 7;
      final angle = -math.pi / 2 + (9 + 0.5) * 2 * math.pi / 24;
      // Monday is the innermost ring.
      const ringMid = inner + pitch * 0.5;
      final at = const Offset(200, 200) + Offset.fromDirection(angle, ringMid);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      final origin = tester.getTopLeft(find.byType(ActivityClockChart));
      await gesture.moveTo(origin + at);

      expect(touched, isNotNull);
      expect(touched!.weekday, 0);
      expect(touched!.hour, 9);
      expect(touched!.count, 2);
      expect(touched!.value, closeTo(3, 1e-9));
      expect(touched!.weekdayLabel, 'Mon');

      await gesture.moveTo(origin + const Offset(200, 200));
      expect(touched, isNull);
    });

    testWidgets('survives no samples and no room', (tester) async {
      await tester.pumpWidget(host(const ActivityClockChart(samples: [])));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 10,
              height: 10,
              child: ActivityClockChart(samples: samples),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
