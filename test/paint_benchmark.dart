import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart/src/renderer/chart_painter.dart';

/// Times what a frame of the chart costs.
///
/// Not a test — it asserts nothing and is not picked up by `flutter test`,
/// which only collects `*_test.dart`. Run it by name:
///
///     flutter test test/paint_benchmark.dart
///
/// Wall-clock numbers say as much about what else the machine was doing as
/// about the chart, which is why the assertions in `render_perf_test.dart`
/// count draw calls instead. This is for putting a number on a change by
/// running it either side of one, on the same quiet machine.
List<KLineEntity> _market({int count = 2000}) {
  final data = <KLineEntity>[];
  var price = 100.0;
  for (var i = 0; i < count; i++) {
    final move = math.sin(i / 6) * 2.4 + 0.18;
    final open = price;
    final close = price + move;
    data.add(
      KLineEntity.fromCustom(
        open: open,
        high: math.max(open, close) + 1.1,
        low: math.min(open, close) - 1.1,
        close: close,
        vol: 800 + math.sin(i / 3) * 300,
        dateTime: DateTime.utc(2024).add(Duration(minutes: i * 15)),
      ),
    );
    price = close;
  }
  DataUtil.calculate(data);
  return data;
}

const Size _size = Size(1200, 800);

/// Microseconds per call, as a median over [runs] after a warm-up.
///
/// The median rather than the mean: one run that landed on a garbage collection
/// should not stand for the rest.
double _median(void Function() body, {int warmup = 40, int runs = 200}) {
  for (var i = 0; i < warmup; i++) {
    body();
  }
  final times = <int>[];
  final watch = Stopwatch();
  for (var i = 0; i < runs; i++) {
    watch
      ..reset()
      ..start();
    body();
    watch.stop();
    times.add(watch.elapsedMicroseconds);
  }
  times.sort();
  return times[times.length ~/ 2].toDouble();
}

void main() {
  Future<ChartPainter> chart(
    WidgetTester tester,
    ChartType type, {
    List<KLineEntity>? data,
    List<Indicator> indicators = const [],
    List<ChartLine> drawings = const [],
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: _size.width,
            height: _size.height,
            child: KChartWidget(
              data ?? _market(),
              ChartColors(),
              isTrendLine: false,
              timeFrame: const Duration(minutes: 15),
              chartType: type,
              indicators: indicators,
              drawings: drawings,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final dynamic state = tester.state(find.byType(KChartWidget));
    // ignore: avoid_dynamic_calls
    return state.painter as ChartPainter;
  }

  void report(String label, double micros, int candles) {
    // ignore: avoid_print
    print('BENCH|$label|${micros.toStringAsFixed(0)}us|candles=$candles');
  }

  /// Paints [body] into a throwaway recorder, the way a frame would.
  void timed(String label, ChartPainter painter, void Function(Canvas) body) {
    late ui.PictureRecorder recorder;
    final micros = _median(() {
      recorder = ui.PictureRecorder();
      body(Canvas(recorder));
      recorder.endRecording().dispose();
    });
    report(label, micros, painter.mStopIndex - painter.mStartIndex + 1);
  }

  for (final type in ChartType.values) {
    testWidgets('paint ${type.name}', (tester) async {
      final painter = await chart(tester, type);
      timed(type.name, painter, (c) => painter.paint(c, _size));
    });
  }

  testWidgets('paint candles with six indicators', (tester) async {
    final painter = await chart(
      tester,
      ChartType.candles,
      indicators: [
        MaIndicator(period: 5),
        MaIndicator(period: 20),
        MaIndicator(period: 60),
        BollIndicator(period: 20, deviations: 2),
        MacdIndicator(),
        RsiIndicator(period: 14),
      ],
    );
    timed('candles+6 indicators', painter, (c) => painter.paint(c, _size));
  });

  testWidgets('paint with twenty drawings over a long history', (tester) async {
    final data = _market(count: 50000);
    final at = data[40000].dateTime!;
    final painter = await chart(
      tester,
      ChartType.candles,
      data: data,
      drawings: <ChartLine>[
        for (var i = 0; i < 20; i++)
          HorizontalLine(price: 100.0 + i * 3, startTime: at),
      ],
    );
    timed('50k candles + 20 drawings', painter, (c) => painter.paint(c, _size));
  });

  testWidgets('a mouse move', (tester) async {
    final painter = await chart(tester, ChartType.candles);
    painter
      ..isHovering = true
      ..selectX = _size.width / 2
      ..selectY = _size.height / 3;

    // Before the crosshair had a layer of its own, a mouse move cost a whole
    // repaint — the `candles` figure above. Now it costs this.
    var x = 0.0;
    late ui.PictureRecorder recorder;
    final micros = _median(() {
      painter.selectX = _size.width / 2 + (x = (x + 1) % 60);
      recorder = ui.PictureRecorder();
      painter.paintOverlay(Canvas(recorder), _size);
      recorder.endRecording().dispose();
    });
    report('mouse move (crosshair layer)', micros, 0);
  });
}
