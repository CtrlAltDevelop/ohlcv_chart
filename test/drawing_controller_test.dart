import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

import 'test_utils.dart';

/// Any tap inside the chart selects the one drawing under test.
const _grabAnything = DrawingStyle(hitTestTolerance: 10000);

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 500, height: 600, child: child)),
);

Widget _chart({
  required ChartDrawingController controller,
  DrawingTool tool = DrawingTool.none,
  DrawingStyle style = const DrawingStyle(),
  bool enableKeyboardShortcuts = true,
}) {
  final data = candles(rampThenFall(60));
  DataUtil.calculate(data);

  return _host(
    KChartWidget(
      data,
      ChartColors(),
      isTrendLine: true,
      timeFrame: const Duration(minutes: 15),
      showNowPrice: false,
      drawingStyle: style,
      drawingController: controller,
      currentDrawingTool: tool,
      enableKeyboardShortcuts: enableKeyboardShortcuts,
    ),
  );
}

/// Presses [key] with the shortcut modifier held.
///
/// Both ⌘ and Ctrl go down, so the press reads as a shortcut whichever platform
/// the test happens to run on.
Future<void> _pressShortcut(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool shift = false,
}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pumpAndSettle();
}

void main() {
  group('ChartDrawingController', () {
    test('starts empty, with nothing to undo', () {
      final controller = ChartDrawingController();

      expect(controller.isEmpty, isTrue);
      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isFalse);
      expect(controller.undo(), isFalse);
      expect(controller.redo(), isFalse);
    });

    test('undo takes back a placement and redo puts it back', () {
      final controller = ChartDrawingController();
      controller.save(HorizontalLine(price: 10));

      expect(controller.length, 1);
      expect(controller.canUndo, isTrue);

      expect(controller.undo(), isTrue);
      expect(controller.length, 0);
      expect(controller.canRedo, isTrue);

      expect(controller.redo(), isTrue);
      expect(controller.length, 1);
      expect(controller.snapshot.horizontalLines.single.price, 10);
    });

    test('undo restores the style a line had before it was edited', () {
      final controller = ChartDrawingController();
      final line = HorizontalLine(price: 10, color: const Color(0xFF0000FF));
      controller.save(line);

      // The chart edits a drawing in place and then reports it, which is what
      // the controller has to be able to walk back.
      line
        ..color = const Color(0xFFFF0000)
        ..thickness = 6;
      controller.save(line);

      expect(controller.undo(), isTrue);

      final restored = controller.snapshot.horizontalLines.single;
      expect(restored.color, const Color(0xFF0000FF));
      expect(restored.thickness, 2);
    });

    test('undo brings back a deleted drawing', () {
      final controller = ChartDrawingController();
      final line = TrendLine(
        time1: DateTime.utc(2024),
        price1: 1,
        time2: DateTime.utc(2024, 1, 2),
        price2: 2,
      );
      controller.save(line);
      controller.remove(line);

      expect(controller.isEmpty, isTrue);
      expect(controller.undo(), isTrue);
      expect(controller.snapshot.trendLines, hasLength(1));
    });

    test('a new edit clears the redo stack', () {
      final controller = ChartDrawingController()
        ..save(HorizontalLine(price: 1))
        ..undo();

      expect(controller.canRedo, isTrue);

      controller.save(HorizontalLine(price: 2));

      expect(controller.canRedo, isFalse);
      expect(controller.length, 1);
    });

    test('clear is one undoable step', () {
      final controller = ChartDrawingController()
        ..save(HorizontalLine(price: 1))
        ..save(VerticalLine(time: DateTime.utc(2024)))
        ..clear();

      expect(controller.isEmpty, isTrue);
      controller.undo();
      expect(controller.length, 2);
    });

    test('the history stops at historyLimit', () {
      final controller = ChartDrawingController(historyLimit: 3);
      for (var i = 0; i < 10; i++) {
        controller.save(HorizontalLine(price: i.toDouble()));
      }

      var undone = 0;
      while (controller.undo()) {
        undone++;
      }

      expect(undone, 3);
      // The oldest steps fell off the back, so the drawings they carried stay.
      expect(controller.length, 7);
    });

    test('a layout round-trips through the controller', () {
      final controller = ChartDrawingController()
        ..save(HorizontalLine(price: 5, title: 'entry'))
        ..save(
          RectangleDrawing(
            time1: DateTime.utc(2024),
            price1: 1,
            time2: DateTime.utc(2024, 1, 2),
            price2: 2,
          ),
        );

      final restored = ChartDrawingController.fromJson(controller.toJson());

      expect(restored.length, 2);
      expect(restored.snapshot.horizontalLines.single.title, 'entry');
      expect(restored.canUndo, isFalse);
    });

    test('clearHistory keeps the drawings and drops the steps', () {
      final controller = ChartDrawingController()
        ..save(HorizontalLine(price: 1))
        ..clearHistory();

      expect(controller.length, 1);
      expect(controller.canUndo, isFalse);
    });

    test('notifies on every change', () {
      var notifications = 0;
      final controller = ChartDrawingController()
        ..addListener(() => notifications++);

      final line = HorizontalLine(price: 1);
      controller
        ..save(line)
        ..remove(line)
        ..undo()
        ..redo();

      expect(notifications, 4);
    });
  });

  group('the chart and its controller', () {
    testWidgets('a placed line lands in the controller', (tester) async {
      final controller = ChartDrawingController();
      await tester.pumpWidget(
        _chart(controller: controller, tool: DrawingTool.horizontal),
      );

      await tester.tapAt(const Offset(250, 200));
      await tester.pumpAndSettle();

      expect(controller.snapshot.horizontalLines, hasLength(1));
    });

    testWidgets('the chart draws what the controller holds', (tester) async {
      final controller = ChartDrawingController(
        drawings: [HorizontalLine(price: 120, showLabel: true, title: 'lvl')],
      );
      await tester.pumpWidget(_chart(controller: controller));

      expect(tester.takeException(), isNull);

      controller.clear();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('⌘Z undoes a placement and ⇧⌘Z redoes it', (tester) async {
      final controller = ChartDrawingController();
      await tester.pumpWidget(
        _chart(controller: controller, tool: DrawingTool.horizontal),
      );

      await tester.tapAt(const Offset(250, 200));
      await tester.pumpAndSettle();
      expect(controller.length, 1);

      await _pressShortcut(tester, LogicalKeyboardKey.keyZ);
      expect(controller.length, 0);

      await _pressShortcut(tester, LogicalKeyboardKey.keyZ, shift: true);
      expect(controller.length, 1);
    });

    testWidgets('shortcuts can be turned off', (tester) async {
      final controller = ChartDrawingController(
        drawings: [HorizontalLine(price: 100)],
      );
      await tester.pumpWidget(
        _chart(controller: controller, enableKeyboardShortcuts: false),
      );

      await _pressShortcut(tester, LogicalKeyboardKey.keyZ);

      expect(controller.length, 1);
    });

    testWidgets('Delete removes the selected drawing', (tester) async {
      final controller = ChartDrawingController(
        drawings: [HorizontalLine(price: 100)],
      );
      await tester.pumpWidget(
        _chart(controller: controller, style: _grabAnything),
      );

      await tester.tap(find.byType(KChartWidget));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();

      expect(controller.isEmpty, isTrue);
      expect(controller.undo(), isTrue);
      expect(controller.length, 1);
    });

    testWidgets('undoing while a drawing is selected closes the editor', (
      tester,
    ) async {
      final controller = ChartDrawingController();
      await tester.pumpWidget(
        _chart(
          controller: controller,
          tool: DrawingTool.horizontal,
          style: _grabAnything,
        ),
      );

      await tester.tapAt(const Offset(250, 200));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Delete'), findsOneWidget);

      await _pressShortcut(tester, LogicalKeyboardKey.keyZ);

      expect(find.byTooltip('Delete'), findsNothing);
    });

    testWidgets('a hidden drawing is neither painted nor selectable', (
      tester,
    ) async {
      final controller = ChartDrawingController(
        drawings: [HorizontalLine(price: 100, hidden: true)],
      );
      await tester.pumpWidget(
        _chart(controller: controller, style: _grabAnything),
      );

      await tester.tap(find.byType(KChartWidget));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Delete'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
