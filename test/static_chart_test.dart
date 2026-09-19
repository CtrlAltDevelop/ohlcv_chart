import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart/src/renderer/base_chart_painter.dart';
import 'package:ohlcv_chart/src/renderer/chart_painter.dart';

import 'test_utils.dart';

ChartPainter _painterOf(WidgetTester tester) {
  final dynamic state = tester.state(find.byType(KChartWidget));
  // ignore: avoid_dynamic_calls
  return state.painter as ChartPainter;
}

double _scrollOf(WidgetTester tester) {
  final dynamic state = tester.state(find.byType(KChartWidget));
  // ignore: avoid_dynamic_calls
  return state.mScrollX as double;
}

/// A session's worth of candles: more than fits the box at the default spacing,
/// so there is something to scroll unless it is turned off.
Widget _chart({
  bool scrollEnabled = true,
  bool zoomEnabled = true,
  double pointWidth = 8,
  ValueChanged<bool>? onLoadMore,
  KChartController? controller,
}) {
  final data = candles(rampThenFall(78));
  DataUtil.calculate(data);

  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 220,
        child: KChartWidget(
          data,
          ChartColors(),
          isTrendLine: false,
          timeFrame: const Duration(minutes: 5),
          chartType: ChartType.area,
          xFrontPadding: 0,
          volHidden: true,
          showNowPrice: false,
          scrollEnabled: scrollEnabled,
          zoomEnabled: zoomEnabled,
          onLoadMore: onLoadMore,
          controller: controller,
          chartStyle: ChartStyle(pointWidth: pointWidth),
        ),
      ),
    ),
  );
}

/// How many zoom sliders are in the tree.
int _sliders() => find
    .byWidgetPredicate(
      (w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeLeftRight,
    )
    .evaluate()
    .length;

Future<void> _pinchOut(WidgetTester tester) async {
  final centre = tester.getCenter(find.byType(KChartWidget));
  final left = await tester.startGesture(centre - const Offset(40, 0));
  final right = await tester.startGesture(centre + const Offset(40, 0));
  await left.moveBy(const Offset(-90, 0));
  await right.moveBy(const Offset(90, 0));
  await tester.pump();
  await left.up();
  await right.up();
  await tester.pumpAndSettle();
}

void main() {
  group('scrollEnabled', () {
    testWidgets('scrolls by default', (tester) async {
      await tester.pumpWidget(_chart());
      await tester.drag(find.byType(KChartWidget), const Offset(200, 0));
      await tester.pumpAndSettle();

      expect(_scrollOf(tester), greaterThan(0));
    });

    testWidgets('off, a drag leaves the window where it was', (tester) async {
      await tester.pumpWidget(_chart(scrollEnabled: false));
      final before = _painterOf(tester);
      final range = (before.mStartIndex, before.mStopIndex);

      await tester.drag(find.byType(KChartWidget), const Offset(400, 0));
      await tester.pumpAndSettle();

      expect(_scrollOf(tester), 0);
      final after = _painterOf(tester);
      expect((after.mStartIndex, after.mStopIndex), range);
    });

    testWidgets('off, a flick does not fling it either', (tester) async {
      await tester.pumpWidget(_chart(scrollEnabled: false));

      await tester.fling(find.byType(KChartWidget), const Offset(300, 0), 3000);
      await tester.pumpAndSettle();

      expect(_scrollOf(tester), 0);
    });

    testWidgets('off, onLoadMore is never asked', (tester) async {
      final calls = <bool>[];
      await tester.pumpWidget(
        _chart(scrollEnabled: false, onLoadMore: calls.add),
      );

      await tester.drag(find.byType(KChartWidget), const Offset(4000, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(KChartWidget), const Offset(-4000, 0));
      await tester.pumpAndSettle();

      expect(calls, isEmpty);
    });

    testWidgets('off, the controller can still scroll it', (tester) async {
      final controller = KChartController();
      await tester.pumpWidget(
        _chart(scrollEnabled: false, controller: controller),
      );

      controller.goToIndex(0, animated: false);
      await tester.pumpAndSettle();

      expect(
        _scrollOf(tester),
        greaterThan(0),
        reason: 'the flag holds the user back, not your own code',
      );
    });
  });

  group('zoomEnabled', () {
    testWidgets('pinches by default', (tester) async {
      await tester.pumpWidget(_chart());
      final before = _painterOf(tester).scaleX;

      await _pinchOut(tester);

      expect(_painterOf(tester).scaleX, isNot(before));
    });

    testWidgets('off, a pinch leaves the scale alone', (tester) async {
      await tester.pumpWidget(_chart(zoomEnabled: false));
      final before = _painterOf(tester).scaleX;

      await _pinchOut(tester);

      expect(_painterOf(tester).scaleX, before);
    });

    testWidgets('off, the zoom slider is left off on desktop and the web', (
      tester,
    ) async {
      // The slider stands in for the pinch on platforms that have no pinch, so
      // it is only ever built on desktop and the web -- and a test runs as
      // Android unless it is told otherwise.
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        // The slider is the only thing that listens for a resize cursor, so it
        // is what a desktop pointer would otherwise find at the bottom edge.
        await tester.pumpWidget(_chart());
        final withSlider = _sliders();

        await tester.pumpWidget(_chart(zoomEnabled: false));
        final without = _sliders();

        expect(withSlider, greaterThan(0), reason: 'shown by default here');
        expect(without, 0);
      } finally {
        // Reset inside the body: a tear-down runs after the framework has
        // already checked that no debug variable was left set.
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('off, the controller can still zoom it', (tester) async {
      final controller = KChartController();
      await tester.pumpWidget(
        _chart(zoomEnabled: false, controller: controller),
      );
      final before = _painterOf(tester).scaleX;

      controller.zoomIn();
      await tester.pumpAndSettle();

      expect(_painterOf(tester).scaleX, isNot(before));
    });
  });

  group('a chart meant to sit still', () {
    testWidgets('with the candles fitting, nothing can move it', (
      tester,
    ) async {
      // 78 candles at 5px in a 400px box: the whole session fits, so there is
      // nothing to scroll into even before the flag.
      await tester.pumpWidget(
        _chart(scrollEnabled: false, zoomEnabled: false, pointWidth: 5),
      );
      final painter = _painterOf(tester);

      expect(BaseChartPainter.maxScrollX, 0);
      expect(painter.mStartIndex, 0);
      expect(painter.mStopIndex, 77, reason: 'the whole session is drawn');

      await tester.drag(find.byType(KChartWidget), const Offset(400, 0));
      await tester.pumpAndSettle();
      await _pinchOut(tester);

      expect(_scrollOf(tester), 0);
      expect(_painterOf(tester).mStartIndex, 0);
      expect(_painterOf(tester).mStopIndex, 77);
    });

    testWidgets('a pinch cannot hand back the scrolling it took away', (
      tester,
    ) async {
      // The trap: zooming out narrows the candles, which leaves room to scroll
      // into. With zoom off there is no way back in.
      await tester.pumpWidget(
        _chart(scrollEnabled: false, zoomEnabled: false, pointWidth: 5),
      );
      expect(BaseChartPainter.maxScrollX, 0);

      await _pinchOut(tester);

      expect(BaseChartPainter.maxScrollX, 0);
      expect(_scrollOf(tester), 0);
    });

    testWidgets('and with zoom left on, it can -- which is why it pairs', (
      tester,
    ) async {
      await tester.pumpWidget(_chart(pointWidth: 5));
      expect(BaseChartPainter.maxScrollX, 0);

      await _pinchOut(tester);

      expect(
        BaseChartPainter.maxScrollX,
        greaterThan(0),
        reason: 'zooming out opens up somewhere to scroll',
      );
    });
  });
}
