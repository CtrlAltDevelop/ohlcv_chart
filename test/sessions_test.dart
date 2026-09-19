import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart/src/renderer/chart_painter.dart';

import 'test_utils.dart';

/// A US-equity-shaped session: 09:30 to 16:00, weekdays.
const _regular = TradingSession(
  open: Duration(hours: 9, minutes: 30),
  close: Duration(hours: 16),
);

DateTime _on(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2024, 1, day, hour, minute);

/// Candles every half hour from [from], however many are asked for.
List<KLineEntity> _halfHourly(DateTime from, int count) {
  final data = [
    for (var i = 0; i < count; i++)
      KLineEntity.fromCustom(
        open: 100.0 + i,
        high: 101.0 + i,
        low: 99.0 + i,
        close: 100.5 + i,
        vol: 100,
        dateTime: from.add(Duration(minutes: 30 * i)),
      ),
  ];
  DataUtil.calculate(data);
  return data;
}

Widget _chart(
  List<KLineEntity> data, {
  TradingSession? session,
  Color? Function(CandleEntity, int)? candleColor,
  ChartType type = ChartType.candles,
  ChartColors? colors,
}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: 500,
      height: 600,
      child: KChartWidget(
        data,
        colors ?? ChartColors(),
        isTrendLine: false,
        timeFrame: const Duration(minutes: 30),
        showNowPrice: false,
        chartType: type,
        session: session,
        candleColor: candleColor,
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

void main() {
  group('what counts as the regular session', () {
    test('inside the hours on a weekday', () {
      // 2024-01-01 was a Monday.
      expect(_regular.contains(_on(1, 10)), isTrue);
      expect(_regular.contains(_on(1, 9, 30)), isTrue, reason: 'the open');
      expect(_regular.contains(_on(1, 15, 59)), isTrue);
    });

    test('outside the hours, or on a weekend', () {
      expect(_regular.contains(_on(1, 9, 29)), isFalse, reason: 'pre-market');
      expect(_regular.contains(_on(1, 16)), isFalse, reason: 'the close');
      expect(_regular.contains(_on(1, 20)), isFalse, reason: 'after hours');
      // The 6th and 7th are the Saturday and Sunday.
      expect(_regular.contains(_on(6, 12)), isFalse);
      expect(_regular.contains(_on(7, 12)), isFalse);
    });

    test('an overnight session belongs to the day it opened on', () {
      // 22:00 to 06:00: opens Monday evening, closes Tuesday morning.
      const overnight = TradingSession(
        open: Duration(hours: 22),
        close: Duration(hours: 6),
      );

      expect(overnight.isOvernight, isTrue);
      expect(overnight.contains(_on(1, 23)), isTrue, reason: 'Monday night');
      expect(overnight.contains(_on(2, 3)), isTrue, reason: 'Tuesday morning');
      expect(overnight.contains(_on(2, 12)), isFalse, reason: 'the daytime');
      // Saturday morning belongs to Friday night, which is a weekday.
      expect(overnight.contains(_on(6, 3)), isTrue);
      // Saturday night is not.
      expect(overnight.contains(_on(6, 23)), isFalse);
      // Monday morning belongs to Sunday night, which is not.
      expect(overnight.contains(_on(1, 3)), isFalse);
    });

    test('the days it is kept can be chosen', () {
      const weekend = TradingSession(
        open: Duration(hours: 9),
        close: Duration(hours: 17),
        weekdays: {DateTime.saturday, DateTime.sunday},
      );

      expect(weekend.contains(_on(6, 12)), isTrue);
      expect(weekend.contains(_on(1, 12)), isFalse);
    });

    test('a round-the-clock market keeps every hour', () {
      const always = TradingSession(
        open: Duration.zero,
        close: Duration.zero,
        weekdays: {
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
          DateTime.friday,
          DateTime.saturday,
          DateTime.sunday,
        },
      );

      // open == close, so it is overnight and covers everything.
      expect(always.contains(_on(1, 0)), isTrue);
      expect(always.contains(_on(1, 12)), isTrue);
      expect(always.contains(_on(6, 23, 59)), isTrue);
    });

    test('two sessions over the same hours are equal', () {
      const a = TradingSession(
        open: Duration(hours: 9),
        close: Duration(hours: 17),
      );
      const b = TradingSession(
        open: Duration(hours: 9),
        close: Duration(hours: 17),
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(
          const TradingSession(
            open: Duration(hours: 8),
            close: Duration(hours: 17),
          ),
        ),
      );
      expect(
        a,
        isNot(
          const TradingSession(
            open: Duration(hours: 9),
            close: Duration(hours: 17),
            weekdays: {DateTime.monday},
          ),
        ),
      );
    });
  });

  group('extended hours on the chart', () {
    testWidgets('a session washes the stretches outside it', (tester) async {
      // Two days of half-hourly candles, so both sessions and both overnights
      // are on screen.
      final data = _halfHourly(_on(1, 0), 96);

      await tester.pumpWidget(_chart(data, session: _regular));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_painterOf(tester).session, same(_regular));
    });

    testWidgets('no session washes nothing', (tester) async {
      await tester.pumpWidget(_chart(_halfHourly(_on(1, 0), 48)));
      await tester.pumpAndSettle();

      expect(_painterOf(tester).session, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the wash colour falls back to something faint', (
      tester,
    ) async {
      final colors = ChartColors();
      expect(colors.extendedHoursColor, isNull);
      expect(colors.effectiveExtendedHoursColor.a, closeTo(0.07, 1e-6));

      colors.extendedHoursColor = const Color(0x33112233);
      expect(colors.effectiveExtendedHoursColor, const Color(0x33112233));
    });

    testWidgets('a market open round the clock is washed nowhere', (
      tester,
    ) async {
      const always = TradingSession(
        open: Duration.zero,
        close: Duration.zero,
        weekdays: {
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
          DateTime.friday,
          DateTime.saturday,
          DateTime.sunday,
        },
      );

      await tester.pumpWidget(
        _chart(_halfHourly(_on(1, 0), 48), session: always),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('candles with no timestamps are washed rather than crash', (
      tester,
    ) async {
      final data = candles(rampThenFall(30));
      DataUtil.calculate(data);

      await tester.pumpWidget(_chart(data, session: _regular));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('colouring a bar yourself', () {
    testWidgets('every bar is offered to the resolver', (tester) async {
      final seen = <int>[];
      await tester.pumpWidget(
        _chart(
          _halfHourly(_on(1, 0), 48),
          candleColor: (candle, index) {
            seen.add(index);
            return null;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(seen, isNotEmpty);
      // Only the ones on screen, and each in order.
      final painter = _painterOf(tester);
      expect(seen.first, painter.mStartIndex);
      expect(seen.last, painter.mStopIndex);
    });

    testWidgets('returning null leaves the usual colour', (tester) async {
      await tester.pumpWidget(
        _chart(_halfHourly(_on(1, 0), 48), candleColor: (_, _) => null),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('a colour of your own is taken, on every bar-shaped type', (
      tester,
    ) async {
      for (final type in [
        ChartType.candles,
        ChartType.bars,
        ChartType.columns,
      ]) {
        await tester.pumpWidget(
          _chart(
            _halfHourly(_on(1, 0), 48),
            type: type,
            candleColor: (_, index) =>
                index.isEven ? const Color(0xFF00FF00) : null,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$type');
      }
    });

    testWidgets('the candle handed over is the one being drawn', (
      tester,
    ) async {
      final data = _halfHourly(_on(1, 0), 48);
      final mismatched = <int>[];

      await tester.pumpWidget(
        _chart(
          data,
          candleColor: (candle, index) {
            if (candle.close != data[index].close) mismatched.add(index);
            return null;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(mismatched, isEmpty);
    });

    testWidgets('a rising candle stays up-coloured on an inverted axis', (
      tester,
    ) async {
      // Not about the resolver, but about the same fix: the colour comes from
      // the prices, so flipping the axis does not flip the colours.
      final data = _halfHourly(_on(1, 0), 48);
      final directions = <bool>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              height: 600,
              child: KChartWidget(
                data,
                ChartColors(),
                isTrendLine: false,
                timeFrame: const Duration(minutes: 30),
                showNowPrice: false,
                invertPriceAxis: true,
                candleColor: (candle, index) {
                  directions.add(candle.close >= candle.open);
                  return null;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Every candle in this series rises, and the resolver saw them all as
      // rising however the axis was drawn.
      expect(directions, isNotEmpty);
      expect(directions.every((up) => up), isTrue);
    });
  });
}
