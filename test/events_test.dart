import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart/src/renderer/chart_painter.dart';

import 'test_utils.dart';

DateTime _at(int minute) =>
    DateTime.utc(2024, 1, 1).add(Duration(minutes: minute));

/// [count] candles, calculated, one a minute from 2024-01-01.
List<KLineEntity> _candles([int count = 60]) {
  final data = candles(rampThenFall(count));
  DataUtil.calculate(data);
  return data;
}

Widget _chart(
  List<KLineEntity> data,
  List<ChartEvent> events, {
  ValueChanged<ChartEvent>? onEventTapped,
  ChartStyle? style,
  ChartColors? colors,
}) =>
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 500,
          height: 600,
          child: KChartWidget(
            data,
            colors ?? ChartColors(),
            isTrendLine: false,
            timeFrame: const Duration(minutes: 1),
            showNowPrice: false,
            chartStyle: style ?? ChartStyle(),
            events: events,
            onEventTapped: onEventTapped,
          ),
        ),
      ),
    );

/// The painter the chart is currently drawing with.
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

/// Where the badge for the event at [index] is painted.
Offset _badgeAt(WidgetTester tester, int index) {
  final painter = _painterOf(tester);
  final chart = tester.getTopLeft(find.byType(KChartWidget));
  final radius = ChartStyle().eventMarkRadius;
  return chart +
      Offset(
        painter.translateXtoX(painter.getX(index)),
        painter.mMainRect.bottom - radius - ChartStyle().eventMarkGap,
      );
}

void main() {
  group('lining events up with the candles', () {
    test('each event takes the candle nearest its own time', () {
      final data = _candles();
      final resolved = resolveEvents(
        [for (final c in data) c.dateTime],
        [
          ChartEvent(time: _at(10)),
          // Mid-bar, so it marks the bar it fell in.
          ChartEvent(time: _at(20).add(const Duration(seconds: 20))),
          ChartEvent(time: _at(30).add(const Duration(seconds: 50))),
        ],
      );

      expect(resolved.map((r) => r.index), [10, 20, 31]);
    });

    test('the result is in candle order, whatever order it was given in', () {
      final data = _candles();
      final resolved = resolveEvents(
        [for (final c in data) c.dateTime],
        [
          ChartEvent(time: _at(40)),
          ChartEvent(time: _at(5)),
          ChartEvent(time: _at(20)),
        ],
      );

      expect(resolved.map((r) => r.index), [5, 20, 40]);
    });

    test('an event beyond the data marks the nearest end of it', () {
      final data = _candles(10);
      final times = [for (final c in data) c.dateTime];

      expect(
        resolveEvents(times, [
          ChartEvent(time: DateTime.utc(2000)),
        ]).single.index,
        0,
      );
      expect(
        resolveEvents(times, [
          ChartEvent(time: DateTime.utc(2030)),
        ]).single.index,
        9,
      );
    });

    test('nothing to mark, or nowhere to mark it, is nothing', () {
      expect(resolveEvents(const [], [ChartEvent(time: _at(0))]), isEmpty);
      expect(
        resolveEvents([for (final c in _candles()) c.dateTime], const []),
        isEmpty,
      );
      // Candles with no times cannot be matched to.
      expect(
        resolveEvents(const [null, null], [ChartEvent(time: _at(0))]),
        isEmpty,
      );
    });
  });

  group('what an event says about itself', () {
    test('each kind has a letter of its own', () {
      expect(
        ChartEvent(time: _at(0), kind: ChartEventKind.earnings).badgeText,
        'E',
      );
      expect(
        ChartEvent(time: _at(0), kind: ChartEventKind.dividend).badgeText,
        'D',
      );
      expect(
        ChartEvent(time: _at(0), kind: ChartEventKind.split).badgeText,
        'S',
      );
      expect(
        ChartEvent(time: _at(0), kind: ChartEventKind.news).badgeText,
        'N',
      );
      expect(ChartEvent(time: _at(0)).badgeText, '•');
    });

    test('a label of its own wins over the kind', () {
      expect(
        ChartEvent(
          time: _at(0),
          kind: ChartEventKind.earnings,
          label: 'Q3',
        ).badgeText,
        'Q3',
      );
    });

    test('every kind is accounted for', () {
      for (final kind in ChartEventKind.values) {
        expect(ChartEvent.defaultLabelOf(kind), isNotEmpty);
      }
    });

    test('two events over the same thing are equal', () {
      ChartEvent of() => ChartEvent(
            time: _at(5),
            kind: ChartEventKind.dividend,
            label: 'D',
            detail: 'ex-date',
          );

      expect(of(), of());
      expect(of().hashCode, of().hashCode);
      expect(of(), isNot(ChartEvent(time: _at(6))));
    });

    test('a kind has a colour, and an unknown one falls back', () {
      final colors = ChartColors();

      expect(colors.eventColor('earnings'), isNot(colors.defaultTextColor));
      expect(colors.eventColor('nonsense'), colors.defaultTextColor);
      for (final kind in ChartEventKind.values) {
        expect(colors.eventColors, contains(kind.name));
      }
    });
  });

  group('events on the chart', () {
    testWidgets('they draw without complaint', (tester) async {
      await tester.pumpWidget(
        _chart(_candles(), [
          ChartEvent(time: _at(10), kind: ChartEventKind.earnings),
          ChartEvent(time: _at(20), kind: ChartEventKind.dividend),
          ChartEvent(time: _at(30), kind: ChartEventKind.split),
          ChartEvent(time: _at(40), kind: ChartEventKind.news),
          ChartEvent(time: _at(50), label: 'AGM', color: Colors.pink),
          ChartEvent(time: _at(55), icon: Icons.campaign_rounded),
        ]),
      );

      expect(tester.takeException(), isNull);
      expect(_painterOf(tester).events, hasLength(6));
    });

    testWidgets('a tap on a badge reports the event', (tester) async {
      final tapped = <ChartEvent>[];
      final event = ChartEvent(
        time: _at(30),
        kind: ChartEventKind.earnings,
        detail: 'beat by a cent',
      );

      await tester.pumpWidget(
        _chart(_candles(), [event], onEventTapped: tapped.add),
      );
      await tester.pumpAndSettle();

      await tester.tapAt(_badgeAt(tester, 30));
      await tester.pumpAndSettle();

      expect(tapped, [same(event)]);
    });

    testWidgets('a tap away from a badge reports nothing', (tester) async {
      final tapped = <ChartEvent>[];
      await tester.pumpWidget(
        _chart(
            _candles(),
            [
              ChartEvent(time: _at(30)),
            ],
            onEventTapped: tapped.add),
      );
      await tester.pumpAndSettle();

      // Well above the badges, over the candles themselves.
      await tester.tapAt(
        tester.getTopLeft(find.byType(KChartWidget)) + const Offset(250, 150),
      );
      await tester.pumpAndSettle();

      expect(tapped, isEmpty);
    });

    testWidgets('the badge on top of a cluster is the one a tap picks up', (
      tester,
    ) async {
      final tapped = <ChartEvent>[];
      final under = ChartEvent(time: _at(30), label: 'A');
      final over = ChartEvent(time: _at(30), label: 'B');

      await tester.pumpWidget(
        _chart(_candles(), [under, over], onEventTapped: tapped.add),
      );
      await tester.pumpAndSettle();

      await tester.tapAt(_badgeAt(tester, 30));
      await tester.pumpAndSettle();

      expect(tapped, [same(over)]);
    });

    testWidgets('a radius of zero draws nothing and answers no taps', (
      tester,
    ) async {
      final tapped = <ChartEvent>[];
      await tester.pumpWidget(
        _chart(
          _candles(),
          [ChartEvent(time: _at(30))],
          onEventTapped: tapped.add,
          style: ChartStyle(eventMarkRadius: 0),
        ),
      );
      await tester.pumpAndSettle();

      // The events are still on the chart, for a panel of your own to list.
      expect(_painterOf(tester).events, hasLength(1));
      expect(_painterOf(tester).eventAt(_badgeAt(tester, 30)), isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('events added later are lined up again', (tester) async {
      final data = _candles();
      await tester.pumpWidget(_chart(data, const []));
      expect(_painterOf(tester).events, isEmpty);

      await tester.pumpWidget(_chart(data, [ChartEvent(time: _at(10))]));
      await tester.pumpAndSettle();

      expect(_painterOf(tester).events, hasLength(1));
      expect(_painterOf(tester).events.single.index, 10);
    });

    testWidgets('an event on a candle off the side is simply not drawn', (
      tester,
    ) async {
      // Far more candles than fit, with the event at the very start.
      await tester.pumpWidget(
        _chart(_candles(600), [ChartEvent(time: _at(0))]),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(_painterOf(tester).events, hasLength(1));
    });

    testWidgets('a chart with no candles marks nothing', (tester) async {
      await tester.pumpWidget(_chart(const [], [ChartEvent(time: _at(0))]));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
