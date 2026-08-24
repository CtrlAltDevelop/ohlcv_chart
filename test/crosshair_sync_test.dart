import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

import 'test_utils.dart';

/// A real chart, driven by [controller], reporting its crosshair to [onMove].
Widget chart(
  List<KLineEntity> data, {
  KChartController? controller,
  ValueChanged<int?>? onMove,
}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: 400,
      height: 500,
      child: KChartWidget(
        data,
        ChartColors(),
        isTrendLine: false,
        watermarkAssetPath: 'assets/none.svg',
        timeFrame: const Duration(minutes: 15),
        showNowPrice: false,
        controller: controller,
        onCrosshairChanged: onMove,
        indicators: [MaIndicator()],
      ),
    ),
  ),
);

void main() {
  group('the crosshair, through the controller', () {
    testWidgets('is null until something puts one up', (tester) async {
      final data = candles(rampThenFall(120));
      DataUtil.calculate(data);
      final controller = KChartController();

      await tester.pumpWidget(chart(data, controller: controller));
      await tester.pumpAndSettle();

      expect(controller.crosshairIndex, isNull);
    });

    testWidgets('reads back the candle a long press landed on', (tester) async {
      final data = candles(rampThenFall(120));
      DataUtil.calculate(data);
      final controller = KChartController();

      await tester.pumpWidget(chart(data, controller: controller));
      await tester.pumpAndSettle();

      final centre = tester.getCenter(find.byType(KChartWidget));
      final press = await tester.startGesture(centre);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(controller.crosshairIndex, isNotNull);

      await press.up();
      await tester.pumpAndSettle();
    });

    testWidgets('can be put up and taken down from outside', (tester) async {
      final data = candles(rampThenFall(120));
      DataUtil.calculate(data);
      final controller = KChartController();

      await tester.pumpWidget(chart(data, controller: controller));
      await tester.pumpAndSettle();

      final visible = controller.visibleRange!;
      final wanted = (visible.firstIndex + visible.lastIndex) ~/ 2;

      controller.showCrosshair(wanted);
      await tester.pumpAndSettle();
      expect(controller.crosshairIndex, wanted);

      controller.hideCrosshair();
      await tester.pumpAndSettle();
      expect(controller.crosshairIndex, isNull);
    });

    testWidgets('a candle off screen rests at the near edge', (tester) async {
      final data = candles(rampThenFall(400));
      DataUtil.calculate(data);
      final controller = KChartController();

      await tester.pumpWidget(chart(data, controller: controller));
      await tester.pumpAndSettle();

      // Candle 0 is well behind the window a fresh chart opens on.
      controller.showCrosshair(0);
      await tester.pumpAndSettle();

      final at = controller.crosshairIndex;
      expect(at, isNotNull);
      expect(
        at,
        greaterThanOrEqualTo(controller.visibleRange!.firstIndex),
        reason: 'clamped into view rather than lost',
      );
    });

    testWidgets('reports where it moved to, and only when it changes', (
      tester,
    ) async {
      final data = candles(rampThenFall(120));
      DataUtil.calculate(data);
      final controller = KChartController();
      final reported = <int?>[];

      await tester.pumpWidget(
        chart(data, controller: controller, onMove: reported.add),
      );
      await tester.pumpAndSettle();
      reported.clear();

      final visible = controller.visibleRange!;
      final wanted = (visible.firstIndex + visible.lastIndex) ~/ 2;

      controller.showCrosshair(wanted);
      await tester.pumpAndSettle();
      expect(reported, [wanted]);

      // Asking for the same candle again says nothing new.
      controller.showCrosshair(wanted);
      await tester.pumpAndSettle();
      expect(reported, [wanted]);

      controller.hideCrosshair();
      await tester.pumpAndSettle();
      expect(reported, [wanted, null]);
    });

    testWidgets('does nothing over a chart with no candles', (tester) async {
      final controller = KChartController();

      await tester.pumpWidget(chart(const [], controller: controller));
      await tester.pumpAndSettle();

      controller.showCrosshair(5);
      await tester.pumpAndSettle();

      expect(controller.crosshairIndex, isNull);
      expect(tester.takeException(), isNull);
    });
  });

  group('two real charts on a link', () {
    testWidgets('one chart\'s crosshair reaches the other', (tester) async {
      final data = candles(rampThenFall(120));
      DataUtil.calculate(data);
      final top = KChartController();
      final bottom = KChartController();
      final link = ChartLink()
        ..add(top)
        ..add(bottom);
      addTearDown(link.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(
                  width: 400,
                  height: 260,
                  child: KChartWidget(
                    data,
                    ChartColors(),
                    isTrendLine: false,
                    watermarkAssetPath: 'assets/none.svg',
                    timeFrame: const Duration(minutes: 15),
                    showNowPrice: false,
                    controller: top,
                  ),
                ),
                SizedBox(
                  width: 400,
                  height: 260,
                  child: KChartWidget(
                    data,
                    ChartColors(),
                    isTrendLine: false,
                    watermarkAssetPath: 'assets/none.svg',
                    timeFrame: const Duration(minutes: 15),
                    showNowPrice: false,
                    controller: bottom,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final visible = top.visibleRange!;
      final wanted = (visible.firstIndex + visible.lastIndex) ~/ 2;

      top.showCrosshair(wanted);
      await tester.pumpAndSettle();

      expect(bottom.crosshairIndex, wanted);

      top.hideCrosshair();
      await tester.pumpAndSettle();
      expect(bottom.crosshairIndex, isNull);
    });
  });
}
