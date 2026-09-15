# Driving the chart

`KChartController` provides programmatic control over the chart: zoom level,
scroll position and image export.

```dart
final chart = KChartController();

KChartWidget(
  candles,
  ChartColors(),
  timeFrame: const Duration(minutes: 15),
  controller: chart,
);

chart.zoomIn();
chart.scrollToNow();                   // animates back to the live candle
chart.isAtRightEdge;                   // whether it is already there
final png = await chart.capture();     // the chart as PNG bytes
```

- `capture` returns the chart content — candles, indicators and drawings —
  without the line editor or other overlay controls.
- All methods are no-ops while no chart is attached, so a controller can safely
  be created before, or retained after, its widget.
- When scrolled away from the newest candle, the chart shows a scroll-to-latest
  button. Disable it with `showScrollToNowButton: false`; its tooltip comes from
  `ChartTranslations.jumpToNow`.

## Visible range

The visible range can be read and set:

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

- `showRange` adjusts zoom and scroll together to show exactly the requested
  candles, within the chart's zoom limits.
- `goToIndex` and `goToDate` keep the current zoom and only scroll, animated by
  default.
- Each method returns whether the view could move; it returns `false` before
  layout or when there are no candles.
- `showTimeRange` expands outwards when the requested times fall between
  candles, so the full span is always included.

`onVisibleRangeChanged` is called after a frame in which the visible range
changed. Scrolling within a single candle does not trigger it:

```dart
KChartWidget(
  candles,
  ChartColors(),
  timeFrame: const Duration(minutes: 15),
  onVisibleRangeChanged: (range) {
    setState(() => barsOnScreen = range.length);
    // Load more history as the user reaches the start of it.
    if (range.firstIndex < 20) feed.loadOlder();
  },
);
```

`indexRangeCovering` and `indexNearest` are exported for computing ranges from a
candle list without a chart instance.

## Disabling gestures

For charts that should not be navigated — a single session, a list thumbnail or
a report figure — `scrollEnabled` and `zoomEnabled` disable the built-in
gestures.

```dart
KChartWidget(
  sessionCandles,
  ChartColors(),
  timeFrame: const Duration(minutes: 5),
  chartType: ChartType.area,
  scrollEnabled: false,
  zoomEnabled: false,
  // 78 candles in a box about 400 wide: 400 / 78 ≈ 5
  chartStyle: const ChartStyle(pointWidth: 5),
  xFrontPadding: 0,
  volHidden: true,
  hideGrid: true,
  showNowPrice: false,
  showInfoDialog: false,
  crosshairOnHover: false,
  showContextMenu: false,
  showScrollToNowButton: false,
  priceScaleDrag: false,
);
```

- With `scrollEnabled: false`, drags and flings are ignored, and
  [`onLoadMore`](candlestick-chart.md) is never called.
- With `zoomEnabled: false`, pinch is ignored and the zoom slider (shown only on
  web and desktop) is hidden.
- Disable both together. Zooming out narrows the candles and creates room to
  scroll, so a chart with only scrolling disabled can become scrollable again.

These flags affect user input only, like `priceScaleDrag`. The chart can still
be controlled programmatically:

```dart
chart.fitAll();      // the whole history in the box
chart.goToIndex(0);  // or somewhere particular
```

### Filling the width

With scrolling disabled, the view stays where it is — usually at the newest
candle, with older candles off-screen. To show a complete series, use
`ChartStyle.fitContent`, which spreads a short series across the full plot and
widens the candles to match:

```dart
chartStyle: ChartStyle(fitContent: true),
```

`fitContent` only increases spacing. A series long enough to fill the plot at
`ChartStyle.pointWidth` (8 by default) is laid out as usual, so the option can
remain enabled as more history loads.

Alternatively, compute the spacing yourself when exact spacing matters more than
filling the width:

```dart
chartStyle: ChartStyle(pointWidth: width / candles.length),
```

Once the series fits, there is nothing to scroll regardless of the flag.
`xFrontPadding: 0` removes the gap to the right of the newest candle, and
`fitAll()` achieves the same result without calculations.

## Linked charts

`ChartLink` synchronises multiple charts. Add each chart's controller; scrolling
or zooming any one of them updates the others:

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

![Two linked charts sharing one crosshair](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/linked-charts.png)

- There is no fixed leader: the chart the user is interacting with drives the
  others, and feedback loops are prevented.
- `syncFrom(controller)` aligns all other charts to one chart immediately,
  which is useful for charts added later.
- Charts with different history lengths align where their data overlaps; the
  window is clamped to each chart's available candles.

### Synchronised by default

The **visible window** (including zoom) and the **crosshair** are synchronised
by default. The crosshair is matched by candle index, so charts of different
widths stay aligned. Either can be disabled:

```dart
ChartLink(crosshair: false);  // scroll together, read separately
ChartLink(window: false);     // one crosshair, each chart scrolled on its own
```

A synchronised crosshair behaves as a hover on the receiving charts, so it never
interrupts user input there. If its candle is scrolled out of view, it rests at
the nearest edge.

### Opt-in synchronisation

Vertical synchronisation is disabled by default because it only makes sense for
charts of the **same instrument**:

```dart
ChartLink(crosshairPrice: true);  // the crosshair's height as well as its candle
ChartLink(priceScale: true);      // the axis's stretch and shift
ChartLink.all();                  // everything, for one market shown twice
```

Instruments at different prices do not share a vertical scale, and forcing one
produces unusable charts. Enable these options only when showing the same market
at different zoom levels or timeframes. With `crosshairPrice` disabled, the
crosshair still syncs by candle and is shown mid-pane on other charts.

To synchronise manually, pass the range from `onVisibleRangeChanged` to another
chart's `showRange`, or the candle from `onCrosshairChanged` to its
`showCrosshair`.

## Crosshair control

`KChartController` can read and set the crosshair independently of `ChartLink`:

```dart
chart.crosshairIndex;                    // which candle it is on, or null
chart.crosshairPrice;                    // and what price it sits at
chart.showCrosshair(120);                // put it on candle 120, mid-pane
chart.showCrosshair(120, price: 68400);  // and at a price of its own
chart.hideCrosshair();                   // take it down
```

The price axis is also controllable: `priceZoom` and `pricePan` read its zoom and
offset, and `setPriceZoom`, `setPricePan` and `resetPriceScale` change them.
`resetPriceScale` also refits a [locked axis](price-axis.md#locking-the-scale) to
the visible window and locks it again.

`onCrosshairChanged` is called after a frame in which the crosshair moved to a
different candle. Movement within a single candle does not trigger it.

## Overview strip

`ChartOverview` is a compact chart of the full history with the visible window
highlighted. Drag the window to scroll, drag its edges to zoom, or tap to jump:

```dart
final chart = KChartController();

Column(
  children: [
    Expanded(
      child: KChartWidget(
        candles,
        ChartColors(),
        timeFrame: const Duration(minutes: 15),
        controller: chart,
      ),
    ),
    ChartOverview(candles, controller: chart, colors: ChartColors()),
  ],
);
```

![The overview strip under a chart, with the visible window lit on it](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/overview.png)

- It uses the same controller as the main chart, so both always stay in sync,
  including when the chart is moved by other means. Pass it the same candle list.
- It draws closing prices as a line, so long histories remain readable.
- `height`, `padding` and `handleWidth` control its size. `handleWidth` sets the
  edge area that resizes rather than pans, so narrow windows remain draggable.
- Dragging past either end keeps the window's width instead of shrinking it.

---

[← All docs](README.md) · [Package README](../README.md)
