import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart/src/renderer/chart_painter.dart';

import 'test_utils.dart';

const double _width = 500;
const double _height = 600;

// Distinct colours so the probe can tell row lines from column lines.
const Color _rowColor = Color(0xFF112233);
const Color _columnColor = Color(0xFF445566);

ChartPainter _painterOf(WidgetTester tester) {
  final dynamic state = tester.state(find.byType(KChartWidget));
  // ignore: avoid_dynamic_calls
  return state.painter as ChartPainter;
}

Widget _chart({required ChartStyle style, int count = 3}) {
  final data = candles(rampThenFall(count));
  DataUtil.calculate(data);
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: _width,
        height: _height,
        child: KChartWidget(
          data,
          ChartColors(gridColor: _rowColor, gridColumnColor: _columnColor),
          isTrendLine: false,
          timeFrame: const Duration(minutes: 15),
          chartStyle: style,
        ),
      ),
    ),
  );
}

/// Records every line drawn, with the colour it was drawn in.
class _LineProbe implements Canvas {
  final List<(Offset, Offset, Color)> lines = [];

  Iterable<(Offset, Offset, Color)> get columns =>
      lines.where((l) => l.$3.toARGB32() == _columnColor.toARGB32());
  Iterable<(Offset, Offset, Color)> get rows =>
      lines.where((l) => l.$3.toARGB32() == _rowColor.toARGB32());

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    lines.add((p1, p2, paint.color));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<_LineProbe> _paint(WidgetTester tester, ChartStyle style) async {
  await tester.pumpWidget(_chart(style: style));
  final probe = _LineProbe();
  _painterOf(tester).paint(probe, const Size(_width, _height));
  return probe;
}

/// Distinct x positions of the vertical column lines in the main pane.
List<double> _columnXs(_LineProbe probe) =>
    ({for (final l in probe.columns) l.$1.dx}.toList()..sort());

void main() {
  testWidgets('evenlySpaced spans the chart however few candles there are', (
    tester,
  ) async {
    final probe = await _paint(
      tester,
      ChartStyle(gridColumnMode: GridColumnMode.evenlySpaced),
    );
    final xs = _columnXs(probe);
    expect(xs.length, ChartStyle().gridColumns + 1);
    final gaps = [for (var i = 1; i < xs.length; i++) xs[i] - xs[i - 1]];
    for (final gap in gaps) {
      expect(gap, closeTo(gaps.first, 0.01));
    }
  });

  testWidgets('dateTicks stays the default and clusters on sparse data', (
    tester,
  ) async {
    expect(ChartStyle().gridColumnMode, GridColumnMode.dateTicks);
    final probe = await _paint(tester, ChartStyle());
    // Three candles cross at most a couple of time buckets.
    expect(_columnXs(probe).length, lessThanOrEqualTo(2));
  });

  testWidgets('showGridColumns: false draws no vertical lines', (tester) async {
    final probe = await _paint(tester, ChartStyle(showGridColumns: false));
    expect(probe.columns, isEmpty);
    expect(probe.rows, isNotEmpty);
  });

  testWidgets('showGridRows: false draws no price lines', (tester) async {
    final all = await _paint(tester, ChartStyle());
    final probe = await _paint(
      tester,
      ChartStyle(
        showGridRows: false,
        gridColumnMode: GridColumnMode.evenlySpaced,
      ),
    );
    // Only the pane borders remain; they are not part of the grid.
    expect(probe.rows.length, lessThan(all.rows.length ~/ 2));
    expect(probe.columns, isNotEmpty);
  });

  testWidgets('gridDashPattern breaks lines into segments', (tester) async {
    final solid = await _paint(tester, ChartStyle());
    final dashed = await _paint(
      tester,
      ChartStyle(gridDashPattern: const [4, 3]),
    );
    expect(dashed.rows.length, greaterThan(solid.rows.length));
    expect(dashed.columns.length, greaterThan(solid.columns.length));
    final dashes = dashed.rows.where((l) => (l.$2 - l.$1).distance <= 4.001);
    expect(dashes, isNotEmpty);
  });

  testWidgets('an invalid dash pattern falls back to solid', (tester) async {
    final solid = await _paint(tester, ChartStyle());
    for (final bad in [
      const <double>[],
      const [0.0, 3.0],
      const [4.0, -1.0],
      const [double.infinity],
    ]) {
      final probe = await _paint(tester, ChartStyle(gridDashPattern: bad));
      expect(probe.rows.length, solid.rows.length, reason: '$bad');
    }
  });

  test('copyWith carries the grid options', () {
    final style = ChartStyle().copyWith(
      gridColumnMode: GridColumnMode.evenlySpaced,
      showGridRows: false,
      showGridColumns: false,
      gridDashPattern: const [2, 2],
    );
    expect(style.gridColumnMode, GridColumnMode.evenlySpaced);
    expect(style.showGridRows, isFalse);
    expect(style.showGridColumns, isFalse);
    expect(style.gridDashPattern, const [2.0, 2.0]);
    // Untouched fields survive.
    expect(style.gridColumns, ChartStyle().gridColumns);
  });
}
