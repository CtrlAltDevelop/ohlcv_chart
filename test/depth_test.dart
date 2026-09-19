import 'dart:ui';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart/src/renderer/depth_painter.dart';
import 'package:ohlcv_chart/src/renderer/text_painter_cache.dart';

/// Raw rungs: 3 sizes a side, a mid of 100.
List<DepthEntity> rawBids() => [
  DepthEntity(99, 1),
  DepthEntity(98, 2),
  DepthEntity(97, 3),
];

List<DepthEntity> rawAsks() => [
  DepthEntity(101, 4),
  DepthEntity(102, 5),
  DepthEntity(103, 6),
];

/// Counts the geometry a painter puts on the canvas.
class Recorder implements Canvas {
  final List<Rect> rects = [];
  final List<Rect> paths = [];
  int lines = 0;
  int labels = 0;

  @override
  void drawRect(Rect rect, Paint paint) => rects.add(rect);
  @override
  void drawPath(Path path, Paint paint) => paths.add(path.getBounds());
  @override
  void drawLine(Offset a, Offset b, Paint paint) => lines++;
  @override
  void drawParagraph(Paragraph paragraph, Offset offset) => labels++;
  @override
  void noSuchMethod(Invocation invocation) {}
}

Recorder paintDepth({
  DepthChartMode mode = DepthChartMode.cumulative,
  DepthScale scale = DepthScale.linear,
  double? zoom,
}) {
  final painter = DepthChartPainter(
    DepthEntity.bids(rawBids()),
    DepthEntity.asks(rawAsks()),
    null,
    false,
    2,
    2,
    const DepthChartColors(),
    const DepthChartStyle(),
    const Offset(8, 0),
    const DepthChartTranslations(),
    textCache: TextPainterCache(capacity: 64),
    mode: mode,
    scale: scale,
    zoom: zoom,
  );
  final recorder = Recorder();
  painter.paint(recorder, const Size(400, 300));
  return recorder;
}

void main() {
  group('DepthBook', () {
    test('recovers each rung size from the cumulative curves', () {
      final book = DepthBook.fromCurves(
        DepthEntity.bids(rawBids()),
        DepthEntity.asks(rawAsks()),
      );

      // Bids ascend by price, so the best bid is last.
      expect(book.bids.map((l) => l.price), [97, 98, 99]);
      expect(book.bids.map((l) => l.size), [3, 2, 1]);
      expect(book.bids.map((l) => l.cumulative), [6, 3, 1]);

      expect(book.asks.map((l) => l.price), [101, 102, 103]);
      expect(book.asks.map((l) => l.size), [4, 5, 6]);
      expect(book.asks.map((l) => l.cumulative), [4, 9, 15]);
    });

    test('reports the mid, the deepest total and the biggest rung', () {
      final book = DepthBook.fromCurves(
        DepthEntity.bids(rawBids()),
        DepthEntity.asks(rawAsks()),
      );

      expect(book.mid, 100);
      expect(book.maxCumulative, 15);
      expect(book.maxSize, 6);
      expect(book.isEmpty, isFalse);
    });

    test('zoom keeps only the levels near the mid', () {
      final book = DepthBook.fromCurves(
        DepthEntity.bids(rawBids()),
        DepthEntity.asks(rawAsks()),
        // Two percent of a mid of 100 reaches 98 and 102.
        zoom: 0.02,
      );

      expect(book.bids.map((l) => l.price), [98, 99]);
      expect(book.asks.map((l) => l.price), [101, 102]);
    });

    test('a zoom that would empty the book falls back to all of it', () {
      final book = DepthBook.fromCurves(
        DepthEntity.bids(rawBids()),
        DepthEntity.asks(rawAsks()),
        zoom: 0.0001,
      );

      expect(book.bids, hasLength(3));
      expect(book.asks, hasLength(3));
    });

    test('an empty side is empty, not a crash', () {
      final book = DepthBook.fromCurves(const [], const []);
      expect(book.isEmpty, isTrue);
      expect(book.mid, 0);
      expect(book.maxCumulative, 0);
    });
  });

  group('depth chart modes', () {
    test('cumulative draws curves and no bars', () {
      final drawn = paintDepth();
      // Two filled curves, and a stroke between each pair of points.
      expect(drawn.paths, hasLength(2));
      expect(drawn.lines, greaterThan(0));
      // The only rectangles a cumulative chart draws are none at all.
      expect(drawn.rects, isEmpty);
    });

    test('histogram draws one bar per level and no curve', () {
      final drawn = paintDepth(mode: DepthChartMode.histogram);

      expect(drawn.rects, hasLength(6), reason: 'three levels a side');
      expect(drawn.paths, isEmpty);
      expect(drawn.lines, 0);
    });

    test('combined draws both', () {
      final drawn = paintDepth(mode: DepthChartMode.combined);

      expect(drawn.rects, hasLength(6));
      expect(drawn.paths, hasLength(2));
      expect(drawn.lines, greaterThan(0));
    });

    test('the biggest bar reaches the top of a histogram', () {
      final drawn = paintDepth(mode: DepthChartMode.histogram);
      final tallest = drawn.rects.reduce((a, b) => a.top < b.top ? a : b);

      // The 6-unit ask rung is the biggest, so it fills the height.
      expect(tallest.top, closeTo(0, 0.001));
      // Bars stand on the baseline, above the bottom labels.
      expect(tallest.bottom, closeTo(290, 0.001));
    });

    test('bars are scaled to the biggest rung, not the deepest total', () {
      final histogram = paintDepth(mode: DepthChartMode.histogram);
      final combined = paintDepth(mode: DepthChartMode.combined);

      double heightOf(List<Rect> rects) =>
          rects.map((r) => r.height).reduce((a, b) => a > b ? a : b);

      // Alone, the tallest bar fills the chart; under the curves it is
      // measured against the running total instead, so it is shorter.
      expect(heightOf(histogram.rects), greaterThan(heightOf(combined.rects)));
    });
  });

  group('depth scales', () {
    test('a log axis lifts the small end of the book', () {
      final linear = paintDepth(mode: DepthChartMode.histogram);
      final logarithmic = paintDepth(
        mode: DepthChartMode.histogram,
        scale: DepthScale.log,
      );

      // The smallest rung is 1 of 6: a sixth of the height linearly, but
      // log(2)/log(7) — nearly two fifths — on a log axis.
      double shortest(List<Rect> rects) =>
          rects.map((r) => r.height).reduce((a, b) => a < b ? a : b);

      expect(shortest(logarithmic.rects), greaterThan(shortest(linear.rects)));
    });

    test('percent lays out exactly like linear', () {
      final linear = paintDepth(mode: DepthChartMode.histogram);
      final percent = paintDepth(
        mode: DepthChartMode.histogram,
        scale: DepthScale.percent,
      );

      expect(percent.rects, linear.rects);
    });

    test('zoom redraws the curves from what is left', () {
      final all = paintDepth(mode: DepthChartMode.histogram);
      final near = paintDepth(mode: DepthChartMode.histogram, zoom: 0.02);

      expect(all.rects, hasLength(6));
      expect(near.rects, hasLength(4));
    });
  });

  group('DepthLadder', () {
    Widget host(Widget child) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 320, height: 600, child: child)),
    );

    testWidgets('lists both sides outwards from the spread', (tester) async {
      await tester.pumpWidget(
        host(
          DepthLadder(
            DepthEntity.bids(rawBids()),
            DepthEntity.asks(rawAsks()),
            quoteUnit: 0,
            baseUnit: 0,
          ),
        ),
      );

      expect(find.text('Price'), findsOneWidget);
      expect(find.text('Size'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);

      // Every level of both sides, with the mid and the spread between them.
      for (final price in ['97', '98', '99', '101', '102', '103']) {
        expect(find.text(price), findsOneWidget, reason: price);
      }
      expect(find.text('100'), findsOneWidget);
      expect(find.textContaining('Spread 2'), findsOneWidget);
    });

    testWidgets('the asks sit above the bids', (tester) async {
      await tester.pumpWidget(
        host(
          DepthLadder(
            DepthEntity.bids(rawBids()),
            DepthEntity.asks(rawAsks()),
            quoteUnit: 0,
            baseUnit: 0,
          ),
        ),
      );

      final bestAsk = tester.getCenter(find.text('101')).dy;
      final bestBid = tester.getCenter(find.text('99')).dy;
      final worstAsk = tester.getCenter(find.text('103')).dy;

      expect(worstAsk, lessThan(bestAsk));
      expect(bestAsk, lessThan(bestBid));
    });

    testWidgets('shows only as many levels as asked for', (tester) async {
      await tester.pumpWidget(
        host(
          DepthLadder(
            DepthEntity.bids(rawBids()),
            DepthEntity.asks(rawAsks()),
            levels: 1,
            quoteUnit: 0,
            baseUnit: 0,
          ),
        ),
      );

      expect(find.text('99'), findsOneWidget);
      expect(find.text('101'), findsOneWidget);
      expect(find.text('97'), findsNothing);
      expect(find.text('103'), findsNothing);
    });

    testWidgets('reads correctly with no Material ancestor', (tester) async {
      // An app with no Scaffold or Material in scope leaves the debug error
      // style — red, double-underlined in yellow — as the ambient default, and
      // a Text merges onto it. The ladder has to anchor its own.
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 320,
            height: 600,
            child: DepthLadder(
              DepthEntity.bids(rawBids()),
              DepthEntity.asks(rawAsks()),
              quoteUnit: 0,
              baseUnit: 0,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final size = tester.widget<Text>(find.text('Size'));
      final resolved = DefaultTextStyle.of(
        tester.element(find.text('Size')),
      ).style.merge(size.style);
      expect(resolved.decoration ?? TextDecoration.none, TextDecoration.none);
      expect(resolved.fontSize, const DepthChartStyle().ladderFontSize);
    });

    testWidgets('an empty book renders nothing at all', (tester) async {
      await tester.pumpWidget(
        host(const DepthLadder(<DepthEntity>[], <DepthEntity>[])),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Price'), findsNothing);
    });

    testWidgets('the chart hands over to the ladder in that mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          DepthChart(
            DepthEntity.bids(rawBids()),
            DepthEntity.asks(rawAsks()),
            mode: DepthChartMode.ladder,
            quoteUnit: 0,
            baseUnit: 0,
          ),
        ),
      );

      expect(find.byType(DepthLadder), findsOneWidget);
      expect(find.text('101'), findsOneWidget);
    });
  });

  group('DepthRatioBar', () {
    Widget host(Widget child) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 320, height: 600, child: child)),
    );

    /// The two halves of the bar, in the order they are drawn.
    List<Size> halves(WidgetTester tester) => [
      for (var i = 0; i < 2; i++)
        tester.getSize(
          find
              .descendant(
                of: find.byType(DepthRatioBar),
                matching: find.byType(Container),
              )
              .at(i),
        ),
    ];

    testWidgets('names each side its share of the book', (tester) async {
      await tester.pumpWidget(
        host(
          DepthRatioBar(
            DepthEntity.bids(rawBids()),
            DepthEntity.asks(rawAsks()),
          ),
        ),
      );

      // 6 resting on the bids against 15 on the asks.
      expect(find.text('28.57%'), findsOneWidget);
      expect(find.text('71.43%'), findsOneWidget);
    });

    testWidgets('draws each side in proportion to its volume', (tester) async {
      await tester.pumpWidget(
        host(
          DepthRatioBar(
            DepthEntity.bids(rawBids()),
            DepthEntity.asks(rawAsks()),
          ),
        ),
      );

      final [bid, ask] = halves(tester);
      // Both ends keep a pill's width whatever they hold, so the proportion is
      // of what is left over once each side has been given one.
      const least = 4.0;
      expect(bid.width, lessThan(ask.width));
      expect((bid.width - least) / (ask.width - least), closeTo(6 / 15, 0.01));
      expect(bid.height, least);
    });

    testWidgets('weighs only the levels a zoom leaves', (tester) async {
      await tester.pumpWidget(
        host(
          DepthRatioBar(
            DepthEntity.bids(rawBids()),
            DepthEntity.asks(rawAsks()),
            // Tight enough to leave the best rung a side: 1 against 4.
            zoom: 0.015,
          ),
        ),
      );

      expect(find.text('20.00%'), findsOneWidget);
      expect(find.text('80.00%'), findsOneWidget);
    });

    testWidgets('holds its place while the book is empty', (tester) async {
      await tester.pumpWidget(
        host(const DepthRatioBar(<DepthEntity>[], <DepthEntity>[])),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('--'), findsNWidgets(2));
      final [bid, ask] = halves(tester);
      expect(bid.width, closeTo(ask.width, 0.01));
    });

    testWidgets('slides to a new split rather than jumping', (tester) async {
      Widget bar(List<DepthEntity> bids) => host(
        DepthRatioBar(DepthEntity.bids(bids), DepthEntity.asks(rawAsks())),
      );

      await tester.pumpWidget(bar(rawBids()));
      final before = halves(tester).first.width;

      // Ten times the bids: the split ends up the other way round.
      await tester.pumpWidget(
        bar([DepthEntity(99, 10), DepthEntity(98, 20), DepthEntity(97, 30)]),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final midway = halves(tester).first.width;

      await tester.pump(const Duration(milliseconds: 400));
      final after = halves(tester).first.width;

      expect(midway, greaterThan(before));
      expect(midway, lessThan(after));
      expect(find.text('80.00%'), findsOneWidget);
    });

    testWidgets('the ladder closes off with one when asked', (tester) async {
      await tester.pumpWidget(
        host(
          DepthLadder(
            DepthEntity.bids(rawBids()),
            DepthEntity.asks(rawAsks()),
            quoteUnit: 0,
            baseUnit: 0,
            showRatioBar: true,
          ),
        ),
      );

      expect(find.byType(DepthRatioBar), findsOneWidget);
      // Under the last of the bids.
      expect(
        tester.getCenter(find.text('28.57%')).dy,
        greaterThan(tester.getCenter(find.text('97')).dy),
      );
    });

    testWidgets('the ladder leaves it off by default', (tester) async {
      await tester.pumpWidget(
        host(
          DepthLadder(
            DepthEntity.bids(rawBids()),
            DepthEntity.asks(rawAsks()),
            quoteUnit: 0,
            baseUnit: 0,
          ),
        ),
      );

      expect(find.byType(DepthRatioBar), findsNothing);
    });
  });

  group('the chart renders every mode', () {
    for (final mode in DepthChartMode.values) {
      testWidgets(mode.name, (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 400,
                child: DepthChart(
                  DepthEntity.bids(rawBids()),
                  DepthEntity.asks(rawAsks()),
                  mode: mode,
                  scale: DepthScale.log,
                  zoom: 0.05,
                  showRatioBar: true,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the ratio bar survives an unbounded height', (tester) async {
      // The painted chart falls back to 200 tall when it is given no height of
      // its own, and flexing it under the bar would break that.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 400,
                child: DepthChart(
                  DepthEntity.bids(rawBids()),
                  DepthEntity.asks(rawAsks()),
                  showRatioBar: true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(DepthRatioBar), findsOneWidget);
      expect(tester.getSize(find.byType(CustomPaint).last).height, 200);
    });
  });
}
