# Migrating from 1.x

No parameters were removed from `KChartWidget`. The per-kind drawing lists,
their `onAdd*` and `onRemove*` callbacks and `isLine` still work, so most apps
only need to update the version. Review the following changes.

## Changed defaults

`crosshairOnHover` and `showScrollToNowButton` are now enabled by default.

- `crosshairOnHover` responds only to hovering pointers, so it has no effect on
  touch devices.
- `showScrollToNowButton` shows a button in the bottom-right corner when the
  chart is scrolled away from the newest candle.

Set either to `false` to restore the previous behaviour.

## Custom drawings must serialise

`toJson` is now part of the `ChartLine` base class; it is required for saving
layouts and for undo history. Build on `baseJson`, and register a matching
`fromJson` where you decode drawings:

```dart
class MyDrawing extends TwoPointDrawing {
  @override
  Map<String, dynamic> toJson() => {
    ...baseJson('myDrawing'),
    ...anchorsJson(),
  };
}
```

Mix in `LabelledDrawing` or `FilledDrawing` to enable the editor's label field
or fill slider for your drawing.

## Internal painter changes

These apply only if you imported painters from `src/` rather than the public
API:

- `ChartPainter` takes a single `drawings` list instead of one list per kind.
- The crosshair candle is reported through an `emitInfoWindow` callback instead
  of a `StreamSink`.
- `MainRenderer.getValue` is now the exact inverse of `getY`, which also fixes a
  small price offset.

## New properties

`ChartLine.hidden` defaults to `false`, so existing drawings remain visible. The
drawing manager uses it to hide drawings.

---

[← All docs](README.md) · [Package README](../README.md)
