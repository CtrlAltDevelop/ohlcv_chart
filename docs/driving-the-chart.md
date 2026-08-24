# Driving the chart

`KChartController` reaches into the chart from your own code: how far it is
zoomed, where it is scrolled, and what it looks like as an image.

```dart
final chart = KChartController();

KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: false,
  watermarkAssetPath: 'assets/logo.svg',
  timeFrame: const Duration(minutes: 15),
  controller: chart,
);

chart.zoomIn();
chart.scrollToNow();                   // animates back to the live candle
chart.isAtRightEdge;                   // whether it is already there
final png = await chart.capture();     // the chart as PNG bytes
```

`capture` returns the chart itself — candles, indicators, drawings — without the
line editor or any other control floating over it. Everything no-ops while no
chart is attached, so a controller built before its widget, or kept after it, is
harmless. The chart also shows its own button back to the live candle whenever it
is scrolled away from one; `showScrollToNowButton: false` turns that off, and its
tooltip comes from `ChartTranslations.jumpToNow`.

## The visible window

Which candles are on screen is both readable and settable:

```dart
final range = chart.visibleRange;      // null until the first frame
range?.firstIndex;                     // the oldest candle in view
range?.lastIndex;                      // the newest
range?.length;                         // how many — a "bars on screen" readout
range?.firstTime;                      // and their instants
range?.span;                           // how long the window covers

chart.showRange(120, 180);             // zoom and scroll to those candles
chart.showTimeRange(candles, from, to);// the same, by time
chart.goToIndex(300);                  // centre that candle, keeping the zoom
chart.goToDate(candles, when);         // the nearest candle to an instant
chart.fitAll();                        // open the window as wide as it goes
```

`showRange` moves the zoom and the scroll together so the window holds exactly
what was asked for, as near as the chart's zoom limits allow; `goToIndex` and
`goToDate` keep the zoom and only scroll, animated by default. Each of them
reports whether it could move at all, which is false for a chart that has not
been laid out yet or one with no candles. `showTimeRange` widens outwards where
the instants fall between candles, so the span asked for is always covered.

`onVisibleRangeChanged` reports the window whenever it changes — after the frame
that changed it, and only when it is actually different, so scrolling within one
candle says nothing:

```dart
KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: false,
  watermarkAssetPath: 'assets/logo.svg',
  timeFrame: const Duration(minutes: 15),
  onVisibleRangeChanged: (range) {
    setState(() => barsOnScreen = range.length);
    // Load more history as the user reaches the start of it.
    if (range.firstIndex < 20) feed.loadOlder();
  },
);
```

That is also how two charts are kept in step — hand the range from one to the
other's `showRange`. `indexRangeCovering` and `indexNearest` are exported for
working out either from a list of candles without a chart in hand.

---

[← All docs](README.md) · [Package README](../README.md)
