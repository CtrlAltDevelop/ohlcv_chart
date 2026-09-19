import 'dart:collection';

import 'package:material_ui/material_ui.dart';

/// Holds laid-out text between frames.
///
/// Laying text out is the most expensive thing the chart does per label, and
/// the labels barely change: the price axis, the date axis and the indicator
/// legends read the same strings frame after frame while the chart is only
/// being hovered or nudged. Every one of them used to be measured again from
/// scratch on every repaint.
///
/// Keyed by everything that can change the result — the string, its colour and
/// its size — so a recolour or a resize lays out afresh and anything else is
/// reused.
///
/// Give a chart one and keep it for the chart's life, and call [dispose] when
/// that life ends; `KChartWidget` owns one already and disposes it. A laid-out
/// [TextPainter] holds a native paragraph, so a cache of a few hundred that is
/// simply dropped leaks every one of them.
///
/// The painters it hands back are shared. Paint them where you like — the
/// offset is the caller's — but never mutate one, or every other holder of it
/// gets the change too.
class TextPainterCache {
  TextPainterCache({this.capacity = 256});

  /// How many laid-out labels to keep before the least recently used goes.
  ///
  /// A chart draws a few dozen labels a frame; the rest of the room absorbs a
  /// price axis whose numbers change as it is panned.
  final int capacity;

  final LinkedHashMap<_Key, TextPainter> _entries =
      LinkedHashMap<_Key, TextPainter>();

  /// How many labels have been served without laying them out again.
  ///
  /// Useful in a test or a benchmark; nothing in the chart reads it.
  int get hits => _hits;
  int _hits = 0;

  /// How many have had to be laid out.
  int get layouts => _layouts;
  int _layouts = 0;

  /// Forgets everything, as though the cache were new.
  ///
  /// The painters it was holding are disposed, so nothing that was handed out
  /// before this call may be painted again.
  void clear() {
    for (final painter in _entries.values) {
      painter.dispose();
    }
    _entries.clear();
  }

  /// Disposes every painter it holds and leaves the cache unusable.
  ///
  /// Call it from the `dispose` of whatever owns the cache.
  void dispose() {
    assert(!_disposed, 'TextPainterCache disposed twice');
    clear();
    _disposed = true;
  }

  bool _disposed = false;

  /// A painter for [text] in [style], laid out and ready to paint.
  TextPainter get(String text, TextStyle style) {
    assert(!_disposed, 'TextPainterCache used after dispose');
    final key = _Key(text, style.color, style.fontSize, style.fontWeight);
    final found = _entries.remove(key);
    if (found != null) {
      // Reinserting puts it back at the fresh end, so what the chart draws
      // every frame is never what gets evicted.
      _entries[key] = found;
      _hits++;
      return found;
    }

    _layouts++;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    if (_entries.length >= capacity) {
      // The least recently used goes, and its native paragraph with it. It was
      // last handed out at least a capacity's worth of labels ago, which is
      // more than any one frame lays out.
      _entries.remove(_entries.keys.first)?.dispose();
    }
    _entries[key] = painter;
    return painter;
  }
}

class _Key {
  const _Key(this.text, this.color, this.fontSize, this.weight);

  final String text;
  final Color? color;
  final double? fontSize;
  final FontWeight? weight;

  @override
  bool operator ==(Object other) =>
      other is _Key &&
      other.text == text &&
      other.color == color &&
      other.fontSize == fontSize &&
      other.weight == weight;

  @override
  int get hashCode => Object.hash(text, color, fontSize, weight);
}
