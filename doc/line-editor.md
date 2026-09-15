# Customising the line editor

![The line editor open on a selected line](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/line-editor.png)

`DrawingStyle` controls the options the editor toolbar offers, its appearance,
and the hit-test tolerance for selecting drawings. All fields are optional:

```dart
KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: true,
  timeFrame: const Duration(minutes: 15),
  drawingStyle: const DrawingStyle(
    // What the user may pick
    colorOptions: [Color(0xFF4DABF7), Color(0xFF12B886), Color(0xFFFA5252)],
    thicknessOptions: [1, 2, 3, 5],
    lineStyleOptions: [LineStyle.solid, LineStyle.dashed],
    minThickness: 0.5,
    maxThickness: 8,

    // Which controls appear
    showOpacityControl: false,
    showLabelTextControl: true,
    showFillControl: true,     // shapes with an interior
    showAlertControl: true,    // levels only

    // How the bar looks
    toolbarAxis: Axis.horizontal,
    toolbarInitialOffset: Offset(16, 40),
    accentColor: Color(0xFF4DABF7),
    iconSize: 20,

    // How the lines themselves are painted
    handleRadius: 7,
    dashLength: 6,
    dashGap: 4,
    hitTestTolerance: 22,

    // What a newly drawn shape looks like
    rectangleFillOpacity: 0.12,
    shapeFillOpacity: 0.12,
    measureFillOpacity: 0.14,
    channelFillOpacity: 0.08,
    positionFillOpacity: 0.16,
  ),
);
```

Controls are shown only where they apply, regardless of these settings: the fill
slider for shapes with an interior, the alert button for alert-capable drawings,
and the label field for drawings that support labels.

## Styling individual drawings

Appearance is stored on each drawing, so you can style a drawing before adding
it to the chart:

```dart
HorizontalLine(
  price: 68400,
  title: 'take profit',
  color: const Color(0xFF12B886),
  thickness: 2,
  style: LineStyle.dashed,
  showLabel: true,
  locked: true,
);
```

`ChartLine.opacity` reads and writes the alpha channel of `color`. `isDashed` is
still supported for code written before `LineStyle`.

---

[← All docs](README.md) · [Package README](../README.md)
