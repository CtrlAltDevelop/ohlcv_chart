import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart/src/renderer/chart_painter.dart';

import 'test_utils.dart';

/// [count] candles, calculated.
List<KLineEntity> _candles([int count = 60]) {
  final data = candles(rampThenFall(count));
  DataUtil.calculate(data);
  return data;
}

Widget _chart(
  List<KLineEntity> data,
  List<Indicator> indicators, {
  void Function(Indicator, IndicatorAlert, KLineEntity, double)?
  onIndicatorAlert,
}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: 500,
      height: 700,
      child: KChartWidget(
        data,
        ChartColors(),
        isTrendLine: false,
        timeFrame: const Duration(minutes: 1),
        showNowPrice: false,
        indicators: indicators,
        onIndicatorAlert: onIndicatorAlert,
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

/// An indicator of one line, whose values, scale and alerts are all given.
class _Given extends Indicator {
  _Given(
    this.values, {
    this.scale = IndicatorScale.linear,
    this.alerts = const [],
    this.name = 'GIVEN',
  });

  final List<double?> values;

  @override
  final IndicatorScale scale;

  @override
  final List<IndicatorAlert> alerts;

  @override
  final String name;

  @override
  IndicatorPlacement get placement => IndicatorPlacement.pane;

  @override
  String get label => name;

  @override
  List<IndicatorLine> get lines => const [IndicatorLine('V')];

  @override
  List<Object?> get settings => [name, values.length];

  @override
  IndicatorSeries compute(List<KLineEntity> candles) => IndicatorSeries([
    [
      for (var i = 0; i < candles.length; i++)
        i < values.length ? values[i] : null,
    ],
  ]);

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) =>
      theme.ma5Color;
}

void main() {
  group('a pane on its own scale', () {
    test('linear is the default', () {
      expect(AtrIndicator().scale, IndicatorScale.linear);
      expect(MacdIndicator().scale, IndicatorScale.linear);
    });

    testWidgets('a log pane spaces its values by ratio', (tester) async {
      // A run from 1 to 1000: on a linear scale the middle of the pane is 500,
      // on a log scale it is about 31.
      final values = [for (var i = 0; i < 60; i++) 1.0 * (i + 1) * (i + 1)];

      await tester.pumpWidget(
        _chart(_candles(), [_Given(values, scale: IndicatorScale.logarithmic)]),
      );
      await tester.pumpAndSettle();

      final pane = _painterOf(tester).mIndicatorPaneList.single;
      expect(pane.isLogarithmic, isTrue);

      final middle = (pane.chartRect.top + pane.chartRect.bottom) / 2;
      final atMiddle = pane.getValue(middle);
      final linearMiddle = (pane.maxValue + pane.minValue) / 2;
      expect(atMiddle, lessThan(linearMiddle));
      // And it is the geometric middle, which is what log means.
      expect(
        atMiddle,
        closeTo((pane.maxValue * pane.minValue) / atMiddle, atMiddle * 0.05),
      );
    });

    testWidgets('getY and getValue are exact inverses', (tester) async {
      final values = [for (var i = 0; i < 60; i++) 1.0 * (i + 1) * (i + 1)];
      await tester.pumpWidget(
        _chart(_candles(), [_Given(values, scale: IndicatorScale.logarithmic)]),
      );
      await tester.pumpAndSettle();

      final pane = _painterOf(tester).mIndicatorPaneList.single;
      for (final value in [pane.minValue, 100.0, pane.maxValue]) {
        expect(pane.getValue(pane.getY(value)), closeTo(value, value * 1e-9));
      }
    });

    testWidgets('a pane reaching zero falls back to linear', (tester) async {
      final values = [for (var i = 0; i < 60; i++) i - 30.0];

      await tester.pumpWidget(
        _chart(_candles(), [_Given(values, scale: IndicatorScale.logarithmic)]),
      );
      await tester.pumpAndSettle();

      final pane = _painterOf(tester).mIndicatorPaneList.single;
      expect(pane.isLogarithmic, isFalse, reason: 'nothing to take a log of');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a percentage pane reads out the move from the window', (
      tester,
    ) async {
      final values = [for (var i = 0; i < 60; i++) 100.0 + i];

      await tester.pumpWidget(
        _chart(_candles(), [_Given(values, scale: IndicatorScale.percentage)]),
      );
      await tester.pumpAndSettle();

      final pane = _painterOf(tester).mIndicatorPaneList.single;
      expect(pane.percentBase, isNotNull);
      // A value 10% above the base reads as +10%.
      expect(pane.formatAxis(pane.percentBase! * 1.1), '+10.00%');
      expect(pane.formatAxis(pane.percentBase!), '+0.00%');
      expect(pane.formatAxis(pane.percentBase! * 0.95), '-5.00%');
    });

    testWidgets('a linear pane reads out its values, not percentages', (
      tester,
    ) async {
      final values = [for (var i = 0; i < 60; i++) 100.0 + i];

      await tester.pumpWidget(_chart(_candles(), [_Given(values)]));
      await tester.pumpAndSettle();

      final pane = _painterOf(tester).mIndicatorPaneList.single;
      expect(pane.percentBase, isNull);
      expect(pane.formatAxis(120), '120.00');
    });

    testWidgets('a percentage pane with nothing to measure from copes', (
      tester,
    ) async {
      await tester.pumpWidget(
        _chart(_candles(), [
          _Given(
            List<double?>.filled(60, null),
            scale: IndicatorScale.percentage,
          ),
        ]),
      );
      await tester.pumpAndSettle();

      final pane = _painterOf(tester).mIndicatorPaneList.single;
      expect(pane.percentBase, isNull);
      expect(pane.formatAxis(null), '--');
      expect(tester.takeException(), isNull);
    });
  });

  group('an indicator over an indicator', () {
    test('the applied indicator reads the source as if it were closes', () {
      final data = _candles(30);
      // A source that counts up by one, then an average of 3 over it.
      final source = _Given([for (var i = 0; i < 30; i++) i * 1.0]);
      final chained = ChainedIndicator(
        source: source,
        applied: MaIndicator(period: 3),
      );

      final values = chained.compute(data).lines.first;

      // The mean of 8, 9, 10 is 9.
      expect(values[10], closeTo(9, 1e-9));
      // Warming up takes the average's own period.
      expect(values[0], isNull);
      expect(values[1], isNull);
    });

    test("the source's own warm-up carries through", () {
      final data = _candles(30);
      // Nothing until candle 10.
      final source = _Given([
        for (var i = 0; i < 30; i++) i < 10 ? null : i * 1.0,
      ]);
      final chained = ChainedIndicator(
        source: source,
        applied: MaIndicator(period: 3),
      );

      final values = chained.compute(data).lines.first;

      expect(values.take(10).every((v) => v == null), isTrue);
      expect(values[12], isNotNull);
    });

    test('it takes its identity, name and label from both halves', () {
      final chained = ChainedIndicator(
        source: MacdIndicator(),
        applied: MaIndicator(period: 9),
      );

      expect(chained.name, 'MA(MACD)');
      expect(chained.label, contains('MACD'));
      expect(chained.placement, MaIndicator(period: 9).placement);

      // Two the same are the same indicator; a different period is not.
      expect(
        chained,
        ChainedIndicator(
          source: MacdIndicator(),
          applied: MaIndicator(period: 9),
        ),
      );
      expect(
        chained,
        isNot(
          ChainedIndicator(
            source: MacdIndicator(),
            applied: MaIndicator(period: 20),
          ),
        ),
      );
    });

    test('it borrows the applied indicator’s pane settings', () {
      final chained = ChainedIndicator(
        source: MacdIndicator(),
        applied: RsiIndicator(period: 14),
      );

      expect(chained.guides, RsiIndicator(period: 14).guides);
      expect(chained.fixedRange, RsiIndicator(period: 14).fixedRange);
      expect(chained.format, RsiIndicator(period: 14).format);
      expect(chained.lines.length, RsiIndicator(period: 14).lines.length);
    });

    test('a line the source does not have draws nothing', () {
      final data = _candles(30);
      final chained = ChainedIndicator(
        source: _Given([for (var i = 0; i < 30; i++) i * 1.0]),
        applied: MaIndicator(period: 3),
        sourceLine: 7,
      );

      final values = chained.compute(data).lines.first;
      expect(values.every((v) => v == null), isTrue);
    });

    test('a source line other than the first can be read', () {
      final data = _candles(60);
      // The MACD's signal line, smoothed again.
      final chained = ChainedIndicator(
        source: MacdIndicator(),
        applied: MaIndicator(period: 3),
        sourceLine: 1,
      );

      expect(chained.compute(data).lines.first.last, isNotNull);
    });

    test('flattening leaves a candle with no range at all', () {
      final data = _candles(10);
      final flat = flattenToCandles(data, [
        for (var i = 0; i < 10; i++) 50.0 + i,
      ]);

      expect(flat, hasLength(10));
      for (final (i, candle) in flat.indexed) {
        expect(candle.open, candle.close);
        expect(candle.high, candle.low);
        expect(candle.close, 50.0 + i);
        expect(candle.dateTime, data[i].dateTime);
        expect(candle.vol, data[i].vol);
      }
    });

    test('a leading run of nulls is held at the first known value', () {
      final data = _candles(10);
      final flat = flattenToCandles(data, [
        null,
        null,
        50,
        51,
        52,
        53,
        54,
        55,
        56,
        57,
      ]);

      // Not zero, which would look to the applied indicator like a crash.
      expect(flat.first.close, 50);
      expect(flat[1].close, 50);
    });

    test('no values at all flattens to a flat nothing', () {
      final data = _candles(5);
      final flat = flattenToCandles(data, const []);

      expect(flat, hasLength(5));
      expect(flat.every((c) => c.close == 0), isTrue);
    });

    testWidgets('a chained indicator draws in its own pane', (tester) async {
      await tester.pumpWidget(
        _chart(_candles(), [
          MacdIndicator(),
          ChainedIndicator(
            source: MacdIndicator(),
            applied: RsiIndicator(period: 14),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_painterOf(tester).mIndicatorPaneList, hasLength(2));
    });
  });

  group('indicator alerts', () {
    test('an indicator has none by default', () {
      expect(RsiIndicator(period: 14).alerts, isEmpty);
    });

    test('two alerts on the same level are the same alert', () {
      expect(const IndicatorAlert(level: 70), const IndicatorAlert(level: 70));
      expect(
        const IndicatorAlert(level: 70).hashCode,
        const IndicatorAlert(level: 70).hashCode,
      );
      expect(
        const IndicatorAlert(level: 70),
        isNot(const IndicatorAlert(level: 70, line: 1)),
      );
    });

    testWidgets('a value crossing a level is reported once', (tester) async {
      final reports = <(Indicator, double)>[];
      final data = _candles(30);

      // Below the level, so the first sighting only sets the side.
      await tester.pumpWidget(
        _chart(
          data,
          [
            _Given(
              List<double?>.filled(30, 10),
              alerts: const [IndicatorAlert(level: 50, label: 'over 50')],
            ),
          ],
          onIndicatorAlert: (indicator, alert, candle, value) =>
              reports.add((indicator, value)),
        ),
      );
      await tester.pumpAndSettle();
      expect(reports, isEmpty);

      // Now above it.
      await tester.pumpWidget(
        _chart(
          data,
          [
            _Given(
              List<double?>.filled(30, 90),
              alerts: const [IndicatorAlert(level: 50, label: 'over 50')],
            ),
          ],
          onIndicatorAlert: (indicator, alert, candle, value) =>
              reports.add((indicator, value)),
        ),
      );
      await tester.pumpAndSettle();

      expect(reports, hasLength(1));
      expect(reports.single.$2, 90);
    });

    testWidgets('staying on one side reports nothing', (tester) async {
      final reports = <double>[];
      final data = _candles(30);

      Widget chart(double value) => _chart(data, [
        _Given(
          List<double?>.filled(30, value),
          alerts: const [IndicatorAlert(level: 50)],
        ),
      ], onIndicatorAlert: (_, _, _, v) => reports.add(v));

      await tester.pumpWidget(chart(10));
      await tester.pumpAndSettle();
      await tester.pumpWidget(chart(20));
      await tester.pumpAndSettle();
      await tester.pumpWidget(chart(30));
      await tester.pumpAndSettle();

      expect(reports, isEmpty);
    });

    testWidgets('an overlay can be alerted on too', (tester) async {
      final reports = <double>[];
      final data = _candles(30);

      Widget chart(double value) => _chart(data, [
        _OverlayGiven(
          List<double?>.filled(30, value),
          alerts: const [IndicatorAlert(level: 50)],
        ),
      ], onIndicatorAlert: (_, _, _, v) => reports.add(v));

      await tester.pumpWidget(chart(10));
      await tester.pumpAndSettle();
      await tester.pumpWidget(chart(90));
      await tester.pumpAndSettle();

      expect(reports, [90]);
    });

    testWidgets('an alert on a line with no value stays quiet', (tester) async {
      final reports = <double>[];
      await tester.pumpWidget(
        _chart(_candles(30), [
          _Given(
            List<double?>.filled(30, null),
            alerts: const [IndicatorAlert(level: 50)],
          ),
        ], onIndicatorAlert: (_, _, _, v) => reports.add(v)),
      );
      await tester.pumpAndSettle();

      expect(reports, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}

/// The same given indicator, drawn over the candles instead of in a pane.
class _OverlayGiven extends _Given {
  _OverlayGiven(super.values, {super.alerts}) : super(name: 'OVERLAYGIVEN');

  @override
  IndicatorPlacement get placement => IndicatorPlacement.overlay;
}
