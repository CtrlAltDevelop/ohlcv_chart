import 'dart:typed_data';
import 'dart:ui';

/// A [Canvas] that tallies the drawing calls made through it and forwards
/// every one to a real canvas underneath.
///
/// Draw-call counts are what a render optimisation actually moves, and unlike a
/// stopwatch they are the same number on a busy CI machine as on a quiet one.
/// Forwarding rather than swallowing keeps the painters honest: they are drawing
/// into a real recorder, so anything that would throw on a real canvas still
/// throws here.
class CountingCanvas implements Canvas {
  CountingCanvas(this._inner);

  final Canvas _inner;

  /// How many times each drawing call was made, by method name.
  final Map<String, int> counts = <String, int>{};

  /// Every drawing call made, whatever it was.
  int get totalDraws =>
      counts.entries.fold(0, (sum, entry) => sum + entry.value);

  /// Forgets the tally, leaving the canvas itself alone.
  void reset() => counts.clear();

  int operator [](String method) => counts[method] ?? 0;

  void _tally(String method) =>
      counts.update(method, (n) => n + 1, ifAbsent: () => 1);

  @override
  String toString() {
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => '${e.key}=${e.value}').join(', ');
  }

  // ── The calls worth counting ─────────────────────────────────────────────

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    _tally('drawLine');
    _inner.drawLine(p1, p2, paint);
  }

  @override
  void drawPath(Path path, Paint paint) {
    _tally('drawPath');
    _inner.drawPath(path, paint);
  }

  @override
  void drawRect(Rect rect, Paint paint) {
    _tally('drawRect');
    _inner.drawRect(rect, paint);
  }

  @override
  void drawRRect(RRect rrect, Paint paint) {
    _tally('drawRRect');
    _inner.drawRRect(rrect, paint);
  }

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    _tally('drawCircle');
    _inner.drawCircle(c, radius, paint);
  }

  @override
  void drawOval(Rect rect, Paint paint) {
    _tally('drawOval');
    _inner.drawOval(rect, paint);
  }

  @override
  void drawParagraph(Paragraph paragraph, Offset offset) {
    _tally('drawParagraph');
    _inner.drawParagraph(paragraph, offset);
  }

  @override
  void drawArc(
    Rect rect,
    double startAngle,
    double sweepAngle,
    bool useCenter,
    Paint paint,
  ) {
    _tally('drawArc');
    _inner.drawArc(rect, startAngle, sweepAngle, useCenter, paint);
  }

  @override
  void drawDRRect(RRect outer, RRect inner, Paint paint) {
    _tally('drawDRRect');
    _inner.drawDRRect(outer, inner, paint);
  }

  @override
  void drawRSuperellipse(RSuperellipse rsuperellipse, Paint paint) {
    _tally('drawRSuperellipse');
    _inner.drawRSuperellipse(rsuperellipse, paint);
  }

  @override
  void drawPoints(PointMode pointMode, List<Offset> points, Paint paint) {
    _tally('drawPoints');
    _inner.drawPoints(pointMode, points, paint);
  }

  @override
  void drawRawPoints(PointMode pointMode, Float32List points, Paint paint) {
    _tally('drawRawPoints');
    _inner.drawRawPoints(pointMode, points, paint);
  }

  @override
  void drawVertices(Vertices vertices, BlendMode blendMode, Paint paint) {
    _tally('drawVertices');
    _inner.drawVertices(vertices, blendMode, paint);
  }

  @override
  void drawColor(Color color, BlendMode blendMode) {
    _tally('drawColor');
    _inner.drawColor(color, blendMode);
  }

  @override
  void drawPaint(Paint paint) {
    _tally('drawPaint');
    _inner.drawPaint(paint);
  }

  @override
  void drawPicture(Picture picture) {
    _tally('drawPicture');
    _inner.drawPicture(picture);
  }

  @override
  void drawImage(Image image, Offset offset, Paint paint) {
    _tally('drawImage');
    _inner.drawImage(image, offset, paint);
  }

  @override
  void drawImageRect(Image image, Rect src, Rect dst, Paint paint) {
    _tally('drawImageRect');
    _inner.drawImageRect(image, src, dst, paint);
  }

  @override
  void drawImageNine(Image image, Rect center, Rect dst, Paint paint) {
    _tally('drawImageNine');
    _inner.drawImageNine(image, center, dst, paint);
  }

  @override
  void drawAtlas(
    Image atlas,
    List<RSTransform> transforms,
    List<Rect> rects,
    List<Color>? colors,
    BlendMode? blendMode,
    Rect? cullRect,
    Paint paint,
  ) {
    _tally('drawAtlas');
    _inner.drawAtlas(
      atlas,
      transforms,
      rects,
      colors,
      blendMode,
      cullRect,
      paint,
    );
  }

  @override
  void drawRawAtlas(
    Image atlas,
    Float32List rstTransforms,
    Float32List rects,
    Int32List? colors,
    BlendMode? blendMode,
    Rect? cullRect,
    Paint paint,
  ) {
    _tally('drawRawAtlas');
    _inner.drawRawAtlas(
      atlas,
      rstTransforms,
      rects,
      colors,
      blendMode,
      cullRect,
      paint,
    );
  }

  @override
  void drawShadow(
    Path path,
    Color color,
    double elevation,
    bool transparentOccluder,
  ) {
    _tally('drawShadow');
    _inner.drawShadow(path, color, elevation, transparentOccluder);
  }

  // ── State, forwarded but not counted ─────────────────────────────────────

  @override
  void save() => _inner.save();

  @override
  void saveLayer(Rect? bounds, Paint paint) {
    _tally('saveLayer');
    _inner.saveLayer(bounds, paint);
  }

  @override
  void restore() => _inner.restore();

  @override
  void restoreToCount(int count) => _inner.restoreToCount(count);

  @override
  int getSaveCount() => _inner.getSaveCount();

  @override
  void translate(double dx, double dy) => _inner.translate(dx, dy);

  @override
  void scale(double sx, [double? sy]) => _inner.scale(sx, sy);

  @override
  void rotate(double radians) => _inner.rotate(radians);

  @override
  void skew(double sx, double sy) => _inner.skew(sx, sy);

  @override
  void transform(Float64List matrix4) => _inner.transform(matrix4);

  @override
  Float64List getTransform() => _inner.getTransform();

  @override
  void clipRect(
    Rect rect, {
    ClipOp clipOp = ClipOp.intersect,
    bool doAntiAlias = true,
  }) =>
      _inner.clipRect(rect, clipOp: clipOp, doAntiAlias: doAntiAlias);

  @override
  void clipRRect(RRect rrect, {bool doAntiAlias = true}) =>
      _inner.clipRRect(rrect, doAntiAlias: doAntiAlias);

  @override
  void clipRSuperellipse(
    RSuperellipse rsuperellipse, {
    bool doAntiAlias = true,
  }) =>
      _inner.clipRSuperellipse(rsuperellipse, doAntiAlias: doAntiAlias);

  @override
  void clipPath(Path path, {bool doAntiAlias = true}) =>
      _inner.clipPath(path, doAntiAlias: doAntiAlias);

  @override
  Rect getLocalClipBounds() => _inner.getLocalClipBounds();

  @override
  Rect getDestinationClipBounds() => _inner.getDestinationClipBounds();
}
