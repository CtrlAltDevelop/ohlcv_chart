import 'dart:ui';

import '../entity/line.dart';

/// One drawing's look, saved so it can be put on another.
///
/// Everything a drawing shares with every other drawing — its colour, how thick
/// and how broken its stroke is, how solid its wash, whether it carries a label
/// — and nothing that belongs to one kind of drawing in particular. Applying a
/// template to a rectangle and to a trend line gives them the same look without
/// either having to know about the other.
///
/// ```dart
/// final house = DrawingTemplate.of(selected);
/// for (final line in drawings.selection) {
///   house.applyTo(line);
/// }
/// ```
class DrawingTemplate {
  /// Creates a template out of the values given.
  const DrawingTemplate({
    this.color,
    this.thickness,
    this.style,
    this.fillOpacity,
    this.showLabel,
  });

  /// Reads the look of [line] into a template.
  factory DrawingTemplate.of(ChartLine line) => DrawingTemplate(
        color: line.color,
        thickness: line.thickness,
        style: line.style,
        fillOpacity: line is FilledDrawing ? line.fillOpacity : null,
        showLabel: line.showLabel,
      );

  /// Rebuilds a template from [json].
  factory DrawingTemplate.fromJson(Map<String, dynamic> json) =>
      DrawingTemplate(
        color:
            json['color'] is num ? Color((json['color'] as num).toInt()) : null,
        thickness: LineJson.maybeNumber(json, 'thickness'),
        style: json['style'] == null ? null : LineJson.style(json),
        fillOpacity: LineJson.maybeNumber(json, 'fillOpacity'),
        showLabel: json['showLabel'] is bool ? json['showLabel'] as bool : null,
      );

  /// Stroke colour, or null to leave whatever the drawing has.
  final Color? color;

  /// Stroke width, or null to leave it.
  final double? thickness;

  /// Stroke style, or null to leave it.
  final LineStyle? style;

  /// How solid a filled drawing's wash is, or null to leave it.
  ///
  /// Ignored by a drawing with no interior.
  final double? fillOpacity;

  /// Whether the drawing's label is painted, or null to leave it.
  final bool? showLabel;

  /// Puts this template's look on [line], in place.
  void applyTo(ChartLine line) {
    if (color != null) line.color = color!;
    if (thickness != null) line.thickness = thickness!;
    if (style != null) line.style = style!;
    if (showLabel != null) line.showLabel = showLabel!;
    if (fillOpacity != null && line is FilledDrawing) {
      line.fillOpacity = fillOpacity!;
    }
  }

  /// This template as a JSON-encodable map.
  Map<String, dynamic> toJson() => <String, dynamic>{
        if (color != null) 'color': color!.toARGB32(),
        if (thickness != null) 'thickness': thickness,
        if (style != null) 'style': style!.name,
        if (fillOpacity != null) 'fillOpacity': fillOpacity,
        if (showLabel != null) 'showLabel': showLabel,
      };

  @override
  bool operator ==(Object other) =>
      other is DrawingTemplate &&
      other.color == color &&
      other.thickness == thickness &&
      other.style == style &&
      other.fillOpacity == fillOpacity &&
      other.showLabel == showLabel;

  @override
  int get hashCode =>
      Object.hash(color, thickness, style, fillOpacity, showLabel);
}
