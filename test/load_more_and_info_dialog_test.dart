import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart/src/components/popup_info_view.dart';
import 'package:ohlcv_chart/src/renderer/chart_painter.dart';

import 'test_utils.dart';

Widget _chart({
  ValueChanged<bool>? onLoadMore,
  bool showInfoDialog = true,
  bool isTapShowInfoDialog = false,
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
          onLoadMore: onLoadMore,
          showInfoDialog: showInfoDialog,
          isTapShowInfoDialog: isTapShowInfoDialog,
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

Widget _chartWith(List<KLineEntity> data) => MaterialApp(
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
          ),
        ),
      ),
    );

void main() {
  group('onLoadMore', () {
    testWidgets('is not called just for building the chart', (tester) async {
      final calls = <bool>[];
      await tester.pumpWidget(_chart(onLoadMore: calls.add));
      expect(calls, isEmpty);
    });

    testWidgets('fires false when the oldest candle is reached', (
      tester,
    ) async {
      final calls = <bool>[];
      await tester.pumpWidget(_chart(onLoadMore: calls.add));

      // Dragging to the right walks back through history.
      await tester.drag(find.byType(KChartWidget), const Offset(4000, 0));
      await tester.pumpAndSettle();

      expect(calls, contains(false));
    });

    testWidgets('fires once per arrival at an edge, not once per frame', (
      tester,
    ) async {
      final calls = <bool>[];
      await tester.pumpWidget(_chart(onLoadMore: calls.add));

      // One long gesture that spends many frames pinned against the edge.
      final gesture = await tester.startGesture(const Offset(250, 200));
      for (var i = 0; i < 40; i++) {
        await gesture.moveBy(const Offset(200, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(calls.where((right) => !right).length, 1);
    });

    testWidgets('asks again after leaving the edge and coming back', (
      tester,
    ) async {
      final calls = <bool>[];
      await tester.pumpWidget(_chart(onLoadMore: calls.add));

      await tester.drag(find.byType(KChartWidget), const Offset(4000, 0));
      await tester.pumpAndSettle();
      final first = calls.where((right) => !right).length;

      // Come away from the oldest candle, then go back to it.
      await tester.drag(find.byType(KChartWidget), const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(KChartWidget), const Offset(4000, 0));
      await tester.pumpAndSettle();

      expect(calls.where((right) => !right).length, first + 1);
    });

    testWidgets('fires true at the newest candle', (tester) async {
      final calls = <bool>[];
      await tester.pumpWidget(_chart(onLoadMore: calls.add));

      // Back through history, then forward past the newest candle again.
      await tester.drag(find.byType(KChartWidget), const Offset(4000, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(KChartWidget), const Offset(-4000, 0));
      await tester.pumpAndSettle();

      expect(calls, contains(true));
    });

    testWidgets('the window stays put when older candles arrive', (
      tester,
    ) async {
      // What a caller does in response to onLoadMore(false): prepend the older
      // candles and hand back the longer list. The chart is anchored to the
      // newest candle, so the window must not jump.
      final recent = candles(rampThenFall(120));
      DataUtil.calculate(recent);
      await tester.pumpWidget(_chartWith(recent));

      await tester.drag(find.byType(KChartWidget), const Offset(300, 0));
      await tester.pumpAndSettle();
      final atRightEdge = recent[_painterOf(tester).mStopIndex].dateTime;

      final longer = [
        for (var i = 0; i < 80; i++) candle(90.0 + i, minute: -80 + i),
        ...recent,
      ];
      DataUtil.calculate(longer);
      await tester.pumpWidget(_chartWith(longer));
      await tester.pumpAndSettle();

      expect(
        longer[_painterOf(tester).mStopIndex].dateTime,
        atRightEdge,
        reason: 'the same candle is still at the right edge',
      );
    });

    testWidgets('a chart with no callback still scrolls', (tester) async {
      await tester.pumpWidget(_chart());
      await tester.drag(find.byType(KChartWidget), const Offset(4000, 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('showInfoDialog', () {
    testWidgets('survives being turned off and on again', (tester) async {
      await tester.pumpWidget(_chart(showInfoDialog: true));
      await tester.pumpWidget(_chart(showInfoDialog: false));
      await tester.pumpWidget(_chart(showInfoDialog: true));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(KChartWidget), findsOneWidget);
    });

    testWidgets('still reads out a candle after being toggled', (tester) async {
      await tester.pumpWidget(
        _chart(showInfoDialog: true, isTapShowInfoDialog: true),
      );
      await tester.pumpWidget(
        _chart(showInfoDialog: false, isTapShowInfoDialog: true),
      );
      await tester.pumpWidget(
        _chart(showInfoDialog: true, isTapShowInfoDialog: true),
      );
      await tester.pumpAndSettle();

      // Held, not tapped: the readout is up only while the press is down.
      final centre = tester.getCenter(find.byType(KChartWidget));
      await tester.startGesture(centre);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(PopupInfoView), findsOneWidget);
    });

    testWidgets('toggling repeatedly never throws', (tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pumpWidget(_chart(showInfoDialog: i.isEven));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });
  });
}
