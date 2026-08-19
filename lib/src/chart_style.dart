import 'package:flutter/material.dart' show Alignment, Color;

/// ChartColors
///
/// Note:
/// If you need to apply multi theme, you need to change at least the colors related to the text, border and background color
/// Ex:
/// Background: bgColor, selectFillColor
/// Border
/// Text
///
class ChartColors {
  /// Creates a colour set, defaulting to a light theme.
  ChartColors({
    this.bgColor = const Color(0xffffffff),
    this.kLineColor = const Color(0xff4C86CD),

    ///
    this.lineFillColor = const Color(0x554C86CD),

    ///
    this.lineFillInsideColor = const Color(0x00000000),

    ///
    this.ma5Color = const Color(0xffE5B767),
    this.ma10Color = const Color(0xff1FD1AC),
    this.ma30Color = const Color(0xffB48CE3),
    this.upColor = const Color(0xFF14AD8F),
    this.dnColor = const Color(0xFFD5405D),
    this.volColor = const Color(0xff2f8fd5),
    this.macdColor = const Color(0xff2f8fd5),
    this.difColor = const Color(0xffE5B767),
    this.deaColor = const Color(0xff1FD1AC),
    this.kColor = const Color(0xffE5B767),
    this.dColor = const Color(0xff1FD1AC),
    this.jColor = const Color(0xffB48CE3),
    this.rsiColor = const Color(0xffE5B767),
    this.vwapColor = const Color(0xFF7E57C2),
    this.atrColor = const Color(0xff2f8fd5),
    this.obvColor = const Color(0xff1FD1AC),
    this.mfiColor = const Color(0xffE5B767),
    this.pdiColor = const Color(0xFF14AD8F),
    this.mdiColor = const Color(0xFFD5405D),
    this.adxColor = const Color(0xffE5B767),
    this.keltnerColor = const Color(0xff2f8fd5),
    this.donchianColor = const Color(0xffB48CE3),
    this.conversionColor = const Color(0xff2f8fd5),
    this.baseColor = const Color(0xffD5405D),
    this.spanAColor = const Color(0xff14AD8F),
    this.spanBColor = const Color(0xffE5B767),
    this.laggingColor = const Color(0xffB48CE3),
    this.stochRsiColor = const Color(0xffE5B767),
    this.rocColor = const Color(0xff2f8fd5),
    this.trixColor = const Color(0xff1FD1AC),
    this.volumeMaColor = const Color(0xffE5B767),
    this.awesomeColor = const Color(0xff2f8fd5),
    this.zigzagColor = const Color(0xffB48CE3),
    this.fibonacciColor = const Color(0xffE5B767),
    this.waveColor = const Color(0xff7E57C2),
    this.defaultTextColor = const Color(0xFF909196),
    this.nowPriceUpColor = const Color(0xFF14AD8F),
    this.nowPriceDnColor = const Color(0xFFD5405D),
    this.nowPriceTextColor = const Color(0xffffffff),
    this.sarColor = const Color(0xffE5B767),
    this.avgColor = const Color(0xff82878e),

    /// trend color
    this.trendLineColor = const Color(0xFFF89215),

    ///value border color after selection
    this.selectBorderColor = const Color(0xFF222223),

    ///background color when value selected
    this.selectFillColor = const Color(0xffffffff),

    ///color of grid
    this.gridColor = const Color(0xFFD1D3DB),

    ///color of annotation content
    this.infoWindowNormalColor = const Color(0xFF222223),
    this.infoWindowTitleColor = const Color(0xFF4D4D4E), //0xFF707070
    this.infoWindowUpColor = const Color(0xFF14AD8F),
    this.infoWindowDnColor = const Color(0xFFD5405D),
    this.hCrossColor = const Color(0xFF222223),
    this.vCrossColor = const Color(0x28424652),
    this.crossTextColor = const Color(0xFF222223),

    ///The color of the maximum and minimum values in the current display
    this.maxColor = const Color(0xFF222223),
    this.minColor = const Color(0xFF222223),

    ///line between the main chart and each pane below it
    this.separatorColor,

    ///pill painted behind the price axis labels; null derives it from bgColor
    this.axisLabelBgColor,

    ///pill painted behind the indicator legends; null derives it from bgColor
    this.legendBgColor,

    ///tint of the watermark; null derives it from defaultTextColor
    this.watermarkColor,
  });

  /// the background color of base chart
  Color bgColor;

  Color kLineColor;

  ///
  Color lineFillColor;

  ///
  Color lineFillInsideColor;

  /// color: ma5, ma10, ma30, up, down, vol, macd, diff, dea, k, d, j, rsi
  Color ma5Color;
  Color ma10Color;
  Color ma30Color;
  Color upColor;
  Color dnColor;
  Color volColor;

  Color macdColor;
  Color difColor;
  Color deaColor;

  Color kColor;
  Color dColor;
  Color jColor;
  Color rsiColor;

  /// Volume-weighted average price line on the main chart.
  Color vwapColor;

  /// Average true range line.
  Color atrColor;

  /// On-balance volume line.
  Color obvColor;

  /// Money flow index line.
  Color mfiColor;

  /// Positive directional indicator line.
  Color pdiColor;

  /// Negative directional indicator line.
  Color mdiColor;

  /// Average directional index line.
  Color adxColor;

  /// Keltner channel bands; the midline uses the moving-average palette.
  Color keltnerColor;

  /// Donchian channel bands.
  Color donchianColor;

  /// Ichimoku conversion line (tenkan-sen).
  Color conversionColor;

  /// Ichimoku base line (kijun-sen).
  Color baseColor;

  /// Ichimoku leading span A.
  Color spanAColor;

  /// Ichimoku leading span B.
  Color spanBColor;

  /// Ichimoku lagging span (chikou).
  Color laggingColor;

  /// Stochastic RSI %K line; %D takes the [dColor] of the KDJ palette.
  Color stochRsiColor;

  /// Rate-of-change line.
  Color rocColor;

  /// TRIX line; its signal takes [deaColor].
  Color trixColor;

  /// Moving average of volume.
  Color volumeMaColor;

  /// Awesome oscillator bars, where they are not coloured by direction.
  Color awesomeColor;

  /// Zigzag swing line.
  Color zigzagColor;

  /// Fibonacci retracement levels.
  Color fibonacciColor;

  /// Elliott wave labels.
  Color waveColor;

  Color sarColor;
  Color avgColor;

  /// default text color: apply for text at grid
  Color defaultTextColor;

  /// color of the current price
  Color nowPriceUpColor;
  Color nowPriceDnColor;
  Color nowPriceTextColor;

  /// trend color
  Color trendLineColor;

  ///value border color after selection
  Color selectBorderColor;

  ///background color when value selected
  Color selectFillColor;

  ///color of grid
  Color gridColor;

  ///color of annotation content
  Color infoWindowNormalColor;
  Color infoWindowTitleColor;
  Color infoWindowUpColor;
  Color infoWindowDnColor;

  /// color of the horizontal cross line
  Color hCrossColor;

  /// color of the vertical cross line
  Color vCrossColor;

  /// text color
  Color crossTextColor;

  ///The color of the maximum and minimum values in the current display
  Color maxColor;
  Color minColor;

  /// Line drawn between the main chart and each pane below it.
  ///
  /// Defaults to [gridColor] when null.
  Color? separatorColor;

  /// Fill of the pill painted behind the price axis labels.
  ///
  /// Defaults to a translucent [bgColor] when null, which keeps the labels
  /// readable where they cross candles. Fully transparent removes the pill.
  Color? axisLabelBgColor;

  /// Fill of the pill painted behind the indicator legends.
  ///
  /// Defaults to a translucent [bgColor] when null.
  Color? legendBgColor;

  /// Tint of the SVG watermark.
  ///
  /// Defaults to a very faint [defaultTextColor] when null.
  Color? watermarkColor;

  /// [separatorColor], or [gridColor] if it was left null.
  Color get effectiveSeparatorColor => separatorColor ?? gridColor;

  /// [axisLabelBgColor], or a translucent [bgColor] if it was left null.
  Color get effectiveAxisLabelBgColor =>
      axisLabelBgColor ?? bgColor.withValues(alpha: 0.72);

  /// [legendBgColor], or a translucent [bgColor] if it was left null.
  Color get effectiveLegendBgColor =>
      legendBgColor ?? bgColor.withValues(alpha: 0.82);

  /// [watermarkColor], or a very faint [defaultTextColor] if it was left null.
  Color get effectiveWatermarkColor =>
      watermarkColor ?? defaultTextColor.withValues(alpha: 0.07);

  /// Colour of the exponential moving average at [index].
  ///
  /// Shares the moving-average palette, so an `MA` and an `EMA` of the same
  /// period are drawn in the same colour.
  Color getEMAColor(int index) => getMAColor(index);

  /// get MA color via index
  Color getMAColor(int index) {
    switch (index % 3) {
      case 1:
        return ma10Color;
      case 2:
        return ma30Color;
      default:
        return ma5Color;
    }
  }
}

/// Geometry of the candlestick chart: paddings, stroke widths, gaps and
/// text sizes.
class ChartStyle {
  /// Creates a style, defaulting to the values the chart ships with.
  const ChartStyle({
    this.topPadding = 20.0,
    this.bottomPadding = 20.0,
    this.childPadding = 12.0,
    this.pointWidth = 8,
    this.candleWidth = 6,
    this.candleLineWidth = 1.0,
    this.volWidth = 6,
    this.macdWidth = 1.5,
    this.indicatorLineWidth = 1.0,
    this.vCrossWidth = 0.8,
    this.hCrossWidth = 0.8,
    this.crossDashLength = 5.0,
    this.crossDashGap = 4.0,
    this.nowPriceLineLength = 4.5,
    this.nowPriceLineSpan = 3.5,
    this.nowPriceLineWidth = 1,
    this.nowPriceDashed = true,
    this.gridRows = 8,
    this.gridColumns = 4,
    this.gridStrokeWidth = 0.5,
    this.separatorWidth = 1.0,
    this.hollowUpCandles = false,
    this.axisLabelBackground = true,
    this.axisLabelPadding = 4.0,
    this.labelCornerRadius = 3.0,
    this.legendPadding = 4.0,
    this.legendSpacing = 2.0,
    this.watermarkAlignment = Alignment.center,
    this.watermarkScale = 0.36,
    this.dateTimeFormat,
  });

  final double topPadding;
  final double bottomPadding;
  final double childPadding;

  ///point-to-point distance
  final double pointWidth;

  ///candle width
  final double candleWidth;
  final double candleLineWidth;

  ///vol column width
  final double volWidth;

  ///macd column width
  final double macdWidth;

  /// Stroke width of an indicator's lines, in a pane or over the candles.
  final double indicatorLineWidth;

  ///vertical-horizontal cross line width
  final double vCrossWidth;
  final double hCrossWidth;

  /// Length of one dash of the crosshair.
  final double crossDashLength;

  /// Gap between the crosshair's dashes; 0 draws it solid.
  final double crossDashGap;

  ///(line length - space line - thickness) of the current price
  final double nowPriceLineLength;
  final double nowPriceLineSpan;
  final double nowPriceLineWidth;

  /// Draws the "now price" line dashed rather than solid.
  final bool nowPriceDashed;

  final int gridRows;
  final int gridColumns;

  /// Stroke width of the grid's hairlines.
  final double gridStrokeWidth;

  /// Stroke width of the line closing off each pane.
  final double separatorWidth;

  /// Draws rising candles as outlines rather than filled bodies.
  final bool hollowUpCandles;

  /// Paints a pill behind the price axis labels so they stay readable where
  /// they cross the candles.
  final bool axisLabelBackground;

  /// Space between the chart edge and the price axis labels.
  final double axisLabelPadding;

  /// Corner radius of the axis label and legend pills.
  final double labelCornerRadius;

  /// Space between an indicator legend's pill and its text.
  final double legendPadding;

  /// Vertical gap between stacked indicator legends.
  final double legendSpacing;

  /// Where the watermark sits inside the main chart area.
  final Alignment watermarkAlignment;

  /// Watermark width as a fraction of the main chart's shorter side.
  final double watermarkScale;

  ///customize the time below
  final List<String>? dateTimeFormat;
}
