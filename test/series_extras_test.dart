import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart/src/renderer/text_painter_cache.dart';
import 'package:ohlcv_chart/src/series/series_chart_painter.dart';
import 'package:ohlcv_chart/src/series/series_paths.dart';
import 'package:ohlcv_chart/src/series/series_scale.dart';

/// Records the geometry that actually reached the canvas.
class Recorder implements Canvas {
  final List<Rect> paths = [];
  final List<RRect> rrects = [];
  final List<Rect> rects = [];
  final List<(Offset, Offset)> lines = [];
  int labels = 0;

  @override
  void drawPath(Path path, Paint paint) => paths.add(path.getBounds());
  @override
  void drawRRect(RRect rrect, Paint paint) => rrects.add(rrect);
  @override
  void drawRect(Rect rect, Paint paint) => rects.add(rect);
  @override
  void drawLine(Offset a, Offset b, Paint paint) => lines.add((a, b));
  @override
  void drawParagraph(Paragraph paragraph, Offset offset) => labels++;
  @override
  void noSuchMethod(Invocation invocation) {}
}

Recorder paintChart(
  List<PlotSeries> series, {
  SeriesOrientation orientation = SeriesOrientation.vertical,
  List<SeriesBetweenFill> betweenFills = const [],
  SeriesXAxis xAxis = const SeriesXAxis(),
  SeriesYAxis yAxis = const SeriesYAxis(),
  Size size = const Size(200, 100),
}) {
  final values = [
    for (final s in series) [for (final p in s.points) p.isGap ? null : p.y],
  ];
  final viewport = fitSeriesViewport(
    series: series,
    values: values,
    xAxis: xAxis,
    yAxis: yAxis,
  );
  final geometry = SeriesGeometry.layout(
    size: size,
    padding: EdgeInsets.zero,
    xAxis: xAxis,
    yAxis: yAxis,
    viewport: viewport,
    orientation: orientation,
  );
  final recorder = Recorder();
  SeriesChartPainter(
    geometry: geometry,
    series: series,
    values: values,
    xAxis: xAxis,
    yAxis: yAxis,
    grid: SeriesGrid.none,
    border: null,
    referenceLines: const [],
    bands: const [],
    betweenFills: betweenFills,
    backgroundColor: null,
    clipToPlot: true,
    textCache: TextPainterCache(capacity: 16),
  ).paint(recorder, size);
  return recorder;
}

void main() {
  group('a horizontal chart', () {
    test('runs its x axis down the plot and grows its values rightwards', () {
      const viewport = SeriesViewport(
        minX: 0,
        maxX: 10,
        minY: 0,
        maxY: 100,
        xTicks: [],
        yTicks: [],
        yStep: 10,
      );
      final geometry = SeriesGeometry(
        size: const Size(200, 100),
        plot: const Rect.fromLTRB(0, 0, 200, 100),
        viewport: viewport,
        orientation: SeriesOrientation.horizontal,
      );

      expect(geometry.point(0, 0), const Offset(0, 0));
      expect(geometry.point(10, 100), const Offset(200, 100));
      expect(geometry.point(5, 50), const Offset(100, 50));
      // The x under a touch is read down the chart, not across it.
      expect(geometry.pxToXAt(const Offset(180, 50)), 5);
    });

    test('lays the value axis along the bottom and the x axis down the '
        'left', () {
      final geometry = SeriesGeometry.layout(
        size: const Size(200, 100),
        padding: EdgeInsets.zero,
        xAxis: const SeriesXAxis(height: 30),
        yAxis: const SeriesYAxis(),
        viewport: const SeriesViewport(
          minX: 0,
          maxX: 1,
          minY: 0,
          maxY: 1,
          xTicks: [],
          yTicks: [],
          yStep: 1,
        ),
        orientation: SeriesOrientation.horizontal,
      );
      expect(geometry.plot.left, 30);
      expect(geometry.plot.right, 200);
      expect(geometry.plot.top, 0);
      expect(geometry.plot.bottom, lessThan(100));
    });

    test('grows its bars rightwards from the baseline', () {
      final recorder = paintChart(
        [
          BarSeries.values(const [1, 2], color: const Color(0xFF00FF00)),
        ],
        orientation: SeriesOrientation.horizontal,
        xAxis: SeriesXAxis.hidden,
        yAxis: SeriesYAxis.hidden,
      );
      expect(recorder.paths, hasLength(1));
      final bars = recorder.paths.single;
      expect(bars.left, 0);
      // The bars run rightwards out of the baseline rather than upwards.
      expect(bars.right, greaterThan(100));
      expect(bars.height, lessThan(100));
    });
  });

  group('stacked bars', () {
    final lower = BarSeries.values(const [2, 2], stack: 'a');
    final upper = BarSeries.values(const [3, 1], stack: 'a');

    test('a bar starts where the ones under it ended', () {
      final values = [
        [2.0, 2.0],
        [3.0, 1.0],
      ];
      expect(stackedBase([lower, upper], values, 0, 0), 0);
      expect(stackedBase([lower, upper], values, 1, 0), 2);
      expect(stackedBase([lower, upper], values, 1, 1), 2);
    });

    test('the value range reaches the top of the stack', () {
      final viewport = fitSeriesViewport(
        series: [lower, upper],
        values: [
          [2.0, 2.0],
          [3.0, 1.0],
        ],
        xAxis: const SeriesXAxis(),
        yAxis: const SeriesYAxis(),
        yPadding: 0,
      );
      expect(viewport.maxY, greaterThanOrEqualTo(5));
    });

    test('bars below the baseline stack downwards', () {
      final down = [
        BarSeries.values(const [-2], stack: 'a'),
        BarSeries.values(const [-3], stack: 'a'),
      ];
      final values = [
        [-2.0],
        [-3.0],
      ];
      expect(stackedBase(down, values, 1, 0), -2);
    });

    test('a stack stands in one place rather than side by side', () {
      final stacked = paintChart(
        [
          BarSeries.values(
            const [1, 1],
            stack: 'a',
            color: const Color(0xFF110000),
          ),
          BarSeries.values(
            const [1, 1],
            stack: 'a',
            color: const Color(0xFF220000),
          ),
        ],
        xAxis: SeriesXAxis.hidden,
        yAxis: SeriesYAxis.hidden,
      );
      final beside = paintChart(
        [
          BarSeries.values(const [1, 1], color: const Color(0xFF110000)),
          BarSeries.values(const [1, 1], color: const Color(0xFF220000)),
        ],
        xAxis: SeriesXAxis.hidden,
        yAxis: SeriesYAxis.hidden,
      );

      expect(stacked.paths[0].center.dx, stacked.paths[1].center.dx);
      expect(
        beside.paths[0].center.dx,
        isNot(closeTo(beside.paths[1].center.dx, 1)),
      );
    });
  });

  group('floating bars and error bars', () {
    test('a bar with a low runs between its two ends', () {
      final recorder = paintChart(
        [
          const BarSeries(
            points: [SeriesPoint(0, 8, low: 4)],
            color: Color(0xFF00FF00),
          ),
        ],
        xAxis: SeriesXAxis.hidden,
        yAxis: SeriesYAxis.hidden,
      );

      final bar = recorder.paths.single;
      expect(bar.top, greaterThan(0));
      expect(bar.bottom, lessThan(100));
    });

    test('the value range takes in the low end', () {
      final viewport = fitSeriesViewport(
        series: const [
          BarSeries(points: [SeriesPoint(0, 8, low: 4)]),
        ],
        values: const [
          [8.0],
        ],
        xAxis: const SeriesXAxis(),
        yAxis: const SeriesYAxis(),
        yPadding: 0,
        niceYRange: false,
      );
      expect(viewport.minY, lessThanOrEqualTo(0));
      expect(viewport.maxY, greaterThanOrEqualTo(8));
    });

    test('an error range draws a bar with a cap at either end', () {
      final recorder = paintChart(
        [
          const ScatterSeries(
            points: [SeriesPoint(0, 5, yError: SeriesErrorRange.symmetric(1))],
          ),
        ],
        xAxis: SeriesXAxis.hidden,
        yAxis: SeriesYAxis.hidden,
      );

      // The bar itself and one cap at each end.
      expect(recorder.lines, hasLength(3));
      final (from, to) = recorder.lines.first;
      expect(from.dx, closeTo(to.dx, 1e-9));
      expect(from.dy, greaterThan(to.dy));
    });

    test('the value range makes room for the error ranges', () {
      final viewport = fitSeriesViewport(
        series: const [
          ScatterSeries(
            points: [SeriesPoint(0, 5, yError: SeriesErrorRange(2, 3))],
          ),
        ],
        values: const [
          [5.0],
        ],
        xAxis: const SeriesXAxis(),
        yAxis: const SeriesYAxis(),
        yPadding: 0,
        niceYRange: false,
      );
      expect(viewport.maxY, greaterThanOrEqualTo(8));
    });
  });

  group('scatter', () {
    testWidgets('a touch picks the dot under the finger, not the whole x', (
      tester,
    ) async {
      final reported = <SeriesTouchDetails?>[];
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: SeriesChart(
                series: const [
                  ScatterSeries(
                    points: [SeriesPoint(0, 0), SeriesPoint(0, 10)],
                  ),
                ],
                xAxis: SeriesXAxis.hidden,
                yAxis: SeriesYAxis.hidden,
                minY: 0,
                maxY: 10,
                niceYRange: false,
                yPadding: 0,
                touch: const SeriesTouch(
                  snap: SeriesTouchSnap.nearestPoint,
                  trigger: SeriesTouchTrigger.press,
                ),
                onTouch: reported.add,
              ),
            ),
          ),
        ),
      );

      final chart = tester.getRect(find.byType(SeriesChart));
      // The top of the plot is the point at 10, the bottom the one at 0.
      await tester.startGesture(chart.topLeft + const Offset(2, 2));
      await tester.pumpAndSettle();

      expect(reported, isNotEmpty);
      final details = reported.whereType<SeriesTouchDetails>().first;
      expect(details.values, hasLength(1));
      expect(details.values.single.pointIndex, 1);
      expect(details.values.single.value, 10);
    });
  });

  group('lines', () {
    test('a step changes value where its step position says', () {
      const points = [Offset(0, 10), Offset(10, 0)];
      final late = seriesRunPath(points, LineCurve.step).getBounds();
      final middle = seriesRunPath(
        points,
        LineCurve.step,
        stepPosition: 0.5,
      ).getBounds();
      expect(late, middle);

      // Where the corner sits is what changes, so the paths differ in metric
      // length rather than in their bounds.
      expect(
        seriesRunPath(
          points,
          LineCurve.step,
          stepPosition: 0,
        ).computeMetrics().first.length,
        closeTo(20, 1e-6),
      );
    });

    test('a fill between two lines covers the gap between them', () {
      final recorder = paintChart(
        [
          LineSeries.values(const [10, 10], width: 0),
          LineSeries.values(const [0, 0], width: 0),
        ],
        betweenFills: const [
          SeriesBetweenFill(from: 0, to: 1, color: Color(0x8800FF00)),
        ],
        xAxis: SeriesXAxis.hidden,
        yAxis: SeriesYAxis.hidden,
      );
      expect(recorder.paths, hasLength(1));
      expect(recorder.paths.single.width, closeTo(200, 1));
    });

    test('a fill naming a series that is not there is left out', () {
      final recorder = paintChart(
        [
          LineSeries.values(const [1, 2], width: 0),
        ],
        betweenFills: const [
          SeriesBetweenFill(from: 0, to: 4, color: Color(0x8800FF00)),
        ],
        xAxis: SeriesXAxis.hidden,
        yAxis: SeriesYAxis.hidden,
      );
      expect(recorder.paths, isEmpty);
    });
  });

  group('axis titles', () {
    testWidgets('each axis writes its name beyond its labels', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 300,
              height: 200,
              child: SeriesChart(
                series: [
                  LineSeries.values(const [1, 2, 3]),
                ],
                xAxis: const SeriesXAxis(title: 'Day'),
                yAxis: const SeriesYAxis(title: 'Balance'),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    test('a title takes room off the plot', () {
      const viewport = SeriesViewport(
        minX: 0,
        maxX: 1,
        minY: 0,
        maxY: 1,
        xTicks: [],
        yTicks: [],
        yStep: 1,
      );
      final plain = SeriesGeometry.layout(
        size: const Size(200, 100),
        padding: EdgeInsets.zero,
        xAxis: const SeriesXAxis(),
        yAxis: const SeriesYAxis(),
        viewport: viewport,
      );
      final titled = SeriesGeometry.layout(
        size: const Size(200, 100),
        padding: EdgeInsets.zero,
        xAxis: const SeriesXAxis(title: 'Day'),
        yAxis: const SeriesYAxis(title: 'Balance'),
        viewport: viewport,
      );
      expect(titled.plot.width, lessThan(plain.plot.width));
      expect(titled.plot.height, lessThan(plain.plot.height));
    });

    test('an axis on the far side leaves its room on that side', () {
      const viewport = SeriesViewport(
        minX: 0,
        maxX: 1,
        minY: 0,
        maxY: 1,
        xTicks: [],
        yTicks: [],
        yStep: 1,
      );
      final flipped = SeriesGeometry.layout(
        size: const Size(200, 100),
        padding: EdgeInsets.zero,
        xAxis: const SeriesXAxis(side: SeriesXSide.top, height: 20),
        yAxis: const SeriesYAxis(side: SeriesAxisSide.right, width: 40),
        viewport: viewport,
      );
      expect(flipped.plot.left, 0);
      expect(flipped.plot.right, 160);
      expect(flipped.plot.top, 20);
      expect(flipped.plot.bottom, 100);
    });
  });
}
