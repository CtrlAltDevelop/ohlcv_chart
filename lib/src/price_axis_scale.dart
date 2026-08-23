/// How the candle area spaces its price axis.
///
/// Pass one to `KChartWidget.priceAxisScale`. The volume and indicator panes
/// always stay linear; this is about the prices only.
enum PriceAxisScale {
  /// Equal prices take equal space: the default, and what a short window of
  /// data wants.
  linear,

  /// Equal *ratios* take equal space, so a move from 10 to 20 covers as much
  /// of the axis as one from 100 to 200.
  ///
  /// This is what makes a long history readable — without it a decade of
  /// compounding squashes the early years flat. A window whose low is zero or
  /// negative cannot be spaced this way, and falls back to [linear] until it
  /// scrolls back into positive prices.
  logarithmic,

  /// Spaced like [linear], but read out as the move away from the first
  /// candle in view.
  ///
  /// The axis, the crosshair's price label and the current-price tag all show
  /// percentages, which is the comparison a performance chart is for.
  percentage,

  /// Spaced like [linear], but read out with the first candle in view at 100.
  ///
  /// The same information as [percentage] said the other way about — 112 rather
  /// than +12% — which is how an index or a rebased performance series is
  /// usually quoted.
  indexedTo100,
}
