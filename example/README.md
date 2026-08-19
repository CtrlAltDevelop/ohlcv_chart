# ohlcv_chart example

Run it with:

```bash
flutter run
```

A tour of the whole package. The **Candles** tab shows the candlestick chart with
a panel for every switch it has:

- **Drawing tools** — place trend, horizontal and vertical lines, then tap one to
  restyle it; the "branded editor" toggle swaps `DrawingStyle` for a vertical
  toolbar with a house palette.
- **Indicators** — add as many as you like from a sheet built entirely out of
  `indicatorCatalog`: pick a kind, set its periods, and colour each of its lines
  or leave them to the theme. Adding one that is already on the chart updates it
  rather than stacking a duplicate, and tapping a chip reopens it for editing.
  `MA(5)`, `MA(10)`, `MA(20)` and `MACD` are there out of the box, and all 26
  kinds are in the sheet — including the Ichimoku cloud, Supertrend, and the
  zigzag, Fibonacci and Elliott wave readings of the market's swings.
- **Main chart** — line mode, filled or hollow candles, and the volume pane.
- **Axes and markers** — grid, price-axis side, the "now price" line and its
  countdown, take-profit and stop-loss `SignalEntity` tags, and decimal places.
- **Readout** — the long-press card, opening it on tap as well, Material or
  Cupertino styling, and a custom `infoDialogBuilder`.
- **Feed** — simulated live ticks that walk the newest candle and roll it over,
  and `onLoadMore` paging in older candles when you scroll past the oldest one.
- **Theme and language** — light and dark `ChartColors`, and a German
  `ChartTranslations` including the drawing editor's labels.

## Screenshots

The images in the package README and on the pub.dev listing are rendered by
`tool/screenshots.dart`, which lays each scene out at a fixed size, captures it
off the raster boundary and writes a PNG:

```sh
flutter run -d macos -t tool/screenshots.dart
```

macOS sandboxes the app, so the files land in its container and the path is
printed on the way through — copy them into `../screenshots/` from there.

The **Depth** tab renders the matching order book with `DepthChart`, built from
raw rungs through `DepthEntity.bids` and `DepthEntity.asks`, with chips for its
four modes — curve, bars, both and the numeric ladder — its linear, log and
percent axes, and how far either side of the mid to look.

The market data is generated locally, so the demo needs no network.
