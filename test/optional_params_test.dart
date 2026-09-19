import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

import 'test_utils.dart';

void main() {
  testWidgets('a chart needs nothing but its candles and colours', (
    tester,
  ) async {
    final data = candles([for (var i = 0; i < 40; i++) 100.0 + i % 7]);
    DataUtil.calculate(data);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: KChartWidget(data, ChartColors()),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final widget = tester.widget<KChartWidget>(find.byType(KChartWidget));
    expect(widget.isTrendLine, isFalse);
    expect(widget.watermark, isNull);
    expect(widget.timeFrame, isNull);
    // With no time frame there is no countdown, so no one-second timer is left
    // running when the test ends — the test framework would fail on one.
  });

  testWidgets('a watermark widget is sized and centred in the candle area', (
    tester,
  ) async {
    final data = candles([for (var i = 0; i < 40; i++) 100.0 + i % 7]);
    DataUtil.calculate(data);
    const mark = Key('watermark');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              height: 300,
              child: KChartWidget(
                data,
                ChartColors(),
                volHidden: true,
                watermark: const SizedBox(key: mark, height: 20),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    final state = tester.state(find.byType(KChartWidget)) as dynamic;
    final Rect main = state.painter.mMainRect;
    final origin = tester.getTopLeft(find.byType(KChartWidget));
    final rect = tester.getRect(find.byKey(mark)).shift(-origin);
    final scale = const ChartStyle().watermarkScale;

    expect(rect.width, closeTo(main.shortestSide * scale, 0.01));
    expect(rect.center.dx, closeTo(main.center.dx, 0.01));
    expect(rect.center.dy, closeTo(main.center.dy, 0.01));
    // It takes no touches: the chart under it still gets them.
    expect(
      find.descendant(
        of: find.byType(IgnorePointer),
        matching: find.byKey(mark),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a time frame still counts the current candle down', (
    tester,
  ) async {
    final data = candles([for (var i = 0; i < 40; i++) 100.0 + i % 7]);
    DataUtil.calculate(data);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: KChartWidget(
              data,
              ChartColors(),
              timeFrame: const Duration(minutes: 1),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    // Dispose the chart so its countdown timer is cancelled.
    await tester.pumpWidget(const SizedBox());
  });
}
