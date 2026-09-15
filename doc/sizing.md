# Sizing

`mBaseHeight` sets the height of the candle area only. The volume pane (60 px)
and each indicator pane (100 px by default, or its resized height) are stacked
below it.

- **Unset (recommended):** the candle area is derived from the widget's
  constraints so the whole stack fits. Place the chart in an `Expanded` to fill
  the available space.
- **Set:** the candle area has a fixed height. Use this when there is no
  bounded height to divide, such as inside a scroll view.

![The candle area filling the box, and pinned to 220](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/sizing.png)

---

[← All docs](README.md) · [Package README](../README.md)
