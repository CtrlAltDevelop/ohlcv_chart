import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart/src/renderer/chart_painter.dart';

import 'test_utils.dart';

const double _boxHeight = 700;
const double _tallBox = 1100;

List<KLineEntity> _candles() {
  final data = candles(rampThenFall(60));
  DataUtil.calculate(data);
  return data;
}

Widget _chart({
  List<Indicator>? indicators,
  List<double>? paneHeights,
  double? volumeHeight,
  KChartController? controller,
  ValueChanged<List<double>>? onChanged,
  bool resizable = false,
  double boxHeight = _boxHeight,
  List<double>? ratios,
  ValueChanged<List<double>>? onRatios,
  bool volHidden = false,
}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: 500,
      height: boxHeight,
      child: KChartWidget(
        _candles(),
        ChartColors(),
        isTrendLine: false,
        timeFrame: const Duration(minutes: 1),
        showNowPrice: false,
        indicators: indicators ?? [RsiIndicator(), MacdIndicator()],
        paneHeights: paneHeights,
        volumeHeight: volumeHeight,
        controller: controller,
        onPaneHeightsChanged: onChanged,
        resizablePanes: resizable,
        paneRatios: ratios,
        onPaneRatiosChanged: onRatios,
        volHidden: volHidden,
      ),
    ),
  ),
);

ChartPainter _painterOf(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find
        .descendant(
          of: find.byType(KChartWidget),
          matching: find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is ChartPainter,
          ),
        )
        .first,
  );
  return paint.painter! as ChartPainter;
}

List<double> _paneHeightsOf(WidgetTester tester) => [
  for (final r in _painterOf(tester).mSecondaryRectList) r.mRect.height,
];

/// A test window tall enough for [_tallBox].
void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('panes keep the standard height by default', (tester) async {
    await tester.pumpWidget(_chart());
    final heights = _paneHeightsOf(tester);
    expect(heights, hasLength(2));
    // The pane rect leaves room for the legend strip above it.
    expect(heights[0], heights[1]);
  });

  testWidgets('paneHeights sizes the panes and null puts them back', (
    tester,
  ) async {
    await tester.pumpWidget(_chart());
    final standard = _paneHeightsOf(tester);

    await tester.pumpWidget(_chart(paneHeights: [250, 80]));
    final sized = _paneHeightsOf(tester);
    expect(sized[0], greaterThan(sized[1]));
    expect(sized[0] - standard[0], closeTo(150, 0.01));
    expect(sized[1] - standard[1], closeTo(-20, 0.01));

    await tester.pumpWidget(_chart());
    expect(_paneHeightsOf(tester), standard);
  });

  testWidgets('a short or unusable list falls back to the standard height', (
    tester,
  ) async {
    await tester.pumpWidget(_chart());
    final standard = _paneHeightsOf(tester);

    await tester.pumpWidget(_chart(paneHeights: [double.nan, -5]));
    expect(_paneHeightsOf(tester), standard);

    await tester.pumpWidget(_chart(paneHeights: [200]));
    final sized = _paneHeightsOf(tester);
    expect(sized[0] - standard[0], closeTo(100, 0.01));
    expect(sized[1], standard[1]);
  });

  testWidgets('a height past the drag ceiling is used, not clamped', (
    tester,
  ) async {
    _tallView(tester);
    await tester.pumpWidget(_chart(boxHeight: _tallBox));
    final standard = _paneHeightsOf(tester);

    await tester.pumpWidget(
      _chart(paneHeights: [450, 100], boxHeight: _tallBox),
    );
    expect(_paneHeightsOf(tester)[0] - standard[0], closeTo(350, 0.01));
  });

  testWidgets('a height too big for the box is cut back to leave the candles', (
    tester,
  ) async {
    await tester.pumpWidget(_chart(paneHeights: [5000, 100]));
    final painter = _painterOf(tester);
    expect(painter.mMainRect.height, greaterThanOrEqualTo(60));
    expect(
      painter.mSecondaryRectList.last.mRect.bottom,
      lessThanOrEqualTo(_boxHeight),
    );
  });

  testWidgets('volumeHeight resizes the volume pane', (tester) async {
    await tester.pumpWidget(_chart());
    final standard = _painterOf(tester).mVolRect!.height;

    await tester.pumpWidget(_chart(volumeHeight: 140));
    expect(_painterOf(tester).mVolRect!.height - standard, closeTo(80, 0.01));

    await tester.pumpWidget(_chart(volumeHeight: -1));
    expect(_painterOf(tester).mVolRect!.height, standard);
  });

  testWidgets('the controller sizes and resets a pane', (tester) async {
    final controller = KChartController();
    final reported = <List<double>>[];
    await tester.pumpWidget(
      _chart(controller: controller, onChanged: reported.add),
    );
    final standard = _paneHeightsOf(tester);
    expect(controller.paneHeights, [100, 100]);

    expect(controller.setPaneHeight(1, 300), isTrue);
    await tester.pump();
    expect(controller.paneHeights, [100, 300]);
    expect(_paneHeightsOf(tester)[1] - standard[1], closeTo(200, 0.01));
    expect(reported.last, [100, 300]);

    expect(controller.setPaneHeight(5, 300), isFalse);
    expect(controller.setPaneHeight(0, 0), isFalse);
    expect(controller.setPaneHeight(0, double.infinity), isFalse);

    controller.resetPaneHeights();
    await tester.pump();
    expect(_paneHeightsOf(tester), standard);
    expect(reported.last, [100, 100]);
  });

  testWidgets('maximizePane fills the box and restorePanes undoes it', (
    tester,
  ) async {
    final controller = KChartController();
    await tester.pumpWidget(_chart(controller: controller));
    final standard = _paneHeightsOf(tester);
    final mainBefore = _painterOf(tester).mMainRect.height;

    expect(controller.maximizePane(1), isTrue);
    await tester.pump();
    expect(controller.maximizedPane, 1);

    final painter = _painterOf(tester);
    final heights = _paneHeightsOf(tester);
    expect(heights[1], greaterThan(heights[0] * 3));
    expect(painter.mMainRect.height, lessThan(mainBefore));
    expect(painter.mMainRect.height, greaterThanOrEqualTo(60));
    expect(
      painter.mSecondaryRectList.last.mRect.bottom,
      lessThanOrEqualTo(_boxHeight),
    );

    controller.restorePanes();
    await tester.pump();
    expect(controller.maximizedPane, isNull);
    expect(_paneHeightsOf(tester), standard);
  });

  testWidgets('toggleMaximizePane flips and the stretch follows a reorder', (
    tester,
  ) async {
    final controller = KChartController();
    await tester.pumpWidget(_chart(controller: controller));

    controller.toggleMaximizePane(0);
    await tester.pump();
    expect(controller.maximizedPane, 0);

    // The same two indicators in the other order: the stretch goes with RSI.
    await tester.pumpWidget(
      _chart(
        controller: controller,
        indicators: [MacdIndicator(), RsiIndicator()],
      ),
    );
    expect(controller.maximizedPane, 1);

    controller.toggleMaximizePane(1);
    await tester.pump();
    expect(controller.maximizedPane, isNull);
  });

  testWidgets('maximizing is dropped when the panes change', (tester) async {
    final controller = KChartController();
    await tester.pumpWidget(_chart(controller: controller));
    controller.maximizePane(0);
    await tester.pump();

    await tester.pumpWidget(
      _chart(controller: controller, indicators: [RsiIndicator()]),
    );
    expect(controller.maximizedPane, isNull);
  });

  testWidgets('a reorder carries the dragged heights with their panes', (
    tester,
  ) async {
    final controller = KChartController();
    await tester.pumpWidget(_chart(controller: controller));
    controller.setPaneHeight(0, 300);
    await tester.pump();
    expect(controller.paneHeights, [300, 100]);

    await tester.pumpWidget(
      _chart(
        controller: controller,
        indicators: [MacdIndicator(), RsiIndicator()],
      ),
    );
    expect(controller.paneHeights, [100, 300]);
  });

  testWidgets('adding a pane throws the sized heights away', (tester) async {
    final controller = KChartController();
    await tester.pumpWidget(_chart(controller: controller));
    controller.setPaneHeight(0, 300);
    await tester.pump();

    await tester.pumpWidget(
      _chart(
        controller: controller,
        indicators: [RsiIndicator(), MacdIndicator(), KdjIndicator()],
      ),
    );
    expect(controller.paneHeights, [100, 100, 100]);
  });

  testWidgets('a drag on a pane edge reports the new heights', (tester) async {
    final reported = <List<double>>[];
    await tester.pumpWidget(_chart(resizable: true, onChanged: reported.add));
    final edge = _painterOf(tester).mSecondaryRectList.first.mRect.bottom;
    final box = tester.getTopLeft(find.byType(KChartWidget));

    final gesture = await tester.startGesture(box + Offset(200, edge));
    await gesture.moveBy(const Offset(0, 20));
    await gesture.moveBy(const Offset(0, 20));
    await gesture.up();
    await tester.pump();

    expect(reported, isNotEmpty);
    expect(reported.last[0], greaterThan(100));
    expect(reported.last[1], 100);
  });

  testWidgets('a host-sized pane taller than the ceiling is not snapped down '
      'by a drag', (tester) async {
    _tallView(tester);
    final reported = <List<double>>[];
    await tester.pumpWidget(
      _chart(
        resizable: true,
        paneHeights: [450, 100],
        onChanged: reported.add,
        boxHeight: _tallBox,
      ),
    );
    final edge = _painterOf(tester).mSecondaryRectList.first.mRect.bottom;
    final box = tester.getTopLeft(find.byType(KChartWidget));

    final gesture = await tester.startGesture(box + Offset(200, edge));
    await gesture.moveBy(const Offset(0, -20));
    await gesture.moveBy(const Offset(0, -20));
    await gesture.up();
    await tester.pump();

    expect(reported, isNotEmpty);
    expect(reported.last[0], greaterThan(400));
  });

  testWidgets('a host that passes paneHeights owns them: a drag only reports', (
    tester,
  ) async {
    _tallView(tester);
    final reported = <List<double>>[];
    await tester.pumpWidget(
      _chart(
        resizable: true,
        paneHeights: [100, 100],
        onChanged: reported.add,
        boxHeight: _tallBox,
      ),
    );
    final before = _paneHeightsOf(tester);
    final edge = _painterOf(tester).mSecondaryRectList.first.mRect.bottom;
    final box = tester.getTopLeft(find.byType(KChartWidget));

    final gesture = await tester.startGesture(box + Offset(200, edge));
    await gesture.moveBy(const Offset(0, 20));
    await gesture.moveBy(const Offset(0, 20));
    await gesture.up();
    await tester.pump();

    expect(reported, isNotEmpty);
    expect(reported.last[0], greaterThan(100));
    expect(_paneHeightsOf(tester), before);

    // Passing the reported heights back is what moves the pane.
    await tester.pumpWidget(
      _chart(
        resizable: true,
        paneHeights: reported.last,
        onChanged: reported.add,
        boxHeight: _tallBox,
      ),
    );
    expect(_paneHeightsOf(tester)[0], greaterThan(before[0]));
  });

  testWidgets('setPaneHeight on a host-owned chart reports without moving', (
    tester,
  ) async {
    final controller = KChartController();
    final reported = <List<double>>[];
    await tester.pumpWidget(
      _chart(
        controller: controller,
        paneHeights: [100, 100],
        onChanged: reported.add,
      ),
    );
    final before = _paneHeightsOf(tester);

    expect(controller.setPaneHeight(0, 250), isTrue);
    await tester.pump();
    expect(reported.last, [250, 100]);
    expect(_paneHeightsOf(tester), before);
  });

  testWidgets('maximizePane still works over host-owned heights', (
    tester,
  ) async {
    final controller = KChartController();
    await tester.pumpWidget(
      _chart(controller: controller, paneHeights: [100, 100]),
    );
    final before = _paneHeightsOf(tester);

    controller.maximizePane(0);
    await tester.pump();
    expect(_paneHeightsOf(tester)[0], greaterThan(before[0] * 2));

    controller.restorePanes();
    await tester.pump();
    expect(_paneHeightsOf(tester), before);
  });

  testWidgets('maximizeVolume fills the box and restorePanes undoes it', (
    tester,
  ) async {
    final controller = KChartController();
    await tester.pumpWidget(_chart(controller: controller));
    final standard = _painterOf(tester).mVolRect!.height;
    final panes = _paneHeightsOf(tester);

    expect(controller.maximizeVolume(), isTrue);
    await tester.pump();
    expect(controller.isVolumeMaximized, isTrue);
    expect(controller.maximizedPane, isNull);

    final painter = _painterOf(tester);
    expect(painter.mVolRect!.height, greaterThan(standard * 3));
    expect(painter.mMainRect.height, greaterThanOrEqualTo(60));
    expect(
      painter.mSecondaryRectList.last.mRect.bottom,
      lessThanOrEqualTo(_boxHeight),
    );

    // Maximizing a pane takes the volume pane back down.
    controller.maximizePane(0);
    await tester.pump();
    expect(controller.isVolumeMaximized, isFalse);
    expect(controller.maximizedPane, 0);

    controller.maximizeVolume();
    controller.restorePanes();
    await tester.pump();
    expect(controller.isVolumeMaximized, isFalse);
    expect(_painterOf(tester).mVolRect!.height, standard);
    expect(_paneHeightsOf(tester), panes);
  });

  testWidgets('the volume pane cannot be maximized while it is hidden', (
    tester,
  ) async {
    final controller = KChartController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 500,
            height: _boxHeight,
            child: KChartWidget(
              _candles(),
              ChartColors(),
              isTrendLine: false,
              timeFrame: const Duration(minutes: 1),
              volHidden: true,
              controller: controller,
            ),
          ),
        ),
      ),
    );
    expect(controller.maximizeVolume(), isFalse);
    expect(controller.isVolumeMaximized, isFalse);
  });

  group('paneRatios', () {
    testWidgets('divides the height between candles, volume and panes', (
      tester,
    ) async {
      final controller = KChartController();
      await tester.pumpWidget(
        _chart(
          controller: controller,
          indicators: [RsiIndicator(), MacdIndicator()],
          ratios: [3, 1, 2, 4],
        ),
      );
      final heights = controller.paneHeights;
      // The two panes hold their 2 : 4 proportion exactly.
      expect(heights[1] / heights[0], closeTo(2, 0.001));

      // The parts fill the box (the test window is shorter than the box),
      // less the strip the date axis takes under the last pane.
      final painter = _painterOf(tester);
      final bottom = painter.mSecondaryRectList.last.mRect.bottom;
      expect(
        bottom,
        closeTo(
          tester.view.physicalSize.height / tester.view.devicePixelRatio,
          30,
        ),
      );

      // 3 : 1 : 2 : 4 — the first pane is 2/10 of what is left of the box.
      final main = painter.mMainRect.height;
      final volume = painter.mVolRect!.height;
      expect(main, greaterThan(volume * 2));
      expect(heights[0], greaterThan(volume));
    });

    testWidgets('keeps the proportions when the box is resized', (
      tester,
    ) async {
      _tallView(tester);
      final controller = KChartController();
      Widget at(double height) => _chart(
        controller: controller,
        indicators: [RsiIndicator(), MacdIndicator()],
        ratios: [3, 1, 2, 4],
        boxHeight: height,
      );

      await tester.pumpWidget(at(600));
      final small = controller.paneHeights;
      await tester.pumpWidget(at(1000));
      final large = controller.paneHeights;

      expect(large[0], greaterThan(small[0]));
      expect(large[1] / large[0], closeTo(2, 0.001));
      expect(large[0] / small[0], closeTo(large[1] / small[1], 0.001));
    });

    testWidgets('leaves the volume out of the list when it is hidden', (
      tester,
    ) async {
      final controller = KChartController();
      await tester.pumpWidget(
        _chart(
          controller: controller,
          volHidden: true,
          indicators: [RsiIndicator(), MacdIndicator()],
          ratios: [2, 1, 3],
        ),
      );
      final heights = controller.paneHeights;
      expect(heights[1] / heights[0], closeTo(3, 0.001));
    });

    testWidgets('a short list or a bad number counts as 1', (tester) async {
      final controller = KChartController();
      await tester.pumpWidget(
        _chart(
          controller: controller,
          indicators: [RsiIndicator(), MacdIndicator()],
          ratios: [3, 1, double.nan],
        ),
      );
      final heights = controller.paneHeights;
      expect(heights[0], closeTo(heights[1], 0.001));
    });

    testWidgets('wins over paneHeights and volumeHeight, and null lets go', (
      tester,
    ) async {
      final controller = KChartController();
      Widget chart({List<double>? ratios}) => _chart(
        controller: controller,
        indicators: [RsiIndicator(), MacdIndicator()],
        paneHeights: [300, 40],
        volumeHeight: 200,
        ratios: ratios,
      );

      await tester.pumpWidget(chart(ratios: [3, 1, 2, 2]));
      final heights = controller.paneHeights;
      expect(heights[0], closeTo(heights[1], 0.001));

      await tester.pumpWidget(chart());
      expect(controller.paneHeights, [300, 40]);
    });

    testWidgets('maximizePane wins over it, and restores to it', (
      tester,
    ) async {
      final controller = KChartController();
      await tester.pumpWidget(
        _chart(
          controller: controller,
          indicators: [RsiIndicator(), MacdIndicator()],
          ratios: [3, 1, 2, 2],
        ),
      );
      final before = controller.paneHeights;

      controller.maximizePane(0);
      await tester.pump();
      expect(controller.paneHeights[0], greaterThan(before[0] * 2));

      controller.restorePanes();
      await tester.pump();
      expect(controller.paneHeights, before);
    });

    testWidgets('a drag reports moved proportions with the total kept', (
      tester,
    ) async {
      final reported = <List<double>>[];
      await tester.pumpWidget(
        _chart(
          resizable: true,
          indicators: [RsiIndicator(), MacdIndicator()],
          ratios: [3, 1, 2, 4],
          onRatios: reported.add,
        ),
      );
      final before = _paneHeightsOf(tester);
      final edge = _painterOf(tester).mSecondaryRectList.first.mRect.bottom;
      final box = tester.getTopLeft(find.byType(KChartWidget));

      final gesture = await tester.startGesture(box + Offset(200, edge));
      await gesture.moveBy(const Offset(0, 20));
      await gesture.moveBy(const Offset(0, 20));
      await gesture.up();
      await tester.pump();

      expect(reported, isNotEmpty);
      final last = reported.last;
      expect(last.fold<double>(0, (a, b) => a + b), closeTo(10, 0.0001));
      // The pane grew and the one below it gave the room; the rest held.
      expect(last[2], greaterThan(2));
      expect(last[3], lessThan(4));
      expect(last[0], 3);
      expect(last[1], 1);
      // The host owns the proportions, so nothing moved until it passes them back.
      expect(_paneHeightsOf(tester), before);
    });

    testWidgets('is ignored when the candle height is fixed', (tester) async {
      final controller = KChartController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              height: _boxHeight,
              child: KChartWidget(
                _candles(),
                ChartColors(),
                isTrendLine: false,
                timeFrame: const Duration(minutes: 1),
                mBaseHeight: 300,
                indicators: [RsiIndicator()],
                paneRatios: const [1, 1, 5],
                controller: controller,
              ),
            ),
          ),
        ),
      );
      expect(controller.paneHeights, [100]);
    });
  });
}
