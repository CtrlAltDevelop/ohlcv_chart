import 'package:flutter/material.dart';

import '../entity/line.dart';
import 'drawing_controller.dart';
import 'drawing_style.dart';
import 'drawing_translations.dart';

/// A list of everything drawn on the chart, with the controls a layout needs:
/// show and hide, lock, delete, undo, redo and clear.
///
/// Point it at the same [ChartDrawingController] the chart has and the two stay
/// in step — tapping a row selects that drawing on the chart, and the chart's
/// own selection highlights the row.
///
/// ```dart
/// Row(
///   children: [
///     Expanded(child: KChartWidget(candles, colors, drawingController: c, /* … */)),
///     SizedBox(width: 260, child: DrawingManager(controller: c)),
///   ],
/// );
/// ```
///
/// It is a plain widget: put it in a side panel, a bottom sheet, a popover —
/// wherever a layout belongs in your app.
class DrawingManager extends StatelessWidget {
  /// Creates a manager over [controller]'s drawings.
  const DrawingManager({
    required this.controller,
    this.style = const DrawingStyle(),
    this.translations = const DrawingTranslations(),
    this.textColor,
    this.backgroundColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    this.showHistoryControls = true,
    this.newestFirst = true,
    this.onSelected,
    super.key,
  });

  /// The drawings to list, and where edits are written.
  final ChartDrawingController controller;

  /// Icon sizes, accent and radii, shared with the chart's line editor.
  final DrawingStyle style;

  /// Every piece of text the panel shows, including what each kind is called.
  final DrawingTranslations translations;

  /// Colour of the text and icons. Defaults to the ambient text colour.
  final Color? textColor;

  /// Fill behind the list. Defaults to transparent.
  final Color? backgroundColor;

  /// Space around the list.
  final EdgeInsets padding;

  /// Whether the undo, redo and clear buttons are shown.
  final bool showHistoryControls;

  /// Whether the most recently placed drawing is listed first.
  final bool newestFirst;

  /// Called when a row is tapped, after it has been selected.
  final ValueChanged<ChartLine>? onSelected;

  @override
  Widget build(BuildContext context) {
    final color =
        textColor ?? DefaultTextStyle.of(context).style.color ?? Colors.white;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final drawings = newestFirst
            ? controller.drawings.reversed.toList()
            : controller.drawings;

        return Container(
          color: backgroundColor,
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _header(color),
              const SizedBox(height: 4),
              if (drawings.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    translations.noDrawings,
                    style: TextStyle(
                      color: color.withValues(alpha: .6),
                      fontSize: 12,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: drawings.length,
                    itemBuilder: (context, index) =>
                        _row(drawings[index], color),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _header(Color color) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${translations.drawings}  ${controller.length}',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (showHistoryControls) ...[
          _iconButton(
            icon: Icons.undo_rounded,
            tooltip: translations.undo,
            color: color,
            onPressed: controller.canUndo ? controller.undo : null,
          ),
          _iconButton(
            icon: Icons.redo_rounded,
            tooltip: translations.redo,
            color: color,
            onPressed: controller.canRedo ? controller.redo : null,
          ),
          _iconButton(
            icon: Icons.delete_sweep_rounded,
            tooltip: translations.clearAll,
            color: style.deleteColor,
            onPressed: controller.isEmpty ? null : controller.clear,
          ),
        ],
      ],
    );
  }

  Widget _row(ChartLine line, Color color) {
    final selected = identical(controller.selected, line);
    final label = line is LabelledDrawing ? line.labelText : null;
    final name = translations.nameOf(line);

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          controller.select(line);
          onSelected?.call(line);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: selected
                ? style.accentColor.withValues(alpha: .18)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: line.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: .35)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label == null || label.isEmpty ? name : '$name · $label',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: line.hidden ? color.withValues(alpha: .5) : color,
                    fontSize: 12,
                  ),
                ),
              ),
              _iconButton(
                icon: line.hidden
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                tooltip: line.hidden ? translations.show : translations.hide,
                color: line.hidden ? color.withValues(alpha: .5) : color,
                onPressed: () {
                  line.hidden = !line.hidden;
                  controller.save(line);
                },
              ),
              if (style.showLockControl)
                _iconButton(
                  icon: line.locked
                      ? Icons.lock_rounded
                      : Icons.lock_open_rounded,
                  tooltip: line.locked
                      ? translations.unlock
                      : translations.lock,
                  color: line.locked ? style.accentColor : color,
                  onPressed: () {
                    line.locked = !line.locked;
                    controller.save(line);
                  },
                ),
              _iconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: translations.delete,
                color: style.deleteColor,
                onPressed: () => controller.remove(line),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    final size = style.iconSize * 0.85;
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: size),
        color: onPressed == null ? color.withValues(alpha: .3) : color,
        iconSize: size,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(4),
        constraints: BoxConstraints.tightFor(
          width: size + 14,
          height: size + 14,
        ),
        onPressed: onPressed,
      ),
    );
  }
}
