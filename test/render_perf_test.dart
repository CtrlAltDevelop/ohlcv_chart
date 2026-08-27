import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart/src/renderer/chart_painter.dart';

import 'counting_canvas.dart';

/// What the chart costs to draw, in the units that actually move a frame
/// budget: draw calls issued, text laid out, and candles scanned.
///
/// These are counts rather than times, so the numbers mean the same thing on a
/// loaded CI machine as on an idle laptop. The bounds are deliberately generous
/// — they are there to catch a regression back to per-candle drawing, not to
/// pin the renderer to an exact call count.

/// A deterministic walk, the same shape the goldens use.
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

const Size _size = Size(800, 600);

Widget _chart(
  List<KLineEntity> data, {
  ChartType type = ChartType.candles,
  List<Indicator> indicators = const [],
  List<ChartLine> drawings = const [],
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: _size.width,
        height: _size.height,
        child: KChartWidget(
          data,
          ChartColors(),
          isTrendLine: false,
          watermarkAssetPath: 'assets/none.svg',
          timeFrame: const Duration(minutes: 15),
          chartType: type,
          indicators: indicators,
          drawings: drawings,
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

/// Paints [painter] through a tallying canvas and hands back the tally.
CountingCanvas _measure(ChartPainter painter) {
  final recorder = ui.PictureRecorder();
  final canvas = CountingCanvas(Canvas(recorder));
  painter.paint(canvas, _size);
  recorder.endRecording().dispose();
  return canvas;
}

void main() {
  group('draw calls per frame', () {
    /// Paints [painter] at two zoom levels and reports what each cost.
    ///
    /// Widening the window is the test that matters: a renderer that draws a
    /// piece per candle spends proportionally more on a wider window, and a
    /// batched one spends the same. Measuring the growth rather than an
    /// absolute count also keeps the grid and the dashed price line — which
    /// scale with the canvas, not the data — out of the answer.
    ({int candles, int draws}) at(ChartPainter painter, double scaleX) {
      painter.scaleX = scaleX;
      final tally = _measure(painter);
      return (
        candles: painter.mStopIndex - painter.mStartIndex + 1,
        draws: tally['drawPath'] + tally['drawLine'] + tally['drawRect'],
      );
    }

    // What one more candle in the window is allowed to cost, by chart type.
    //
    // A candle body and an OHLC bar are rectangles, one per candle, and stay
    // that way — a rectangle is cheap and batching them into a path would
    // change how they blend. Everything a chart draws as a *series* is
    // collected and drawn once, so those types pay only for the volume bar
    // beside them.
    const budget = <ChartType, int>{
      // Wick, body, volume bar.
      ChartType.candles: 3,
      // High-low bar, the open tick, the close tick, volume bar.
      ChartType.bars: 4,
      // The column and its volume bar.
      ChartType.columns: 2,
      // The series is one path; only the volume bar is per candle.
      ChartType.line: 1,
      ChartType.area: 1,
      ChartType.baseline: 1,
      ChartType.stepLine: 1,
      ChartType.hlcArea: 1,
    };

    for (final type in ChartType.values) {
      testWidgets('$type costs at most ${budget[type]} draws per candle', (
        tester,
      ) async {
        await tester.pumpWidget(_chart(_market(), type: type));
        await tester.pumpAndSettle();

        final painter = _painterOf(tester);
        final narrow = at(painter, 1.0);
        final wide = at(painter, 0.25);

        expect(
          wide.candles,
          greaterThan(narrow.candles * 2),
          reason: 'the window did not widen',
        );

        // Measured as growth, so the grid and the dashed price line — which
        // scale with the canvas rather than the data — stay out of the answer.
        final extraCandles = wide.candles - narrow.candles;
        final extraDraws = wide.draws - narrow.draws;
        final perCandle = extraDraws / extraCandles;

        // The allowance is for the axis furniture, which grows a little with
        // the window — a few more date ticks. It is far below the one draw per
        // candle a renderer that had stopped batching would add.
        expect(
          perCandle,
          lessThanOrEqualTo(budget[type]! + 0.25),
          reason:
              '$type spent ${perCandle.toStringAsFixed(2)} draw calls per '
              'candle ($extraDraws more for $extraCandles more candles, '
              '${narrow.draws} -> ${wide.draws})',
        );
      });
    }

    testWidgets('the volume moving averages are stroked once, not per segment', (
      tester,
    ) async {
      await tester.pumpWidget(_chart(_market()));
      await tester.pumpAndSettle();

      final painter = _painterOf(tester);
      painter.scaleX = 1.0;
      final narrow = _measure(painter)['drawLine'];
      final narrowCandles = painter.mStopIndex - painter.mStartIndex + 1;

      painter.scaleX = 0.25;
      final wide = _measure(painter)['drawLine'];
      final wideCandles = painter.mStopIndex - painter.mStartIndex + 1;

      // Two averages drawn per segment would add two strokes per extra candle.
      expect(
        wide - narrow,
        lessThan(wideCandles - narrowCandles),
        reason: 'drawLine grew from $narrow to $wide over the wider window',
      );
    });
  });

  group('text layout', () {
    testWidgets('a second identical paint lays out no new text', (
      tester,
    ) async {
      await tester.pumpWidget(_chart(_market()));
      await tester.pumpAndSettle();

      final painter = _painterOf(tester);
      _measure(painter);
      final first = painter.textLayouts;
      _measure(painter);
      final second = painter.textLayouts;

      expect(first, greaterThan(0), reason: 'no text was drawn at all');
      expect(
        second - first,
        lessThan(first ~/ 4),
        reason: 'repainting the same chart re-laid-out ${second - first} labels',
      );
    });
  });

  group('large history', () {
    testWidgets('paint does not scan the whole series per drawing', (
      tester,
    ) async {
      final data = _market(count: 20000);
      final at = data[15000].dateTime!;
      final drawings = <ChartLine>[
        for (var i = 0; i < 20; i++)
          HorizontalLine(price: 100.0 + i, startTime: at),
      ];

      await tester.pumpWidget(_chart(data, drawings: drawings));
      await tester.pumpAndSettle();

      final painter = _painterOf(tester);
      final index = painter.candleIndex;
      final before = index.scans;
      _measure(painter);
      final scanned = index.scans - before;
      final lookups = index.lookups;

      expect(lookups, greaterThan(20), reason: 'no anchors were resolved');
      // Twenty drawings looking up their anchor must not mean twenty walks of
      // twenty thousand candles. The lookup is already built by the time the
      // chart has painted once, so a repaint should walk nothing at all.
      expect(
        scanned,
        lessThan(data.length),
        reason: 'anchor lookups walked $scanned candles over $lookups lookups',
      );
    });
  });

  group('hovering', () {
    testWidgets('redraws the crosshair and leaves the chart alone', (
      tester,
    ) async {
      await tester.pumpWidget(_chart(_market()));
      await tester.pumpAndSettle();

      final painter = _painterOf(tester);
      final chartBefore = painter.chartPaints;
      final overlayBefore = painter.overlayPaints;
      final centre = tester.getCenter(find.byType(KChartWidget));

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);

      for (var step = 0; step < 5; step++) {
        await mouse.moveTo(centre + Offset(step * 7.0, 0));
        await tester.pump();
      }

      expect(
        painter.overlayPaints,
        greaterThan(overlayBefore),
        reason: 'the crosshair did not redraw',
      );
      expect(
        painter.chartPaints,
        chartBefore,
        reason:
            'moving the pointer redrew the chart '
            '${painter.chartPaints - chartBefore} times',
      );
      // The same painter throughout: a rebuild would have replaced it, and
      // taken every candle with it.
      expect(identical(_painterOf(tester), painter), isTrue);
    });
  });
}
