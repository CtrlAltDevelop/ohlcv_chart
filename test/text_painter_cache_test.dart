import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ohlcv_chart/src/corner_radius.dart';
import 'package:ohlcv_chart/src/renderer/text_painter_cache.dart';

const _style = TextStyle(color: Color(0xFFFFFFFF), fontSize: 10);

void main() {
  group('the label cache', () {
    test('serves the same painter twice', () {
      final cache = TextPainterCache(capacity: 4);
      final first = cache.get('12.50', _style);
      final second = cache.get('12.50', _style);

      expect(identical(first, second), isTrue);
      expect(cache.hits, 1);
      expect(cache.layouts, 1);
      cache.dispose();
    });

    test('lays out afresh for a different colour or size', () {
      final cache = TextPainterCache(capacity: 8);
      cache.get('12.50', _style);
      cache.get('12.50', _style.copyWith(color: const Color(0xFF000000)));
      cache.get('12.50', _style.copyWith(fontSize: 12));

      expect(cache.layouts, 3);
      expect(cache.hits, 0);
      cache.dispose();
    });

    test('disposes the painter it evicts', () {
      final cache = TextPainterCache(capacity: 2);
      final evicted = cache.get('a', _style);
      cache.get('b', _style);
      // 'a' is the least recently used, so laying out a third label drops it.
      cache.get('c', _style);

      expect(
        () => evicted.paint(_NullCanvas(), Offset.zero),
        throwsA(anything),
      );
      cache.dispose();
    });

    test('keeps what is drawn every frame and drops what is not', () {
      final cache = TextPainterCache(capacity: 2);
      cache.get('kept', _style);
      cache.get('churn', _style);
      // Reading 'kept' puts it back at the fresh end, so the next label
      // evicts 'churn' instead of it.
      cache.get('kept', _style);
      cache.get('new', _style);

      final layoutsBefore = cache.layouts;
      cache.get('kept', _style);
      expect(cache.layouts, layoutsBefore, reason: 'kept was laid out again');
      cache.dispose();
    });

    test('disposes everything it holds', () {
      final cache = TextPainterCache(capacity: 4);
      final painter = cache.get('12.50', _style);
      cache.dispose();

      expect(
        () => painter.paint(_NullCanvas(), Offset.zero),
        throwsA(anything),
      );
    });

    test('rejects use after dispose', () {
      final cache = TextPainterCache(capacity: 4)..dispose();
      expect(() => cache.get('12.50', _style), throwsAssertionError);
    });
  });

  group('roundedBox', () {
    const rect = Rect.fromLTWH(0, 0, 40, 20);

    test('squares a negative radius rather than inverting the corner', () {
      final box = roundedBox(rect, BorderRadius.circular(-4));
      expect(box.tlRadiusX, 0);
      expect(box.tlRadiusY, 0);
    });

    test('scales radii too big for the rectangle down together', () {
      final box = roundedBox(
        rect,
        const BorderRadius.vertical(top: Radius.circular(500)),
      );
      expect(box.tlRadiusX, lessThanOrEqualTo(rect.width / 2));
      expect(box.tlRadiusY, lessThanOrEqualTo(rect.height));
      expect(box.blRadiusX, 0);
    });

    test('reads the corners as they are drawn', () {
      final box = roundedBox(
        rect,
        const BorderRadius.only(topLeft: Radius.circular(4)),
      );
      expect(box.tlRadiusX, 4);
      expect(box.trRadiusX, 0);
      expect(box.brRadiusX, 0);
      expect(box.blRadiusX, 0);
    });
  });
}

/// A canvas that records nothing — painting onto it only has to reach the
/// painter's own state.
class _NullCanvas implements Canvas {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
