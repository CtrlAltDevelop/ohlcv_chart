import 'package:flutter/material.dart' show Color;

/// Every colour the depth chart paints with.
class DepthChartColors {
  /// Creates a colour set, defaulting to a light theme.
  const DepthChartColors({
    ///depth color
    this.upColor = const Color(0xFF14AD8F),
    this.upFillPathColor = const Color(0x2314AD8F),
    this.dnColor = const Color(0xFFD5405D),
    this.dnFillPathColor = const Color(0x23D5405D),

    ///value border color after selection
    this.selectBorderColor = const Color(0xFF909196),

    ///background color when value selected
    this.selectFillColor = const Color(0xFFFFFFFF),

    ///color of annotation content
    this.defaultTextColor = const Color(0xFF909196),
    this.annotationColor = const Color(0xFF222223),
    this.crossColor = const Color(0xFF191919),
    this.barrierColor = const Color(0x21AFAFAF),
  });

  /// depth color
  final Color upColor;
  final Color upFillPathColor;
  final Color dnColor;
  final Color dnFillPathColor;

  /// default text color: apply for text at grid
  final Color defaultTextColor;

  ///value border color after selection
  final Color selectBorderColor;

  ///background color when value selected
  final Color selectFillColor;

  ///color of annotation content
  final Color annotationColor;

  ///color of cross dash line
  final Color crossColor;

  /// barrier color
  final Color barrierColor;
}

/// Geometry of the depth chart: stroke widths, paddings and text sizes.
class DepthChartStyle {
  /// Creates a style, defaulting to the values the chart ships with.
  const DepthChartStyle({
    this.lineWidth = 1.0,
    this.radius = 4.0,
    this.strokeWidth = 0.6,
    this.space = 2.0,
    this.padding = 6.0,
    this.dotRadius = 5.0,
    this.crossWidth = 0.5,
    this.barWidthFactor = 0.7,
    this.ladderRowHeight = 22,
    this.ladderFontSize = 11,
  });

  final double lineWidth;
  final double radius;
  final double strokeWidth;

  final double space;
  final double padding;

  final double dotRadius;

  final double crossWidth;

  /// How much of each level's slot a histogram bar fills, from 0 to 1.
  final double barWidthFactor;

  /// Height of one row of the ladder.
  final double ladderRowHeight;

  /// Text size used by the ladder.
  final double ladderFontSize;
}
