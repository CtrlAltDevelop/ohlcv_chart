import 'dart:ui' show PointerDeviceKind;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

const _models = [
  ModelPoint(name: 'Large', cost: 15, score: 88, size: 200000, group: 'A'),
  ModelPoint(name: 'Mid', cost: 3, score: 82, size: 128000, group: 'A'),
  ModelPoint(name: 'Small', cost: 0.25, score: 71, size: 128000, group: 'A'),
  ModelPoint(name: 'Open 70B', cost: 0.9, score: 79, group: 'B'),
  ModelPoint(name: 'Dated', cost: 10, score: 70, group: 'B'),
];

void main() {
  group('the frontier', () {
    test('keeps the models nothing beats, by rising cost', () {
      // Small (0.25, 71), Open (0.9, 79), Mid (3, 82), Large (15, 88); Dated is
      // dearer and worse than Mid.
      expect(paretoIndices(_models), [2, 3, 1, 0]);
    });

    test('a model that costs more for the same score is off it', () {
      final frontier = paretoIndices(const [
        ModelPoint(name: 'a', cost: 1, score: 80),
        ModelPoint(name: 'b', cost: 2, score: 80),
      ]);

      expect(frontier, [0]);
    });

    test('at the same cost only the better one counts', () {
      final frontier = paretoIndices(const [
        ModelPoint(name: 'a', cost: 1, score: 70),
        ModelPoint(name: 'b', cost: 1, score: 90),
      ]);

      expect(frontier, [1]);
    });

    test('skips what is not a number', () {
      final frontier = paretoIndices(const [
        ModelPoint(name: 'a', cost: double.nan, score: 90),
        ModelPoint(name: 'b', cost: 1, score: double.infinity),
        ModelPoint(name: 'c', cost: 1, score: 50),
      ]);

      expect(frontier, [2]);
      expect(paretoIndices(const []), isEmpty);
    });
  });

  group('the widget', () {
    Widget host(Widget chart) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 500, height: 320, child: chart)),
    );

    testWidgets('says what beats a model that is off the frontier', (
      tester,
    ) async {
      ModelTouchDetails? touched;
      await tester.pumpWidget(
        host(
          ModelParetoChart(
            models: _models,
            labelAll: true,
            onTouch: (d) => touched = d,
          ),
        ),
      );

      // Sweep the plot until the pointer meets the dated model.
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      final origin = tester.getTopLeft(find.byType(ModelParetoChart));
      outer:
      for (var y = 5.0; y < 270; y += 6) {
        for (var x = 50.0; x < 490; x += 6) {
          await gesture.moveTo(origin + Offset(x, y));
          if (touched?.model.name == 'Dated') break outer;
        }
      }

      expect(touched, isNotNull);
      expect(touched!.model.name, 'Dated');
      expect(touched!.onFrontier, isFalse);
      expect(touched!.beatenBy?.name, 'Mid');
    });

    testWidgets('draws linear, with no sizes and no groups', (tester) async {
      await tester.pumpWidget(
        host(
          const ModelParetoChart(
            logCost: false,
            models: [
              ModelPoint(name: 'a', cost: 1, score: 50),
              ModelPoint(name: 'b', cost: 2, score: 60),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a model costing nothing is left off a log axis', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const ModelParetoChart(
            models: [
              ModelPoint(name: 'free', cost: 0, score: 60),
              ModelPoint(name: 'paid', cost: 1, score: 70),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('survives no models and a single one', (tester) async {
      await tester.pumpWidget(host(const ModelParetoChart(models: [])));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        host(
          const ModelParetoChart(
            models: [ModelPoint(name: 'only', cost: 2, score: 5)],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
