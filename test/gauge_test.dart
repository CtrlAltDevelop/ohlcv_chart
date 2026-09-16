import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

void main() {
  group('the layout', () {
    const dial = GaugeLayout(
      center: Offset(100, 100),
      radius: 80,
      min: 0,
      max: 100,
    );

    test('values run along the arc, held to its ends', () {
      expect(dial.fractionOf(0), 0);
      expect(dial.fractionOf(50), 0.5);
      expect(dial.fractionOf(100), 1);
      expect(dial.fractionOf(-20), 0);
      expect(dial.fractionOf(140), 1);
      expect(dial.fractionOf(double.nan), 0);
    });

    test('the middle of a symmetric dial points straight up', () {
      final top = dial.pointAt(50, 80);
      expect(top.dx, closeTo(100, 1e-9));
      expect(top.dy, closeTo(20, 1e-9));
    });

    test('angles are measured clockwise from twelve o\'clock', () {
      const half = GaugeLayout(
        center: Offset.zero,
        radius: 1,
        min: 0,
        max: 1,
        startAngle: -90,
        sweepAngle: 180,
      );
      final left = half.pointAt(0, 1);
      final right = half.pointAt(1, 1);
      expect(left.dx, closeTo(-1, 1e-9));
      expect(right.dx, closeTo(1, 1e-9));
      expect(half.pointAt(0.5, 1).dy, closeTo(-1, 1e-9));
    });

    test('an empty range puts every value at the start', () {
      const flat = GaugeLayout(
        center: Offset.zero,
        radius: 1,
        min: 5,
        max: 5,
      );
      expect(flat.fractionOf(5), 0);
    });

    test('a half circle is fitted to a box twice as wide as tall', () {
      final extent = GaugeLayout.arcExtent(-90, 180);
      expect(extent.width, closeTo(2, 1e-9));
      expect(extent.height, closeTo(1, 1e-3));

      final layout = GaugeLayout.fit(
        const Rect.fromLTWH(0, 0, 200, 100),
        min: 0,
        max: 1,
        startAngle: -90,
        sweepAngle: 180,
      );
      expect(layout.radius, closeTo(100, 1e-6));
      expect(layout.center.dx, closeTo(100, 1e-6));
      expect(layout.center.dy, closeTo(100, 0.2));
    });

    test('a full dial fits the shorter side of its box', () {
      final layout = GaugeLayout.fit(
        const Rect.fromLTWH(0, 0, 300, 200),
        min: 0,
        max: 1,
        startAngle: 0,
        sweepAngle: 360,
      );
      expect(layout.radius, closeTo(100, 1e-6));
      expect(layout.center, const Offset(150, 100));
    });
  });

  group('ticks', () {
    test('a count divides the range evenly', () {
      expect(
          const GaugeTicks(count: 4).majorValues(0, 100), [0, 25, 50, 75, 100]);
    });

    test('an interval steps from the start and stops inside the range', () {
      expect(
        const GaugeTicks(interval: 30).majorValues(0, 100),
        [0, 30, 60, 90],
      );
    });

    test('nothing to divide, or no marks asked for, gives no marks', () {
      expect(const GaugeTicks().majorValues(5, 5), isEmpty);
      expect(GaugeTicks.none.majorValues(0, 100), isEmpty);
      expect(const GaugeTicks(interval: 0).majorValues(0, 100), isEmpty);
    });

    test('labels drop needless decimals', () {
      const ticks = GaugeTicks();
      expect(ticks.labelFor(25), '25');
      expect(ticks.labelFor(12.5), '12.5');
      expect(
        GaugeTicks(formatter: (v) => '${v.round()}%').labelFor(40),
        '40%',
      );
    });
  });

  test('a range knows what it holds, whichever way round it is given', () {
    const range = GaugeRange(from: 80, to: 40, color: Color(0xFF000000));
    expect(range.contains(60), isTrue);
    expect(range.contains(40), isTrue);
    expect(range.contains(81), isFalse);
  });

  group('the widget', () {
    Widget host(Widget chart) => MaterialApp(
          home: Scaffold(
            body:
                Center(child: SizedBox(width: 240, height: 240, child: chart)),
          ),
        );

    testWidgets('draws over many shapes without a fuss', (tester) async {
      for (final (start, sweep) in [
        (-135.0, 270.0),
        (-90.0, 180.0),
        (0.0, 360.0),
        (0.0, 0.0)
      ]) {
        await tester.pumpWidget(
          host(
            GaugeChart(
              value: 64,
              startAngle: start,
              sweepAngle: sweep,
              ranges: const [
                GaugeRange(from: 0, to: 50, color: Color(0xFF2F9E44)),
                GaugeRange(from: 50, to: 100, color: Color(0xFFE03131)),
              ],
              needle: const GaugeNeedle(),
              label: 'Risk',
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: '$start $sweep');
      }
    });

    testWidgets('announces its value', (tester) async {
      await tester.pumpWidget(
        host(
          GaugeChart(
            value: 42.5,
            label: 'Margin',
            valueFormatter: (v) => '${v.toStringAsFixed(1)}%',
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(GaugeChart)),
        matchesSemantics(label: 'Margin', value: '42.5%'),
      );
    });

    testWidgets('a centre widget replaces the written value', (tester) async {
      await tester.pumpWidget(
        host(const GaugeChart(value: 10, centerChild: Text('custom'))),
      );
      expect(find.text('custom'), findsOneWidget);
    });

    testWidgets('sweeps to a new value and settles on it', (tester) async {
      const duration = Duration(milliseconds: 400);
      await tester.pumpWidget(
        host(const GaugeChart(value: 20, animationDuration: duration)),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        host(const GaugeChart(value: 80, animationDuration: duration)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      GaugeChartPainter painter() => tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byType(GaugeChart),
              matching: find.byType(CustomPaint),
            ),
          )
          .map((p) => p.painter)
          .whereType<GaugeChartPainter>()
          .single;

      final midway = painter().shownValue;
      expect(midway, greaterThan(20));
      expect(midway, lessThan(80));

      await tester.pumpAndSettle();
      expect(painter().shownValue, closeTo(80, 1e-9));
    });
  });
}
