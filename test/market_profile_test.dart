import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

import 'test_utils.dart';

const _bounds = Rect.fromLTWH(0, 0, 200, 100);

/// Four candles, all overlapping 10–11, with two reaching further up.
List<KLineEntity> _session() => [
  candle(10.5, high: 11, low: 10, minute: 0),
  candle(10.5, high: 11, low: 10, minute: 1),
  candle(11.5, high: 12, low: 11, minute: 2),
  candle(12.5, high: 13, low: 12, minute: 3),
];

void main() {
  group('building the profile', () {
    test('every level a candle covered is credited to it', () {
      final profile = buildMarketProfile(_session(), tickSize: 1);
      expect(profile.rows.length, 3); // 10–11, 11–12, 12–13
      expect(profile.rows.map((r) => r.count), [2, 1, 1]);
      expect(profile.rows.first.periods, [0, 1]);
      expect(profile.periodCount, 4);
    });

    test('the busiest level is the point of control', () {
      final profile = buildMarketProfile(_session(), tickSize: 1);
      expect(profile.pointOfControl, 10.5);
      expect(profile.busiest, 2);
    });

    test('the value area grows out of the point of control', () {
      final profile = buildMarketProfile(_session(), tickSize: 1);
      // Four TPOs in total; 70% of them is 2.8, so it takes a neighbour.
      expect(profile.valueAreaLow, 10);
      expect(profile.valueAreaHigh, 12);
      expect(profile.inValueArea(11.5), isTrue);
      expect(profile.inValueArea(12.5), isFalse);
    });

    test('a fraction of 1 takes in every level', () {
      final profile = buildMarketProfile(
        _session(),
        tickSize: 1,
        valueAreaFraction: 1,
      );
      expect(profile.valueAreaLow, 10);
      expect(profile.valueAreaHigh, 13);
    });

    test('rowCount splits the range instead of a tick size', () {
      final profile = buildMarketProfile(_session(), rowCount: 6);
      expect(profile.rows.length, 6);
      expect(profile.tickSize, 0.5);
    });

    test('no candles, or no prices, build nothing', () {
      expect(buildMarketProfile(const []).isEmpty, isTrue);
    });
  });

  group('the layout', () {
    test('rows stack from the bottom, the lowest price first', () {
      final profile = buildMarketProfile(_session(), tickSize: 1);
      final bars = layOutMarketProfile(profile, _bounds, rowSpacing: 0);
      expect(bars.first.row.from, 10);
      expect(bars.first.band.bottom, 100);
      expect(bars.last.band.top, 0);
    });

    test('a bar is as wide as the level was busy', () {
      final profile = buildMarketProfile(_session(), tickSize: 1);
      final bars = layOutMarketProfile(profile, _bounds);
      expect(bars.first.blockWidth, 100); // the busiest row holds two
      expect(bars.first.rect.width, 200);
      expect(bars[1].rect.width, 100);
    });

    test('a fixed block width is kept, clipped to the chart', () {
      final profile = buildMarketProfile(_session(), tickSize: 1);
      final bars = layOutMarketProfile(profile, _bounds, blockWidth: 500);
      expect(bars.first.rect.width, 200);
    });

    test('nothing to show, or no room, lays out nothing', () {
      expect(layOutMarketProfile(MarketProfile.empty, _bounds), isEmpty);
      expect(
        layOutMarketProfile(
          buildMarketProfile(_session(), tickSize: 1),
          Rect.zero,
        ),
        isEmpty,
      );
    });

    test('a point in a row finds it', () {
      final profile = buildMarketProfile(_session(), tickSize: 1);
      final bars = layOutMarketProfile(profile, _bounds);
      expect(marketProfileBarAt(bars, const Offset(10, 95))?.index, 0);
      expect(marketProfileBarAt(bars, const Offset(10, 500)), isNull);
    });
  });

  group('the widget', () {
    testWidgets('draws, reports touches and takes its default height', (
      tester,
    ) async {
      MarketProfileTouchDetails? touched;
      final profile = buildMarketProfile(_session(), tickSize: 1);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                MarketProfileChart(
                  profile: profile,
                  onTouch: (d) => touched = d,
                  tooltipBuilder: (context, d) => Text('card ${d.row.count}'),
                  semanticLabel: 'Session profile',
                ),
              ],
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(MarketProfileChart));
      expect(size.height, 320);

      final topLeft = tester.getTopLeft(find.byType(MarketProfileChart));
      final gesture = await tester.startGesture(
        topLeft + Offset(size.width - 10, size.height - 10),
      );
      await tester.pump();
      expect(touched?.row.from, 10);
      expect(find.text('card 2'), findsOneWidget);

      await gesture.up();
      await tester.pump();
      expect(touched, isNull);
    });

    testWidgets('grows in and survives its profile changing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarketProfileChart(
              profile: buildMarketProfile(_session(), tickSize: 1),
              animationDuration: const Duration(milliseconds: 200),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarketProfileChart(
              profile: buildMarketProfile(_session(), rowCount: 20),
              showLetters: false,
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
