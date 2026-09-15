import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

const _bounds = Rect.fromLTWH(0, 0, 300, 200);

// A bull call spread: long the 100 call for 4, short the 110 call for 1.5.
const _spread = [
  OptionLeg.longCall(strike: 100, premium: 4),
  OptionLeg.shortCall(strike: 110, premium: 1.5),
];

void main() {
  group('the payoff', () {
    test('a long call loses its premium below the strike', () {
      const leg = OptionLeg.longCall(strike: 100, premium: 4);
      expect(leg.payoffAt(90), -4);
      expect(leg.payoffAt(100), -4);
      expect(leg.payoffAt(106), 2);
    });

    test('a short put is the mirror of a long one', () {
      const long = OptionLeg.longPut(strike: 100, premium: 3);
      const short = OptionLeg.shortPut(strike: 100, premium: 3);
      expect(short.payoffAt(80), -long.payoffAt(80));
      expect(short.payoffAt(120), 3);
    });

    test('the underlying pays the move from where it was traded', () {
      const stock = OptionLeg(kind: OptionKind.underlying, strike: 50);
      expect(stock.payoffAt(60), 10);
      expect(stock.payoffAt(40), -10);
    });

    test('quantity and contract size multiply the leg', () {
      const leg = OptionLeg.longCall(
        strike: 100,
        premium: 1,
        quantity: 2,
        contractSize: 100,
      );
      expect(leg.payoffAt(105), 800);
    });

    test('the legs add up', () {
      expect(optionPayoff(_spread, 90), -2.5);
      expect(optionPayoff(_spread, 110), 7.5);
      expect(optionPayoff(_spread, 200), 7.5);
    });

    test('break-evens are found exactly between the strikes', () {
      final evens = optionBreakEvens(_spread, 80, 130);
      expect(evens.length, 1);
      expect(evens.single, closeTo(102.5, 1e-9));
    });

    test('a strategy that never crosses zero has no break-even', () {
      final evens = optionBreakEvens(
        const [OptionLeg.longCall(strike: 100, premium: 2)],
        50,
        90,
      );
      expect(evens, isEmpty);
    });

    test('the price range covers the strikes and the spot, with room', () {
      final range = optionPriceRange(_spread, pad: 0.5);
      expect(range.min, 95);
      expect(range.max, 115);
      expect(optionPriceRange(_spread, spot: 80, pad: 0).min, 80);
      expect(optionPriceRange(const []), (min: 0.0, max: 1.0));
    });
  });

  group('the layout', () {
    test('the line is sampled at the strikes, so the kinks are exact', () {
      final layout = layOutOptionPayoff(
        _spread,
        _bounds,
        minPrice: 90,
        maxPrice: 120,
        steps: 2,
      );
      // 90, 100, 105, 110, 120: both strikes plus the even steps.
      expect(layout.points.length, 5);
      expect(layout.xOf(100), 100);
    });

    test('zero is always on the chart', () {
      final layout = layOutOptionPayoff(
        const [OptionLeg.longCall(strike: 100)],
        _bounds,
        minPrice: 50,
        maxPrice: 90,
      );
      expect(layout.minPayoff, lessThanOrEqualTo(0));
      expect(layout.maxPayoff, greaterThanOrEqualTo(0));
      expect(layout.zeroY, inInclusiveRange(0, 200));
    });

    test('prices map across the plot, and back again', () {
      final layout = layOutOptionPayoff(
        _spread,
        _bounds,
        minPrice: 100,
        maxPrice: 200,
      );
      expect(layout.xOf(150), 150);
      expect(layout.priceAt(150), 150);
      expect(layout.priceAt(-100), 100);
      expect(layout.priceAt(1000), 200);
    });

    test('nothing to show, no room, or a backwards range lays out nothing',
        () {
      expect(
        layOutOptionPayoff(const [], _bounds, minPrice: 0, maxPrice: 1).isEmpty,
        isTrue,
      );
      expect(
        layOutOptionPayoff(_spread, Rect.zero, minPrice: 0, maxPrice: 1).isEmpty,
        isTrue,
      );
      expect(
        layOutOptionPayoff(_spread, _bounds, minPrice: 10, maxPrice: 10)
            .isEmpty,
        isTrue,
      );
    });
  });

  group('the widget', () {
    testWidgets('draws, reports touches and takes its default height',
        (tester) async {
      OptionPayoffTouchDetails? touched;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                OptionPayoffChart(
                  legs: _spread,
                  spot: 102,
                  minPrice: 90,
                  maxPrice: 120,
                  onTouch: (d) => touched = d,
                  tooltipBuilder: (context, d) =>
                      Text('card ${d.payoff.toStringAsFixed(1)}'),
                  semanticLabel: 'Bull call spread',
                ),
              ],
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(OptionPayoffChart));
      expect(size.height, 260);

      // Halfway across the plot is a price of 105.
      final topLeft = tester.getTopLeft(find.byType(OptionPayoffChart));
      final plotLeft = 52.0;
      final gesture = await tester.startGesture(
        topLeft + Offset(plotLeft + (size.width - plotLeft) / 2, 50),
      );
      await tester.pump();
      expect(touched?.price, closeTo(105, 0.5));
      expect(touched?.payoff, closeTo(2.5, 0.5));
      expect(find.textContaining('card'), findsOneWidget);

      await gesture.up();
      await tester.pump();
      expect(touched, isNull);
    });

    testWidgets('draws itself in and survives its legs changing',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OptionPayoffChart(
              legs: _spread,
              animationDuration: const Duration(milliseconds: 200),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OptionPayoffChart(
              legs: const [OptionLeg.longPut(strike: 50, premium: 2)],
              animationDuration: const Duration(milliseconds: 200),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
