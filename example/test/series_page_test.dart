import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart_example/src/demo_state.dart';
import 'package:ohlcv_chart_example/src/series_page.dart';

void main() {
  testWidgets('the series demo builds at both layouts and themes', (
    tester,
  ) async {
    final state = DemoState();
    addTearDown(state.dispose);

    for (final size in [const Size(1280, 900), const Size(420, 900)]) {
      for (final dark in [false, true]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        state.update(() => state.dark = dark);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: SeriesPage(state: state)),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$size dark: $dark');
        expect(find.byType(SeriesChart), findsWidgets);
      }
    }
  });
}
