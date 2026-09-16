import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

/// Golden tests over the painters.
///
/// They are what catches a change in how the chart is drawn that no unit test
/// would notice — a pane laid out a pixel out, a wash lost, a label moved. Text
/// is drawn in the test framework's own font, so the images are stable within a
/// Flutter version; run `flutter test --update-goldens` after a deliberate
/// change to how the chart looks, and after a Flutter upgrade.
DateTime _at(int minute) =>
    DateTime.utc(2024, 1, 1).add(Duration(minutes: minute));

/// A deterministic walk that looks enough like a market to be worth drawing.
List<KLineEntity> _market({int count = 80, double start = 100}) {
  final data = <KLineEntity>[];
  var price = start;
  for (var i = 0; i < count; i++) {
    // A sine wave with a drift: no randomness, so the goldens never wobble.
    final move = math.sin(i / 6) * 2.4 + 0.18;
    final open = price;
    final close = price + move;
    data.add(
      KLineEntity.fromCustom(
        open: open,
        high: math.max(open, close) + 1.1,
        low: math.min(open, close) - 1.1,
        close: close,
        vol: 800 + math.sin(i / 3) * 300,
        dateTime: _at(i * 15),
      ),
    );
    price = close;
  }
  DataUtil.calculate(data);
  return data;
}

Widget _framed(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF17181C),
        body: Center(child: SizedBox(width: 480, height: 420, child: child)),
      ),
    );

Widget _chart({
  List<KLineEntity>? data,
  ChartType? chartType,
  PriceAxisScale priceAxisScale = PriceAxisScale.linear,
  List<Indicator> indicators = const [],
  List<ChartLine> drawings = const [],
  ChartStyle style = const ChartStyle(),
  bool showOhlcLegend = false,
  bool volHidden = false,
  PriceAxisScale? secondaryPriceAxisScale,
  String Function(double)? priceFormatter,
}) =>
    _framed(
      KChartWidget(
        data ?? _market(),
        ChartColors(),
        isTrendLine: true,
        timeFrame: const Duration(minutes: 15),
        showNowPrice: false,
        showScrollToNowButton: false,
        chartType: chartType,
        priceAxisScale: priceAxisScale,
        secondaryPriceAxisScale: secondaryPriceAxisScale,
        priceFormatter: priceFormatter,
        indicators: indicators,
        drawings: drawings,
        chartStyle: style,
        showOhlcLegend: showOhlcLegend,
        volHidden: volHidden,
      ),
    );

void main() {
  Future<void> matches(WidgetTester tester, Widget widget, String name) async {
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(KChartWidget),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets('candles, volume and an indicator pane', (tester) async {
    await matches(
      tester,
      _chart(
        indicators: [
          MaIndicator(period: 5),
          MaIndicator(period: 20),
          MacdIndicator(),
        ],
      ),
      'candles',
    );
  });

  testWidgets('OHLC bars', (tester) async {
    await matches(tester, _chart(chartType: ChartType.bars), 'bars');
  });

  testWidgets('a line chart', (tester) async {
    await matches(tester, _chart(chartType: ChartType.line), 'line');
  });

  testWidgets('an area chart', (tester) async {
    await matches(tester, _chart(chartType: ChartType.area), 'area');
  });

  testWidgets('a baseline chart', (tester) async {
    await matches(tester, _chart(chartType: ChartType.baseline), 'baseline');
  });

  testWidgets('a step line', (tester) async {
    await matches(tester, _chart(chartType: ChartType.stepLine), 'step_line');
  });

  testWidgets('a high-low band with the close through it', (tester) async {
    await matches(tester, _chart(chartType: ChartType.hlcArea), 'hlc_area');
  });

  testWidgets('columns from the baseline', (tester) async {
    await matches(tester, _chart(chartType: ChartType.columns), 'columns');
  });

  testWidgets('Heikin-Ashi candles', (tester) async {
    final ha = CandleTransforms.heikinAshi(_market());
    DataUtil.calculate(ha);
    await matches(tester, _chart(data: ha), 'heikin_ashi');
  });

  testWidgets('Renko bricks', (tester) async {
    final bricks = CandleTransforms.renko(_market(), brickSize: 2);
    DataUtil.calculate(bricks);
    await matches(tester, _chart(data: bricks, volHidden: true), 'renko');
  });

  testWidgets('a logarithmic axis over a tenfold range', (tester) async {
    final data = [
      for (var i = 0; i < 60; i++)
        KLineEntity.fromCustom(
          open: 10 * math.pow(1.04, i).toDouble(),
          high: 10 * math.pow(1.04, i).toDouble() * 1.02,
          low: 10 * math.pow(1.04, i).toDouble() * 0.98,
          close: 10 * math.pow(1.04, i + 1).toDouble(),
          vol: 500,
          dateTime: _at(i * 15),
        ),
    ];
    DataUtil.calculate(data);

    await matches(
      tester,
      _chart(data: data, priceAxisScale: PriceAxisScale.logarithmic),
      'log_axis',
    );
  });

  testWidgets('the OHLC legend and day dividers', (tester) async {
    await matches(
      tester,
      _chart(
        showOhlcLegend: true,
        style: const ChartStyle(showSessionDividers: true),
      ),
      'legend_and_sessions',
    );
  });

  testWidgets('every drawing at once', (tester) async {
    // Anchored to the last stretch of candles, which is the part of the walk
    // the chart opens on.
    await matches(
      tester,
      _chart(
        volHidden: true,
        drawings: [
          HorizontalLine(price: 118, title: 'entry', showLabel: true),
          HorizontalLine(price: 110, startTime: _at(62 * 15)),
          VerticalLine(time: _at(56 * 15), title: 'open', showLabel: true),
          TrendLine(
            time1: _at(46 * 15),
            price1: 110,
            time2: _at(60 * 15),
            price2: 122,
            arrow: true,
          ),
          RectangleDrawing(
            time1: _at(62 * 15),
            price1: 122,
            time2: _at(70 * 15),
            price2: 114,
            label: 'range',
            showLabel: true,
          ),
          EllipseDrawing(
            time1: _at(72 * 15),
            price1: 121,
            time2: _at(78 * 15),
            price2: 113,
          ),
          FibRetracement(
            time1: _at(48 * 15),
            price1: 108,
            time2: _at(54 * 15),
            price2: 120,
          ),
          MeasureDrawing(
            time1: _at(64 * 15),
            price1: 112,
            time2: _at(74 * 15),
            price2: 124,
          ),
          TextAnnotation(time: _at(58 * 15), price: 124, text: 'CPI'),
        ],
      ),
      'drawings',
    );
  });

  testWidgets('a channel and a planned position', (tester) async {
    await matches(
      tester,
      _chart(
        volHidden: true,
        drawings: [
          ParallelChannel(
            time1: _at(46 * 15),
            price1: 110,
            time2: _at(70 * 15),
            price2: 120,
            time3: _at(58 * 15),
            price3: 124,
          ),
          PositionDrawing(
            time1: _at(60 * 15),
            price1: 116,
            time2: _at(78 * 15),
            price2: 124,
            time3: _at(78 * 15),
            price3: 112,
          ),
        ],
      ),
      'channel_and_position',
    );
  });

  testWidgets('a short series bunched up at the fixed spacing', (tester) async {
    await matches(
      tester,
      _chart(data: _market(count: 12), volHidden: true),
      'short_series',
    );
  });

  testWidgets('the same short series fitted to the width', (tester) async {
    await matches(
      tester,
      _chart(
        data: _market(count: 12),
        volHidden: true,
        style: const ChartStyle(fitContent: true),
      ),
      'fit_content',
    );
  });

  testWidgets('a second axis reading the change in percent', (tester) async {
    await matches(
      tester,
      _chart(
        secondaryPriceAxisScale: PriceAxisScale.percentage,
        style: const ChartStyle(
          priceAxisWidth: 56,
          secondaryPriceAxisWidth: 56,
        ),
        volHidden: true,
      ),
      'secondary_axis',
    );
  });

  testWidgets('prices written as currency', (tester) async {
    await matches(
      tester,
      _chart(
        priceFormatter: (price) => '\$${price.toStringAsFixed(1)}',
        showOhlcLegend: true,
        volHidden: true,
      ),
      'price_formatter',
    );
  });

  testWidgets('a level the axis cannot reach, marked at the edge', (
    tester,
  ) async {
    await matches(
      tester,
      _chart(
        drawings: [
          HorizontalLine(price: 400, title: 'Off the axis', showLabel: true),
        ],
        volHidden: true,
      ),
      'level_off_axis',
    );
  });
}
