# Treemap

![A market map of sectors and symbols, beside portfolio weight as tiles](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/treemap.png)

`TreemapChart` divides a rectangle into tiles sized by value. Typical uses
include market maps (stocks sized by market cap and coloured by daily change),
portfolio composition and budget breakdowns.

```dart
TreemapChart(
  items: [
    TreemapItem.group(label: 'Technology', children: [
      TreemapItem(value: 3400, label: 'AAPL', colorValue: 1.8),
      TreemapItem(value: 3100, label: 'MSFT', colorValue: -0.6),
      TreemapItem(value: 2200, label: 'NVDA', colorValue: 4.2),
    ]),
    TreemapItem.group(label: 'Finance', children: [
      TreemapItem(value: 560, label: 'JPM', colorValue: 0.4),
      TreemapItem(value: 480, label: 'V', colorValue: -1.1),
    ]),
  ],
  scale: const HeatmapGradientScale(
    colors: [Color(0xFFE03131), Color(0xFF343A40), Color(0xFF2F9E44)],
  ),
  minColorValue: -3,
  maxColorValue: 3,
  labelBuilder: (tile) =>
      '${tile.item.label}\n${tile.item.colorValue!.toStringAsFixed(1)}%',
);
```

The chart fills its constraints. When the height is unbounded, it uses
`defaultHeight`.

## Items

| Constructor | Description |
| --- | --- |
| `TreemapItem(value:)` | A leaf tile sized by `value` |
| `TreemapItem.group(children:)` | A group sized by the total of its children, which are laid out inside it |

| Field | Description |
| --- | --- |
| `label` | Tile or group label |
| `color` | Fixed colour; takes precedence over the scale |
| `colorValue` | Value used by `scale` to colour a leaf, independent of its size |
| `data` | Arbitrary app data, returned on touch |

Items with a value of zero, a negative value or a non-finite value are omitted.

## Layout

Tiles use the squarified algorithm, which keeps tiles as close to square as the
proportions allow so small items remain readable.

| Parameter | Description |
| --- | --- |
| `sort` | Place the largest items first for the squarest layout (default); `false` keeps the given order |
| `spacing` | Gap between tiles |
| `radius` | Tile corner rounding, as a `BorderRadius` |
| `groupHeaderHeight` | Height reserved at the top of a group for its label; omitted for groups too short to fit it. `0` disables headers |
| `groupColor`, `groupLabelStyle` | Group background and label style |
| `padding` | Space around the chart |

## Colour

A leaf's colour is resolved in this order:

1. `TreemapItem.color`.
2. `scale`, applied to `colorValue` over `minColorValue`–`maxColorValue` (or the
   range of all colour values). Leaves without a `colorValue` use the scale's
   `emptyColor`. Any `HeatmapScale` works, including `HeatmapGradientScale` for a
   diverging red–green market map and `HeatmapStepScale` for bands.
3. The nearest enclosing group's `color`.
4. `palette`, indexed by the top-level item the leaf belongs to.

## Labels

- `labelBuilder` returns the text for a leaf; line breaks are supported, so a
  second line can show a value. Without it, `TreemapItem.label` is used.
- `labelAlignment` and `labelPadding` position the text within the tile.
- Without `labelStyle`, text is black or white depending on tile brightness.
- Labels that do not fit their tile are omitted.

## Touch

Touch or mouse hover identifies the leaf under the pointer. `hoverBorder`
highlights it, `onTouch` reports a `TreemapTouchDetails` (or `null` when the
touch ends), and `tooltipBuilder` shows a widget above it:

```dart
TreemapChart(
  items: items,
  onTouch: (details) => setState(() => selected = details?.item.data),
  tooltipBuilder: (context, details) => Card(
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Text('${details.item.label}: ${details.item.value}'),
    ),
  ),
);
```

Groups are not touch targets; touches resolve to the leaf beneath.

## Custom layout

`layOutTreemap` and `treemapTileAt` are public, so the layout can be tested or
used to position custom widgets:

```dart
final tiles = layOutTreemap(items, const Rect.fromLTWH(0, 0, 400, 300));
final tile = treemapTileAt(tiles, const Offset(120, 80));
```

Each `TreemapTile` exposes its `rect`, `depth`, `parent`, `root` and, for groups,
`headerRect`.

## Animation

When `animationDuration` is set, tiles grow from their centres on first build
and whenever `items` changes.

---

[← All docs](README.md) · [Package README](../README.md)
