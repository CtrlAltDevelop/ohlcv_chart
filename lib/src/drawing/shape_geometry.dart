/// Where the lines of the fan, box and fork shapes fall on the canvas.
///
/// Every function here works in view space and takes only the anchors it needs,
/// so the painter and the hit test read the same geometry from the same place
/// rather than each doing the arithmetic its own way.
library;

import 'dart:ui';

import '../entity/pitchfork_drawing.dart';

/// The direction a Gann ray at [ratio] leaves [pivot] in.
///
/// [oneByOne] is where the `1×1` was placed, which sets one unit of price
/// against one unit of time. Multiplying the vertical component by the ratio
/// gives the whole fan: `2` is the `1×2`, `0.5` the `2×1`.
Offset gannRayDirection(Offset pivot, Offset oneByOne, double ratio) {
  final run = oneByOne - pivot;
  return Offset(run.dx, run.dy * ratio);
}

/// Where a Gann ray at [ratio] passes, one unit of time out from [pivot].
///
/// The point is only a direction made concrete; the painter runs the ray on
/// past it to the edge of the chart.
Offset gannRayThrough(Offset pivot, Offset oneByOne, double ratio) =>
    pivot + gannRayDirection(pivot, oneByOne, ratio);

/// Where a Fibonacci fan ray at [level] passes, on the far edge of the swing.
///
/// The swing is boxed by [from] and [to]. Level `0` puts the ray through the
/// flat top of the box and `1` through the far corner, so the fan spreads
/// between the two.
Offset fibFanRayThrough(Offset from, Offset to, double level) =>
    Offset(to.dx, from.dy + (to.dy - from.dy) * level);

/// Where a Fibonacci time zone at [level] falls, in canvas x.
///
/// [from] and [to] set one unit of time, so level `8` is eight units on from
/// the first anchor.
double fibTimeZoneX(Offset from, Offset to, double level) =>
    from.dx + (to.dx - from.dx) * level;

/// The horizontal and vertical rules of a Gann box at [ratios].
///
/// Each ratio is taken as a fraction of the box both ways, so the two lists
/// come back together: the prices to rule across, and the times to rule down.
({List<double> horizontals, List<double> verticals}) gannBoxRules(
  Rect box,
  List<double> ratios,
) => (
  horizontals: [for (final r in ratios) box.top + box.height * r],
  verticals: [for (final r in ratios) box.left + box.width * r],
);

/// The handle, median and tines of a pitchfork, in view space.
///
/// [handle] is where the median leaves from, which is the pivot itself for
/// Andrews' and a lifted point for the two Schiffs. [median] is the midpoint of
/// the second and third anchors, which the median line runs through. [tines] is
/// one pair of lines per level, each running parallel to the median.
typedef ForkGeometry = ({
  Offset handle,
  Offset median,
  List<({double level, Offset upper, Offset lower})> tines,
});

/// Works out a pitchfork's handle, median and tines from its three anchors.
///
/// [levels] are fractions of the way out to the anchors: `0` is the median
/// itself and `1` the tines through [p2] and [p3]. Each tine is given as the
/// point it starts at, alongside the handle; the painter runs it out parallel
/// to the median.
ForkGeometry pitchforkGeometry(
  Offset p1,
  Offset p2,
  Offset p3,
  PitchforkKind kind,
  List<double> levels,
) {
  final median = Offset((p2.dx + p3.dx) / 2, (p2.dy + p3.dy) / 2);
  final handle = switch (kind) {
    // Andrews' leaves the handle on the pivot.
    PitchforkKind.andrews => p1,
    // Schiff lifts it halfway to the median in price, which takes some of the
    // trend out of the slope without moving it in time.
    PitchforkKind.schiff => Offset(p1.dx, (p1.dy + median.dy) / 2),
    // Modified Schiff lifts it in time as well.
    PitchforkKind.modifiedSchiff => Offset(
      (p1.dx + median.dx) / 2,
      (p1.dy + median.dy) / 2,
    ),
  };

  return (
    handle: handle,
    median: median,
    tines: [
      for (final level in levels)
        (
          level: level,
          upper: median + (p2 - median) * level,
          lower: median + (p3 - median) * level,
        ),
    ],
  );
}
