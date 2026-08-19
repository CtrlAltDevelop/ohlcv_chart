/// How the depth chart draws an order book.
enum DepthChartMode {
  /// Two filled curves of the running total either side of the mid price.
  ///
  /// The classic depth chart: it shows how much is resting between the mid and
  /// any price, so the shape reads as how hard the book is to move through.
  cumulative,

  /// One bar per price level, each the size resting on that rung alone.
  ///
  /// Shows where the individual walls sit, which a running total smooths away.
  histogram,

  /// The cumulative curves with the per-rung bars behind them.
  combined,

  /// A numeric ladder: price, size and running total, one row per level.
  ///
  /// See [DepthLadder], which the chart hands over to in this mode.
  ladder,
}

/// How volume is spaced up the depth chart's vertical axis.
enum DepthScale {
  /// Volume as it is, evenly spaced.
  linear,

  /// Logarithmic, so a book whose far side dwarfs the near one still reads.
  ///
  /// Spaced by `log(1 + volume)`, which leaves an empty book at the baseline
  /// rather than at minus infinity.
  log,

  /// Volume as a percentage of the largest total on either side.
  ///
  /// Laid out exactly like [linear]; only the axis labels change.
  percent,
}
