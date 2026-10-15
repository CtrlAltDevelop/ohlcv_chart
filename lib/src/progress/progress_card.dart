import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// How a [ProgressCard]'s background fills in.
enum ProgressCardMode {
  /// A wedge sweeps round the card's centre like a clock, from twelve o'clock
  /// and clockwise. Half done is the right half; a quarter is the top right.
  /// The angle is the progress, so it reads at a glance on a tile.
  sweep,

  /// A circle grows from the middle of the card's left edge, and at full
  /// progress has reached the far corners. Its edge is a curve rather than a
  /// line, which suits a wide card better than a sweep does.
  circle,

  /// A bar fills the card from its left edge, as wide as the progress. Reads
  /// best on a wide, short card.
  linear,
}

/// A card around any widget whose whole background is a progress fill.
///
/// The card is faintly tinted in [color], and a part of it fills in as far as
/// [progress] has got — round the card like a clock, as a circle growing from
/// its left edge, or along it from the left, as [mode] says. The child is drawn as it is, over the fill.
///
/// ```dart
/// ProgressCard(
///   progress: 12 / 20,
///   color: Colors.teal,
///   child: Text('Technical analysis · 12 of 20 lessons'),
/// );
/// ```
class ProgressCard extends StatelessWidget {
  /// Creates a card around [child] filled to [progress], from 0 to 1.
  const ProgressCard({
    super.key,
    required this.child,
    required this.progress,
    this.mode = ProgressCardMode.sweep,
    this.color = const Color(0xFF4C86CD),
    this.trackOpacity = 0.08,
    this.fillOpacity = 0.55,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.padding = const EdgeInsets.all(16),
    this.animationDuration = const Duration(milliseconds: 600),
    this.animationCurve = Curves.easeOutCubic,
    this.semanticLabel,
  });

  /// What the card holds.
  final Widget child;

  /// How far along the thing is, from 0 to 1. Values outside that range, and
  /// ones that are not numbers, are held to it.
  final double progress;

  /// How the background fills in: round the card, as a circle, or along it.
  final ProgressCardMode mode;

  /// What the background is painted in.
  final Color color;

  /// The opacity of [color] over the part of the card not yet filled.
  final double trackOpacity;

  /// The opacity of [color] over the part that is.
  final double fillOpacity;

  /// The rounding of the card's corners.
  final BorderRadius borderRadius;

  /// Space between the card's edge and its child.
  final EdgeInsetsGeometry padding;

  /// How long the fill takes to reach [progress], on the first build and on
  /// every change.
  final Duration animationDuration;

  /// The easing of [animationDuration].
  final Curve animationCurve;

  /// What a screen reader announces for the card.
  final String? semanticLabel;

  /// How much of the card is filled, from 0 to 1.
  double get fraction => progress.isFinite ? progress.clamp(0.0, 1.0) : 0.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticLabel,
      child: Container(
        // Clipped, so the fill takes the card's rounded corners.
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: color.withValues(alpha: trackOpacity),
          borderRadius: borderRadius,
          // A line of the full colour keeps an empty card's edge readable.
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: fraction),
          duration: animationDuration,
          curve: animationCurve,
          builder: (context, value, child) => CustomPaint(
            painter: _FillPainter(
              mode: mode,
              fraction: value,
              color: color.withValues(alpha: fillOpacity),
            ),
            child: child,
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Fills the part of the box that [fraction] of the way round, or along, is.
class _FillPainter extends CustomPainter {
  _FillPainter({
    required this.mode,
    required this.fraction,
    required this.color,
  });

  final ProgressCardMode mode;
  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (fraction <= 0 || size.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;
    if (fraction >= 1) {
      canvas.drawRect(Offset.zero & size, paint);
      return;
    }
    if (mode == ProgressCardMode.linear) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width * fraction, size.height),
        paint,
      );
      return;
    }
    if (mode == ProgressCardMode.circle) {
      // From the middle of the left edge, out to the farthest corner at 1.
      final reach = math.sqrt(
        size.width * size.width + size.height * size.height / 4,
      );
      canvas.drawCircle(Offset(0, size.height / 2), reach * fraction, paint);
      return;
    }
    // Wide enough to reach the corners, so the wedge runs edge to edge.
    final center = size.center(Offset.zero);
    final radius = math.sqrt(
      size.width * size.width + size.height * size.height,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * fraction,
      true,
      paint,
    );
  }

  @override
  bool shouldRepaint(_FillPainter old) =>
      old.mode != mode || old.fraction != fraction || old.color != color;
}
