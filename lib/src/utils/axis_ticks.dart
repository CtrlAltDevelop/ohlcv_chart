/// Round values for an axis to label and rule itself by.
///
/// A chart that divides its box into equal pixel bands and then reads back
/// whatever value lands on each one prints an axis of `70429, 69745, 69060`.
/// The functions here do the reverse — choose the round numbers first, then
/// let the renderer place them — so the same axis reads `70000, 69500, 69000`.
library;

import 'dart:math' as math;

/// The step sizes an axis is allowed to take, within one power of ten.
const List<double> _mantissas = [1.0, 2.0, 2.5, 5.0, 10.0];

/// However many steps are asked for, never return more than this many ticks.
///
/// Floating-point noise in a degenerate range could otherwise spin out a very
/// long list, and nothing legible needs more.
const int _maxTicks = 64;

/// The smallest allowed step of about `span / target`, as one of 1, 2, 2.5 or
/// 5 times a power of ten.
double niceStep(double span, int target) {
  if (!span.isFinite || span <= 0 || target <= 0) return 0;

  final raw = span / target;
  final magnitude = math
      .pow(10, (math.log(raw) / math.ln10).floor())
      .toDouble();
  if (magnitude <= 0 || !magnitude.isFinite) return 0;

  final normalized = raw / magnitude;
  for (final mantissa in _mantissas) {
    if (normalized <= mantissa) return mantissa * magnitude;
  }
  return 10 * magnitude;
}

/// Round values inside `[min, max]`, about [target] of them.
///
/// Returns an empty list for a range that cannot be divided — a flat or
/// backwards one, or one holding a value that is not finite.
List<double> niceTicks(double min, double max, {int target = 5}) {
  if (!min.isFinite || !max.isFinite || max <= min) return const [];

  final step = niceStep(max - min, target);
  if (step <= 0) return const [];

  // Both ends are nudged by a thousandth of a step so a tick that lands
  // exactly on the boundary is not lost to floating-point drift.
  final epsilon = step / 1000;
  final ticks = <double>[];
  var value = (min / step).ceil() * step;
  while (value <= max + epsilon && ticks.length < _maxTicks) {
    // Re-round each tick: repeated addition of, say, 0.1 drifts, and the label
    // is formatted straight off this value.
    ticks.add((value / step).roundToDouble() * step);
    value += step;
  }
  return ticks;
}

/// Round values inside `[min, max]` spaced by ratio rather than by difference,
/// for a logarithmic axis.
///
/// Walks 1, 2 and 5 times each power of ten the range covers. A range too
/// narrow to hold three of those — an intraday window on a big number — has no
/// useful decade structure, so it falls back to [niceTicks].
List<double> niceLogTicks(double min, double max, {int target = 5}) {
  if (!min.isFinite || !max.isFinite || max <= min || min <= 0) {
    return niceTicks(min, max, target: target);
  }

  final lowDecade = (math.log(min) / math.ln10).floor();
  final highDecade = (math.log(max) / math.ln10).ceil();

  final ticks = <double>[];
  for (var decade = lowDecade; decade <= highDecade; decade++) {
    final magnitude = math.pow(10, decade).toDouble();
    for (final mantissa in const [1.0, 2.0, 5.0]) {
      final value = mantissa * magnitude;
      if (value < min || value > max) continue;
      ticks.add(value);
      if (ticks.length >= _maxTicks) return ticks;
    }
  }

  return ticks.length < 3 ? niceTicks(min, max, target: target) : ticks;
}

/// The steps a time axis is allowed to take, from a second to a year.
///
/// Every one of them divides its own larger unit evenly, which is what lets a
/// label land on a round clock time rather than an arbitrary offset from one.
const List<Duration> _timeSteps = [
  Duration(seconds: 1),
  Duration(seconds: 5),
  Duration(seconds: 15),
  Duration(seconds: 30),
  Duration(minutes: 1),
  Duration(minutes: 5),
  Duration(minutes: 15),
  Duration(minutes: 30),
  Duration(hours: 1),
  Duration(hours: 2),
  Duration(hours: 4),
  Duration(hours: 6),
  Duration(hours: 12),
  Duration(days: 1),
  Duration(days: 2),
  Duration(days: 7),
  Duration(days: 14),
  Duration(days: 30),
  Duration(days: 90),
  Duration(days: 180),
  Duration(days: 365),
];

/// How far below the ideal step a coarser one may still be taken.
///
/// The ladder is uneven — it jumps from a week straight to a fortnight — so
/// insisting on a step no finer than `span / target` would label a month of
/// daily candles twice instead of weekly. A step within a fifth of the ideal
/// counts as close enough, which costs a label or so and keeps the round unit.
const double _timeStepTolerance = 0.8;

/// The smallest round step that fits about [target] labels across [span].
Duration niceTimeStep(Duration span, {int target = 4}) {
  if (span <= Duration.zero || target <= 0) return _timeSteps.first;

  final wanted = span.inMilliseconds / target * _timeStepTolerance;
  for (final step in _timeSteps) {
    if (step.inMilliseconds >= wanted) return step;
  }
  return _timeSteps.last;
}

/// Whether a step is coarse enough that it should follow the calendar rather
/// than a fixed number of milliseconds.
///
/// Months and years are not a whole number of days, so flooring an epoch to a
/// 30- or 365-day multiple drifts away from the first of the month.
bool _isCalendarStep(Duration step) => step >= const Duration(days: 28);

/// The bucket [time] falls in, for a step of [step].
///
/// Two times share a bucket when no label belongs between them; a tick is
/// placed wherever the bucket changes from one candle to the next.
///
/// [time] is read as a wall clock, not as an instant. A label has to land on a
/// round time *as the chart prints it*, and the chart prints the display time
/// zone — so flooring the underlying epoch would put the boundaries on round
/// UTC hours, which in a zone offset by half an hour is not round at all.
int timeBucket(DateTime time, Duration step) {
  if (_isCalendarStep(step)) {
    if (step >= const Duration(days: 365)) return time.year;
    final months = step.inDays >= 90 ? 3 : 1;
    return time.year * 12 + (time.month - 1) ~/ months;
  }
  final wallClock = DateTime.utc(
    time.year,
    time.month,
    time.day,
    time.hour,
    time.minute,
    time.second,
  );
  return wallClock.millisecondsSinceEpoch ~/ step.inMilliseconds;
}

/// Whether a label at [time] should name the day rather than the clock time.
///
/// A sub-daily axis reads as a run of times — `06:00, 12:00, 18:00` — with the
/// date promoted at the boundary where the day turns over, which is how a
/// trader tells one session from the next.
bool startsNewDay(DateTime time, DateTime? previous) =>
    previous == null ||
    time.year != previous.year ||
    time.month != previous.month ||
    time.day != previous.day;
