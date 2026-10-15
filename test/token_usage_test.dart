import 'dart:ui' show PointerDeviceKind;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

final _day = DateTime.utc(2026, 9, 1);

List<UsageBucket> _buckets() => [
  for (var i = 0; i < 7; i++)
    UsageBucket(
      time: _day.add(Duration(days: i)),
      inputTokens: 1e6 * (i + 1),
      outputTokens: 4e5 * (i + 1),
      cachedTokens: 5e5,
      cost: 12.0 + i,
    ),
];

void main() {
  group('a bucket', () {
    test('adds up every kind of token', () {
      final b = UsageBucket(
        time: _day,
        inputTokens: 100,
        outputTokens: 50,
        cachedTokens: 25,
      );

      expect(b.total, 175);
    });

    test('the cache hit rate is cached over the whole prompt', () {
      final b = UsageBucket(time: _day, inputTokens: 300, cachedTokens: 700);

      expect(b.cacheHitRate, closeTo(0.7, 1e-9));
      expect(UsageBucket(time: _day).cacheHitRate, 0);
    });

    test('a value that is not finite counts as nothing', () {
      final b = UsageBucket(
        time: _day,
        inputTokens: double.nan,
        outputTokens: -5,
        cachedTokens: double.infinity,
      );

      expect(b.total, 0);
    });
  });

  group('totals', () {
    test('add the buckets, costs only where there is one', () {
      final totals = usageTotals([
        UsageBucket(time: _day, inputTokens: 10, outputTokens: 5, cost: 2),
        UsageBucket(time: _day, inputTokens: 20, cachedTokens: 30),
        UsageBucket(time: _day, cost: double.nan),
      ]);

      expect(totals.input, 30);
      expect(totals.output, 5);
      expect(totals.cached, 30);
      expect(totals.tokens, 65);
      expect(totals.cost, 2);
      expect(totals.cacheHitRate, closeTo(0.5, 1e-9));
    });

    test('nothing adds up to nothing', () {
      final totals = usageTotals(const []);

      expect(totals.tokens, 0);
      expect(totals.cacheHitRate, 0);
    });
  });

  test('counts are written compactly', () {
    expect(compactCount(950), '950');
    expect(compactCount(12400), '12.4k');
    expect(compactCount(3100000), '3.1M');
    expect(compactCount(2e9), '2B');
    expect(compactCount(1500), '1.5k');
    expect(compactCount(0), '0');
    expect(compactCount(double.nan), '–');
  });

  group('the widget', () {
    Widget host(Widget chart) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 400, height: 300, child: chart)),
    );

    testWidgets('reports the column under the pointer', (tester) async {
      UsageTouchDetails? touched;
      await tester.pumpWidget(
        host(TokenUsageChart(buckets: _buckets(), onTouch: (d) => touched = d)),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      final origin = tester.getTopLeft(find.byType(TokenUsageChart));
      // Seven columns across a plot from 44 px to 400 - 44 = 356 px.
      const width = (400 - 44 - 44) / 7;
      await gesture.moveTo(origin + const Offset(44 + width * 3.5, 100));

      expect(touched, isNotNull);
      expect(touched!.index, 3);
      expect(touched!.bucket.inputTokens, 4e6);

      await gesture.moveTo(origin + const Offset(1, 100));
      expect(touched, isNull);
    });

    testWidgets('draws without a cost, and hourly', (tester) async {
      await tester.pumpWidget(
        host(
          TokenUsageChart(
            showCost: false,
            buckets: [
              for (var i = 0; i < 24; i++)
                UsageBucket(
                  time: _day.add(Duration(hours: i)),
                  inputTokens: 1000.0 + i,
                  outputTokens: 300,
                ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('survives nothing, zeros and one bucket', (tester) async {
      await tester.pumpWidget(host(const TokenUsageChart(buckets: [])));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        host(TokenUsageChart(buckets: [UsageBucket(time: _day)])),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
