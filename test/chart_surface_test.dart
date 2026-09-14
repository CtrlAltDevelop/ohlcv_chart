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

Widget _chart({
  KChartController? controller,
  bool showScrollToNowButton = true,
  bool resizablePanes = false,
  bool reorderablePanes = false,
  void Function(int from, int to)? onReorderPane,
  List<Indicator> indicators = const [],
  ChartStyle style = const ChartStyle(),
  Duration timeZoneOffset = Duration.zero,
}) {
  final data = candles(rampThenFall(120));
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
          showNowPrice: false,
          controller: controller,
          showScrollToNowButton: showScrollToNowButton,
          resizablePanes: resizablePanes,
          reorderablePanes: reorderablePanes,
          onReorderPane: onReorderPane,
          indicators: indicators,
          chartStyle: style,
          timeZoneOffset: timeZoneOffset,
        ),
      ),
    ),
  );
}

void main() {
  group('KChartController', () {
    testWidgets('attaches to the chart it is given to', (tester) async {
      final controller = KChartController();
      expect(controller.isAttached, isFalse);

      await tester.pumpWidget(_chart(controller: controller));

      expect(controller.isAttached, isTrue);
      expect(controller.isAtRightEdge, isTrue);
    });

    testWidgets('zooms within the range the chart allows', (tester) async {
      final controller = KChartController();
      await tester.pumpWidget(_chart(controller: controller));

      controller.zoomIn();
      await tester.pumpAndSettle();
      expect(controller.scale, closeTo(1.2, 1e-9));

      controller.zoomOut(0.5);
      await tester.pumpAndSettle();
      expect(controller.scale, closeTo(0.7, 1e-9));

      controller.zoomTo(99);
      await tester.pumpAndSettle();
      expect(
        controller.scale,
        3.0,
        reason: 'clamped to the maximum the chart allows',
      );

      controller.zoomTo(0);
      await tester.pumpAndSettle();
      expect(controller.scale, closeTo(0.1, 1e-9));
    });

    testWidgets('scrolls back to the newest candle', (tester) async {
      final controller = KChartController();
      await tester.pumpWidget(_chart(controller: controller));

      // Drag back into history.
      await tester.drag(find.byType(KChartWidget), const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(controller.isAtRightEdge, isFalse);

      controller.scrollToNow(animated: false);
      await tester.pumpAndSettle();

      expect(controller.isAtRightEdge, isTrue);
    });

    testWidgets('animates its way back', (tester) async {
      final controller = KChartController();
      await tester.pumpWidget(_chart(controller: controller));

      await tester.drag(find.byType(KChartWidget), const Offset(300, 0));
      await tester.pumpAndSettle();

      controller.scrollToNow();
      await tester.pumpAndSettle();

      expect(controller.isAtRightEdge, isTrue);
    });

    testWidgets('captures the chart as a PNG', (tester) async {
      final controller = KChartController();
      await tester.pumpWidget(_chart(controller: controller));
      await tester.pumpAndSettle();

      final bytes = await tester.runAsync(() => controller.capture());

      expect(bytes, isNotNull);
      // The PNG magic number.
      expect(bytes!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    });

    test('a detached controller is harmless', () async {
      final controller = KChartController();

      controller
        ..zoomIn()
        ..scrollToNow();

      expect(controller.scale, 1.0);
      expect(controller.isAtRightEdge, isTrue);
      expect(await controller.capture(), isNull);
    });

    testWidgets('detaches when the chart goes away', (tester) async {
      final controller = KChartController();
      await tester.pumpWidget(_chart(controller: controller));
      expect(controller.isAttached, isTrue);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      expect(controller.isAttached, isFalse);
    });
  });

  group('the jump-to-now button', () {
    testWidgets('only appears once the chart is scrolled away', (tester) async {
      await tester.pumpWidget(_chart());
      expect(find.byTooltip('Jump to the latest candle'), findsNothing);

      await tester.drag(find.byType(KChartWidget), const Offset(300, 0));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Jump to the latest candle'), findsOneWidget);
    });

    testWidgets('scrolls back when tapped', (tester) async {
      final controller = KChartController();
      await tester.pumpWidget(_chart(controller: controller));

      await tester.drag(find.byType(KChartWidget), const Offset(300, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Jump to the latest candle'));
      await tester.pumpAndSettle();

      expect(controller.isAtRightEdge, isTrue);
      expect(find.byTooltip('Jump to the latest candle'), findsNothing);
    });

    testWidgets('can be turned off', (tester) async {
      await tester.pumpWidget(_chart(showScrollToNowButton: false));

      await tester.drag(find.byType(KChartWidget), const Offset(300, 0));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Jump to the latest candle'), findsNothing);
    });
  });

  group('resizing a pane', () {
    testWidgets('dragging its lower edge makes it taller', (tester) async {
      await tester.pumpWidget(
        _chart(resizablePanes: true, indicators: [MacdIndicator()]),
      );
      await tester.pumpAndSettle();

      final before = _painterOf(tester).mSecondaryRectList.single.mRect;
      await tester.dragFrom(Offset(250, before.bottom), const Offset(0, 40));
      await tester.pumpAndSettle();

      final after = _painterOf(tester).mSecondaryRectList.single.mRect;
      expect(after.height, greaterThan(before.height));
    });

    testWidgets('a pane cannot be dragged below its minimum', (tester) async {
      await tester.pumpWidget(
        _chart(
          resizablePanes: true,
          indicators: [MacdIndicator()],
          style: const ChartStyle(minPaneHeight: 80),
        ),
      );
      await tester.pumpAndSettle();

      final edge = _painterOf(tester).mSecondaryRectList.single.mRect.bottom;
      await tester.dragFrom(Offset(250, edge), const Offset(0, -400));
      await tester.pumpAndSettle();

      final rect = _painterOf(tester).mSecondaryRectList.single.mRect;
      // The rect is the pane less its legend padding, so compare the pane.
      expect(rect.height, greaterThan(50));
    });

    testWidgets('is off unless asked for', (tester) async {
      await tester.pumpWidget(_chart(indicators: [MacdIndicator()]));
      await tester.pumpAndSettle();

      final before = _painterOf(tester).mSecondaryRectList.single.mRect;
      await tester.dragFrom(Offset(250, before.bottom), const Offset(0, 40));
      await tester.pumpAndSettle();

      final after = _painterOf(tester).mSecondaryRectList.single.mRect;
      expect(after.height, before.height);
    });
  });

  group('reordering panes', () {
    testWidgets('dragging a pane down reports the move', (tester) async {
      final moves = <(int, int)>[];
      await tester.pumpWidget(
        _chart(
          reorderablePanes: true,
          onReorderPane: (from, to) => moves.add((from, to)),
          indicators: [MacdIndicator(), RsiIndicator()],
        ),
      );
      await tester.pumpAndSettle();

      final pane = _painterOf(tester).mSecondaryRectList.first.mRect;
      // The legend strip at the top of the pane is what picks it up.
      final gesture = await tester.startGesture(Offset(250, pane.top - 6));
      for (var i = 0; i < 3; i++) {
        await gesture.moveBy(const Offset(0, 60));
        await tester.pump();
      }

      expect(
        _painterOf(tester).highlightedPane,
        0,
        reason: 'the pane being moved is marked while it is dragged',
      );

      await gesture.up();
      await tester.pumpAndSettle();

      expect(moves, [(0, 1)]);
      expect(_painterOf(tester).highlightedPane, isNull);
    });

    testWidgets('a drag that goes nowhere reports nothing', (tester) async {
      final moves = <(int, int)>[];
      await tester.pumpWidget(
        _chart(
          reorderablePanes: true,
          onReorderPane: (from, to) => moves.add((from, to)),
          indicators: [MacdIndicator(), RsiIndicator()],
        ),
      );
      await tester.pumpAndSettle();

      final grab = _painterOf(tester).mSecondaryRectList.first.mRect.top - 6;
      await tester.dragFrom(Offset(250, grab), const Offset(0, 4));
      await tester.pumpAndSettle();

      expect(moves, isEmpty);
    });

    testWidgets('is off unless asked for', (tester) async {
      final moves = <(int, int)>[];
      await tester.pumpWidget(
        _chart(
          onReorderPane: (from, to) => moves.add((from, to)),
          indicators: [MacdIndicator(), RsiIndicator()],
        ),
      );
      await tester.pumpAndSettle();

      final grab = _painterOf(tester).mSecondaryRectList.first.mRect.top - 6;
      await tester.dragFrom(Offset(250, grab), const Offset(0, 150));
      await tester.pumpAndSettle();

      expect(moves, isEmpty);
    });
  });

  group('sessions and time zones', () {
    testWidgets('day dividers draw without blowing up', (tester) async {
      await tester.pumpWidget(
        _chart(style: const ChartStyle(showSessionDividers: true)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('the axis reads dates in the zone it is given', (tester) async {
      await tester.pumpWidget(
        _chart(timeZoneOffset: const Duration(hours: 5, minutes: 30)),
      );
      await tester.pumpAndSettle();

      final painter = _painterOf(tester);
      final at = DateTime.utc(2024, 1, 1, 12);
      expect(painter.displayTime(at), DateTime.utc(2024, 1, 1, 17, 30));
      expect(painter.getDate(at), contains('17:30'));
    });

    testWidgets('no offset leaves the time as it came', (tester) async {
      await tester.pumpWidget(_chart());
      await tester.pumpAndSettle();

      final at = DateTime.utc(2024, 1, 1, 12);
      expect(_painterOf(tester).displayTime(at), at);
    });
  });
}
