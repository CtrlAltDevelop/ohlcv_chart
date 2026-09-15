# Theming

![The same chart under the dark and light palettes](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/theming.png)

The chart's appearance is controlled by three objects:

| Class | Controls |
| --- | --- |
| `ChartColors` | All colours |
| `ChartStyle` | Layout and geometry |
| `ChartTranslations` | All text labels |

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

## Localisation

`ChartTranslations` contains every on-chart label (`date`, `open`, `high`,
`low`, `close`, `changeAmount`, `change`, `amount`, `vol`, `jumpToNow`), so you
can build one from your `AppLocalizations`. Its `drawing` field localises the
line editor, the drawing manager and drawing names:

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

`DrawingTranslations.nameOf` returns the display name for a drawing, so a
renamed drawing kind is consistent throughout the UI.

## Colours and style

- `ChartColors.sessionDividerColor` colours session dividers.
- `ChartColors.gridColumnColor` colours vertical gridlines. It defaults to a
  lighter shade of `gridColor`, so horizontal price lines remain more
  prominent.
- `ChartStyle.copyWith` creates variations of a base style:

```dart
final style = const ChartStyle().copyWith(showSessionDividers: true);
```

The long-press readout sizes to its content between `infoDialogWidth` and
`infoDialogMaxWidth`, and never exceeds the chart width. Set
`isTapShowInfoDialog` to also open it on tap.

## Watermark

![Candles under a watermark made of an icon and a name](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/watermark.png)

`watermark` accepts any widget — an `Image.asset` logo, an icon or text — and
renders it faintly over the candle area:

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

- The watermark is painted in a single colour, `ChartColors.watermarkColor`
  (defaulting to a very faint `defaultTextColor`), so full-colour logos render
  as a silhouette.
- It ignores pointer events and does not affect chart interaction.
- The package has no SVG dependency. For an SVG watermark, pass
  `SvgPicture.asset` from `flutter_svg`.

## Series charts

`SeriesChart` does not use `ChartColors` or `ChartStyle`. Each series defines its
own colour, and axes, grid, tooltip and range selector accept styles directly,
so series charts can follow your app's theme. See
[Series charts](series-chart.md).

---

[← All docs](README.md) · [Package README](../README.md)
