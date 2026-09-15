import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

const _bounds = Rect.fromLTWH(0, 0, 300, 400);

final _days = [
  CalendarDay(date: DateTime(2024, 1, 1), value: 100),
  CalendarDay(date: DateTime(2024, 1, 31), value: -40),
  CalendarDay(date: DateTime(2024, 2, 15), value: 20),
];

void main() {
  group('the layout', () {
    test('one panel per month, from the first day to the last', () {
      final layout = layOutCalendar(_days, _bounds, monthsPerRow: 1);
      expect(layout.months.length, 2);
      expect(layout.months.first.firstDay, DateTime(2024));
      expect(layout.months.last.firstDay, DateTime(2024, 2));
      expect(layout.cells.length, 31 + 29); // 2024 is a leap year
    });

    test('from and to widen the range beyond the data', () {
      final layout = layOutCalendar(
        _days,
        _bounds,
        from: DateTime(2023, 12, 20),
        to: DateTime(2024, 3, 2),
        monthsPerRow: 1,
      );
      expect(layout.months.length, 4);
      expect(layout.months.first.firstDay, DateTime(2023, 12));
    });

    test('a month totals its days and counts the ones it has', () {
      final layout = layOutCalendar(_days, _bounds, monthsPerRow: 1);
      expect(layout.months.first.total, 60);
      expect(layout.months.first.days, 2);
      expect(layout.months.last.days, 1);
    });

    test('days sit in weeks beginning on the day asked for', () {
      // 1 January 2024 was a Monday.
      final monday = layOutCalendar(_days, _bounds, monthsPerRow: 1);
      final first = monday.cells.first;
      expect(first.rect.left, monday.months.first.rect.left);

      final sunday = layOutCalendar(
        _days,
        _bounds,
        monthsPerRow: 1,
        firstWeekday: DateTime.sunday,
      );
      // Starting the week on Sunday moves Monday one column right.
      expect(
        sunday.cells.first.rect.left,
        greaterThan(sunday.months.first.rect.left),
      );
    });

    test('a day carries what the app gave for it, and nothing otherwise', () {
      final layout = layOutCalendar(_days, _bounds, monthsPerRow: 1);
      expect(layout.cells.first.value, 100);
      expect(layout.cells[1].day, isNull);
      expect(layout.cells[1].value, isNull);
    });

    test('panels flow across the width when asked for more per row', () {
      final layout = layOutCalendar(_days, _bounds, monthsPerRow: 2);
      expect(layout.months[1].rect.top, layout.months[0].rect.top);
      expect(layout.months[1].rect.left, greaterThan(layout.months[0].rect.left));
    });

    test('squares shrink so the calendar fits the box it is given', () {
      final roomy = layOutCalendar(_days, _bounds, monthsPerRow: 1);
      final cramped = layOutCalendar(
        _days,
        const Rect.fromLTWH(0, 0, 300, 120),
        monthsPerRow: 1,
      );
      expect(cramped.cellSize, lessThan(roomy.cellSize));
      expect(cramped.height, lessThanOrEqualTo(120.001));
    });

    test('nothing to show, or no room, lays out nothing', () {
      expect(layOutCalendar(const [], _bounds).isEmpty, isTrue);
      expect(layOutCalendar(_days, Rect.zero).isEmpty, isTrue);
    });

    test('a point in a square finds its day', () {
      final layout = layOutCalendar(_days, _bounds, monthsPerRow: 1);
      final cell = layout.cells.first;
      expect(calendarCellAt(layout, cell.rect.center)?.date, DateTime(2024));
      expect(calendarCellAt(layout, const Offset(299, 399)), isNull);
    });

    test('the value range covers every day', () {
      expect(calendarValueRange(_days), (-40.0, 100.0));
      expect(calendarValueRange(const []), (0.0, 1.0));
    });
  });

  group('the widget', () {
    testWidgets('draws, reports touches and takes its default height',
        (tester) async {
      CalendarTouchDetails? touched;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CalendarChart(
                  days: _days,
                  monthsPerRow: 1,
                  showDayNumbers: true,
                  showWeekdayHeader: true,
                  onTouch: (d) => touched = d,
                  tooltipBuilder: (context, d) =>
                      Text('card ${d.date.day}/${d.date.month}'),
                  semanticLabel: 'Daily P&L',
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(CalendarChart)).height, 320);

      final topLeft = tester.getTopLeft(find.byType(CalendarChart));
      final layout = layOutCalendar(
        _days,
        Rect.fromLTWH(0, 0, tester.getSize(find.byType(CalendarChart)).width,
            320),
        monthsPerRow: 1,
      );
      final gesture =
          await tester.startGesture(topLeft + layout.cells.first.rect.center);
      await tester.pump();
      expect(touched?.date, DateTime(2024));
      expect(touched?.day?.value, 100);
      expect(touched?.month.total, 60);
      expect(find.text('card 1/1'), findsOneWidget);

      await gesture.up();
      await tester.pump();
      expect(touched, isNull);
    });

    testWidgets('fades in and survives its data changing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarChart(
              days: _days,
              animationDuration: const Duration(milliseconds: 200),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarChart(
              days: [CalendarDay(date: DateTime(2025, 5, 4), value: 1)],
              animationDuration: const Duration(milliseconds: 200),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
