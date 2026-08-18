import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

import 'test_utils.dart';

void main() {
  group('calculate', () {
    test('accepts an empty list without throwing', () {
      expect(() => DataUtil.calculate([]), returnsNormally);
    });

    test('accepts a list shorter than every indicator period', () {
      final data = candles([100, 101, 102]);
      expect(() => DataUtil.calculate(data), returnsNormally);
    });

    test('fills every indicator field once enough candles exist', () {
      final data = candles(rampThenFall(60));
      DataUtil.calculate(data);

      final last = data.last;
      expect(last.maValueList, isNotNull);
      expect(last.up, isNotNull);
      expect(last.dn, isNotNull);
      expect(last.sar, isNotNull);
      expect(last.macd, isNotNull);
      expect(last.k, isNotNull);
      expect(last.rsi, isNotNull);
      expect(last.r, isNotNull);
      expect(last.cci, isNotNull);
      expect(last.ma5Volume, isNotNull);
    });

    test('never produces NaN or infinite indicator values', () {
      final data = candles(rampThenFall(80));
      DataUtil.calculate(data);

      for (final e in data) {
        for (final v in <double?>[
          e.bollMa,
          e.up,
          e.dn,
          e.sar,
          e.dif,
          e.dea,
          e.macd,
          e.k,
          e.d,
          e.j,
          e.rsi,
          e.r,
          e.cci,
        ]) {
          if (v != null) expect(v.isFinite, isTrue, reason: 'got $v');
        }
      }
    });

    test('is stable when every candle has the same price', () {
      final data = candles(List.filled(40, 100));
      expect(() => DataUtil.calculate(data), returnsNormally);
      for (final e in data) {
        expect(e.cci?.isFinite ?? true, isTrue);
        expect(e.k?.isFinite ?? true, isTrue);
      }
    });
  });

  group('calcMA', () {
    test('starts at the period boundary and averages the window', () {
      final data = candles([1, 2, 3, 4, 5, 6]);
      DataUtil.calcMA(data, [3]);

      // Warm-up entries stay at the zero fill.
      expect(data[1].maValueList![0], 0);
      // (1+2+3)/3
      expect(data[2].maValueList![0], closeTo(2, 1e-9));
      // (4+5+6)/3
      expect(data[5].maValueList![0], closeTo(5, 1e-9));
    });
  });

  group('calcBOLL', () {
    test('brackets the middle band symmetrically', () {
      final data = candles(rampThenFall(40));
      DataUtil.calcBOLL(data, 20, 2);

      final last = data.last;
      expect(last.up! > last.mb!, isTrue);
      expect(last.dn! < last.mb!, isTrue);
      expect(last.up! - last.mb!, closeTo(last.mb! - last.dn!, 1e-9));
    });
  });

  group('calcRSI', () {
    test('pins to 100 on an unbroken advance and stays in range', () {
      final data = candles([for (var i = 0; i < 40; i++) 100.0 + i]);
      DataUtil.calcRSI(data);

      expect(data[12].rsi, isNull, reason: 'warm-up is not reported');
      expect(data.last.rsi, closeTo(100, 1e-6));
      for (final e in data) {
        if (e.rsi != null) expect(e.rsi!, inInclusiveRange(0, 100));
      }
    });
  });

  group('calcWR', () {
    test('stays within the -100..0 band', () {
      final data = candles(rampThenFall(50));
      DataUtil.calcWR(data);

      for (var i = 13; i < data.length; i++) {
        final r = data[i].r;
        if (r != null) expect(r, inInclusiveRange(-100, 0));
      }
    });
  });

  group('calcSAR', () {
    test('resets the acceleration factor identically in both directions', () {
      // A clean up-leg followed by a clean down-leg forces one reversal each
      // way; the SAR must stay finite and flip sides of the price.
      final data = candles(rampThenFall(60));
      DataUtil.calcSAR(data);

      expect(data.every((e) => e.sar!.isFinite), isTrue);

      final above = data.where((e) => e.sar! > e.high).length;
      final below = data.where((e) => e.sar! < e.low).length;
      expect(above, greaterThan(0));
      expect(below, greaterThan(0));
    });
  });

  group('calcMACD', () {
    test('keeps macd equal to twice the dif/dea spread', () {
      final data = candles(rampThenFall(40));
      DataUtil.calcMACD(data);

      for (final e in data) {
        expect(e.macd!, closeTo((e.dif! - e.dea!) * 2, 1e-9));
      }
    });

    test('goes negative on a sustained decline', () {
      final data = candles([for (var i = 0; i < 40; i++) 200.0 - i]);
      DataUtil.calcMACD(data);
      expect(data.last.macd!, lessThan(0));
      expect(data.last.dif!, lessThan(0));
    });
  });

  group('calcVolumeMA', () {
    test('averages the trailing volume window', () {
      final data = [
        for (var i = 0; i < 12; i++) candle(100, vol: 10, minute: i),
      ];
      DataUtil.calcVolumeMA(data);

      expect(data[3].ma5Volume, 0, reason: 'warm-up');
      expect(data[4].ma5Volume, closeTo(10, 1e-9));
      expect(data[9].ma10Volume, closeTo(10, 1e-9));
    });
  });
}
