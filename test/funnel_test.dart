import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

const _bounds = Rect.fromLTWH(0, 0, 400, 300);

const _stages = [
  FunnelStage(value: 1000, label: 'Visited'),
  FunnelStage(value: 500, label: 'Signed up'),
  FunnelStage(value: 250, label: 'Verified'),
];

void main() {
  group('the layout', () {
    test('each stage is as wide as its share of the largest', () {
      final segments = layOutFunnel(_stages, _bounds, minWidthFraction: 0);
      expect(segments.map((s) => s.topWidth), [400, 200, 100]);
    });

    test('a tapered stage narrows to the next, and the last keeps its own', () {
      final segments = layOutFunnel(_stages, _bounds, minWidthFraction: 0);
      expect(segments[0].bottomWidth, segments[1].topWidth);
      expect(segments[1].bottomWidth, segments[2].topWidth);
      expect(segments[2].bottomWidth, segments[2].topWidth);
    });

    test('a stepped stage is a bar of its own width', () {
      final segments = layOutFunnel(
        _stages,
        _bounds,
        minWidthFraction: 0,
        shape: FunnelShape.stepped,
      );
      for (final s in segments) {
        expect(s.bottomWidth, s.topWidth);
      }
    });

    test('stages share the height, gaps taken out', () {
      final segments = layOutFunnel(_stages, _bounds, gap: 15);
      expect(segments[0].rect, const Rect.fromLTWH(0, 0, 400, 90));
      expect(segments[1].rect.top, 105);
      expect(segments[2].rect.bottom, 300);
    });

    test('a stage that lost almost everyone is still visible', () {
      final segments = layOutFunnel(
        const [FunnelStage(value: 1000), FunnelStage(value: 1)],
        _bounds,
        minWidthFraction: 0.1,
      );
      expect(segments[1].topWidth, 40);
    });

    test('conversions are read against the first and the previous stage', () {
      final segments = layOutFunnel(_stages, _bounds);
      expect(segments[0].ofFirst, 1);
      expect(segments[0].ofPrevious, 1);
      expect(segments[2].ofFirst, 0.25);
      expect(segments[2].ofPrevious, 0.5);
    });

    test('nothing to show, or no room, lays out nothing', () {
      expect(layOutFunnel(const [], _bounds), isEmpty);
      expect(layOutFunnel(_stages, Rect.zero), isEmpty);
      final zeros = layOutFunnel(const [
        FunnelStage(value: 0),
        FunnelStage(value: double.nan),
      ], _bounds);
      expect(zeros.map((s) => s.ofFirst), [0, 0]);
      expect(zeros.map((s) => s.ofPrevious), [1, 0]);
    });

    test('a point is inside the trapezoid, not merely its band', () {
      final segments = layOutFunnel(_stages, _bounds, minWidthFraction: 0);
      final top = segments.first;
      // At the top edge it is 400 wide, at the bottom 200.
      expect(top.contains(Offset(10, top.rect.top + 1)), isTrue);
      expect(top.contains(Offset(10, top.rect.bottom - 1)), isFalse);
      expect(top.contains(Offset(200, top.rect.bottom - 1)), isTrue);
      expect(funnelSegmentAt(segments, const Offset(200, 150))?.index, 1);
      expect(funnelSegmentAt(segments, const Offset(5, 250)), isNull);
    });
  });

  group('the widget', () {
    Widget host(Widget chart) => MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 400, height: 300, child: chart)),
      ),
    );

    testWidgets('draws both shapes, and nothing, without a fuss', (
      tester,
    ) async {
      for (final shape in FunnelShape.values) {
        for (final stages in [const <FunnelStage>[], _stages]) {
          await tester.pumpWidget(
            host(FunnelChart(stages: stages, shape: shape)),
          );
          expect(tester.takeException(), isNull);
        }
      }
    });

    testWidgets('a touch reports the stage and shows its card', (tester) async {
      FunnelTouchDetails? reported;
      await tester.pumpWidget(
        host(
          FunnelChart(
            stages: _stages,
            onTouch: (d) => reported = d,
            tooltipBuilder: (context, d) => Text('card ${d.stage.label}'),
          ),
        ),
      );

      final origin = tester.getTopLeft(find.byType(FunnelChart));
      final gesture = await tester.startGesture(
        origin + const Offset(200, 150),
      );
      await tester.pump();
      expect(reported?.stage.label, 'Signed up');
      expect(find.text('card Signed up'), findsOneWidget);

      await gesture.up();
      await tester.pump();
      expect(reported, isNull);
    });

    testWidgets('widens in when asked, and settles', (tester) async {
      await tester.pumpWidget(
        host(
          const FunnelChart(
            stages: _stages,
            animationDuration: Duration(milliseconds: 300),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
