# Options payoff

`OptionPayoffChart` draws what an options strategy makes or loses at expiry,
price by price: profit shaded green above the zero line, loss red below it, with
the strikes, the break-evens and the current spot marked.

```dart
OptionPayoffChart(
  legs: const [
    OptionLeg.longCall(strike: 100, premium: 4),
    OptionLeg.shortCall(strike: 110, premium: 1.5),
  ],
  spot: 102,
);
```

The chart fills its constraints. When the height is unbounded, it uses
`defaultHeight`.

## Legs

`OptionLeg` has four shorthands — `longCall`, `shortCall`, `longPut`,
`shortPut` — and a general constructor for the underlying itself:

```dart
const OptionLeg(kind: OptionKind.underlying, strike: 98); // 100 shares, bought at 98
```

| Field | Description |
| --- | --- |
| `kind` | `call`, `put` or `underlying` |
| `strike` | The strike; for `underlying`, the price it was traded at |
| `premium` | Paid per contract for a long leg, taken in for a short one |
| `quantity` | How many contracts; negative is short |
| `contractSize` | How much of the underlying one contract covers (100, often) |
| `label` | What the leg is called |

`leg.payoffAt(price)` is one leg's profit at expiry, and
`optionPayoff(legs, price)` the whole strategy's.

## Break-evens and range

The payoff is a straight line between strikes, so break-evens are found exactly
rather than by scanning:

- `optionBreakEvens(legs, min, max)` — every price in the range where the
  strategy crosses zero.
- `optionPriceRange(legs, pad: 0.35, spot: …)` — the price range worth drawing,
  covering every strike and the spot with room either side.

## Layout

| Parameter | Description |
| --- | --- |
| `minPrice`, `maxPrice` | The prices drawn; `null` reads them off the strikes |
| `minPayoff`, `maxPayoff` | Ends of the payoff axis; `null` reads them off the payoff, always including zero |
| `spot` | Where the underlying is now; `null` marks none |
| `steps` | How many prices the line is sampled at, on top of the strikes |
| `axisWidth`, `axisHeight`, `showAxes` | The two axes |
| `padding` | Space around the chart |

`layOutOptionPayoff(legs, bounds, minPrice: …, maxPrice: …)` returns the
`OptionPayoffLayout` the chart paints, with `xOf`, `yOf` and `priceAt` for
mapping between prices and pixels. Sampling always includes every strike, so the
kinks in the line are exact.

## Appearance

| Parameter | Description |
| --- | --- |
| `profitColor`, `lossColor` | The line and shading above and below zero |
| `lineWidth`, `fillOpacity` | Line weight and shading |
| `showStrikes`, `strikeColor` | A line at each strike |
| `showBreakEvens`, `breakEvenColor` | Marks and prices where the strategy crosses zero |
| `spotColor` | The line marking `spot` |
| `gridColor`, `crosshairColor` | Grid and crosshair |
| `priceFormatter`, `payoffFormatter`, `axisLabelStyle` | Axis label text |
| `tickCount`, `backgroundColor` | Ticks and background |

## Touch

The chart reads raw pointer events, so the crosshair follows a drag at once.
`onTouch` reports an `OptionPayoffTouchDetails` with the `price` under the
pointer, the `payoff` there and where it sits, and `null` when the pointer
leaves.

```dart
OptionPayoffChart(
  legs: legs,
  tooltipBuilder: (context, details) => Card(
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Text('At ${details.price.toStringAsFixed(2)}: '
          '${details.payoff.toStringAsFixed(2)}'),
    ),
  ),
);
```

## Animation

`animationDuration` draws the line in from the left; `animationCurve` eases it
and `animateOnMount` controls whether the first build animates. The chart
animates again whenever `legs` changes identity.
