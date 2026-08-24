import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

/// A chart that only remembers where it was told to look.
class _FakeHost implements KChartHost {
  _FakeHost({this.total = 200, this.first = 0, this.last = 19});

  final int total;
  int first;
  int last;

  /// Every window it was asked to show, in order.
  final List<(int, int)> asked = [];

  /// The controller to notify, as a real chart does when it moves.
  KChartController? controller;

  late final List<KLineEntity> candles = [
    for (var i = 0; i < total; i++)
      KLineEntity.fromCustom(
        open: 100,
        high: 100,
        low: 100,
        close: 100,
        vol: 1,
        dateTime: DateTime.utc(2024).add(Duration(minutes: i)),
      ),
  ];

  /// Moves as a user scrolling it would, telling the controller afterwards.
  void scrollTo(int from, int to) {
    first = from;
    last = to;
    controller?.hostChanged();
  }

  @override
  ChartVisibleRange? get chartVisibleRange =>
      ChartVisibleRange.of(candles, first, last);

  @override
  bool showChartRange(int firstIndex, int lastIndex) {
    asked.add((firstIndex, lastIndex));
    first = firstIndex.clamp(0, total - 1);
    last = lastIndex.clamp(0, total - 1);
    controller?.hostChanged();
    return true;
  }

  // Nothing below is reached by the link.
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
}

({KChartController controller, _FakeHost host}) chart({
  int total = 200,
  int first = 0,
  int last = 19,
}) {
  final host = _FakeHost(total: total, first: first, last: last);
  final controller = KChartController()..attach(host);
  host.controller = controller;
  return (controller: controller, host: host);
}

void main() {
  group('ChartLink', () {
    test('moving one chart moves the others', () {
      final a = chart();
      final b = chart();
      final c = chart();
      ChartLink()
        ..add(a.controller)
        ..add(b.controller)
        ..add(c.controller);

      a.host.scrollTo(100, 119);

      expect(b.host.asked.last, (100, 119));
      expect(c.host.asked.last, (100, 119));
    });

    test('the follower does not push the leader back', () {
      final a = chart();
      final b = chart();
      ChartLink()
        ..add(a.controller)
        ..add(b.controller);

      a.host.scrollTo(50, 69);

      // A pushes B; B's own notification must not travel back to A, or the two
      // would bounce the window between them.
      expect(a.host.asked, isEmpty, reason: 'the chart the user moved is left');
      expect(b.host.asked, [(50, 69)]);
    });

    test('a chart already there is not moved again', () {
      final a = chart();
      final b = chart(first: 100, last: 119);
      ChartLink()
        ..add(a.controller)
        ..add(b.controller);

      a.host.scrollTo(100, 119);

      expect(b.host.asked, isEmpty, reason: 'it was already showing that');
    });

    test('either chart can lead', () {
      final a = chart();
      final b = chart();
      ChartLink()
        ..add(a.controller)
        ..add(b.controller);

      a.host.scrollTo(30, 49);
      expect(b.host.asked.last, (30, 49));

      b.host.scrollTo(80, 99);
      expect(a.host.asked.last, (80, 99));
    });

    test('a shorter history is lined up as far as it reaches', () {
      final long = chart(total: 500);
      final short = chart(total: 60);
      ChartLink()
        ..add(long.controller)
        ..add(short.controller);

      long.host.scrollTo(400, 419);

      // Asked for candles it does not have, it clamps rather than refusing.
      expect(short.host.asked.last, (400, 419));
      expect(short.host.first, 59);
      expect(short.host.last, 59);
    });

    test('a chart taken off the link stops following', () {
      final a = chart();
      final b = chart();
      final link = ChartLink()
        ..add(a.controller)
        ..add(b.controller);

      expect(link.remove(b.controller), isTrue);
      expect(link.remove(b.controller), isFalse);

      a.host.scrollTo(100, 119);
      expect(b.host.asked, isEmpty);
    });

    test('adding the same chart twice changes nothing', () {
      final a = chart();
      final b = chart();
      final link = ChartLink()
        ..add(a.controller)
        ..add(a.controller)
        ..add(b.controller);

      expect(link.length, 2);
      expect(link.controllers, [a.controller, b.controller]);

      a.host.scrollTo(100, 119);
      expect(b.host.asked, [(100, 119)], reason: 'pushed once, not twice');
    });

    test('disposing stops every chart following', () {
      final a = chart();
      final b = chart();
      ChartLink()
        ..add(a.controller)
        ..add(b.controller)
        ..dispose();

      a.host.scrollTo(100, 119);
      expect(b.host.asked, isEmpty);
    });

    test('syncFrom joins a chart to where the others already are', () {
      final a = chart(first: 100, last: 119);
      final b = chart();
      final link = ChartLink()
        ..add(a.controller)
        ..add(b.controller);

      expect(link.syncFrom(a.controller), isTrue);
      expect(b.host.asked.last, (100, 119));
    });

    test('syncFrom says so when there is no window yet', () {
      final link = ChartLink();
      final detached = KChartController();
      link.add(detached);

      expect(link.syncFrom(detached), isFalse);
    });

    test('the list it hands out cannot be edited behind its back', () {
      final link = ChartLink()..add(chart().controller);
      expect(
        () => link.controllers.add(KChartController()),
        throwsUnsupportedError,
      );
    });
  });
}
