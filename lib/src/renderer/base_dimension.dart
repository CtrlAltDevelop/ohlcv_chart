/// How tall each part of the chart is.
class BaseDimension {
  /// Works out the total height from the candle area and what sits below it.
  ///
  /// [paneCount] is the number of indicator panes and [legendRowCount] the
  /// number of legend rows reserved above the candles.
  BaseDimension({
    required double mBaseHeight,
    required bool volHidden,
    required int paneCount,
    required int legendRowCount,
  }) {
    _mBaseHeight = mBaseHeight;
    _mVolumeHeight = volHidden ? 0 : volumeHeight;
    _mSecondaryHeight = secondaryPaneHeight;
    _totalSecondaryHeight = _mSecondaryHeight * paneCount;
    _totalLabelHeight = legendRowHeight * legendRowCount;

    _mDisplayHeight =
        _mBaseHeight +
        _mVolumeHeight +
        _totalSecondaryHeight +
        _totalLabelHeight;
  }

  /// Height given to the volume pane when it is shown.
  static const double volumeHeight = 60;

  /// Height given to each indicator pane.
  static const double secondaryPaneHeight = 100;

  /// Height reserved above the candles for one legend row.
  static const double legendRowHeight = 12;

  /// Total height everything except the candle area needs.
  ///
  /// Lets a caller work out how tall the candles can be inside a given box.
  static double panesHeight({
    required bool volHidden,
    required int paneCount,
    required int legendRowCount,
  }) =>
      (volHidden ? 0 : volumeHeight) +
      secondaryPaneHeight * paneCount +
      legendRowHeight * legendRowCount;

  // the height of base chart
  double _mBaseHeight = 380;

  // default: 0
  // the height of volume chart
  double _mVolumeHeight = 0;

  // default: 0
  // the height of a secondary chart
  double _mSecondaryHeight = 0;
  double _totalSecondaryHeight = 0;

  double _totalLabelHeight = 0;

  // total height of chart: _mBaseHeight + _mVolumeHeight + (_mSecondaryHeight * n)
  // n : number of secondary charts
  double _mDisplayHeight = 0;

  /// Height of the volume pane, or 0 when it is hidden.
  double get mVolumeHeight => _mVolumeHeight;

  /// Height of one indicator pane.
  double get mSecondaryHeight => _mSecondaryHeight;

  /// Height of every indicator pane together.
  double get totalSecondaryHeight => _totalSecondaryHeight;

  /// Height of one legend row.
  double get mLabelHeight => legendRowHeight;

  /// Height reserved for the legend rows above the candles.
  double get totalLabelHeight => _totalLabelHeight;

  /// Height of the whole chart.
  double get mDisplayHeight => _mDisplayHeight;
}
