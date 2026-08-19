import 'package:flutter/material.dart' show Color;

import '../chart_style.dart';
import 'indicator.dart';
import 'indicators.dart';

/// One setting of an indicator type, described so a form can be built from it.
///
/// A period is a whole number with a sensible range; a SAR's acceleration is a
/// fraction. [min], [max] and [step] are what a slider or stepper should use,
/// not a hard constraint — an indicator computes whatever it is given.
class IndicatorSetting {
  /// Describes one setting.
  const IndicatorSetting({
    required this.key,
    required this.label,
    required this.defaultValue,
    required this.min,
    required this.max,
    this.step = 1,
    this.isInteger = true,
  });

  /// Identifier used in the values map, such as `period`.
  final String key;

  /// Name to show beside the field, such as `Period`.
  final String label;

  /// Value the indicator uses when the caller does not choose one.
  final num defaultValue;

  /// Smallest value a form should offer.
  final num min;

  /// Largest value a form should offer.
  final num max;

  /// How much a stepper should move by.
  final num step;

  /// Whether the value is a whole number.
  final bool isInteger;

  /// Rounds and clamps [value] to what this setting accepts.
  num coerce(num value) {
    final bounded = value.clamp(min, max);
    return isInteger ? bounded.round() : bounded.toDouble();
  }
}

/// A kind of indicator that can be added to a chart, and how to configure it.
///
/// This is what an "add indicator" sheet is built from: [settings] gives the
/// fields to show, [lineLabels] the colour slots to offer, and [create] turns
/// the user's choices into an [Indicator] to hand to `KChartWidget`.
///
/// ```dart
/// final type = indicatorCatalog.firstWhere((t) => t.name == 'ATR');
/// final values = type.defaults..['period'] = 8;
/// setState(() => indicators.upsert(type.create(values: values,
///     colors: [Colors.purple])));
/// ```
class IndicatorType {
  /// Describes a kind of indicator.
  const IndicatorType({
    required this.name,
    required this.description,
    required this.placement,
    required this.settings,
    required this.builder,
  });

  /// Short name of the type, such as `ATR`.
  final String name;

  /// One line on what the indicator shows.
  final String description;

  /// Whether instances draw over the candles or in their own pane.
  final IndicatorPlacement placement;

  /// The settings a caller may choose, in the order a form should show them.
  final List<IndicatorSetting> settings;

  /// Turns a values map and optional colours into an instance.
  ///
  /// Prefer [create], which fills in the defaults for any missing setting.
  final Indicator Function(Map<String, num> values, List<Color>? colors)
  builder;

  /// Every setting at its default, ready to be edited and passed to [create].
  Map<String, num> get defaults => {
    for (final setting in settings) setting.key: setting.defaultValue,
  };

  /// Builds an instance from [values], filling in defaults for what is missing.
  ///
  /// [colors] overrides the theme, one entry per line of [lineLabels]; a
  /// shorter list colours only the lines it covers.
  Indicator create({Map<String, num>? values, List<Color>? colors}) {
    final resolved = defaults;
    if (values != null) {
      for (final setting in settings) {
        final given = values[setting.key];
        if (given != null) resolved[setting.key] = setting.coerce(given);
      }
    }
    return builder(resolved, colors);
  }

  /// The settings of [indicator] as a values map, for editing an existing one.
  ///
  /// Reads the settings this type describes, in order; anything an indicator
  /// keeps beyond them — a Fibonacci's ratio list, say — is part of what makes
  /// it distinct but is not a field a generic form can edit. Returns null when
  /// [indicator] is not of this type.
  Map<String, num>? valuesOf(Indicator indicator) {
    if (indicator.name != name) return null;
    final current = indicator.settings;
    if (current.length < settings.length) return null;
    final values = <String, num>{};
    for (var i = 0; i < settings.length; i++) {
      final value = current[i];
      if (value is! num) return null;
      values[settings[i].key] = value;
    }
    return values;
  }

  /// The lines an instance draws, for labelling the colour pickers.
  ///
  /// Built from an instance at [values], because some labels carry the
  /// settings — a `MA(20)` line is called `MA20`.
  List<String> lineLabels({Map<String, num>? values}) => [
    for (final line in create(values: values).lines) line.label,
  ];

  /// The colours an instance would draw with, to seed the colour pickers.
  ///
  /// [ordinal] is the position the new indicator would take among others of
  /// its kind, which is what makes a second moving average a different colour.
  List<Color> defaultColors(
    ChartColors theme, {
    Map<String, num>? values,
    int ordinal = 0,
  }) {
    final indicator = create(values: values);
    return [
      for (var line = 0; line < indicator.lines.length; line++)
        indicator.colorFor(line, theme, ordinal: ordinal),
    ];
  }

  @override
  String toString() => name;
}

const IndicatorSetting _period = IndicatorSetting(
  key: 'period',
  label: 'Period',
  defaultValue: 14,
  min: 2,
  max: 200,
);

IndicatorSetting _periodOf(int defaultValue) => IndicatorSetting(
  key: 'period',
  label: 'Period',
  defaultValue: defaultValue,
  min: 2,
  max: 200,
);

/// Every indicator the chart can draw, with the settings each one takes.
///
/// Drive an "add indicator" menu from this list rather than hard-coding the
/// types, so a new indicator shows up in the menu on its own. Nothing stops a
/// caller building indicators directly — `AtrIndicator(period: 8)` — the
/// catalog is there for menus and settings dialogs.
final List<IndicatorType> indicatorCatalog = List.unmodifiable([
  IndicatorType(
    name: 'MA',
    description: 'Simple moving average of the close.',
    placement: IndicatorPlacement.overlay,
    settings: [_periodOf(5)],
    builder: (values, colors) => MaIndicator(
      period: values['period']!.toInt(),
      color: colors?.firstOrNull,
    ),
  ),
  IndicatorType(
    name: 'EMA',
    description: 'Exponential moving average of the close.',
    placement: IndicatorPlacement.overlay,
    settings: [_periodOf(5)],
    builder: (values, colors) => EmaIndicator(
      period: values['period']!.toInt(),
      color: colors?.firstOrNull,
    ),
  ),
  IndicatorType(
    name: 'BOLL',
    description: 'Bollinger bands around a moving average.',
    placement: IndicatorPlacement.overlay,
    settings: [
      _periodOf(20),
      const IndicatorSetting(
        key: 'deviations',
        label: 'Deviations',
        defaultValue: 2,
        min: 0.5,
        max: 5,
        step: 0.5,
        isInteger: false,
      ),
    ],
    builder: (values, colors) => BollIndicator(
      period: values['period']!.toInt(),
      deviations: values['deviations']!.toDouble(),
      colors: colors,
    ),
  ),
  IndicatorType(
    name: 'SAR',
    description: 'Parabolic stop and reverse dots.',
    placement: IndicatorPlacement.overlay,
    settings: [
      const IndicatorSetting(
        key: 'start',
        label: 'Start',
        defaultValue: 0.02,
        min: 0.001,
        max: 0.2,
        step: 0.01,
        isInteger: false,
      ),
      const IndicatorSetting(
        key: 'step',
        label: 'Step',
        defaultValue: 0.02,
        min: 0.001,
        max: 0.2,
        step: 0.01,
        isInteger: false,
      ),
      const IndicatorSetting(
        key: 'maximum',
        label: 'Maximum',
        defaultValue: 0.2,
        min: 0.01,
        max: 1,
        step: 0.05,
        isInteger: false,
      ),
    ],
    builder: (values, colors) => SarIndicator(
      start: values['start']!.toDouble(),
      step: values['step']!.toDouble(),
      maximum: values['maximum']!.toDouble(),
      color: colors?.firstOrNull,
    ),
  ),
  IndicatorType(
    name: 'VWAP',
    description: 'Volume-weighted average price.',
    placement: IndicatorPlacement.overlay,
    settings: [],
    builder: (values, colors) => VwapIndicator(color: colors?.firstOrNull),
  ),
  IndicatorType(
    name: 'ST',
    description: 'Supertrend: an ATR stop that flips with the trend.',
    placement: IndicatorPlacement.overlay,
    settings: [
      _periodOf(10),
      const IndicatorSetting(
        key: 'multiplier',
        label: 'Multiplier',
        defaultValue: 3,
        min: 0.5,
        max: 10,
        step: 0.5,
        isInteger: false,
      ),
    ],
    builder: (values, colors) => SupertrendIndicator(
      period: values['period']!.toInt(),
      multiplier: values['multiplier']!.toDouble(),
      colors: colors,
    ),
  ),
  IndicatorType(
    name: 'KC',
    description: 'Keltner channels: an EMA with average-true-range bands.',
    placement: IndicatorPlacement.overlay,
    settings: [
      _periodOf(20),
      const IndicatorSetting(
        key: 'atrPeriod',
        label: 'ATR period',
        defaultValue: 10,
        min: 2,
        max: 100,
      ),
      const IndicatorSetting(
        key: 'multiplier',
        label: 'Multiplier',
        defaultValue: 2,
        min: 0.5,
        max: 10,
        step: 0.5,
        isInteger: false,
      ),
    ],
    builder: (values, colors) => KeltnerIndicator(
      period: values['period']!.toInt(),
      atrPeriod: values['atrPeriod']!.toInt(),
      multiplier: values['multiplier']!.toDouble(),
      colors: colors,
    ),
  ),
  IndicatorType(
    name: 'DC',
    description: 'Donchian channels: the highest high and lowest low.',
    placement: IndicatorPlacement.overlay,
    settings: [_periodOf(20)],
    builder: (values, colors) =>
        DonchianIndicator(period: values['period']!.toInt(), colors: colors),
  ),
  IndicatorType(
    name: 'ICH',
    description: 'Ichimoku Cloud: conversion, base, cloud and lagging span.',
    placement: IndicatorPlacement.overlay,
    settings: [
      const IndicatorSetting(
        key: 'conversionPeriod',
        label: 'Conversion',
        defaultValue: 9,
        min: 2,
        max: 100,
      ),
      const IndicatorSetting(
        key: 'basePeriod',
        label: 'Base',
        defaultValue: 26,
        min: 2,
        max: 200,
      ),
      const IndicatorSetting(
        key: 'spanPeriod',
        label: 'Span B',
        defaultValue: 52,
        min: 2,
        max: 400,
      ),
      const IndicatorSetting(
        key: 'displacement',
        label: 'Shift',
        defaultValue: 26,
        min: 0,
        max: 200,
      ),
    ],
    builder: (values, colors) => IchimokuIndicator(
      conversionPeriod: values['conversionPeriod']!.toInt(),
      basePeriod: values['basePeriod']!.toInt(),
      spanPeriod: values['spanPeriod']!.toInt(),
      displacement: values['displacement']!.toInt(),
      colors: colors,
    ),
  ),
  IndicatorType(
    name: 'ZigZag',
    description: 'A line through the swing highs and lows.',
    placement: IndicatorPlacement.overlay,
    settings: [
      const IndicatorSetting(
        key: 'depth',
        label: 'Swing % (0 = auto)',
        defaultValue: 0,
        min: 0,
        max: 30,
        step: 0.5,
        isInteger: false,
      ),
    ],
    builder: (values, colors) => ZigZagIndicator(
      depth: values['depth']!.toDouble(),
      color: colors?.firstOrNull,
    ),
  ),
  IndicatorType(
    name: 'FIB',
    description: 'Fibonacci retracement levels over the last swing.',
    placement: IndicatorPlacement.overlay,
    settings: [
      const IndicatorSetting(
        key: 'depth',
        label: 'Swing % (0 = auto)',
        defaultValue: 0,
        min: 0,
        max: 30,
        step: 0.5,
        isInteger: false,
      ),
    ],
    builder: (values, colors) =>
        FibonacciIndicator(depth: values['depth']!.toDouble(), colors: colors),
  ),
  IndicatorType(
    name: 'Elliott',
    description: 'Wave labels over the swings — a sketch, not a rules check.',
    placement: IndicatorPlacement.overlay,
    settings: [
      const IndicatorSetting(
        key: 'depth',
        label: 'Swing % (0 = auto)',
        defaultValue: 0,
        min: 0,
        max: 30,
        step: 0.5,
        isInteger: false,
      ),
    ],
    builder: (values, colors) => ElliottWaveIndicator(
      depth: values['depth']!.toDouble(),
      color: colors?.firstOrNull,
    ),
  ),
  IndicatorType(
    name: 'MACD',
    description: 'Moving average convergence divergence.',
    placement: IndicatorPlacement.pane,
    settings: [
      const IndicatorSetting(
        key: 'fast',
        label: 'Fast',
        defaultValue: 12,
        min: 2,
        max: 100,
      ),
      const IndicatorSetting(
        key: 'slow',
        label: 'Slow',
        defaultValue: 26,
        min: 2,
        max: 200,
      ),
      const IndicatorSetting(
        key: 'signal',
        label: 'Signal',
        defaultValue: 9,
        min: 2,
        max: 100,
      ),
    ],
    builder: (values, colors) => MacdIndicator(
      fast: values['fast']!.toInt(),
      slow: values['slow']!.toInt(),
      signal: values['signal']!.toInt(),
      colors: colors,
    ),
  ),
  IndicatorType(
    name: 'KDJ',
    description: 'Stochastic oscillator with a J line.',
    placement: IndicatorPlacement.pane,
    settings: [
      _periodOf(9),
      const IndicatorSetting(
        key: 'kSmoothing',
        label: 'K smoothing',
        defaultValue: 3,
        min: 1,
        max: 50,
      ),
      const IndicatorSetting(
        key: 'dSmoothing',
        label: 'D smoothing',
        defaultValue: 3,
        min: 1,
        max: 50,
      ),
    ],
    builder: (values, colors) => KdjIndicator(
      period: values['period']!.toInt(),
      kSmoothing: values['kSmoothing']!.toInt(),
      dSmoothing: values['dSmoothing']!.toInt(),
      colors: colors,
    ),
  ),
  IndicatorType(
    name: 'RSI',
    description: 'Relative strength index.',
    placement: IndicatorPlacement.pane,
    settings: [_period],
    builder: (values, colors) => RsiIndicator(
      period: values['period']!.toInt(),
      color: colors?.firstOrNull,
    ),
  ),
  IndicatorType(
    name: 'WR',
    description: 'Williams %R.',
    placement: IndicatorPlacement.pane,
    settings: [_period],
    builder: (values, colors) => WrIndicator(
      period: values['period']!.toInt(),
      color: colors?.firstOrNull,
    ),
  ),
  IndicatorType(
    name: 'CCI',
    description: 'Commodity channel index.',
    placement: IndicatorPlacement.pane,
    settings: [_period],
    builder: (values, colors) => CciIndicator(
      period: values['period']!.toInt(),
      color: colors?.firstOrNull,
    ),
  ),
  IndicatorType(
    name: 'ATR',
    description: 'Average true range: how far price travels per candle.',
    placement: IndicatorPlacement.pane,
    settings: [_period],
    builder: (values, colors) => AtrIndicator(
      period: values['period']!.toInt(),
      color: colors?.firstOrNull,
    ),
  ),
  IndicatorType(
    name: 'OBV',
    description: 'On-balance volume.',
    placement: IndicatorPlacement.pane,
    settings: [],
    builder: (values, colors) => ObvIndicator(color: colors?.firstOrNull),
  ),
  IndicatorType(
    name: 'MFI',
    description: 'Money flow index: a volume-weighted RSI.',
    placement: IndicatorPlacement.pane,
    settings: [_period],
    builder: (values, colors) => MfiIndicator(
      period: values['period']!.toInt(),
      color: colors?.firstOrNull,
    ),
  ),
  IndicatorType(
    name: 'DMI',
    description: 'Directional movement: +DI, -DI and ADX.',
    placement: IndicatorPlacement.pane,
    settings: [_period],
    builder: (values, colors) =>
        DmiIndicator(period: values['period']!.toInt(), colors: colors),
  ),
  IndicatorType(
    name: 'StochRSI',
    description: 'Stochastic RSI: where the RSI sits in its own range.',
    placement: IndicatorPlacement.pane,
    settings: [
      const IndicatorSetting(
        key: 'rsiPeriod',
        label: 'RSI period',
        defaultValue: 14,
        min: 2,
        max: 200,
      ),
      _periodOf(14),
      const IndicatorSetting(
        key: 'kSmoothing',
        label: 'K smoothing',
        defaultValue: 3,
        min: 1,
        max: 50,
      ),
      const IndicatorSetting(
        key: 'dSmoothing',
        label: 'D smoothing',
        defaultValue: 3,
        min: 1,
        max: 50,
      ),
    ],
    builder: (values, colors) => StochRsiIndicator(
      rsiPeriod: values['rsiPeriod']!.toInt(),
      period: values['period']!.toInt(),
      kSmoothing: values['kSmoothing']!.toInt(),
      dSmoothing: values['dSmoothing']!.toInt(),
      colors: colors,
    ),
  ),
  IndicatorType(
    name: 'ROC',
    description: 'Rate of change: how far price has moved, in percent.',
    placement: IndicatorPlacement.pane,
    settings: [_periodOf(12)],
    builder: (values, colors) => RocIndicator(
      period: values['period']!.toInt(),
      color: colors?.firstOrNull,
    ),
  ),
  IndicatorType(
    name: 'TRIX',
    description: 'TRIX: momentum of a triple-smoothed average.',
    placement: IndicatorPlacement.pane,
    settings: [
      _periodOf(15),
      const IndicatorSetting(
        key: 'signalPeriod',
        label: 'Signal',
        defaultValue: 9,
        min: 1,
        max: 100,
      ),
    ],
    builder: (values, colors) => TrixIndicator(
      period: values['period']!.toInt(),
      signalPeriod: values['signalPeriod']!.toInt(),
      colors: colors,
    ),
  ),
  IndicatorType(
    name: 'VOLMA',
    description: 'A moving average of volume.',
    placement: IndicatorPlacement.pane,
    settings: [_periodOf(20)],
    builder: (values, colors) => VolumeMaIndicator(
      period: values['period']!.toInt(),
      color: colors?.firstOrNull,
    ),
  ),
  IndicatorType(
    name: 'AO',
    description: 'Awesome oscillator: fast against slow midpoint averages.',
    placement: IndicatorPlacement.pane,
    settings: [
      const IndicatorSetting(
        key: 'fast',
        label: 'Fast',
        defaultValue: 5,
        min: 2,
        max: 100,
      ),
      const IndicatorSetting(
        key: 'slow',
        label: 'Slow',
        defaultValue: 34,
        min: 2,
        max: 200,
      ),
    ],
    builder: (values, colors) => AwesomeIndicator(
      fast: values['fast']!.toInt(),
      slow: values['slow']!.toInt(),
      color: colors?.firstOrNull,
    ),
  ),
]);

/// The catalog entry describing [indicator], or null if there is none.
IndicatorType? indicatorTypeOf(Indicator indicator) {
  for (final type in indicatorCatalog) {
    if (type.name == indicator.name) return type;
  }
  return null;
}
