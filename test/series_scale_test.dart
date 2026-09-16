import 'dart:ui';

import 'package:flutter/painting.dart' show EdgeInsets;
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart/src/series/series_axis.dart'
    show formatSeriesNumber;
import 'package:ohlcv_chart/src/series/series_paths.dart';
import 'package:ohlcv_chart/src/series/series_scale.dart';

List<List<double?>> _valuesOf(List<PlotSeries> series) => [
      for (final s in series) [for (final p in s.points) p.isGap ? null : p.y],
    ];

SeriesViewport _fit(
  List<PlotSeries> series, {
  SeriesXAxis xAxis = const SeriesXAxis(),
  SeriesYAxis yAxis = const SeriesYAxis(),
  List<SeriesReferenceLine> referenceLines = const [],
  double? minX,
  double? maxX,
  double? minY,
  double? maxY,
}) =>
    fitSeriesViewport(
      series: series,
      values: _valuesOf(series),
      xAxis: xAxis,
      yAxis: yAxis,
      referenceLines: referenceLines,
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
    );

void main() {
  group('fitSeriesViewport', () {
    test('spans the points and widens the values to round ticks', () {
      final viewport = _fit([
        LineSeries.values([10, 20, 15, 30]),
      ]);

      expect(viewport.minX, 0);
      expect(viewport.maxX, 3);
      expect(viewport.minY, 5);
      expect(viewport.maxY, 35);
      expect(viewport.yTicks, [5, 10, 15, 20, 25, 30, 35]);
    });

    test('never pads a series that stays above zero below it', () {
      final viewport = _fit([
        LineSeries.values([0, 5, 10]),
      ]);

      expect(viewport.minY, 0);
      expect(viewport.maxY, greaterThan(10));
    });

    test('bars reach their baseline and get half a unit either side', () {
      final viewport = _fit([
        BarSeries.values([5, 8]),
      ]);

      expect(viewport.minX, -0.5);
      expect(viewport.maxX, 1.5);
      expect(viewport.minY, 0);
    });

    test('keeps the bounds it is given', () {
      final viewport = _fit(
        [
          LineSeries.values([1, 2]),
        ],
        minY: -3,
        maxY: 7,
      );

      expect(viewport.minY, -3);
      expect(viewport.maxY, 7);
    });

    test('fits the values only to the x window in view', () {
      final viewport = _fit(
        [
          LineSeries.values([100, 1, 2, 3]),
        ],
        minX: 0.5,
        maxX: 3.5,
      );

      expect(viewport.maxY, lessThan(10));
    });

    test('gives a flat series a range of its own', () {
      final viewport = _fit([
        LineSeries.values([5, 5, 5]),
      ]);

      expect(viewport.maxY, greaterThan(viewport.minY));
      expect(viewport.minY, lessThan(5));
      expect(viewport.maxY, greaterThan(5));
    });

    test('labels the indices whose label is not blank', () {
      final viewport = _fit([
        LineSeries.values([1, 2, 3, 4, 5, 6]),
      ], xAxis: const SeriesXAxis(labels: ['Jan', '', '', 'Feb', '', 'Mar']));

      expect(viewport.xTicks, [0, 3, 5]);
    });

    test('rules only the value ticks it is given, inside the range', () {
      final viewport = _fit([
        LineSeries.values([0, 100]),
      ], yAxis: const SeriesYAxis(ticks: [0, 50, 100, 1000]));

      expect(viewport.yTicks, [0, 50, 100]);
    });

    test('takes a reference line into the range only when it asks', () {
      final series = [
        LineSeries.values([1, 2]),
      ];

      expect(
        _fit(
          series,
          referenceLines: const [SeriesReferenceLine.horizontal(10)],
        ).maxY,
        lessThan(10),
      );
      expect(
        _fit(
          series,
          referenceLines: const [
            SeriesReferenceLine.horizontal(10, extendsRange: true),
          ],
        ).maxY,
        greaterThanOrEqualTo(10),
      );
    });

    test('maps values to pixels and back', () {
      final geometry = SeriesGeometry.layout(
        size: const Size(200, 100),
        padding: EdgeInsets.zero,
        xAxis: SeriesXAxis.hidden,
        yAxis: SeriesYAxis.hidden,
        viewport: const SeriesViewport(
          minX: 0,
          maxX: 4,
          minY: 0,
          maxY: 10,
          xTicks: [],
          yTicks: [],
          yStep: 1,
        ),
      );

      expect(geometry.plot, const Rect.fromLTWH(0, 0, 200, 100));
      expect(geometry.xToPx(2), 100);
      expect(geometry.yToPx(10), 0);
      expect(geometry.yToPx(0), 100);
      expect(geometry.pxToX(50), 1);
    });
  });

  group('paths', () {
    test('a monotone curve never swings past the points either side', () {
      const points = [
        Offset(0, 0),
        Offset(10, 10),
        Offset(20, 10),
        Offset(30, 0),
        Offset(40, 5),
        Offset(50, 50),
      ];
      final path = Path();
      addSeriesRun(path, points, LineCurve.monotone);

      final metric = path.computeMetrics().single;
      for (var d = 0.0; d <= metric.length; d += 0.5) {
        final p = metric.getTangentForOffset(d)!.position;
        var segment = 0;
        while (segment < points.length - 2 && p.dx > points[segment + 1].dx) {
          segment++;
        }
        final a = points[segment].dy;
        final b = points[segment + 1].dy;
        expect(
          p.dy,
          inInclusiveRange((a < b ? a : b) - 0.01, (a > b ? a : b) + 0.01),
          reason: 'at $p',
        );
      }
    });

    test('dashes cut a line into its pattern', () {
      final line = Path()
        ..moveTo(0, 0)
        ..lineTo(100, 0);
      final metrics = dashSeriesPath(line, [10, 10]).computeMetrics().toList();

      expect(metrics, hasLength(5));
      expect(
        metrics.fold<double>(0, (sum, m) => sum + m.length),
        closeTo(50, 0.001),
      );
      expect(identical(dashSeriesPath(line, null), line), isTrue);
    });

    test('a bar is rounded on the end away from its baseline', () {
      final up = seriesBarShape(
        left: 0,
        right: 10,
        valueY: 20,
        baseY: 100,
        radius: 3,
      )!;
      expect(up.tlRadiusX, 3);
      expect(up.blRadiusX, 0);

      final down = seriesBarShape(
        left: 0,
        right: 10,
        valueY: 150,
        baseY: 100,
        radius: 3,
      )!;
      expect(down.tlRadiusX, 0);
      expect(down.blRadiusX, 3);

      final wide = seriesBarShape(
        left: 0,
        right: 10,
        valueY: 0,
        baseY: 100,
        radius: 50,
      )!;
      expect(wide.tlRadiusX, 5);

      expect(
        seriesBarShape(left: 0, right: 10, valueY: 50, baseY: 50, radius: 3),
        isNull,
      );
    });
  });

  test('numbers get the decimals their step needs', () {
    expect(formatSeriesNumber(5, 1), '5');
    expect(formatSeriesNumber(7.5, 2.5), '7.5');
    expect(formatSeriesNumber(0.25, 0.25), '0.25');
    expect(formatSeriesNumber(1, 0.25), '1.00');
    expect(formatSeriesNumber(0.3, 0.1), '0.3');
  });

  test('an x label between whole numbers keeps its decimals', () {
    const axis = SeriesXAxis();
    expect(axis.labelFor(0.5, step: 0.5), '0.5');
    // Every label on an axis stepping by 0.5 carries one decimal, whole or not.
    expect(axis.labelFor(2, step: 0.5), '2.0');
    expect(axis.labelFor(3), '3');

    final viewport = _fit([
      LineSeries(
        points: const [
          SeriesPoint(0, 1),
          SeriesPoint(0.5, 2),
          SeriesPoint(1, 3),
        ],
      ),
    ], xAxis: const SeriesXAxis(interval: 0.25));
    expect(viewport.xTicks, [0, 0.25, 0.5, 0.75, 1]);
    expect(viewport.xStep, 0.25);
  });
}
