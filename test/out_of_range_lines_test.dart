import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart/src/renderer/chart_painter.dart';

import 'test_utils.dart';

const double _width = 500;
const double _height = 600;

ChartPainter _painterOf(WidgetTester tester) {
  final dynamic state = tester.state(find.byType(KChartWidget));
  // ignore: avoid_dynamic_calls
  return state.painter as ChartPainter;
}

/// A canvas that notes where every line and every run of text was drawn.
class _Probe implements Canvas {
  final List<Offset> lines = [];
  final List<Offset> textAt = [];

  Offset _translate = Offset.zero;
  final List<Offset> _stack = [];

  /// The lines drawn outside [rect], vertically — the ones that escape the
  /// pane they belong to.
  List<Offset> escaping(Rect rect) => lines
      .where((o) => o.dy < rect.top - 0.5 || o.dy > rect.bottom + 0.5)
      .toList();

  @override
  void save() => _stack.add(_translate);

  @override
  void restore() {
    if (_stack.isNotEmpty) _translate = _stack.removeLast();
  }

  @override
  void translate(double dx, double dy) =>
      _translate = _translate.translate(dx, dy);

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    lines
      ..add(p1 + _translate)
      ..add(p2 + _translate);
  }

  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) =>
      textAt.add(offset + _translate);

  @override
  void noSuchMethod(Invocation invocation) {}
}

/// A climb steep enough that scrolling leaves a locked range far behind.
List<KLineEntity> _trend([int count = 300]) {
  final data = candles([for (var i = 0; i < count; i++) 100.0 + i * 2]);
  DataUtil.calculate(data);
  return data;
}

Widget _chart({
  required List<KLineEntity> data,
  ChartDrawingController? controller,
  bool showNowPrice = false,
}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: _width,
      height: _height,
      child: KChartWidget(
        data,
        ChartColors(),
        isTrendLine: false,
        watermarkAssetPath: 'assets/none.svg',
        timeFrame: const Duration(minutes: 15),
        showNowPrice: showNowPrice,
        lockPriceScale: true,
        drawingController: controller,
      ),
    ),
  ),
);

/// Lays the chart out, then records one draw pass of [draw] on its own.
///
/// Recording the whole paint would sweep in the grid and the date axis, which
/// are drawn outside the candle area because that is where they belong. What
/// is on trial here is the price-anchored lines.
_Probe _record(ChartPainter painter, void Function(Canvas, Size) draw) {
  painter.paint(Canvas(ui.PictureRecorder()), const Size(_width, _height));
  final probe = _Probe();
  draw(probe, const Size(_width, _height));
  return probe;
}

void main() {
  group('a price the locked axis does not reach', () {
    testWidgets('keeps a horizontal line out of the other panes', (
      tester,
    ) async {
      // Far above anything the chart ever shows, so it is outside whatever
      // range the axis locked onto.
      final controller = ChartDrawingController(
        drawings: [HorizontalLine(price: 100000)],
      );
      await tester.pumpWidget(_chart(data: _trend(), controller: controller));
      await tester.pump();

      final painter = _painterOf(tester);
      expect(
        painter.withinMain(painter.getMainY(100000)),
        isFalse,
        reason: 'the level really is off the axis',
      );
      final probe = _record(painter, painter.drawHorizontalLines);
      expect(probe.lines, isEmpty);
    });

    testWidgets('still marks the edge with the line label', (tester) async {
      final controller = ChartDrawingController(
        drawings: [HorizontalLine(price: 100000, showLabel: true)],
      );
      await tester.pumpWidget(_chart(data: _trend(), controller: controller));
      await tester.pump();

      final painter = _painterOf(tester);
      final rect = painter.mMainRect;
      final probe = _record(painter, painter.drawHorizontalLineTitles);
      expect(probe.textAt, isNotEmpty, reason: 'the label is still drawn');
      expect(
        probe.textAt.every((o) => o.dy >= rect.top - 20 && o.dy <= rect.bottom),
        isTrue,
        reason: 'and pinned to the edge the price went past',
      );
    });

    testWidgets('draws a level the axis does reach as it always did', (
      tester,
    ) async {
      final data = _trend();
      await tester.pumpWidget(_chart(data: data));
      await tester.pump();
      final at = _painterOf(tester).mMainRenderer;
      final inRange = (at.minValue + at.maxValue) / 2;

      final controller = ChartDrawingController(
        drawings: [HorizontalLine(price: inRange)],
      );
      await tester.pumpWidget(_chart(data: data, controller: controller));
      await tester.pump();

      final painter = _painterOf(tester);
      final probe = _record(painter, painter.drawHorizontalLines);
      expect(probe.lines, isNotEmpty);
      expect(probe.escaping(painter.mMainRect), isEmpty);
    });

    testWidgets('pins the now-price line to the edge it went past', (
      tester,
    ) async {
      final data = _trend();
      await tester.pumpWidget(_chart(data: data, showNowPrice: true));
      await tester.pump();

      // Scroll back so the axis is locked on old, low prices while the last
      // candle — what the now-price line marks — is far above them.
      await tester.drag(find.byType(KChartWidget), const Offset(2000, 0));
      await tester.pumpAndSettle();

      final painter = _painterOf(tester);
      final probe = _record(
        painter,
        (canvas, _) => painter.drawNowPrice(canvas),
      );
      expect(probe.lines, isNotEmpty, reason: 'the line is still drawn');
      expect(probe.escaping(painter.mMainRect), isEmpty);
    });
  });
}
