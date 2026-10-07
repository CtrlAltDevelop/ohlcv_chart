import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart/src/renderer/chart_painter.dart';

import 'test_utils.dart';

ChartPainter _painterOf(WidgetTester tester) {
  final dynamic state = tester.state(find.byType(KChartWidget));
  // ignore: avoid_dynamic_calls
  return state.painter as ChartPainter;
}

/// A chart too short to fill its box at the default spacing.
Widget _chart({
  required bool fitContent,
  int count = 10,
  List<Indicator> indicators = const [],
}) {
  final data = candles(rampThenFall(count));
  DataUtil.calculate(data);

  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 220,
        child: KChartWidget(
          data,
          ChartColors(),
          isTrendLine: false,
          timeFrame: const Duration(minutes: 5),
          xFrontPadding: 0,
          volHidden: true,
          showNowPrice: false,
          chartStyle: ChartStyle(fitContent: fitContent),
          indicators: indicators,
        ),
      ),
    ),
  );
}

/// The widths of the rects an indicator pane draws across its candles.
List<double> _paneBarWidths(WidgetTester tester, {required double scaleX}) {
  final painter = _painterOf(tester);
  final canvas = TestRecordingCanvas();
  painter.mIndicatorPaneList.single.drawSeries(
    canvas,
    painter.candles!,
    start: 0,
    stop: painter.candles!.length - 1,
    xOf: (i) => i * 10.0,
    scaleX: scaleX,
  );
  final widths = [
    for (final call in canvas.invocations)
      if (call.invocation.memberName == #drawRect)
        (call.invocation.positionalArguments.first as Rect).width,
  ];
  // everyElement passes on an empty list, which would hide a pane drawing none.
  expect(widths, isNotEmpty);
  return widths;
}

/// Bars drawn over the candles, one per candle, from zero.
class _OverlayBars extends Indicator {
  @override
  String get name => 'OVERLAYBARS';

  @override
  String get label => name;

  @override
  IndicatorPlacement get placement => IndicatorPlacement.overlay;

  @override
  List<IndicatorLine> get lines => const [
    IndicatorLine('V', shape: IndicatorShape.histogram),
  ];

  @override
  List<Object?> get settings => [name];

  @override
  IndicatorSeries compute(List<KLineEntity> candles) => IndicatorSeries([
    [for (final c in candles) c.close],
  ]);

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) =>
      theme.ma5Color;
}

Future<void> _pinchOut(WidgetTester tester) async {
  final centre = tester.getCenter(find.byType(KChartWidget));
  final left = await tester.startGesture(centre - const Offset(40, 0));
  final right = await tester.startGesture(centre + const Offset(40, 0));
  await left.moveBy(const Offset(-90, 0));
  await right.moveBy(const Offset(90, 0));
  await tester.pump();
  await left.up();
  await right.up();
  await tester.pumpAndSettle();
}

void main() {
  group('indicator pane bars', () {
    testWidgets('over the candles, widen with the zoom too', (tester) async {
      await tester.pumpWidget(
        _chart(fitContent: false, count: 200, indicators: [_OverlayBars()]),
      );
      await _pinchOut(tester);
      final painter = _painterOf(tester);
      expect(painter.scaleX, greaterThan(1.2));

      final canvas = TestRecordingCanvas();
      painter.paint(canvas, tester.getSize(find.byType(KChartWidget)));

      final widths = [
        for (final call in canvas.invocations)
          if (call.invocation.memberName == #drawRect)
            (call.invocation.positionalArguments.first as Rect).width,
      ];
      expect(
        widths,
        contains(
          closeTo(const ChartStyle().candleWidth * painter.scaleX, 0.001),
        ),
      );
    });

    testWidgets('the chart hands its zoom to the panes', (tester) async {
      await tester.pumpWidget(
        _chart(fitContent: false, count: 200, indicators: [MacdIndicator()]),
      );
      await _pinchOut(tester);
      final painter = _painterOf(tester);
      expect(painter.scaleX, greaterThan(1.2));

      final canvas = TestRecordingCanvas();
      painter.paint(canvas, tester.getSize(find.byType(KChartWidget)));

      final widths = [
        for (final call in canvas.invocations)
          if (call.invocation.memberName == #drawRect)
            (call.invocation.positionalArguments.first as Rect).width,
      ];
      expect(
        widths,
        contains(closeTo(const ChartStyle().macdWidth * painter.scaleX, 0.001)),
      );
    });

    testWidgets('widen with the zoom, as the candles do', (tester) async {
      await tester.pumpWidget(
        _chart(fitContent: false, indicators: [MacdIndicator()]),
      );
      final width = const ChartStyle().macdWidth;

      expect(_paneBarWidths(tester, scaleX: 1), everyElement(width));
      expect(_paneBarWidths(tester, scaleX: 3), everyElement(width * 3));
    });

    testWidgets('never shrink past a hairline when zoomed out', (tester) async {
      await tester.pumpWidget(
        _chart(fitContent: false, indicators: [MacdIndicator()]),
      );

      expect(_paneBarWidths(tester, scaleX: 0.1), everyElement(1.0));
    });
  });

  group('ChartStyle.fitContent', () {
    testWidgets('off, a short series keeps the fixed spacing', (tester) async {
      await tester.pumpWidget(_chart(fitContent: false));

      expect(_painterOf(tester).mPointWidth, const ChartStyle().pointWidth);
    });

    testWidgets('on, a short series spreads across the plot', (tester) async {
      await tester.pumpWidget(_chart(fitContent: true));
      final painter = _painterOf(tester);

      expect(painter.mPointWidth, closeTo(40, 0.001));
      // The last candle's body ends at the right edge rather than a tenth of
      // the way in, which is what the bunching complaint was about.
      final lastX = painter.translateXtoX(painter.getX(9));
      expect(lastX, closeTo(400 - painter.mPointWidth / 2, 0.001));
    });

    testWidgets('on, the candles widen with the spacing', (tester) async {
      await tester.pumpWidget(_chart(fitContent: true));
      final painter = _painterOf(tester);

      const style = ChartStyle();
      final spread = painter.mPointWidth / style.pointWidth;
      expect(
        painter.fittedStyle.candleWidth,
        closeTo(style.candleWidth * spread, 0.001),
      );
    });

    testWidgets('on, an indicator pane\'s bars widen with the spacing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _chart(fitContent: true, indicators: [MacdIndicator()]),
      );
      final painter = _painterOf(tester);

      const style = ChartStyle();
      final spread = painter.mPointWidth / style.pointWidth;
      expect(
        painter.mIndicatorPaneList.single.chartStyle.macdWidth,
        closeTo(style.macdWidth * spread, 0.001),
      );
    });

    testWidgets('off, an indicator pane\'s bars keep their width', (
      tester,
    ) async {
      await tester.pumpWidget(
        _chart(fitContent: false, indicators: [MacdIndicator()]),
      );

      expect(
        _painterOf(tester).mIndicatorPaneList.single.chartStyle.macdWidth,
        const ChartStyle().macdWidth,
      );
    });

    testWidgets('on, a series that already fills the plot is left alone', (
      tester,
    ) async {
      await tester.pumpWidget(_chart(fitContent: true, count: 200));

      expect(_painterOf(tester).mPointWidth, const ChartStyle().pointWidth);
    });
  });
}
