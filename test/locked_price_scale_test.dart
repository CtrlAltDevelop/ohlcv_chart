import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart/src/renderer/chart_painter.dart';

import 'test_utils.dart';

ChartPainter _painterOf(WidgetTester tester) {
  final dynamic state = tester.state(find.byType(KChartWidget));
  // ignore: avoid_dynamic_calls
  return state.painter as ChartPainter;
}

/// A steady climb, so every window holds a visibly different price range.
List<KLineEntity> _trend([int count = 300]) {
  final data = candles([for (var i = 0; i < count; i++) 100.0 + i * 2]);
  DataUtil.calculate(data);
  return data;
}

Widget _chart({
  required bool lock,
  List<KLineEntity>? data,
  KChartController? controller,
}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: 500,
      height: 600,
      child: KChartWidget(
        data ?? _trend(),
        ChartColors(),
        isTrendLine: false,
        watermarkAssetPath: 'assets/none.svg',
        timeFrame: const Duration(minutes: 15),
        showNowPrice: false,
        lockPriceScale: lock,
        controller: controller,
      ),
    ),
  ),
);

/// The range the price axis is actually drawn at, which is the renderer's --
/// the painter's own min and max stay the honest fit to the window.
({double min, double max}) _range(WidgetTester tester) {
  final r = _painterOf(tester).mMainRenderer;
  return (min: r.minValue, max: r.maxValue);
}

/// The fit to the candles in the window, locked or not.
({double min, double max}) _windowFit(WidgetTester tester) {
  final p = _painterOf(tester);
  return (min: p.mMainMinValue, max: p.mMainMaxValue);
}

void main() {
  group('an unlocked price axis', () {
    testWidgets('refits to the window as the chart scrolls', (tester) async {
      await tester.pumpWidget(_chart(lock: false));
      final before = _range(tester);

      await tester.drag(find.byType(KChartWidget), const Offset(600, 0));
      await tester.pumpAndSettle();

      // The long-standing behaviour, kept: this is what the lock is for.
      expect(_range(tester).min, isNot(before.min));
    });
  });

  group('a locked price axis', () {
    testWidgets('holds its range while the chart scrolls', (tester) async {
      await tester.pumpWidget(_chart(lock: true));
      // One more frame, so the axis has a fitted range to lock onto.
      await tester.pump();
      final locked = _range(tester);

      await tester.drag(find.byType(KChartWidget), const Offset(600, 0));
      await tester.pumpAndSettle();

      expect(_range(tester).min, locked.min);
      expect(_range(tester).max, locked.max);
    });

    testWidgets('holds it across several scrolls in both directions', (
      tester,
    ) async {
      await tester.pumpWidget(_chart(lock: true));
      await tester.pump();
      final locked = _range(tester);

      for (final dx in const [400.0, -200.0, 900.0, -600.0]) {
        await tester.drag(find.byType(KChartWidget), Offset(dx, 0));
        await tester.pumpAndSettle();
        expect(_range(tester).min, locked.min, reason: 'after dx=$dx');
        expect(_range(tester).max, locked.max, reason: 'after dx=$dx');
      }
    });

    testWidgets('locks onto what the user was already looking at', (
      tester,
    ) async {
      // Fitted first, then locked: the range must not jump on the way.
      await tester.pumpWidget(_chart(lock: false));
      final fitted = _range(tester);

      await tester.pumpWidget(_chart(lock: true));
      await tester.pump();

      expect(_range(tester).min, fitted.min);
      expect(_range(tester).max, fitted.max);
    });

    testWidgets('holds still while candles are paged in behind it', (
      tester,
    ) async {
      final recent = _trend();
      await tester.pumpWidget(_chart(lock: true, data: recent));
      await tester.pump();
      final locked = _range(tester);

      // What onLoadMore(false) leads to: older candles, at quite other prices.
      final longer = [
        for (var i = 0; i < 80; i++) candle(-500.0 + i, minute: -80 + i),
        ...recent,
      ];
      DataUtil.calculate(longer);
      await tester.pumpWidget(_chart(lock: true, data: longer));
      await tester.pumpAndSettle();

      expect(_range(tester).min, locked.min);
      expect(_range(tester).max, locked.max);
    });

    testWidgets('still marks the window own high and low', (tester) async {
      await tester.pumpWidget(_chart(lock: true));
      await tester.pump();
      await tester.drag(find.byType(KChartWidget), const Offset(600, 0));
      await tester.pumpAndSettle();

      final painter = _painterOf(tester);
      final data = _trend();
      // The markers read the candles in view, not the locked scale, so they
      // still point at the candles that actually set them.
      expect(painter.mMainHighMaxValue, data[painter.mMainMaxIndex].high);
      expect(painter.mMainLowMinValue, data[painter.mMainMinIndex].low);

      // And the window fit has moved on even though the drawn axis has not:
      // the two are genuinely separate.
      expect(_windowFit(tester).min, isNot(_range(tester).min));
    });

    testWidgets('is handed back to the chart by resetPriceScale', (
      tester,
    ) async {
      final controller = KChartController();
      await tester.pumpWidget(_chart(lock: true, controller: controller));
      await tester.pump();
      final locked = _range(tester);

      await tester.drag(find.byType(KChartWidget), const Offset(600, 0));
      await tester.pumpAndSettle();
      expect(_range(tester).min, locked.min, reason: 'held while scrolled');

      controller.resetPriceScale();
      await tester.pumpAndSettle();

      // Refitted to the window it is now over, then locked there afresh.
      expect(_range(tester).min, isNot(locked.min));
      final refitted = _range(tester);
      await tester.drag(find.byType(KChartWidget), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(_range(tester).min, refitted.min, reason: 'locked again');
    });

    testWidgets('goes back to fitting when the lock is taken off', (
      tester,
    ) async {
      await tester.pumpWidget(_chart(lock: true));
      await tester.pump();
      final locked = _range(tester);

      await tester.pumpWidget(_chart(lock: false));
      await tester.drag(find.byType(KChartWidget), const Offset(600, 0));
      await tester.pumpAndSettle();

      expect(_range(tester).min, isNot(locked.min));
    });

    testWidgets('can still be zoomed, from the range it is held at', (
      tester,
    ) async {
      final controller = KChartController();
      await tester.pumpWidget(_chart(lock: true, controller: controller));
      await tester.pump();
      final locked = _range(tester);
      final span = locked.max - locked.min;

      controller.setPriceZoom(2.0);
      await tester.pumpAndSettle();

      final zoomed = _range(tester);
      expect(
        zoomed.max - zoomed.min,
        closeTo(span / 2, span * 0.02),
        reason: 'zoom works off the locked range, not the window',
      );
    });
  });
}
