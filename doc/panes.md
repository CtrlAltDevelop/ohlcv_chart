# Panes

![Three ATR panes stacked under the candles](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/panes.png)

Indicator panes can be resized by dragging their lower edge and reordered by
dragging their legend row:

```dart
KChartWidget(
  candles,
  ChartColors(),
  timeFrame: const Duration(minutes: 15),
  indicators: [MacdIndicator(), RsiIndicator()],
  resizablePanes: true,
  reorderablePanes: true,
  onReorderPane: (from, to) => setState(() {
    indicators.insert(to, indicators.removeAt(from));
  }),
);
```

## Scales and guides

- Each pane has its own gridlines and labels at round values, so panes such as
  ATRs with different periods can be compared directly.
- Indicators with a fixed range (RSI, KDJ, WR) show their guide levels instead.
- MACD and Awesome Oscillator panes draw a zero line.
- The volume pane shows a round reference level.

## Height and order

By default pane heights are managed by the chart: 100 each, or whatever the user
dragged them to, constrained between `ChartStyle.minPaneHeight` and
`maxPaneHeight`, and reset when panes are added or removed. A reorder carries
each height along with its pane.

Pane order is owned by your indicator list. The chart reports the move through
`onReorderPane`, and your code applies it.

## Sizing panes from your code

Two ways to set heights from outside — a "maximize this indicator" button is
the usual reason.

**`KChartController`** takes commands:

```dart
chart.maximizePane(1);          // pane 1 fills the chart, candles shrink to a strip
chart.restorePanes();           // …and back
chart.toggleMaximizePane(1);    // one button for both
chart.maximizeVolume();         // the volume pane instead
chart.setPaneHeight(0, 220);    // any single pane, any positive height
chart.resetPaneHeights();       // every pane back to the standard height
chart.paneHeights;              // what is drawn now
```

![Three panes at the standard height](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/panes-default.jpg)
![The RSI pane maximized](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/panes-maximized-rsi.jpg)
![The OBV pane maximized](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/panes-maximized-obv.jpg)

Only one pane — or the volume pane — is maximized at a time. A maximized pane follows the chart's size and moves with its indicator when you
reorder; dragging any pane lets go of it. It needs the chart to size its own
candle area, so it has no effect when `mBaseHeight` is set.

**`KChartWidget.paneHeights`** is the same thing as state:

```dart
KChartWidget(
  candles,
  ChartColors(),
  indicators: indicators,
  paneHeights: maximized ? [60, 500] : null,   // null: the chart's own layout
  volumeHeight: 80,                            // the volume pane, default 60
  onPaneHeightsChanged: (heights) => setState(() => saved = heights),
);
```

- Heights set from code are used as given, not held to `minPaneHeight` and
  `maxPaneHeight`, so a pane can be taller than a user could drag it. A height
  too big for the box is cut back so the candles keep a strip above it.
- A pane missing from a shorter list, or given a height that is not a positive
  number, gets the standard height.
- While a list is given you own the heights, like a controlled text field. A
  drag (with `resizablePanes` on) or `setPaneHeight` does not move a pane by
  itself: it is reported through `onPaneHeightsChanged`, and the pane moves when
  you pass the new list back. Pass `null` to give the heights back to the chart.
  Maximizing through the controller still works over a list, and lets go of
  whenever a height changes.
- Panes in `paneHeights` are matched by position. When `onReorderPane` moves
  one, move its height with it.

`ChartStyle.paneResizeTolerance` and `paneGrabHeight` set the size of the
resize and reorder hit areas.

---

[← All docs](README.md) · [Package README](../README.md)
