/// What the candle area draws for each candle.
///
/// Pass one to `KChartWidget.chartType`. Heikin-Ashi and Renko are not here:
/// both rewrite the candles themselves rather than the way they are drawn, so
/// they live in `CandleTransforms` and are drawn as [candles].
enum ChartType {
  /// A filled or hollow body with a wick: the default.
  candles,

  /// An OHLC bar — the high-low range, with the open ticked off to the left and
  /// the close to the right.
  ///
  /// What a bar chart is for: less ink than a candle at the same width, so a
  /// long window stays readable.
  bars,

  /// A line through the closes.
  line,

  /// A line through the closes with the area beneath it washed in.
  area,

  /// A line through the closes, washed towards a level, in the profit colour
  /// above it and the loss colour below.
  ///
  /// The level is `KChartWidget.baselinePrice`, or the oldest close in view.
  baseline,

  /// A line through the closes that steps rather than slopes.
  ///
  /// Each close is held flat until the next one, so the line only ever moves at
  /// a close. Honest about a series that is only known at those instants — a
  /// settlement, an official rate — where a sloping line invents the values in
  /// between.
  stepLine,

  /// The high-low range washed in, with the close drawn through it.
  ///
  /// Reads like an area chart that has not thrown the range away: how far the
  /// market travelled each bar as well as where it ended.
  hlcArea,

  /// A column per candle, from the baseline up or down to the close.
  ///
  /// The level is `KChartWidget.baselinePrice`, or the oldest close in view,
  /// and a column takes the profit colour above it and the loss colour below.
  /// Reads a series of discrete readings — a net position, a daily change —
  /// rather than a continuous price.
  columns,
}
