import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart/src/renderer/series_painter.dart';

import 'test_utils.dart';

/// Records what geometry actually reached the canvas.
class Recorder implements Canvas {
  final List<Rect> paths = [];
  final List<Offset> circles = [];
  final List<Rect> rects = [];
  int labels = 0;

  @override
  void drawPath(Path path, Paint paint) => paths.add(path.getBounds());
  @override
  void drawCircle(Offset c, double radius, Paint paint) => circles.add(c);
  @override
  void drawRect(Rect rect, Paint paint) => rects.add(rect);
  @override
  void drawParagraph(Paragraph paragraph, Offset offset) => labels++;
  @override
  void noSuchMethod(Invocation invocation) {}
}

Recorder paint(
  Indicator indicator,
  List<KLineEntity> data, {
  required int start,
  required int stop,
}) {
  final resolved = ResolvedIndicator(
    indicator: indicator,
    series: indicator.compute(data),
  );
  final recorder = Recorder();
  paintIndicatorSeries(
    recorder,
    resolved: resolved,
    candles: data,
    start: start,
    stop: stop,
    xOf: (i) => i * 4.0,
    yOf: (value) => 400 - value,
    colors: ChartColors(),
    strokeWidth: 1,
    barWidth: 3,
  );
  return recorder;
}

/// Two long legs: up to candle 40, then down to candle 90.
List<KLineEntity> swinging() {
  final closes = [
    for (var i = 0; i < 40; i++) 100.0 + i * 2,
    for (var i = 0; i < 50; i++) 178.0 - i * 2,
  ];
  return [
    for (var i = 0; i < closes.length; i++)
      candle(closes[i], high: closes[i], low: closes[i], minute: i),
  ];
}

void main() {
  group('pivot lines', () {
    test('draw the leg crossing a window that holds no pivot', () {
      final data = swinging();
      final indicator = ZigZagIndicator(depth: 5);

      // Candles 50-70 sit in the middle of the second leg: the pivots either
      // side of the window are the only values the line has.
      final drawn = paint(indicator, data, start: 50, stop: 70);

      expect(
        drawn.paths,
        hasLength(1),
        reason: 'the leg through the window is drawn',
      );
      final bounds = drawn.paths.single;
      expect(bounds.width, greaterThan(0));
      // It reaches across the whole window rather than stopping at its edges.
      expect(bounds.left, lessThanOrEqualTo(50 * 4.0));
      expect(bounds.right, greaterThanOrEqualTo(70 * 4.0));
    });

    test('a plain line still breaks at a gap', () {
      final data = swinging();
      // The same values, drawn as an ordinary line, have nothing to join.
      final drawn = paint(MaIndicator(period: 5), data, start: 50, stop: 70);
      expect(drawn.paths, hasLength(1));
      expect(drawn.paths.single.width, greaterThan(0));
    });

    test('a window with no pivots on either side draws nothing', () {
      final flat = candles([for (var i = 0; i < 40; i++) 100.0]);
      final drawn = paint(ZigZagIndicator(depth: 5), flat, start: 0, stop: 39);
      expect(drawn.paths, isEmpty);
    });
  });

  group('markers', () {
    test('draw a dot and a label at each wave', () {
      final data = swinging();
      final drawn = paint(
        ElliottWaveIndicator(depth: 5),
        data,
        start: 0,
        stop: data.length - 1,
      );

      expect(drawn.circles, isNotEmpty);
      expect(drawn.labels, drawn.circles.length);
    });

    test('stay out of a window they do not fall in', () {
      final data = swinging();
      final drawn = paint(
        ElliottWaveIndicator(depth: 5),
        data,
        start: 41,
        stop: 45,
      );
      expect(drawn.circles, isEmpty);
    });
  });

  group('fills', () {
    test('shade the cloud between the two spans', () {
      final data = [
        for (var i = 0; i < 140; i++)
          candle(100.0 + i, high: 101.0 + i, low: 99.0 + i, minute: i),
      ];
      final drawn = paint(
        IchimokuIndicator(),
        data,
        start: 0,
        stop: data.length - 1,
      );

      // Five lines plus at least one shaded stretch between the spans.
      expect(drawn.paths.length, greaterThan(5));
      expect(drawn.paths.any((r) => r.height > 0), isTrue);
    });
  });
}
