import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

import 'test_utils.dart';

/// Any tap inside the chart selects the one drawing under test.
const _grabAnything = DrawingStyle(hitTestTolerance: 10000);

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 500, height: 600, child: child)),
);

/// A chart with [tool] armed, collecting whatever the user places.
({Widget widget, List<ChartLine> placed, List<KLineEntity> data})
_chartWithTool(
  DrawingTool tool, {
  DrawingStyle style = const DrawingStyle(),
  bool selectAfterDrawing = true,
}) {
  final data = candles(rampThenFall(60));
  DataUtil.calculate(data);
  final placed = <ChartLine>[];

  return (
    data: data,
    placed: placed,
    widget: _host(
      KChartWidget(
        data,
        ChartColors(),
        isTrendLine: true,
        timeFrame: const Duration(minutes: 15),
        showNowPrice: false,
        drawingStyle: style,
        currentDrawingTool: tool,
        selectAfterDrawing: selectAfterDrawing,
        onAddDrawing: placed.add,
      ),
    ),
  );
}

/// A chart drawing [drawings], with the tools live and nothing armed.
({Widget widget, List<ChartLine> removed}) _chartWith(
  List<ChartLine> drawings, {
  DrawingStyle style = _grabAnything,
}) {
  final data = candles(rampThenFall(60));
  DataUtil.calculate(data);
  final removed = <ChartLine>[];

  return (
    removed: removed,
    widget: _host(
      KChartWidget(
        data,
        ChartColors(),
        isTrendLine: true,
        timeFrame: const Duration(minutes: 15),
        showNowPrice: false,
        drawingStyle: style,
        drawings: drawings,
        onRemoveDrawing: removed.add,
      ),
    ),
  );
}

Future<void> _tapAt(WidgetTester tester, Offset at) async {
  await tester.tapAt(at);
  await tester.pumpAndSettle();
}

DateTime _at(int minute) =>
    DateTime.utc(2024, 1, 1).add(Duration(minutes: minute));

void main() {
  group('placing the two-point shapes', () {
    for (final (tool, matcher) in <(DrawingTool, TypeMatcher<ChartLine>)>[
      (DrawingTool.measure, TypeMatcher<MeasureDrawing>()),
      (DrawingTool.ellipse, TypeMatcher<EllipseDrawing>()),
    ]) {
      testWidgets('$tool takes two taps', (tester) async {
        final harness = _chartWithTool(tool);
        await tester.pumpWidget(harness.widget);

        await _tapAt(tester, const Offset(120, 200));
        expect(harness.placed, isEmpty);

        await _tapAt(tester, const Offset(320, 300));

        expect(harness.placed, hasLength(1));
        expect(harness.placed.single, matcher);
        expect((harness.placed.single as TwoPointDrawing).isComplete, isTrue);
      });
    }
  });

  group('placing the three-point shapes', () {
    for (final (tool, matcher) in <(DrawingTool, TypeMatcher<ChartLine>)>[
      (DrawingTool.triangle, TypeMatcher<TriangleDrawing>()),
      (DrawingTool.channel, TypeMatcher<ParallelChannel>()),
      (DrawingTool.position, TypeMatcher<PositionDrawing>()),
    ]) {
      testWidgets('$tool takes three taps', (tester) async {
        final harness = _chartWithTool(tool);
        await tester.pumpWidget(harness.widget);

        await _tapAt(tester, const Offset(120, 300));
        await _tapAt(tester, const Offset(320, 200));
        expect(harness.placed, isEmpty, reason: 'still waiting for the third');

        await _tapAt(tester, const Offset(320, 350));

        expect(harness.placed, hasLength(1));
        expect(harness.placed.single, matcher);
        final shape = harness.placed.single as ThreePointDrawing;
        expect(shape.isComplete, isTrue);
        expect(shape.time3, isNotNull);
        expect(shape.price3, isNotNull);
      });
    }
  });

  group('the note tool', () {
    testWidgets('pins a note with one tap', (tester) async {
      final harness = _chartWithTool(DrawingTool.text);
      await tester.pumpWidget(harness.widget);

      await _tapAt(tester, const Offset(200, 250));

      expect(harness.placed, hasLength(1));
      expect(harness.placed.single, isA<TextAnnotation>());
    });

    testWidgets('the label field types into it', (tester) async {
      final note = TextAnnotation(time: _at(30), price: 120);
      final harness = _chartWith([note]);
      await tester.pumpWidget(harness.widget);

      await tester.tap(find.byType(KChartWidget));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Label'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'CPI print');
      await tester.pumpAndSettle();

      expect(note.text, 'CPI print');
    });
  });

  group('the brush', () {
    testWidgets('lays down a stroke on a drag', (tester) async {
      final harness = _chartWithTool(DrawingTool.brush);
      await tester.pumpWidget(harness.widget);

      final gesture = await tester.startGesture(const Offset(120, 200));
      for (var i = 1; i <= 6; i++) {
        await gesture.moveBy(const Offset(30, 8));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(harness.placed, hasLength(1));
      final stroke = harness.placed.single as FreehandDrawing;
      expect(stroke.points.length, greaterThan(1));
    });

    testWidgets('a press that never moved is not a stroke', (tester) async {
      final harness = _chartWithTool(DrawingTool.brush);
      await tester.pumpWidget(harness.widget);

      final gesture = await tester.startGesture(const Offset(120, 200));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(harness.placed, isEmpty);
    });
  });

  group('what the shapes work out', () {
    test('a measurement reads its own move', () {
      final measure = MeasureDrawing(
        time1: _at(0),
        price1: 100,
        time2: _at(60),
        price2: 110,
      );

      expect(measure.priceMove, 10);
      expect(measure.ratio, closeTo(0.1, 1e-9));
      expect(measure.span, const Duration(minutes: 60));
      expect(measure.isUp, isTrue);
    });

    test('a downward measurement knows it', () {
      final measure = MeasureDrawing(
        time1: _at(0),
        price1: 100,
        time2: _at(10),
        price2: 90,
      );

      expect(measure.isUp, isFalse);
      expect(measure.ratio, closeTo(-0.1, 1e-9));
    });

    test('a channel puts its parallel through the third point', () {
      final channel = ParallelChannel(
        time1: _at(0),
        price1: 100,
        time2: _at(10),
        price2: 110,
        time3: _at(5),
        price3: 115,
      );

      // The base line is at 105 halfway along, so the parallel sits 10 above.
      expect(channel.priceOnBaseLineAt(_at(5)), closeTo(105, 1e-9));
      expect(channel.offset, closeTo(10, 1e-9));
    });

    test('a channel with no second point is flat', () {
      final channel = ParallelChannel(time1: _at(0), price1: 100);

      expect(channel.priceOnBaseLineAt(_at(99)), 100);
      expect(channel.offset, isNull);
      expect(channel.isComplete, isFalse);
    });

    test('a long position works out its reward against its risk', () {
      final position = PositionDrawing(
        time1: _at(0),
        price1: 100,
        time2: _at(20),
        price2: 130,
        time3: _at(20),
        price3: 90,
      );

      expect(position.isLong, isTrue);
      expect(position.reward, 30);
      expect(position.risk, 10);
      expect(position.riskReward, closeTo(3, 1e-9));
    });

    test('a short position is read the other way round', () {
      final position = PositionDrawing(
        time1: _at(0),
        price1: 100,
        time2: _at(20),
        price2: 80,
        time3: _at(20),
        price3: 105,
      );

      expect(position.isLong, isFalse);
      expect(position.reward, 20);
      expect(position.risk, 5);
      expect(position.riskReward, closeTo(4, 1e-9));
    });

    test('a position with no stop has no ratio', () {
      final position = PositionDrawing(
        time1: _at(0),
        price1: 100,
        time2: _at(20),
        price2: 130,
      );

      expect(position.risk, isNull);
      expect(position.riskReward, isNull);
    });

    test('a freehand stroke drops repeated points', () {
      final stroke = FreehandDrawing()
        ..extendTo((time: _at(1), price: 10))
        ..extendTo((time: _at(1), price: 10))
        ..extendTo((time: _at(2), price: 11));

      expect(stroke.points, hasLength(2));
      expect(stroke.isComplete, isTrue);
    });
  });

  group('selecting and deleting the new shapes', () {
    final samples = <ChartLine>[
      MeasureDrawing(time1: _at(10), price1: 105, time2: _at(30), price2: 120),
      EllipseDrawing(time1: _at(10), price1: 105, time2: _at(30), price2: 120),
      TriangleDrawing(
        time1: _at(10),
        price1: 105,
        time2: _at(30),
        price2: 120,
        time3: _at(40),
        price3: 110,
      ),
      ParallelChannel(
        time1: _at(10),
        price1: 105,
        time2: _at(30),
        price2: 120,
        time3: _at(20),
        price3: 118,
      ),
      PositionDrawing(
        time1: _at(10),
        price1: 105,
        time2: _at(30),
        price2: 120,
        time3: _at(30),
        price3: 100,
      ),
      TextAnnotation(time: _at(20), price: 110, text: 'note'),
      FreehandDrawing(
        points: [(time: _at(10), price: 105), (time: _at(20), price: 110)],
      ),
    ];

    for (final sample in samples) {
      testWidgets('${sample.runtimeType} can be selected and deleted', (
        tester,
      ) async {
        final harness = _chartWith([sample]);
        await tester.pumpWidget(harness.widget);

        await tester.tap(find.byType(KChartWidget));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Delete'), findsOneWidget);

        await tester.tap(find.byTooltip('Delete'));
        await tester.pumpAndSettle();

        expect(harness.removed, [same(sample)]);
      });
    }

    testWidgets('every new shape renders without blowing up', (tester) async {
      final harness = _chartWith(samples);
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('a half-placed shape renders too', (tester) async {
      final harness = _chartWith([
        TriangleDrawing(
          time1: _at(10),
          price1: 105,
          time2: _at(20),
          price2: 110,
        ),
        ParallelChannel(
          time1: _at(10),
          price1: 105,
          time2: _at(20),
          price2: 110,
        ),
        PositionDrawing(time1: _at(10), price1: 105),
        TextAnnotation(time: _at(15), price: 108),
        FreehandDrawing(),
      ]);
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('the fill slider', () {
    testWidgets('washes the inside of a shape', (tester) async {
      final oval = EllipseDrawing(
        time1: _at(10),
        price1: 105,
        time2: _at(30),
        price2: 120,
      );
      await tester.pumpWidget(_chartWith([oval]).widget);

      await tester.tap(find.byType(KChartWidget));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Fill'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Slider), const Offset(200, 0));
      await tester.pumpAndSettle();

      expect(oval.fillOpacity, greaterThan(0.12));
    });

    testWidgets('is absent for a line with no inside', (tester) async {
      await tester.pumpWidget(_chartWith([HorizontalLine(price: 110)]).widget);

      await tester.tap(find.byType(KChartWidget));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Fill'), findsNothing);
    });
  });

  group('level alerts', () {
    testWidgets('fire when the newest candle crosses', (tester) async {
      final data = candles([for (var i = 0; i < 40; i++) 100.0]);
      DataUtil.calculate(data);
      final level = HorizontalLine(price: 105, alert: true);
      final crossings = <double>[];

      Widget build() => _host(
        KChartWidget(
          data,
          ChartColors(),
          isTrendLine: true,
          timeFrame: const Duration(minutes: 15),
          showNowPrice: false,
          drawings: [level],
          onAlertCrossed: (line, candle) => crossings.add(candle.close),
        ),
      );

      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      expect(
        crossings,
        isEmpty,
        reason: 'the first frame only takes a reading',
      );

      data.last.close = 110;
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      expect(crossings, [110]);

      // Still above: the same crossing is not reported twice.
      data.last.close = 111;
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      expect(crossings, [110]);

      data.last.close = 99;
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      expect(crossings, [110, 99]);
    });

    testWidgets('a level with no alert stays quiet', (tester) async {
      final data = candles([for (var i = 0; i < 40; i++) 100.0]);
      DataUtil.calculate(data);
      final level = HorizontalLine(price: 105);
      var fired = 0;

      Widget build() => _host(
        KChartWidget(
          data,
          ChartColors(),
          isTrendLine: true,
          timeFrame: const Duration(minutes: 15),
          showNowPrice: false,
          drawings: [level],
          onAlertCrossed: (line, candle) => fired++,
        ),
      );

      await tester.pumpWidget(build());
      data.last.close = 110;
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      expect(fired, 0);
    });

    testWidgets('the toolbar arms one', (tester) async {
      final level = HorizontalLine(price: 110);
      await tester.pumpWidget(_chartWith([level]).widget);

      await tester.tap(find.byType(KChartWidget));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Alert me here'));
      await tester.pumpAndSettle();

      expect(level.alert, isTrue);
      expect(find.byTooltip('Remove alert'), findsOneWidget);
    });
  });

  group('drawing several in a row', () {
    testWidgets('selectAfterDrawing off leaves the editor closed', (
      tester,
    ) async {
      final harness = _chartWithTool(
        DrawingTool.horizontal,
        selectAfterDrawing: false,
      );
      await tester.pumpWidget(harness.widget);

      await _tapAt(tester, const Offset(200, 250));

      expect(harness.placed, hasLength(1));
      expect(find.byTooltip('Delete'), findsNothing);
    });
  });
}
