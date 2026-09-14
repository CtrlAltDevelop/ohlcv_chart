# Theming

![The same chart under the dark and light palettes](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/theming.png)

```dart
KChartWidget(
  candles,
  ChartColors(
    upColor: const Color(0xFF12B886),
    dnColor: const Color(0xFFFA5252),
    bgColor: const Color(0xFF0E1116),
  ),
  chartStyle: const ChartStyle(),
  chartTranslations: const ChartTranslations(),
  // …
);
```

`ChartTranslations` carries every on-chart label (`date`, `open`, `high`, `low`,
`close`, `changeAmount`, `change`, `amount`, `vol`, `jumpToNow`), so localising
the chart is a matter of building one from your own `AppLocalizations`. Its
`drawing` field does the same for the line editor, the drawing manager and what
each kind of drawing is called:

```dart
ChartTranslations(
  date: l10n.date,
  drawing: DrawingTranslations(
    color: l10n.colour,
    delete: l10n.delete,
    fill: l10n.fill,
    alert: l10n.setAlert,
    drawings: l10n.drawings,
    trendLineName: l10n.trendLine,
  ),
);
```

`DrawingTranslations.nameOf` is what turns a drawing into the name the manager
shows, so a kind you have renamed reads the same everywhere.

`ChartColors` gained `sessionDividerColor` for the day dividers and
`gridColumnColor` for the vertical grid lines, which default to a lighter shade
of `gridColor` — a chart is read across price far more than across time, so the
time columns sit behind the price rows. `ChartStyle` now has a `copyWith`, so a
house geometry can be varied a switch at a time:

```dart
final style = const ChartStyle().copyWith(showSessionDividers: true);
```

The long-press readout sizes itself to its content between `infoDialogWidth` and
`infoDialogMaxWidth`, and is never wider than the chart. Set
`isTapShowInfoDialog` to open it on a plain tap as well.

---

[← All docs](README.md) · [Package README](../README.md)
