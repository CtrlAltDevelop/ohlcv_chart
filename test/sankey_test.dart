import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

const _bounds = Rect.fromLTWH(0, 0, 400, 300);

const _nodes = [
  SankeyNode(id: 'salary', label: 'Salary'),
  SankeyNode(id: 'budget', label: 'Budget'),
  SankeyNode(id: 'rent', label: 'Rent'),
  SankeyNode(id: 'saved', label: 'Saved'),
];

const _links = [
  SankeyLink(source: 'salary', target: 'budget', value: 100),
  SankeyLink(source: 'budget', target: 'rent', value: 40),
  SankeyLink(source: 'budget', target: 'saved', value: 60),
];

void main() {
  group('the layout', () {
    test('a node stands one column right of what feeds it', () {
      final layout = layOutSankey(_nodes, _links, _bounds);
      expect(layout.nodes.map((n) => n.depth), [0, 1, 2, 2]);
    });

    test('columns are spread across the width, bars nodeWidth wide', () {
      final layout = layOutSankey(_nodes, _links, _bounds, nodeWidth: 10);
      expect(layout.nodes[0].rect.left, 0);
      expect(layout.nodes[1].rect.left, 195);
      expect(layout.nodes[2].rect.left, 390);
      expect(layout.nodes[0].rect.width, 10);
    });

    test('a bar is as tall as what passes through it', () {
      final layout = layOutSankey(_nodes, _links, _bounds, nodePadding: 20);
      // The tallest column holds two bars and one gap: 280px for 100 units.
      expect(layout.nodes[0].rect.height, closeTo(280, 0.001));
      expect(layout.nodes[2].rect.height, closeTo(112, 0.001));
      expect(layout.nodes[3].rect.height, closeTo(168, 0.001));
    });

    test('a node reports what arrives and what leaves', () {
      final layout = layOutSankey(_nodes, _links, _bounds);
      expect(layout.nodes[1].incoming, 100);
      expect(layout.nodes[1].outgoing, 100);
      expect(layout.nodes[0].incoming, 0);
      expect(layout.nodes[2].outgoing, 0);
    });

    test('ribbons stack against their bars in the order given', () {
      final layout = layOutSankey(_nodes, _links, _bounds, nodePadding: 20);
      final out = layout.links.where((l) => l.source.index == 1).toList();
      expect(out.first.sourceTop, layout.nodes[1].rect.top);
      expect(
        out.last.sourceTop,
        closeTo(layout.nodes[1].rect.top + out.first.thickness, 0.001),
      );
      // Each ribbon meets its target at the top of that bar.
      for (final ribbon in out) {
        expect(ribbon.targetTop, ribbon.target.rect.top);
      }
    });

    test('a link into a full column is dropped when it points backwards', () {
      final layout = layOutSankey(
        _nodes,
        const [
          ..._links,
          SankeyLink(source: 'saved', target: 'salary', value: 10),
        ],
        _bounds,
      );
      expect(layout.links.length, 3);
    });

    test('links naming an unknown node, itself or nothing are dropped', () {
      final layout = layOutSankey(
        _nodes,
        const [
          SankeyLink(source: 'salary', target: 'nowhere', value: 10),
          SankeyLink(source: 'salary', target: 'salary', value: 10),
          SankeyLink(source: 'salary', target: 'budget', value: 0),
          SankeyLink(source: 'salary', target: 'budget', value: double.nan),
        ],
        _bounds,
      );
      expect(layout.links, isEmpty);
      expect(layout.nodes.every((n) => n.rect.height == 0), isTrue);
    });

    test('nothing to show, or no room, lays out nothing', () {
      expect(layOutSankey(const [], _links, _bounds).isEmpty, isTrue);
      expect(layOutSankey(_nodes, _links, Rect.zero).isEmpty, isTrue);
    });
  });

  group('hit testing', () {
    test('a point inside a bar finds its node', () {
      final layout = layOutSankey(_nodes, _links, _bounds);
      expect(
          sankeyNodeAt(layout, layout.nodes[1].rect.center)?.node.id, 'budget');
      expect(sankeyNodeAt(layout, const Offset(100, 5)), isNull);
    });

    test('a point inside a ribbon finds its link', () {
      final layout = layOutSankey(_nodes, _links, _bounds);
      final ribbon = layout.links.first;
      expect(
        sankeyLinkAt(layout, ribbon.path.getBounds().center)?.link.target,
        'budget',
      );
    });
  });

  group('the widget', () {
    testWidgets('draws, reports touches and takes its default height',
        (tester) async {
      SankeyTouchDetails? touched;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SankeyChart(
                  nodes: _nodes,
                  links: _links,
                  onTouch: (d) => touched = d,
                  tooltipBuilder: (context, details) =>
                      const Text('card', textDirection: TextDirection.ltr),
                  semanticLabel: 'Cash flow',
                ),
              ],
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(SankeyChart));
      expect(size.height, 280);

      final topLeft = tester.getTopLeft(find.byType(SankeyChart));
      final gesture =
          await tester.startGesture(topLeft + Offset(7, size.height / 2));
      await tester.pump();
      expect(touched?.node?.node.id, 'salary');
      expect(find.text('card'), findsOneWidget);

      await gesture.up();
      await tester.pump();
      expect(touched, isNull);
    });

    testWidgets('animates in and survives its data changing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SankeyChart(
              nodes: _nodes,
              links: _links,
              animationDuration: const Duration(milliseconds: 200),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SankeyChart(
              nodes: const [
                SankeyNode(id: 'a'),
                SankeyNode(id: 'b'),
              ],
              links: const [SankeyLink(source: 'a', target: 'b', value: 5)],
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
