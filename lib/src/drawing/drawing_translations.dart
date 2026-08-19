/// Every piece of text the line-editing toolbar shows.
///
/// Build one from your own localisations and hand it to
/// [ChartTranslations.drawing]:
///
/// ```dart
/// ChartTranslations(
///   drawing: DrawingTranslations(color: l10n.color, delete: l10n.delete),
/// );
/// ```
class DrawingTranslations {
  /// Creates a translation set, defaulting to English.
  const DrawingTranslations({
    this.color = 'Colour',
    this.opacity = 'Opacity',
    this.thickness = 'Thickness',
    this.lineStyle = 'Style',
    this.solid = 'Solid',
    this.dashed = 'Dashed',
    this.dotted = 'Dotted',
    this.label = 'Label',
    this.labelHint = 'Label text',
    this.showLabel = 'Show label',
    this.hideLabel = 'Hide label',
    this.lock = 'Lock',
    this.unlock = 'Unlock',
    this.delete = 'Delete',
    this.done = 'Done',
    this.move = 'Move toolbar',
  });

  /// Title of the colour popover.
  final String color;

  /// Label of the opacity slider.
  final String opacity;

  /// Title of the thickness popover.
  final String thickness;

  /// Title of the stroke-style popover.
  final String lineStyle;

  /// Name of `LineStyle.solid`.
  final String solid;

  /// Name of `LineStyle.dashed`.
  final String dashed;

  /// Name of `LineStyle.dotted`.
  final String dotted;

  /// Title of the label popover.
  final String label;

  /// Placeholder shown in the empty label field.
  final String labelHint;

  /// Tooltip of the label toggle while the label is hidden.
  final String showLabel;

  /// Tooltip of the label toggle while the label is shown.
  final String hideLabel;

  /// Tooltip of the lock button while the line is unlocked.
  final String lock;

  /// Tooltip of the lock button while the line is locked.
  final String unlock;

  /// Tooltip of the delete button.
  final String delete;

  /// Tooltip of the button that dismisses the toolbar.
  final String done;

  /// Tooltip of the drag grip.
  final String move;
}
