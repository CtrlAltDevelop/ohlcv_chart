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
}
