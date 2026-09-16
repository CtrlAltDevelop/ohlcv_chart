import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

import 'test_utils.dart';

/// Candles that walk through [closes], each with a wick of [wick].
List<KLineEntity> _walk(List<double> closes, {double wick = 0}) {
  final out = <KLineEntity>[];
  var open = closes.first;
  for (final (i, close) in closes.indexed) {
    out.add(
      candle(
        close,
        open: open,
        high: (open > close ? open : close) + wick,
        low: (open < close ? open : close) - wick,
        minute: i,
      ),
    );
    open = close;
  }
  return out;
}

/// Draws [data] on a chart, to check the transform's output is drawable.
Widget _chart(List<KLineEntity> data) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 500,
          height: 600,
          child: KChartWidget(
            data,
            ChartColors(),
            isTrendLine: false,
            timeFrame: const Duration(minutes: 15),
          ),
        ),
      ),
    );

void main() {
  group('three-line break', () {
    test('a steady rise draws one block per new close', () {
      final blocks = CandleTransforms.lineBreak(
        _walk([100, 101, 102, 103, 104]),
      );

      expect(blocks, hasLength(4));
      // Contiguous: each block starts where the last one ended.
      expect(blocks.first.open, 100);
      expect(blocks.first.close, 101);
      expect(blocks[1].open, 101);
      expect(blocks.last.close, 104);
      expect(blocks.every((b) => b.close > b.open), isTrue);
    });

    test('a close inside the last block draws nothing', () {
      final blocks = CandleTransforms.lineBreak(
        _walk([100, 101, 102, 103, 102.5, 102.8]),
      );

      // The two closes back inside the run break nothing, so only the three
      // rises drew.
      expect(blocks, hasLength(3));
      expect(blocks.last.close, 103);
    });

    test('turning round takes a close under the whole run', () {
      final blocks = CandleTransforms.lineBreak(
        _walk([100, 101, 102, 103, 100.5]),
      );

      // 100.5 is above the lowest of the last three blocks (which is 100), so
      // it is not a reversal.
      expect(blocks, hasLength(3));

      final reversed = CandleTransforms.lineBreak(
        _walk([100, 101, 102, 103, 99]),
      );
      expect(reversed, hasLength(4));
      expect(reversed.last.close, 99);
      expect(reversed.last.close, lessThan(reversed.last.open));
    });

    test('the run it looks back over is configurable', () {
      // Over one line, a close under the last block alone turns it round.
      final blocks = CandleTransforms.lineBreak(
        _walk([100, 101, 102, 103, 101.5]),
        lines: 1,
      );

      expect(blocks.last.close, 101.5);
      expect(blocks.last.close, lessThan(blocks.last.open));
    });

    test('every block has a time of its own', () {
      final blocks = CandleTransforms.lineBreak(
        _walk([100, 101, 102, 103, 104]),
      );
      final times = blocks.map((b) => b.dateTime).toSet();

      expect(times, hasLength(blocks.length));
    });

    test('volume is carried across the candles a block covers', () {
      final data = _walk([100, 100, 100, 101]);
      final blocks = CandleTransforms.lineBreak(data);

      expect(blocks, hasLength(1));
      expect(blocks.single.vol, data.fold<double>(0, (a, c) => a + c.vol));
    });

    test('a flat market draws nothing, and nonsense draws nothing', () {
      expect(CandleTransforms.lineBreak(_walk([100, 100, 100])), isEmpty);
      expect(CandleTransforms.lineBreak(const []), isEmpty);
      expect(CandleTransforms.lineBreak(_walk([1, 2]), lines: 0), isEmpty);
    });

    testWidgets('the blocks draw on a chart', (tester) async {
      final blocks = CandleTransforms.lineBreak(_walk(rampThenFall(60)));
      DataUtil.calculate(blocks);

      await tester.pumpWidget(_chart(blocks));
      expect(tester.takeException(), isNull);
    });
  });

  group('Kagi', () {
    test('a trend is one segment however many bars it took', () {
      final segments = CandleTransforms.kagi(
        _walk([100, 101, 102, 103, 104, 100]),
        reversal: 3,
      );

      // Up to 104, then a fall of 4 turns it round: one segment, from where the
      // line started to the extreme it reached.
      expect(segments, hasLength(2));
      expect(segments.first.open, 100);
      expect(segments.first.close, 104);
      expect(segments.first.close, greaterThan(segments.first.open));
    });

    test('a retracement smaller than the reversal draws nothing new', () {
      final segments = CandleTransforms.kagi(
        _walk([100, 105, 104, 106]),
        reversal: 3,
      );

      // The dip of 1 is not a turn, so the line simply carries on to 106.
      expect(segments, hasLength(1));
      expect(segments.single.close, 106);
    });

    test('the reversal can be a percentage of the extreme', () {
      final segments = CandleTransforms.kagi(
        _walk([100, 110, 104]),
        reversal: 0.05,
        asPercent: true,
      );

      // 5% of 110 is 5.5, and the fall to 104 is 6, so it turns — leaving the
      // rise as one segment and the turn as the one still running.
      expect(segments, hasLength(2));
      expect(segments.first.close, 110);
      expect(segments.last.close, 104);

      final held = CandleTransforms.kagi(
        _walk([100, 110, 106]),
        reversal: 0.05,
        asPercent: true,
      );
      // A fall of 4 is not enough, so the segment still running is all there is.
      expect(held.single.close, 110);
    });

    test('the segment still running when the data ends is drawn', () {
      final segments = CandleTransforms.kagi(
        _walk([100, 110, 104, 112]),
        reversal: 3,
      );

      expect(segments, hasLength(3));
      expect(segments.last.close, 112);
      expect(segments.last.close, greaterThan(segments.last.open));
    });

    test('nothing at all draws nothing', () {
      expect(CandleTransforms.kagi(const [], reversal: 1), isEmpty);
      expect(CandleTransforms.kagi(_walk([1, 2]), reversal: 0), isEmpty);
      expect(CandleTransforms.kagi(_walk([100, 100]), reversal: 5), isEmpty);
    });

    testWidgets('the segments draw on a chart', (tester) async {
      final segments = CandleTransforms.kagi(
        _walk(rampThenFall(60)),
        reversal: 3,
      );
      DataUtil.calculate(segments);

      await tester.pumpWidget(_chart(segments));
      expect(tester.takeException(), isNull);
    });
  });

  group('point and figure', () {
    test('a rise files into boxes and draws one column', () {
      final columns = CandleTransforms.pointAndFigure(
        _walk([100, 102, 104, 106, 108]),
        boxSize: 2,
      );

      // One column, still running when the data ended.
      expect(columns, hasLength(1));
      expect(columns.single.close, greaterThan(columns.single.open));
      expect(columns.single.close, 108);
    });

    test('a move smaller than a box draws nothing', () {
      expect(
        CandleTransforms.pointAndFigure(
          _walk([100, 100.5, 100.9, 100.2]),
          boxSize: 2,
        ),
        isEmpty,
      );
    });

    test('a new column takes a reversal of the given boxes', () {
      final held = CandleTransforms.pointAndFigure(
        _walk([100, 110, 106]),
        boxSize: 2,
        reversalBoxes: 3,
      );
      // A fall of 4 is two boxes, which is not the three a reversal takes.
      expect(held, hasLength(1));

      final turned = CandleTransforms.pointAndFigure(
        _walk([100, 110, 102]),
        boxSize: 2,
        reversalBoxes: 3,
      );
      expect(turned, hasLength(2));
      expect(turned.first.close, greaterThan(turned.first.open));
      expect(turned.last.close, lessThan(turned.last.open));
    });

    test('columns sit on a grid, so the same data files the same way', () {
      final once = CandleTransforms.pointAndFigure(
        _walk([100, 110, 100, 112]),
        boxSize: 2,
      );
      final again = CandleTransforms.pointAndFigure(
        _walk([100, 110, 100, 112]),
        boxSize: 2,
      );

      expect(
        once.map((c) => (c.open, c.close)),
        again.map((c) => (c.open, c.close)),
      );
      // Every level is a whole number of boxes.
      for (final column in once) {
        expect(column.open % 2, closeTo(0, 1e-9));
        expect(column.close % 2, closeTo(0, 1e-9));
      }
    });

    test('it reads the highs and lows, not only the closes', () {
      // The closes never move, but the wicks travel a long way.
      final columns = CandleTransforms.pointAndFigure(
        _walk([100, 100, 100], wick: 10),
        boxSize: 2,
      );

      expect(columns, isNotEmpty);
    });

    test('nonsense draws nothing', () {
      expect(
        CandleTransforms.pointAndFigure(_walk([1, 2]), boxSize: 0),
        isEmpty,
      );
      expect(
        CandleTransforms.pointAndFigure(
          _walk([1, 2]),
          boxSize: 1,
          reversalBoxes: 0,
        ),
        isEmpty,
      );
      expect(CandleTransforms.pointAndFigure(const [], boxSize: 1), isEmpty);
    });

    testWidgets('the columns draw on a chart', (tester) async {
      final columns = CandleTransforms.pointAndFigure(
        _walk(rampThenFall(60)),
        boxSize: 2,
      );
      DataUtil.calculate(columns);

      await tester.pumpWidget(_chart(columns));
      expect(tester.takeException(), isNull);
    });
  });

  group('range bars', () {
    test('each bar covers the range it was given', () {
      final bars = CandleTransforms.rangeBars(
        _walk([100, 102, 104, 106, 108, 110]),
        range: 4,
      );

      expect(bars, isNotEmpty);
      for (final bar in bars) {
        expect((bar.close - bar.open).abs(), closeTo(4, 1e-9));
      }
      expect(bars.first.open, 100);
      expect(bars.first.close, 104);
    });

    test('a quiet market draws fewer bars than a busy one', () {
      final quiet = CandleTransforms.rangeBars(
        _walk([for (var i = 0; i < 20; i++) 100 + i * 0.1]),
        range: 4,
      );
      final busy = CandleTransforms.rangeBars(
        _walk([for (var i = 0; i < 20; i++) 100 + i * 2.0]),
        range: 4,
      );

      expect(busy.length, greaterThan(quiet.length));
    });

    test('a bar that fell reads as a down bar', () {
      final bars = CandleTransforms.rangeBars(_walk([100, 96, 92]), range: 4);

      expect(bars, isNotEmpty);
      expect(bars.first.close, lessThan(bars.first.open));
      expect(bars.first.close, 96);
    });

    test('one candle may carry price through several bars', () {
      // A single jump of 20, with a range of 4, is five bars' worth.
      final bars = CandleTransforms.rangeBars(_walk([100, 120]), range: 4);

      expect(bars.length, greaterThan(1));
      expect(bars.first.open, 100);
    });

    test('a bar is at least as tall as its range', () {
      final bars = CandleTransforms.rangeBars(
        _walk(rampThenFall(60), wick: 1),
        range: 4,
      );

      for (final bar in bars) {
        expect(bar.high - bar.low, greaterThanOrEqualTo(4 - 1e-9));
      }
    });

    test('every bar has a time of its own', () {
      final bars = CandleTransforms.rangeBars(_walk([100, 120]), range: 4);
      expect(bars.map((b) => b.dateTime).toSet(), hasLength(bars.length));
    });

    test('nonsense draws nothing', () {
      expect(CandleTransforms.rangeBars(_walk([1, 2]), range: 0), isEmpty);
      expect(CandleTransforms.rangeBars(const [], range: 1), isEmpty);
      expect(
        CandleTransforms.rangeBars(_walk([100, 100, 100]), range: 10),
        isEmpty,
      );
    });

    testWidgets('the bars draw on a chart', (tester) async {
      final bars = CandleTransforms.rangeBars(
        _walk(rampThenFall(60)),
        range: 4,
      );
      DataUtil.calculate(bars);

      await tester.pumpWidget(_chart(bars));
      expect(tester.takeException(), isNull);
    });
  });

  group('every transform leaves its input alone', () {
    test('the original candles are unchanged', () {
      final data = _walk(rampThenFall(40));
      final before = [
        for (final c in data) (c.open, c.high, c.low, c.close, c.dateTime),
      ];

      CandleTransforms.lineBreak(data);
      CandleTransforms.kagi(data, reversal: 2);
      CandleTransforms.pointAndFigure(data, boxSize: 2);
      CandleTransforms.rangeBars(data, range: 4);
      CandleTransforms.renko(data, brickSize: 2);
      CandleTransforms.heikinAshi(data);

      expect([
        for (final c in data) (c.open, c.high, c.low, c.close, c.dateTime),
      ], before);
    });
  });
}
