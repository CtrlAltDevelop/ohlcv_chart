# Panes

![Three ATR panes stacked under the candles](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/panes.png)

An indicator pane can be made taller by dragging its lower edge, and moved up or
down the stack by dragging its legend row:

```dart
KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: false,
  watermarkAssetPath: 'assets/logo.svg',
  timeFrame: const Duration(minutes: 15),
  indicators: [MacdIndicator(), RsiIndicator()],
  resizablePanes: true,
  reorderablePanes: true,
  onReorderPane: (from, to) => setState(() {
    indicators.insert(to, indicators.removeAt(from));
  }),
);
```

Each pane is ruled and labelled at round values of its own, rather than showing
only its highest and lowest — which is what lets three ATRs at three periods be
read against each other instead of being three unlabelled squiggles. A pane with
a range it already knows — RSI, KDJ, WR — keeps its guides instead. MACD and the
Awesome oscillator draw their zero line, the axis their histogram changes colour
across, and the volume pane marks a round level part-way up so a bar can be read
against something.

Heights live in the chart, between `ChartStyle.minPaneHeight` and
`maxPaneHeight`, and are given up whenever the panes themselves change. The order
does not: the indicators own that, so the chart reports where a pane was dropped
and leaves the move to you. `ChartStyle.paneResizeTolerance` and `paneGrabHeight`
decide how big each target is.

---

[← All docs](README.md) · [Package README](../README.md)
