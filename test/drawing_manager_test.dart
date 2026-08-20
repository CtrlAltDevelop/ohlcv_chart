import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

DateTime _at(int minute) =>
    DateTime.utc(2024, 1, 1).add(Duration(minutes: minute));

ChartDrawingController _controller() => ChartDrawingController(
  drawings: [
    HorizontalLine(price: 100, title: 'entry'),
    TrendLine(time1: _at(1), price1: 1, time2: _at(9), price2: 2),
    PositionDrawing(
      time1: _at(1),
      price1: 100,
      time2: _at(9),
      price2: 120,
      time3: _at(9),
      price3: 95,
    ),
  ],
);

Widget _host(ChartDrawingController controller) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: 400,
      height: 600,
      child: DrawingManager(controller: controller),
    ),
  ),
);

void main() {
  testWidgets('lists every drawing by name, newest first', (tester) async {
    await tester.pumpWidget(_host(_controller()));

    expect(find.textContaining('Horizontal line'), findsOneWidget);
    expect(find.textContaining('Trend line'), findsOneWidget);
    expect(find.textContaining('Long position'), findsOneWidget);
    expect(find.textContaining('Drawings  3'), findsOneWidget);
  });

  testWidgets('shows a label alongside the kind', (tester) async {
    await tester.pumpWidget(_host(_controller()));

    expect(find.text('Horizontal line · entry'), findsOneWidget);
  });

  testWidgets('says so when nothing is drawn', (tester) async {
    await tester.pumpWidget(_host(ChartDrawingController()));

    expect(find.text('Nothing drawn yet'), findsOneWidget);
  });

  testWidgets('a row hides and shows its drawing', (tester) async {
    final controller = _controller();
    await tester.pumpWidget(_host(controller));

    await tester.tap(find.byTooltip('Hide').first);
    await tester.pumpAndSettle();

    expect(controller.drawings.any((line) => line.hidden), isTrue);

    await tester.tap(find.byTooltip('Show').first);
    await tester.pumpAndSettle();

    expect(controller.drawings.any((line) => line.hidden), isFalse);
  });

  testWidgets('a row locks its drawing', (tester) async {
    final controller = _controller();
    await tester.pumpWidget(_host(controller));

    await tester.tap(find.byTooltip('Lock').first);
    await tester.pumpAndSettle();

    expect(controller.drawings.any((line) => line.locked), isTrue);
    expect(find.byTooltip('Unlock'), findsOneWidget);
  });

  testWidgets('a row deletes its drawing, undoably', (tester) async {
    final controller = _controller();
    await tester.pumpWidget(_host(controller));

    await tester.tap(find.byTooltip('Delete').first);
    await tester.pumpAndSettle();

    expect(controller.length, 2);

    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();

    expect(controller.length, 3);
  });

  testWidgets('clear all empties the list', (tester) async {
    final controller = _controller();
    await tester.pumpWidget(_host(controller));

    await tester.tap(find.byTooltip('Clear all'));
    await tester.pumpAndSettle();

    expect(controller.isEmpty, isTrue);
    expect(find.text('Nothing drawn yet'), findsOneWidget);
  });

  testWidgets('undo and redo are disabled with nothing to do', (tester) async {
    final controller = ChartDrawingController();
    await tester.pumpWidget(_host(controller));

    for (final tooltip in ['Undo', 'Redo', 'Clear all']) {
      final button = tester.widget<IconButton>(
        find.descendant(
          of: find.byTooltip(tooltip),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.onPressed, isNull, reason: tooltip);
    }
  });

  testWidgets('tapping a row selects that drawing', (tester) async {
    final controller = _controller();
    final tapped = <ChartLine>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: DrawingManager(
              controller: controller,
              onSelected: tapped.add,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.textContaining('Trend line'));
    await tester.pumpAndSettle();

    expect(controller.selected, isA<TrendLine>());
    expect(tapped, hasLength(1));
  });

  testWidgets('the chart opens its editor on the row that was tapped', (
    tester,
  ) async {
    final controller = _controller();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(
                width: 400,
                height: 300,
                child: KChartWidget(
                  [
                    for (var i = 0; i < 40; i++)
                      KLineEntity.fromCustom(
                        open: 100,
                        high: 101,
                        low: 99,
                        close: 100,
                        vol: 1,
                        dateTime: _at(i),
                      ),
                  ],
                  ChartColors(),
                  isTrendLine: true,
                  watermarkAssetPath: 'assets/none.svg',
                  timeFrame: const Duration(minutes: 1),
                  showNowPrice: false,
                  drawingController: controller,
                ),
              ),
              SizedBox(
                width: 400,
                height: 300,
                child: DrawingManager(controller: controller),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byTooltip('Done'), findsNothing);

    await tester.tap(find.textContaining('Horizontal line'));
    await tester.pumpAndSettle();

    // The chart's line editor is now open on the drawing the row named.
    expect(find.byTooltip('Done'), findsOneWidget);
  });

  testWidgets('translations rename every kind', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DrawingManager(
            controller: _controller(),
            translations: const DrawingTranslations(
              drawings: 'Zeichnungen',
              horizontalLineName: 'Horizontale Linie',
              longPositionName: 'Long-Position',
              trendLineName: 'Trendlinie',
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('Zeichnungen'), findsOneWidget);
    expect(find.textContaining('Horizontale Linie'), findsOneWidget);
    expect(find.textContaining('Long-Position'), findsOneWidget);
  });
}
