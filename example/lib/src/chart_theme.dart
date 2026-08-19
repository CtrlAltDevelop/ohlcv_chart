import 'package:flutter/material.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

/// Ready-made palettes and geometries, showing how far `ChartColors`,
/// `ChartStyle` and `DrawingStyle` can be pushed without touching the package.
class ChartTheme {
  const ChartTheme._();

  /// A dark "terminal" palette.
  static ChartColors darkColors() => ChartColors(
    bgColor: const Color(0xFF10141A),
    gridColor: const Color(0xFF1E2530),
    separatorColor: const Color(0xFF2A3340),
    defaultTextColor: const Color(0xFF8A93A3),
    upColor: const Color(0xFF26A69A),
    dnColor: const Color(0xFFEF5350),
    volColor: const Color(0xFF4C6884),
    ma5Color: const Color(0xFFF5C26B),
    ma10Color: const Color(0xFF4DD0E1),
    ma30Color: const Color(0xFFB39DDB),
    nowPriceUpColor: const Color(0xFF26A69A),
    nowPriceDnColor: const Color(0xFFEF5350),
    nowPriceTextColor: const Color(0xFF0B0E13),
    maxColor: const Color(0xFFB6BFCC),
    minColor: const Color(0xFFB6BFCC),
    crossTextColor: const Color(0xFFE8ECF2),
    hCrossColor: const Color(0xFF9FB0C4),
    vCrossColor: const Color(0x33FFFFFF),
    selectFillColor: const Color(0xFF1A222C),
    selectBorderColor: const Color(0xFF3A4656),
    infoWindowNormalColor: const Color(0xFFE8ECF2),
    infoWindowTitleColor: const Color(0xFF8A93A3),
    infoWindowUpColor: const Color(0xFF26A69A),
    infoWindowDnColor: const Color(0xFFEF5350),
    sarColor: const Color(0xFFF5C26B),
  );

  /// A light palette, close to the package defaults but a little softer.
  static ChartColors lightColors() => ChartColors(
    bgColor: const Color(0xFFFCFCFD),
    gridColor: const Color(0xFFE7E9EF),
    separatorColor: const Color(0xFFD8DCE5),
    defaultTextColor: const Color(0xFF6B7280),
    upColor: const Color(0xFF16A085),
    dnColor: const Color(0xFFE04F5F),
    volColor: const Color(0xFF9AAFC4),
    nowPriceUpColor: const Color(0xFF16A085),
    nowPriceDnColor: const Color(0xFFE04F5F),
    nowPriceTextColor: const Color(0xFFFFFFFF),
    maxColor: const Color(0xFF4B5563),
    minColor: const Color(0xFF4B5563),
    crossTextColor: const Color(0xFF1F2937),
    hCrossColor: const Color(0xFF6B7280),
    vCrossColor: const Color(0x22000000),
    selectFillColor: const Color(0xFFFFFFFF),
    selectBorderColor: const Color(0xFFCBD2DE),
    infoWindowNormalColor: const Color(0xFF1F2937),
    infoWindowTitleColor: const Color(0xFF6B7280),
  );

  /// Filled candles on a dense grid.
  static const ChartStyle filled = ChartStyle();

  /// Hollow rising candles, a sparser grid and wider spacing — the look most
  /// desktop terminals use.
  static const ChartStyle hollow = ChartStyle(
    hollowUpCandles: true,
    gridRows: 5,
    gridColumns: 4,
    pointWidth: 10,
    candleWidth: 7,
    candleLineWidth: 1.2,
  );

  /// The line editor with the package defaults.
  static const DrawingStyle defaultDrawing = DrawingStyle();

  /// A compact vertical editor with a house palette.
  static const DrawingStyle brandedDrawing = DrawingStyle(
    colorOptions: [
      Color(0xFF4DABF7),
      Color(0xFF26A69A),
      Color(0xFFF5C26B),
      Color(0xFFEF5350),
      Color(0xFFB39DDB),
      Color(0xFFFFFFFF),
    ],
    thicknessOptions: [1, 2, 3, 5],
    swatchesPerRow: 3,
    toolbarAxis: Axis.vertical,
    toolbarBorderRadius: 18,
    toolbarInitialOffset: Offset(12, 28),
    accentColor: Color(0xFF4DABF7),
    iconSize: 18,
    handleRadius: 7,
    hitTestTolerance: 24,
  );

  /// Depth-chart colours matched to [darkColors].
  static const DepthChartColors darkDepth = DepthChartColors(
    upColor: Color(0xFF26A69A),
    upFillPathColor: Color(0x3326A69A),
    dnColor: Color(0xFFEF5350),
    dnFillPathColor: Color(0x33EF5350),
    defaultTextColor: Color(0xFF8A93A3),
    annotationColor: Color(0xFFE8ECF2),
    crossColor: Color(0xFF9FB0C4),
    selectBorderColor: Color(0xFF3A4656),
    selectFillColor: Color(0xFF1A222C),
    barrierColor: Color(0x22FFFFFF),
  );

  /// Depth-chart colours matched to [lightColors].
  static const DepthChartColors lightDepth = DepthChartColors(
    upColor: Color(0xFF16A085),
    upFillPathColor: Color(0x2216A085),
    dnColor: Color(0xFFE04F5F),
    dnFillPathColor: Color(0x22E04F5F),
    defaultTextColor: Color(0xFF6B7280),
    annotationColor: Color(0xFF1F2937),
    crossColor: Color(0xFF6B7280),
  );
}
