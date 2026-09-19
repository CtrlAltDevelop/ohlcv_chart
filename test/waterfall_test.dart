import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

const _bounds = Rect.fromLTWH(0, 0, 400, 200);

const _steps = [
  WaterfallStep.total(value: 100, label: 'Opening'),
  WaterfallStep(value: 40, label: 'Wins'),
  WaterfallStep(value: -20, label: 'Losses'),
  WaterfallStep.total(label: 'Closing'),
];

void main() {
  group('the running total', () {
    test('deltas add up and totals report what stands', () {
      expect(waterfallTotals(_steps), [100, 140, 120, 120]);
    });

    test('a first delta starts from zero', () {
      expect(
        waterfallTotals(const [
          WaterfallStep(value: 5),
          WaterfallStep(value: -2),
        ]),
        [5, 3],
      );
    });

    test('a value that is not a number moves nothing', () {
      expect(
        waterfallTotals(const [
          WaterfallStep(value: 10),
          WaterfallStep(value: double.nan),
        ]),
        [10, 10],
      );
    });

    test('the range takes in every total and zero', () {
      final range = waterfallRange(const [
        WaterfallStep(value: 50),
        WaterfallStep(value: -80),
      ]);
      expect(range.min, lessThan(-30));
      expect(range.max, greaterThan(50));
      expect(waterfallRange(const []), (min: -1.0, max: 1.0));
    });
  });

  group('the layout', () {
    List<WaterfallBar> layOut() =>
        layOutWaterfall(_steps, _bounds, min: 0, max: 200);

    test('steps take a column each, bars centred in them', () {
      final bars = layOut();
      expect(bars[0].band, const Rect.fromLTWH(0, 0, 100, 200));
      expect(bars[1].rect.center.dx, 150);
      expect(bars[0].rect.width, 60);
    });

    test('a total stands on the baseline', () {
      final bars = layOut();
      expect(bars.first.start, 0);
      expect(bars.first.end, 100);
      expect(bars.first.rect.bottom, 200);
      expect(bars.first.rect.top, 100);
      expect(bars.first.isTotal, isTrue);
    });

    test('a delta picks up where the last step left off', () {
      final bars = layOut();
      expect(bars[1].start, 100);
      expect(bars[1].end, 140);
      expect(bars[1].change, 40);
      expect(bars[1].rect.bottom, 100);
      expect(bars[1].rect.top, 60);
    });

    test('a falling step hangs below where it started', () {
      final bars = layOut();
      expect(bars[2].change, -20);
      expect(bars[2].rect.top, 60);
      expect(bars[2].rect.bottom, 80);
    });

    test('a step that moved nothing still draws a sliver', () {
      final bars = layOutWaterfall(
        const [WaterfallStep(value: 0)],
        _bounds,
        min: -1,
        max: 1,
        minBarHeight: 2,
      );
      expect(bars.single.rect.height, 2);
    });

    test('nothing to show, or no room, lays out nothing', () {
      expect(layOutWaterfall(const [], _bounds, min: 0, max: 1), isEmpty);
      expect(layOutWaterfall(_steps, Rect.zero, min: 0, max: 1), isEmpty);
    });

    test('a point in a column finds its bar', () {
      final bars = layOut();
      expect(waterfallBarAt(bars, const Offset(250, 5))?.index, 2);
      expect(waterfallBarAt(bars, const Offset(250, 900)), isNull);
    });
  });

  group('the widget', () {
    testWidgets('draws, reports touches and takes its default height', (
      tester,
    ) async {
      WaterfallTouchDetails? touched;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                WaterfallChart(
                  steps: _steps,
                  onTouch: (d) => touched = d,
                  tooltipBuilder: (context, d) => Text('card ${d.step.label}'),
                  semanticLabel: 'Account bridge',
                ),
              ],
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(WaterfallChart));
      expect(size.height, 260);

      final topLeft = tester.getTopLeft(find.byType(WaterfallChart));
      final plotLeft = 52.0;
      final gesture = await tester.startGesture(
        topLeft + Offset(plotLeft + (size.width - plotLeft) / 8, 50),
      );
      await tester.pump();
      expect(touched?.step.label, 'Opening');
      expect(touched?.bar.end, 100);
      expect(find.text('card Opening'), findsOneWidget);

      await gesture.up();
      await tester.pump();
      expect(touched, isNull);
    });

    testWidgets('grows in and survives its steps changing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WaterfallChart(
              steps: _steps,
              animationDuration: const Duration(milliseconds: 200),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WaterfallChart(
              steps: const [WaterfallStep(value: -3, label: 'Only')],
              showConnectors: false,
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
