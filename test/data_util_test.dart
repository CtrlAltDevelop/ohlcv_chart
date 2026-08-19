import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart/src/utils/number_util.dart';

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

  group('NumberUtil.formatCompact', () {
    test('abbreviates large values in both directions', () {
      expect(NumberUtil.formatCompact(1234), '1234.00');
      expect(NumberUtil.formatCompact(25000), '25.00K');
      expect(NumberUtil.formatCompact(-25000), '-25.00K');
      expect(NumberUtil.formatCompact(-3.5e6), '-3.50M');
    });
  });

  group('calcEMA', () {
    test('weights recent closes more heavily than a simple average', () {
      final data = candles([for (var i = 0; i < 30; i++) 100.0 + i]);
      DataUtil.calcEMA(data, const [10]);
      DataUtil.calcMA(data, const [10]);

      // Rising prices put the exponential average above the simple one.
      expect(
        data.last.emaValueList![0],
        greaterThan(data.last.maValueList![0]),
      );
      // And it has a value from the very first candle.
      expect(data.first.emaValueList![0], closeTo(100, 1e-9));
    });

    test('a flat market leaves every average at the price', () {
      final data = candles([for (var i = 0; i < 20; i++) 50.0]);
      DataUtil.calcEMA(data, const [5, 10]);

      expect(data.last.emaValueList, everyElement(closeTo(50, 1e-9)));
    });
  });

  group('calcVWAP', () {
    test('sits at the typical price when every candle is identical', () {
      final data = [
        for (var i = 0; i < 5; i++) candle(100, vol: 10, minute: i),
      ];
      DataUtil.calcVWAP(data);

      // candle() spreads high and low one either side, so typical == close.
      expect(data.last.vwap, closeTo(100, 1e-9));
    });

    test('is pulled towards the price that traded the most volume', () {
      final data = [
        candle(100, vol: 1, minute: 0),
        candle(200, vol: 99, minute: 1),
      ];
      DataUtil.calcVWAP(data);

      expect(data.last.vwap, greaterThan(190));
    });

    test('survives candles with no volume', () {
      final data = [for (var i = 0; i < 3; i++) candle(100, vol: 0, minute: i)];
      DataUtil.calcVWAP(data);

      expect(data.every((e) => e.vwap!.isFinite), isTrue);
    });
  });

  group('calcATR', () {
    test('stays null until the first window is complete', () {
      final data = candles(rampThenFall(30));
      DataUtil.calcATR(data);

      expect(data.take(13).every((e) => e.atr == null), isTrue);
      expect(data[13].atr, isNotNull);
    });

    test('measures the candle range, not its direction', () {
      final wide = [
        for (var i = 0; i < 20; i++) candle(100, high: 110, low: 90, minute: i),
      ];
      final narrow = [
        for (var i = 0; i < 20; i++) candle(100, high: 101, low: 99, minute: i),
      ];
      DataUtil.calcATR(wide);
      DataUtil.calcATR(narrow);

      expect(wide.last.atr!, greaterThan(narrow.last.atr!));
      expect(wide.last.atr!, closeTo(20, 1e-6));
    });
  });

  group('calcOBV', () {
    test('adds volume on up candles and subtracts it on down candles', () {
      final data = [
        candle(100, vol: 10, minute: 0),
        candle(101, vol: 10, minute: 1),
        candle(102, vol: 10, minute: 2),
        candle(101, vol: 4, minute: 3),
        candle(101, vol: 7, minute: 4),
      ];
      DataUtil.calcOBV(data);

      expect(data.map((e) => e.obv), [0, 10, 20, 16, 16]);
    });
  });

  group('calcMFI', () {
    test('pins to 100 when every candle closes higher', () {
      final data = candles([for (var i = 0; i < 30; i++) 100.0 + i]);
      DataUtil.calcMFI(data);

      expect(data.take(14).every((e) => e.mfi == null), isTrue);
      expect(data.last.mfi, closeTo(100, 1e-9));
    });

    test('stays low through a sustained decline', () {
      final data = candles([for (var i = 0; i < 30; i++) 200.0 - i]);
      DataUtil.calcMFI(data);

      expect(data.last.mfi!, lessThan(20));
    });
  });

  group('calcDMI', () {
    test('+DI leads -DI while price is rising', () {
      final data = candles([for (var i = 0; i < 60; i++) 100.0 + i]);
      DataUtil.calcDMI(data);

      expect(data.last.pdi!, greaterThan(data.last.mdi!));
      expect(data.last.adx, isNotNull);
      expect(data.last.adx!, inInclusiveRange(0, 100));
    });

    test('-DI leads +DI while price is falling', () {
      final data = candles([for (var i = 0; i < 60; i++) 200.0 - i]);
      DataUtil.calcDMI(data);

      expect(data.last.mdi!, greaterThan(data.last.pdi!));
    });

    test('warms up the directional indicators before the ADX', () {
      final data = candles(rampThenFall(60));
      DataUtil.calcDMI(data);

      expect(data[13].pdi, isNull);
      expect(data[14].pdi, isNotNull);
      // The ADX needs a second window on top of the DI one.
      expect(data[20].adx, isNull);
      expect(data[27].adx, isNotNull);
    });
  });
}
