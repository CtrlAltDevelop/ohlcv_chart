# ohlcv_chart documentation

Every feature of the package, one page each. Start with the
[candlestick chart](candlestick-chart.md); the rest can be read in any order.

For installation, the feature list and support, see the
[package README](../README.md).

## Getting started

- **[Candlestick chart](candlestick-chart.md)** — the candles a `KChartWidget`
  needs, and the shape `KLineEntity` expects them in.

## Series and indicators

- **[Indicators](indicators.md)** — all 31 of them as configured instances, the
  catalogue behind an "add indicator" sheet, pane scales, chained indicators,
  alerts, colours and writing your own.
- **[Comparing a second instrument](comparison.md)** — overlaying other series,
  rebased or at their own prices, matched to the candles by time.
- **[Chart types](chart-types.md)** — the eight ways to draw a series, and the
  six transforms that rewrite the candles instead: Heikin-Ashi, Renko, line
  break, Kagi, point & figure and range bars.

## Axes and reading the chart

- **[Price axis](price-axis.md)** — linear, logarithmic, percentage or indexed
  to 100; inverting it, marking the window's high, low and average close, and
  dragging the scale by hand.
- **[The date axis](date-axis.md)** — round time values, the formats it picks
  between, and taking it over with `dateFormatter`.
- **[The legend and the crosshair](legend-and-crosshair.md)** — the OHLC row
  above the chart and the crosshair that follows the mouse.
- **[The long-press readout](readout.md)** — the card that opens over a held
  candle, and replacing it with your own.

## Drawing

- **[Drawing tools](drawing-tools.md)** — all 29 tools and what each one takes
  to place, persisting a layout as JSON, undo and redo, multi-select, style
  templates, typed coordinates, the right-click menu, the drawing manager and
  level alerts.
- **[Customising the line editor](line-editor.md)** — every control, option list
  and pixel of the editor that opens on selection, through `DrawingStyle`.

## Market context

- **[Orders and positions](orders-and-positions.md)** — live lines from your
  venue, tagged with side, size and P&L, and draggable to amend.
- **[Event marks](event-marks.md)** — earnings, dividends, splits and news
  badged under the candle they fell on.
- **[Sessions and time zones](sessions.md)** — day dividers, a display time
  zone, extended-hours shading and colouring a bar yourself.

## Driving it from your code

- **[Driving the chart](driving-the-chart.md)** — `KChartController` for zoom,
  scroll and a PNG of the chart, plus reading and setting the visible window.
- **[Panes](panes.md)** — stacking, resizing and reordering the indicator panes.
- **[Bar replay](bar-replay.md)** — rewind to any candle and step or play the
  market forward, with the indicators only knowing what has arrived.
- **[Sizing](sizing.md)** — how the candle area and the panes divide up the
  height they are given.

## More

- **[Depth chart](depth-chart.md)** — the `DepthChart` widget for an order book:
  its four modes, three axes, how far either side of the mid to look, and the
  bid/ask ratio bar.
- **[Theming](theming.md)** — `ChartStyle` for geometry, `ChartColors` for
  colour, `ChartTranslations` for every label.
- **[Migrating from 1.x](migrating-from-1.x.md)** — what changed, and what to
  replace it with.
