import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart/src/drawing/shape_geometry.dart';

import 'test_utils.dart';

/// Any tap inside the chart selects the one drawing under test.
const _grabAnything = DrawingStyle(hitTestTolerance: 10000);

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 500, height: 600, child: child)),
);

/// A chart with [tool] armed, collecting whatever the user places.
({Widget widget, List<ChartLine> placed, List<KLineEntity> data})
_chartWithTool(DrawingTool tool) {
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
        watermarkAssetPath: 'assets/none.svg',
        timeFrame: const Duration(minutes: 15),
        showNowPrice: false,
        currentDrawingTool: tool,
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
        watermarkAssetPath: 'assets/none.svg',
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
  group('placing the new two-point tools', () {
    for (final (tool, matcher) in <(DrawingTool, TypeMatcher<ChartLine>)>[
      (DrawingTool.gannFan, TypeMatcher<GannFan>()),
      (DrawingTool.gannBox, TypeMatcher<GannBox>()),
      (DrawingTool.fibFan, TypeMatcher<FibFan>()),
      (DrawingTool.fibTimeZones, TypeMatcher<FibTimeZones>()),
      (DrawingTool.regressionTrend, TypeMatcher<RegressionChannel>()),
      (DrawingTool.priceRange, TypeMatcher<PriceRangeDrawing>()),
      (DrawingTool.dateRange, TypeMatcher<DateRangeDrawing>()),
      (DrawingTool.callout, TypeMatcher<CalloutDrawing>()),
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

  group('placing the new three-point tools', () {
    for (final (tool, matcher) in <(DrawingTool, TypeMatcher<ChartLine>)>[
      (DrawingTool.pitchfork, TypeMatcher<PitchforkDrawing>()),
      (DrawingTool.fibExtension, TypeMatcher<FibExtension>()),
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
        expect(shape.price3, isNotNull);
      });
    }
  });

  group('the flag tool', () {
    testWidgets('plants a flag with one tap', (tester) async {
      final harness = _chartWithTool(DrawingTool.flag);
      await tester.pumpWidget(harness.widget);

      await _tapAt(tester, const Offset(200, 250));

      expect(harness.placed, hasLength(1));
      expect(harness.placed.single, isA<FlagDrawing>());
    });

    testWidgets('the staff is grabbable above the point it stands on', (
      tester,
    ) async {
      final flag = FlagDrawing(time: _at(30), price: 120, staffHeight: 40);
      final harness = _chartWith(
        [flag],
        // Tight enough that only the staff itself answers.
        style: const DrawingStyle(hitTestTolerance: 6),
      );
      await tester.pumpWidget(harness.widget);

      // Far from the flag: nothing selected, so no editor.
      await _tapAt(tester, const Offset(40, 500));
      expect(find.byTooltip('Delete'), findsNothing);
    });
  });

  group('the xabcd tool', () {
    testWidgets('takes five taps, one per point', (tester) async {
      final harness = _chartWithTool(DrawingTool.xabcd);
      await tester.pumpWidget(harness.widget);

      for (final at in const [
        Offset(80, 400),
        Offset(160, 200),
        Offset(240, 320),
        Offset(320, 180),
        Offset(400, 300),
      ]) {
        expect(
          harness.placed,
          isEmpty,
          reason: 'not finished before the fifth',
        );
        await _tapAt(tester, at);
      }

      expect(harness.placed, hasLength(1));
      final pattern = harness.placed.single as XabcdDrawing;
      expect(pattern.points, hasLength(5));
      expect(pattern.isComplete, isTrue);
      expect(pattern.acceptsMorePoints, isFalse);
    });

    test('each leg reads out its retracement of the one before', () {
      final pattern = XabcdDrawing(
        points: [
          (time: _at(0), price: 100),
          (time: _at(10), price: 120),
          (time: _at(20), price: 110),
          (time: _at(30), price: 130),
          (time: _at(40), price: 120),
        ],
      );

      expect(
        pattern.retracementAt(0),
        isNull,
        reason: 'X has no leg behind it',
      );
      expect(pattern.retracementAt(1), isNull);
      // AB is 10 against XA's 20.
      expect(pattern.retracementAt(2), closeTo(0.5, 1e-9));
      // BC is 20 against AB's 10.
      expect(pattern.retracementAt(3), closeTo(2, 1e-9));
      // CD is 10 against BC's 20.
      expect(pattern.retracementAt(4), closeTo(0.5, 1e-9));
    });
  });

  group('the path tool', () {
    testWidgets('keeps taking taps until a repeat finishes it', (tester) async {
      final harness = _chartWithTool(DrawingTool.path);
      await tester.pumpWidget(harness.widget);

      // Each tap lands somewhere new, so however fast they come none of them
      // reads as the repeat that finishes the path.
      for (final at in const [
        Offset(80, 400),
        Offset(160, 300),
        Offset(240, 350),
        Offset(320, 220),
      ]) {
        await _tapAt(tester, at);
      }
      expect(harness.placed, isEmpty, reason: 'a path is never done counting');

      // Twice in the same place says it is finished.
      await tester.tapAt(const Offset(400, 260));
      await tester.tapAt(const Offset(400, 260));
      await tester.pumpAndSettle();

      expect(harness.placed, hasLength(1));
      final path = harness.placed.single as PathDrawing;
      expect(path.points.length, greaterThanOrEqualTo(4));
      expect(path.isComplete, isTrue);
      expect(path.acceptsMorePoints, isTrue, reason: 'it never stops taking');
    });

    testWidgets('disarming the tool finishes it rather than losing it', (
      tester,
    ) async {
      final data = candles(rampThenFall(60));
      DataUtil.calculate(data);
      final placed = <ChartLine>[];

      Widget chart(DrawingTool tool) => _host(
        KChartWidget(
          data,
          ChartColors(),
          isTrendLine: true,
          watermarkAssetPath: 'assets/none.svg',
          timeFrame: const Duration(minutes: 15),
          showNowPrice: false,
          currentDrawingTool: tool,
          onAddDrawing: placed.add,
        ),
      );

      await tester.pumpWidget(chart(DrawingTool.path));
      await _tapAt(tester, const Offset(100, 400));
      await _tapAt(tester, const Offset(200, 300));
      await _tapAt(tester, const Offset(300, 350));
      expect(placed, isEmpty);

      await tester.pumpWidget(chart(DrawingTool.none));
      await tester.pumpAndSettle();

      expect(placed, hasLength(1));
      expect(placed.single, isA<PathDrawing>());
    });

    test('a path with too little to draw is not a path', () {
      final path = PathDrawing(points: [(time: _at(0), price: 100)]);
      expect(path.isComplete, isFalse);
      expect(path.pointCount, isNull);
    });
  });

  group('selecting and deleting the new shapes', () {
    final samples = <ChartLine>[
      PitchforkDrawing(
        time1: _at(10),
        price1: 105,
        time2: _at(30),
        price2: 120,
        time3: _at(40),
        price3: 100,
      ),
      GannFan(time1: _at(10), price1: 105, time2: _at(30), price2: 120),
      GannBox(time1: _at(10), price1: 105, time2: _at(30), price2: 120),
      FibExtension(
        time1: _at(10),
        price1: 105,
        time2: _at(30),
        price2: 120,
        time3: _at(40),
        price3: 112,
      ),
      FibFan(time1: _at(10), price1: 105, time2: _at(30), price2: 120),
      FibTimeZones(time1: _at(10), price1: 105, time2: _at(20), price2: 120),
      RegressionChannel(
        time1: _at(5),
        price1: 105,
        time2: _at(40),
        price2: 120,
      ),
      XabcdDrawing(
        points: [
          (time: _at(0), price: 100),
          (time: _at(10), price: 120),
          (time: _at(20), price: 110),
          (time: _at(30), price: 130),
          (time: _at(40), price: 120),
        ],
      ),
      PriceRangeDrawing(
        time1: _at(10),
        price1: 105,
        time2: _at(30),
        price2: 120,
      ),
      DateRangeDrawing(
        time1: _at(10),
        price1: 105,
        time2: _at(30),
        price2: 120,
      ),
      CalloutDrawing(
        time1: _at(10),
        price1: 105,
        time2: _at(30),
        price2: 120,
        text: 'here',
      ),
      PathDrawing(
        points: [
          (time: _at(0), price: 100),
          (time: _at(10), price: 120),
          (time: _at(20), price: 110),
        ],
      ),
      FlagDrawing(time: _at(20), price: 110, text: 'earnings'),
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
      await tester.pumpWidget(_chartWith(samples).widget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a half-placed one renders too', (tester) async {
      await tester.pumpWidget(
        _chartWith([
          PitchforkDrawing(time1: _at(10), price1: 105),
          GannFan(time1: _at(10), price1: 105),
          GannBox(time1: _at(10), price1: 105),
          FibExtension(
            time1: _at(10),
            price1: 105,
            time2: _at(20),
            price2: 115,
          ),
          FibFan(time1: _at(10), price1: 105),
          FibTimeZones(time1: _at(10), price1: 105),
          RegressionChannel(time1: _at(10), price1: 105),
          PriceRangeDrawing(time1: _at(10), price1: 105),
          DateRangeDrawing(time1: _at(10), price1: 105),
          CalloutDrawing(time1: _at(10), price1: 105),
          XabcdDrawing(points: [(time: _at(10), price: 105)]),
          PathDrawing(points: [(time: _at(10), price: 105)]),
        ]).widget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a shape whose candles are gone is simply not drawn', (
      tester,
    ) async {
      // Anchored a year away from anything the chart holds.
      final away = DateTime.utc(2030);
      await tester.pumpWidget(
        _chartWith([
          GannFan(time1: away, price1: 105, time2: away, price2: 120),
          RegressionChannel(time1: away, price1: 105, time2: away, price2: 120),
          XabcdDrawing(points: [(time: away, price: 105)]),
          FlagDrawing(time: away, price: 110),
        ]).widget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('the shapes round-trip through JSON', () {
    final samples = <ChartLine>[
      PitchforkDrawing(
        time1: _at(10),
        price1: 105,
        time2: _at(30),
        price2: 120,
        time3: _at(40),
        price3: 100,
        kind: PitchforkKind.modifiedSchiff,
        levels: const [0, 0.5, 1],
      ),
      GannFan(
        time1: _at(10),
        price1: 105,
        time2: _at(30),
        price2: 120,
        ratios: const [2, 1, 0.5],
      ),
      GannBox(
        time1: _at(10),
        price1: 105,
        time2: _at(30),
        price2: 120,
        showDiagonals: false,
        ratios: const [0, 0.5, 1],
      ),
      FibExtension(
        time1: _at(10),
        price1: 105,
        time2: _at(30),
        price2: 120,
        time3: _at(40),
        price3: 112,
        levels: const [0, 1, 1.618],
      ),
      FibFan(time1: _at(10), price1: 105, time2: _at(30), price2: 120),
      FibTimeZones(
        time1: _at(10),
        price1: 105,
        time2: _at(20),
        price2: 120,
        levels: const [1, 2, 3],
      ),
      RegressionChannel(
        time1: _at(5),
        price1: 105,
        time2: _at(40),
        price2: 120,
        deviations: 1.5,
        showBands: false,
        extend: true,
      ),
      XabcdDrawing(
        points: [
          (time: _at(0), price: 100),
          (time: _at(10), price: 120),
          (time: _at(20), price: 110),
        ],
      ),
      PriceRangeDrawing(
        time1: _at(10),
        price1: 105,
        time2: _at(30),
        price2: 120,
      ),
      DateRangeDrawing(
        time1: _at(10),
        price1: 105,
        time2: _at(30),
        price2: 120,
      ),
      CalloutDrawing(
        time1: _at(10),
        price1: 105,
        time2: _at(30),
        price2: 120,
        text: 'here',
      ),
      PathDrawing(
        points: [(time: _at(0), price: 100), (time: _at(10), price: 120)],
        closed: true,
        arrow: true,
      ),
      FlagDrawing(time: _at(20), price: 110, text: 'earnings', staffHeight: 40),
    ];

    for (final sample in samples) {
      test('${sample.runtimeType} survives a save and a load', () {
        final copy = copyDrawing(sample);

        expect(copy.runtimeType, sample.runtimeType);
        expect(copy.toJson(), sample.toJson());
      });
    }

    test('a whole layout of them round-trips', () {
      final drawings = ChartDrawings(samples);
      final restored = ChartDrawings.fromJson(drawings.toJson());

      expect(restored.all, hasLength(samples.length));
      expect(restored.pitchforks, hasLength(1));
      expect(restored.gannFans, hasLength(1));
      expect(restored.gannBoxes, hasLength(1));
      expect(restored.fibExtensions, hasLength(1));
      expect(restored.fibFans, hasLength(1));
      expect(restored.fibTimeZones, hasLength(1));
      expect(restored.regressions, hasLength(1));
      expect(restored.xabcds, hasLength(1));
      expect(restored.priceRanges, hasLength(1));
      expect(restored.dateRanges, hasLength(1));
      expect(restored.callouts, hasLength(1));
      expect(restored.paths, hasLength(1));
      expect(restored.flags, hasLength(1));
    });

    test('a drawing saved with no points loads as an empty one', () {
      final restored = drawingFromJson({'type': 'path'});
      expect(restored, isA<PathDrawing>());
      expect((restored! as PathDrawing).points, isEmpty);
      expect((restored as PathDrawing).isComplete, isFalse);
    });
  });

  group('every one of them is named', () {
    const translations = DrawingTranslations();

    test('the drawing manager has a name for each', () {
      final named = <ChartLine>[
        PitchforkDrawing(time1: _at(0), price1: 1),
        GannFan(time1: _at(0), price1: 1),
        GannBox(time1: _at(0), price1: 1),
        FibExtension(time1: _at(0), price1: 1),
        FibFan(time1: _at(0), price1: 1),
        FibTimeZones(time1: _at(0), price1: 1),
        RegressionChannel(time1: _at(0), price1: 1),
        XabcdDrawing(),
        PriceRangeDrawing(time1: _at(0), price1: 1),
        DateRangeDrawing(time1: _at(0), price1: 1),
        CalloutDrawing(time1: _at(0), price1: 1),
        PathDrawing(),
        FlagDrawing(time: _at(0), price: 1),
      ];

      for (final line in named) {
        expect(
          translations.nameOf(line),
          isNot(translations.drawingName),
          reason: '${line.runtimeType} fell back to the generic name',
        );
      }
    });
  });

  group('the shared geometry', () {
    test('a Gann ray steepens with its ratio', () {
      const pivot = Offset(0, 100);
      const oneByOne = Offset(100, 0);

      // Screen y grows downwards, so a rise is a negative dy.
      expect(gannRayDirection(pivot, oneByOne, 1), const Offset(100, -100));
      expect(gannRayDirection(pivot, oneByOne, 2), const Offset(100, -200));
      expect(gannRayDirection(pivot, oneByOne, 0.5), const Offset(100, -50));
    });

    test('Gann rays are named the way Gann named them', () {
      expect(GannFan.labelFor(1), '1×1');
      expect(GannFan.labelFor(2), '1×2');
      expect(GannFan.labelFor(0.5), '2×1');
      expect(GannFan.labelFor(0.125), '8×1');
      expect(GannFan.labelFor(1 / 3), '3×1');
    });

    test('a fib fan spreads between the flat and the diagonal', () {
      const from = Offset(0, 100);
      const to = Offset(200, 0);

      expect(fibFanRayThrough(from, to, 0), const Offset(200, 100));
      expect(fibFanRayThrough(from, to, 1), to);
      expect(fibFanRayThrough(from, to, 0.5), const Offset(200, 50));
    });

    test('a time zone is a multiple of the unit span', () {
      const from = Offset(100, 0);
      const to = Offset(120, 0);

      expect(fibTimeZoneX(from, to, 0), 100);
      expect(fibTimeZoneX(from, to, 1), 120);
      expect(fibTimeZoneX(from, to, 8), 260);
    });

    test('a Gann box is ruled at the same fractions both ways', () {
      const box = Rect.fromLTRB(0, 0, 100, 200);
      final rules = gannBoxRules(box, const [0, 0.5, 1]);

      expect(rules.verticals, [0, 50, 100]);
      expect(rules.horizontals, [0, 100, 200]);
    });

    test('a pitchfork runs its median through the midpoint of the swing', () {
      const p1 = Offset(0, 100);
      const p2 = Offset(100, 0);
      const p3 = Offset(100, 200);

      final andrews = pitchforkGeometry(
        p1,
        p2,
        p3,
        PitchforkKind.andrews,
        const [0, 1],
      );
      expect(andrews.median, const Offset(100, 100));
      expect(andrews.handle, p1, reason: "Andrews' leaves the handle alone");

      // The outer tines pass through the two swing points.
      final outer = andrews.tines.firstWhere((t) => t.level == 1);
      expect(outer.upper, p2);
      expect(outer.lower, p3);

      // And the median's own "tine" is the midpoint itself.
      final median = andrews.tines.firstWhere((t) => t.level == 0);
      expect(median.upper, andrews.median);
      expect(median.lower, andrews.median);
    });

    test(
      'Schiff lifts the handle, and modified Schiff lifts it in time too',
      () {
        const p1 = Offset(0, 200);
        const p2 = Offset(100, 0);
        const p3 = Offset(100, 100);

        final schiff = pitchforkGeometry(
          p1,
          p2,
          p3,
          PitchforkKind.schiff,
          const [0],
        );
        // Median is (100, 50), so the handle rises halfway to it but stays put
        // in time.
        expect(schiff.handle, const Offset(0, 125));

        final modified = pitchforkGeometry(
          p1,
          p2,
          p3,
          PitchforkKind.modifiedSchiff,
          const [0],
        );
        expect(modified.handle, const Offset(50, 125));
      },
    );
  });

  group('the regression fit', () {
    test('a straight ramp is fitted exactly, with no spread', () {
      final data = candles([for (var i = 0; i < 10; i++) 100.0 + i]);

      final fit = fitRegression(data, 0, 9)!;
      expect(fit.startPrice, closeTo(100, 1e-9));
      expect(fit.endPrice, closeTo(109, 1e-9));
      expect(fit.deviation, closeTo(0, 1e-9));
    });

    test('a spread market fits the middle and reports the spread', () {
      // Alternating a point either side of 100, so the fit runs down the
      // middle and the spread is about the one point of the swing.
      final data = candles([
        for (var i = 0; i < 10; i++) i.isEven ? 99.0 : 101.0,
      ]);

      final fit = fitRegression(data, 0, 9)!;
      expect(fit.startPrice, closeTo(100, 0.5));
      expect(fit.endPrice, closeTo(100, 0.5));
      expect(fit.deviation, closeTo(1, 0.05));
    });

    test('the ends may be given in either order', () {
      final data = candles([for (var i = 0; i < 10; i++) 100.0 + i]);

      expect(fitRegression(data, 9, 0), fitRegression(data, 0, 9));
    });

    test('one candle cannot be fitted', () {
      final data = candles([for (var i = 0; i < 10; i++) 100.0 + i]);

      expect(fitRegression(data, 3, 3), isNull);
      expect(fitRegression(const [], 0, 0), isNull);
    });

    test('a fit covers only the candles between the anchors', () {
      // Flat, then a ramp. A fit over the flat stretch says the market is flat,
      // whatever the ramp after it does.
      final data = candles([
        for (var i = 0; i < 10; i++) 100.0,
        for (var i = 0; i < 10; i++) 100.0 + i * 5,
      ]);

      final flat = fitRegression(data, 0, 9)!;
      expect(flat.endPrice - flat.startPrice, closeTo(0, 1e-9));

      final ramp = fitRegression(data, 10, 19)!;
      expect(ramp.endPrice - ramp.startPrice, greaterThan(40));
    });
  });

  group('the fib extension projects from the third anchor', () {
    test('a level of one is the impulse again', () {
      final extension = FibExtension(
        time1: _at(0),
        price1: 100,
        time2: _at(10),
        price2: 120,
        time3: _at(20),
        price3: 110,
      );

      // The impulse is +20, measured on again from 110.
      expect(extension.priceAt(0), closeTo(110, 1e-9));
      expect(extension.priceAt(1), closeTo(130, 1e-9));
      expect(extension.priceAt(1.618), closeTo(142.36, 1e-9));
    });

    test('nothing is projected until all three anchors have landed', () {
      final half = FibExtension(time1: _at(0), price1: 100);
      expect(half.priceAt(1), isNull);
      expect(half.isComplete, isFalse);
    });
  });
}
