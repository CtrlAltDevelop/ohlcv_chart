import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

void main() {
  group('pie layout', () {
    const sections = [
      PieSection(value: 50),
      PieSection(value: 25),
      PieSection(value: 25),
    ];

    test('each section gets the share of the circle its value is worth', () {
      final slices = layOutPie(
        sections: sections,
        radius: 100,
        innerRadius: 0,
        startAngle: 0,
      );

      expect(slices.map((s) => s.index), [0, 1, 2]);
      expect(slices[0].sweepAngle, closeTo(math.pi, 1e-9));
      expect(slices[1].sweepAngle, closeTo(math.pi / 2, 1e-9));
      expect(slices[1].startAngle, closeTo(math.pi, 1e-9));
      expect(slices[2].startAngle, closeTo(math.pi * 1.5, 1e-9));
    });

    test(
        'sections worth nothing are left out, and nothing at all lays out '
        'as nothing', () {
      final some = layOutPie(
        sections: const [
          PieSection(value: 1),
          PieSection(value: 0),
          PieSection(value: 1),
        ],
        radius: 50,
        innerRadius: 0,
      );
      expect(some.map((s) => s.index), [0, 2]);

      expect(
        layOutPie(
          sections: const [PieSection(value: 0)],
          radius: 50,
          innerRadius: 0,
        ),
        isEmpty,
      );
    });

    test('going anticlockwise mirrors the sections about the start', () {
      final back = layOutPie(
        sections: sections,
        radius: 100,
        innerRadius: 0,
        startAngle: 0,
        clockwise: false,
      );
      // The first section ends where a clockwise one would have started.
      expect(back[0].startAngle + back[0].sweepAngle, closeTo(0, 1e-9));
      expect(back[1].startAngle + back[1].sweepAngle, closeTo(-math.pi, 1e-9));
    });

    test('the animation sweeps the sections open without moving them', () {
      final half = layOutPie(
        sections: sections,
        radius: 100,
        innerRadius: 0,
        startAngle: 0,
        animation: 0.5,
      );
      expect(half[0].sweepAngle, closeTo(math.pi / 2, 1e-9));
      expect(half[1].startAngle, closeTo(math.pi, 1e-9));
    });

    test('the space between sections is taken off each of them', () {
      final spaced = layOutPie(
        sections: sections,
        radius: 100,
        innerRadius: 0,
        startAngle: 0,
        space: 10,
      );
      expect(spaced[0].sweepAngle, closeTo(math.pi - 0.1, 1e-9));
      expect(spaced[0].startAngle, closeTo(0.05, 1e-9));
    });
  });

  group('what a touch on a pie lands on', () {
    final slices = layOutPie(
      sections: const [PieSection(value: 1), PieSection(value: 1)],
      radius: 100,
      innerRadius: 40,
      startAngle: 0,
    );
    const centre = Offset(100, 100);

    test('a point in a section names it', () {
      expect(
        pieSectionAt(
          local: centre + const Offset(60, 20),
          centre: centre,
          slices: slices,
        ),
        0,
      );
      expect(
        pieSectionAt(
          local: centre + const Offset(-60, -20),
          centre: centre,
          slices: slices,
        ),
        1,
      );
    });

    test('the hole and the space outside name nothing', () {
      expect(
        pieSectionAt(local: centre, centre: centre, slices: slices),
        isNull,
      );
      expect(
        pieSectionAt(
          local: centre + const Offset(200, 0),
          centre: centre,
          slices: slices,
        ),
        isNull,
      );
    });

    test('a section that crosses three o\'clock still matches', () {
      final wrapped = layOutPie(
        sections: const [PieSection(value: 1)],
        radius: 100,
        innerRadius: 0,
        startAngle: -math.pi / 4,
      );
      expect(
        pieSectionAt(
          local: centre + const Offset(50, 1),
          centre: centre,
          slices: wrapped,
        ),
        0,
      );
    });
  });

  group('radar geometry', () {
    test('features are spread evenly, the first at twelve o\'clock', () {
      const centre = Offset(100, 100);
      final top = radarCorner(
        centre: centre,
        radius: 50,
        count: 4,
        index: 0,
      );
      final right = radarCorner(
        centre: centre,
        radius: 50,
        count: 4,
        index: 1,
      );
      expect(top.dx, closeTo(100, 1e-9));
      expect(top.dy, closeTo(50, 1e-9));
      expect(right.dx, closeTo(150, 1e-9));
      expect(right.dy, closeTo(100, 1e-9));
    });

    test('a value is placed between the middle and the outer ring', () {
      const layout = RadarLayout(
        centre: Offset.zero,
        radius: 100,
        count: 5,
        minValue: 0,
        maxValue: 10,
        startAngle: 0,
      );
      expect(layout.radiusFor(0), 0);
      expect(layout.radiusFor(5), 50);
      expect(layout.radiusFor(10), 100);
      // Values beyond the range are held at the edge rather than drawn off it.
      expect(layout.radiusFor(20), 100);
      expect(layout.radiusFor(-5), 0);
    });
  });

  group('the widgets', () {
    testWidgets('a pie draws its sections and answers a tap', (tester) async {
      final touched = <PieTouchDetails?>[];
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: PieChart(
                sections: const [
                  PieSection(value: 1, color: Color(0xFF00FF00), label: 'a'),
                  PieSection(value: 1, color: Color(0xFF0000FF), label: 'b'),
                ],
                centerSpaceRadius: 20,
                centerChild: const Text('mid'),
                onTouch: touched.add,
              ),
            ),
          ),
        ),
      );

      expect(find.text('mid'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Right of the middle is the first section, which starts at twelve.
      await tester.tapAt(
          tester.getCenter(find.byType(PieChart)) + const Offset(60, 10));
      await tester.pump();
      expect(touched.first?.index, 0);
    });

    testWidgets('a radar reports the corner under a tap', (tester) async {
      final touched = <RadarTouchDetails?>[];
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 300,
              height: 300,
              child: RadarChart(
                features: const ['a', 'b', 'c', 'd'],
                series: const [
                  RadarSeries(values: [10, 5, 5, 5]),
                ],
                minValue: 0,
                maxValue: 10,
                radius: 100,
                onTouch: touched.add,
              ),
            ),
          ),
        ),
      );

      final centre = tester.getCenter(find.byType(RadarChart));
      final top = Offset(centre.dx, centre.dy - 100);
      await tester.tapAt(top);
      await tester.pump();
      expect(touched.first?.featureIndex, 0);
      expect(touched.first?.value, 10);
    });

    testWidgets('a radar with no features still draws', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 200,
            height: 200,
            child: RadarChart(
              series: [
                RadarSeries(values: [1, 2, 3]),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
