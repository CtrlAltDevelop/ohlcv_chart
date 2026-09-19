import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart/src/series/series_chart_painter.dart';

Widget _host(Widget child, {double width = 300, double height = 200}) =>
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, height: height, child: child),
        ),
      ),
    );

SeriesChartPainter _painter(WidgetTester tester) {
  final paints = tester.widgetList<CustomPaint>(
    find.descendant(
      of: find.byType(SeriesChart),
      matching: find.byType(CustomPaint),
    ),
  );
  return paints.map((p) => p.painter).whereType<SeriesChartPainter>().first;
}

/// A chart whose plot is the whole 300 × 200 box, so x = i sits at 75 * i.
SeriesChart _bare(
  List<double?> values, {
  SeriesTouch? touch = const SeriesTouch(),
  SeriesChartController? controller,
  ValueChanged<SeriesTouchDetails?>? onTouch,
  Duration animationDuration = Duration.zero,
  bool animateOnMount = true,
}) => SeriesChart(
  series: [LineSeries.values(values)],
  xAxis: SeriesXAxis.hidden,
  yAxis: SeriesYAxis.hidden,
  touch: touch,
  controller: controller,
  onTouch: onTouch,
  animationDuration: animationDuration,
  animateOnMount: animateOnMount,
);

void main() {
  testWidgets('draws every kind of series and furniture', (tester) async {
    await tester.pumpWidget(
      _host(
        SeriesChart(
          series: [
            BarSeries.values(
              [3, -2, 5, -1, 4],
              color: Colors.green,
              negativeColor: Colors.red,
              radius: const BorderRadius.vertical(top: Radius.circular(3)),
              trackColor: Colors.white10,
            ),
            LineSeries.values(
              [1, 4, null, -3, 2],
              curve: LineCurve.monotone,
              negativeColor: Colors.red,
              fill: SeriesFill.fade(Colors.blue, negativeColor: Colors.red),
              dot: const SeriesDot(),
              dashPattern: const [4, 2],
            ),
            LineSeries.values([2, 2, 2, 2, 2], curve: LineCurve.step),
            LineSeries.values([0, 1, 0, 1, 0], curve: LineCurve.smooth),
          ],
          xAxis: const SeriesXAxis(labels: ['a', 'b', 'c', 'd', 'e']),
          yAxis: const SeriesYAxis(side: SeriesAxisSide.right),
          grid: const SeriesGrid(dashPattern: [4, 4]),
          border: const BorderSide(color: Colors.grey),
          referenceLines: const [
            SeriesReferenceLine.horizontal(
              0,
              dashPattern: [3, 3],
              label: 'zero',
            ),
            SeriesReferenceLine.vertical(2, label: 'now'),
          ],
          bands: const [SeriesBand.vertical(3, 4, color: Colors.white12)],
          semanticLabel: 'demo',
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('demo'), findsOneWidget);
  });

  testWidgets('hidden axes give the plot the whole chart', (tester) async {
    await tester.pumpWidget(_host(_bare([1, 2, 3]), height: 58));

    expect(_painter(tester).geometry.plot, const Rect.fromLTWH(0, 0, 300, 58));
  });

  testWidgets('in a box with no height it takes its default height', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                SeriesChart(
                  series: [
                    LineSeries.values([1, 2, 3]),
                  ],
                  defaultHeight: 120,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(SeriesChart)).height, 120);
  });

  testWidgets('a long press shows the touched values until it lifts', (
    tester,
  ) async {
    final reports = <SeriesTouchDetails?>[];
    await tester.pumpWidget(
      _host(
        _bare(
          [10, 20, 30, 40, 50],
          touch: const SeriesTouch(trigger: SeriesTouchTrigger.longPress),
          onTouch: reports.add,
        ),
      ),
    );

    final origin = tester.getTopLeft(find.byType(SeriesChart));
    final gesture = await tester.startGesture(origin + const Offset(160, 100));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await tester.pump();

    expect(reports.last!.x, 2);
    expect(reports.last!.values.single.value, 30);
    expect(find.text('30'), findsOneWidget);

    await gesture.up();
    await tester.pump();
    await tester.pump();

    expect(reports.last, isNull);
    expect(find.text('30'), findsNothing);
  });

  testWidgets('a press follows a drag across the chart', (tester) async {
    final reports = <SeriesTouchDetails?>[];
    await tester.pumpWidget(
      _host(_bare([10, 20, 30, 40, 50], onTouch: reports.add)),
    );

    final origin = tester.getTopLeft(find.byType(SeriesChart));
    final gesture = await tester.startGesture(origin + const Offset(75, 100));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    expect(reports.last!.x, 1);

    await gesture.moveBy(const Offset(60, 0));
    await gesture.moveBy(const Offset(90, 0));
    await tester.pump();
    await tester.pump();
    expect(reports.last!.x, 3);

    await gesture.up();
    await tester.pump();
    await tester.pump();
    expect(reports.last, isNull);
  });

  testWidgets('one controller marks the same x on two charts', (tester) async {
    final controller = SeriesChartController();
    addTearDown(controller.dispose);
    final top = <SeriesTouchDetails?>[];
    final bottom = <SeriesTouchDetails?>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(
                height: 100,
                child: _bare(
                  [1, 2, 3],
                  controller: controller,
                  onTouch: top.add,
                ),
              ),
              SizedBox(
                height: 100,
                child: SeriesChart(
                  series: [
                    BarSeries.values([5, -5, 5]),
                  ],
                  controller: controller,
                  onTouch: bottom.add,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    controller.show(1);
    await tester.pump();
    await tester.pump();

    expect(top.last!.values.single.value, 2);
    expect(bottom.last!.values.single.value, -5);

    controller.clear();
    await tester.pump();
    await tester.pump();
    expect(top.last, isNull);
    expect(bottom.last, isNull);
  });

  testWidgets('a tooltip builder replaces the card', (tester) async {
    final controller = SeriesChartController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        _bare(
          [1, 2, 3],
          controller: controller,
          touch: SeriesTouch(
            tooltip: SeriesTooltip(
              builder: (context, details) => Text('custom ${details.index}'),
            ),
          ),
        ),
      ),
    );

    controller.show(1);
    await tester.pump();

    expect(find.text('custom 1'), findsOneWidget);
  });

  testWidgets('new values move from the old ones', (tester) async {
    await tester.pumpWidget(
      _host(
        _bare(
          [0, 0],
          animationDuration: const Duration(milliseconds: 200),
          animateOnMount: false,
        ),
      ),
    );
    expect(_painter(tester).values[0][0], 0);

    await tester.pumpWidget(
      _host(
        _bare(
          [100, 100],
          animationDuration: const Duration(milliseconds: 200),
          animateOnMount: false,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final halfway = _painter(tester).values[0][0]!;
    expect(halfway, greaterThan(0));
    expect(halfway, lessThan(100));

    await tester.pumpAndSettle();
    expect(_painter(tester).values[0][0], 100);
  });

  testWidgets('the first build grows out of the baseline', (tester) async {
    await tester.pumpWidget(
      _host(
        _bare([-10, 20], animationDuration: const Duration(milliseconds: 200)),
      ),
    );
    // Zero is in range here, so both values start on it.
    expect(_painter(tester).values[0], [0, 0]);

    await tester.pumpAndSettle();
    expect(_painter(tester).values[0], [-10, 20]);
  });

  testWidgets('a baseline out of range grows from the plot edge', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _bare([10, 20], animationDuration: const Duration(milliseconds: 200)),
      ),
    );
    final painter = _painter(tester);
    expect(painter.values[0][0], painter.geometry.viewport.minY);

    await tester.pumpAndSettle();
    expect(_painter(tester).values[0][0], 10);
  });

  testWidgets('the range selector pans and resizes its window', (tester) async {
    var window = const SeriesWindow(10, 15);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              child: StatefulBuilder(
                builder: (context, setState) => SeriesRangeSelector(
                  series: [
                    LineSeries.values([
                      for (var i = 0; i < 21; i++) i.toDouble(),
                    ]),
                  ],
                  window: window,
                  minSpan: 4,
                  onChanged: (next) => setState(() => window = next),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // The data spans -0.5 to 20.5, so one unit is 300 / 21 pixels wide.
    final origin = tester.getTopLeft(find.byType(SeriesRangeSelector));
    const unit = 300 / 21;
    await tester.dragFrom(
      origin + const Offset(12.5 * unit + 0.5, 26),
      const Offset(3 * unit, 0),
    );
    await tester.pump();
    expect(window.start, closeTo(13, 0.05));
    expect(window.end, closeTo(18, 0.05));

    await tester.dragFrom(
      origin + Offset((window.end + 0.5) * unit, 26),
      const Offset(-200, 0),
    );
    await tester.pump();
    expect(window.end, closeTo(window.start + 4, 0.001));
  });
}
