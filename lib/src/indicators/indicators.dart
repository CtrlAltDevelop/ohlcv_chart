import 'dart:math' show max;

import 'package:flutter/material.dart' show Color;

import '../chart_style.dart';
import '../entity/k_line_entity.dart';
import 'indicator.dart';
import 'series_math.dart';

// ── Overlays ───────────────────────────────────────────────────────────────

/// A simple moving average of the close, drawn over the candles.
class MaIndicator extends Indicator {
  /// Creates a moving average over [period] candles.
  MaIndicator({this.period = 5, Color? color})
      : super(colors: color == null ? null : [color]);

  /// How many candles the average covers.
  final int period;

  @override
  IndicatorPlacement get placement => IndicatorPlacement.overlay;

  @override
  String get name => 'MA';

  @override
  String get label => 'MA($period)';

  @override
  List<IndicatorLine> get lines => [IndicatorLine('MA$period')];

  @override
  List<Object?> get settings => [period];

  @override
  IndicatorFormat get format => IndicatorFormat.price;

  @override
  IndicatorSeries compute(List<KLineEntity> candles) =>
      IndicatorSeries([smaSeries(candles, period)]);

  @override
  IndicatorSeries? extendSeries(
    List<KLineEntity> candles,
    IndicatorSeries previous,
    int from,
  ) =>
      IndicatorSeries([
        graftTail(
          candles,
          previous.lines[0],
          from,
          period - 1,
          (slice) => smaSeries(slice, period),
        ),
      ]);

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) =>
      theme.getMAColor(ordinal);
}

/// An exponential moving average of the close, drawn over the candles.
class EmaIndicator extends Indicator {
  /// Creates an exponential average over [period] candles.
  EmaIndicator({this.period = 5, Color? color})
      : super(colors: color == null ? null : [color]);

  /// How many candles the average covers.
  final int period;

  @override
  IndicatorPlacement get placement => IndicatorPlacement.overlay;

  @override
  String get name => 'EMA';

  @override
  String get label => 'EMA($period)';

  @override
  List<IndicatorLine> get lines => [IndicatorLine('EMA$period')];

  @override
  List<Object?> get settings => [period];

  @override
  IndicatorFormat get format => IndicatorFormat.price;

  @override
  IndicatorSeries compute(List<KLineEntity> candles) =>
      IndicatorSeries([emaSeries(candles, period)]);

  @override
  IndicatorSeries? extendSeries(
    List<KLineEntity> candles,
    IndicatorSeries previous,
    int from,
  ) {
    final line = emaTail(candles, period, previous.lines[0], from);
    return line == null ? null : IndicatorSeries([line]);
  }

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) =>
      theme.getEMAColor(ordinal);
}

/// Bollinger bands: a moving average with a band either side of it.
class BollIndicator extends Indicator {
  /// Creates bands [deviations] standard deviations wide over [period] candles.
  BollIndicator({this.period = 20, this.deviations = 2, super.colors});

  /// How many candles the middle average covers.
  final int period;

  /// How many standard deviations the bands sit from the average.
  final double deviations;

  @override
  IndicatorPlacement get placement => IndicatorPlacement.overlay;

  @override
  String get name => 'BOLL';

  @override
  String get label => 'BOLL($period,${_trim(deviations)})';

  @override
  List<IndicatorLine> get lines => [
        IndicatorLine('BOLL'),
        IndicatorLine('UB'),
        IndicatorLine('LB'),
      ];

  @override
  List<Object?> get settings => [period, deviations];

  @override
  IndicatorFormat get format => IndicatorFormat.price;

  @override
  IndicatorSeries compute(List<KLineEntity> candles) {
    final bands = bollSeries(candles, period, deviations);
    return IndicatorSeries([bands.middle, bands.upper, bands.lower]);
  }

  @override
  IndicatorSeries? extendSeries(
    List<KLineEntity> candles,
    IndicatorSeries previous,
    int from,
  ) =>
      IndicatorSeries(
        // The bands warm up a candle after the average they sit around, so the
        // window is `period` rather than `period - 1`.
        graftTailLines(candles, previous.lines, from, period, (slice) {
          final bands = bollSeries(slice, period, deviations);
          return [bands.middle, bands.upper, bands.lower];
        }),
      );

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) =>
      switch (line) {
        1 => theme.ma10Color,
        2 => theme.ma30Color,
        _ => theme.ma5Color,
      };
}

/// Parabolic SAR: one dot per candle, flipping side with the trend.
class SarIndicator extends Indicator {
  /// Creates a SAR with the usual acceleration settings.
  SarIndicator({
    this.start = 0.02,
    this.step = 0.02,
    this.maximum = 0.2,
    Color? color,
  }) : super(colors: color == null ? null : [color]);

  /// Acceleration factor a new trend starts at.
  final double start;

  /// How much the acceleration factor grows at each new extreme.
  final double step;

  /// Ceiling on the acceleration factor.
  final double maximum;

  @override
  IndicatorPlacement get placement => IndicatorPlacement.overlay;

  @override
  String get name => 'SAR';

  @override
  String get label => 'SAR(${_trim(step)},${_trim(maximum)})';

  @override
  List<IndicatorLine> get lines => [
        IndicatorLine('SAR', shape: IndicatorShape.dots),
      ];

  @override
  List<Object?> get settings => [start, step, maximum];

  @override
  IndicatorFormat get format => IndicatorFormat.price;

  @override
  IndicatorSeries compute(List<KLineEntity> candles) => IndicatorSeries([
        sarSeries(candles, start: start, step: step, maximum: maximum),
      ]);

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) =>
      theme.sarColor;

  @override
  Color? colorForPoint(
    int line,
    int index,
    KLineEntity candle,
    double value,
    ChartColors theme,
  ) {
    // Only tint the dots while the caller has not chosen a colour of its own.
    if (colors != null) return null;
    final middle = (candle.high + candle.low) / 2;
    if (value == middle) return theme.avgColor;
    return value < middle ? theme.upColor : theme.dnColor;
  }
}

/// Volume-weighted average price, accumulated over the candles given.
class VwapIndicator extends Indicator {
  /// Creates a VWAP line.
  VwapIndicator({Color? color}) : super(colors: color == null ? null : [color]);

  @override
  IndicatorPlacement get placement => IndicatorPlacement.overlay;

  @override
  String get name => 'VWAP';

  @override
  String get label => 'VWAP';

  @override
  List<IndicatorLine> get lines => [IndicatorLine('VWAP')];

  @override
  List<Object?> get settings => const [];

  @override
  IndicatorFormat get format => IndicatorFormat.price;

  @override
  IndicatorSeries compute(List<KLineEntity> candles) =>
      IndicatorSeries([vwapSeries(candles)]);

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) =>
      theme.vwapColor;
}

/// Volume-weighted average price measured from one candle onwards.
///
/// The plain [VwapIndicator] averages the whole series; this one starts where
/// it is anchored, which is what makes it a reading of what a position opened
/// there has paid on average since. Anchors go on a swing high or low, a gap,
/// or the open of a session.
class AnchoredVwapIndicator extends Indicator {
  /// Creates a VWAP anchored at the candle [anchor] counts in.
  AnchoredVwapIndicator({this.anchor = 0, Color? color})
      : super(colors: color == null ? null : [color]);

  /// Which candle the average is measured from, as an index into the series.
  ///
  /// Out-of-range values are pulled back into it, so a chart that has since
  /// scrolled past its anchor still draws.
  final int anchor;

  @override
  IndicatorPlacement get placement => IndicatorPlacement.overlay;

  @override
  String get name => 'AVWAP';

  @override
  String get label => 'AVWAP($anchor)';

  @override
  String get group => 'AVWAP';

  @override
  List<IndicatorLine> get lines => [IndicatorLine('AVWAP')];

  @override
  List<Object?> get settings => [anchor];

  @override
  IndicatorFormat get format => IndicatorFormat.price;

  @override
  IndicatorSeries compute(List<KLineEntity> candles) =>
      IndicatorSeries([anchoredVwapSeries(candles, anchor)]);

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) =>
      theme.vwapColor;
}

/// VWAP restarted at every session boundary, with a band either side.
///
/// The plain [VwapIndicator] averages the whole series and [AnchoredVwapIndicator]
/// measures from a candle you pick; this one begins again each session, which is
/// what a desk means by the word — what has been paid on average *today*, not
/// since the history happened to start.
///
/// The bands are [deviations] volume-weighted standard deviations from that
/// average, so they say how far from it the session has been trading. Set
/// [deviations] to zero to draw the average alone; the band lines stay in the
/// legend and simply hold no values.
class SessionVwapIndicator extends Indicator {
  /// Creates a VWAP restarting each [session], banded at [deviations].
  SessionVwapIndicator({
    this.session = PivotSession.day,
    this.deviations = 1,
    super.colors,
  });

  /// How often the average begins again.
  final PivotSession session;

  /// How many volume-weighted standard deviations the bands sit either side.
  final double deviations;

  @override
  IndicatorPlacement get placement => IndicatorPlacement.overlay;

  // One name per catalog entry, as the pivots do it: the entry that rebuilds
  // an indicator is found by name first, so a weekly VWAP must not answer to
  // the daily one's.
  @override
  String get name => switch (session) {
        PivotSession.day => 'SVWAP',
        PivotSession.week => 'SVWAPW',
        PivotSession.month => 'SVWAPM',
        PivotSession.year => 'SVWAPY',
      };

  @override
  String get label => deviations > 0
      ? 'VWAP(${_sessionLabel(session)},${_trim(deviations)})'
      : 'VWAP(${_sessionLabel(session)})';

  @override
  List<IndicatorLine> get lines => [
        IndicatorLine('VWAP'),
        IndicatorLine('UB'),
        IndicatorLine('LB'),
      ];

  // The numeric setting comes first: a catalog entry reads these positionally,
  // and stops at the first one that is not a number.
  @override
  List<Object?> get settings => [deviations, session];

  @override
  IndicatorFormat get format => IndicatorFormat.price;

  @override
  IndicatorSeries compute(List<KLineEntity> candles) {
    final series = sessionVwapSeries(
      candles,
      session: session,
      deviations: deviations,
    );
    return IndicatorSeries([series.vwap, series.upper, series.lower]);
  }

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) =>
      line == 0 ? theme.vwapColor : theme.avgColor;
}

/// Writes a session the way a platform labels it: `D`, `W`, `M`, `Y`.
String _sessionLabel(PivotSession session) => switch (session) {
      PivotSession.day => 'D',
      PivotSession.week => 'W',
      PivotSession.month => 'M',
      PivotSession.year => 'Y',
    };

/// The pivot of the session before, with its supports and resistances.
///
/// Each session takes its levels from the one that closed before it, so they
/// are flat across the session and step at its boundary. The first session has
/// none, having nothing behind it.
class PivotPointsIndicator extends Indicator {
  /// Creates pivot levels worked out by [method] over each [session].
  PivotPointsIndicator({
    this.method = PivotMethod.standard,
    this.session = PivotSession.day,
    super.colors,
  });

  /// How the levels are spaced out from the pivot.
  final PivotMethod method;

  /// The stretch of time one set of levels is worked out from.
  final PivotSession session;

  @override
  IndicatorPlacement get placement => IndicatorPlacement.overlay;

  @override
  String get name {
    final spacing = switch (method) {
      PivotMethod.standard => 'PIVOT',
      PivotMethod.fibonacci => 'PIVOTFIB',
      PivotMethod.camarilla => 'PIVOTCAM',
    };
    // The session is part of the name, so a weekly pivot is a different
    // indicator from a daily one and the catalog can tell them apart. The day
    // is the usual session and keeps the plain name.
    return switch (session) {
      PivotSession.day => spacing,
      PivotSession.week => '${spacing}W',
      PivotSession.month => '${spacing}M',
      PivotSession.year => '${spacing}Y',
    };
  }

  @override
  String get label {
    final spacing = switch (method) {
      PivotMethod.standard => 'Pivots',
      PivotMethod.fibonacci => 'Pivots (fib)',
      PivotMethod.camarilla => 'Pivots (camarilla)',
    };
    // The day is the usual session, so only an unusual one is worth the room.
    return session == PivotSession.day ? spacing : '$spacing ${session.name}';
  }

  @override
  List<IndicatorLine> get lines => const [
        IndicatorLine('P'),
        IndicatorLine('R1'),
        IndicatorLine('R2'),
        IndicatorLine('R3'),
        IndicatorLine('S1'),
        IndicatorLine('S2'),
        IndicatorLine('S3'),
      ];

  @override
  List<Object?> get settings => [method, session];

  @override
  IndicatorFormat get format => IndicatorFormat.price;

  @override
  IndicatorSeries compute(List<KLineEntity> candles) => IndicatorSeries(
        pivotSeries(candles, method: method, sessionOf: session.keyOf),
      );

  @override
  Color defaultColor(
    int line,
    ChartColors theme,
    int ordinal,
  ) =>
      switch (line) {
        // The pivot itself carries the session; the supports and resistances take
        // the up and down colours, fading with how far out they are.
        0 => theme.vwapColor,
        1 || 2 || 3 => theme.dnColor.withValues(alpha: 1 - (line - 1) * 0.25),
        _ => theme.upColor.withValues(alpha: 1 - (line - 4) * 0.25),
      };
}

/// Volume gathered by price rather than by time, drawn across the candles.
///
/// The bars run from the far side of the chart back towards the candles, one
/// per price band, so the prices the market actually traded at can be read off
/// the same axis. The busiest band — the point of control — is picked out, and
/// the value area around it shaded.
///
/// The volume of a candle is spread evenly over the bands its range covers,
/// which is the usual approximation when all that is known is OHLCV.
class VolumeProfileIndicator extends Indicator {
  /// Creates a profile of [bins] bands covering [valueArea] of the volume.
  VolumeProfileIndicator({this.bins = 24, this.valueArea = 0.7, super.colors});

  /// How many price bands the range is cut into.
  final int bins;

  /// The share of the volume the value area holds, from 0 to 1.
  final double valueArea;

  @override
  IndicatorPlacement get placement => IndicatorPlacement.overlay;

  @override
  String get name => 'VP';

  @override
  String get label => 'Volume profile($bins)';

  @override
  List<IndicatorLine> get lines => const [IndicatorLine('POC')];

  @override
  List<Object?> get settings => [bins, valueArea];

  @override
  IndicatorFormat get format => IndicatorFormat.price;

  /// The point of control, held flat across every candle.
  ///
  /// The profile itself is drawn from [computeProfile]; this is the one value
  /// worth reading out in a legend.
  @override
  IndicatorSeries compute(List<KLineEntity> candles) {
    final profile = computeProfile(candles);
    final poc = profile.pointOfControl;
    if (poc < 0) {
      return IndicatorSeries([List<double?>.filled(candles.length, null)]);
    }

    final bin = profile.bins[poc];
    final middle = (bin.low + bin.high) / 2;
    return IndicatorSeries([List<double?>.filled(candles.length, middle)]);
  }

  @override
  IndicatorProfile computeProfile(List<KLineEntity> candles) =>
      volumeProfile(candles, bins: bins, valueArea: valueArea);

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) =>
      theme.effectiveProfilePocColor;
}

// ── Panes ──────────────────────────────────────────────────────────────────

/// Moving average convergence divergence, with its histogram.
class MacdIndicator extends Indicator {
  /// Creates a MACD from the [fast], [slow] and [signal] periods.
  MacdIndicator({
    this.fast = 12,
    this.slow = 26,
    this.signal = 9,
    super.colors,
  });

  /// Period of the faster average.
  final int fast;

  /// Period of the slower average.
  final int slow;

  /// Period of the signal average.
  final int signal;

  @override
  IndicatorPlacement get placement => IndicatorPlacement.pane;

  @override
  String get name => 'MACD';

  @override
  String get label => 'MACD($fast,$slow,$signal)';

  @override
  List<IndicatorLine> get lines => [
        IndicatorLine('MACD', shape: IndicatorShape.histogram),
        IndicatorLine('DIF'),
        IndicatorLine('DEA'),
      ];

  /// The histogram flips sign about zero, so the pane has to show where zero
  /// is; without it the bars change colour across an invisible axis.
  @override
  List<double> get guides => const [0];

  @override
  List<Object?> get settings => [fast, slow, signal];

  @override
  bool get includeZero => true;

  @override
  IndicatorSeries compute(List<KLineEntity> candles) {
    final series = macdSeries(candles, fast: fast, slow: slow, signal: signal);
    return IndicatorSeries([series.macd, series.dif, series.dea]);
  }

  @override
  IndicatorSeries? extendSeries(
    List<KLineEntity> candles,
    IndicatorSeries previous,
    int from,
  ) =>
      IndicatorSeries(
        // The two averages behind the difference cannot be recovered from it, so
        // the slowest of the three sets how far back to pick the recursion up.
        graftTailLines(
          candles,
          previous.lines,
          from,
          recursiveLookback([fast, slow, signal].reduce(max)),
          (slice) {
            final series = macdSeries(
              slice,
              fast: fast,
              slow: slow,
              signal: signal,
            );
            return [series.macd, series.dif, series.dea];
          },
        ),
      );

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) =>
      switch (line) {
        1 => theme.difColor,
        2 => theme.deaColor,
        _ => theme.macdColor,
      };

  @override
  Color? colorForPoint(
    int line,
    int index,
    KLineEntity candle,
    double value,
    ChartColors theme,
  ) {
    if (line != 0 || colors != null) return null;
    return value >= 0 ? theme.upColor : theme.dnColor;
  }
}

/// Stochastic oscillator: %K, %D and %J.
class KdjIndicator extends Indicator {
  /// Creates a KDJ over [period] candles.
  KdjIndicator({
    this.period = 9,
    this.kSmoothing = 3,
    this.dSmoothing = 3,
    super.colors,
  });

  /// How many candles the raw stochastic covers.
  final int period;

  /// Smoothing applied to %K.
  final int kSmoothing;

  /// Smoothing applied to %D.
  final int dSmoothing;

  @override
  IndicatorPlacement get placement => IndicatorPlacement.pane;

  @override
  String get name => 'KDJ';

  @override
  String get label => 'KDJ($period,$kSmoothing,$dSmoothing)';

  @override
  List<IndicatorLine> get lines => [
        IndicatorLine('K'),
        IndicatorLine('D'),
        IndicatorLine('J'),
      ];

  @override
  List<Object?> get settings => [period, kSmoothing, dSmoothing];

  @override
  List<double> get guides => const [20, 50, 80];

  @override
  IndicatorSeries compute(List<KLineEntity> candles) {
    final series = kdjSeries(
      candles,
      period: period,
      kSmoothing: kSmoothing,
      dSmoothing: dSmoothing,
    );
    return IndicatorSeries([series.k, series.d, series.j]);
  }

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) =>
      switch (line) {
        1 => theme.dColor,
        2 => theme.jColor,
        _ => theme.kColor,
      };
}

/// Relative strength index.
class RsiIndicator extends Indicator {
  /// Creates an RSI over [period] candles.
  RsiIndicator({this.period = 14, Color? color})
      : super(colors: color == null ? null : [color]);

  /// How many candles the index covers.
  final int period;

  @override
  IndicatorPlacement get placement => IndicatorPlacement.pane;

  @override
  String get name => 'RSI';

  @override
  String get label => 'RSI($period)';

  @override
  List<IndicatorLine> get lines => [IndicatorLine('RSI')];

  @override
  List<Object?> get settings => [period];

  @override
  List<double> get guides => const [30, 50, 70];

  @override
  (double, double)? get fixedRange => (0, 100);

  @override
  IndicatorSeries compute(List<KLineEntity> candles) =>
      IndicatorSeries([rsiSeries(candles, period)]);

  @override
  IndicatorSeries? extendSeries(
    List<KLineEntity> candles,
    IndicatorSeries previous,
    int from,
  ) =>
      IndicatorSeries([
        // Wilder's smoothing keeps state the RSI values do not show, so this waits
        // the seed out rather than resuming from it.
        graftTail(
          candles,
          previous.lines[0],
          from,
          recursiveLookback(period),
          (slice) => rsiSeries(slice, period),
        ),
      ]);

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) =>
      theme.rsiColor;
}

/// Williams %R.
class WrIndicator extends Indicator {
  /// Creates a Williams %R over [period] candles.
  WrIndicator({this.period = 14, Color? color})
      : super(colors: color == null ? null : [color]);

  /// How many candles the range covers.
  final int period;

  @override
  IndicatorPlacement get placement => IndicatorPlacement.pane;

  @override
  String get name => 'WR';

  @override
  String get label => 'WR($period)';

  @override
  List<IndicatorLine> get lines => [IndicatorLine('WR')];

  @override
  List<Object?> get settings => [period];

  @override
  List<double> get guides => const [-30, -50, -70];

  @override
  (double, double)? get fixedRange => (-100, 0);

  @override
  IndicatorSeries compute(List<KLineEntity> candles) =>
      IndicatorSeries([wrSeries(candles, period)]);

  @override
  IndicatorSeries? extendSeries(
    List<KLineEntity> candles,
    IndicatorSeries previous,
    int from,
  ) =>
      IndicatorSeries([
        // The window reaches back `period` candles, not `period - 1`.
        graftTail(
          candles,
          previous.lines[0],
          from,
          period,
          (slice) => wrSeries(slice, period),
        ),
      ]);

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) =>
      theme.rsiColor;
}

/// Commodity channel index.
class CciIndicator extends Indicator {
  /// Creates a CCI over [period] candles.
  CciIndicator({this.period = 14, Color? color})
      : super(colors: color == null ? null : [color]);

  /// How many candles the index covers.
  final int period;

  @override
  IndicatorPlacement get placement => IndicatorPlacement.pane;

  @override
  String get name => 'CCI';

  @override
  String get label => 'CCI($period)';

  @override
  List<IndicatorLine> get lines => [IndicatorLine('CCI')];

  @override
  List<Object?> get settings => [period];

  @override
  List<double> get guides => const [-100, 100];

  @override
  IndicatorSeries compute(List<KLineEntity> candles) =>
      IndicatorSeries([cciSeries(candles, period)]);

  @override
  IndicatorSeries? extendSeries(
    List<KLineEntity> candles,
    IndicatorSeries previous,
    int from,
  ) =>
      IndicatorSeries([
        graftTail(
          candles,
          previous.lines[0],
          from,
          period - 1,
          (slice) => cciSeries(slice, period),
        ),
      ]);

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) =>
      theme.rsiColor;
}

/// Average true range: how far price travels per candle.
class AtrIndicator extends Indicator {
  /// Creates an ATR over [period] candles.
  AtrIndicator({this.period = 14, Color? color})
      : super(colors: color == null ? null : [color]);

  /// How many candles the average covers.
  final int period;

  @override
  IndicatorPlacement get placement => IndicatorPlacement.pane;

  @override
  String get name => 'ATR';

  @override
  String get label => 'ATR($period)';

  @override
  List<IndicatorLine> get lines => [IndicatorLine('ATR')];

  @override
  List<Object?> get settings => [period];

  @override
  IndicatorFormat get format => IndicatorFormat.price;

  @override
  IndicatorSeries compute(List<KLineEntity> candles) =>
      IndicatorSeries([atrSeries(candles, period)]);

  @override
  IndicatorSeries? extendSeries(
    List<KLineEntity> candles,
    IndicatorSeries previous,
    int from,
  ) {
    final line = atrTail(candles, period, previous.lines[0], from);
    return line == null ? null : IndicatorSeries([line]);
  }

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) =>
      theme.atrColor;
}

/// On-balance volume: volume signed by each candle's direction.
class ObvIndicator extends Indicator {
  /// Creates an OBV line.
  ObvIndicator({Color? color}) : super(colors: color == null ? null : [color]);

  @override
  IndicatorPlacement get placement => IndicatorPlacement.pane;

  @override
  String get name => 'OBV';

  @override
  String get label => 'OBV';

  @override
  List<IndicatorLine> get lines => [IndicatorLine('OBV')];

  @override
  List<Object?> get settings => const [];

  @override
  IndicatorFormat get format => IndicatorFormat.compact;

  @override
  IndicatorSeries compute(List<KLineEntity> candles) =>
      IndicatorSeries([obvSeries(candles)]);

  @override
  IndicatorSeries? extendSeries(
    List<KLineEntity> candles,
    IndicatorSeries previous,
    int from,
  ) {
    final line = obvTail(candles, previous.lines[0], from);
    return line == null ? null : IndicatorSeries([line]);
  }

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) =>
      theme.obvColor;
}

/// Money flow index: a volume-weighted relative strength index.
class MfiIndicator extends Indicator {
  /// Creates an MFI over [period] candles.
  MfiIndicator({this.period = 14, Color? color})
      : super(colors: color == null ? null : [color]);

  /// How many candles the index covers.
  final int period;

  @override
  IndicatorPlacement get placement => IndicatorPlacement.pane;

  @override
  String get name => 'MFI';

  @override
  String get label => 'MFI($period)';

  @override
  List<IndicatorLine> get lines => [IndicatorLine('MFI')];

  @override
  List<Object?> get settings => [period];

  @override
  List<double> get guides => const [20, 80];

  @override
  (double, double)? get fixedRange => (0, 100);

  @override
  IndicatorSeries compute(List<KLineEntity> candles) =>
      IndicatorSeries([mfiSeries(candles, period)]);

  @override
  IndicatorSeries? extendSeries(
    List<KLineEntity> candles,
    IndicatorSeries previous,
    int from,
  ) =>
      IndicatorSeries([
        // Each candle's flow is read against the one before it, so the
        // window is a candle longer than the period.
        graftTail(
          candles,
          previous.lines[0],
          from,
          period,
          (slice) => mfiSeries(slice, period),
        ),
      ]);

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) =>
      theme.mfiColor;
}

/// Directional movement: +DI, -DI and the ADX.
class DmiIndicator extends Indicator {
  /// Creates a DMI over [period] candles.
  DmiIndicator({this.period = 14, super.colors});

  /// How many candles the smoothing covers.
  final int period;

  @override
  IndicatorPlacement get placement => IndicatorPlacement.pane;

  @override
  String get name => 'DMI';

  @override
  String get label => 'DMI($period)';

  @override
  List<IndicatorLine> get lines => [
        IndicatorLine('+DI'),
        IndicatorLine('-DI'),
        IndicatorLine('ADX'),
      ];

  @override
  List<Object?> get settings => [period];

  @override
  List<double> get guides => const [20];

  @override
  IndicatorSeries compute(List<KLineEntity> candles) {
    final series = dmiSeries(candles, period);
    return IndicatorSeries([series.plusDi, series.minusDi, series.adx]);
  }

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) =>
      switch (line) {
        1 => theme.mdiColor,
        2 => theme.adxColor,
        _ => theme.pdiColor,
      };
}

// ── Overlays: channels and trend ───────────────────────────────────────────

/// Supertrend: an ATR band that follows price and flips at a reversal.
class SupertrendIndicator extends Indicator {
  /// Creates a Supertrend from [period] and [multiplier].
  SupertrendIndicator({this.period = 10, this.multiplier = 3, super.colors});

  /// How many candles the average true range covers.
  final int period;

  /// How many average true ranges the band sits from the midpoint.
  final double multiplier;

  /// Which side of price the line is on at each candle, 1 below and -1 above.
  List<int?> _trend = const [];

  @override
  IndicatorPlacement get placement => IndicatorPlacement.overlay;

  @override
  String get name => 'ST';

  @override
  String get label => 'ST($period,${_trim(multiplier)})';

  @override
  List<IndicatorLine> get lines => [IndicatorLine('ST')];

  @override
  List<Object?> get settings => [period, multiplier];

  @override
  IndicatorFormat get format => IndicatorFormat.price;

  @override
  IndicatorSeries compute(List<KLineEntity> candles) {
    final series = supertrendSeries(
      candles,
      period: period,
      multiplier: multiplier,
    );
    _trend = series.trend;
    return IndicatorSeries([series.line]);
  }

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) => theme.upColor;

  @override
  Color? colorForPoint(
    int line,
    int index,
    KLineEntity candle,
    double value,
    ChartColors theme,
  ) {
    if (colors != null) return null;
    final direction = index < _trend.length ? _trend[index] : null;
    return direction == -1 ? theme.dnColor : theme.upColor;
  }
}

/// Keltner channels: an EMA with average-true-range bands either side.
class KeltnerIndicator extends Indicator {
  /// Creates Keltner channels.
  KeltnerIndicator({
    this.period = 20,
    this.atrPeriod = 10,
    this.multiplier = 2,
    super.colors,
  });

  /// How many candles the midline's average covers.
  final int period;

  /// How many candles the average true range covers.
  final int atrPeriod;

  /// How many average true ranges the bands sit from the midline.
  final double multiplier;

  @override
  IndicatorPlacement get placement => IndicatorPlacement.overlay;

  @override
  String get name => 'KC';

  @override
  String get label => 'KC($period,$atrPeriod,${_trim(multiplier)})';

  @override
  List<IndicatorLine> get lines => [
        IndicatorLine('KC'),
        IndicatorLine('UB'),
        IndicatorLine('LB'),
      ];

  @override
  List<Object?> get settings => [period, atrPeriod, multiplier];

  @override
  IndicatorFormat get format => IndicatorFormat.price;

  @override
  IndicatorSeries compute(List<KLineEntity> candles) {
    final bands = keltnerSeries(
      candles,
      period: period,
      atrPeriod: atrPeriod,
      multiplier: multiplier,
    );
    return IndicatorSeries([bands.middle, bands.upper, bands.lower]);
  }

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) =>
      line == 0 ? theme.getMAColor(ordinal) : theme.keltnerColor;
}

/// Donchian channels: the highest high and lowest low of a window.
class DonchianIndicator extends Indicator {
  /// Creates Donchian channels over [period] candles.
  DonchianIndicator({this.period = 20, super.colors});

  /// How many candles the high and low cover.
  final int period;

  @override
  IndicatorPlacement get placement => IndicatorPlacement.overlay;

  @override
  String get name => 'DC';

  @override
  String get label => 'DC($period)';

  @override
  List<IndicatorLine> get lines => [
        IndicatorLine('DC'),
        IndicatorLine('UB'),
        IndicatorLine('LB'),
      ];

  @override
  List<Object?> get settings => [period];

  @override
  IndicatorFormat get format => IndicatorFormat.price;

  @override
  IndicatorSeries compute(List<KLineEntity> candles) {
    final bands = donchianSeries(candles, period);
    return IndicatorSeries([bands.middle, bands.upper, bands.lower]);
  }

  @override
  IndicatorSeries? extendSeries(
    List<KLineEntity> candles,
    IndicatorSeries previous,
    int from,
  ) =>
      IndicatorSeries(
        graftTailLines(candles, previous.lines, from, period - 1, (slice) {
          final bands = donchianSeries(slice, period);
          return [bands.middle, bands.upper, bands.lower];
        }),
      );

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) =>
      line == 0 ? theme.avgColor : theme.donchianColor;
}

/// Ichimoku Cloud: conversion and base lines, a shaded cloud and the lagging
/// span.
///
/// The spans are shifted forward and the lagging line back, as the indicator is
/// drawn. The chart holds one value per candle, so the stretch of cloud that
/// would project past the newest candle is not drawn.
class IchimokuIndicator extends Indicator {
  /// Creates an Ichimoku with the usual periods.
  IchimokuIndicator({
    this.conversionPeriod = 9,
    this.basePeriod = 26,
    this.spanPeriod = 52,
    this.displacement = 26,
    super.colors,
  });

  /// How many candles the conversion line (tenkan-sen) covers.
  final int conversionPeriod;

  /// How many candles the base line (kijun-sen) covers.
  final int basePeriod;

  /// How many candles leading span B covers.
  final int spanPeriod;

  /// How far the spans are shifted forward and the lagging line back.
  final int displacement;

  @override
  IndicatorPlacement get placement => IndicatorPlacement.overlay;

  @override
  String get name => 'ICH';

  @override
  String get label => 'ICH($conversionPeriod,$basePeriod,$spanPeriod)';

  @override
  List<IndicatorLine> get lines => [
        IndicatorLine('Tenkan'),
        IndicatorLine('Kijun'),
        IndicatorLine('SpanA'),
        IndicatorLine('SpanB'),
        IndicatorLine('Chikou'),
      ];

  @override
  List<Object?> get settings => [
        conversionPeriod,
        basePeriod,
        spanPeriod,
        displacement,
      ];

  @override
  List<IndicatorFill> get fills => const [IndicatorFill(2, 3)];

  @override
  IndicatorFormat get format => IndicatorFormat.price;

  @override
  IndicatorSeries compute(List<KLineEntity> candles) {
    final series = ichimokuSeries(
      candles,
      conversionPeriod: conversionPeriod,
      basePeriod: basePeriod,
      spanPeriod: spanPeriod,
      displacement: displacement,
    );
    return IndicatorSeries([
      series.conversion,
      series.base,
      series.spanA,
      series.spanB,
      series.lagging,
    ]);
  }

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) =>
      switch (line) {
        1 => theme.baseColor,
        2 => theme.spanAColor,
        3 => theme.spanBColor,
        4 => theme.laggingColor,
        _ => theme.conversionColor,
      };
}

/// A zigzag through the swing highs and lows, ignoring moves below [depth].
class ZigZagIndicator extends Indicator {
  /// Creates a zigzag that turns on a [depth] percent reversal.
  ZigZagIndicator({this.depth = 0, Color? color})
      : super(colors: color == null ? null : [color]);

  /// How far price must reverse, in percent, to end a swing.
  ///
  /// Zero — the default — sizes it from the candles, so the swings suit the
  /// market being looked at rather than a number that fits one timeframe.
  final double depth;

  @override
  IndicatorPlacement get placement => IndicatorPlacement.overlay;

  @override
  String get name => 'ZigZag';

  @override
  String get label => 'ZigZag(${_depthLabel(depth)})';

  @override
  List<IndicatorLine> get lines => [
        IndicatorLine('ZigZag', shape: IndicatorShape.pivotLine),
      ];

  @override
  List<Object?> get settings => [depth];

  @override
  IndicatorFormat get format => IndicatorFormat.price;

  @override
  IndicatorSeries compute(List<KLineEntity> candles) =>
      IndicatorSeries([zigzagSeries(candles, depth)]);

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) =>
      theme.zigzagColor;
}

/// Fibonacci retracement levels over the last swing.
///
/// The swing is found the way [ZigZagIndicator] finds one, so the levels move
/// to the newest leg as price makes it — there is nothing to place by hand.
class FibonacciIndicator extends Indicator {
  /// Creates retracement levels over the last [depth] percent swing.
  FibonacciIndicator({
    this.depth = 0,
    List<double> ratios = fibonacciRatios,
    super.colors,
  }) : ratios = List<double>.unmodifiable(ratios);

  /// How far price must reverse, in percent, for a swing to count.
  ///
  /// Zero — the default — sizes it from the candles; see [ZigZagIndicator].
  final double depth;

  /// The ratios to draw, from the swing's end (0) to its start (1).
  final List<double> ratios;

  @override
  IndicatorPlacement get placement => IndicatorPlacement.overlay;

  @override
  String get name => 'FIB';

  @override
  String get label => 'FIB(${_depthLabel(depth)})';

  @override
  List<IndicatorLine> get lines => [
        for (final ratio in ratios) IndicatorLine(_trim(ratio)),
      ];

  @override
  List<Object?> get settings => [depth, ratios.join(',')];

  @override
  IndicatorFormat get format => IndicatorFormat.price;

  @override
  IndicatorSeries compute(List<KLineEntity> candles) =>
      IndicatorSeries(fibonacciSeries(candles, depth, ratios: ratios));

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) =>
      // The swing's own ends stand out from the levels between them.
      line == 0 || line == ratios.length - 1
          ? theme.avgColor
          : theme.fibonacciColor;
}

/// Elliott wave labels over the zigzag's pivots.
///
/// A reading of the swings rather than a rules-checked count: the alternating
/// pivots are labelled `1`-`5` then `A`-`C`, and the counting starts again
/// after each correction. Treat it as a sketch to check by eye.
class ElliottWaveIndicator extends Indicator {
  /// Creates wave labels over swings of at least [depth] percent.
  ElliottWaveIndicator({this.depth = 0, Color? color})
      : super(colors: color == null ? null : [color]);

  /// How far price must reverse, in percent, to end a wave.
  ///
  /// Zero — the default — sizes it from the candles; see [ZigZagIndicator].
  final double depth;

  /// Label per candle index, filled in by [compute].
  Map<int, String> _labels = const {};

  @override
  IndicatorPlacement get placement => IndicatorPlacement.overlay;

  @override
  String get name => 'Elliott';

  @override
  String get label => 'Elliott(${_depthLabel(depth)})';

  @override
  List<IndicatorLine> get lines => [
        IndicatorLine('Wave', shape: IndicatorShape.markers),
      ];

  @override
  List<Object?> get settings => [depth];

  @override
  IndicatorFormat get format => IndicatorFormat.price;

  @override
  IndicatorSeries compute(List<KLineEntity> candles) {
    final waves = elliottWaves(candles, depth);
    final values = List<double?>.filled(candles.length, null);
    _labels = {for (final wave in waves) wave.pivot.index: wave.label};
    for (final wave in waves) {
      values[wave.pivot.index] = wave.pivot.price;
    }
    return IndicatorSeries([values]);
  }

  @override
  String? markerLabel(int line, int index) => _labels[index];

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) =>
      theme.waveColor;
}

// ── Panes: momentum and volume ─────────────────────────────────────────────

/// Stochastic RSI: where the RSI sits in its own recent range.
class StochRsiIndicator extends Indicator {
  /// Creates a stochastic RSI.
  StochRsiIndicator({
    this.rsiPeriod = 14,
    this.period = 14,
    this.kSmoothing = 3,
    this.dSmoothing = 3,
    super.colors,
  });

  /// How many candles the underlying RSI covers.
  final int rsiPeriod;

  /// How many candles the RSI's range is taken over.
  final int period;

  /// Smoothing applied to %K.
  final int kSmoothing;

  /// Smoothing applied to %D.
  final int dSmoothing;

  @override
  IndicatorPlacement get placement => IndicatorPlacement.pane;

  @override
  String get name => 'StochRSI';

  @override
  String get label => 'StochRSI($rsiPeriod,$period,$kSmoothing,$dSmoothing)';

  @override
  List<IndicatorLine> get lines => [IndicatorLine('K'), IndicatorLine('D')];

  @override
  List<Object?> get settings => [rsiPeriod, period, kSmoothing, dSmoothing];

  @override
  List<double> get guides => const [20, 80];

  @override
  (double, double)? get fixedRange => (0, 100);

  @override
  IndicatorSeries compute(List<KLineEntity> candles) {
    final series = stochRsiSeries(
      candles,
      rsiPeriod: rsiPeriod,
      period: period,
      kSmoothing: kSmoothing,
      dSmoothing: dSmoothing,
    );
    return IndicatorSeries([series.k, series.d]);
  }

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) =>
      line == 1 ? theme.dColor : theme.stochRsiColor;
}

/// Rate of change: how far the close has moved over a window, in percent.
class RocIndicator extends Indicator {
  /// Creates a rate of change over [period] candles.
  RocIndicator({this.period = 12, Color? color})
      : super(colors: color == null ? null : [color]);

  /// How many candles back the comparison is made.
  final int period;

  @override
  IndicatorPlacement get placement => IndicatorPlacement.pane;

  @override
  String get name => 'ROC';

  @override
  String get label => 'ROC($period)';

  @override
  List<IndicatorLine> get lines => [IndicatorLine('ROC')];

  @override
  List<Object?> get settings => [period];

  @override
  List<double> get guides => const [0];

  @override
  bool get includeZero => true;

  @override
  IndicatorSeries compute(List<KLineEntity> candles) =>
      IndicatorSeries([rocSeries(candles, period)]);

  @override
  IndicatorSeries? extendSeries(
    List<KLineEntity> candles,
    IndicatorSeries previous,
    int from,
  ) =>
      IndicatorSeries([
        graftTail(
          candles,
          previous.lines[0],
          from,
          period,
          (slice) => rocSeries(slice, period),
        ),
      ]);

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) =>
      theme.rocColor;
}

/// TRIX: the percentage change of a triple-smoothed average, with its signal.
class TrixIndicator extends Indicator {
  /// Creates a TRIX over [period] candles with a [signalPeriod] signal.
  TrixIndicator({this.period = 15, this.signalPeriod = 9, super.colors});

  /// How many candles each of the three smoothings covers.
  final int period;

  /// How many candles the signal line averages.
  final int signalPeriod;

  @override
  IndicatorPlacement get placement => IndicatorPlacement.pane;

  @override
  String get name => 'TRIX';

  @override
  String get label => 'TRIX($period,$signalPeriod)';

  @override
  List<IndicatorLine> get lines => [
        IndicatorLine('TRIX'),
        IndicatorLine('Signal'),
      ];

  @override
  List<Object?> get settings => [period, signalPeriod];

  @override
  List<double> get guides => const [0];

  @override
  bool get includeZero => true;

  @override
  IndicatorSeries compute(List<KLineEntity> candles) {
    final series = trixSeries(
      candles,
      period: period,
      signalPeriod: signalPeriod,
    );
    return IndicatorSeries([series.trix, series.signal]);
  }

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) =>
      line == 1 ? theme.deaColor : theme.trixColor;
}

/// A moving average of volume, in its own pane.
class VolumeMaIndicator extends Indicator {
  /// Creates a volume average over [period] candles.
  VolumeMaIndicator({this.period = 20, Color? color})
      : super(colors: color == null ? null : [color]);

  /// How many candles the average covers.
  final int period;

  @override
  IndicatorPlacement get placement => IndicatorPlacement.pane;

  @override
  String get name => 'VOLMA';

  @override
  String get label => 'VOLMA($period)';

  @override
  List<IndicatorLine> get lines => [IndicatorLine('VOLMA')];

  @override
  List<Object?> get settings => [period];

  @override
  bool get includeZero => true;

  @override
  IndicatorFormat get format => IndicatorFormat.compact;

  @override
  IndicatorSeries compute(List<KLineEntity> candles) =>
      IndicatorSeries([volumeMaSeries(candles, period)]);

  @override
  IndicatorSeries? extendSeries(
    List<KLineEntity> candles,
    IndicatorSeries previous,
    int from,
  ) =>
      IndicatorSeries([
        graftTail(
          candles,
          previous.lines[0],
          from,
          period - 1,
          (slice) => volumeMaSeries(slice, period),
        ),
      ]);

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) =>
      theme.volumeMaColor;
}

/// Awesome oscillator: the gap between a fast and a slow midpoint average.
class AwesomeIndicator extends Indicator {
  /// Creates an awesome oscillator from the [fast] and [slow] periods.
  AwesomeIndicator({this.fast = 5, this.slow = 34, Color? color})
      : super(colors: color == null ? null : [color]);

  /// Period of the faster average.
  final int fast;

  /// Period of the slower average.
  final int slow;

  @override
  IndicatorPlacement get placement => IndicatorPlacement.pane;

  @override
  String get name => 'AO';

  @override
  String get label => 'AO($fast,$slow)';

  @override
  List<IndicatorLine> get lines => [
        IndicatorLine('AO', shape: IndicatorShape.histogram),
      ];

  @override
  List<Object?> get settings => [fast, slow];

  @override
  bool get includeZero => true;

  /// Like the MACD histogram, the oscillator is read against zero.
  @override
  List<double> get guides => const [0];

  /// Whether each bar grew on the one before it, filled in by [compute].
  List<bool> _rising = const [];

  @override
  IndicatorSeries compute(List<KLineEntity> candles) {
    final values = awesomeSeries(candles, fast: fast, slow: slow);
    // Worked out here rather than while painting, so a bar's colour does not
    // depend on where the visible window happens to start.
    final rising = List<bool>.filled(values.length, true);
    double? previous;
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (value == null) continue;
      rising[i] = previous == null || value >= previous;
      previous = value;
    }
    _rising = rising;
    return IndicatorSeries([values]);
  }

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) =>
      theme.awesomeColor;

  @override
  Color? colorForPoint(
    int line,
    int index,
    KLineEntity candle,
    double value,
    ChartColors theme,
  ) {
    if (colors != null) return null;
    // Bars are read by whether the momentum grew or shrank, not by its sign.
    final grew = index < _rising.length ? _rising[index] : true;
    return grew ? theme.upColor : theme.dnColor;
  }
}

/// Aroon: how recently the highest high and the lowest low of the last
/// [period] candles fell, each read as a percentage — up near 100 marks a
/// fresh high, down near 100 a fresh low, and a cross between the two lines
/// is the usual read of a change in trend.
class AroonIndicator extends Indicator {
  /// Creates an Aroon over [period] candles.
  AroonIndicator({this.period = 14, super.colors});

  /// How many candles back the highs and lows are read over.
  final int period;

  @override
  IndicatorPlacement get placement => IndicatorPlacement.pane;

  @override
  String get name => 'AROON';

  @override
  String get label => 'AROON($period)';

  @override
  List<IndicatorLine> get lines => [IndicatorLine('Up'), IndicatorLine('Down')];

  @override
  List<Object?> get settings => [period];

  @override
  List<double> get guides => const [30, 70];

  @override
  (double, double)? get fixedRange => (0, 100);

  @override
  IndicatorSeries compute(List<KLineEntity> candles) {
    final aroon = aroonSeries(candles, period);
    return IndicatorSeries([aroon.up, aroon.down]);
  }

  @override
  IndicatorSeries? extendSeries(
    List<KLineEntity> candles,
    IndicatorSeries previous,
    int from,
  ) =>
      IndicatorSeries(
        graftTailLines(candles, previous.lines, from, period, (slice) {
          final aroon = aroonSeries(slice, period);
          return [aroon.up, aroon.down];
        }),
      );

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) =>
      line == 0 ? theme.aroonUpColor : theme.aroonDownColor;
}

/// Writes a swing depth, naming the one worked out from the candles.
String _depthLabel(double depth) => depth > 0 ? '${_trim(depth)}%' : 'auto';

/// Writes 2.0 as `2`, so a label reads `BOLL(20,2)`.
String _trim(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : '$value';
