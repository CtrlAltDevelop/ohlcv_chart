import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../chart_type.dart';
import '../comparison.dart';
import '../drawing/line_painting.dart';
import '../entity/candle_entity.dart';
import '../entity/k_line_entity.dart';
import '../entity/line.dart';
import '../indicators/resolved_indicator.dart';
import '../price_axis_scale.dart';
import '../utils/axis_ticks.dart';
import 'base_chart_renderer.dart';
import 'path_batch.dart';
import 'series_painter.dart';

/// Which side of the main chart the price axis labels sit on.
enum VerticalTextAlignment {
  /// Labels are drawn against the left edge.
  left,

  /// Labels are drawn against the right edge.
  right,
}

//For TrendLine
double? trendLineMax;
double? trendLineScale;
double? trendLineContentRec;

class MainRenderer extends BaseChartRenderer<CandleEntity> {
  MainRenderer(
    Rect mainRect,
    double maxValue,
    double minValue,
    double topPadding,
    this.overlays,
    this.isLine,
    int fixedLength,
    this.chartStyle,
    this.chartColors,
    this.scaleX,
    this.verticalTextAlignment,
    this.hasPanesBelow, {
    this.comparisons = const <ResolvedComparison>[],
    this.comparisonAnchors = const <ComparisonAnchor?>[],
    this.priceScale = PriceAxisScale.linear,
    this.percentBase,
    this.chartType = ChartType.candles,
    this.baselinePrice,
    this.inverted = false,
    this.averageClose,
    this.candleColor,
    super.priceAxisGutter = 0.0,
    super.priceAxisGutterOnLeft = false,
  }) : super(
         chartRect: mainRect,
         maxValue: maxValue,
         minValue: minValue,
         topPadding: topPadding,
         fixedLength: fixedLength,
         gridColor: chartColors.gridColor,
         separatorColor: chartColors.effectiveSeparatorColor,
         gridColumnColor: chartColors.effectiveGridColumnColor,
         gridStrokeWidth: chartStyle.gridStrokeWidth,
         separatorWidth: chartStyle.separatorWidth,
         labelCornerRadius: chartStyle.labelCornerRadius,
         legendPadding: chartStyle.legendPadding,
         legendBgColor: chartColors.effectiveLegendBgColor,
       ) {
    mCandleWidth = chartStyle.candleWidth;
    mCandleLineWidth = chartStyle.candleLineWidth;
    mLinePaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = mLineStrokeWidth
      ..color = chartColors.kLineColor;
    _contentRect = Rect.fromLTRB(
      chartRect.left,
      chartRect.top + _contentPadding,
      chartRect.right,
      chartRect.bottom - _contentPadding,
    );
    if (maxValue == minValue) {
      maxValue *= 1.5;
      minValue /= 2;
    }
    scaleY = _contentRect.height / (maxValue - minValue);

    // The axis is drawn in transformed space — prices for a linear axis, their
    // logarithms for a logarithmic one — so one scale factor covers both.
    _transformedMax = _transform(maxValue);
    final span = _transformedMax - _transform(minValue);
    _transformedScaleY = span <= 0 ? scaleY : _contentRect.height / span;
  }

  /// Compared instruments drawn over the candles, lined up with them.
  final List<ResolvedComparison> comparisons;

  /// Where each comparison is pinned to the main series, in the same order.
  final List<ComparisonAnchor?> comparisonAnchors;

  /// What the candle area draws for each candle.
  final ChartType chartType;

  /// The level a [ChartType.baseline] chart is washed towards.
  final double? baselinePrice;

  /// How the price axis spaces its values.
  final PriceAxisScale priceScale;

  /// The close a [PriceAxisScale.percentage] axis measures against, which is
  /// the first candle in view.
  final double? percentBase;

  /// A colour of your own for the bar at an index, or null for the usual one.
  ///
  /// Asked about every candle, bar and column drawn, so a bar can be picked out
  /// for whatever reason the caller has — inside a session, above an average,
  /// part of a pattern.
  final Color? Function(CandleEntity candle, int index)? candleColor;

  /// Whether the axis runs the other way, with higher prices lower down.
  final bool inverted;

  /// The average close over the visible window, drawn as a level.
  ///
  /// Null when the chart is not showing one.
  final double? averageClose;

  late final double _transformedMax;
  late final double _transformedScaleY;

  /// Whether prices really are spaced by ratio.
  ///
  /// A window holding zero or a negative price has no logarithm to space by, so
  /// it falls back to a linear axis rather than drawing nothing.
  bool get isLogarithmic =>
      priceScale == PriceAxisScale.logarithmic && minValue > 0;

  double _transform(double price) =>
      isLogarithmic ? math.log(price <= 0 ? _logFloor : price) : price;

  double _untransform(double value) => isLogarithmic ? math.exp(value) : value;

  /// Stands in for a price a logarithm cannot take.
  static const double _logFloor = 1e-9;

  /// Formats [price] the way the axis reads it.
  ///
  /// A percentage axis shows the move away from [percentBase] and an indexed one
  /// shows it with that base at 100; every other axis shows the price itself.
  String formatAxis(double price) {
    final base = percentBase;
    if (base == null || base == 0) return format(price);

    return switch (priceScale) {
      PriceAxisScale.percentage => () {
        final move = (price / base - 1) * 100;
        return '${move >= 0 ? '+' : ''}${move.toStringAsFixed(2)}%';
      }(),
      PriceAxisScale.indexedTo100 => (price / base * 100).toStringAsFixed(2),
      _ => format(price),
    };
  }

  late double mCandleWidth;
  late double mCandleLineWidth;

  /// Indicators drawn over the candles, with their values.
  List<ResolvedIndicator> overlays;
  bool isLine;

  // The content area to be drawn
  late Rect _contentRect;
  final _contentPadding = 5.0;
  final ChartStyle chartStyle;
  final ChartColors chartColors;
  final double mLineStrokeWidth = 1.0;
  double scaleX;
  late Paint mLinePaint;
  final VerticalTextAlignment verticalTextAlignment;

  /// Whether a volume or indicator pane is stacked under the main chart.
  ///
  /// When one is, the bottom-most price label is left out: it would sit on that
  /// pane's own legend, and the low of the range is already marked on the
  /// candle that set it.
  final bool hasPanesBelow;

  /// Draws the overlay legends, one row per kind of indicator.
  ///
  /// Repeated averages share a row — `MA5 MA10 MA20` reads as one line — while
  /// a different indicator starts a new one. [startRow] leaves room above for
  /// rows someone else has already taken, such as the OHLC legend.
  void drawLegends(Canvas canvas, int index, double x, {int startRow = 0}) {
    // The comparisons take a row of their own, above the indicators, and are
    // read out whether or not the main series is drawn as a line.
    if (comparisons.isNotEmpty) {
      drawComparisonLegend(canvas, index, x, startRow);
      startRow++;
    }
    if (isLine) return;

    final rows = <String, List<InlineSpan>>{};
    for (final overlay in overlays) {
      final spans = rows.putIfAbsent(overlay.indicator.group, () => []);
      for (var line = 0; line < overlay.indicator.lines.length; line++) {
        final value = overlay.valueAt(line, index);
        if (value == null || !value.isFinite) continue;
        spans.add(
          TextSpan(
            text:
                '${overlay.indicator.lines[line].label}:'
                '${format(value)}    ',
            style: getTextStyle(overlay.colorFor(line, chartColors)),
          ),
        );
      }
    }

    var row = startRow;
    for (final spans in rows.values) {
      if (spans.isEmpty) continue;
      final tp = TextPainter(
        text: TextSpan(children: spans),
        textDirection: TextDirection.ltr,
      )..layout();
      paintLegend(
        canvas,
        tp,
        Offset(
          x,
          chartRect.top -
              topPadding +
              row * (tp.height + chartStyle.legendSpacing),
        ),
      );
      row++;
    }
  }

  /// Draws the average close over the window, as a level across the chart.
  ///
  /// What the market has been worth on average over what is on screen, which is
  /// the level a mean-reversion read is taken against. Panning moves it, since
  /// it describes the window rather than the whole history.
  void drawAverageClose(Canvas canvas, Size size) {
    final average = averageClose;
    if (average == null) return;

    final y = getY(average);
    if (y < chartRect.top || y > chartRect.bottom) return;

    paintStyledLine(
      canvas,
      Offset(chartRect.left, y),
      Offset(size.width, y),
      Paint()
        ..color = chartColors.avgColor
        ..strokeWidth = chartStyle.gridStrokeWidth * 2
        ..isAntiAlias = true,
      style: LineStyle.dashed,
      dashLength: 4,
      dashGap: 4,
    );
  }

  /// Draws each compared instrument as a line across the visible candles.
  ///
  /// A rebased comparison is pinned to the main series at the left edge of the
  /// window, so the two lines start together and diverge by how differently
  /// they moved. One on its own price scale is simply drawn where its prices
  /// fall.
  void drawComparisons(
    Canvas canvas, {
    required int start,
    required int stop,
    required double Function(int index) xOf,
  }) {
    if (comparisons.isEmpty) return;

    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(
        chartRect.left,
        chartRect.top - topPadding,
        chartRect.right,
        chartRect.bottom,
      ),
    );

    for (final (ordinal, comparison) in comparisons.indexed) {
      final anchor = ordinal < comparisonAnchors.length
          ? comparisonAnchors[ordinal]
          : null;
      final paint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = comparison.series.thickness
        ..color = colorOfComparison(comparison);

      Offset? previous;
      for (var i = start; i <= stop; i++) {
        final price = comparisonPriceAt(comparison, i, anchor);
        if (price == null) {
          // A gap in the compared series breaks the line rather than joining
          // across it.
          previous = null;
          continue;
        }
        final at = Offset(xOf(i), getY(price));
        if (previous != null) {
          paintStyledLine(
            canvas,
            previous,
            at,
            paint,
            style: comparison.series.style,
          );
        }
        previous = at;
      }
    }
    canvas.restore();
  }

  /// The colour [comparison] is drawn in.
  ///
  /// Its own where it was given one, and otherwise the next of the chart's
  /// comparison palette, so two comparisons never come out the same colour by
  /// accident.
  Color colorOfComparison(ResolvedComparison comparison) =>
      comparison.series.color ??
      chartColors.getComparisonColor(comparison.ordinal);

  /// Reads out each compared instrument: its name and how far it has moved.
  ///
  /// The move is measured from where the comparison is pinned, which is the left
  /// edge of the window — so it says what a reader of the two lines can see.
  void drawComparisonLegend(Canvas canvas, int index, double x, int row) {
    if (comparisons.isEmpty) return;

    final spans = <InlineSpan>[];
    for (final (ordinal, comparison) in comparisons.indexed) {
      final anchor = ordinal < comparisonAnchors.length
          ? comparisonAnchors[ordinal]
          : null;
      final value = comparison.valueAt(index);
      if (value == null || !value.isFinite) continue;

      final move = anchor == null ? null : (value / anchor.value - 1) * 100;
      final text = move == null
          ? '${comparison.series.label}:${format(value)}'
          : '${comparison.series.label}:'
                '${move >= 0 ? '+' : ''}${move.toStringAsFixed(2)}%';
      spans.add(
        TextSpan(
          text: '$text    ',
          style: getTextStyle(colorOfComparison(comparison)),
        ),
      );
    }
    if (spans.isEmpty) return;

    final tp = TextPainter(
      text: TextSpan(children: spans),
      textDirection: TextDirection.ltr,
    )..layout();
    paintLegend(
      canvas,
      tp,
      Offset(
        x,
        chartRect.top -
            topPadding +
            row * (tp.height + chartStyle.legendSpacing),
      ),
    );
  }

  /// Draws every overlay's lines and dots across the visible candles.
  void drawOverlays(
    Canvas canvas,
    List<KLineEntity> candles, {
    required int start,
    required int stop,
    required double Function(int index) xOf,
  }) {
    if (isLine || overlays.isEmpty) return;

    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(
        chartRect.left,
        chartRect.top - topPadding,
        chartRect.right,
        chartRect.bottom,
      ),
    );
    for (final overlay in overlays) {
      paintIndicatorSeries(
        canvas,
        resolved: overlay,
        candles: candles,
        start: start,
        stop: stop,
        xOf: xOf,
        yOf: getY,
        colors: chartColors,
        strokeWidth: chartStyle.indicatorLineWidth,
        barWidth: chartStyle.candleWidth,
      );
    }
    canvas.restore();
  }

  /// Draws every overlay's volume profile, behind the candles.
  ///
  /// The bars run in from the far side of the chart — the side the price
  /// labels are not on — so they sit behind the newest candles rather than
  /// over the ones being read. Each is as long as its share of the busiest
  /// band, split into the volume that traded on rising candles and the volume
  /// that traded on falling ones, with the point of control picked out and the
  /// value area shaded across the whole width.
  void drawProfiles(Canvas canvas) {
    for (final overlay in overlays) {
      final profile = overlay.profile;
      if (profile == null || profile.isEmpty) continue;

      final peak = profile.peakVolume;
      final widest = chartRect.width * chartStyle.profileWidth.clamp(0.0, 1.0);
      final fromLeft = verticalTextAlignment == VerticalTextAlignment.right;
      final up = Paint()
        ..isAntiAlias = true
        ..color = chartColors.effectiveProfileUpColor;
      final down = Paint()
        ..isAntiAlias = true
        ..color = chartColors.effectiveProfileDownColor;
      final pocPaint = Paint()
        ..isAntiAlias = true
        ..color = overlay.colorFor(0, chartColors);

      final areaTop = profile.valueAreaHigh;
      final areaBottom = profile.valueAreaLow;
      if (areaTop != null && areaBottom != null) {
        canvas.drawRect(
          Rect.fromLTRB(
            chartRect.left,
            getY(areaTop),
            chartRect.right,
            getY(areaBottom),
          ),
          Paint()..color = chartColors.effectiveProfileValueAreaColor,
        );
      }

      for (var i = 0; i < profile.bins.length; i++) {
        final bin = profile.bins[i];
        if (bin.volume <= 0) continue;

        final top = getY(bin.high);
        final bottom = getY(bin.low);
        // A hairline gap keeps neighbouring bands legible as bands.
        final height = (bottom - top - 1).clamp(1.0, double.infinity);
        final length = widest * bin.volume / peak;
        // The busiest band is drawn whole in its own colour, so it reads as
        // one level rather than as the widest of a run of split bars.
        if (i == profile.pointOfControl) {
          canvas.drawRect(
            _profileBar(fromLeft, top, height, 0, length),
            pocPaint,
          );
          continue;
        }

        // The rising share runs from the outside in, so the split sits at the
        // same place on every band and the two colours read as one bar.
        final rising = length * (bin.upVolume / bin.volume).clamp(0.0, 1.0);
        if (rising > 0) {
          canvas.drawRect(_profileBar(fromLeft, top, height, 0, rising), up);
        }
        if (length - rising > 0) {
          canvas.drawRect(
            _profileBar(fromLeft, top, height, rising, length),
            down,
          );
        }
      }
    }
  }

  /// One slice of a profile bar, [from] to [to] pixels along its length.
  ///
  /// [fromLeft] measures the length from the left edge of the chart rather
  /// than from the right, so the bars grow away from the price labels.
  Rect _profileBar(
    bool fromLeft,
    double top,
    double height,
    double from,
    double to,
  ) => fromLeft
      ? Rect.fromLTWH(chartRect.left + from, top, to - from, height)
      : Rect.fromLTWH(chartRect.right - to, top, to - from, height);

  @override
  void drawChart(
    CandleEntity lastPoint,
    CandleEntity curPoint,
    double lastX,
    double curX,
    Size size,
    Canvas canvas, {
    int index = 0,
  }) {
    switch (chartType) {
      case ChartType.candles:
        drawCandle(curPoint, canvas, curX, index);
      case ChartType.bars:
        drawBar(curPoint, canvas, curX, index);
      case ChartType.line:
        drawPolyline(
          lastPoint.close,
          curPoint.close,
          canvas,
          lastX,
          curX,
          fill: false,
        );
      case ChartType.area:
        drawPolyline(lastPoint.close, curPoint.close, canvas, lastX, curX);
      case ChartType.baseline:
        drawBaselineSegment(
          lastPoint.close,
          curPoint.close,
          canvas,
          lastX,
          curX,
        );
      case ChartType.stepLine:
        drawStepSegment(lastPoint.close, curPoint.close, canvas, lastX, curX);
      case ChartType.hlcArea:
        drawHlcSegment(lastPoint, curPoint, canvas, lastX, curX);
      case ChartType.columns:
        drawColumn(curPoint, canvas, curX, index);
    }
  }

  /// Draws one step of a step line: flat from the last close, then up or down
  /// to this one.
  ///
  /// The value only changes where a candle closed, which is the whole point of
  /// drawing it this way rather than sloping between the two.
  void drawStepSegment(
    double lastPrice,
    double curPrice,
    Canvas canvas,
    double lastXO,
    double curX,
  ) {
    final lastX = lastXO == curX ? 0.0 : lastXO;
    final lastY = getY(lastPrice);
    final curY = getY(curPrice);

    _stepLine.path
      ..moveTo(lastX, lastY)
      ..lineTo(curX, lastY)
      ..lineTo(curX, curY);
    _stepLine.touch();
  }

  /// Draws one stretch of an HLC area: the high-low band washed in, with the
  /// close drawn through it.
  void drawHlcSegment(
    CandleEntity lastPoint,
    CandleEntity curPoint,
    Canvas canvas,
    double lastXO,
    double curX,
  ) {
    final lastX = lastXO == curX ? 0.0 : lastXO;

    _hlcBand.path
      ..moveTo(lastX, getY(lastPoint.high))
      ..lineTo(curX, getY(curPoint.high))
      ..lineTo(curX, getY(curPoint.low))
      ..lineTo(lastX, getY(lastPoint.low))
      ..close();
    _hlcBand.touch();

    _hlcClose.addSegment(
      lastX,
      getY(lastPoint.close),
      curX,
      getY(curPoint.close),
    );
  }

  /// Draws one column: from the baseline to the close, in the colour of the
  /// side it ends on.
  void drawColumn(
    CandleEntity point,
    Canvas canvas,
    double curX, [
    int index = 0,
  ]) {
    // With no level to measure from, a column has no length; the chart hands
    // one down from `baselinePrice` or the oldest close in view.
    final baseline = baselinePrice;
    if (baseline == null) return;

    final baseY = getY(baseline);
    final closeY = getY(point.close);
    final above = point.close >= baseline;
    final half = mCandleWidth / 2;

    canvas.drawRect(
      Rect.fromLTRB(
        curX - half,
        math.min(baseY, closeY),
        curX + half,
        math.max(baseY, closeY),
      ),
      chartPaint
        ..style = PaintingStyle.fill
        ..color =
            candleColor?.call(point, index) ??
            (above ? chartColors.upColor : chartColors.dnColor),
    );
  }

  /// Draws one OHLC bar: the high-low range, with the open ticked left and the
  /// close ticked right.
  void drawBar(
    CandleEntity point,
    Canvas canvas,
    double curX, [
    int index = 0,
  ]) {
    final high = getY(point.high);
    final low = getY(point.low);
    final open = getY(point.open);
    final close = getY(point.close);
    // Read from the prices, so an inverted axis does not recolour the bar.
    final rising = point.close >= point.open;
    final tick = mCandleWidth / 2;

    chartPaint
      ..color =
          candleColor?.call(point, index) ??
          (rising ? chartColors.upColor : chartColors.dnColor)
      ..strokeWidth = mCandleLineWidth
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTRB(
        curX - mCandleLineWidth / 2,
        math.min(high, low),
        curX + mCandleLineWidth / 2,
        math.max(high, low),
      ),
      chartPaint,
    );
    canvas.drawRect(
      Rect.fromLTRB(
        curX - tick,
        open - mCandleLineWidth / 2,
        curX,
        open + mCandleLineWidth / 2,
      ),
      chartPaint,
    );
    canvas.drawRect(
      Rect.fromLTRB(
        curX,
        close - mCandleLineWidth / 2,
        curX + tick,
        close + mCandleLineWidth / 2,
      ),
      chartPaint,
    );
  }

  /// Draws one segment of a baseline chart: the stretch of line between two
  /// closes, washed towards the baseline in the colour of the side it is on.
  void drawBaselineSegment(
    double lastPrice,
    double curPrice,
    Canvas canvas,
    double lastXO,
    double curX,
  ) {
    final baseline = baselinePrice;
    if (baseline == null) {
      drawPolyline(lastPrice, curPrice, canvas, lastXO, curX);
      return;
    }

    final lastX = lastXO == curX ? 0.0 : lastXO;
    final baseY = getY(baseline);
    final lastY = getY(lastPrice);
    final curY = getY(curPrice);

    // Which side of the level this stretch sits on decides its colour; a
    // stretch that straddles it takes the side it ends on, so the two sides are
    // collected apart and stroked in their own colour.
    final above = curPrice >= baseline;

    final fill = above ? _baselineUpFill : _baselineDnFill;
    fill.path
      ..moveTo(lastX, baseY)
      ..lineTo(lastX, lastY)
      ..lineTo(curX, curY)
      ..lineTo(curX, baseY)
      ..close();
    fill.touch();

    final stroke = above ? _baselineUpLine : _baselineDnLine;
    stroke.addSegment(lastX, lastY, curX, curY);
  }

  Shader? mLineFillShader;
  Paint mLineFillPaint = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  /// Fills a band — the HLC wash, and either side of a baseline.
  final Paint _bandPaint = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  /// Strokes a series in a colour of its own, where [mLinePaint]'s is wrong.
  final Paint _seriesLinePaint = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;

  /// The series, collected a candle at a time and drawn in [flushSeries].
  final PathBatch _line = PathBatch();
  final PathBatch _lineFill = PathBatch();
  final PathBatch _stepLine = PathBatch();
  final PathBatch _hlcBand = PathBatch();
  final PathBatch _hlcClose = PathBatch();
  final PathBatch _baselineUpFill = PathBatch();
  final PathBatch _baselineDnFill = PathBatch();
  final PathBatch _baselineUpLine = PathBatch();
  final PathBatch _baselineDnLine = PathBatch();

  // Draw a line graph
  void drawPolyline(
    double lastPrice,
    double curPrice,
    Canvas canvas,
    double lastXO,
    double curX, {
    bool fill = true,
  }) {
    double lastX = lastXO;
    if (lastX == curX) lastX = 0; // Fill at the starting position
    _line.path
      ..moveTo(lastX, getY(lastPrice))
      ..cubicTo(
        (lastX + curX) / 2,
        getY(lastPrice),
        (lastX + curX) / 2,
        getY(curPrice),
        curX,
        getY(curPrice),
      );
    _line.touch();

    if (!fill) return;

    _lineFill.path
      ..moveTo(lastX, chartRect.height + chartRect.top)
      ..lineTo(lastX, getY(lastPrice))
      ..cubicTo(
        (lastX + curX) / 2,
        getY(lastPrice),
        (lastX + curX) / 2,
        getY(curPrice),
        curX,
        getY(curPrice),
      )
      ..lineTo(curX, chartRect.height + chartRect.top)
      ..close();
    _lineFill.touch();
  }

  /// The wash under a line or area chart.
  ///
  /// Built once for the pane it fills, since it is measured from the pane and
  /// not from the data.
  Shader get _fillShader => mLineFillShader ??=
      LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        tileMode: TileMode.clamp,
        colors: [chartColors.lineFillColor, chartColors.lineFillInsideColor],
      ).createShader(
        Rect.fromLTRB(
          chartRect.left,
          chartRect.top,
          chartRect.right,
          chartRect.bottom,
        ),
      );

  /// Draws the series collected over the visible window.
  ///
  /// The renderer is handed one candle at a time, so a line used to cost a
  /// `drawPath` per candle. Each piece is appended as its own subpath instead
  /// and the lot goes down in one call, which draws the same thing: an
  /// unjoined subpath strokes exactly as a separate call did.
  ///
  /// Called after the candle loop, inside the transform the pieces were
  /// measured in.
  @override
  void flushSeries(Canvas canvas) {
    final strokeWidth = (mLineStrokeWidth / scaleX).clamp(0.1, 1.0);

    _lineFill.flush(canvas, mLineFillPaint..shader = _fillShader);
    _line.flush(canvas, mLinePaint..strokeWidth = strokeWidth);

    _stepLine.flush(canvas, mLinePaint..strokeWidth = strokeWidth);

    _hlcBand.flush(
      canvas,
      _bandPaint
        ..color = chartColors.kLineColor.withValues(
          alpha: chartStyle.hlcAreaOpacity.clamp(0.0, 1.0),
        ),
    );
    _hlcClose.flush(canvas, mLinePaint..strokeWidth = strokeWidth);

    _baselineUpFill.flush(
      canvas,
      _bandPaint..color = chartColors.upColor.withValues(alpha: 0.18),
    );
    _baselineDnFill.flush(
      canvas,
      _bandPaint..color = chartColors.dnColor.withValues(alpha: 0.18),
    );
    _baselineUpLine.flush(
      canvas,
      _seriesLinePaint
        ..color = chartColors.upColor
        ..strokeWidth = strokeWidth,
    );
    _baselineDnLine.flush(
      canvas,
      _seriesLinePaint
        ..color = chartColors.dnColor
        ..strokeWidth = strokeWidth,
    );
  }

  void drawCandle(
    CandleEntity curPoint,
    Canvas canvas,
    double curX, [
    int index = 0,
  ]) {
    final high = getY(curPoint.high);
    final low = getY(curPoint.low);
    final open = getY(curPoint.open);
    final close = getY(curPoint.close);
    final double r = mCandleWidth / 2;
    final double lineR = mCandleLineWidth / 2;

    // Read from the prices, not from the pixels: an inverted axis puts a
    // rising candle's close lower down the screen, and it is still rising.
    final isRising = curPoint.close >= curPoint.open;
    var bodyTop = math.min(open, close);
    var bodyBottom = math.max(open, close);

    // A doji would otherwise vanish; keep it one stroke tall.
    if (bodyBottom - bodyTop < mCandleLineWidth) {
      final centre = (bodyTop + bodyBottom) / 2;
      bodyTop = centre - mCandleLineWidth / 2;
      bodyBottom = centre + mCandleLineWidth / 2;
    }

    chartPaint
      ..color =
          candleColor?.call(curPoint, index) ??
          (isRising ? chartColors.upColor : chartColors.dnColor)
      ..style = PaintingStyle.fill;

    // The wick spans the whole high-low range, behind the body. Sorted rather
    // than assumed, since an inverted axis puts the high below the low.
    canvas.drawRect(
      Rect.fromLTRB(
        curX - lineR,
        math.min(high, low),
        curX + lineR,
        math.max(high, low),
      ),
      chartPaint,
    );

    final body = Rect.fromLTRB(curX - r, bodyTop, curX + r, bodyBottom);
    if (chartStyle.hollowUpCandles &&
        isRising &&
        bodyBottom - bodyTop > mCandleLineWidth * 3) {
      // Clear the wick out of the body, then outline it.
      canvas.drawRect(body, Paint()..color = chartColors.bgColor);
      canvas.drawRect(
        body.deflate(mCandleLineWidth / 2),
        chartPaint
          ..style = PaintingStyle.stroke
          ..strokeWidth = mCandleLineWidth,
      );
      chartPaint.style = PaintingStyle.fill;
    } else {
      canvas.drawRect(body, chartPaint);
    }
  }

  List<double>? _priceTicks;

  /// The prices this axis rules and labels itself by.
  ///
  /// Round numbers chosen first, then placed wherever they fall — so the axis
  /// reads `69000, 69500, 70000` rather than whatever prices happen to land on
  /// evenly spaced pixels. A logarithmic axis steps by ratio, and a percentage
  /// or indexed one picks round percentages or index levels and converts them
  /// back to the prices they stand for.
  List<double> priceTicks(int gridRows) {
    final cached = _priceTicks;
    if (cached != null) return cached;

    final target = math.max(2, gridRows ~/ 2);
    final base = percentBase;
    final List<double> ticks;
    if (priceScale == PriceAxisScale.percentage && base != null && base != 0) {
      final low = (minValue / base - 1) * 100;
      final high = (maxValue / base - 1) * 100;
      ticks = [
        for (final move in niceTicks(low, high, target: target))
          base * (1 + move / 100),
      ];
    } else if (priceScale == PriceAxisScale.indexedTo100 &&
        base != null &&
        base != 0) {
      // Round index levels — 100, 105, 110 — converted back to the prices they
      // stand for, so the labels read as round numbers.
      final low = minValue / base * 100;
      final high = maxValue / base * 100;
      ticks = [
        for (final level in niceTicks(low, high, target: target))
          base * level / 100,
      ];
    } else if (isLogarithmic) {
      ticks = niceLogTicks(minValue, maxValue, target: target);
    } else {
      ticks = niceTicks(minValue, maxValue, target: target);
    }

    // A range too flat to divide would otherwise leave the axis blank; fall
    // back to the two ends it does have.
    return _priceTicks = ticks.isEmpty ? [minValue, maxValue] : ticks;
  }

  @override
  void drawVerticalText(Canvas canvas, TextStyle textStyle, int gridRows) {
    final padding = chartStyle.axisLabelPadding;

    for (final value in priceTicks(gridRows)) {
      final y = getY(value);
      if (!y.isFinite) continue;

      final TextSpan span = TextSpan(text: formatAxis(value), style: textStyle);
      final TextPainter tp = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
      )..layout();

      // The label sits above its own line, and is nudged back inside the pane
      // at either end so the top one clears the legend and the bottom one is
      // not clipped away.
      final offsetY = (y - tp.height).clamp(
        chartRect.top - topPadding,
        chartRect.bottom - tp.height,
      );

      // With a pane stacked underneath, a label near the bottom edge would
      // print over that pane's legend.
      if (hasPanesBelow && chartRect.bottom - y < tp.height) continue;

      final offsetX = axisLabelX(
        tp.width,
        padding,
        onLeft: verticalTextAlignment == VerticalTextAlignment.left,
      );

      if (chartStyle.axisLabelBackground) {
        canvas.drawRRect(
          RRect.fromLTRBR(
            offsetX - padding / 2,
            offsetY,
            offsetX + tp.width + padding / 2,
            offsetY + tp.height,
            Radius.circular(chartStyle.labelCornerRadius),
          ),
          Paint()..color = chartColors.effectiveAxisLabelBgColor,
        );
      }
      tp.paint(canvas, Offset(offsetX, offsetY));
    }
  }

  @override
  void drawGrid(
    Canvas canvas,
    int gridRows,
    int gridColumns, {
    List<double>? columnXs,
  }) {
    // Rule the pane where the labels are, not on evenly spaced pixels.
    for (final value in priceTicks(gridRows)) {
      final y = getY(value);
      if (!y.isFinite || y < chartRect.top || y > chartRect.bottom) continue;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }

    final columns =
        columnXs ??
        [
          for (int i = 0; i <= gridColumns; i++)
            chartRect.width / gridColumns * i,
        ];
    for (final x in columns) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, chartRect.bottom),
        columnGridPaint,
      );
    }
  }

  /// The price at [y], the exact inverse of [getY].
  @override
  double getValue(double y) {
    final along = (y - _contentRect.top) / _transformedScaleY;
    return _untransform(
      inverted ? _transformedMin + along : _transformedMax - along,
    );
  }

  late final double _transformedMin = _transform(minValue);

  @override
  String get name => 'Price';

  @override
  double getY(double y) {
    //For TrendLine
    updateTrendLineData();
    final value = _transform(y);
    final along = inverted ? value - _transformedMin : _transformedMax - value;
    return along * _transformedScaleY + _contentRect.top;
  }

  void updateTrendLineData() {
    trendLineMax = maxValue;
    trendLineScale = scaleY;
    trendLineContentRec = _contentRect.top;
  }
}
