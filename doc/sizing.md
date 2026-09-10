# Sizing

`mBaseHeight` is the candle area alone; the volume pane (60px) and each indicator
pane (100px, until one is dragged) are stacked underneath. Left unset it is
derived from the widget's box, so the whole stack fits — put the chart in an
`Expanded` and it fills the space. Pass a number to pin the candle area instead, for instance inside a scroll
view where there is no height to divide up.

![The candle area filling the box, and pinned to 220](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/sizing.png)

---

[← All docs](README.md) · [Package README](../README.md)
