import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

import 'test_utils.dart';

/// Any right-click inside the chart lands on whatever is under test.
const _grabAnything = DrawingStyle(hitTestTolerance: 10000);

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 500, height: 600, child: child)),
);

/// Sixty candles, calculated.
List<KLineEntity> _candles() {
  final data = candles(rampThenFall(60));
  DataUtil.calculate(data);
  return data;
}

({Widget widget, List<KLineEntity> data, List<ChartLine> removed}) _chart({
  ChartDrawingController? controller,
  List<ChartLine>? drawings,
  DrawingStyle style = _grabAnything,
  bool showContextMenu = true,
  ChartMenuBuilder? contextMenuBuilder,
  List<KLineEntity>? candles,
}) {
  final data = candles ?? _candles();
  final removed = <ChartLine>[];
  return (
    data: data,
    removed: removed,
    widget: _host(
      KChartWidget(
        data,
        ChartColors(),
        isTrendLine: true,
        timeFrame: const Duration(minutes: 15),
        showNowPrice: false,
        drawingStyle: style,
        drawingController: controller,
        drawings: drawings ?? const [],
        showContextMenu: showContextMenu,
        contextMenuBuilder: contextMenuBuilder,
        onRemoveDrawing: removed.add,
      ),
    ),
  );
}

/// Right-clicks the chart at [at], and settles the menu open.
Future<void> _rightClick(
  WidgetTester tester,
  Offset at, {
  Duration settle = const Duration(seconds: 1),
}) async {
  final gesture = await tester.startGesture(at, buttons: kSecondaryButton);
  await gesture.up();
  await tester.pumpAndSettle(settle);
}

void main() {
  group('the chart menu', () {
    testWidgets('a right-click on empty chart offers the chart actions', (
      tester,
    ) async {
      final controller = ChartDrawingController();
      await tester.pumpWidget(_chart(controller: controller).widget);

      await _rightClick(tester, const Offset(250, 300));

      expect(find.text('Paste'), findsOneWidget);
      expect(find.text('Select all drawings'), findsOneWidget);
      expect(find.text('Fit the price scale'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      expect(find.text('Clear all'), findsOneWidget);
      // Nothing was clicked, so none of the per-drawing actions show.
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Bring to front'), findsNothing);
    });

    testWidgets('a right-click on a drawing offers its own actions', (
      tester,
    ) async {
      final line = HorizontalLine(price: 105);
      final controller = ChartDrawingController(drawings: [line]);
      await tester.pumpWidget(_chart(controller: controller).widget);

      await _rightClick(tester, const Offset(250, 300));

      expect(find.text('Edit coordinates…'), findsOneWidget);
      expect(find.text('Duplicate'), findsOneWidget);
      expect(find.text('Bring to front'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Paste'), findsNothing);
    });

    testWidgets('right-clicking a drawing selects it', (tester) async {
      final line = HorizontalLine(price: 105);
      final controller = ChartDrawingController(drawings: [line]);
      await tester.pumpWidget(_chart(controller: controller).widget);
      expect(controller.selected, isNull);

      await _rightClick(tester, const Offset(250, 300));

      expect(controller.selected, same(line));
    });

    testWidgets('the drawing under the pointer takes the selection', (
      tester,
    ) async {
      final bottom = HorizontalLine(price: 105);
      final top = HorizontalLine(price: 110);
      final controller = ChartDrawingController(drawings: [bottom, top])
        ..select(bottom);
      await tester.pumpWidget(_chart(controller: controller).widget);

      // Both are within reach, so the one painted on top is what was clicked,
      // and the menu is about that one rather than about what was selected.
      await _rightClick(tester, const Offset(250, 300));

      expect(controller.selected, same(top));
      expect(controller.selectionLength, 1);
    });

    testWidgets('a menu on one of several leaves the selection alone', (
      tester,
    ) async {
      final a = HorizontalLine(price: 105);
      final b = HorizontalLine(price: 110);
      final controller = ChartDrawingController(drawings: [a, b])
        ..selectMany([a, b]);
      await tester.pumpWidget(_chart(controller: controller).widget);

      await _rightClick(tester, const Offset(250, 300));

      expect(controller.selectionLength, 2);
    });

    testWidgets('Delete removes the drawing that was clicked', (tester) async {
      final line = HorizontalLine(price: 105);
      final controller = ChartDrawingController(drawings: [line]);
      final harness = _chart(controller: controller);
      await tester.pumpWidget(harness.widget);

      await _rightClick(tester, const Offset(250, 300));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(controller.isEmpty, isTrue);
      expect(harness.removed, [same(line)]);
    });

    testWidgets('Duplicate copies it', (tester) async {
      final controller = ChartDrawingController(
        drawings: [HorizontalLine(price: 105)],
      );
      await tester.pumpWidget(_chart(controller: controller).widget);

      await _rightClick(tester, const Offset(250, 300));
      await tester.tap(find.text('Duplicate'));
      await tester.pumpAndSettle();

      expect(controller.length, 2);
    });

    testWidgets('Send to back restacks the one that was clicked', (
      tester,
    ) async {
      final bottom = HorizontalLine(price: 105);
      final top = HorizontalLine(price: 110);
      final controller = ChartDrawingController(drawings: [bottom, top]);
      await tester.pumpWidget(_chart(controller: controller).widget);

      // Both are within reach of the click, so the one painted on top is the
      // one the menu is about — which is the last in the stack.
      await _rightClick(tester, const Offset(250, 300));
      expect(controller.selected, same(top));

      await tester.tap(find.text('Send to back'));
      await tester.pumpAndSettle();

      expect(controller.indexOf(top), 0);
      expect(controller.indexOf(bottom), 1);
    });

    testWidgets('Lock and Hide toggle, and read as ticked when set', (
      tester,
    ) async {
      final line = HorizontalLine(price: 105);
      final controller = ChartDrawingController(drawings: [line]);
      await tester.pumpWidget(_chart(controller: controller).widget);

      await _rightClick(tester, const Offset(250, 300));
      expect(find.text('Lock'), findsOneWidget);
      await tester.tap(find.text('Lock'));
      await tester.pumpAndSettle();
      expect(line.locked, isTrue);

      // A locked drawing cannot be picked up by a tap, but a right-click on it
      // still opens its menu — which now offers to unlock it.
      await _rightClick(tester, const Offset(250, 300));
      expect(find.text('Unlock'), findsOneWidget);
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      expect(line.locked, isFalse);
    });

    testWidgets('the alert item is offered only where it means something', (
      tester,
    ) async {
      final data = _candles();
      final note = TextAnnotation(
        time: data[20].dateTime!,
        price: data[20].close,
      );
      final controller = ChartDrawingController(drawings: [note]);
      await tester.pumpWidget(
        _chart(controller: controller, candles: data).widget,
      );

      await _rightClick(tester, const Offset(250, 300));

      // A note has no level to cross, so it is not an AlertingDrawing.
      expect(find.text('Alert me here'), findsNothing);
      expect(find.text('Lock'), findsOneWidget);
    });

    testWidgets('the alert item arms an alert on a level', (tester) async {
      final line = HorizontalLine(price: 105);
      final controller = ChartDrawingController(drawings: [line]);
      await tester.pumpWidget(_chart(controller: controller).widget);

      await _rightClick(tester, const Offset(250, 300));
      await tester.tap(find.text('Alert me here'));
      await tester.pumpAndSettle();

      expect(line.alert, isTrue);
    });

    testWidgets('an action applies to the whole selection', (tester) async {
      final a = HorizontalLine(price: 105);
      final b = HorizontalLine(price: 110);
      final controller = ChartDrawingController(drawings: [a, b])
        ..selectMany([a, b]);
      await tester.pumpWidget(_chart(controller: controller).widget);

      await _rightClick(tester, const Offset(250, 300));
      await tester.tap(find.text('Lock'));
      await tester.pumpAndSettle();

      expect(a.locked, isTrue);
      expect(b.locked, isTrue);
    });

    testWidgets('Clear all empties the chart', (tester) async {
      final controller = ChartDrawingController(
        drawings: [HorizontalLine(price: 105)],
      );
      final harness = _chart(controller: controller);
      await tester.pumpWidget(harness.widget);

      // Away from the level, so the chart menu opens rather than the drawing's.
      await _rightClick(tester, const Offset(250, 300));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(controller.isEmpty, isTrue);
    });

    testWidgets('Paste is offered but disabled with nothing copied', (
      tester,
    ) async {
      final controller = ChartDrawingController();
      await tester.pumpWidget(_chart(controller: controller).widget);

      await _rightClick(tester, const Offset(250, 300));

      final item = tester.widget<PopupMenuItem<ChartMenuItem>>(
        find
            .ancestor(
              of: find.text('Paste'),
              matching: find.byType(PopupMenuItem<ChartMenuItem>),
            )
            .first,
      );
      expect(item.enabled, isFalse);
    });

    testWidgets('the menu can be turned off', (tester) async {
      await tester.pumpWidget(_chart(showContextMenu: false).widget);

      await _rightClick(tester, const Offset(250, 300));

      expect(find.text('Paste'), findsNothing);
    });

    testWidgets('a right-click outside the candles opens nothing', (
      tester,
    ) async {
      await tester.pumpWidget(_chart().widget);

      // Below the candle area, over the volume and date axis.
      await _rightClick(tester, const Offset(250, 590));

      expect(find.text('Paste'), findsNothing);
    });
  });

  group('a menu of your own', () {
    testWidgets('the builder is handed what was clicked', (tester) async {
      final data = _candles();
      final line = HorizontalLine(price: data[20].close);
      ChartMenuRequest? seen;

      await tester.pumpWidget(
        _chart(
          drawings: [line],
          candles: data,
          contextMenuBuilder: (request) {
            seen = request;
            return request.defaults;
          },
        ).widget,
      );

      await _rightClick(tester, const Offset(250, 300));

      expect(seen, isNotNull);
      expect(seen!.drawing, same(line));
      expect(seen!.candle, isNotNull);
      expect(seen!.price, isNotNull);
      expect(seen!.position, const Offset(250, 300));
      expect(seen!.defaults, isNotEmpty);
    });

    testWidgets('an item can be added to the defaults', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        _chart(
          contextMenuBuilder: (request) => [
            ...request.defaults,
            const ChartMenuDivider(),
            ChartMenuItem(
              label: 'Place an order here',
              onSelected: () => pressed++,
            ),
          ],
        ).widget,
      );

      await _rightClick(tester, const Offset(250, 300));
      expect(find.text('Paste'), findsOneWidget);

      await tester.tap(find.text('Place an order here'));
      await tester.pumpAndSettle();

      expect(pressed, 1);
    });

    testWidgets('returning nothing shows no menu', (tester) async {
      await tester.pumpWidget(
        _chart(contextMenuBuilder: (_) => const []).widget,
      );

      await _rightClick(tester, const Offset(250, 300));

      expect(find.text('Paste'), findsNothing);
    });

    testWidgets('the builder wins over showContextMenu being off', (
      tester,
    ) async {
      await tester.pumpWidget(
        _chart(
          showContextMenu: false,
          contextMenuBuilder: (_) => [
            ChartMenuItem(label: 'Only mine', onSelected: () {}),
          ],
        ).widget,
      );

      await _rightClick(tester, const Offset(250, 300));

      expect(find.text('Only mine'), findsOneWidget);
    });
  });

  group('showChartMenu on its own', () {
    testWidgets('shows items, dividers and ticks, and runs what is picked', (
      tester,
    ) async {
      var picked = '';
      late BuildContext ctx;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                ctx = context;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );

      final menu = showChartMenu(
        context: ctx,
        position: const Offset(100, 100),
        entries: [
          ChartMenuItem(label: 'First', onSelected: () => picked = 'first'),
          const ChartMenuDivider(),
          ChartMenuItem(
            label: 'Ticked',
            checked: true,
            onSelected: () => picked = 'ticked',
          ),
          ChartMenuItem(label: 'Off', enabled: false, onSelected: () {}),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('First'), findsOneWidget);
      expect(find.byType(PopupMenuDivider), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      await tester.tap(find.text('Ticked'));
      await tester.pumpAndSettle();
      await menu;

      expect(picked, 'ticked');
    });

    testWidgets('an empty list opens nothing', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                ctx = context;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );

      await showChartMenu(
        context: ctx,
        position: Offset.zero,
        entries: const [],
      );
      await tester.pumpAndSettle();

      expect(find.byType(PopupMenuItem<ChartMenuItem>), findsNothing);
    });
  });
}
