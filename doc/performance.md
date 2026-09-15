# Performance

Charts redraw frequently: on every frame of a pan, every data update and every
mouse movement. This page describes the chart's rendering optimisations, the
patterns in host code that can defeat them, and how to measure performance.

## Benchmarks

```
Paint time per frame (µs) — 140 candles, 1200×800, median of three runs.
Filled bar: current. Hollow bar: before the 2.3.1 optimisations.

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

Long history behind the visible window:

                        0           1000        2000  µs
                        ┼──┬──┬──┬──┼──┬──┬──┬──┼──┬──┬──┬─
50k candles, 20 lines   ██░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░    198 ← 2668  13.5×
```

Both measure the duration of a single painter call — the portion of a frame the
chart is responsible for. Series batching accounts for most per-type
improvements, the separate crosshair layer for mouse movement, and anchor
indexing for the long-history case, which is **13.5× faster** (2668 µs to
198 µs). Frame cost no longer depends on the amount of off-screen history.

To reproduce:

```
flutter test test/paint_benchmark.dart
```

The benchmark has no assertions and no `_test` suffix, so `flutter test` does
not run it by default. Run it before and after a change on the same idle
machine.

## Built-in optimisations

**Visible-range rendering.** The paint loop covers only the visible candles,
located by binary search. Frame cost depends on window width, not history
length.

**Batched series drawing.** Series are collected as subpaths and drawn in a
single call, rather than one `drawPath` (and one `Path` allocation) per candle.
Remaining per-candle draw calls:

| Chart type | Draw calls per candle |
| --- | --- |
| `line`, `area`, `baseline`, `stepLine`, `hlcArea` | 1 — the volume bar beside it |
| `columns` | 2 |
| `candles` | 3 — wick, body, volume bar |
| `bars` | 4 — the range, the two ticks, volume bar |

Candle bodies and OHLC bars remain individual rectangles, which are inexpensive
and blend correctly. All series, including volume moving averages, have no
per-candle cost.

**Text layout caching.** Text layout is the most expensive per-label operation.
Axis and legend labels are cached by string, colour and size, and re-laid out
only when one of those changes.

**Indexed drawing anchors.** Drawings store timestamps, which must be resolved to
candle indices. A lookup table is built once per series and reused until the
series changes, instead of searching the history for each anchor on each frame.

**Incremental indicator updates.** When the newest candle changes, indicators
that support it extend their existing results instead of recomputing the full
series — see [Recomputing only what moved](indicators.md#recomputing-only-what-moved).
Indicators that cannot resume are recomputed in full, so results are always
identical.

**Separate crosshair layer.** The chart and crosshair are drawn behind separate
repaint boundaries. Mouse movement repaints only the crosshair, its labels and
the legends; candles, indicators and axes are untouched. This is especially
significant on desktop and web, where the crosshair follows the mouse.

## Avoiding common pitfalls

Most optimisations depend on detecting unchanged input. Avoid patterns that make
unchanged data look new.

**Append to the candle list instead of replacing it.** Appending to the same list
is recognised as growth of the existing series, preserving indicator results,
the anchor index and cached labels. Creating a new list on every update (for
example `[...candles, newOne]`) forces a full recomputation.

**Keep indicator instances stable.** Indicators are compared by identity as well
as settings. Store the indicator list in state; creating
`[MaIndicator(period: 20)]` inside `build` recomputes values on every frame.

**Use stable comparison and event lists.** These are compared by value, so
rebuilding them does not force realignment, but `const []` is cheaper when there
are none.

**Provide stable constraints.** Layout is derived from the chart's size. A
parent that changes the chart's height every frame forces a full layout on
every frame.

## Measuring

Wall-clock timings in tests are unreliable because they depend on system load.
The chart instead exposes counters for draw calls, text layouts and series
scans:

```dart
painter.chartPaints      // times the chart layer has been drawn
painter.overlayPaints    // times the crosshair layer has been drawn
painter.textLayouts      // labels that had to be measured
painter.candleIndex.scans// candles walked to build the anchor lookup
```

`test/render_perf_test.dart` asserts on these counters, using the `Canvas`
wrapper in `test/counting_canvas.dart` that counts every draw call. It measures
how draw calls grow as the window widens rather than absolute counts, excluding
elements that scale with the canvas, such as the grid.

`test/paint_benchmark.dart` measures timings for the same scenarios, for
comparing revisions.

For real-world profiling, run in profile mode and inspect the timeline:

```
flutter run --profile --trace-skia
```

---

[← All docs](README.md) · [Package README](../README.md)
