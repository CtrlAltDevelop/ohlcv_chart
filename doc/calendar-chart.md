# Calendar

`CalendarChart` lays a run of daily numbers out as real months, each day a
square coloured by its value. Typical uses include daily profit and loss, trades
taken per day, and activity graphs.

```dart
CalendarChart(
  days: [
    for (final entry in pnlByDay.entries)
      CalendarDay(date: entry.key, value: entry.value),
  ],
);
```

The default scale is diverging — red through neutral to green — with the range
made symmetric about zero, so a flat day takes the middle colour.

The chart fills its constraints. When the height is unbounded, it uses
`defaultHeight`.

## Days

| Field | Description |
| --- | --- |
| `date` | The day; only year, month and day are read |
| `value` | What the square is coloured by |
| `color` | Fixed colour, which wins over the scale |
| `data` | Arbitrary app data, returned on touch |

Days not given are drawn in the scale's `emptyColor`.

## Range and colour

`scale` is the same `HeatmapScale` the [heatmap](heatmap-chart.md) takes, so a
gradient or stepped scale can be shared between them:

```dart
CalendarChart(
  days: days,
  scale: const HeatmapStepScale(
    steps: [
      HeatmapStep(-double.infinity, Color(0xFFE03131), label: 'Loss'),
      HeatmapStep(0, Color(0xFF2F9E44), label: 'Profit'),
    ],
  ),
);
```

| Parameter | Description |
| --- | --- |
| `min`, `max` | Ends of the scale; `null` reads them off the days |
| `symmetricRange` | Makes an automatic range symmetric about zero (default `true`) |

`calendarValueRange(days)` returns the range the chart would read.

## Layout

| Parameter | Description |
| --- | --- |
| `from`, `to` | First and last month to draw; `null` follows the data |
| `firstWeekday` | The day a week begins on (default `DateTime.monday`) |
| `monthsPerRow` | Month panels per row; `null` fits as many as it can |
| `minPanelWidth` | The narrowest a panel may be when fitting a row |
| `cellSpacing`, `cellRadius` | Gap between and rounding of day squares |
| `headerHeight`, `monthSpacing` | Room for a month's name, and between panels |
| `padding` | Space around the chart |

Every panel is six week rows tall, so rows line up across the calendar. When the
months given need more room than the chart has, the squares shrink so everything
still fits.

`layOutCalendar(days, bounds, …)` returns the `CalendarLayout` the chart paints —
`months`, `cells`, `cellSize` and the `height` it came out — and
`calendarCellAt(layout, local)` hit-tests it. Both are public, so a layout can be
computed and tested without a widget.

## Labels

| Parameter | Description |
| --- | --- |
| `showDayNumbers` | Writes the day of the month in each square, when it fits |
| `showWeekdayHeader` | Writes weekday initials under each month's name |
| `monthNames`, `weekdayNames` | Names for other languages |
| `monthLabelBuilder` | Custom header text for a `CalendarMonthPanel` |
| `valueFormatter` | Formats the total in the default header (default: signed, at most two decimals) |
| `headerStyle`, `dayNumberStyle` | Text styles |

By default a month's header shows its name, its total, and its year when the
calendar spans more than one.

## Touch

`onTouch` reports a `CalendarTouchDetails` with the `cell`, its `date`, the
`day` the app gave (or `null`) and the `month` panel it sits in, and `null` when
the pointer leaves.

```dart
CalendarChart(
  days: days,
  tooltipBuilder: (context, details) => Card(
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Text(details.day == null
          ? 'No trades'
          : '${details.date.day}: ${details.day!.value}'),
    ),
  ),
);
```

## Animation

`animationDuration` fades the squares in; `animationCurve` eases it and
`animateOnMount` controls whether the first build animates. The chart animates
again whenever `days` changes identity.
