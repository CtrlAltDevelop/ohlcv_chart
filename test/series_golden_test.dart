import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

/// Golden tests over [SeriesChart]: what an area, a set of bars and several
/// lines with a tooltip look like. Run `flutter test --update-goldens` after a
/// deliberate change to how they are drawn.
Widget _framed(Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  home: Scaffold(
    backgroundColor: const Color(0xFF17181C),
    body: Center(
      child: SizedBox(
        width: 480,
        height: 300,
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      ),
    ),
  ),
);

const _purple = Color(0xFF9775FA);
const _green = Color(0xFF12B886);
const _red = Color(0xFFFA5252);
const _amber = Color(0xFFFAB005);
const _gridColor = Color(0xFF2C2E33);

List<double> _wave(int count, {double phase = 0, double scale = 1}) => [
  for (var i = 0; i < count; i++)
    (math.sin(i / 3 + phase) * 40 + i * 1.5 - 12) * scale,
];

void main() {
  testWidgets('an area crossing zero', (tester) async {
    await tester.pumpWidget(
      _framed(
        SeriesChart(
          series: [
            LineSeries.values(
              _wave(24),
              color: _green,
              negativeColor: _red,
              curve: LineCurve.monotone,
              fill: SeriesFill.fade(_green, negativeColor: _red),
            ),
          ],
          xAxis: SeriesXAxis(
            labels: [
              for (var i = 0; i < 24; i++) i % 6 == 0 ? 'W${i ~/ 6 + 1}' : '',
            ],
          ),
          grid: const SeriesGrid(color: _gridColor, dashPattern: [4, 4]),
          border: const BorderSide(color: _gridColor),
          referenceLines: const [
            SeriesReferenceLine.horizontal(
              0,
              color: Color(0xFF5C5F66),
              dashPattern: [3, 3],
            ),
          ],
        ),
      ),
    );

    await expectLater(
      find.byType(SeriesChart),
      matchesGoldenFile('goldens/series_area.png'),
    );
  });

  testWidgets('rounded profit bars', (tester) async {
    await tester.pumpWidget(
      _framed(
        SeriesChart(
          series: [
            BarSeries.values(
              _wave(18, phase: 1),
              color: _green,
              negativeColor: _red,
              radius: const BorderRadius.vertical(top: Radius.circular(3)),
              minWidth: 3.5,
              maxWidth: 12,
            ),
          ],
          xAxis: const SeriesXAxis(interval: 3),
          grid: const SeriesGrid(
            vertical: false,
            color: _gridColor,
            dashPattern: [4, 4],
          ),
          border: const BorderSide(color: _gridColor),
        ),
      ),
    );

    await expectLater(
      find.byType(SeriesChart),
      matchesGoldenFile('goldens/series_bars.png'),
    );
  });

  testWidgets('several lines with a tooltip', (tester) async {
    final controller = SeriesChartController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _framed(
        SeriesChart(
          series: [
            LineSeries.values(
              _wave(30, scale: 20).map((v) => v + 1500).toList(),
              label: 'Deposits',
              color: _purple,
              fill: SeriesFill.fade(_purple, opacity: 0.2),
            ),
            LineSeries.values(
              _wave(30, phase: 2, scale: 12).map((v) => v + 900).toList(),
              label: 'Withdrawals',
              color: _amber,
              dashPattern: const [6, 4],
            ),
          ],
          yAxis: SeriesYAxis(
            width: 44,
            formatter: (v) => '\$${(v / 1000).toStringAsFixed(1)}k',
          ),
          grid: const SeriesGrid(color: _gridColor, dashPattern: [4, 4]),
          border: const BorderSide(color: _gridColor),
          controller: controller,
          touch: SeriesTouch(
            tooltip: SeriesTooltip(
              title: (d) => 'Day ${d.index + 1}',
              showSeriesLabels: true,
            ),
          ),
        ),
      ),
    );
    controller.show(12);
    await tester.pump();

    await expectLater(
      find.byType(SeriesChart),
      matchesGoldenFile('goldens/series_lines_tooltip.png'),
    );
  });
}
