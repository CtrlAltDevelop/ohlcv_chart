import 'indicator.dart';
import 'indicator_codec.dart';
import 'indicators.dart';

/// A named set of indicators, saved so it can be put on a chart in one go.
///
/// `DrawingTemplate` saves one drawing's look; this saves a whole reading of
/// the market — the averages, the oscillator and the volume study somebody
/// works from — under a name they choose:
///
/// ```dart
/// final mine = IndicatorTemplate(
///   name: 'Swing',
///   indicators: [MaIndicator(period: 50), RsiIndicator(), MacdIndicator()],
/// );
///
/// setState(() => indicators = mine.indicators);
/// ```
///
/// Templates serialise through the same codec a workspace uses, so an
/// indicator the catalog cannot rebuild is left out rather than saved as
/// something else — [unsaveable] says which, so an app can tell somebody
/// instead of quietly dropping it.
class IndicatorTemplate {
  /// Creates a template called [name] holding [indicators].
  const IndicatorTemplate({required this.name, required this.indicators});

  /// Rebuilds a template from [json].
  ///
  /// An indicator this version does not recognise is skipped, so a template
  /// written by a newer release still loads with the rest.
  factory IndicatorTemplate.fromJson(Map<String, dynamic> json) {
    final raw = json['indicators'];
    return IndicatorTemplate(
      name: json['name'] is String ? json['name'] as String : '',
      indicators: [
        if (raw is List)
          for (final entry in raw)
            if (entry is Map<String, dynamic>)
              if (indicatorFromJson(entry) case final v?) v,
      ],
    );
  }

  /// What the template is called, and what it is looked up by.
  final String name;

  /// The indicators it puts on the chart, in the order they are added.
  final List<Indicator> indicators;

  /// The indicators [toJson] cannot write down.
  ///
  /// One of your own, or a built-in configured past what the catalog
  /// describes, has no entry to rebuild it from — see `indicatorToJson`.
  List<Indicator> get unsaveable => [
    for (final indicator in indicators)
      if (indicatorToJson(indicator) == null) indicator,
  ];

  /// Writes the template out, ready for `jsonEncode`.
  Map<String, dynamic> toJson() => {
    'name': name,
    'indicators': [
      for (final indicator in indicators)
        if (indicatorToJson(indicator) case final v?) v,
    ],
  };

  /// A copy under a different [name], or with different [indicators].
  IndicatorTemplate copyWith({String? name, List<Indicator>? indicators}) =>
      IndicatorTemplate(
        name: name ?? this.name,
        indicators: indicators ?? this.indicators,
      );

  /// A few sets to start from, which an app can offer or ignore.
  ///
  /// Nothing here is privileged: they are ordinary templates, listed so an
  /// empty template menu has something in it on the first run.
  static List<IndicatorTemplate> get starters => [
    IndicatorTemplate(
      name: 'Trend',
      indicators: [
        MaIndicator(period: 20),
        MaIndicator(period: 50),
        MaIndicator(period: 200),
      ],
    ),
    IndicatorTemplate(
      name: 'Momentum',
      indicators: [RsiIndicator(period: 14), MacdIndicator()],
    ),
    IndicatorTemplate(
      name: 'Volatility',
      indicators: [
        BollIndicator(period: 20, deviations: 2),
        AtrIndicator(period: 14),
      ],
    ),
    IndicatorTemplate(
      name: 'Volume',
      indicators: [VolumeMaIndicator(period: 20), ObvIndicator()],
    ),
  ];

  @override
  bool operator ==(Object other) =>
      other is IndicatorTemplate &&
      other.name == name &&
      _sameIndicators(other.indicators, indicators);

  @override
  int get hashCode => Object.hash(name, Object.hashAll(indicators));

  @override
  String toString() => 'IndicatorTemplate($name, ${indicators.length})';

  static bool _sameIndicators(List<Indicator> a, List<Indicator> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// The templates somebody has saved, kept by name.
///
/// Saving under a name that is already taken replaces it, which is what makes
/// "save" and "overwrite" the same gesture. Order is the order they were first
/// added, so a menu built from [all] does not reshuffle itself.
///
/// ```dart
/// final saved = IndicatorTemplates(IndicatorTemplate.starters);
/// saved.save(IndicatorTemplate(name: 'Swing', indicators: indicators));
///
/// await prefs.setString('templates', jsonEncode(saved.toJson()));
/// ```
class IndicatorTemplates {
  /// Creates a set holding [templates].
  IndicatorTemplates([Iterable<IndicatorTemplate> templates = const []]) {
    for (final template in templates) {
      save(template);
    }
  }

  /// Rebuilds a set saved by [toJson].
  ///
  /// Anything that is not a readable template is skipped rather than throwing.
  factory IndicatorTemplates.fromJson(Map<String, dynamic> json) {
    final raw = json['templates'];
    return IndicatorTemplates([
      if (raw is List)
        for (final entry in raw)
          if (entry is Map<String, dynamic>) IndicatorTemplate.fromJson(entry),
    ]);
  }

  final Map<String, IndicatorTemplate> _byName = {};

  /// Every template, in the order they were first saved.
  List<IndicatorTemplate> get all => List.unmodifiable(_byName.values);

  /// How many are saved.
  int get length => _byName.length;

  /// Whether none are.
  bool get isEmpty => _byName.isEmpty;

  /// Whether any are.
  bool get isNotEmpty => _byName.isNotEmpty;

  /// The template called [name], or null if there is none.
  IndicatorTemplate? operator [](String name) => _byName[name];

  /// Saves [template], replacing any of the same name in its place.
  void save(IndicatorTemplate template) => _byName[template.name] = template;

  /// Removes the template called [name], answering whether there was one.
  bool remove(String name) => _byName.remove(name) != null;

  /// Forgets every template.
  void clear() => _byName.clear();

  /// Writes them all out, ready for `jsonEncode`.
  Map<String, dynamic> toJson() => {
    'templates': [for (final template in _byName.values) template.toJson()],
  };

  @override
  String toString() => 'IndicatorTemplates(${_byName.keys.join(', ')})';
}
