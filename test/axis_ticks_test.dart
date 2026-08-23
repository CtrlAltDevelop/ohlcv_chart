import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/src/utils/axis_ticks.dart';

void main() {
  group('niceStep', () {
    test('picks a round step near span / target', () {
      expect(niceStep(100, 5), 20);
      expect(niceStep(1, 5), 0.2);
      expect(niceStep(5486, 4), 2000);
    });

    test('is one of 1, 2, 2.5 or 5 times a power of ten', () {
      for (var span = 0.01; span < 1e6; span *= 1.37) {
        final step = niceStep(span, 5);
        final mantissa = step / _powerOfTenBelow(step);
        expect(
          const [1.0, 2.0, 2.5, 5.0, 10.0],
          contains(closeTo(mantissa, 1e-9)),
          reason: 'span $span gave step $step',
        );
      }
    });

    test('has no step for a range that cannot be divided', () {
      expect(niceStep(0, 5), 0);
      expect(niceStep(-10, 5), 0);
      expect(niceStep(double.nan, 5), 0);
      expect(niceStep(100, 0), 0);
    });
  });

  group('niceTicks', () {
    test('labels round prices rather than the ends of the range', () {
      // The range the screenshot in the README was drawn from, which used to
      // print 70429, 69745, 69060, 68376.
      final ticks = niceTicks(64955, 70441, target: 4);
      expect(ticks, [66000, 68000, 70000]);
    });

    test('stays inside the range', () {
      final ticks = niceTicks(3.3, 9.1, target: 5);
      expect(ticks.first, greaterThanOrEqualTo(3.3));
      expect(ticks.last, lessThanOrEqualTo(9.1));
    });

    test('is evenly spaced', () {
      final ticks = niceTicks(0, 97, target: 5);
      final gaps = [
        for (var i = 1; i < ticks.length; i++) ticks[i] - ticks[i - 1],
      ];
      expect(gaps.every((gap) => (gap - gaps.first).abs() < 1e-9), isTrue);
    });

    test('does not drift on a fractional step', () {
      final ticks = niceTicks(0, 1, target: 5);
      expect(ticks, [0, 0.2, 0.4, 0.6000000000000001, 0.8, 1.0]);
      // Each one is a clean multiple of the step, whatever its binary form.
      for (final tick in ticks) {
        expect((tick * 5) - (tick * 5).roundToDouble(), closeTo(0, 1e-9));
      }
    });

    test('keeps a tick that lands exactly on either end', () {
      expect(niceTicks(0, 100, target: 5), [0, 20, 40, 60, 80, 100]);
    });

    test('gives nothing back for a range with no width', () {
      expect(niceTicks(5, 5), isEmpty);
      expect(niceTicks(9, 3), isEmpty);
      expect(niceTicks(double.nan, 3), isEmpty);
      expect(niceTicks(0, double.infinity), isEmpty);
    });
  });

  group('niceLogTicks', () {
    test('steps by ratio across decades', () {
      expect(niceLogTicks(0.8, 1200), [
        1,
        2,
        5,
        10,
        20,
        50,
        100,
        200,
        500,
        1000,
      ]);
    });

    test('falls back to linear ticks in a range too narrow for decades', () {
      // An intraday window on a big number holds no decade structure at all.
      expect(
        niceLogTicks(69000, 70000, target: 4),
        niceTicks(69000, 70000, target: 4),
      );
    });

    test('falls back for a range a logarithm cannot take', () {
      expect(niceLogTicks(-5, 5, target: 4), niceTicks(-5, 5, target: 4));
    });
  });

  group('niceTimeStep', () {
    test('picks a round step for the span on screen', () {
      expect(
        niceTimeStep(const Duration(hours: 24), target: 4),
        const Duration(hours: 6),
      );
      expect(
        niceTimeStep(const Duration(minutes: 60), target: 4),
        const Duration(minutes: 15),
      );
      expect(
        niceTimeStep(const Duration(days: 30), target: 4),
        const Duration(days: 7),
      );
    });

    test('never runs past the coarsest step it knows', () {
      expect(
        niceTimeStep(const Duration(days: 365 * 100), target: 4),
        const Duration(days: 365),
      );
    });

    test('takes the finest step for a span with no width', () {
      expect(niceTimeStep(Duration.zero), const Duration(seconds: 1));
    });
  });

  group('timeBucket', () {
    test('groups times that share a step', () {
      const step = Duration(hours: 6);
      final a = DateTime.utc(2026, 8, 20, 6);
      final b = DateTime.utc(2026, 8, 20, 11, 59);
      final c = DateTime.utc(2026, 8, 20, 12);
      expect(timeBucket(a, step), timeBucket(b, step));
      expect(timeBucket(c, step), isNot(timeBucket(b, step)));
    });

    test('follows the calendar for a monthly step', () {
      // 30 days of milliseconds would drift off the first of the month; these
      // two are one month apart but 31 days.
      const step = Duration(days: 30);
      expect(
        timeBucket(DateTime.utc(2026, 1, 31), step),
        isNot(timeBucket(DateTime.utc(2026, 2, 1), step)),
      );
      expect(
        timeBucket(DateTime.utc(2026, 2, 1), step),
        timeBucket(DateTime.utc(2026, 2, 28), step),
      );
    });

    test('groups by quarter and by year for the coarsest steps', () {
      expect(
        timeBucket(DateTime.utc(2026, 1, 5), const Duration(days: 90)),
        timeBucket(DateTime.utc(2026, 3, 20), const Duration(days: 90)),
      );
      expect(
        timeBucket(DateTime.utc(2026, 1, 5), const Duration(days: 365)),
        timeBucket(DateTime.utc(2026, 12, 20), const Duration(days: 365)),
      );
    });
  });

  group('timeBucket reads a wall clock, not an instant', () {
    test('boundaries land on round displayed times in a half-hour zone', () {
      // Asia/Tehran is UTC+03:30. Flooring the epoch would put a six-hour
      // boundary on 09:30 local rather than on a round local hour.
      const step = Duration(hours: 6);
      final morning = DateTime.utc(2026, 8, 20, 5, 59); // read as wall clock
      final noon = DateTime.utc(2026, 8, 20, 6, 0);
      expect(timeBucket(morning, step), isNot(timeBucket(noon, step)));
      expect(
        timeBucket(noon, step),
        timeBucket(DateTime.utc(2026, 8, 20, 11, 59), step),
      );
    });

    test('a zone offset does not shift where the boundary falls', () {
      const step = Duration(hours: 6);
      // The same wall clock in two different DateTime flavours buckets alike,
      // because only the printed fields matter.
      final asUtc = DateTime.utc(2026, 8, 20, 12);
      final asLocal = DateTime(2026, 8, 20, 12);
      expect(timeBucket(asUtc, step), timeBucket(asLocal, step));
    });
  });

  group('startsNewDay', () {
    test('is true at the first label and where the day turns over', () {
      expect(startsNewDay(DateTime.utc(2026, 8, 20, 6), null), isTrue);
      expect(
        startsNewDay(DateTime.utc(2026, 8, 21), DateTime.utc(2026, 8, 20, 18)),
        isTrue,
      );
      expect(
        startsNewDay(
          DateTime.utc(2026, 8, 20, 18),
          DateTime.utc(2026, 8, 20, 12),
        ),
        isFalse,
      );
    });
  });
}

/// The largest power of ten no bigger than [value].
double _powerOfTenBelow(double value) {
  var magnitude = 1.0;
  while (magnitude * 10 <= value) {
    magnitude *= 10;
  }
  while (magnitude > value) {
    magnitude /= 10;
  }
  return magnitude;
}
