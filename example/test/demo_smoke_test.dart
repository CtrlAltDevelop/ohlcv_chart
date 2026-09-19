import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart_example/src/chart_page.dart';
import 'package:ohlcv_chart_example/src/demo_state.dart';

void main() {
  testWidgets('the demo builds at both layouts', (tester) async {
    final state = DemoState();
    addTearDown(state.dispose);

    for (final size in [const Size(1280, 900), const Size(420, 900)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ChartPage(state: state)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });

  testWidgets('every chart type and axis renders in the demo', (tester) async {
    final state = DemoState();
    addTearDown(state.dispose);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ChartPage(state: state)),
      ),
    );

    for (final type in ChartType.values) {
      state.update(() => state.chartType = type);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$type');
    }

    for (final aggregation in Aggregation.values) {
      state.update(() => state.aggregation = aggregation);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$aggregation');
    }
  });
}
