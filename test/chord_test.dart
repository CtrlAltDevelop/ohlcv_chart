import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

const _nodes = [
  ChordNode(label: 'Binance'),
  ChordNode(label: 'OKX'),
  ChordNode(label: 'Bybit'),
];

const _flows = [
  ChordFlow(from: 'Binance', to: 'OKX', value: 40),
  ChordFlow(from: 'OKX', to: 'Bybit', value: 25),
  ChordFlow(from: 'Bybit', to: 'Binance', value: 30),
];

void main() {
  group('the totals', () {
    test('count what leaves and what arrives at each node', () {
      final totals = ChordTotals.of(
        [for (final node in _nodes) node.label],
        _flows,
      );
      expect(totals.out, [40, 25, 30]);
      expect(totals.into, [30, 40, 25]);
      expect(totals.totalAt(0), 70);
    });

    test('the grand total counts every flow at both its ends', () {
      final totals = ChordTotals.of(
        [for (final node in _nodes) node.label],
        _flows,
      );
      expect(totals.grandTotal, (40 + 25 + 30) * 2);
    });

    test('a flow naming a node that is not there is dropped', () {
      final totals = ChordTotals.of(
        const ['a'],
        const [ChordFlow(from: 'a', to: 'ghost', value: 5)],
      );
      expect(totals.out, [0]);
    });

    test('negatives and nonsense count as nothing', () {
      final totals = ChordTotals.of(
        const ['a', 'b'],
        const [
          ChordFlow(from: 'a', to: 'b', value: -5),
          ChordFlow(from: 'a', to: 'b', value: double.nan),
        ],
      );
      expect(totals.grandTotal, 0);
    });
  });

  group('the layout', () {
    test('arcs are as long as the flow through their node', () {
      final layout =
          layOutChord(_nodes, _flows, size: const Size(300, 300), padAngle: 0);
      final sweeps = [for (final arc in layout.arcs) arc.sweepAngle];
      expect(sweeps.reduce((a, b) => a + b), closeTo(2 * math.pi, 1e-9));
      // Binance carries 70 of 190.
      expect(sweeps[0], closeTo(2 * math.pi * 70 / 190, 1e-9));
    });

    test('the pads come out before the arcs share the turn', () {
      final layout = layOutChord(
        _nodes,
        _flows,
        size: const Size(300, 300),
        padAngle: 0.1,
      );
      final sweeps = [for (final arc in layout.arcs) arc.sweepAngle];
      expect(
        sweeps.reduce((a, b) => a + b),
        closeTo(2 * math.pi - 0.3, 1e-9),
      );
      // Still in true proportion to each other.
      expect(sweeps[0] / sweeps[1], closeTo(70 / 65, 1e-9));
    });

    test('the arcs run on from each other, starting where asked', () {
      final layout = layOutChord(
        _nodes,
        _flows,
        size: const Size(300, 300),
        padAngle: 0,
        startAngle: 0,
      );
      expect(layout.arcs.first.startAngle, 0);
      for (var i = 1; i < layout.arcs.length; i++) {
        expect(
          layout.arcs[i].startAngle,
          closeTo(
            layout.arcs[i - 1].startAngle + layout.arcs[i - 1].sweepAngle,
            1e-9,
          ),
        );
      }
    });

    test('a ribbon is drawn for every flow', () {
      final layout = layOutChord(_nodes, _flows, size: const Size(300, 300));
      expect(layout.ribbons, hasLength(3));
      expect(layout.ribbons.first.fromIndex, 0);
      expect(layout.ribbons.first.toIndex, 1);
    });

    test('a cycle is drawn, not broken', () {
      // Every node both sends and receives; a Sankey would have to cut one.
      final layout = layOutChord(_nodes, _flows, size: const Size(300, 300));
      expect(layout.ribbons.map((r) => r.toIndex).toSet(), {0, 1, 2});
    });

    test('labels take their room out of the radius', () {
      final wide = layOutChord(_nodes, _flows, size: const Size(300, 300));
      final tight = layOutChord(
        _nodes,
        _flows,
        size: const Size(300, 300),
        labelWidth: 40,
      );
      expect(tight.radius, closeTo(wide.radius - 40, 1e-9));
    });

    test('progress sweeps the ring open', () {
      final half = layOutChord(
        _nodes,
        _flows,
        size: const Size(300, 300),
        padAngle: 0,
        progress: 0.5,
      );
      final sweeps = [for (final arc in half.arcs) arc.sweepAngle];
      expect(sweeps.reduce((a, b) => a + b), closeTo(math.pi, 1e-9));
    });

    test('nothing to show lays out nothing', () {
      expect(layOutChord(const [], _flows, size: const Size(300, 300)).isEmpty,
          true);
      expect(layOutChord(_nodes, _flows, size: Size.zero).isEmpty, true);
      expect(
        layOutChord(_nodes, const [], size: const Size(300, 300)).isEmpty,
        true,
      );
    });

    test('a point finds the arc on the ring and the ribbon inside it', () {
      final layout = layOutChord(
        _nodes,
        _flows,
        size: const Size(300, 300),
        padAngle: 0,
        startAngle: 0,
        labelWidth: 0,
      );
      final arc = layout.arcs.first;
      final onRing = layout.center +
          Offset(math.cos(arc.midAngle), math.sin(arc.midAngle)) *
              (layout.radius - layout.ringThickness / 2);
      expect(layout.arcAt(onRing)?.index, 0);
      // The middle of the ring is inside no arc but under the ribbons.
      expect(layout.arcAt(layout.center), isNull);
      expect(layout.ribbonAt(layout.center), isNotNull);
      expect(layout.arcAt(const Offset(0, 0)), isNull);
    });
  });

  group('the widget', () {
    testWidgets('draws and reports what is under the finger', (tester) async {
      ChordNode? node;
      ChordFlow? flow;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: ChordChart(
                nodes: _nodes,
                flows: _flows,
                onNodeTap: (touched) => node = touched ?? node,
                onFlowTap: (touched) => flow = touched ?? flow,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(ChordChart), findsOneWidget);

      final box = tester.getRect(find.byType(ChordChart));
      final gesture = await tester.startGesture(box.center);
      await tester.pump();
      expect(flow, isNotNull);
      expect(node, isNull);
      await gesture.up();
      await tester.pump();
    });

    testWidgets('takes its default size in an unbounded box', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChordChart(
                nodes: _nodes,
                flows: _flows,
                defaultSize: 200,
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(ChordChart)).height, 200);
    });

    testWidgets('sweeps the ring open over time', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: ChordChart(
                nodes: _nodes,
                flows: _flows,
                animationDuration: Duration(milliseconds: 200),
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
