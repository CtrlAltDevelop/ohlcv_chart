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

`indexRangeCovering` and `indexNearest` are exported for working out either
from a list of candles without a chart in hand.

## Keeping charts in step

`ChartLink` holds several charts on the same window. Add each one's controller
and whichever the user scrolls or zooms carries the rest with it:

```dart
final price = KChartController();
final volume = KChartController();
late final link = ChartLink()..add(price)..add(volume);

@override
void dispose() {
  link.dispose();
  super.dispose();
}
```

There is no leader: any chart the user moves becomes the one being followed for
as long as it is moving, and the link guards against the push back — moving the
others notifies them, and without the guard their notification would move the
first one straight back.

`syncFrom(controller)` puts every other chart on that one's window at once,
which is what a chart built later wants so it joins the others where they
already are rather than waiting for a scroll.

Charts over histories of different lengths line up as far as they overlap: a
window pushed onto a chart is clamped to the candles it actually has.

**What is linked** is the visible window — and with it the zoom, since showing
the same candles across the same width is what zoom means here — and the
crosshair, by candle rather than by pixel, so charts at different widths still
point at the same bar. Either can be left off:

```dart
ChartLink(crosshair: false);  // scroll together, read separately
ChartLink(window: false);     // one crosshair, each chart scrolled on its own
```

A crosshair pushed onto a chart reads as one *hovered* rather than one held
down, so it never takes the place of a press the user is making themselves, and
a candle scrolled out of view rests at the near edge rather than vanishing.

The price axis is deliberately left alone. Two instruments at different prices
share no sensible vertical scale, and forcing one would leave a chart drawing a
flat line off the top of its pane.

Doing either by hand is still an option — pass the range from
`onVisibleRangeChanged` to the other chart's `showRange`, or the candle from
`onCrosshairChanged` to its `showCrosshair`.

## The crosshair, on its own

`KChartController` reads and moves the crosshair whether or not a link is
involved:

```dart
chart.crosshairIndex;        // which candle it is on, or null
chart.showCrosshair(120);    // put it on candle 120
chart.hideCrosshair();       // take it down
```

`onCrosshairChanged` reports where it moved to, on the same terms as
`onVisibleRangeChanged`: after the frame that moved it, and only when the
candle is actually different, so sliding the pointer within one candle says
nothing.

## The overview strip

`ChartOverview` is a slim chart of the whole history with the visible window
marked on it — drag the lit part to scrub, drag either edge to widen or narrow
the window, or tap anywhere to jump there:

```dart
final chart = KChartController();

Column(
  children: [
    Expanded(
      child: KChartWidget(
        candles,
        ChartColors(),
        isTrendLine: false,
        timeFrame: const Duration(minutes: 15),
        controller: chart,
      ),
    ),
    ChartOverview(candles, controller: chart, colors: ChartColors()),
  ],
);
```

It drives the chart through the same controller and reads the window back from
it, so the two never disagree about where they are — and a chart scrolled by
any other means moves the strip with it. Hand it the same list the chart has.

It draws the closes rather than the candles, so a long history still reads as a
shape at a glance. `height`, `padding` and `handleWidth` size it;
`handleWidth` is how near an edge a grab counts as a resize rather than a pan,
so a narrow window is still draggable rather than being all handle.

Panning to either end slides the window up against it rather than shrinking it,
so a drag past the edge keeps the window the width it was.

---

[← All docs](README.md) · [Package README](../README.md)
