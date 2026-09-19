import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

/// A chart that only remembers where it was told to look.
///
/// The overview drives a chart through the controller and nothing else, so a
/// stand-in host is enough to say exactly what it asked for.
class _FakeHost implements KChartHost {
  _FakeHost(this.candles, {this.first = 0, this.last = 49});

  final List<KLineEntity> candles;

  /// Where the chart is currently looking.
  int first;
  int last;

  /// Every window it was asked to show, in order.
  final List<(int, int)> asked = [];

  @override
  ChartVisibleRange? get chartVisibleRange =>
      ChartVisibleRange.of(candles, first, last);

  @override
  bool showChartRange(int firstIndex, int lastIndex) {
    asked.add((firstIndex, lastIndex));
    first = firstIndex;
    last = lastIndex;
    return true;
  }

  // Nothing below is reached by the overview.
  @override
  double get chartScale => 1;
  @override
  void setChartScale(double scale) {}
  @override
  void scrollChartToNow({required bool animated}) {}
  @override
  bool get isChartAtRightEdge => true;
  @override
  Future<Uint8List?> captureChart({required double pixelRatio}) async => null;
  @override
  double get chartPriceZoom => 1;
  @override
  void setChartPriceZoom(double zoom) {}
  @override
  void resetChartPriceScale() {}
  @override
  bool scrollChartTo(int index, {required bool animated}) => false;
  @override
  bool fitChartToData() => false;
  @override
  int? get chartCrosshairIndex => null;
  @override
  double? get chartCrosshairPrice => null;
  @override
  void showChartCrosshair(int? index, {double? price}) {}
  @override
  double get chartPricePan => 0;
  @override
  void setChartPricePan(double pan) {}
}

List<KLineEntity> series(int count) => [
  for (var i = 0; i < count; i++)
    KLineEntity.fromCustom(
      open: 100.0 + i,
      high: 101.0 + i,
      low: 99.0 + i,
      close: 100.0 + i,
      vol: 10,
      dateTime: DateTime.utc(2024).add(Duration(minutes: i)),
    ),
];

/// The overview at a known 400px wide, over [count] candles.
({Widget widget, KChartController controller, _FakeHost host}) harness(
  int count, {
  int first = 0,
  int last = 49,
}) {
  final candles = series(count);
  final host = _FakeHost(candles, first: first, last: last);
  final controller = KChartController()..attach(host);

  return (
    host: host,
    controller: controller,
    widget: MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            child: ChartOverview(candles, controller: controller),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('ChartOverview', () {
    testWidgets('draws over a history, and over nothing at all', (
      tester,
    ) async {
      for (final count in [0, 1, 2, 500]) {
        final built = harness(count, first: 0, last: count > 1 ? 1 : 0);
        await tester.pumpWidget(built.widget);
        expect(tester.takeException(), isNull, reason: '$count candles');
      }
    });

    testWidgets('a flat history still draws', (tester) async {
      final candles = [
        for (var i = 0; i < 20; i++)
          KLineEntity.fromCustom(
            open: 100,
            high: 100,
            low: 100,
            close: 100,
            vol: 1,
            dateTime: DateTime.utc(2024).add(Duration(minutes: i)),
          ),
      ];
      final controller = KChartController()..attach(_FakeHost(candles));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: ChartOverview(candles, controller: controller),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping outside the window centres it there', (tester) async {
      // 200 candles over 400px: two pixels a candle.
      final built = harness(200, first: 0, last: 19);
      await tester.pumpWidget(built.widget);

      // 300px across is candle 150 or so; the 20-wide window should centre on
      // it rather than jumping to a window of a different size.
      await tester.tapAt(
        tester.getTopLeft(find.byType(ChartOverview)).translate(300, 10),
      );
      await tester.pumpAndSettle();

      expect(built.host.asked, isNotEmpty);
      final (first, last) = built.host.asked.last;
      expect(last - first, 19, reason: 'the window keeps its width');
      expect((first + last) / 2, closeTo(150, 3));
    });

    testWidgets('dragging the window pans it without resizing', (tester) async {
      final built = harness(200, first: 90, last: 109);
      await tester.pumpWidget(built.widget);

      final origin = tester.getTopLeft(find.byType(ChartOverview));
      // The window sits around candle 100, which is 200px across.
      await tester.dragFrom(origin.translate(200, 10), const Offset(40, 0));
      await tester.pumpAndSettle();

      expect(built.host.asked, isNotEmpty);
      final (first, last) = built.host.asked.last;
      expect(last - first, 19, reason: 'still twenty candles wide');
      expect(first, greaterThan(90), reason: 'and it moved forward');
    });

    testWidgets('dragging an edge resizes the window', (tester) async {
      final built = harness(200, first: 90, last: 109);
      await tester.pumpWidget(built.widget);

      final origin = tester.getTopLeft(find.byType(ChartOverview));
      // The left edge of the window is candle 90 — 180px across.
      await tester.dragFrom(origin.translate(180, 10), const Offset(-60, 0));
      await tester.pumpAndSettle();

      final (first, last) = built.host.asked.last;
      expect(last, 109, reason: 'the far edge stayed put');
      expect(first, lessThan(90), reason: 'the near edge moved out');
    });

    testWidgets('panning to the end keeps the window its width', (
      tester,
    ) async {
      final built = harness(200, first: 170, last: 189);
      await tester.pumpWidget(built.widget);

      final origin = tester.getTopLeft(find.byType(ChartOverview));
      // Shove it well past the end.
      await tester.dragFrom(origin.translate(360, 10), const Offset(400, 0));
      await tester.pumpAndSettle();

      final (first, last) = built.host.asked.last;
      expect(last, 199, reason: 'stops at the newest candle');
      expect(last - first, 19, reason: 'rather than shrinking against the end');
    });

    testWidgets('follows the controller when the chart moves on its own', (
      tester,
    ) async {
      final built = harness(200, first: 0, last: 19);
      await tester.pumpWidget(built.widget);

      // The chart scrolls itself; the strip should repaint, not throw.
      built.host.showChartRange(100, 119);
      built.controller.hostChanged();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(built.controller.visibleRange!.firstIndex, 100);
    });

    testWidgets('does nothing while no chart is attached', (tester) async {
      final candles = series(50);
      final controller = KChartController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: ChartOverview(candles, controller: controller),
            ),
          ),
        ),
      );

      await tester.tapAt(
        tester.getTopLeft(find.byType(ChartOverview)).translate(200, 10),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('redraws when the newest candle moves in place', (
      tester,
    ) async {
      final candles = series(100);
      final host = _FakeHost(candles, first: 50, last: 99);
      final controller = KChartController()..attach(host);
      // One set of colours for the life of the strip, as an app passes them.
      final colors = ChartColors();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: ChartOverview(
                candles,
                controller: controller,
                colors: colors,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      CustomPainter overviewPainter() => tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byType(ChartOverview),
              matching: find.byType(CustomPaint),
            ),
          )
          .firstWhere((paint) => paint.painter != null)
          .painter!;

      final before = overviewPainter();
      // A tick mutates the newest candle in the list the strip already holds.
      candles.last.close += 50;
      controller.hostChanged();
      await tester.pumpAndSettle();
      final after = overviewPainter();

      expect(identical(after, before), isFalse, reason: 'nothing rebuilt');
      expect(after.shouldRepaint(before), isTrue);
    });
  });
}
