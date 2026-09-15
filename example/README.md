# ohlcv_chart example

Run it with:

```bash
flutter run
```

A tour of the whole package in three tabs. The market data is generated locally,
so the demo needs no network.

## The Candles tab

The candlestick chart, with a panel for every switch it has, in the order they
run down the side:

- **Drawing tools** — a "select" chip and one for each of the 29 tools; pick
  one, then tap the chart or drag. "Magnet" snaps new points to the nearest
  open, high, low or close, "keep the tool armed" draws several in a row without
  the editor opening over each, and the "branded editor" toggle swaps
  `DrawingStyle` for a vertical toolbar with a house palette. Undo, redo and
  clear sit under the chips, beside Save and Restore, which round-trip the whole
  layout through JSON.
- **The window** — the visible range read out live, with Last 50, Last 200, go
  to the middle and fit everything.
- **Compare** — a second instrument over the same window, rebased to the left of
  it or left at its own prices; plus a working order and an open position you
  can drag to amend, and earnings, dividend, split and news marks you can tap.
- **The selection** — shift- or ⌘-click for several, ⌘A for the lot, then
  duplicate, bring to front or send to back; and style templates, saving one
  drawing's look as "house" to put on the rest.
- **Indicators** — add as many as you like from a sheet built entirely out of
  `indicatorCatalog`: pick a kind, set its periods, and colour each of its lines
  or leave them to the theme. Adding one that is already on the chart updates it
  rather than stacking a duplicate, and tapping a chip reopens it for editing.
  `MA(5)`, `MA(10)`, `MA(20)` and `MACD` are there out of the box, and all 32
  kinds are in the sheet — including the Ichimoku cloud, Supertrend, and the
  zigzag, Fibonacci and Elliott wave readings of the market's swings.
- **Main chart** — all eight chart types, the six candle transforms
  (Heikin-Ashi, Renko, line break, Kagi, point & figure and range bars), the
  four price-axis scales and inverting them, the window's average close and its
  high and low on the axis, extended-hours shading, a per-bar colour of your
  own, a pinned baseline, hollow rising candles and the volume pane.
- **Panes** — resizing a pane by dragging its lower edge, and reordering panes
  by dragging a legend.
- **Axes and markers** — grid, price-axis side, the "now price" line and its
  countdown, take-profit and stop-loss `SignalEntity` tags, the OHLC legend, a
  crosshair that follows the mouse, day dividers, display time zone, decimal
  places, dragging the price axis to stretch it, taking the date axis over with
  `dateFormatter`, front padding, the scroll-to-now button and the keyboard
  shortcuts.
- **Readout** — the long-press card, opening it on tap as well, Material or
  Cupertino styling, and a custom `infoDialogBuilder`.
- **Replay** — rewind to a candle and step or play the market forward, with the
  indicators only knowing what has arrived.
- **Feed** — simulated live ticks that walk the newest candle and roll it over,
  and `onLoadMore` paging in older candles when you scroll past the oldest one.
- **Theme and language** — light and dark `ChartColors`, and a German
  `ChartTranslations` including the drawing editor's labels.

## The Depth tab

The matching order book, rendered with `DepthChart` and built from raw rungs
through `DepthEntity.bids` and `DepthEntity.asks`, with chips for its four modes
— curve, bars, both and the numeric ladder — its linear, log and percent axes,
and how far either side of the mid to look.

## The Series tab

`SeriesChart` drawing the charts a business app asks for, each in its own card:

- **A sparkline** — 58 pixels high with no axes, a monotone line over a fading
  fill; press and drag for a tooltip above the point.
- **Deposits and withdrawals** — two filled series over a 30-day window of 120
  days, with a long-press tooltip and a `SeriesRangeSelector` underneath to move
  and resize the window.
- **Balance and profit** — a balance line with its dashed average over rounded
  green and red profit bars, the two panels sharing one `SeriesChartController`
  so holding either marks the same day on both.
- **ROI** — a line and its fill split green and red exactly at a dashed zero
  line.
- **Flows per month** — two bar series stacked on each other, on a chart turned
  on its side, with both axes named.
- **Trades** — a scatter plot whose dots take their size, shape and colour from
  the point, read out one dot at a time.
- **Holdings** — a `PieChart` doughnut with a total in the hole; hovering a
  slice pushes it out and names it.
- **Two strategies scored** — a `RadarChart` over five measures, reporting the
  corner under the pointer.
- **Orders by hour and weekday** — a `HeatmapChart` with a legend under it; the
  card title reads out the square under the pointer.

All nine follow the palette switch in the app bar.

## Screenshots

The images in the package README and on the pub.dev listing are rendered by
`tool/screenshots.dart`, which lays each scene out at a fixed size, captures it
off the raster boundary and writes a PNG:

```sh
flutter run -d macos -t tool/screenshots.dart
```

macOS sandboxes the app, so the files land in its container and the path is
printed on the way through — copy them into `../screenshots/` from there.

`--dart-define=only=treemap,gauge` shoots just those scenes, for a run that is
adding one rather than redoing the set. The gallery — one image per chart doc
page — lives in `tool/gallery_scenes.dart`, a part of the same file, so the
scenes there share the palette and the panel card with the rest.
