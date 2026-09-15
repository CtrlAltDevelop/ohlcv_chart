import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

const _points = [
  OpenInterestPoint(time: 1, openInterest: 100, funding: 0.0001, price: 60000),
  OpenInterestPoint(time: 2, openInterest: 140, funding: 0.0003, price: 62000),
  OpenInterestPoint(time: 3, openInterest: 120, funding: -0.0002, price: 61000),
  OpenInterestPoint(time: 4, openInterest: 160, funding: 0.0001, price: 59000),
];

void main() {
  group('the moves', () {
    test('the four cases are read off price and interest together', () {
      final moves = openInterestMoves(_points);
      expect(moves[0], OpenInterestMove.flat); // nothing before it
      expect(moves[1], OpenInterestMove.newLongs); // both up
      expect(moves[2], OpenInterestMove.longsClosing); // both down
      expect(moves[3], OpenInterestMove.newShorts); // price down, OI up
    });

    test('shorts covering is price up on falling interest', () {
      final moves = openInterestMoves(const [
        OpenInterestPoint(time: 1, openInterest: 100, price: 10),
        OpenInterestPoint(time: 2, openInterest: 80, price: 12),
      ]);
      expect(moves[1], OpenInterestMove.shortsCovering);
    });

    test('a missing price, or no move at all, is flat', () {
      final moves = openInterestMoves(const [
        OpenInterestPoint(time: 1, openInterest: 100),
        OpenInterestPoint(time: 2, openInterest: 120),
        OpenInterestPoint(time: 3, openInterest: 120, price: 10),
      ]);
      expect(moves[1], OpenInterestMove.flat);
      expect(moves[2], OpenInterestMove.flat);
    });

    test('every move has a name', () {
      for (final move in OpenInterestMove.values) {
        expect(moveLabel(move), isNotEmpty);
      }
    });
  });

  group('the layout', () {
    test('the funding panel takes its share off the bottom', () {
      final layout = layOutOpenInterest(
        _points,
        size: const Size(400, 200),
        fundingShare: 0.25,
        panelGap: 8,
      );
      expect(layout.fundingRect.height, closeTo(48, 1e-9));
      expect(layout.interestRect.height, closeTo(144, 1e-9));
      expect(layout.fundingRect.top, closeTo(152, 1e-9));
    });

    test('open interest is scaled to its own range, not down to zero', () {
      final layout =
          layOutOpenInterest(_points, size: const Size(400, 200));
      expect(layout.interestMin, 100);
      expect(layout.interestMax, 160);
      expect(
        layout.interestPoints.first!.dy,
        closeTo(layout.interestRect.bottom, 1e-9),
      );
      expect(
        layout.interestPoints.last!.dy,
        closeTo(layout.interestRect.top, 1e-9),
      );
    });

    test('price has its own scale over the same panel', () {
      final layout =
          layOutOpenInterest(_points, size: const Size(400, 200));
      expect(layout.priceMin, 59000);
      expect(layout.priceMax, 62000);
      expect(
        layout.pricePoints[1]!.dy,
        closeTo(layout.interestRect.top, 1e-9),
      );
    });

    test('funding bars hang off the zero line, either way', () {
      final layout = layOutOpenInterest(
        _points,
        size: const Size(400, 200),
        axisWidth: 0,
      );
      expect(layout.fundingMax, closeTo(0.0003, 1e-12));
      // Longs paying rises above zero; shorts paying hangs below it.
      expect(layout.fundingBars[1]!.bottom, closeTo(layout.zeroY, 1e-9));
      expect(layout.fundingBars[1]!.top, lessThan(layout.zeroY));
      expect(layout.fundingBars[2]!.top, closeTo(layout.zeroY, 1e-9));
      expect(layout.fundingBars[2]!.bottom, greaterThan(layout.zeroY));
      // The largest rate fills half the panel.
      expect(
        layout.fundingBars[1]!.height,
        closeTo(layout.fundingRect.height / 2, 1e-9),
      );
    });

    test('a reading with no funding gets no bar', () {
      final layout = layOutOpenInterest(
        const [OpenInterestPoint(time: 1, openInterest: 10)],
        size: const Size(400, 200),
      );
      expect(layout.fundingBars.single, isNull);
    });

    test('a given funding scale pins the bars', () {
      final layout = layOutOpenInterest(
        _points,
        size: const Size(400, 200),
        fundingMax: 0.0006,
      );
      expect(
        layout.fundingBars[1]!.height,
        closeTo(layout.fundingRect.height / 4, 1e-9),
      );
    });

    test('progress reveals the readings left to right', () {
      final layout = layOutOpenInterest(
        _points,
        size: const Size(400, 200),
        progress: 0.5,
      );
      expect(layout.interestPoints.first, isNotNull);
      expect(layout.interestPoints.last, isNull);
      expect(layout.fundingBars.last, isNull);
    });

    test('nothing to show lays out nothing', () {
      expect(
        layOutOpenInterest(const [], size: const Size(400, 200)).isEmpty,
        true,
      );
      expect(layOutOpenInterest(_points, size: Size.zero).isEmpty, true);
      expect(
        layOutOpenInterest(
          const [OpenInterestPoint(time: 1, openInterest: double.nan)],
          size: const Size(400, 200),
        ).isEmpty,
        true,
      );
    });

    test('a point finds the reading nearest it', () {
      final layout = layOutOpenInterest(
        _points,
        size: const Size(400, 200),
        axisWidth: 0,
      );
      expect(layout.indexAt(layout.columnX.first - 30), 0);
      expect(layout.indexAt(layout.columnX.last + 30), 3);
    });
  });

  group('the widget', () {
    testWidgets('draws and reports the reading under the finger',
        (tester) async {
      OpenInterestPoint? touched;
      OpenInterestMove? move;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 200,
              child: OpenInterestChart(
                points: _points,
                onTouch: (point, what) {
                  touched = point ?? touched;
                  move = what ?? move;
                },
              ),
            ),
          ),
        ),
      );
      expect(find.byType(OpenInterestChart), findsOneWidget);

      final box = tester.getRect(find.byType(OpenInterestChart));
      final gesture =
          await tester.startGesture(Offset(box.left + 1, box.center.dy));
      await tester.pump();
      expect(touched?.openInterest, 100);
      expect(move, OpenInterestMove.flat);
      await gesture.up();
      await tester.pump();
    });

    testWidgets('takes its default height in an unbounded box',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OpenInterestChart(points: _points, defaultHeight: 180),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(OpenInterestChart)).height, 180);
    });

    testWidgets('draws the lines in over time', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 200,
              child: OpenInterestChart(
                points: _points,
                animationDuration: Duration(milliseconds: 200),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
