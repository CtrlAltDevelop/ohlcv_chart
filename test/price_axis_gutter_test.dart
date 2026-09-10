import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart/src/renderer/chart_painter.dart';

import 'counting_canvas.dart';
import 'test_utils.dart';

const double _width = 500;
const double _gutter = 60;

ChartPainter _painterOf(WidgetTester tester) {
  final dynamic state = tester.state(find.byType(KChartWidget));
  // ignore: avoid_dynamic_calls
  return state.painter as ChartPainter;
}

Widget _chart({
  double priceAxisWidth = 0.0,
  VerticalTextAlignment alignment = VerticalTextAlignment.right,
  int count = 120,
}) {
  final data = candles(rampThenFall(count));
  DataUtil.calculate(data);

  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: _width,
        height: 600,
        child: KChartWidget(
          data,
          ChartColors(),
          isTrendLine: false,
          watermarkAssetPath: 'assets/none.svg',
          timeFrame: const Duration(minutes: 15),
          showNowPrice: true,
          verticalTextAlignment: alignment,
          chartStyle: ChartStyle(priceAxisWidth: priceAxisWidth),
        ),
      ),
    ),
  );
}

/// Every x a line or rect was drawn at, from one paint of [painter].
({List<double> xs, CountingCanvas canvas}) _record(ChartPainter painter) {
  final recorder = ui.PictureRecorder();
  final canvas = CountingCanvas(Canvas(recorder));
  painter.paint(canvas, Size(_width, 600));
  return (xs: const [], canvas: canvas);
}

/// A canvas that records the clips pushed during a paint, and any line drawn
/// past the plot while the clip in force would have allowed it.
///
/// Fills are left alone: the background and the axis label pills are *meant*
/// to reach into the gutter.
class _GutterProbe implements Canvas {
  _GutterProbe(this.plotRight);

  final double plotRight;

  /// Every clip the painter pushed, in order.
  final List<Rect> clips = [];

  /// Lines drawn past the plot that the clip did not hold back.
  final List<String> spill = [];

  Rect _clip = const Rect.fromLTRB(0, 0, 1e9, 1e9);
  final List<Rect> _stack = [];

  /// Whether the plot was clipped to at any point.
  bool get clippedToPlot => clips.any((r) => (r.right - plotRight).abs() < 0.5);

  void _check(String what, double x) {
    if (x > plotRight + 0.5 && _clip.right > plotRight + 0.5) {
      spill.add('$what at $x');
    }
  }

  @override
  void save() => _stack.add(_clip);

  @override
  void restore() {
    if (_stack.isNotEmpty) _clip = _stack.removeLast();
  }

  @override
  void clipRect(
    Rect rect, {
    ui.ClipOp clipOp = ui.ClipOp.intersect,
    bool doAntiAlias = true,
  }) {
    clips.add(rect);
    _clip = _clip.intersect(rect);
  }

  /// Where each run of text was painted.
  final List<Offset> textAt = [];

  /// Every translate the painter applied.
  final List<double> translates = [];

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    _check('line', p1.dx > p2.dx ? p1.dx : p2.dx);
  }

  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) {
    textAt.add(offset);
  }

  @override
  void translate(double dx, double dy) => translates.add(dx);

  @override
  void noSuchMethod(Invocation invocation) {}
}

void main() {
  group('the price axis gutter', () {
    testWidgets('is not held back by default', (tester) async {
      await tester.pumpWidget(_chart());
      final painter = _painterOf(tester);

      expect(painter.priceAxisGutter, 0);
      expect(painter.mWidth, _width);
      expect(painter.mPlotLeft, 0);
      expect(painter.mPlotRight, _width);
      expect(painter.mMainRect.right, _width);
    });

    testWidgets('takes width off the plot on the label side', (tester) async {
      await tester.pumpWidget(_chart(priceAxisWidth: _gutter));
      final painter = _painterOf(tester);

      expect(painter.priceAxisGutter, _gutter);
      expect(painter.mCanvasWidth, _width);
      expect(painter.mWidth, _width - _gutter);
      expect(painter.mPlotLeft, 0, reason: 'labels on the right');
      expect(painter.mPlotRight, _width - _gutter);
    });

    testWidgets('holds it back on the left when the labels are', (
      tester,
    ) async {
      await tester.pumpWidget(
        _chart(priceAxisWidth: _gutter, alignment: VerticalTextAlignment.left),
      );
      final painter = _painterOf(tester);

      expect(painter.mPlotLeft, _gutter);
      expect(painter.mPlotRight, _width);
      expect(painter.mMainRect.left, _gutter);
    });

    testWidgets('every pane stops at the gutter, not the canvas', (
      tester,
    ) async {
      await tester.pumpWidget(_chart(priceAxisWidth: _gutter));
      final painter = _painterOf(tester);

      expect(painter.mMainRect.right, _width - _gutter);
      expect(painter.mVolRect?.right, _width - _gutter);
      for (final pane in painter.mSecondaryRectList) {
        expect(pane.mRect.right, _width - _gutter);
      }
    });

    testWidgets('the labels are drawn in it, clear of the plot', (
      tester,
    ) async {
      await tester.pumpWidget(_chart(priceAxisWidth: _gutter));
      final painter = _painterOf(tester);

      final probe = _GutterProbe(_width - _gutter);
      painter.paint(probe, const Size(_width, 600));

      expect(
        probe.textAt.where((o) => o.dx >= _width - _gutter),
        isNotEmpty,
        reason: 'price labels sit inside the gutter',
      );
    });

    testWidgets('without it the labels stay over the plot', (tester) async {
      await tester.pumpWidget(_chart());
      final painter = _painterOf(tester);

      final probe = _GutterProbe(_width);
      painter.paint(probe, const Size(_width, 600));

      expect(probe.textAt, isNotEmpty);
      expect(
        probe.textAt.every((o) => o.dx < _width),
        isTrue,
        reason: 'nothing is pushed off the canvas',
      );
    });

    testWidgets('is never wide enough to leave no plot', (tester) async {
      await tester.pumpWidget(_chart(priceAxisWidth: 10000));
      final painter = _painterOf(tester);

      expect(painter.mWidth, greaterThan(0));
      expect(painter.priceAxisGutter, _width / 2);
    });
  });

  group('the axis stays put while the chart scrolls', () {
    testWidgets('the labels do not move when the candles do', (tester) async {
      await tester.pumpWidget(_chart(priceAxisWidth: _gutter));
      final painter = _painterOf(tester);

      final before = painter.mPlotRight;
      await tester.drag(find.byType(KChartWidget), const Offset(200, 0));
      await tester.pumpAndSettle();

      expect(_painterOf(tester).mPlotRight, before);
    });

    testWidgets('the newest candle rests against the gutter, not the edge', (
      tester,
    ) async {
      await tester.pumpWidget(_chart(priceAxisWidth: _gutter));
      final painter = _painterOf(tester);

      // Held at the right edge, the last candle sits at the end of the plot --
      // which is now the gutter's inner edge rather than the canvas edge.
      final newest = painter.translateXtoX(
        painter.getX(painter.mItemCount - 1),
      );
      expect(newest, lessThanOrEqualTo(_width - _gutter));

      // And it is the gutter that moved it, not a coincidence: with no gutter
      // the same candle rests a gutter's width further right.
      await tester.pumpWidget(_chart());
      final wide = _painterOf(tester);
      final newestWide = wide.translateXtoX(wide.getX(wide.mItemCount - 1));
      expect(newestWide - newest, closeTo(_gutter, 1.0));
    });

    testWidgets('the plot is clipped so nothing runs under the axis', (
      tester,
    ) async {
      await tester.pumpWidget(_chart(priceAxisWidth: _gutter));

      // Scrolled into history, so candles fill the window and would spill over
      // the axis were the plot not clipped.
      await tester.drag(find.byType(KChartWidget), const Offset(300, 0));
      await tester.pumpAndSettle();

      final probe = _GutterProbe(_width - _gutter);
      _painterOf(tester).paint(probe, const Size(_width, 600));

      expect(probe.clippedToPlot, isTrue, reason: 'the plot clip is pushed');
      expect(probe.spill, isEmpty, reason: 'and nothing escapes it');
    });

    testWidgets('without a gutter the plot is the whole canvas', (
      tester,
    ) async {
      await tester.pumpWidget(_chart());
      await tester.drag(find.byType(KChartWidget), const Offset(300, 0));
      await tester.pumpAndSettle();

      final probe = _GutterProbe(_width);
      _painterOf(tester).paint(probe, const Size(_width, 600));

      expect(probe.spill, isEmpty);
    });

    testWidgets('painting with a gutter draws without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(_chart(priceAxisWidth: _gutter));
      final painter = _painterOf(tester);

      final recorded = _record(painter);
      expect(recorded.canvas.totalDraws, greaterThan(0));
    });
  });

  group('coordinates round-trip through the gutter', () {
    testWidgets('a plot x maps back to itself', (tester) async {
      await tester.pumpWidget(
        _chart(priceAxisWidth: _gutter, alignment: VerticalTextAlignment.left),
      );
      final painter = _painterOf(tester);

      for (final x in <double>[_gutter, 200, 480]) {
        expect(
          painter.translateXtoX(painter.xToTranslateX(x)),
          closeTo(x, 0.001),
          reason: 'x=$x survives the round trip',
        );
      }
    });

    testWidgets('the visible range is measured across the plot', (
      tester,
    ) async {
      await tester.pumpWidget(_chart(priceAxisWidth: _gutter, count: 400));
      final withGutter = _painterOf(tester);
      final narrowed = withGutter.mStopIndex - withGutter.mStartIndex;

      await tester.pumpWidget(_chart(count: 400));
      final full = _painterOf(tester);
      final wide = full.mStopIndex - full.mStartIndex;

      expect(
        narrowed,
        lessThan(wide),
        reason: 'a narrower plot shows fewer candles',
      );
    });

    testWidgets('candle space starts at the plot, not the canvas', (
      tester,
    ) async {
      // The guard on the transform: candles are drawn through a translate, and
      // the crosshair and every drawing are placed through translateXtoX. If
      // the two disagree about where the plot begins, the crosshair drifts off
      // the candle it is reading.
      await tester.pumpWidget(
        _chart(priceAxisWidth: _gutter, alignment: VerticalTextAlignment.left),
      );
      final painter = _painterOf(tester);

      final probe = _GutterProbe(_width);
      painter.paint(probe, const Size(_width, 600));

      final expected = painter.mPlotLeft + painter.mTranslateX * painter.scaleX;
      expect(
        probe.translates.any((dx) => (dx - expected).abs() < 0.001),
        isTrue,
        reason: 'candle space is offset by the plot origin',
      );

      // And the two agree: candle 0 lands where the transform says.
      expect(
        painter.translateXtoX(painter.getX(0)),
        closeTo(expected + painter.getX(0) * painter.scaleX, 0.001),
      );
    });

    testWidgets('a long press reads the candle under the pointer', (
      tester,
    ) async {
      await tester.pumpWidget(_chart(priceAxisWidth: _gutter));
      final painter = _painterOf(tester);

      // The candle the transform puts at this x is the one picked out.
      const at = 300.0;
      final expected = painter.calculateSelectedX(at);
      final x = painter.translateXtoX(painter.getX(expected));

      expect(x, closeTo(at, painter.mPointWidth));
    });
  });
}
