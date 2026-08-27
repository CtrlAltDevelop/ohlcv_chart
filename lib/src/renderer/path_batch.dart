import 'package:flutter/material.dart' show Canvas, Paint, Path;

/// Collects the pieces of one series and draws them in a single call.
///
/// The renderers are handed one candle at a time, which used to mean one
/// `drawPath` or `drawLine` per candle — a window of ninety candles spent ninety
/// draw calls on a line that is one stroke. Each piece is appended as its own
/// subpath, so a batch strokes and fills exactly as the separate calls did: a
/// subpath that starts with `moveTo` has no join to the one before it, and a
/// closed subpath keeps its own outline.
///
/// Reset by [flush], so one batch serves every frame of a repaint.
class PathBatch {
  final Path _path = Path();

  /// Whether anything has been added since the last flush.
  bool get isEmpty => _empty;
  bool _empty = true;

  /// The path being built, for a caller that has to append something shaped.
  ///
  /// Mark it with [touch], or a flush will take the batch for empty and drop
  /// it.
  Path get path => _path;

  /// Says that something has been appended to [path] directly.
  void touch() => _empty = false;

  /// Adds a straight segment, unjoined to whatever came before it.
  void addSegment(double x1, double y1, double x2, double y2) {
    _path
      ..moveTo(x1, y1)
      ..lineTo(x2, y2);
    _empty = false;
  }

  /// Draws what has been collected and empties the batch.
  void flush(Canvas canvas, Paint paint) {
    if (_empty) return;
    canvas.drawPath(_path, paint);
    _path.reset();
    _empty = true;
  }
}
