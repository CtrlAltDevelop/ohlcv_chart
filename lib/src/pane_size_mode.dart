/// How the heights of the candles, the volume pane and the indicator panes are
/// worked out.
///
/// Pass one to `KChartWidget.paneSizeMode`.
enum PaneSizeMode {
  /// Pixel heights: 100 for each indicator pane and 60 for the volume pane, or
  /// what `KChartWidget.paneHeights` and `volumeHeight` say, with the candles
  /// taking the rest. The default.
  ///
  /// With `resizablePanes` on, dragging a pane's lower edge changes its height.
  heights,

  /// Proportions: `KChartWidget.paneRatios` splits the height between the
  /// candles, the volume pane and each indicator pane, and the split holds as
  /// the chart is resized.
  ///
  /// The host owns the proportions; a drag with `resizablePanes` on reports the
  /// new ones through `onPaneRatiosChanged`.
  ratios,

  /// The user lays the chart out themselves. Turn editing on with
  /// `KChartController.editPanes` and a line appears between each two parts,
  /// to be dragged up or down between the smallest and largest height each part
  /// may take (`ChartStyle.minPaneHeight` and `maxPaneHeight`, and a minimum
  /// for the candles).
  ///
  /// The chart owns the layout and keeps it as proportions, so it holds through
  /// a resize. It starts from `paneRatios` when given, or from the standard
  /// heights, and the result is reported through `onPaneRatiosChanged` for
  /// saving.
  custom,
}
