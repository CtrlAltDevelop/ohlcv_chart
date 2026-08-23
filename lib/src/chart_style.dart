import 'package:flutter/material.dart' show Alignment, Color;

import 'trading.dart';

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
    this.profileColor,
    this.profileUpColor,
    this.profileDownColor,
    this.profilePocColor,
    this.profileValueAreaColor,
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
    this.sessionDividerColor,

    ///vertical grid lines; null derives a lighter shade of gridColor
    this.gridColumnColor,

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

  /// One colour for the whole volume profile, or null for a faint [volColor].
  ///
  /// Setting this and leaving [profileUpColor] and [profileDownColor] null
  /// draws every band whole, with no split between what rose and what fell.
  Color? profileColor;

  /// The part of a profile band that traded on rising candles.
  ///
  /// Null for [profileColor], and for a faint [upColor] if that is null too.
  Color? profileUpColor;

  /// The part of a profile band that traded on falling candles.
  ///
  /// Null for [profileColor], and for a faint [dnColor] if that is null too.
  Color? profileDownColor;

  /// Wash over the candles outside the regular session, or null for a faint
  /// [defaultTextColor].
  ///
  /// Only drawn where `KChartWidget.session` says what the regular session is.
  Color? extendedHoursColor;

  /// The colour a buy order or a long position is drawn in.
  Color buyColor = const Color(0xFF26A69A);

  /// The colour a sell order or a short position is drawn in.
  Color sellColor = const Color(0xFFEF5350);

  /// The colour each kind of event mark takes when it names none of its own.
  ///
  /// Keyed by `ChartEventKind.name`, so a kind with no entry falls back to
  /// [defaultTextColor].
  Map<String, Color> eventColors = const {
    'earnings': Color(0xFF42A5F5),
    'dividend': Color(0xFF66BB6A),
    'split': Color(0xFFAB47BC),
    'news': Color(0xFFFFA726),
    'custom': Color(0xFF90A4AE),
  };

  /// Colours the compared instruments are drawn in, taken in turn.
  ///
  /// Distinct from the moving-average palette, so a compared line reads as a
  /// second instrument rather than as another overlay.
  List<Color> comparisonColors = const [
    Color(0xFF7E57C2),
    Color(0xFF26A69A),
    Color(0xFFEF6C00),
    Color(0xFF42A5F5),
  ];

  /// Colour of the profile's busiest band, or null for [vwapColor].
  Color? profilePocColor;

  /// Wash over the value area, drawn the full width behind the candles.
  ///
  /// Null for a very faint [profilePocColor]. Set it fully transparent to
  /// leave the value area unmarked.
  Color? profileValueAreaColor;
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

  /// Colour of the vertical grid lines, which mark time.
  ///
  /// Defaults to a lighter [gridColor] when null. A chart is read across price
  /// far more than across time, so the convention is for the time columns to
  /// sit behind the price rows rather than compete with them.
  Color? gridColumnColor;

  /// [gridColumnColor], or a lighter [gridColor] if it was left null.
  Color get effectiveGridColumnColor =>
      gridColumnColor ?? gridColor.withValues(alpha: gridColor.a * 0.55);

  /// Colour of the lines marking the start of each day.
  ///
  /// Defaults to a faint [gridColor] when null.
  Color? sessionDividerColor;

  /// [sessionDividerColor], or a faint [gridColor] if it was left null.
  Color get effectiveSessionDividerColor =>
      sessionDividerColor ?? gridColor.withValues(alpha: 0.5);

  /// [axisLabelBgColor], or a translucent [bgColor] if it was left null.
  Color get effectiveAxisLabelBgColor =>
      axisLabelBgColor ?? bgColor.withValues(alpha: 0.72);

  /// [legendBgColor], or a translucent [bgColor] if it was left null.
  Color get effectiveLegendBgColor =>
      legendBgColor ?? bgColor.withValues(alpha: 0.82);

  /// [watermarkColor], or a very faint [defaultTextColor] if it was left null.
  Color get effectiveWatermarkColor =>
      watermarkColor ?? defaultTextColor.withValues(alpha: 0.07);

  /// [profileColor], or a faint [volColor] if it was left null.
  Color get effectiveProfileColor =>
      profileColor ?? volColor.withValues(alpha: 0.35);

  /// [profileUpColor], falling back to [profileColor] and then a faint
  /// [upColor].
  Color get effectiveProfileUpColor =>
      profileUpColor ?? profileColor ?? upColor.withValues(alpha: 0.35);

  /// [profileDownColor], falling back to [profileColor] and then a faint
  /// [dnColor].
  Color get effectiveProfileDownColor =>
      profileDownColor ?? profileColor ?? dnColor.withValues(alpha: 0.35);

  /// [profilePocColor], or [vwapColor] if it was left null.
  Color get effectiveProfilePocColor => profilePocColor ?? vwapColor;

  /// [profileValueAreaColor], or a very faint [effectiveProfilePocColor].
  Color get effectiveProfileValueAreaColor =>
      profileValueAreaColor ?? effectiveProfilePocColor.withValues(alpha: 0.08);

  /// Colour of the exponential moving average at [index].
  ///
  /// Shares the moving-average palette, so an `MA` and an `EMA` of the same
  /// period are drawn in the same colour.
  Color getEMAColor(int index) => getMAColor(index);

  /// [extendedHoursColor], or a faint [defaultTextColor] if it was left null.
  Color get effectiveExtendedHoursColor =>
      extendedHoursColor ?? defaultTextColor.withValues(alpha: 0.07);

  /// The colour a trade on [side] is drawn in.
  Color tradeColor(TradeSide side) =>
      side == TradeSide.buy ? buyColor : sellColor;

  /// The colour an event of [kind] is marked in.
  Color eventColor(String kind) => eventColors[kind] ?? defaultTextColor;

  /// The colour of the compared instrument at [index].
  ///
  /// A palette of its own, kept away from the moving-average colours so a
  /// compared line is never mistaken for an overlay. Set
  /// [comparisonColors] to use your own.
  Color getComparisonColor(int index) {
    final palette = comparisonColors;
    if (palette.isEmpty) return defaultTextColor;
    return palette[index % palette.length];
  }

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
    this.showSessionDividers = false,
    this.paneResizeTolerance = 6.0,
    this.paneGrabHeight = 16.0,
    this.priceScaleGripWidth = 52.0,
    this.profileWidth = 0.28,
    this.hlcAreaOpacity = 0.16,
    this.eventMarkRadius = 8.0,
    this.eventMarkGap = 4.0,
    this.trading = const TradingStyle(),
    this.minPaneHeight = 40.0,
    this.maxPaneHeight = 400.0,
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

  /// How densely the price axis is labelled and ruled.
  ///
  /// Not a row count: the axis chooses round values first — see `niceTicks` —
  /// and about `gridRows ~/ 2` of them land inside the window, so the labels
  /// read `70000, 69500, 69000` rather than whatever fell on an evenly spaced
  /// pixel. Raise it for a denser axis, lower it for a sparser one; the grid is
  /// ruled wherever the labels end up.
  final int gridRows;

  /// How densely the date axis is labelled and ruled.
  ///
  /// Read the same way as [gridRows]: the axis picks round times near this
  /// many columns, drops any label that would crowd its neighbour, and rules a
  /// vertical line at each one that survives.
  final int gridColumns;

  /// Stroke width of the grid's hairlines.
  final double gridStrokeWidth;

  /// Stroke width of the line closing off each pane.
  final double separatorWidth;

  /// Draws rising candles as outlines rather than filled bodies.
  final bool hollowUpCandles;

  /// How close to a pane's lower edge a press has to land to start resizing it.
  ///
  /// Only consulted when `KChartWidget.resizablePanes` is on.
  final double paneResizeTolerance;

  /// How tall the strip at the top of a pane is that grabs it for reordering.
  ///
  /// Only consulted when `KChartWidget.reorderablePanes` is on. It is the
  /// pane's legend row, which is why it is the part that picks the pane up.
  final double paneGrabHeight;

  /// How wide the strip down the price axis is that drags the scale.
  ///
  /// Measured in from whichever side the price labels are on, and only
  /// consulted when `KChartWidget.priceScaleDrag` is on. Wide enough to cover
  /// the labels, so what stretches the scale is the part of the chart that
  /// reads it out.
  final double priceScaleGripWidth;

  /// How solid the high-low band of a [ChartType.hlcArea] chart is.
  final double hlcAreaOpacity;

  /// How big an event mark's badge is, as its radius in logical pixels.
  ///
  /// Set it to zero to leave the marks undrawn while keeping the events on the
  /// chart for a panel of your own to list.
  final double eventMarkRadius;

  /// How far below the candles the event marks sit.
  final double eventMarkGap;

  /// How the working-order and open-position lines are drawn.
  final TradingStyle trading;

  /// How much of the chart's width a volume profile's busiest bar takes.
  ///
  /// A fraction, so the profile keeps its proportions whatever the chart is
  /// sized to. Every other bar is drawn relative to that one.
  final double profileWidth;

  /// Shortest an indicator pane may be dragged.
  final double minPaneHeight;

  /// Tallest an indicator pane may be dragged.
  final double maxPaneHeight;

  /// Marks the start of each day with a vertical line.
  ///
  /// What tells one session from the next on an intraday chart, where the date
  /// only appears every few axis labels. Drawn in
  /// [ChartColors.sessionDividerColor], in the time zone the chart is showing —
  /// see `KChartWidget.timeZoneOffset`.
  final bool showSessionDividers;

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

  /// Returns a copy with the given fields replaced.
  ChartStyle copyWith({
    double? topPadding,
    double? bottomPadding,
    double? childPadding,
    double? pointWidth,
    double? candleWidth,
    double? candleLineWidth,
    double? volWidth,
    double? macdWidth,
    double? indicatorLineWidth,
    double? vCrossWidth,
    double? hCrossWidth,
    double? crossDashLength,
    double? crossDashGap,
    double? nowPriceLineLength,
    double? nowPriceLineSpan,
    double? nowPriceLineWidth,
    bool? nowPriceDashed,
    int? gridRows,
    int? gridColumns,
    double? gridStrokeWidth,
    double? separatorWidth,
    bool? hollowUpCandles,
    bool? showSessionDividers,
    double? paneResizeTolerance,
    double? paneGrabHeight,
    double? priceScaleGripWidth,
    double? profileWidth,
    double? hlcAreaOpacity,
    double? eventMarkRadius,
    double? eventMarkGap,
    TradingStyle? trading,
    double? minPaneHeight,
    double? maxPaneHeight,
    bool? axisLabelBackground,
    double? axisLabelPadding,
    double? labelCornerRadius,
    double? legendPadding,
    double? legendSpacing,
    Alignment? watermarkAlignment,
    double? watermarkScale,
    List<String>? dateTimeFormat,
  }) {
    return ChartStyle(
      topPadding: topPadding ?? this.topPadding,
      bottomPadding: bottomPadding ?? this.bottomPadding,
      childPadding: childPadding ?? this.childPadding,
      pointWidth: pointWidth ?? this.pointWidth,
      candleWidth: candleWidth ?? this.candleWidth,
      candleLineWidth: candleLineWidth ?? this.candleLineWidth,
      volWidth: volWidth ?? this.volWidth,
      macdWidth: macdWidth ?? this.macdWidth,
      indicatorLineWidth: indicatorLineWidth ?? this.indicatorLineWidth,
      vCrossWidth: vCrossWidth ?? this.vCrossWidth,
      hCrossWidth: hCrossWidth ?? this.hCrossWidth,
      crossDashLength: crossDashLength ?? this.crossDashLength,
      crossDashGap: crossDashGap ?? this.crossDashGap,
      nowPriceLineLength: nowPriceLineLength ?? this.nowPriceLineLength,
      nowPriceLineSpan: nowPriceLineSpan ?? this.nowPriceLineSpan,
      nowPriceLineWidth: nowPriceLineWidth ?? this.nowPriceLineWidth,
      nowPriceDashed: nowPriceDashed ?? this.nowPriceDashed,
      gridRows: gridRows ?? this.gridRows,
      gridColumns: gridColumns ?? this.gridColumns,
      gridStrokeWidth: gridStrokeWidth ?? this.gridStrokeWidth,
      separatorWidth: separatorWidth ?? this.separatorWidth,
      hollowUpCandles: hollowUpCandles ?? this.hollowUpCandles,
      showSessionDividers: showSessionDividers ?? this.showSessionDividers,
      paneResizeTolerance: paneResizeTolerance ?? this.paneResizeTolerance,
      paneGrabHeight: paneGrabHeight ?? this.paneGrabHeight,
      priceScaleGripWidth: priceScaleGripWidth ?? this.priceScaleGripWidth,
      profileWidth: profileWidth ?? this.profileWidth,
      hlcAreaOpacity: hlcAreaOpacity ?? this.hlcAreaOpacity,
      eventMarkRadius: eventMarkRadius ?? this.eventMarkRadius,
      eventMarkGap: eventMarkGap ?? this.eventMarkGap,
      trading: trading ?? this.trading,
      minPaneHeight: minPaneHeight ?? this.minPaneHeight,
      maxPaneHeight: maxPaneHeight ?? this.maxPaneHeight,
      axisLabelBackground: axisLabelBackground ?? this.axisLabelBackground,
      axisLabelPadding: axisLabelPadding ?? this.axisLabelPadding,
      labelCornerRadius: labelCornerRadius ?? this.labelCornerRadius,
      legendPadding: legendPadding ?? this.legendPadding,
      legendSpacing: legendSpacing ?? this.legendSpacing,
      watermarkAlignment: watermarkAlignment ?? this.watermarkAlignment,
      watermarkScale: watermarkScale ?? this.watermarkScale,
      dateTimeFormat: dateTimeFormat ?? this.dateTimeFormat,
    );
  }
}
