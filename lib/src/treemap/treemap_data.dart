import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The colours a [TreemapChart] gives its top-level items, in turn, when they
/// name none of their own and no scale colours them.
const List<Color> treemapPalette = [
  Color(0xFF4C86CD),
  Color(0xFF12B886),
  Color(0xFFF59F00),
  Color(0xFF7950F2),
  Color(0xFFFA5252),
  Color(0xFF15AABF),
  Color(0xFFE64980),
  Color(0xFF82C91E),
];

/// One rectangle of a [TreemapChart], or a group of them.
///
/// A leaf is sized by its [value]. A group is an item with [children]: it is
/// sized by what they add up to, and they are laid out inside it.
@immutable
class TreemapItem {
  /// Creates a leaf worth [value].
  const TreemapItem({
    required this.value,
    this.label,
    this.color,
    this.colorValue,
    this.data,
  }) : children = const [];

  /// Creates a group holding [children], sized by their total.
  const TreemapItem.group({
    required this.children,
    this.label,
    this.color,
    this.data,
  })  : value = 0,
        colorValue = null;

  /// How much room a leaf takes, relative to the others. Ignored for a group.
  final double value;

  /// The items inside a group; empty for a leaf.
  final List<TreemapItem> children;

  /// What the rectangle is called.
  final String? label;

  /// A colour of this item's own, which wins over the chart's scale.
  final Color? color;

  /// The value the chart's scale colours this leaf by — a day's change for a
  /// market map, say — kept apart from [value], which sizes it.
  final double? colorValue;

  /// Anything the app wants back when this item is touched.
  final Object? data;

  /// Whether this item holds others.
  bool get isGroup => children.isNotEmpty;

  /// The room this item takes: its own value, or its children's total.
  double get total {
    if (!isGroup) return value.isFinite && value > 0 ? value : 0;
    var sum = 0.0;
    for (final child in children) {
      sum += child.total;
    }
    return sum;
  }
}

/// Where one [TreemapItem] was laid out.
@immutable
class TreemapTile {
  /// Creates the tile of [item] at [rect].
  const TreemapTile({
    required this.item,
    required this.rect,
    required this.depth,
    required this.index,
    this.parent,
    this.headerRect,
  });

  /// The item this tile draws.
  final TreemapItem item;

  /// The whole tile, in the chart's local pixels, spacing already taken off.
  final Rect rect;

  /// How deeply nested it is: 0 for a top-level item.
  final int depth;

  /// Its position among its siblings, in the order they were given.
  final int index;

  /// The group it sits in, or null at the top level.
  final TreemapTile? parent;

  /// The strip a group's label is written in; null for a leaf, or for a group
  /// too small to hold one.
  final Rect? headerRect;

  /// The top-level tile this one belongs to — itself, at the top.
  TreemapTile get root {
    var tile = this;
    while (tile.parent != null) {
      tile = tile.parent!;
    }
    return tile;
  }
}

/// Lays [items] out inside [bounds] as a squarified treemap.
///
/// Every item takes a share of the area in proportion to its
/// [TreemapItem.total], and the rectangles are kept as close to square as the
/// proportions allow, which is what keeps small items readable. Items worth
/// nothing are left out.
///
/// Groups come before their children in the result, so painting it in order
/// draws a group's background under what is inside it. [spacing] is left
/// between neighbouring tiles, and a group holds back [groupHeaderHeight] at
/// its top for its label when it is tall enough to spare it.
///
/// With [sort] on — the default — the largest items are placed first, which
/// gives the squarest layout; off, the given order is kept.
List<TreemapTile> layOutTreemap(
  List<TreemapItem> items,
  Rect bounds, {
  double spacing = 0,
  double groupHeaderHeight = 0,
  bool sort = true,
}) {
  final tiles = <TreemapTile>[];
  _layOutLevel(
    items,
    bounds,
    tiles,
    spacing: math.max(0, spacing),
    groupHeaderHeight: math.max(0, groupHeaderHeight),
    sort: sort,
    depth: 0,
    parent: null,
  );
  return tiles;
}

void _layOutLevel(
  List<TreemapItem> items,
  Rect bounds,
  List<TreemapTile> out, {
  required double spacing,
  required double groupHeaderHeight,
  required bool sort,
  required int depth,
  required TreemapTile? parent,
}) {
  if (bounds.width <= 0 || bounds.height <= 0) return;

  final entries = <_Entry>[
    for (var i = 0; i < items.length; i++)
      if (items[i].total > 0) _Entry(items[i], i, items[i].total),
  ];
  if (entries.isEmpty) return;
  if (sort) entries.sort((a, b) => b.weight.compareTo(a.weight));

  var sum = 0.0;
  for (final entry in entries) {
    sum += entry.weight;
  }
  final scale = bounds.width * bounds.height / sum;
  for (final entry in entries) {
    entry.area = entry.weight * scale;
  }

  _squarify(entries, bounds);

  for (final entry in entries) {
    final rect = entry.rect.deflate(spacing / 2);
    if (rect.width <= 0 || rect.height <= 0) continue;

    final item = entry.item;
    // A header only where it leaves the children something to be laid out in.
    final header = item.isGroup &&
            groupHeaderHeight > 0 &&
            rect.height > groupHeaderHeight * 2
        ? Rect.fromLTWH(rect.left, rect.top, rect.width, groupHeaderHeight)
        : null;

    final tile = TreemapTile(
      item: item,
      rect: rect,
      depth: depth,
      index: entry.index,
      parent: parent,
      headerRect: header,
    );
    out.add(tile);

    if (item.isGroup) {
      _layOutLevel(
        item.children,
        header == null
            ? rect
            : Rect.fromLTRB(rect.left, header.bottom, rect.right, rect.bottom),
        out,
        spacing: spacing,
        groupHeaderHeight: groupHeaderHeight,
        sort: sort,
        depth: depth + 1,
        parent: tile,
      );
    }
  }
}

class _Entry {
  _Entry(this.item, this.index, this.weight);

  final TreemapItem item;
  final int index;
  final double weight;
  double area = 0;
  Rect rect = Rect.zero;
}

/// Bruls, Huizing and van Wijk's squarified layout: rows are filled along the
/// shorter side of what is left for as long as adding an item makes the row's
/// worst aspect ratio better, then the row is fixed and the rest carries on.
void _squarify(List<_Entry> entries, Rect bounds) {
  var remaining = bounds;
  var start = 0;

  while (start < entries.length) {
    final side = math.min(remaining.width, remaining.height);
    var end = start + 1;
    var rowArea = entries[start].area;
    var worst = _worstRatio(entries, start, end, rowArea, side);

    while (end < entries.length) {
      final nextArea = rowArea + entries[end].area;
      final next = _worstRatio(entries, start, end + 1, nextArea, side);
      if (next > worst) break;
      worst = next;
      rowArea = nextArea;
      end++;
    }

    final last = end == entries.length;
    if (remaining.width >= remaining.height) {
      // A column down the left of what is left.
      final width = last
          ? remaining.width
          : remaining.height <= 0
              ? 0.0
              : rowArea / remaining.height;
      var top = remaining.top;
      for (var i = start; i < end; i++) {
        final height = i == end - 1
            ? remaining.bottom - top
            : width <= 0
                ? 0.0
                : entries[i].area / width;
        entries[i].rect = Rect.fromLTWH(remaining.left, top, width, height);
        top += height;
      }
      remaining = Rect.fromLTRB(
        math.min(remaining.left + width, remaining.right),
        remaining.top,
        remaining.right,
        remaining.bottom,
      );
    } else {
      // A row across the top of what is left.
      final height = last
          ? remaining.height
          : remaining.width <= 0
              ? 0.0
              : rowArea / remaining.width;
      var left = remaining.left;
      for (var i = start; i < end; i++) {
        final width = i == end - 1
            ? remaining.right - left
            : height <= 0
                ? 0.0
                : entries[i].area / height;
        entries[i].rect = Rect.fromLTWH(left, remaining.top, width, height);
        left += width;
      }
      remaining = Rect.fromLTRB(
        remaining.left,
        math.min(remaining.top + height, remaining.bottom),
        remaining.right,
        remaining.bottom,
      );
    }

    start = end;
  }
}

/// The worst aspect ratio in the row [start]..[end], laid along [side].
double _worstRatio(
  List<_Entry> entries,
  int start,
  int end,
  double rowArea,
  double side,
) {
  if (rowArea <= 0 || side <= 0) return double.infinity;
  var largest = 0.0;
  var smallest = double.infinity;
  for (var i = start; i < end; i++) {
    largest = math.max(largest, entries[i].area);
    smallest = math.min(smallest, entries[i].area);
  }
  final sideSquared = side * side;
  final areaSquared = rowArea * rowArea;
  return math.max(
    sideSquared * largest / areaSquared,
    areaSquared / (sideSquared * smallest),
  );
}

/// The deepest leaf under [local] in [tiles], or null when there is none.
TreemapTile? treemapTileAt(List<TreemapTile> tiles, Offset local) {
  for (var i = tiles.length - 1; i >= 0; i--) {
    final tile = tiles[i];
    if (!tile.item.isGroup && tile.rect.contains(local)) return tile;
  }
  return null;
}
