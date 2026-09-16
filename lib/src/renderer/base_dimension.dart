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
    List<double>? paneHeights,
  }) {
    _mBaseHeight = mBaseHeight;
    _mVolumeHeight = volHidden ? 0 : volumeHeight;
    _paneHeights = [
      for (var i = 0; i < paneCount; i++)
        paneHeights != null && i < paneHeights.length
            ? paneHeights[i]
            : secondaryPaneHeight,
    ];
    _mSecondaryHeight =
        _paneHeights.isEmpty ? secondaryPaneHeight : _paneHeights.first;
    _totalSecondaryHeight = _paneHeights.fold(0.0, (sum, h) => sum + h);
    _totalLabelHeight = legendRowHeight * legendRowCount;

    _mDisplayHeight = _mBaseHeight +
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
    List<double>? paneHeights,
  }) {
    var panes = 0.0;
    for (var i = 0; i < paneCount; i++) {
      panes += paneHeights != null && i < paneHeights.length
          ? paneHeights[i]
          : secondaryPaneHeight;
    }
    return (volHidden ? 0 : volumeHeight) +
        panes +
        legendRowHeight * legendRowCount;
  }

  // the height of base chart
  double _mBaseHeight = 380;

  // default: 0
  // the height of volume chart
  double _mVolumeHeight = 0;

  // default: 0
  // the height of a secondary chart
  double _mSecondaryHeight = 0;
  List<double> _paneHeights = const [];
  double _totalSecondaryHeight = 0;

  double _totalLabelHeight = 0;

  // total height of chart: _mBaseHeight + _mVolumeHeight + (_mSecondaryHeight * n)
  // n : number of secondary charts
  double _mDisplayHeight = 0;

  /// Height of the volume pane, or 0 when it is hidden.
  double get mVolumeHeight => _mVolumeHeight;

  /// Height of the first indicator pane, or the default when there are none.
  ///
  /// Panes may differ in height once the user has dragged a separator; see
  /// [paneHeights].
  double get mSecondaryHeight => _mSecondaryHeight;

  /// The height of each indicator pane, in the order they are stacked.
  List<double> get paneHeights => List<double>.unmodifiable(_paneHeights);

  /// Height of every indicator pane together.
  double get totalSecondaryHeight => _totalSecondaryHeight;

  /// Height of one legend row.
  double get mLabelHeight => legendRowHeight;

  /// Height reserved for the legend rows above the candles.
  double get totalLabelHeight => _totalLabelHeight;

  /// Height of the whole chart.
  double get mDisplayHeight => _mDisplayHeight;
}
