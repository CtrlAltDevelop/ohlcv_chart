# Migrating from 1.x

Nothing was taken off `KChartWidget`: the per-kind drawing lists, their `onAdd*`
and `onRemove*` callbacks and `isLine` all still work, so most apps upgrade by
changing the version and nothing else. Three things to know:

- **Two defaults changed what an existing chart shows.** `crosshairOnHover` and
  `showScrollToNowButton` are both on. The first only ever fires for a pointer
  that hovers, so a touch app never sees it; the second draws a small button over
  the bottom right corner whenever the chart is scrolled away from the newest
  candle. Set either to `false` to keep the old behaviour.
- **A custom `ChartLine` now has to serialise.** `toJson` is part of the base
  class, since that is what lets a layout be saved and a drawing be copied for
  the undo history. Build yours on `baseJson`, and register a `fromJson` of your
  own where you decode:

  ```dart
  class MyDrawing extends TwoPointDrawing {
    @override
    Map<String, dynamic> toJson() => {
      ...baseJson('myDrawing'),
      ...anchorsJson(),
    };
  }
  ```

  Adopting `LabelledDrawing` or `FilledDrawing` is what gets your drawing the
  editor's label field or its fill slider.
- **The painters moved on**, if you imported them from `src/` rather than through
  the public API: `ChartPainter` now takes one `drawings` list rather than a list
  per kind, and reports the crosshair's candle through an `emitInfoWindow`
  callback rather than a `StreamSink`. `MainRenderer.getValue` is now the exact
  inverse of `getY`, which also corrects a price read a few pixels out.

`ChartLine.hidden` is new and defaults to false, so nothing disappears; the
drawing manager is what turns it on.

---

[← All docs](README.md) · [Package README](../README.md)
