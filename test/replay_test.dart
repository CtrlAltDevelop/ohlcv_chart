import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart/src/renderer/chart_painter.dart';

import 'test_utils.dart';

Widget _chart(List<KLineEntity> data, {ChartReplayController? replay}) {
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
          replay: replay,
          indicators: [MaIndicator(period: 5)],
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

/// How many candles the chart is currently drawing.
int _drawnCount(WidgetTester tester) => _painterOf(tester).candles?.length ?? 0;

List<KLineEntity> _data([int count = 60]) {
  final data = candles(rampThenFall(count));
  DataUtil.calculate(data);
  return data;
}

void main() {
  group('the controller', () {
    test('starts inactive and hands the whole series over', () {
      final replay = ChartReplayController();

      expect(replay.isActive, isFalse);
      expect(replay.position, isNull);
      expect(replay.isPlaying, isFalse);

      replay.dispose();
    });

    test('rewinds, steps and stops', () {
      final replay = ChartReplayController()..reportLength(60);

      replay.start(at: 20);
      expect(replay.position, 20);
      expect(replay.isActive, isTrue);

      replay.stepForward();
      expect(replay.position, 21);

      replay.stepForward(5);
      expect(replay.position, 26);

      replay.stepBack(6);
      expect(replay.position, 20);

      replay.stop();
      expect(replay.isActive, isFalse);

      replay.dispose();
    });

    test('never leaves the series', () {
      final replay = ChartReplayController()..reportLength(10);

      replay.start(at: 500);
      expect(replay.position, 10);

      replay.start(at: -5);
      expect(replay.position, 1);

      replay.stepBack(100);
      expect(replay.position, 1);

      replay.dispose();
    });

    test('a shorter series pulls the position back', () {
      final replay = ChartReplayController()..reportLength(60);
      replay.start(at: 50);

      replay.reportLength(20);
      expect(replay.position, 20);

      replay.dispose();
    });

    test('reports every move to its listeners', () {
      final replay = ChartReplayController()..reportLength(60);
      var notified = 0;
      replay.addListener(() => notified++);

      replay.start(at: 10);
      replay.stepForward();
      replay.stepBack();
      replay.stop();

      expect(notified, 4);

      // A move that changes nothing is not a move.
      replay.start(at: 10);
      replay.start(at: 10);
      expect(notified, 5);

      replay.dispose();
    });

    testWidgets('plays, pauses and gives up at the end', (tester) async {
      final replay = ChartReplayController(
        interval: const Duration(milliseconds: 100),
      )..reportLength(5);

      replay.start(at: 3);
      replay.play();
      expect(replay.isPlaying, isTrue);

      await tester.pump(const Duration(milliseconds: 110));
      expect(replay.position, 4);

      replay.pause();
      expect(replay.isPlaying, isFalse);
      await tester.pump(const Duration(milliseconds: 200));
      expect(replay.position, 4);

      replay.play();
      await tester.pump(const Duration(milliseconds: 110));
      expect(replay.position, 5);
      // The newest candle is the end of it: the timer stops itself.
      expect(replay.isPlaying, isFalse);
      expect(replay.isAtEnd, isTrue);

      replay.dispose();
    });

    testWidgets('play from cold starts halfway', (tester) async {
      final replay = ChartReplayController(
        interval: const Duration(milliseconds: 100),
      )..reportLength(40);

      replay.play();
      expect(replay.position, 20);
      expect(replay.isPlaying, isTrue);

      replay.pause();
      replay.dispose();
    });

    testWidgets('toggle plays and pauses', (tester) async {
      final replay = ChartReplayController(
        interval: const Duration(milliseconds: 100),
      )..reportLength(40);

      replay.toggle();
      expect(replay.isPlaying, isTrue);

      replay.toggle();
      expect(replay.isPlaying, isFalse);

      replay.dispose();
    });

    testWidgets('a new interval takes hold straight away', (tester) async {
      final replay = ChartReplayController(
        interval: const Duration(seconds: 10),
      )..reportLength(40);

      replay.start(at: 10);
      replay.play();
      replay.setInterval(const Duration(milliseconds: 50));

      await tester.pump(const Duration(milliseconds: 60));
      expect(replay.position, 11);

      replay.pause();
      replay.dispose();
    });
  });

  group('the chart', () {
    testWidgets('draws only as far as the replay has got', (tester) async {
      final replay = ChartReplayController();
      final data = _data();

      await tester.pumpWidget(_chart(data, replay: replay));
      expect(_drawnCount(tester), 60);

      replay.start(at: 25);
      await tester.pumpAndSettle();
      expect(_drawnCount(tester), 25);

      replay.stepForward();
      await tester.pumpAndSettle();
      expect(_drawnCount(tester), 26);

      replay.stop();
      await tester.pumpAndSettle();
      expect(_drawnCount(tester), 60);

      replay.dispose();
    });

    testWidgets('learns how long the series is on its own', (tester) async {
      final replay = ChartReplayController();
      await tester.pumpWidget(_chart(_data(), replay: replay));

      expect(replay.length, 60);

      replay.dispose();
    });

    testWidgets('the indicators only know what has arrived', (tester) async {
      final replay = ChartReplayController();
      final data = _data();

      await tester.pumpWidget(_chart(data, replay: replay));
      final full = _painterOf(tester).overlays.first.series.lines.first.length;
      expect(full, 60);

      replay.start(at: 30);
      await tester.pumpAndSettle();
      expect(_painterOf(tester).overlays.first.series.lines.first.length, 30);

      replay.dispose();
    });

    testWidgets('a chart with no replay is unaffected', (tester) async {
      await tester.pumpWidget(_chart(_data()));
      expect(_drawnCount(tester), 60);
    });

    testWidgets('a replay swapped in mid-flight is listened to', (
      tester,
    ) async {
      final first = ChartReplayController();
      final second = ChartReplayController();
      final data = _data();

      await tester.pumpWidget(_chart(data, replay: first));
      await tester.pumpWidget(_chart(data, replay: second));

      second.start(at: 15);
      await tester.pumpAndSettle();
      expect(_drawnCount(tester), 15);

      // The chart let go of the one it was handed first.
      first.start(at: 40);
      await tester.pumpAndSettle();
      expect(_drawnCount(tester), 15);

      first.dispose();
      second.dispose();
    });
  });
}
