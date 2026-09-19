import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart/src/renderer/chart_painter.dart';

import 'test_utils.dart';

const double _width = 500;
const double _height = 600;

ChartPainter _painterOf(WidgetTester tester) {
  final dynamic state = tester.state(find.byType(KChartWidget));
  // ignore: avoid_dynamic_calls
  return state.painter as ChartPainter;
}

Widget _chart({
  String Function(double)? priceFormatter,
  PriceAxisScale scale = PriceAxisScale.linear,
}) {
  final data = candles(rampThenFall(120));
  DataUtil.calculate(data);

  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: _width,
        height: _height,
        child: KChartWidget(
          data,
          ChartColors(),
          isTrendLine: false,
          timeFrame: const Duration(minutes: 15),
          showNowPrice: true,
          priceAxisScale: scale,
          priceFormatter: priceFormatter,
        ),
      ),
    ),
  );
}

void main() {
  group('priceFormatter', () {
    testWidgets('writes the axis labels', (tester) async {
      await tester.pumpWidget(
        _chart(priceFormatter: (p) => '\$${p.toStringAsFixed(1)}'),
      );
      final painter = _painterOf(tester);

      expect(painter.mMainRenderer.formatAxis(1234.5), r'$1234.5');
    });

    testWidgets('is left out, prices are the plain decimals', (tester) async {
      await tester.pumpWidget(_chart());
      final painter = _painterOf(tester);

      expect(painter.mMainRenderer.formatAxis(1234.5), '1234.50');
    });

    testWidgets('writes the on-chart prices too', (tester) async {
      await tester.pumpWidget(
        _chart(priceFormatter: (p) => '${p.toStringAsFixed(0)} USD'),
      );
      final painter = _painterOf(tester);

      expect(painter.mMainRenderer.formatPrice(99.4), '99 USD');
    });

    testWidgets('is not asked by an axis that reads out a move', (
      tester,
    ) async {
      await tester.pumpWidget(
        _chart(
          scale: PriceAxisScale.percentage,
          priceFormatter: (p) => 'never',
        ),
      );
      final painter = _painterOf(tester);
      final base = painter.mMainRenderer.percentBase;

      expect(base, isNotNull);
      expect(painter.mMainRenderer.formatAxis(base! * 1.1), '+10.00%');
    });

    testWidgets('a chart with one paints without complaint', (tester) async {
      await tester.pumpWidget(
        _chart(priceFormatter: (p) => '\$${p.toStringAsFixed(1)}'),
      );

      _painterOf(
        tester,
      ).paint(Canvas(ui.PictureRecorder()), const Size(_width, _height));
      expect(tester.takeException(), isNull);
    });
  });
}
