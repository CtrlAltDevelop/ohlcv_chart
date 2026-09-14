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

## Watermark

![Candles under a watermark made of an icon and a name](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/watermark.png)

`watermark` takes any widget — an `Image.asset` of your logo, an icon, a line of
text — and draws it faintly over the candle area:

```dart
KChartWidget(
  candles,
  ChartColors(watermarkColor: Colors.white.withValues(alpha: .06)),
  watermark: Image.asset('assets/logo.png'),
  chartStyle: const ChartStyle(
    watermarkScale: .3,                       // width, as a share of the shorter side
    watermarkAlignment: Alignment.bottomRight,
  ),
);
```

It is painted in one colour, `ChartColors.watermarkColor` — a very faint
`defaultTextColor` when left null — so a full-colour logo reads as a quiet
silhouette. It takes no touches, so the chart under it behaves as though it were
not there. The package has no SVG dependency; an app that wants an SVG
watermark passes an `SvgPicture.asset` from `flutter_svg` itself.

## Series charts

`SeriesChart` does not read `ChartColors` or `ChartStyle`: each series carries
its own colour, and the axes, grid, tooltip and range selector take their styles
directly, so a series chart picks up an app's theme from wherever the app keeps
it. See [Series charts](series-chart.md).

---

[← All docs](README.md) · [Package README](../README.md)
