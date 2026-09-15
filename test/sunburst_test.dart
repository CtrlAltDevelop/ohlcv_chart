import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

const _items = [
  TreemapItem.group(
    label: 'Equities',
    children: [
      TreemapItem(value: 30, label: 'AAPL'),
      TreemapItem(value: 20, label: 'MSFT'),
    ],
  ),
  TreemapItem(value: 50, label: 'Bonds'),
];

List<SunburstArc> _layOut({int? maxDepth, double ringGap = 0}) =>
    layOutSunburst(
      _items,
      innerRadius: 0,
      outerRadius: 100,
      startAngle: 0,
      ringGap: ringGap,
      maxDepth: maxDepth,
    );

void main() {
  group('the layout', () {
    test('the first level shares the whole turn by value', () {
      final arcs = _layOut();
      final top = arcs.where((a) => a.depth == 0).toList();
      expect(top.length, 2);
      expect(top[0].sweepAngle, closeTo(math.pi, 1e-9));
      expect(top[1].startAngle, closeTo(math.pi, 1e-9));
    });

    test('children share their parent sweep and sit in the next ring', () {
      final arcs = _layOut();
      final children = arcs.where((a) => a.depth == 1).toList();
      expect(children.map((a) => a.item.label), ['AAPL', 'MSFT']);
      expect(children[0].startAngle, 0);
      expect(children[0].sweepAngle, closeTo(math.pi * 0.6, 1e-9));
      expect(children[0].innerRadius, 50);
      expect(children[0].outerRadius, 100);
    });

    test('rings share the radius, gaps taken out', () {
      final arcs = _layOut(ringGap: 10);
      expect(arcs.first.innerRadius, 0);
      expect(arcs.first.outerRadius, 45);
      expect(arcs.last.innerRadius, isNot(45));
      expect(
        arcs.firstWhere((a) => a.depth == 1).innerRadius,
        55,
      );
    });

    test('maxDepth stops at the ring asked for', () {
      final arcs = _layOut(maxDepth: 1);
      expect(arcs.every((a) => a.depth == 0), isTrue);
      expect(arcs.first.outerRadius, 100);
    });

    test('a group is sized by its children, and reports their total', () {
      final arcs = _layOut();
      expect(arcs.first.total, 50);
    });

    test('an arc knows the top-level arc it belongs to', () {
      final arcs = _layOut();
      final child = arcs.firstWhere((a) => a.item.label == 'MSFT');
      expect(child.root.item.label, 'Equities');
      expect(arcs.first.root, arcs.first);
    });

    test('slivers are dropped, along with what is inside them', () {
      final arcs = layOutSunburst(
        const [
          TreemapItem(value: 1000, label: 'big'),
          TreemapItem.group(
            label: 'tiny',
            children: [TreemapItem(value: 1, label: 'inside')],
          ),
        ],
        innerRadius: 0,
        outerRadius: 100,
        minSweep: 0.05,
      );
      expect(arcs.map((a) => a.item.label), ['big']);
    });

    test('nothing to show, or no room, lays out nothing', () {
      expect(layOutSunburst(const [], innerRadius: 0, outerRadius: 100),
          isEmpty);
      expect(layOutSunburst(_items, innerRadius: 50, outerRadius: 50), isEmpty);
      expect(
        layOutSunburst(
          const [TreemapItem(value: 0)],
          innerRadius: 0,
          outerRadius: 100,
        ),
        isEmpty,
      );
    });
  });

  group('hit testing', () {
    test('a point in a ring finds its arc, the deepest ring winning', () {
      final arcs = _layOut();
      const center = Offset.zero;
      // A quarter turn round, 75px out: inside the second ring.
      final at = Offset(math.cos(0.5) * 75, math.sin(0.5) * 75);
      expect(sunburstArcAt(arcs, center, at)?.item.label, 'AAPL');
      // The same angle, closer in: the group itself.
      final inner = Offset(math.cos(0.5) * 25, math.sin(0.5) * 25);
      expect(sunburstArcAt(arcs, center, inner)?.item.label, 'Equities');
      expect(sunburstArcAt(arcs, center, const Offset(300, 0)), isNull);
    });
  });

  group('the widget', () {
    testWidgets('draws, reports touches and takes its default height',
        (tester) async {
      SunburstTouchDetails? touched;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SunburstChart(
                  items: _items,
                  startAngle: 0,
                  innerRadiusFraction: 0,
                  onTouch: (d) => touched = d,
                  tooltipBuilder: (context, d) => Text('card ${d.item.label}'),
                  center: const Text('100'),
                  semanticLabel: 'Portfolio',
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(SunburstChart)).height, 280);

      final middle = tester.getCenter(find.byType(SunburstChart));
      final gesture = await tester.startGesture(middle + const Offset(0, 100));
      await tester.pump();
      expect(touched?.arc.item.label, 'AAPL');
      expect(find.text('card AAPL'), findsOneWidget);

      await gesture.up();
      await tester.pump();
      expect(touched, isNull);
    });

    testWidgets('sweeps in and survives its data changing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SunburstChart(
              items: _items,
              animationDuration: const Duration(milliseconds: 200),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SunburstChart(
              items: const [TreemapItem(value: 1, label: 'only')],
              animationDuration: const Duration(milliseconds: 200),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
