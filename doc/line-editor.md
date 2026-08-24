# Customising the line editor

`DrawingStyle` decides what the toolbar offers, how it looks, and how close a tap
has to land to count. Everything is optional:

```dart
KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: true,
  watermarkAssetPath: 'assets/logo.svg',
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

A control that a drawing has no use for is left out whatever these say: the fill
slider only appears on a shape with an interior, the alert bell only on a level,
and the label field only on a drawing that can carry one.

A line's own appearance lives on the line, so you can style one before it ever
reaches the chart:

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

`ChartLine.opacity` reads and writes the alpha of `color`, and `isDashed` still
works for code written before `LineStyle`.

---

[← All docs](README.md) · [Package README](../README.md)
