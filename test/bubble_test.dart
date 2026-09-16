import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

const _bounds = Rect.fromLTWH(0, 0, 200, 100);

const _points = [
  BubblePoint(x: 0, y: 0, size: 100, label: 'A'),
  BubblePoint(x: 10, y: 20, size: 25, label: 'B'),
];

List<BubbleCircle> _layOut({double minRadius = 0, double maxRadius = 40}) =>
    layOutBubbles(
      _points,
      _bounds,
      minX: 0,
      maxX: 10,
      minY: 0,
      maxY: 20,
      minRadius: minRadius,
      maxRadius: maxRadius,
    );

void main() {
  group('the layout', () {
    test('points are placed against the ranges, y running up', () {
      final circles = _layOut();
      expect(circles[0].center, const Offset(0, 100));
      expect(circles[1].center, const Offset(200, 0));
    });

    test('a bubble\'s area, not its radius, carries its size', () {
      final circles = _layOut();
      // A quarter of the size is half the radius.
      expect(circles[0].radius, 40);
      expect(circles[1].radius, 20);
    });

    test('radii stay between the two limits', () {
      final circles = _layOut(minRadius: 10, maxRadius: 20);
      expect(circles[0].radius, 20);
      expect(circles[1].radius, 15);
      final zero = layOutBubbles(
        const [BubblePoint(x: 0, y: 0, size: 0)],
        _bounds,
        minX: 0,
        maxX: 1,
        minY: 0,
        maxY: 1,
        minRadius: 3,
      );
      expect(zero.single.radius, 3);
    });

    test('maxSize fixes what the largest radius is worth', () {
      final circles = layOutBubbles(
        _points,
        _bounds,
        minX: 0,
        maxX: 10,
        minY: 0,
        maxY: 20,
        minRadius: 0,
        maxRadius: 40,
        maxSize: 400,
      );
      expect(circles[0].radius, 20);
    });

    test('a flat range puts everything down the middle', () {
      final circles = layOutBubbles(
        _points,
        _bounds,
        minX: 5,
        maxX: 5,
        minY: 0,
        maxY: 20,
      );
      expect(circles.every((c) => c.center.dx == 100), isTrue);
    });

    test('the range covers every point with room for the bubbles', () {
      final range = bubbleRange(_points);
      expect(range.minX, -1);
      expect(range.maxX, 11);
      expect(range.minY, -2);
      expect(range.maxY, 22);
      expect(
        bubbleRange(const [BubblePoint(x: 3, y: 3)]),
        (minX: 2.0, maxX: 4.0, minY: 2.0, maxY: 4.0),
      );
      expect(
          bubbleRange(const []), (minX: 0.0, maxX: 1.0, minY: 0.0, maxY: 1.0));
    });

    test('nothing to show, or no room, lays out nothing', () {
      expect(
        layOutBubbles(const [], _bounds, minX: 0, maxX: 1, minY: 0, maxY: 1),
        isEmpty,
      );
      expect(
        layOutBubbles(_points, Rect.zero, minX: 0, maxX: 1, minY: 0, maxY: 1),
        isEmpty,
      );
    });

    test('the smallest bubble under the pointer wins', () {
      final circles = layOutBubbles(
        const [
          BubblePoint(x: 5, y: 10, size: 100),
          BubblePoint(x: 5, y: 10, size: 1),
        ],
        _bounds,
        minX: 0,
        maxX: 10,
        minY: 0,
        maxY: 20,
      );
      expect(bubbleAt(circles, const Offset(100, 50))?.index, 1);
      expect(bubbleAt(circles, const Offset(0, 0)), isNull);
    });
  });

  group('the widget', () {
    testWidgets('draws, reports touches and takes its default height',
        (tester) async {
      BubbleTouchDetails? touched;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                BubbleChart(
                  points: const [
                    BubblePoint(x: 5, y: 5, size: 10, label: 'Mid'),
                  ],
                  xAxisTitle: 'Volatility',
                  yAxisTitle: 'Return',
                  xReferenceLines: const [5],
                  yReferenceLines: const [5],
                  onTouch: (d) => touched = d,
                  tooltipBuilder: (context, d) => Text('card ${d.point.label}'),
                  semanticLabel: 'Risk and return',
                ),
              ],
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(BubbleChart));
      expect(size.height, 260);

      // The only point sits in the middle of the plot area.
      final topLeft = tester.getTopLeft(find.byType(BubbleChart));
      final plotCenter = topLeft +
          Offset(44 + (size.width - 44) / 2, (size.height - 18 - 14) / 2);
      final gesture = await tester.startGesture(plotCenter);
      await tester.pump();
      expect(touched?.point.label, 'Mid');
      expect(find.text('card Mid'), findsOneWidget);

      await gesture.up();
      await tester.pump();
      expect(touched, isNull);
    });

    testWidgets('grows in and survives its data changing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BubbleChart(
              points: _points,
              animationDuration: const Duration(milliseconds: 200),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BubbleChart(
              points: const [BubblePoint(x: 1, y: 1)],
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
