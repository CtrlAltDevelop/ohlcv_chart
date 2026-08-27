# Performance

A chart is redrawn more often than almost anything else on screen: every frame
of a pan, every tick from the feed, every pixel the mouse moves. This page says
what the chart does to keep that cheap, and the few things a host can do that
undo it.

## Where it stands

```
Microseconds to paint one frame — 140 candles in a 1200×800 box, median
of three runs. Filled is what it costs now; hollow is what went away.

                        0           200          400  µs
                        ┼──┬──┬──┬──┼──┬───┬──┬──┼──┬──┬──┬
candles                 ███████████████████░░░░░░░░░        312 ← 445  1.4×
OHLC bars               ██████████████████░░░░░░            285 ← 391  1.4×
line                    ████████████░░░░░░░                 190 ← 307  1.6×
area                    ████████████░░░░░░░░░░░░            191 ← 386  2.0×
baseline                ███████████░░░░░░░░░░               173 ← 344  2.0×
step line               ██████████░░░░░░░░░                 162 ← 300  1.9×
high-low band           ██████████░░░░░░░░░░░               163 ← 344  2.1×
columns                 ██████████░░░░░░                    164 ← 254  1.5×
candles + 6 indicators  ████████████████████████░░░░░░░░    382 ← 522  1.4×
a mouse move            ████░░░░░░░░░░░░░░░░░░░░░░░░        72 ← 445  6.2×

With a long history behind the window, on a scale of its own:

                        0           1000        2000  µs
                        ┼──┬──┬──┬──┼──┬──┬──┬──┼──┬──┬──┬─
50k candles, 20 lines   ██░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░    198 ← 2668  13.5×
```

Both charts are the same measurement: the time one call to the painter takes,
which is the part of a frame the chart is responsible for. The gains come from
the sections below — the series batching accounts for most of the per-type
difference, the crosshair layer for the mouse move, and the anchor index for
almost all of the long-history case, which is **13.5× faster**: a frame that
cost 2668µs now costs 198, so what is behind the window no longer decides what
a frame costs.

Reproduce them with:

```
flutter test test/paint_benchmark.dart
```

It is not a test and asserts nothing, so `flutter test` does not collect it —
its name has no `_test` suffix. Run it either side of a change, on the same
quiet machine.

## What the chart already does

**Only the window is drawn.** The paint loop runs from the first candle on
screen to the last, found by binary search, so the cost of a frame follows the
width of the window and not the length of the history. A chart holding a hundred
thousand candles draws the same hundred-odd that a chart holding a thousand
does.

**A series is one draw call, not one per candle.** The renderers are handed a
candle at a time, so a line chart used to spend a `drawPath` on every candle in
the window — ninety candles, ninety calls, and ninety throwaway `Path` objects
with them. Each piece is now collected as its own subpath and the lot goes down
in a single call. What is left per candle is only what is genuinely per candle:

| Chart type | Draw calls per candle |
| --- | --- |
| `line`, `area`, `baseline`, `stepLine`, `hlcArea` | 1 — the volume bar beside it |
| `columns` | 2 |
| `candles` | 3 — wick, body, volume bar |
| `bars` | 4 — the range, the two ticks, volume bar |

A candle body and an OHLC bar stay one rectangle each: a rectangle is cheap, and
folding them into a path would change how they blend. Everything drawn as a
*series* — including both volume moving averages — costs nothing per candle.

**Text is laid out once.** Laying out a label is the most expensive thing the
chart does per label, and the labels barely change: the price axis, the date
axis and the legends read the same strings frame after frame while the chart is
only being hovered. They are held laid out, keyed by the string, its colour and
its size, so a recolour or a resize measures afresh and nothing else does.

**Drawing anchors are indexed.** A drawing remembers *when* it was placed, not
where, so every anchor has to be turned back into a candle index before it can
be drawn. Doing that by searching the list walks the whole history once per
anchor per frame. The lookup is built once per series instead and kept until the
series changes.

**Indicators are extended, not recomputed.** A tick that moves the newest candle
offers each indicator the chance to carry on from what it already has, rather
than computing the whole series again — see
[Recomputing only what moved](indicators.md#recomputing-only-what-moved). An indicator that cannot resume is
recomputed in full, so this is a shortcut where one exists and never a different
answer.

**The crosshair is a layer of its own.** The chart and the crosshair over it are
drawn separately, each behind its own repaint boundary. Moving the mouse redraws
the crosshair, its readouts and the legends — which read out the candle under it
— and leaves every candle, indicator and axis label exactly as it was. On
desktop and web, where the crosshair follows a resting mouse, this is the
difference between redrawing the whole chart on every mouse move and redrawing
almost nothing.

## What a host can do to spoil it

Most of the above is keyed on noticing that nothing has changed, so the thing to
avoid is telling the chart that everything has.

**Append to the candle list; do not rebuild it.** A feed that appends to the
list it already passed is recognised as the same series grown, and the
indicators, the anchor index and the laid-out labels all survive. A host that
builds a fresh list every tick — `[...candles, newOne]` — is passing a series
the chart has never seen, and everything is computed again from the first
candle.

**Keep indicator instances alive.** Indicators are compared by identity as well
as by settings, because two indicators of one kind with the same settings are
free to compute different values. Holding your list in state and appending to
it reuses the computed values; rebuilding `[MaIndicator(period: 20)]` inside
`build` computes them again every frame.

**Pass a stable list of comparisons and events.** These are compared by value,
so a host that rebuilds the list every frame is not realigned every frame — but
an empty `const []` is cheaper still, and a chart with no events never lines any
up.

**Give the chart a stable box.** The geometry is worked out from the size it is
given, so a parent that changes the height every frame recomputes the whole
layout every frame.

## Measuring it

Wall-clock numbers from a test are worth very little — they say more about what
else the machine was doing. What moves a frame budget is draw calls, text
layouts and how much of the series was walked, and all three are counted:

```dart
painter.chartPaints      // times the chart layer has been drawn
painter.overlayPaints    // times the crosshair layer has been drawn
painter.textLayouts      // labels that had to be measured
painter.candleIndex.scans// candles walked to build the anchor lookup
```

`test/render_perf_test.dart` asserts on those, using a `Canvas` in
`test/counting_canvas.dart` that tallies every drawing call and forwards it to a
real one. It measures the *growth* in draw calls as the window widens rather
than an absolute count, so the grid and the dashed price line — which scale with
the canvas and not with the data — stay out of the answer.

`test/paint_benchmark.dart` puts a time on the same cases, for comparing one
revision against another rather than for guarding anything.

For the real thing, run in profile mode and read the timeline:

```
flutter run --profile --trace-skia
```

---

[← All docs](README.md) · [Package README](../README.md)
