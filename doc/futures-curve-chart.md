# Futures curve

![A futures curve in contango, with last month dashed behind it](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/futures-curve.png)

`FuturesCurveChart` plots futures prices against delivery month — the market's
term structure. One curve shows whether the market is in **contango** (later
contracts cost more) or **backwardation** (they cost less); several curves, such
as today's and last month's drawn dashed, show how it has moved.

```dart
FuturesCurveChart(
  curves: [
    FuturesCurve(
      label: 'Today',
      contracts: [
        FuturesContract(label: 'Jan', price: 71.2),
        FuturesContract(label: 'Feb', price: 71.9),
        FuturesContract(label: 'Mar', price: 72.4),
      ],
    ),
    FuturesCurve(label: 'A month ago', dashed: true, contracts: before),
  ],
);
```

The chart fills its constraints. When the height is unbounded, it uses
`defaultHeight`.

## Data

| Type | Fields |
| --- | --- |
| `FuturesContract` | `label` (the delivery month), `price`, `data` |
| `FuturesCurve` | `label`, `contracts` nearest first, `color`, `dashed` |

Contracts are spread evenly, one slot each, so the same contract sits at the
same place on every curve. A curve shorter than the longest leaves the far slots
empty, and a contract whose price is not finite leaves a gap in the line. The
labels along the bottom are those of the longest curve.

## The shape

The first curve's shape and slope are written in the corner —
`Contango +2.3%` — and the badge is coloured green for contango and red for
backwardation. `shapeTolerance` is the share of price a step must exceed to
count as a rise or a fall, so noise in the last decimal does not make a
contango look mixed. `showShapeBadge: false` hides it, and `contangoLabel`,
`backwardationLabel`, `flatLabel` and `mixedLabel` translate it.

| Function | Description |
| --- | --- |
| `curveShape(contracts, tolerance:)` | `contango`, `backwardation`, `flat`, `mixed` or `unknown` |
| `curveSlope(contracts)` | The last price over the first, as a fraction |
| `calendarSpreads(contracts)` | Each price less the one before it |
| `layOutFutures(curves, bounds, …)` | The dots the chart paints, usable without a widget |

## Appearance

| Parameter | Description |
| --- | --- |
| `palette` | Colours taken in turn by curves with none of their own |
| `lineWidth`, `dotRadius`, `showDots` | The lines and their points |
| `showLegend`, `legendStyle` | The curves' names, when there is more than one |
| `showAxes`, `priceFormatter`, `priceAxisTitle`, `tickCount` | The price axis |
| `gridColor`, `hoverBorder`, `backgroundColor`, `padding` | Grid, hover ring, box |

## Touch

`onTouch` reports a `FuturesTouchDetails` with the `contract`, its `curve`, and
the calendar `spread` to the contract before it, and `null` when the pointer
leaves. `tooltipBuilder` builds a card beside the dot.

## Animation

`animationDuration` draws the curves in from the left; `animationCurve` eases it
and `animateOnMount` controls the first build. It animates again only when the
curves' values change.

[← All docs](README.md) · [Package README](../README.md)
