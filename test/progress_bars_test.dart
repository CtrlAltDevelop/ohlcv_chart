import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

const _items = [
  ProgressItem(label: 'Profit', value: 72, target: 60),
  ProgressItem(label: 'Trades', value: 150, total: 100),
  ProgressItem(label: 'Drawdown', value: 0),
];

void main() {
  progressCardTests();
  group('an item', () {
    test('fills to its share of the total, and no further', () {
      expect(_items[0].fraction, closeTo(0.72, 1e-9));
      expect(_items[1].fraction, 1);
      expect(_items[2].fraction, 0);
    });

    test('a total that cannot be divided by fills nothing', () {
      expect(const ProgressItem(label: 'x', value: 5, total: 0).fraction, 0);
      expect(const ProgressItem(label: 'x', value: double.nan).fraction, 0);
    });

    test('the target sits on the same scale as the value', () {
      expect(_items[0].targetFraction, closeTo(0.6, 1e-9));
      expect(_items[2].targetFraction, isNull);
    });
  });

  group('the layout', () {
    test('a row is a header, a gap and a bar, stacked with a gap between', () {
      final layout = layOutProgress(
        _items,
        size: const Size(300, 400),
        barHeight: 10,
        headerHeight: 18,
        headerGap: 6,
        rowGap: 16,
      );
      expect(layout.rows, hasLength(3));
      final first = layout.rows[0];
      expect(first.headerRect.height, 18);
      expect(first.trackRect.top, 24);
      expect(first.trackRect.height, 10);
      expect(layout.rows[1].rowRect.top, 50);
    });

    test('the fill runs from the left edge by the share done', () {
      final layout = layOutProgress(_items, size: const Size(300, 400));
      final row = layout.rows.first;
      expect(row.fillRect.left, row.trackRect.left);
      expect(row.fillRect.width, closeTo(300 * 0.72, 1e-6));
      expect(row.targetX, closeTo(300 * 0.6, 1e-6));
    });

    test('progress shortens the fills but leaves the targets alone', () {
      final half = layOutProgress(
        _items,
        size: const Size(300, 400),
        progress: 0.5,
      );
      final full = layOutProgress(_items, size: const Size(300, 400));
      expect(
        half.rows.first.fillRect.width,
        closeTo(full.rows.first.fillRect.width / 2, 1e-6),
      );
      expect(half.rows.first.targetX, full.rows.first.targetX);
    });

    test('rows shrink to fit a box too short for them', () {
      final layout = layOutProgress(_items, size: const Size(300, 60));
      expect(layout.rows.last.trackRect.bottom, lessThanOrEqualTo(60.001));
    });

    test('nothing to show lays out nothing', () {
      expect(
        layOutProgress(const [], size: const Size(300, 100)).isEmpty,
        true,
      );
      expect(layOutProgress(_items, size: Size.zero).isEmpty, true);
    });

    test('a point finds its row, and nothing past the last', () {
      final layout = layOutProgress(_items, size: const Size(300, 400));
      expect(layout.rowAt(const Offset(100, 10))?.index, 0);
      expect(layout.rowAt(const Offset(100, 60))?.index, 1);
      expect(layout.rowAt(const Offset(100, 300)), isNull);
    });
  });

  group('the widget', () {
    testWidgets('draws every shape without an error', (tester) async {
      for (final shape in ProgressShape.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                height: 200,
                child: ProgressBars(items: _items, shape: shape),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('reports the row under the finger', (tester) async {
      ProgressItem? touched;
      var cleared = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 200,
              child: ProgressBars(
                items: _items,
                onItemTap: (item) {
                  if (item == null) {
                    cleared = true;
                  } else {
                    touched = item;
                  }
                },
              ),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getTopLeft(find.byType(ProgressBars)) + const Offset(100, 28),
      );
      await tester.pump();
      expect(touched?.label, 'Profit');
      await gesture.up();
      await tester.pump();
      expect(cleared, true);
    });

    testWidgets('takes its own height in an unbounded box', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: ProgressBars(items: _items)),
          ),
        ),
      );
      // Three rows of 18 + 6 + 10, and two gaps of 16.
      expect(tester.getSize(find.byType(ProgressBars)).height, 3 * 34 + 2 * 16);
    });

    testWidgets('animates the fills in', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 200,
              child: ProgressBars(
                items: _items,
                animationDuration: const Duration(milliseconds: 200),
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

void progressCardTests() {
  group('a progress card', () {
    test('progress outside 0 to 1, or not a number, is held to it', () {
      const child = SizedBox();
      expect(const ProgressCard(progress: 0.4, child: child).fraction, 0.4);
      expect(const ProgressCard(progress: 7, child: child).fraction, 1);
      expect(const ProgressCard(progress: -2, child: child).fraction, 0);
      expect(
        const ProgressCard(progress: double.nan, child: child).fraction,
        0,
      );
    });

    testWidgets('sweeps a wedge of that share round the card', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: SizedBox(
              width: 200,
              child: ProgressCard(
                progress: 0.25,
                animationDuration: Duration.zero,
                child: Text('Course'),
              ),
            ),
          ),
        ),
      );
      final paint = tester.widget<CustomPaint>(
        find
            .descendant(
              of: find.byType(ProgressCard),
              matching: find.byType(CustomPaint),
            )
            .first,
      );
      // ignore: avoid_dynamic_calls
      expect((paint.painter! as dynamic).fraction, 0.25);
      expect((paint.painter! as dynamic).mode, ProgressCardMode.sweep);
      expect(find.text('Course'), findsOneWidget);
    });

    testWidgets('linear mode fills along the card instead', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProgressCard(
            progress: 0.5,
            mode: ProgressCardMode.linear,
            animationDuration: Duration.zero,
            child: Text('Course'),
          ),
        ),
      );
      final paint = tester.widget<CustomPaint>(
        find
            .descendant(
              of: find.byType(ProgressCard),
              matching: find.byType(CustomPaint),
            )
            .first,
      );
      // ignore: avoid_dynamic_calls
      expect((paint.painter! as dynamic).mode, ProgressCardMode.linear);
    });

    testWidgets('draws every mode without an error', (tester) async {
      for (final mode in ProgressCardMode.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: ProgressCard(
              progress: 0.4,
              mode: mode,
              animationDuration: Duration.zero,
              child: const Text('Course'),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });
  });
}
