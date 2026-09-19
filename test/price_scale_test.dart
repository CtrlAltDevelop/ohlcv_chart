import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart/src/renderer/chart_painter.dart';

import 'test_utils.dart';

Widget _chart({
  KChartController? controller,
  bool priceScaleDrag = true,
  VerticalTextAlignment alignment = VerticalTextAlignment.right,
  PriceAxisScale scale = PriceAxisScale.linear,
}) {
  final data = candles(rampThenFall(60));
  DataUtil.calculate(data);

  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 500,
        height: 600,
        child: KChartWidget(
          data,
          ChartColors(),
          isTrendLine: false,
          timeFrame: const Duration(minutes: 15),
          controller: controller,
          priceScaleDrag: priceScaleDrag,
          verticalTextAlignment: alignment,
          priceAxisScale: scale,
        ),
      ),
    ),
  );
}

ChartPainter _painterOf(WidgetTester tester) {
  final dynamic state = tester.state(find.byType(KChartWidget));
  // ignore: avoid_dynamic_calls
  return state.painter as ChartPainter;
}

/// The price range the candle area is currently drawing.
({double top, double bottom}) _rangeOf(WidgetTester tester) {
  final painter = _painterOf(tester);
  final renderer = painter.mMainRenderer;
  return (top: renderer.maxValue, bottom: renderer.minValue);
}

/// The middle of the price scale's grip strip.
Offset _gripCentre(WidgetTester tester) {
  final rect = _painterOf(tester).mMainRect;
  final chart = tester.getTopLeft(find.byType(KChartWidget));
  return chart + Offset(rect.right - 26, rect.center.dy);
}

void main() {
  group('dragging the price scale', () {
    testWidgets('up compresses the range, down stretches it', (tester) async {
      await tester.pumpWidget(_chart());
      final fitted = _rangeOf(tester);

      await tester.dragFrom(_gripCentre(tester), const Offset(0, -60));
      await tester.pump();
      final compressed = _rangeOf(tester);

      final fittedSpan = fitted.top - fitted.bottom;
      final compressedSpan = compressed.top - compressed.bottom;
      expect(compressedSpan, greaterThan(fittedSpan));

      await tester.dragFrom(_gripCentre(tester), const Offset(0, 120));
      await tester.pump();
      final stretched = _rangeOf(tester);

      expect(stretched.top - stretched.bottom, lessThan(compressedSpan));
    });

    testWidgets('holds the middle of the range still', (tester) async {
      await tester.pumpWidget(_chart());
      final fitted = _rangeOf(tester);

      await tester.dragFrom(_gripCentre(tester), const Offset(0, -80));
      await tester.pump();
      final scaled = _rangeOf(tester);

      expect(
        (scaled.top + scaled.bottom) / 2,
        closeTo((fitted.top + fitted.bottom) / 2, 1e-6),
      );
    });

    testWidgets('a double-tap fits it back to the window', (tester) async {
      final controller = KChartController();
      await tester.pumpWidget(_chart(controller: controller));
      final fitted = _rangeOf(tester);

      controller.setPriceZoom(2.5);
      await tester.pump();
      expect(_rangeOf(tester).top, lessThan(fitted.top));

      final grip = _gripCentre(tester);
      await tester.tapAt(grip);
      await tester.pump(kDoubleTapMinTime);
      await tester.tapAt(grip);
      await tester.pumpAndSettle();

      expect(_rangeOf(tester).top, closeTo(fitted.top, 1e-6));
      expect(_rangeOf(tester).bottom, closeTo(fitted.bottom, 1e-6));
    });

    testWidgets('a stretched log axis is still a log axis', (tester) async {
      await tester.pumpWidget(_chart(scale: PriceAxisScale.logarithmic));
      final controller = _painterOf(tester);
      final fitted = controller.mMainRenderer;
      final ratio = fitted.maxValue / fitted.minValue;

      await tester.dragFrom(_gripCentre(tester), const Offset(0, -60));
      await tester.pump();

      final scaled = _painterOf(tester).mMainRenderer;
      // Stretched by ratio, not by price: the window opens out on both sides
      // by the same factor, so the geometric middle stays put.
      expect(scaled.maxValue / scaled.minValue, greaterThan(ratio));
      expect(
        scaled.maxValue * scaled.minValue,
        closeTo(fitted.maxValue * fitted.minValue, 1e-3),
      );
    });

    testWidgets('off, the axis keeps fitting the window', (tester) async {
      await tester.pumpWidget(_chart(priceScaleDrag: false));
      final fitted = _rangeOf(tester);

      await tester.dragFrom(_gripCentre(tester), const Offset(0, -80));
      await tester.pump();

      expect(_rangeOf(tester).top, closeTo(fitted.top, 1e-6));
      expect(_rangeOf(tester).bottom, closeTo(fitted.bottom, 1e-6));
    });
  });

  group('the controller', () {
    testWidgets('stretches, compresses and resets', (tester) async {
      final controller = KChartController();
      await tester.pumpWidget(_chart(controller: controller));

      expect(controller.priceZoom, 1.0);

      controller.stretchPrice();
      await tester.pump();
      expect(controller.priceZoom, closeTo(1.2, 1e-9));

      controller.compressPrice(0.4);
      await tester.pump();
      expect(controller.priceZoom, closeTo(0.8, 1e-9));

      controller.resetPriceScale();
      await tester.pump();
      expect(controller.priceZoom, 1.0);
    });

    testWidgets('reports a change to its listeners', (tester) async {
      final controller = KChartController();
      await tester.pumpWidget(_chart(controller: controller));

      var notified = 0;
      controller.addListener(() => notified++);

      controller.setPriceZoom(2);
      await tester.pump();

      expect(notified, greaterThan(0));
    });

    testWidgets('does nothing while no chart is attached', (tester) async {
      final controller = KChartController();

      expect(controller.priceZoom, 1.0);
      controller.setPriceZoom(3);
      controller.resetPriceScale();

      expect(controller.priceZoom, 1.0);
    });
  });

  group('panning the price', () {
    testWidgets('a vertical drag slides a held scale', (tester) async {
      final controller = KChartController();
      await tester.pumpWidget(_chart(controller: controller));

      controller.setPriceZoom(2);
      await tester.pump();
      final held = _rangeOf(tester);

      await tester.drag(find.byType(KChartWidget), const Offset(0, 40));
      await tester.pumpAndSettle();
      final panned = _rangeOf(tester);

      // Dragging down carries the candles down, which means the window moved
      // up: both ends rise by the same amount, so the span is unchanged.
      expect(panned.top, greaterThan(held.top));
      expect(panned.bottom, greaterThan(held.bottom));
      expect(panned.top - panned.bottom, closeTo(held.top - held.bottom, 1e-6));
    });

    testWidgets('leaves a fitted scale alone', (tester) async {
      await tester.pumpWidget(_chart());
      final fitted = _rangeOf(tester);

      await tester.drag(find.byType(KChartWidget), const Offset(0, 40));
      await tester.pumpAndSettle();

      expect(_rangeOf(tester).top, closeTo(fitted.top, 1e-6));
      expect(_rangeOf(tester).bottom, closeTo(fitted.bottom, 1e-6));
    });
  });

  group('the grip', () {
    testWidgets('steps aside while a tool is armed', (tester) async {
      final data = candles(rampThenFall(60));
      DataUtil.calculate(data);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              height: 600,
              child: KChartWidget(
                data,
                ChartColors(),
                isTrendLine: true,
                timeFrame: const Duration(minutes: 15),
                currentDrawingTool: DrawingTool.horizontal,
              ),
            ),
          ),
        ),
      );

      final fitted = _rangeOf(tester);
      await tester.dragFrom(_gripCentre(tester), const Offset(0, -80));
      await tester.pump();

      expect(_rangeOf(tester).top, closeTo(fitted.top, 1e-6));
    });

    testWidgets('sits on the left when the labels do', (tester) async {
      await tester.pumpWidget(_chart(alignment: VerticalTextAlignment.left));
      final fitted = _rangeOf(tester);
      final rect = _painterOf(tester).mMainRect;
      final chart = tester.getTopLeft(find.byType(KChartWidget));

      await tester.dragFrom(
        chart + Offset(rect.left + 26, rect.center.dy),
        const Offset(0, -80),
      );
      await tester.pump();

      expect(
        _rangeOf(tester).top - _rangeOf(tester).bottom,
        greaterThan(fitted.top - fitted.bottom),
      );
    });
  });
}
