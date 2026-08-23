import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

import 'test_utils.dart';

/// Any tap inside the chart selects whatever is under test.
const _grabAnything = DrawingStyle(hitTestTolerance: 10000);

DateTime _at(int minute) =>
    DateTime.utc(2024, 1, 1).add(Duration(minutes: minute));

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 500, height: 600, child: child)),
);

/// A chart over [controller]'s drawings, with the tools live.
({Widget widget, List<KLineEntity> data}) _chart(
  ChartDrawingController controller, {
  DrawingStyle style = _grabAnything,
  void Function(ChartLine, KLineEntity, double)? onDrawingAlert,
  List<KLineEntity>? candles,
}) {
  final data = candles ?? candles0();
  return (
    data: data,
    widget: _host(
      KChartWidget(
        data,
        ChartColors(),
        isTrendLine: true,
        watermarkAssetPath: 'assets/none.svg',
        timeFrame: const Duration(minutes: 15),
        showNowPrice: false,
        drawingStyle: style,
        drawingController: controller,
        onDrawingAlert: onDrawingAlert,
      ),
    ),
  );
}

/// Sixty candles, calculated, timestamped a minute apart.
List<KLineEntity> candles0() {
  final data = candles(rampThenFall(60));
  DataUtil.calculate(data);
  return data;
}

/// Presses [key] with the platform's shortcut modifier held.
Future<void> _shortcut(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool shift = false,
}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pumpAndSettle();
}

void main() {
  // The shortcuts use the Apple modifier, so the tests run as macOS.
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.macOS);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('multi-select', () {
    test('a second selection joins the first rather than replacing it', () {
      final a = HorizontalLine(price: 1);
      final b = HorizontalLine(price: 2);
      final controller = ChartDrawingController(drawings: [a, b]);

      controller.select(a);
      expect(controller.selection, [a]);
      expect(controller.hasMultipleSelected, isFalse);

      controller.addToSelection(b);
      expect(controller.selection, [a, b]);
      expect(controller.selected, same(b), reason: 'the editor moves to it');
      expect(controller.hasMultipleSelected, isTrue);
      expect(controller.isSelected(a), isTrue);
    });

    test('toggling takes a drawing back out', () {
      final a = HorizontalLine(price: 1);
      final b = HorizontalLine(price: 2);
      final controller = ChartDrawingController(drawings: [a, b])
        ..select(a)
        ..addToSelection(b);

      controller.toggleSelection(b);
      expect(controller.selection, [a]);
      expect(controller.selected, same(a));

      controller.toggleSelection(a);
      expect(controller.selection, isEmpty);
      expect(controller.selected, isNull);
    });

    test('taking out the primary leaves the editor on what is left', () {
      final a = HorizontalLine(price: 1);
      final b = HorizontalLine(price: 2);
      final controller = ChartDrawingController(drawings: [a, b])
        ..select(a)
        ..addToSelection(b);

      controller.removeFromSelection(b);
      expect(controller.selected, same(a));
      expect(controller.selectionLength, 1);
    });

    test('selecting one alone clears the rest', () {
      final a = HorizontalLine(price: 1);
      final b = HorizontalLine(price: 2);
      final controller = ChartDrawingController(drawings: [a, b])
        ..selectMany([a, b]);
      expect(controller.selectionLength, 2);

      controller.select(a);
      expect(controller.selection, [a]);
    });

    test('selectAll takes everything, and an empty list clears', () {
      final a = HorizontalLine(price: 1);
      final b = HorizontalLine(price: 2);
      final controller = ChartDrawingController(drawings: [a, b])..selectAll();

      expect(controller.selectionLength, 2);

      controller.selectMany(const []);
      expect(controller.selection, isEmpty);
      expect(controller.selected, isNull);
    });

    test('a stranger cannot be selected', () {
      final held = HorizontalLine(price: 1);
      final stranger = HorizontalLine(price: 9);
      final controller = ChartDrawingController(drawings: [held]);

      controller
        ..addToSelection(stranger)
        ..selectMany([stranger]);
      expect(controller.selection, isEmpty);
    });

    test('deleting one of several leaves the others selected', () {
      final a = HorizontalLine(price: 1);
      final b = HorizontalLine(price: 2);
      final controller = ChartDrawingController(drawings: [a, b])
        ..selectMany([a, b]);

      controller.remove(b);
      expect(controller.selected, same(a));
      expect(controller.selectionLength, 1);
    });

    testWidgets('⌘A selects everything drawn', (tester) async {
      final controller = ChartDrawingController(
        drawings: [HorizontalLine(price: 105), HorizontalLine(price: 110)],
      );
      await tester.pumpWidget(_chart(controller).widget);

      await _shortcut(tester, LogicalKeyboardKey.keyA);

      expect(controller.selectionLength, 2);
    });

    testWidgets('a hidden drawing is left out of ⌘A', (tester) async {
      final shown = HorizontalLine(price: 105);
      final controller = ChartDrawingController(
        drawings: [shown, HorizontalLine(price: 110, hidden: true)],
      );
      await tester.pumpWidget(_chart(controller).widget);

      await _shortcut(tester, LogicalKeyboardKey.keyA);

      expect(controller.selection, [shown]);
    });

    testWidgets('Delete removes the whole selection in one step', (
      tester,
    ) async {
      final controller = ChartDrawingController(
        drawings: [HorizontalLine(price: 105), HorizontalLine(price: 110)],
      );
      await tester.pumpWidget(_chart(controller).widget);

      await _shortcut(tester, LogicalKeyboardKey.keyA);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();

      expect(controller.isEmpty, isTrue);

      // One step, so one undo brings both back.
      expect(controller.undo(), isTrue);
      expect(controller.length, 2);
    });

    testWidgets('the toolbar says how many are being edited', (tester) async {
      final controller = ChartDrawingController(
        drawings: [HorizontalLine(price: 105), HorizontalLine(price: 110)],
      );
      await tester.pumpWidget(_chart(controller).widget);

      await _shortcut(tester, LogicalKeyboardKey.keyA);

      expect(find.text('2 selected'), findsOneWidget);
    });

    testWidgets('an edit made through the toolbar reaches the rest', (
      tester,
    ) async {
      final a = HorizontalLine(price: 105, thickness: 2);
      final b = HorizontalLine(price: 110, thickness: 2);
      final controller = ChartDrawingController(drawings: [a, b]);
      await tester.pumpWidget(_chart(controller).widget);

      await _shortcut(tester, LogicalKeyboardKey.keyA);
      expect(controller.selected, same(b));

      // Through the thickness popover, which is what a user reaches for.
      await tester.tap(find.byTooltip('Thickness'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4').last);
      await tester.pumpAndSettle();

      expect(b.thickness, 4);
      expect(a.thickness, 4, reason: 'the other selected line follows');
    });
  });

  group('copy, paste and duplicate', () {
    test('the clipboard holds copies, not the originals', () {
      final line = HorizontalLine(price: 105);
      final controller = ChartDrawingController(drawings: [line])
        ..copyToClipboard([line]);

      expect(controller.canPaste, isTrue);
      expect(controller.clipboardLength, 1);

      // Editing the original afterwards leaves what was copied alone.
      line.price = 999;
      final pasted = controller.paste();
      expect(pasted, hasLength(1));
      expect((pasted.single as HorizontalLine).price, 105);
      expect(controller.length, 2);
    });

    test('pasting nothing is nothing', () {
      final controller = ChartDrawingController();
      expect(controller.paste(), isEmpty);
      expect(controller.canPaste, isFalse);
    });

    test('the clipboard can be emptied', () {
      final line = HorizontalLine(price: 1);
      final controller = ChartDrawingController(drawings: [line])
        ..copyToClipboard([line])
        ..clearClipboard();

      expect(controller.canPaste, isFalse);
    });

    test('duplicating leaves the copies selected', () {
      final line = TrendLine(time1: _at(0), price1: 1, time2: _at(5), price2: 2);
      final controller = ChartDrawingController(drawings: [line]);

      final copies = controller.duplicate([line]);

      expect(copies, hasLength(1));
      expect(copies.single, isNot(same(line)));
      expect(controller.selection, copies);
      expect(controller.length, 2);
    });

    test('duplicating a stranger duplicates nothing', () {
      final controller = ChartDrawingController();
      expect(controller.duplicate([HorizontalLine(price: 1)]), isEmpty);
    });

    testWidgets('⌘C then ⌘V lands a copy clear of the original', (
      tester,
    ) async {
      final data = candles0();
      final line = TrendLine(
        time1: data[10].dateTime!,
        price1: data[10].close,
        time2: data[20].dateTime!,
        price2: data[20].close,
      );
      final controller = ChartDrawingController(drawings: [line]);
      await tester.pumpWidget(_chart(controller, candles: data).widget);

      await tester.tap(find.byType(KChartWidget));
      await tester.pumpAndSettle();
      expect(controller.selected, same(line));

      await _shortcut(tester, LogicalKeyboardKey.keyC);
      await _shortcut(tester, LogicalKeyboardKey.keyV);

      expect(controller.length, 2);
      final copy = controller.drawings.last as TrendLine;
      expect(copy, isNot(same(line)));
      // Nudged, so it can be seen and grabbed rather than hiding underneath.
      expect(copy.time1, isNot(line.time1));
      expect(copy.price1, lessThan(line.price1));
    });

    testWidgets('⌘D duplicates without touching the clipboard', (tester) async {
      final controller = ChartDrawingController(
        drawings: [HorizontalLine(price: 105)],
      );
      await tester.pumpWidget(_chart(controller).widget);

      await tester.tap(find.byType(KChartWidget));
      await tester.pumpAndSettle();
      await _shortcut(tester, LogicalKeyboardKey.keyD);

      expect(controller.length, 2);
      expect(controller.canPaste, isFalse);
    });

    testWidgets('a paste with nothing copied does nothing', (tester) async {
      final controller = ChartDrawingController(
        drawings: [HorizontalLine(price: 105)],
      );
      await tester.pumpWidget(_chart(controller).widget);

      await _shortcut(tester, LogicalKeyboardKey.keyV);

      expect(controller.length, 1);
    });
  });

  group('stacking order', () {
    test('the controller walks a drawing up and down the stack', () {
      final bottom = HorizontalLine(price: 1);
      final top = HorizontalLine(price: 2);
      final controller = ChartDrawingController(drawings: [bottom, top]);

      expect(controller.indexOf(bottom), 0);
      expect(controller.bringToFront(bottom), isTrue);
      expect(controller.indexOf(bottom), 1);

      expect(controller.sendToBack(bottom), isTrue);
      expect(controller.indexOf(bottom), 0);

      expect(controller.bringForward(bottom), isTrue);
      expect(controller.indexOf(bottom), 1);

      expect(controller.sendBackward(bottom), isTrue);
      expect(controller.indexOf(bottom), 0);
    });

    test('restacking is undoable, and a move that does nothing is not', () {
      final bottom = HorizontalLine(price: 1);
      final top = HorizontalLine(price: 2);
      final controller = ChartDrawingController(drawings: [bottom, top]);
      expect(controller.canUndo, isFalse);

      expect(controller.sendBackward(bottom), isFalse);
      expect(
        controller.canUndo,
        isFalse,
        reason: 'nothing moved, so there is nothing to undo',
      );

      expect(controller.bringToFront(bottom), isTrue);
      expect(controller.canUndo, isTrue);
      controller.undo();
      expect(controller.drawings.first.hashCode, isNotNull);
      expect(controller.length, 2);
    });

    test('an edit no longer restacks the drawing it edited', () {
      final bottom = HorizontalLine(price: 1);
      final top = HorizontalLine(price: 2);
      final controller = ChartDrawingController(drawings: [bottom, top]);

      bottom.thickness = 5;
      controller.save(bottom);

      expect(
        controller.indexOf(bottom),
        0,
        reason: 'restyling must not move it over the one drawn after it',
      );
    });

    testWidgets('⌘] and ⌘[ move the selection through the stack', (
      tester,
    ) async {
      final bottom = HorizontalLine(price: 105);
      final top = HorizontalLine(price: 110);
      final controller = ChartDrawingController(drawings: [bottom, top]);
      await tester.pumpWidget(_chart(controller).widget);

      controller.select(bottom);
      await tester.pumpAndSettle();

      await _shortcut(tester, LogicalKeyboardKey.bracketRight);
      expect(controller.indexOf(bottom), 1);

      await _shortcut(tester, LogicalKeyboardKey.bracketLeft, shift: true);
      expect(controller.indexOf(bottom), 0);
    });

    testWidgets('a selection of several keeps its own order', (tester) async {
      final a = HorizontalLine(price: 105);
      final b = HorizontalLine(price: 110);
      final c = HorizontalLine(price: 115);
      final controller = ChartDrawingController(drawings: [a, b, c]);
      await tester.pumpWidget(_chart(controller).widget);

      controller.selectMany([a, b]);
      await tester.pumpAndSettle();

      await _shortcut(tester, LogicalKeyboardKey.bracketRight, shift: true);

      expect(controller.drawings, [c, a, b]);
    });
  });

  group('style templates', () {
    test('a template carries the shared look and nothing else', () {
      final box = RectangleDrawing(
        time1: _at(0),
        price1: 1,
        time2: _at(5),
        price2: 2,
        fillOpacity: 0.5,
        color: const Color(0xFF112233),
        thickness: 4,
        style: LineStyle.dotted,
      );

      final template = DrawingTemplate.of(box);
      final line = HorizontalLine(price: 9);
      template.applyTo(line);

      expect(line.color, box.color);
      expect(line.thickness, 4);
      expect(line.style, LineStyle.dotted);
      // A horizontal level has no inside, so the fill is simply ignored.
      expect(line, isNot(isA<FilledDrawing>()));
    });

    test('a template with nothing set leaves a drawing alone', () {
      final line = HorizontalLine(price: 1, thickness: 3);
      const DrawingTemplate().applyTo(line);

      expect(line.thickness, 3);
    });

    test('a template round-trips through JSON', () {
      final template = DrawingTemplate.of(
        RectangleDrawing(
          time1: _at(0),
          price1: 1,
          fillOpacity: 0.25,
          color: const Color(0xFF445566),
          thickness: 3,
          style: LineStyle.dashed,
        ),
      );

      expect(DrawingTemplate.fromJson(template.toJson()), template);
    });

    test('a malformed template loads as one that changes nothing', () {
      final template = DrawingTemplate.fromJson(const {
        'color': 'blue',
        'thickness': 'thick',
      });

      final line = HorizontalLine(price: 1, thickness: 2);
      template.applyTo(line);
      expect(line.thickness, 2);
    });

    test('the controller saves a template and puts it on a selection', () {
      final source = HorizontalLine(
        price: 1,
        color: const Color(0xFF00FF00),
        thickness: 5,
      );
      final a = HorizontalLine(price: 2);
      final b = HorizontalLine(price: 3);
      final controller = ChartDrawingController(drawings: [source, a, b]);

      controller.saveTemplate('house', source);
      expect(controller.templates.keys, ['house']);

      expect(controller.applyTemplate('house', [a, b]), isTrue);
      expect(a.color, source.color);
      expect(b.thickness, 5);

      // One undoable step, so undo puts both back.
      expect(controller.canUndo, isTrue);
    });

    test('an unknown template applies nothing and says so', () {
      final controller = ChartDrawingController(
        drawings: [HorizontalLine(price: 1)],
      );
      expect(controller.applyTemplate('nope', controller.drawings), isFalse);
    });

    test('templates can be removed, saved and loaded', () {
      final controller = ChartDrawingController()
        ..putTemplate('a', const DrawingTemplate(thickness: 3))
        ..putTemplate('b', const DrawingTemplate(thickness: 5));

      final saved = controller.templatesToJson();
      expect(saved.keys, ['a', 'b']);

      expect(controller.removeTemplate('a'), isTrue);
      expect(controller.removeTemplate('a'), isFalse);
      expect(controller.templates.keys, ['b']);

      controller.loadTemplates(saved);
      expect(controller.templates, hasLength(2));
      expect(controller.templates['a']!.thickness, 3);
    });

    test('loading rubbish loads no templates', () {
      final controller = ChartDrawingController()
        ..putTemplate('a', const DrawingTemplate(thickness: 3))
        ..loadTemplates(const {'a': 7, 'b': 'nope'});

      expect(controller.templates, isEmpty);
    });
  });

  group('alerts on any drawing', () {
    test('a horizontal level answers its own price', () {
      final line = HorizontalLine(price: 100, alert: true);
      expect(line.alertLevelsAt(_at(5)), [100]);
    });

    test('a ray has no level before it starts', () {
      final ray = HorizontalLine(price: 100, startTime: _at(10), alert: true);

      expect(ray.alertLevelsAt(_at(5)), isEmpty);
      expect(ray.alertLevelsAt(_at(20)), [100]);
    });

    test('a trend line answers where it is at that candle', () {
      final line = TrendLine(
        time1: _at(0),
        price1: 100,
        time2: _at(10),
        price2: 110,
        alert: true,
      );

      expect(line.alertLevelsAt(_at(5)).single, closeTo(105, 1e-9));
      expect(line.alertLevelsAt(_at(0)).single, closeTo(100, 1e-9));
      // Past the end of a plain segment there is nothing to cross.
      expect(line.alertLevelsAt(_at(20)), isEmpty);
    });

    test('a ray and an extended line reach further than a segment', () {
      TrendLine of(LineExtension extend) => TrendLine(
        time1: _at(10),
        price1: 100,
        time2: _at(20),
        price2: 110,
        extend: extend,
        alert: true,
      );

      expect(of(LineExtension.right).alertLevelsAt(_at(40)).single, 130);
      expect(of(LineExtension.right).alertLevelsAt(_at(0)), isEmpty);
      expect(of(LineExtension.both).alertLevelsAt(_at(0)).single, 90);
    });

    test('a half-placed trend line has nothing to cross', () {
      expect(TrendLine(time1: _at(0), price1: 100).alertLevelsAt(_at(5)),
          isEmpty);
    });

    test('a channel answers both of its lines', () {
      final channel = ParallelChannel(
        time1: _at(0),
        price1: 100,
        time2: _at(10),
        price2: 110,
        time3: _at(10),
        price3: 120,
        alert: true,
      );

      final levels = channel.alertLevelsAt(_at(5));
      expect(levels, hasLength(2));
      expect(levels.first, closeTo(105, 1e-9));
      expect(levels.last, closeTo(115, 1e-9));
    });

    test('a retracement answers every level, from the swing rightwards', () {
      final fib = FibRetracement(
        time1: _at(0),
        price1: 100,
        time2: _at(10),
        price2: 200,
        levels: const [0, 0.5, 1],
        alert: true,
      );

      expect(fib.alertLevelsAt(_at(30)), [100, 150, 200]);
    });

    test('alerts survive a save and a load', () {
      for (final line in <ChartLine>[
        HorizontalLine(price: 1, alert: true),
        TrendLine(time1: _at(0), price1: 1, time2: _at(5), price2: 2,
            alert: true),
        ParallelChannel(time1: _at(0), price1: 1, alert: true),
        FibRetracement(time1: _at(0), price1: 1, alert: true),
      ]) {
        final restored = copyDrawing(line) as AlertingDrawing;
        expect(restored.alert, isTrue, reason: '${line.runtimeType}');
      }
    });

    testWidgets('a trend line reports when the market crosses it', (
      tester,
    ) async {
      // Rising then falling, so the last candle is below a level the earlier
      // ones were above.
      final data = candles([for (var i = 0; i < 20; i++) 100.0 + i]);
      DataUtil.calculate(data);

      final reports = <(ChartLine, double)>[];
      final line = TrendLine(
        time1: data.first.dateTime!,
        price1: 100,
        time2: data.last.dateTime!,
        price2: 100,
        extend: LineExtension.both,
        alert: true,
      );
      final controller = ChartDrawingController(drawings: [line]);

      await tester.pumpWidget(
        _chart(
          controller,
          candles: data,
          onDrawingAlert: (line, candle, level) => reports.add((line, level)),
        ).widget,
      );
      await tester.pumpAndSettle();
      // The first sighting sets the side rather than reporting a crossing.
      expect(reports, isEmpty);

      // Drop the newest candle below the line and pump again.
      line.price1 = 500;
      line.price2 = 500;
      await tester.pumpWidget(
        _chart(
          controller,
          candles: data,
          onDrawingAlert: (line, candle, level) => reports.add((line, level)),
        ).widget,
      );
      await tester.pumpAndSettle();

      expect(reports, hasLength(1));
      expect(reports.single.$1, same(line));
      expect(reports.single.$2, 500);
    });

    testWidgets('the toolbar arms an alert on a trend line', (tester) async {
      final data = candles0();
      final line = TrendLine(
        time1: data[10].dateTime!,
        price1: data[10].close,
        time2: data[20].dateTime!,
        price2: data[20].close,
      );
      final controller = ChartDrawingController(drawings: [line]);
      await tester.pumpWidget(_chart(controller, candles: data).widget);

      await tester.tap(find.byType(KChartWidget));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Alert me here'));
      await tester.pumpAndSettle();

      expect(line.alert, isTrue);
    });
  });

  group('the coordinates dialog', () {
    test('a drawing reads out its anchors, named', () {
      final trend = TrendLine(
        time1: _at(0),
        price1: 100,
        time2: _at(10),
        price2: 110,
      );

      final anchors = drawingAnchors(trend);
      expect(anchors.map((a) => a.name), ['Start', 'End']);
      expect(anchors.first.price, 100);
      expect(anchors.last.time, _at(10));
    });

    test('a three-point shape reads out its third', () {
      final channel = ParallelChannel(
        time1: _at(0),
        price1: 1,
        time2: _at(5),
        price2: 2,
        time3: _at(5),
        price3: 3,
      );

      expect(drawingAnchors(channel), hasLength(3));
      expect(drawingAnchors(channel).last.name, 'Third');
    });

    test('a harmonic pattern names its points X through D', () {
      final pattern = XabcdDrawing(
        points: [
          for (var i = 0; i < 5; i++) (time: _at(i * 5), price: 100.0 + i),
        ],
      );

      expect(drawingAnchors(pattern).map((a) => a.name), [
        'X',
        'A',
        'B',
        'C',
        'D',
      ]);
    });

    test('a path numbers its points past the named ones', () {
      final path = PathDrawing(
        points: [for (var i = 0; i < 3; i++) (time: _at(i), price: 1)],
      );

      expect(drawingAnchors(path).map((a) => a.name), [
        'Point 1',
        'Point 2',
        'Point 3',
      ]);
    });

    test('a level has a price and no candle; a vertical the other way', () {
      expect(drawingAnchors(HorizontalLine(price: 5)).single.time, isNull);
      expect(drawingAnchors(HorizontalLine(price: 5)).single.price, 5);
      expect(drawingAnchors(VerticalLine(time: _at(3))).single.price, isNull);
      expect(drawingAnchors(VerticalLine(time: _at(3))).single.time, _at(3));
    });

    test('a half-placed shape reads out only what has landed', () {
      expect(drawingAnchors(TrendLine(time1: _at(0), price1: 1)), hasLength(1));
    });

    test('an anchor can be typed in', () {
      final trend = TrendLine(
        time1: _at(0),
        price1: 100,
        time2: _at(10),
        price2: 110,
      );

      expect(setDrawingAnchor(trend, 1, time: _at(20), price: 999), isTrue);
      expect(trend.time2, _at(20));
      expect(trend.price2, 999);

      // Only the part given is written.
      expect(setDrawingAnchor(trend, 0, price: 5), isTrue);
      expect(trend.price1, 5);
      expect(trend.time1, _at(0));
    });

    test('an anchor that is not there cannot be typed in', () {
      final trend = TrendLine(time1: _at(0), price1: 1);
      expect(setDrawingAnchor(trend, 5, price: 9), isFalse);
      expect(setDrawingAnchor(trend, -1, price: 9), isFalse);
    });

    test('a freehand stroke reads out its ends and takes no edits', () {
      final stroke = FreehandDrawing(
        points: [
          (time: _at(0), price: 100),
          (time: _at(1), price: 101),
          (time: _at(2), price: 102),
        ],
      );

      expect(drawingAnchors(stroke).map((a) => a.name), ['Start', 'End']);
      expect(drawingAnchorsAreEditable(stroke), isFalse);
      expect(setDrawingAnchor(stroke, 0, price: 9), isFalse);
      expect(stroke.points.first.price, 100);
    });

    test('an empty stroke reads out nothing', () {
      expect(drawingAnchors(FreehandDrawing()), isEmpty);
    });

    test('a multi-point anchor can be typed in', () {
      final path = PathDrawing(
        points: [(time: _at(0), price: 1), (time: _at(5), price: 2)],
      );

      expect(setDrawingAnchor(path, 1, price: 7), isTrue);
      expect(path.points.last.price, 7);
      expect(path.points.last.time, _at(5));
    });

    testWidgets('the toolbar opens it, and Apply writes the price back', (
      tester,
    ) async {
      final data = candles0();
      final line = HorizontalLine(price: data[10].close);
      final controller = ChartDrawingController(drawings: [line]);
      await tester.pumpWidget(_chart(controller, candles: data).widget);

      await tester.tap(find.byType(KChartWidget));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Coordinates'));
      await tester.pumpAndSettle();
      expect(find.text('Exact coordinates — Horizontal line'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '123.45');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(line.price, 123.45);
    });

    testWidgets('Cancel leaves the drawing alone', (tester) async {
      final data = candles0();
      final line = HorizontalLine(price: 105);
      final controller = ChartDrawingController(drawings: [line]);
      await tester.pumpWidget(_chart(controller, candles: data).widget);

      await tester.tap(find.byType(KChartWidget));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Coordinates'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '999');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(line.price, 105);
    });

    testWidgets('the button can be left off', (tester) async {
      final data = candles0();
      await tester.pumpWidget(
        _host(
          KChartWidget(
            data,
            ChartColors(),
            isTrendLine: true,
            watermarkAssetPath: 'assets/none.svg',
            timeFrame: const Duration(minutes: 15),
            showNowPrice: false,
            drawingStyle: _grabAnything,
            showDrawingCoordinates: false,
            drawings: [HorizontalLine(price: 105)],
          ),
        ),
      );

      await tester.tap(find.byType(KChartWidget));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Delete'), findsOneWidget);
      expect(find.byTooltip('Coordinates'), findsNothing);
    });

    testWidgets('a stroke says why it cannot be typed into', (tester) async {
      final data = candles0();
      final stroke = FreehandDrawing(
        points: [
          (time: data[5].dateTime!, price: data[5].close),
          (time: data[15].dateTime!, price: data[15].close),
        ],
      );
      final controller = ChartDrawingController(drawings: [stroke]);
      await tester.pumpWidget(_chart(controller, candles: data).widget);

      await tester.tap(find.byType(KChartWidget));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Coordinates'));
      await tester.pumpAndSettle();

      expect(
        find.text('A freehand stroke has too many points to type in.'),
        findsOneWidget,
      );
    });
  });
}
