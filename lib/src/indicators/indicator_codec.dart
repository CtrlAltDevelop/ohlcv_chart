import 'package:material_ui/material_ui.dart' show Color;

import 'indicator.dart';
import 'indicator_catalog.dart';

/// Turns [indicator] into a map that [indicatorFromJson] reads back.
///
/// Returns null for an indicator the catalog cannot rebuild — one of your own,
/// or a built-in configured past what the catalog describes. Nothing is written
/// that would come back as a different indicator, so a null here means "this one
/// cannot be saved", not "this one was saved approximately".
///
/// ```dart
/// final saved = [for (final i in indicators) ?indicatorToJson(i)];
/// await prefs.setString('indicators', jsonEncode(saved));
/// ```
Map<String, dynamic>? indicatorToJson(Indicator indicator) {
  final type = indicatorTypeRebuilding(indicator);
  if (type == null) return null;

  final colors = indicator.colors;
  return {
    'kind': type.name,
    if (type.settings.isNotEmpty)
      'values': {
        for (final setting in type.settings)
          setting.key: (type.valuesOf(indicator) ?? type.defaults)[setting.key],
      },
    if (colors != null)
      'colors': [for (final color in colors) color.toARGB32()],
  };
}

/// Rebuilds one indicator from the map [indicatorToJson] produced.
///
/// Returns null for a map with no `kind`, or a `kind` this version does not
/// know: a workspace saved by a newer release still loads, minus the indicators
/// that have no meaning here. Settings outside the range the catalog describes
/// are brought into it rather than refused, and any that are missing fall back
/// to their defaults.
Indicator? indicatorFromJson(Map<String, dynamic> json) {
  final kind = json['kind'];
  if (kind is! String) return null;

  IndicatorType? type;
  for (final candidate in indicatorCatalog) {
    if (candidate.name == kind) {
      type = candidate;
      break;
    }
  }
  if (type == null) return null;

  final rawValues = json['values'];
  final values = <String, num>{};
  if (rawValues is Map) {
    for (final setting in type.settings) {
      final value = rawValues[setting.key];
      if (value is num) values[setting.key] = value;
    }
  }

  final rawColors = json['colors'];
  final colors = rawColors is List
      ? [
          for (final value in rawColors)
            if (value is num) Color(value.toInt()),
        ]
      : null;

  return type.create(
    values: values,
    colors: colors == null || colors.isEmpty ? null : colors,
  );
}
