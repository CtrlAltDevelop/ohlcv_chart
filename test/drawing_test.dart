import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

import 'test_utils.dart';

/// Any tap inside the chart selects the one line under test, so the toolbar can
/// be exercised without guessing where a price lands on screen.
const _grabAnything = DrawingStyle(hitTestTolerance: 10000);

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 500, height: 600, child: child)),
);

/// A chart holding a single [HorizontalLine], with the drawing tools enabled.
({Widget widget, HorizontalLine line, List<ChartLine> persisted})
_chartWithLine({
  DrawingStyle style = _grabAnything,
  ChartTranslations translations = const ChartTranslations(),
}) {
  final data = candles(rampThenFall(60));
  DataUtil.calculate(data);

  final line = HorizontalLine(price: data[30].close, title: 'entry');
  final persisted = <ChartLine>[];

  return (
    line: line,
    persisted: persisted,
    widget: _host(
      KChartWidget(
        data,
        ChartColors(),
        isTrendLine: true,
        watermarkAssetPath: 'assets/none.svg',
        timeFrame: const Duration(minutes: 15),
        showNowPrice: false,
        drawingStyle: style,
        chartTranslations: translations,
        horizontalLines: [line],
        onAddHorizontalLine: persisted.add,
      ),
    ),
  );
}

/// Finds a colour swatch by the colour it paints.
Finder _swatch(Color color) => find.byWidgetPredicate(
  (widget) =>
      widget is Container &&
      widget.decoration is BoxDecoration &&
      (widget.decoration! as BoxDecoration).color == color &&
      (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
);

Future<void> _selectLine(WidgetTester tester) async {
  await tester.tap(find.byType(KChartWidget));
  await tester.pumpAndSettle();
}

/// A chart with [tool] armed and nothing drawn yet, collecting whatever the
/// user places.
({Widget widget, List<ChartLine> placed}) _chartWithTool(
  DrawingTool tool, {
  bool magnetMode = false,
  DrawingStyle style = const DrawingStyle(),
  List<KLineEntity>? data,
}) {
  final candleData = data ?? candles(rampThenFall(60));
  DataUtil.calculate(candleData);
  final placed = <ChartLine>[];

  return (
    placed: placed,
    widget: _host(
      KChartWidget(
        candleData,
        ChartColors(),
        isTrendLine: true,
        watermarkAssetPath: 'assets/none.svg',
        timeFrame: const Duration(minutes: 15),
        showNowPrice: false,
        currentDrawingTool: tool,
        magnetMode: magnetMode,
        drawingStyle: style,
        onAddTrendLine: placed.add,
        onAddHorizontalLine: placed.add,
        onAddVerticalLine: placed.add,
        onAddRectangle: placed.add,
        onAddFibRetracement: placed.add,
      ),
    ),
  );
}

void main() {
  group('ChartLine', () {
    test('style and isDashed agree', () {
      final line = HorizontalLine(price: 1);
      expect(line.style, LineStyle.solid);
      expect(line.isDashed, isFalse);

      line.isDashed = true;
      expect(line.style, LineStyle.dashed);

      line.style = LineStyle.dotted;
      expect(line.isDashed, isTrue, reason: 'dotted is a broken stroke too');

      line.isDashed = false;
      expect(line.style, LineStyle.solid);
    });

    test('a line built with isDashed keeps drawing dashed', () {
      expect(HorizontalLine(price: 1, isDashed: true).style, LineStyle.dashed);
      expect(
        HorizontalLine(price: 1, style: LineStyle.dotted).style,
        LineStyle.dotted,
      );
    });

    test('opacity is the colour alpha', () {
      final line = TrendLine(time1: DateTime(2024), price1: 1);
      line.opacity = 0.5;
      expect(line.opacity, closeTo(0.5, 0.01));
      expect(line.color.a, closeTo(0.5, 0.01));

      line.opacity = 4;
      expect(line.opacity, 1.0, reason: 'clamped');
    });
  });

  group('DrawingStyle', () {
    test('the thickness slider widens to hold every preset', () {
      const style = DrawingStyle(thicknessOptions: [0.25, 12]);
      expect(style.thicknessRange, (0.25, 12.0));
    });

    test('copyWith replaces one field and keeps the rest', () {
      const style = DrawingStyle(swatchesPerRow: 3);
      final copy = style.copyWith(iconSize: 30);
      expect(copy.iconSize, 30);
      expect(copy.swatchesPerRow, 3);
    });
  });

  group('DrawingToolbar', () {
    testWidgets('appears once a line is selected and dismisses on done', (
      tester,
    ) async {
      final harness = _chartWithLine();
      await tester.pumpWidget(harness.widget);
      expect(find.byTooltip('Colour'), findsNothing);

      await _selectLine(tester);
      expect(find.byTooltip('Colour'), findsOne);

      await tester.tap(find.byTooltip('Done'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Colour'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('only shows the controls the style enables', (tester) async {
      final harness = _chartWithLine(
        style: _grabAnything.copyWith(
          showThicknessControl: false,
          showLineStyleControl: false,
          showLabelTextControl: false,
          showLockControl: false,
        ),
      );
      await tester.pumpWidget(harness.widget);
      await _selectLine(tester);

      expect(find.byTooltip('Colour'), findsOne);
      expect(find.byTooltip('Thickness'), findsNothing);
      expect(find.byTooltip('Style'), findsNothing);
      expect(find.byTooltip('Label'), findsNothing);
      expect(find.byTooltip('Lock'), findsNothing);
      expect(find.byTooltip('Delete'), findsOne);
    });

    testWidgets('picking a colour restyles the line and reports it', (
      tester,
    ) async {
      const teal = Color(0xFF00BFA5);
      final harness = _chartWithLine(
        style: _grabAnything.copyWith(colorOptions: const [teal]),
      );
      await tester.pumpWidget(harness.widget);
      await _selectLine(tester);

      await tester.tap(find.byTooltip('Colour'));
      await tester.pumpAndSettle();
      await tester.tap(_swatch(teal).first);
      await tester.pumpAndSettle();

      expect(harness.line.color, teal);
      expect(harness.persisted, [
        harness.line,
      ], reason: 'an edit is reported so the host can persist it');
    });

    testWidgets('the opacity slider dims the line without losing its hue', (
      tester,
    ) async {
      const teal = Color(0xFF00BFA5);
      final harness = _chartWithLine(
        style: _grabAnything.copyWith(
          colorOptions: const [teal],
          showThicknessControl: false,
        ),
      );
      await tester.pumpWidget(harness.widget);
      await _selectLine(tester);

      await tester.tap(find.byTooltip('Colour'));
      await tester.pumpAndSettle();
      await tester.tap(_swatch(teal).first);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Slider), const Offset(-200, 0));
      await tester.pumpAndSettle();

      expect(harness.line.opacity, lessThan(1.0));
      expect(harness.line.color.r, closeTo(teal.r, 0.01));
      expect(harness.line.color.g, closeTo(teal.g, 0.01));
      expect(harness.persisted, isNotEmpty);
    });

    testWidgets('the thickness slider resizes the stroke', (tester) async {
      final harness = _chartWithLine(
        style: _grabAnything.copyWith(showColorControl: false),
      );
      await tester.pumpWidget(harness.widget);
      await _selectLine(tester);

      await tester.tap(find.byTooltip('Thickness'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Slider), const Offset(200, 0));
      await tester.pumpAndSettle();

      expect(harness.line.thickness, greaterThan(2.0));
      expect(harness.persisted, isNotEmpty);
    });

    testWidgets('the style picker switches the stroke to dotted', (
      tester,
    ) async {
      final harness = _chartWithLine();
      await tester.pumpWidget(harness.widget);
      await _selectLine(tester);

      await tester.tap(find.byTooltip('Style'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dotted'));
      await tester.pumpAndSettle();

      expect(harness.line.style, LineStyle.dotted);
      expect(harness.persisted, isNotEmpty);
    });

    testWidgets('the label field renames the line and reveals the label', (
      tester,
    ) async {
      final harness = _chartWithLine();
      harness.line.showLabel = false;
      await tester.pumpWidget(harness.widget);
      await _selectLine(tester);

      await tester.tap(find.byTooltip('Label'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'take profit');
      await tester.pumpAndSettle();

      expect(harness.line.title, 'take profit');
      expect(harness.line.showLabel, isTrue);
    });

    testWidgets('lock and label visibility toggle', (tester) async {
      final harness = _chartWithLine();
      expect(
        harness.line.showLabel,
        isFalse,
        reason: 'the default for a price',
      );
      await tester.pumpWidget(harness.widget);
      await _selectLine(tester);

      await tester.tap(find.byTooltip('Lock'));
      await tester.pumpAndSettle();
      expect(harness.line.locked, isTrue);
      expect(find.byTooltip('Unlock'), findsOne);

      await tester.tap(find.byTooltip('Show label'));
      await tester.pumpAndSettle();
      expect(harness.line.showLabel, isTrue);
      expect(find.byTooltip('Hide label'), findsOne);
    });

    testWidgets('delete removes the line through the callback', (tester) async {
      final data = candles(rampThenFall(60));
      DataUtil.calculate(data);
      final lines = [HorizontalLine(price: data[30].close)];
      final removed = <HorizontalLine>[];

      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) => KChartWidget(
              data,
              ChartColors(),
              isTrendLine: true,
              watermarkAssetPath: 'assets/none.svg',
              timeFrame: const Duration(minutes: 15),
              showNowPrice: false,
              drawingStyle: _grabAnything,
              horizontalLines: lines,
              onRemoveHorizontalLine: (line) => setState(() {
                removed.add(line);
                lines.remove(line);
              }),
            ),
          ),
        ),
      );
      await _selectLine(tester);

      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();

      expect(removed, hasLength(1));
      expect(lines, isEmpty);
      expect(find.byTooltip('Delete'), findsNothing);
    });

    testWidgets('translations reach every control', (tester) async {
      final harness = _chartWithLine(
        translations: const ChartTranslations(
          drawing: DrawingTranslations(
            color: 'Couleur',
            thickness: 'Épaisseur',
            delete: 'Supprimer',
          ),
        ),
      );
      await tester.pumpWidget(harness.widget);
      await _selectLine(tester);

      expect(find.byTooltip('Couleur'), findsOne);
      expect(find.byTooltip('Épaisseur'), findsOne);
      expect(find.byTooltip('Supprimer'), findsOne);
    });

    testWidgets('dragging a trend line by its stroke moves both ends', (
      tester,
    ) async {
      final data = candles(rampThenFall(60));
      DataUtil.calculate(data);

      final line = TrendLine(
        time1: data[10].dateTime!,
        price1: data[10].close,
        time2: data[40].dateTime!,
        price2: data[40].close,
      );
      final before = (line.time1, line.price1, line.time2, line.price2);

      await tester.pumpWidget(
        _host(
          KChartWidget(
            data,
            ChartColors(),
            isTrendLine: true,
            watermarkAssetPath: 'assets/none.svg',
            timeFrame: const Duration(minutes: 15),
            showNowPrice: false,
            // Ends unreachable, stroke reachable: every grab is a body grab.
            drawingStyle: const DrawingStyle(
              hitTestTolerance: 10000,
              handleHitTestTolerance: 0,
            ),
            trendLines: [line],
          ),
        ),
      );

      await tester.drag(find.byType(KChartWidget), const Offset(-40, -60));
      await tester.pumpAndSettle();

      expect(line.price1, greaterThan(before.$2));
      expect(line.price2, greaterThan(before.$4!));
      expect(
        line.price1 - before.$2,
        closeTo(line.price2! - before.$4!, 0.001),
        reason: 'both ends shift by the same amount of price',
      );
      expect(
        line.time2!.difference(line.time1),
        before.$3!.difference(before.$1),
        reason: 'and the line keeps its length in time',
      );
    });

    testWidgets('a locked line stays put when dragged', (tester) async {
      final harness = _chartWithLine();
      harness.line.locked = true;
      final price = harness.line.price;

      await tester.pumpWidget(harness.widget);
      await _selectLine(tester);
      await tester.drag(find.byType(KChartWidget), const Offset(0, -80));
      await tester.pumpAndSettle();

      expect(harness.line.price, price);
    });
  });

  group('placing a line', () {
    testWidgets('a trend line takes one tap per end', (tester) async {
      final harness = _chartWithTool(DrawingTool.trend);
      await tester.pumpWidget(harness.widget);

      await tester.tapAt(const Offset(120, 200));
      await tester.pumpAndSettle();
      expect(harness.placed, isEmpty, reason: 'one end is not a line yet');

      await tester.tapAt(const Offset(320, 300));
      await tester.pumpAndSettle();

      expect(harness.placed, hasLength(1));
      final line = harness.placed.single as TrendLine;
      expect(line.time2, isNotNull);
      expect(line.price2, isNotNull);
      expect(line.time2, isNot(line.time1));
    });

    testWidgets('dragging from end to end still draws a trend line', (
      tester,
    ) async {
      final harness = _chartWithTool(DrawingTool.trend);
      await tester.pumpWidget(harness.widget);

      await tester.dragFrom(const Offset(120, 200), const Offset(180, 80));
      await tester.pumpAndSettle();

      expect(harness.placed, hasLength(1));
      expect((harness.placed.single as TrendLine).time2, isNotNull);
    });

    testWidgets('one tap is a whole horizontal line', (tester) async {
      final harness = _chartWithTool(DrawingTool.horizontal);
      await tester.pumpWidget(harness.widget);

      await tester.tapAt(const Offset(200, 220));
      await tester.pumpAndSettle();

      expect(harness.placed, hasLength(1));
      expect(harness.placed.single, isA<HorizontalLine>());
    });

    testWidgets('one tap is a whole vertical line', (tester) async {
      final harness = _chartWithTool(DrawingTool.vertical);
      await tester.pumpWidget(harness.widget);

      await tester.tapAt(const Offset(200, 220));
      await tester.pumpAndSettle();

      expect(harness.placed, hasLength(1));
      expect(harness.placed.single, isA<VerticalLine>());
    });

    testWidgets('escape throws away a half-drawn trend line', (tester) async {
      final harness = _chartWithTool(DrawingTool.trend);
      await tester.pumpWidget(harness.widget);

      await tester.tapAt(const Offset(120, 200));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // The anchor is gone, so this tap starts a new line rather than
      // finishing the abandoned one.
      await tester.tapAt(const Offset(320, 300));
      await tester.pumpAndSettle();
      expect(harness.placed, isEmpty);
    });

    testWidgets('hovering an armed tool previews without placing anything', (
      tester,
    ) async {
      final harness = _chartWithTool(DrawingTool.horizontal);
      await tester.pumpWidget(harness.widget);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(150, 180));
      addTearDown(mouse.removePointer);
      await tester.pump();
      await mouse.moveTo(const Offset(220, 260));
      await tester.pumpAndSettle();

      expect(harness.placed, isEmpty, reason: 'a preview is not a line');

      // The editor belongs to finished lines, not to the preview.
      expect(find.byTooltip('Colour'), findsNothing);
    });

    testWidgets('magnet mode lands the point on a candle price', (
      tester,
    ) async {
      final data = candles(rampThenFall(60));
      final harness = _chartWithTool(
        DrawingTool.horizontal,
        magnetMode: true,
        // Anywhere on the chart is "close enough", so the snap is certain.
        style: const DrawingStyle(magnetSnapDistance: 10000),
        data: data,
      );
      await tester.pumpWidget(harness.widget);

      await tester.tapAt(const Offset(200, 220));
      await tester.pumpAndSettle();

      final price = (harness.placed.single as HorizontalLine).price;
      expect(
        data.any(
          (c) =>
              c.open == price ||
              c.high == price ||
              c.low == price ||
              c.close == price,
        ),
        isTrue,
        reason: 'the price snapped to an OHLC value',
      );
    });

    testWidgets('magnet mode snaps an anchor being dragged, not just placed', (
      tester,
    ) async {
      final data = candles(rampThenFall(60));
      DataUtil.calculate(data);

      // Deliberately off any candle value, so a snap is visible.
      final line = TrendLine(
        time1: data[10].dateTime!,
        price1: data[10].close + 3.7,
        time2: data[40].dateTime!,
        price2: data[40].close + 3.7,
      );

      await tester.pumpWidget(
        _host(
          KChartWidget(
            data,
            ChartColors(),
            isTrendLine: true,
            watermarkAssetPath: 'assets/none.svg',
            timeFrame: const Duration(minutes: 15),
            showNowPrice: false,
            magnetMode: true,
            // Handles reachable and the stroke not, so a grab takes an anchor
            // rather than the body — and anywhere is within the snap.
            drawingStyle: const DrawingStyle(
              hitTestTolerance: 0,
              handleHitTestTolerance: 10000,
              magnetSnapDistance: 10000,
            ),
            trendLines: [line],
          ),
        ),
      );

      await tester.drag(find.byType(KChartWidget), const Offset(30, -40));
      await tester.pumpAndSettle();

      bool isCandleValue(double? price) => data.any(
        (c) =>
            c.open == price ||
            c.high == price ||
            c.low == price ||
            c.close == price,
      );

      expect(
        isCandleValue(line.price1) || isCandleValue(line.price2),
        isTrue,
        reason: 'the dragged anchor landed on an OHLC value',
      );
    });

    testWidgets('a whole-drawing drag keeps its shape under magnet mode', (
      tester,
    ) async {
      final data = candles(rampThenFall(60));
      DataUtil.calculate(data);

      final line = TrendLine(
        time1: data[10].dateTime!,
        price1: data[10].close,
        time2: data[40].dateTime!,
        price2: data[40].close,
      );
      final span = line.price2! - line.price1;

      await tester.pumpWidget(
        _host(
          KChartWidget(
            data,
            ChartColors(),
            isTrendLine: true,
            watermarkAssetPath: 'assets/none.svg',
            timeFrame: const Duration(minutes: 15),
            showNowPrice: false,
            magnetMode: true,
            // Stroke reachable, ends not: every grab moves the whole line.
            drawingStyle: const DrawingStyle(
              hitTestTolerance: 10000,
              handleHitTestTolerance: 0,
              magnetSnapDistance: 10000,
            ),
            trendLines: [line],
          ),
        ),
      );

      await tester.drag(find.byType(KChartWidget), const Offset(-40, -60));
      await tester.pumpAndSettle();

      // Snapping one end of a delta would stretch the line; it must not.
      expect(
        line.price2! - line.price1,
        closeTo(span, 0.001),
        reason: 'a body drag shifts the line rather than snapping an end',
      );
    });
  });

  group('shapes', () {
    /// Places a two-point shape with a tap at each end.
    Future<ChartLine> place(WidgetTester tester, DrawingTool tool) async {
      final harness = _chartWithTool(tool);
      await tester.pumpWidget(harness.widget);
      await tester.tapAt(const Offset(140, 180));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(320, 300));
      await tester.pumpAndSettle();
      return harness.placed.single;
    }

    testWidgets('a ray extends past its second end', (tester) async {
      final line = await place(tester, DrawingTool.ray) as TrendLine;
      expect(line.extend, LineExtension.right);
      expect(line.arrow, isFalse);
      expect(line.isComplete, isTrue);
    });

    testWidgets('an extended line runs both ways', (tester) async {
      final line = await place(tester, DrawingTool.extendedLine) as TrendLine;
      expect(line.extend, LineExtension.both);
    });

    testWidgets('an arrow keeps its head and stops at its end', (tester) async {
      final line = await place(tester, DrawingTool.arrow) as TrendLine;
      expect(line.arrow, isTrue);
      expect(line.extend, LineExtension.none);
    });

    testWidgets('a horizontal ray starts where it was tapped', (tester) async {
      final harness = _chartWithTool(DrawingTool.horizontalRay);
      await tester.pumpWidget(harness.widget);

      await tester.tapAt(const Offset(220, 240));
      await tester.pumpAndSettle();

      final line = harness.placed.single as HorizontalLine;
      expect(line.isRay, isTrue, reason: 'one tap is the whole ray');
      expect(line.startTime, isNotNull);
    });

    testWidgets('a rectangle takes two opposite corners', (tester) async {
      final box =
          await place(tester, DrawingTool.rectangle) as RectangleDrawing;
      expect(box.isComplete, isTrue);
      expect(box.price2, isNot(box.price1));
      expect(
        box.fillColor.a,
        lessThan(box.color.a),
        reason: 'the inside is a wash, not a block of colour',
      );
    });

    testWidgets('a retracement carries the default levels', (tester) async {
      final fib =
          await place(tester, DrawingTool.fibRetracement) as FibRetracement;
      expect(fib.levels, FibRetracement.defaultLevels);
      expect(fib.priceAt(0), fib.price1);
      expect(fib.priceAt(1), fib.price2);
      expect(
        fib.priceAt(0.5),
        closeTo((fib.price1 + fib.price2!) / 2, 0.000001),
      );
    });

    testWidgets('retracement levels can be configured', (tester) async {
      final harness = _chartWithTool(
        DrawingTool.fibRetracement,
        style: const DrawingStyle(fibLevels: [0, 0.5, 1]),
      );
      await tester.pumpWidget(harness.widget);
      await tester.tapAt(const Offset(140, 180));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(320, 300));
      await tester.pumpAndSettle();

      expect((harness.placed.single as FibRetracement).levels, [0, 0.5, 1]);
    });

    testWidgets('every new shape renders without blowing up', (tester) async {
      for (final tool in [
        DrawingTool.ray,
        DrawingTool.extendedLine,
        DrawingTool.arrow,
        DrawingTool.rectangle,
        DrawingTool.fibRetracement,
      ]) {
        await place(tester, tool);
        expect(tester.takeException(), isNull, reason: '$tool');
      }
    });

    testWidgets('the label field names a rectangle', (tester) async {
      final data = candles(rampThenFall(60));
      DataUtil.calculate(data);
      final box = RectangleDrawing(
        time1: data[20].dateTime!,
        price1: data[20].close,
        time2: data[40].dateTime!,
        price2: data[40].close,
      );

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
            rectangles: [box],
          ),
        ),
      );
      await _selectLine(tester);

      await tester.tap(find.byTooltip('Label'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'supply zone');
      await tester.pumpAndSettle();

      expect(box.label, 'supply zone');
      expect(box.showLabel, isTrue);
    });

    testWidgets('a drawn shape can be selected and dragged as a whole', (
      tester,
    ) async {
      final data = candles(rampThenFall(60));
      DataUtil.calculate(data);
      final box = RectangleDrawing(
        time1: data[20].dateTime!,
        price1: data[20].close,
        time2: data[40].dateTime!,
        price2: data[40].close,
      );
      final saved = <ChartLine>[];

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
            rectangles: [box],
            onAddRectangle: saved.add,
          ),
        ),
      );

      final before = (box.time1, box.price1);
      await tester.drag(find.byType(KChartWidget), const Offset(-40, -60));
      await tester.pumpAndSettle();

      expect(saved, contains(box), reason: 'the move is reported for saving');
      expect((box.time1, box.price1), isNot(before));
      expect(box.isComplete, isTrue, reason: 'both corners moved together');
    });
  });
}
