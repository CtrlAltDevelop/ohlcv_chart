import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart/src/renderer/chart_painter.dart';

import 'test_utils.dart';

const double _width = 500;
const double _height = 600;
const double _gutter = 60;

ChartPainter _painterOf(WidgetTester tester) {
  final dynamic state = tester.state(find.byType(KChartWidget));
  // ignore: avoid_dynamic_calls
  return state.painter as ChartPainter;
}

/// The y of every horizontal line drawn.
class _Lines implements Canvas {
  final List<double> ys = [];

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    if ((p1.dy - p2.dy).abs() < 0.5) ys.add(p1.dy);
  }

  @override
  void noSuchMethod(Invocation invocation) {}
}

/// Where each run of text was painted.
class _Text implements Canvas {
  final List<Offset> at = [];

  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) => at.add(offset);

  @override
  void noSuchMethod(Invocation invocation) {}
}

Widget _chart({
  PriceAxisScale? second,
  VerticalTextAlignment alignment = VerticalTextAlignment.right,
  double priceAxisWidth = _gutter,
  double secondaryWidth = _gutter,
}) {
  final data = candles(rampThenFall(120));
  DataUtil.calculate(data);

  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: _width,
        height: _height,
        child: KChartWidget(
          data,
          ChartColors(),
          isTrendLine: false,
          timeFrame: const Duration(minutes: 15),
          showNowPrice: false,
          verticalTextAlignment: alignment,
          secondaryPriceAxisScale: second,
          chartStyle: ChartStyle(
            priceAxisWidth: priceAxisWidth,
            secondaryPriceAxisWidth: secondaryWidth,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('a second price axis', () {
    testWidgets('is not there unless it is asked for', (tester) async {
      await tester.pumpWidget(_chart());
      final painter = _painterOf(tester);

      expect(painter.secondaryAxisGutter, 0);
      expect(painter.mWidth, _width - _gutter);
      expect(painter.mPlotLeft, 0);
    });

    testWidgets('takes the side the price axis left free', (tester) async {
      await tester.pumpWidget(_chart(second: PriceAxisScale.percentage));
      final painter = _painterOf(tester);

      expect(painter.secondaryAxisGutter, _gutter);
      expect(painter.mWidth, _width - _gutter * 2);
      expect(painter.mPlotLeft, _gutter, reason: 'prices on the right');
      expect(painter.mMainRect.left, _gutter);
      expect(painter.mMainRect.right, _width - _gutter);
    });

    testWidgets('and swaps sides with the price axis', (tester) async {
      await tester.pumpWidget(
        _chart(
          second: PriceAxisScale.percentage,
          alignment: VerticalTextAlignment.left,
        ),
      );
      final painter = _painterOf(tester);

      // Prices on the left now, so the second axis holds the right.
      expect(painter.mPlotLeft, _gutter);
      expect(painter.mMainRect.right, _width - _gutter);
    });

    testWidgets('the panes below stop at it too', (tester) async {
      await tester.pumpWidget(_chart(second: PriceAxisScale.percentage));
      final painter = _painterOf(tester);

      expect(painter.mVolRect?.left, _gutter);
      expect(painter.mVolRect?.right, _width - _gutter);
    });

    testWidgets('marks its own round values, not the price axis\'s', (
      tester,
    ) async {
      await tester.pumpWidget(_chart(second: PriceAxisScale.percentage));
      final renderer = _painterOf(tester).mMainRenderer;

      final labels = [
        for (final tick in renderer.ticksFor(PriceAxisScale.percentage, 8))
          renderer.formatAxisAs(PriceAxisScale.percentage, tick),
      ];

      expect(labels, isNotEmpty);
      expect(labels.every((l) => l.endsWith('%')), isTrue);
      // Round percentages: two decimals that are always zero.
      expect(
        labels.every((l) => l.contains('.00%')),
        isTrue,
        reason: '$labels',
      );
    });

    testWidgets('writes its labels in its own gutter', (tester) async {
      await tester.pumpWidget(_chart(second: PriceAxisScale.percentage));
      final painter = _painterOf(tester);

      final probe = _Text();
      painter.paint(probe, const Size(_width, _height));

      expect(
        probe.at.where((o) => o.dx < painter.mPlotLeft),
        isNotEmpty,
        reason: 'the second axis writes in the gutter it was given',
      );
    });

    testWidgets('leaves the grid to the price axis', (tester) async {
      await tester.pumpWidget(_chart(second: PriceAxisScale.percentage));
      final renderer = _painterOf(tester).mMainRenderer;

      final probe = _Lines();
      renderer.drawGrid(probe, 8, 4);

      // The rows are ruled at the round prices, not at the round percentages
      // the second axis marks — one set of lines, the one the prices agree
      // with.
      final rows = probe.ys
          .where((y) => y >= renderer.chartRect.top - 0.5)
          .toSet();
      for (final tick in renderer.priceTicks(8)) {
        final y = renderer.getY(tick);
        if (y < renderer.chartRect.top || y > renderer.chartRect.bottom) {
          continue;
        }
        expect(
          rows.any((r) => (r - y).abs() < 0.5),
          isTrue,
          reason: 'no grid line at the round price $tick',
        );
      }
    });

    testWidgets('the crosshair still reads the price axis', (tester) async {
      await tester.pumpWidget(_chart(second: PriceAxisScale.percentage));
      final renderer = _painterOf(tester).mMainRenderer;

      // The second axis is an axis, not a second voice for the readouts.
      expect(renderer.formatAxis(123.456), '123.46');
    });
  });
}
