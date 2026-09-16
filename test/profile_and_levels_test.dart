import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart/src/indicators/series_math.dart';
import 'package:ohlcv_chart/src/renderer/main_renderer.dart';

import 'test_utils.dart';

/// Records the rectangles a profile paints, and the colour of each.
///
/// The colour is kept packed, because a [Paint] holds its colour as floats and
/// a [Color] does not survive the round trip as an equal [Color].
class _Bars implements Canvas {
  final List<(Rect, int)> rects = [];

  /// Every rectangle painted in [color].
  Iterable<Rect> inColor(Color color) =>
      rects.where((b) => b.$2 == color.toARGB32()).map((b) => b.$1);

  @override
  void drawRect(Rect rect, Paint paint) =>
      rects.add((rect, paint.color.toARGB32()));
  @override
  void noSuchMethod(Invocation invocation) {}
}

/// Paints [indicator]'s profile over [data] into a recorder.
_Bars _paintProfile(
  Indicator indicator,
  List<KLineEntity> data, {
  ChartColors? colors,
  VerticalTextAlignment alignment = VerticalTextAlignment.right,
}) {
  final theme = colors ?? ChartColors();
  final resolved = ResolvedIndicator(
    indicator: indicator,
    series: indicator.compute(data),
    profile: indicator.computeProfile(data),
  );
  var low = double.infinity;
  var high = -double.infinity;
  for (final candle in data) {
    low = low < candle.low ? low : candle.low;
    high = high > candle.high ? high : candle.high;
  }

  final renderer = MainRenderer(
    const Rect.fromLTRB(0, 0, 400, 300),
    high,
    low,
    0,
    [resolved],
    false,
    2,
    ChartStyle(),
    theme,
    1,
    alignment,
    false,
  );
  final bars = _Bars();
  renderer.drawProfiles(bars);
  return bars;
}

/// Candles that rise on real up-bars and fall on real down-bars.
///
/// [candles] opens every candle at its close, which counts as a rise, so a
/// profile built from it never has a falling side to split off.
List<KLineEntity> _mixedDirections() {
  KLineEntity at(int minute, double open, double close) =>
      KLineEntity.fromCustom(
        open: open,
        high: (open > close ? open : close) + 1,
        low: (open < close ? open : close) - 1,
        close: close,
        vol: 100,
        dateTime: DateTime.utc(2024, 1, 1).add(Duration(minutes: minute)),
      );

  return [
    for (var i = 0; i < 20; i++) at(i, 100.0 + i, 101.0 + i),
    for (var i = 0; i < 20; i++) at(20 + i, 120.0 - i, 119.0 - i),
  ];
}

/// Two sessions of candles, a day apart, so the pivots have a session behind
/// them to be worked out from.
List<KLineEntity> _sessions() {
  KLineEntity at(DateTime time, double close, {double? high, double? low}) =>
      KLineEntity.fromCustom(
        open: close,
        high: high ?? close + 2,
        low: low ?? close - 2,
        close: close,
        vol: 100,
        dateTime: time,
      );

  return [
    at(DateTime.utc(2024, 1, 1, 9), 100, high: 110, low: 90),
    at(DateTime.utc(2024, 1, 1, 10), 105, high: 108, low: 95),
    at(DateTime.utc(2024, 1, 2, 9), 106),
    at(DateTime.utc(2024, 1, 2, 10), 104),
  ];
}

void main() {
  group('anchored VWAP', () {
    test('says nothing before its anchor', () {
      final data = candles([10, 20, 30, 40]);
      final values = anchoredVwapSeries(data, 2);

      expect(values[0], isNull);
      expect(values[1], isNull);
      expect(values[2], isNotNull);
      expect(values[3], isNotNull);
    });

    test('starts at the anchor candle and averages from there', () {
      final data = candles([10, 20, 30]);
      final values = anchoredVwapSeries(data, 1);

      // Every candle here carries the same volume, so the anchored average is
      // the mean of the typical prices since the anchor.
      double typical(KLineEntity c) => (c.high + c.low + c.close) / 3;
      expect(values[1], closeTo(typical(data[1]), 1e-9), reason: 'the anchor');
      expect(
        values[2],
        closeTo((typical(data[1]) + typical(data[2])) / 2, 1e-9),
      );
    });

    test('an anchor past the end is pulled back into the series', () {
      final data = candles([10, 20, 30]);
      final values = anchoredVwapSeries(data, 99);

      expect(values.last, isNotNull);
      expect(values.first, isNull);
    });

    test('an anchor of zero is the plain VWAP', () {
      final data = candles(rampThenFall(20));

      expect(anchoredVwapSeries(data, 0), vwapSeries(data));
    });

    test('the indicator carries its anchor in its identity', () {
      expect(
        AnchoredVwapIndicator(anchor: 5),
        isNot(AnchoredVwapIndicator(anchor: 9)),
      );
      expect(
        AnchoredVwapIndicator(anchor: 5),
        AnchoredVwapIndicator(anchor: 5),
      );
      expect(AnchoredVwapIndicator(anchor: 5).label, 'AVWAP(5)');
    });
  });

  group('pivot points', () {
    test('the first session has nothing behind it', () {
      final levels = pivotSeries(_sessions());

      expect(levels.first[0], isNull);
      expect(levels.first[1], isNull);
    });

    test("a session takes the last one's pivot", () {
      final levels = pivotSeries(_sessions());

      // The first session ran 90 to 110 and closed at 105.
      final pivot = (110 + 90 + 105) / 3;
      expect(levels[0][2], closeTo(pivot, 1e-9));
      expect(levels[0][3], closeTo(pivot, 1e-9), reason: 'flat all session');
    });

    test('the levels sit either side of the pivot, in order', () {
      final levels = pivotSeries(_sessions());
      final at = 2;

      final pivot = levels[0][at]!;
      final r1 = levels[1][at]!;
      final r2 = levels[2][at]!;
      final r3 = levels[3][at]!;
      final s1 = levels[4][at]!;
      final s2 = levels[5][at]!;
      final s3 = levels[6][at]!;

      expect(r1, greaterThan(pivot));
      expect(r2, greaterThan(r1));
      expect(r3, greaterThan(r2));
      expect(s1, lessThan(pivot));
      expect(s2, lessThan(s1));
      expect(s3, lessThan(s2));
    });

    test('fibonacci places its levels on the ratios', () {
      final levels = pivotSeries(_sessions(), method: PivotMethod.fibonacci);
      final pivot = levels[0][2]!;
      const range = 110 - 90;

      expect(levels[1][2], closeTo(pivot + 0.382 * range, 1e-9));
      expect(levels[2][2], closeTo(pivot + 0.618 * range, 1e-9));
      expect(levels[3][2], closeTo(pivot + range, 1e-9));
    });

    test('camarilla crowds its levels around the close', () {
      final standard = pivotSeries(_sessions());
      final camarilla = pivotSeries(_sessions(), method: PivotMethod.camarilla);

      final standardR1 = standard[1][2]! - standard[0][2]!;
      final camarillaR1 = camarilla[1][2]! - camarilla[0][2]!;
      expect(camarillaR1.abs(), lessThan(standardR1.abs()));
    });

    test('a session of its own can be nominated', () {
      // Split by the hour rather than the day: every candle is its own
      // session, so every one but the first carries levels.
      final levels = pivotSeries(
        _sessions(),
        sessionOf: (candle) => candle.dateTime?.hour,
      );

      expect(levels[0][0], isNull);
      expect(levels[0][1], isNotNull);
    });

    test('no candles is no levels', () {
      final levels = pivotSeries(const []);
      expect(levels, hasLength(7));
      expect(levels.first, isEmpty);
    });

    test('a session can be a week, a month or a year', () {
      final week = PivotSession.week;
      // The Monday of the week either date falls in is the same Monday.
      expect(
        week.keyOf(candle(1, minute: 0)),
        week.keyOf(
          KLineEntity.fromCustom(
            open: 1,
            high: 1,
            low: 1,
            close: 1,
            vol: 1,
            dateTime: DateTime.utc(2024, 1, 4),
          ),
        ),
      );
      expect(
        PivotSession.month.keyOf(
          KLineEntity.fromCustom(
            open: 1,
            high: 1,
            low: 1,
            close: 1,
            vol: 1,
            dateTime: DateTime.utc(2024, 3, 31),
          ),
        ),
        (2024, 3),
      );
      expect(
        PivotSession.year.keyOf(
          KLineEntity.fromCustom(
            open: 1,
            high: 1,
            low: 1,
            close: 1,
            vol: 1,
            dateTime: DateTime.utc(2024, 12, 31),
          ),
        ),
        2024,
      );
    });

    test('the session is part of the indicator, and of its label', () {
      final daily = PivotPointsIndicator();
      final weekly = PivotPointsIndicator(session: PivotSession.week);

      expect(daily, isNot(weekly));
      expect(daily.label, 'Pivots');
      expect(weekly.label, 'Pivots week');

      // Two candles a day apart are one weekly session, so the second carries
      // nothing where a daily pivot would already have levels.
      final levels = weekly.compute(_sessions()).lines;
      expect(levels[0][2], isNull);
      expect(
        PivotPointsIndicator().compute(_sessions()).lines[0][2],
        isNotNull,
      );
    });

    test('each method is its own indicator', () {
      expect(
        PivotPointsIndicator(),
        isNot(PivotPointsIndicator(method: PivotMethod.camarilla)),
      );
      expect(PivotPointsIndicator().name, 'PIVOT');
      expect(
        PivotPointsIndicator(method: PivotMethod.fibonacci).name,
        'PIVOTFIB',
      );
      expect(PivotPointsIndicator().lines, hasLength(7));
    });
  });

  group('volume profile', () {
    List<KLineEntity> traded() => [
          candle(100, high: 101, low: 99, vol: 10, minute: 0),
          candle(100, high: 101, low: 99, vol: 30, minute: 1),
          candle(110, high: 111, low: 109, vol: 5, minute: 2),
        ];

    test('gathers volume into bands of price', () {
      final profile = volumeProfile(traded(), bins: 12);

      expect(profile.bins, hasLength(12));
      expect(profile.bins.first.low, closeTo(99, 1e-9));
      expect(profile.bins.last.high, closeTo(111, 1e-9));
      expect(profile.isEmpty, isFalse);
    });

    test('the point of control is where the most traded', () {
      final profile = volumeProfile(traded(), bins: 12);
      final poc = profile.bins[profile.pointOfControl];

      // The 40 lots that changed hands around 100 dwarf the 5 up at 110.
      expect(poc.low, lessThan(105));
      expect(poc.volume, profile.peakVolume);
    });

    test('splits each band into what rose and what fell', () {
      final profile = volumeProfile([
        candle(100, open: 99, high: 101, low: 99, vol: 10, minute: 0),
        candle(99, open: 101, high: 101, low: 99, vol: 10, minute: 1),
      ], bins: 4);

      final total = profile.bins.fold<double>(0, (sum, b) => sum + b.volume);
      final up = profile.bins.fold<double>(0, (sum, b) => sum + b.upVolume);
      final down = profile.bins.fold<double>(0, (sum, b) => sum + b.downVolume);

      expect(total, closeTo(20, 1e-9));
      expect(up, closeTo(10, 1e-9));
      expect(down, closeTo(10, 1e-9));
    });

    test('the value area holds its share of the volume', () {
      final data = candles(rampThenFall(60));
      final profile = volumeProfile(data, bins: 20, valueArea: 0.7);

      final total = profile.bins.fold<double>(0, (sum, b) => sum + b.volume);
      final inside = profile.bins
          .where(
            (b) =>
                b.low >= profile.valueAreaLow! - 1e-9 &&
                b.high <= profile.valueAreaHigh! + 1e-9,
          )
          .fold<double>(0, (sum, b) => sum + b.volume);

      expect(inside / total, greaterThanOrEqualTo(0.7));
      expect(profile.valueAreaLow, lessThan(profile.valueAreaHigh!));
    });

    test('a flat market has nothing to profile', () {
      final flat = [
        KLineEntity.fromCustom(
          open: 10,
          high: 10,
          low: 10,
          close: 10,
          vol: 5,
          dateTime: DateTime.utc(2024),
        ),
      ];

      expect(volumeProfile(flat).isEmpty, isTrue);
      expect(volumeProfile(const []).pointOfControl, -1);
    });

    test('the indicator reads out its point of control', () {
      final indicator = VolumeProfileIndicator(bins: 12);
      final data = traded();
      final series = indicator.compute(data);
      final profile = indicator.computeProfile(data);

      final poc = profile.bins[profile.pointOfControl];
      expect(series.lines.first.first, closeTo((poc.low + poc.high) / 2, 1e-9));
      expect(indicator.label, 'Volume profile(12)');
    });

    test('each band is split into what rose and what fell', () {
      final theme = ChartColors()
        ..profileUpColor = const Color(0xff00ff00)
        ..profileDownColor = const Color(0xff0000ff)
        ..profilePocColor = const Color(0xffff0000)
        ..profileValueAreaColor = const Color(0x00000000);
      final bars = _paintProfile(
        VolumeProfileIndicator(bins: 10),
        _mixedDirections(),
        colors: theme,
      );

      final up = bars.inColor(theme.profileUpColor!).toList();
      final down = bars.inColor(theme.profileDownColor!).toList();

      expect(up, isNotEmpty, reason: 'the rise trades on rising candles');
      expect(down, isNotEmpty, reason: 'and the fall on falling ones');
      expect(
        bars.inColor(theme.profilePocColor!),
        hasLength(1),
        reason: 'exactly one point of control',
      );

      // The rising half starts at the outer edge and the falling half picks
      // up where it stops, so the two abut rather than overlap and the band
      // reads as one bar.
      for (final rising in up) {
        final falling = down.where((r) => r.top == rising.top);
        if (falling.isEmpty) continue;
        expect(rising.left, 0.0);
        expect(falling.first.left, closeTo(rising.right, 1e-9));
      }
    });

    test('the bars grow away from the price labels', () {
      // One colour throughout and no wash, so every rectangle recorded is a
      // whole band and its ends can be read straight off.
      final theme = ChartColors()
        ..profileColor = const Color(0xff00ff00)
        ..profilePocColor = const Color(0xff00ff00)
        ..profileValueAreaColor = const Color(0x00000000);
      final data = _mixedDirections();

      final labelsRight = _paintProfile(
        VolumeProfileIndicator(),
        data,
        colors: theme,
      );
      final labelsLeft = _paintProfile(
        VolumeProfileIndicator(),
        data,
        colors: theme,
        alignment: VerticalTextAlignment.left,
      );

      // Labels on the right, so the bars start at the left edge, and the other
      // way about. The transparent wash is skipped by colour, as it spans the
      // width either way and so tells the two apart on neither.
      final right = labelsRight.inColor(theme.profileColor!).toList();
      final left = labelsLeft.inColor(theme.profileColor!).toList();

      expect(right, isNotEmpty);
      expect(right.where((r) => r.left == 0.0), isNotEmpty);
      expect(right.map((r) => r.right), everyElement(lessThan(400.0)));
      expect(left.where((r) => r.right == 400.0), isNotEmpty);
      expect(left.map((r) => r.left), everyElement(greaterThan(0.0)));
    });

    test('the value area is washed across the whole width', () {
      final theme = ChartColors()
        ..profileValueAreaColor = const Color(0xff112233);
      final bars = _paintProfile(
        VolumeProfileIndicator(),
        _mixedDirections(),
        colors: theme,
      );

      final wash = bars.inColor(theme.profileValueAreaColor!).toList();
      expect(wash, hasLength(1));
      expect(wash.first.left, 0.0);
      expect(wash.first.right, 400.0);

      final profile = VolumeProfileIndicator().computeProfile(
        _mixedDirections(),
      );
      expect(profile.valueAreaHigh, isNotNull);
      expect(profile.valueAreaLow, lessThan(profile.valueAreaHigh!));
    });

    test('one profileColor draws every band whole', () {
      final theme = ChartColors()..profileColor = const Color(0xff445566);

      expect(theme.effectiveProfileUpColor, theme.profileColor);
      expect(theme.effectiveProfileDownColor, theme.profileColor);

      // Up and down being the same colour, the split shows only as two
      // rectangles that happen to abut. Ten bands, one of them the point of
      // control in its own colour, leaves nine split in two.
      final bars = _paintProfile(
        VolumeProfileIndicator(bins: 10),
        _mixedDirections(),
        colors: theme,
      );
      expect(bars.inColor(theme.profileColor!), hasLength(18));
    });

    test('the colours fall back to the candles', () {
      final theme = ChartColors();

      expect(theme.effectiveProfileUpColor.a, closeTo(0.35, 1e-6));
      expect(theme.effectiveProfileDownColor.a, closeTo(0.35, 1e-6));
      expect(
        theme.effectiveProfileUpColor.toARGB32() | 0xff000000,
        theme.upColor.toARGB32(),
      );
      expect(
        theme.effectiveProfileDownColor.toARGB32() | 0xff000000,
        theme.dnColor.toARGB32(),
      );
      expect(theme.effectiveProfileValueAreaColor.a, closeTo(0.08, 1e-6));
      expect(
        theme.effectiveProfileValueAreaColor.toARGB32() | 0xff000000,
        theme.effectiveProfilePocColor.toARGB32(),
      );
    });

    testWidgets('a chart draws one without complaint', (tester) async {
      final data = candles(rampThenFall(60));
      DataUtil.calculate(data);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              height: 600,
              child: KChartWidget(
                data,
                ChartColors(),
                isTrendLine: false,
                timeFrame: const Duration(minutes: 15),
                indicators: [
                  VolumeProfileIndicator(),
                  PivotPointsIndicator(),
                  AnchoredVwapIndicator(anchor: 10),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
