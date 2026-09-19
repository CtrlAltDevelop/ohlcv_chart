import 'package:flutter/painting.dart';

/// The shape of [rect] with [radius] on its corners.
///
/// The radii are read as they are drawn on the screen — `topLeft` is the
/// rectangle's top-left corner however the shape it belongs to was grown — and
/// scaled down together when they are too big for [rect], so a corner can
/// never bow past the middle of an edge.
RRect roundedBox(Rect rect, BorderRadius radius) {
  if (radius == BorderRadius.zero) {
    return RRect.fromRectAndRadius(rect, Radius.zero);
  }
  return radius.toRRect(rect).scaleRadii();
}
