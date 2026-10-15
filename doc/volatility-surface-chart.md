# Volatility surface

`VolatilitySurfaceChart` draws implied volatility across strike and expiry at
once, as a heatmap. `VolatilityCurveChart` shows one smile or one term structure
at a time; the surface is the whole picture, where a skew that steepens into
short expiries or a kink at one strike stands out as colour.

```dart
VolatilitySurfaceChart(
  strikes: const [90, 95, 100, 105, 110],
  expiries: const ['1W', '1M', '3M', '6M'],
  volatilities: [
    [0.34, 0.30, 0.28, 0.29, 0.32], // one row per expiry
    [0.31, 0.28, 0.26, 0.27, 0.29],
    [0.29, 0.27, 0.25, 0.26, 0.28],
    [0.28, 0.26, 0.25, 0.26, 0.27],
  ],
  spot: 100,
);
```

The chart fills its constraints. When the height is unbounded, it uses
`defaultHeight`. It is built on `HeatmapChart`, so a cell is `null` where there
is no quote and is left empty.

## Data

| Parameter | Description |
| --- | --- |
| `strikes` | One per column, left to right |
| `expiries` | One name per row, top to bottom |
| `volatilities` | A row per expiry holding a value per strike, as fractions: 0.25 is 25% |
| `spot` | The underlying's price; used to find the at-the-money strike for the skew |

## Colour

`lowColor`, `midColor` and `highColor` run the scale, cool to warm by default.
`minVolatility` and `maxVolatility` fix its ends — useful to keep two surfaces
comparable — and otherwise take the lowest and highest reading drawn.

## Numbers

| Function | Description |
| --- | --- |
| `atTheMoneyIndex(strikes, spot)` | The column of the strike nearest the spot |
| `surfaceSkew(row, atmIndex)` | Each strike's volatility less the at-the-money one |

## Touch

`onTouch` reports a `VolatilitySurfaceTouchDetails` with the `expiry`, `strike`,
`volatility`, the `atTheMoneyVolatility` of the same expiry and the `skew`
between them, and `null` when the pointer leaves. `tooltipBuilder` builds a card
beside the square.

## Appearance

| Parameter | Description |
| --- | --- |
| `showValues`, `valueFormatter`, `labelStyle` | Volatilities written in the squares |
| `strikeFormatter`, `axisLabelStyle` | Strike labels and their style |
| `expiryAxisWidth`, `strikeAxisHeight` | Room for the labels |
| `spacing`, `radius` | Gap between squares and their corner rounding |
| `animationDuration`, `animationCurve`, `animateOnMount` | Fade-in |
| `backgroundColor`, `padding`, `defaultHeight` | Box |

[← All docs](README.md) · [Package README](../README.md)
