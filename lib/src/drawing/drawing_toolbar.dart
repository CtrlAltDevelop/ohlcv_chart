import 'package:flutter/material.dart';

import '../chart_style.dart';
import '../entity/horizontal_line.dart';
import '../entity/line.dart';
import 'drawing_style.dart';
import 'drawing_translations.dart';
import 'line_painting.dart';

/// The floating editor for the currently selected chart line.
///
/// Shows a swatch of the line's colour, its thickness and stroke style, and
/// buttons for its label, its lock and its removal. Which controls appear, the
/// values they offer and how the bar looks all come from [style].
///
/// Every control edits [line] in place: [onChanged] fires on each change so the
/// chart repaints, and [onCommitted] fires once an interaction settles, which
/// is the moment to persist the line.
class DrawingToolbar extends StatelessWidget {
  /// Creates a toolbar for [line].
  const DrawingToolbar({
    required this.line,
    required this.style,
    required this.translations,
    required this.chartColors,
    required this.onChanged,
    required this.onCommitted,
    required this.onDelete,
    required this.onDone,
    this.onMoved,
    super.key,
  });

  /// The line being edited.
  final ChartLine line;

  /// Appearance of the bar and the options it offers.
  final DrawingStyle style;

  /// Text for every control.
  final DrawingTranslations translations;

  /// Used to derive the bar's default colours from the chart's palette.
  final ChartColors chartColors;

  /// Called after every edit, including each frame of a slider drag.
  final VoidCallback onChanged;

  /// Called once an edit settles, so the change can be persisted.
  final VoidCallback onCommitted;

  /// Called when the delete button is pressed.
  final VoidCallback onDelete;

  /// Called when the done button is pressed.
  final VoidCallback onDone;

  /// Called with the drag delta while the grip is dragged.
  final ValueChanged<Offset>? onMoved;

  Color get _iconColor => style.iconColor ?? chartColors.defaultTextColor;

  Color get _background =>
      style.toolbarBackgroundColor ??
      chartColors.bgColor.withValues(alpha: .94);

  Color get _popoverBackground =>
      style.popoverBackgroundColor ?? _background.withValues(alpha: .98);

  Color get _borderColor =>
      style.toolbarBorderColor ?? _iconColor.withValues(alpha: .25);

  @override
  Widget build(BuildContext context) {
    final canEditLabel = style.showLabelTextControl && line is LabelledDrawing;
    final canFill = style.showFillControl && line is FilledDrawing;
    final canAlert = style.showAlertControl && line is HorizontalLine;

    final controls = <Widget>[
      if (style.toolbarDraggable && onMoved != null) _buildGrip(),
      if (style.showColorControl) _buildColorControl(),
      if (style.showThicknessControl) _buildThicknessControl(),
      if (style.showLineStyleControl) _buildLineStyleControl(),
      if (canFill) _buildFillControl(line as FilledDrawing),
      if (canEditLabel) _buildLabelTextControl(),
      if (style.showLabelControl) _buildLabelToggle(),
      if (canAlert) _buildAlertToggle(line as HorizontalLine),
      if (style.showLockControl) _buildLockToggle(),
      if (style.showDeleteControl || style.showDoneControl) _buildSeparator(),
      if (style.showDeleteControl)
        _ToolbarButton(
          icon: Icons.delete_outline_rounded,
          tooltip: translations.delete,
          color: style.deleteColor,
          style: style,
          onPressed: onDelete,
        ),
      if (style.showDoneControl)
        _ToolbarButton(
          icon: Icons.check_circle_outline_rounded,
          tooltip: translations.done,
          color: style.doneColor,
          style: style,
          onPressed: onDone,
        ),
    ];

    // Claims the gesture arena so panning or tapping the bar never scrolls,
    // zooms or reselects the chart underneath it.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      onScaleStart: (_) {},
      onScaleUpdate: (_) {},
      onScaleEnd: (_) {},
      child: Container(
        padding: style.toolbarPadding,
        decoration: BoxDecoration(
          color: _background,
          borderRadius: BorderRadius.circular(style.toolbarBorderRadius),
          border: style.toolbarBorderWidth <= 0
              ? null
              : Border.all(
                  color: _borderColor,
                  width: style.toolbarBorderWidth,
                ),
          boxShadow:
              style.toolbarShadows ??
              [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .32),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
        ),
        child: style.toolbarAxis == Axis.horizontal
            ? Row(mainAxisSize: MainAxisSize.min, children: controls)
            : Column(mainAxisSize: MainAxisSize.min, children: controls),
      ),
    );
  }

  // ── Controls ──────────────────────────────────────────────────────────────

  Widget _buildGrip() {
    return Tooltip(
      message: translations.move,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: GestureDetector(
          onPanUpdate: (details) => onMoved?.call(details.delta),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            child: Icon(
              style.toolbarAxis == Axis.horizontal
                  ? Icons.drag_indicator_rounded
                  : Icons.drag_handle_rounded,
              size: style.iconSize,
              color: _iconColor.withValues(alpha: .7),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSeparator() {
    final horizontal = style.toolbarAxis == Axis.horizontal;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontal ? 4 : 6,
        vertical: horizontal ? 6 : 4,
      ),
      child: SizedBox(
        width: horizontal ? style.toolbarBorderWidth.clamp(0.6, 2.0) : 18,
        height: horizontal ? 18 : style.toolbarBorderWidth.clamp(0.6, 2.0),
        child: ColoredBox(color: _borderColor),
      ),
    );
  }

  Widget _buildColorControl() {
    return _Popover(
      style: style,
      background: _popoverBackground,
      borderColor: _borderColor,
      tooltip: translations.color,
      button: _ColorSwatchIcon(
        color: line.color,
        size: style.iconSize,
        borderColor: _iconColor.withValues(alpha: .55),
      ),
      contentBuilder: (close) => _ColorPanel(
        line: line,
        style: style,
        translations: translations,
        labelColor: _iconColor,
        onChanged: onChanged,
        onCommitted: onCommitted,
      ),
    );
  }

  Widget _buildThicknessControl() {
    return _Popover(
      style: style,
      background: _popoverBackground,
      borderColor: _borderColor,
      tooltip: translations.thickness,
      button: Icon(
        Icons.line_weight_rounded,
        size: style.iconSize,
        color: _iconColor,
      ),
      contentBuilder: (close) => _ThicknessPanel(
        line: line,
        style: style,
        translations: translations,
        labelColor: _iconColor,
        onChanged: onChanged,
        onCommitted: onCommitted,
      ),
    );
  }

  Widget _buildLineStyleControl() {
    return _Popover(
      style: style,
      background: _popoverBackground,
      borderColor: _borderColor,
      tooltip: translations.lineStyle,
      button: Icon(
        switch (line.style) {
          LineStyle.solid => Icons.remove_rounded,
          LineStyle.dashed => Icons.more_horiz_rounded,
          LineStyle.dotted => Icons.more_vert_rounded,
        },
        size: style.iconSize,
        color: _iconColor,
      ),
      contentBuilder: (close) => _LineStylePanel(
        line: line,
        style: style,
        translations: translations,
        labelColor: _iconColor,
        onSelected: () {
          onChanged();
          onCommitted();
          close();
        },
      ),
    );
  }

  Widget _buildFillControl(FilledDrawing filled) {
    return _Popover(
      style: style,
      background: _popoverBackground,
      borderColor: _borderColor,
      tooltip: translations.fill,
      button: Icon(
        Icons.format_color_fill_rounded,
        size: style.iconSize,
        color: _iconColor,
      ),
      contentBuilder: (close) => SizedBox(
        width: 184,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _PanelTitle(translations.fill, color: _iconColor),
            StatefulBuilder(
              builder: (context, setState) => _ValueSlider(
                value: filled.fillOpacity.clamp(0.0, 1.0),
                min: 0,
                max: 1,
                accent: style.accentColor,
                labelColor: _iconColor,
                format: (value) => '${(value * 100).round()}%',
                onChanged: (value) {
                  setState(() => filled.fillOpacity = value);
                  onChanged();
                },
                onChangeEnd: (_) => onCommitted(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertToggle(HorizontalLine level) {
    return _ToolbarButton(
      icon: level.alert
          ? Icons.notifications_active_rounded
          : Icons.notifications_none_rounded,
      tooltip: level.alert ? translations.clearAlert : translations.alert,
      color: level.alert ? style.accentColor : _iconColor,
      style: style,
      onPressed: () {
        level.alert = !level.alert;
        onChanged();
        onCommitted();
      },
    );
  }

  Widget _buildLabelTextControl() {
    return _Popover(
      style: style,
      background: _popoverBackground,
      borderColor: _borderColor,
      tooltip: translations.label,
      button: Icon(
        Icons.text_fields_rounded,
        size: style.iconSize,
        color: _iconColor,
      ),
      contentBuilder: (close) => _LabelPanel(
        line: line,
        style: style,
        translations: translations,
        labelColor: _iconColor,
        onChanged: onChanged,
        onCommitted: onCommitted,
        onSubmitted: close,
      ),
    );
  }

  Widget _buildLabelToggle() {
    return _ToolbarButton(
      icon: line.showLabel
          ? Icons.visibility_rounded
          : Icons.visibility_off_rounded,
      tooltip: line.showLabel ? translations.hideLabel : translations.showLabel,
      color: line.showLabel ? style.accentColor : _iconColor,
      style: style,
      onPressed: () {
        line.showLabel = !line.showLabel;
        onChanged();
        onCommitted();
      },
    );
  }

  Widget _buildLockToggle() {
    return _ToolbarButton(
      icon: line.locked ? Icons.lock_rounded : Icons.lock_open_rounded,
      tooltip: line.locked ? translations.unlock : translations.lock,
      color: line.locked ? style.accentColor : _iconColor,
      style: style,
      onPressed: () {
        line.locked = !line.locked;
        onChanged();
        onCommitted();
      },
    );
  }
}

/// One icon button in the toolbar.
class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.style,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final DrawingStyle style;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final touchSize = style.iconSize + 16;
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: style.iconSize, color: color),
        splashRadius: touchSize / 2,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        constraints: BoxConstraints(minWidth: touchSize, minHeight: touchSize),
        onPressed: onPressed,
      ),
    );
  }
}

/// A toolbar button that opens a styled popover above the chart.
///
/// The panel is hosted in the app's overlay, so its sliders and text fields
/// are not fighting the chart's pan and zoom recognisers.
class _Popover extends StatefulWidget {
  const _Popover({
    required this.style,
    required this.background,
    required this.borderColor,
    required this.tooltip,
    required this.button,
    required this.contentBuilder,
  });

  final DrawingStyle style;
  final Color background;
  final Color borderColor;
  final String tooltip;
  final Widget button;
  final Widget Function(VoidCallback close) contentBuilder;

  @override
  State<_Popover> createState() => _PopoverState();
}

class _PopoverState extends State<_Popover> {
  final MenuController _controller = MenuController();

  @override
  Widget build(BuildContext context) {
    final touchSize = widget.style.iconSize + 16;
    final radius = BorderRadius.circular(widget.style.popoverBorderRadius);

    return MenuAnchor(
      controller: _controller,
      alignmentOffset: const Offset(0, 8),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(widget.background),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shadowColor: WidgetStatePropertyAll(
          Colors.black.withValues(alpha: .35),
        ),
        elevation: const WidgetStatePropertyAll(6),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(12)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: widget.borderColor),
          ),
        ),
      ),
      menuChildren: [widget.contentBuilder(_controller.close)],
      builder: (context, controller, child) => Tooltip(
        message: widget.tooltip,
        child: IconButton(
          icon: widget.button,
          splashRadius: touchSize / 2,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: BoxConstraints(
            minWidth: touchSize,
            minHeight: touchSize,
          ),
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
        ),
      ),
    );
  }
}

/// The colour swatch shown on the toolbar's colour button.
class _ColorSwatchIcon extends StatelessWidget {
  const _ColorSwatchIcon({
    required this.color,
    required this.size,
    required this.borderColor,
  });

  final Color color;
  final double size;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.5),
      ),
    );
  }
}

/// Small caps heading shared by every popover.
class _PanelTitle extends StatelessWidget {
  const _PanelTitle(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Colour swatches, plus an opacity slider when enabled.
class _ColorPanel extends StatelessWidget {
  const _ColorPanel({
    required this.line,
    required this.style,
    required this.translations,
    required this.labelColor,
    required this.onChanged,
    required this.onCommitted,
  });

  final ChartLine line;
  final DrawingStyle style;
  final DrawingTranslations translations;
  final Color labelColor;
  final VoidCallback onChanged;
  final VoidCallback onCommitted;

  @override
  Widget build(BuildContext context) {
    const gap = 8.0;
    final perRow = style.swatchesPerRow < 1 ? 1 : style.swatchesPerRow;
    final width = perRow * style.swatchSize + (perRow - 1) * gap;

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _PanelTitle(translations.color, color: labelColor),
          Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final color in style.colorOptions)
                _Swatch(
                  color: color,
                  size: style.swatchSize,
                  selected: _sameHue(color, line.color),
                  accent: style.accentColor,
                  onTap: () {
                    // Keep the opacity the user already picked.
                    line.color = color.withValues(alpha: line.color.a);
                    onChanged();
                    onCommitted();
                  },
                ),
            ],
          ),
          if (style.showOpacityControl) ...[
            const SizedBox(height: 10),
            _PanelTitle(translations.opacity, color: labelColor),
            _ValueSlider(
              value: line.color.a,
              min: 0.1,
              max: 1.0,
              accent: style.accentColor,
              labelColor: labelColor,
              format: (value) => '${(value * 100).round()}%',
              onChanged: (value) {
                line.opacity = value;
                onChanged();
              },
              onChangeEnd: (_) => onCommitted(),
            ),
          ],
        ],
      ),
    );
  }

  /// Compares swatch to line ignoring alpha, so opacity does not clear the tick.
  static bool _sameHue(Color a, Color b) =>
      a.withValues(alpha: 1).toARGB32() == b.withValues(alpha: 1).toARGB32();
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.size,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final Color color;
  final double size;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? accent : Colors.white.withValues(alpha: .35),
            width: selected ? 2.5 : 1,
          ),
        ),
        child: selected
            ? Icon(
                Icons.check_rounded,
                size: size * 0.6,
                color: _contrastOn(color),
              )
            : null,
      ),
    );
  }

  static Color _contrastOn(Color color) =>
      color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
}

/// Thickness presets and a fine slider.
class _ThicknessPanel extends StatelessWidget {
  const _ThicknessPanel({
    required this.line,
    required this.style,
    required this.translations,
    required this.labelColor,
    required this.onChanged,
    required this.onCommitted,
  });

  final ChartLine line;
  final DrawingStyle style;
  final DrawingTranslations translations;
  final Color labelColor;
  final VoidCallback onChanged;
  final VoidCallback onCommitted;

  @override
  Widget build(BuildContext context) {
    final (min, max) = style.thicknessRange;

    return SizedBox(
      width: 184,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _PanelTitle(translations.thickness, color: labelColor),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final thickness in style.thicknessOptions)
                _PreviewChip(
                  width: 52,
                  selected: (line.thickness - thickness).abs() < 0.01,
                  accent: style.accentColor,
                  borderColor: labelColor,
                  onTap: () {
                    line.thickness = thickness;
                    onChanged();
                    onCommitted();
                  },
                  child: _StrokePreview(
                    color: line.color,
                    thickness: thickness,
                    lineStyle: line.style,
                    style: style,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _ValueSlider(
            value: line.thickness.clamp(min, max),
            min: min,
            max: max,
            accent: style.accentColor,
            labelColor: labelColor,
            format: (value) => value.toStringAsFixed(1),
            onChanged: (value) {
              line.thickness = double.parse(value.toStringAsFixed(1));
              onChanged();
            },
            onChangeEnd: (_) => onCommitted(),
          ),
        ],
      ),
    );
  }
}

/// Solid, dashed and dotted previews.
class _LineStylePanel extends StatelessWidget {
  const _LineStylePanel({
    required this.line,
    required this.style,
    required this.translations,
    required this.labelColor,
    required this.onSelected,
  });

  final ChartLine line;
  final DrawingStyle style;
  final DrawingTranslations translations;
  final Color labelColor;
  final VoidCallback onSelected;

  String _name(LineStyle lineStyle) => switch (lineStyle) {
    LineStyle.solid => translations.solid,
    LineStyle.dashed => translations.dashed,
    LineStyle.dotted => translations.dotted,
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _PanelTitle(translations.lineStyle, color: labelColor),
          for (final option in style.lineStyleOptions)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _PreviewChip(
                width: 146,
                selected: line.style == option,
                accent: style.accentColor,
                borderColor: labelColor,
                onTap: () {
                  line.style = option;
                  onSelected();
                },
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 56,
                      child: _StrokePreview(
                        color: line.color,
                        thickness: line.thickness,
                        lineStyle: option,
                        style: style,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _name(option),
                        style: TextStyle(color: labelColor, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A text field bound to the name a drawing carries.
class _LabelPanel extends StatefulWidget {
  const _LabelPanel({
    required this.line,
    required this.style,
    required this.translations,
    required this.labelColor,
    required this.onChanged,
    required this.onCommitted,
    required this.onSubmitted,
  });

  final ChartLine line;
  final DrawingStyle style;
  final DrawingTranslations translations;
  final Color labelColor;
  final VoidCallback onChanged;
  final VoidCallback onCommitted;
  final VoidCallback onSubmitted;

  @override
  State<_LabelPanel> createState() => _LabelPanelState();
}

class _LabelPanelState extends State<_LabelPanel> {
  late final TextEditingController _controller = TextEditingController(
    text: _title,
  );

  String? get _title {
    final line = widget.line;
    return line is LabelledDrawing ? line.labelText : null;
  }

  void _write(String value) {
    final line = widget.line;
    if (line is! LabelledDrawing) return;

    final title = value.trim().isEmpty ? null : value;
    line.labelText = title;
    // A label the user has just typed is only useful once it is visible.
    if (title != null) widget.line.showLabel = true;
    widget.onChanged();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _PanelTitle(widget.translations.label, color: widget.labelColor),
          TextField(
            controller: _controller,
            autofocus: true,
            style: TextStyle(color: widget.labelColor, fontSize: 12),
            cursorColor: widget.style.accentColor,
            decoration: InputDecoration(
              isDense: true,
              hintText: widget.translations.labelHint,
              hintStyle: TextStyle(
                color: widget.labelColor.withValues(alpha: .5),
                fontSize: 12,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: widget.labelColor.withValues(alpha: .3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: widget.style.accentColor),
              ),
            ),
            onChanged: _write,
            onSubmitted: (value) {
              _write(value);
              widget.onCommitted();
              widget.onSubmitted();
            },
            onTapOutside: (_) => widget.onCommitted(),
          ),
        ],
      ),
    );
  }
}

/// A tappable, selectable container used by the thickness and style previews.
class _PreviewChip extends StatelessWidget {
  const _PreviewChip({
    required this.width,
    required this.selected,
    required this.accent,
    required this.borderColor,
    required this.onTap,
    required this.child,
  });

  final double width;
  final bool selected;
  final Color accent;
  final Color borderColor;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: 30,
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: .18) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? accent : borderColor.withValues(alpha: .28),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Draws a sample of a stroke at a given thickness and style.
class _StrokePreview extends StatelessWidget {
  const _StrokePreview({
    required this.color,
    required this.thickness,
    required this.lineStyle,
    required this.style,
  });

  final Color color;
  final double thickness;
  final LineStyle lineStyle;
  final DrawingStyle style;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StrokePreviewPainter(
        color: color,
        thickness: thickness,
        lineStyle: lineStyle,
        style: style,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _StrokePreviewPainter extends CustomPainter {
  _StrokePreviewPainter({
    required this.color,
    required this.thickness,
    required this.lineStyle,
    required this.style,
  });

  final Color color;
  final double thickness;
  final LineStyle lineStyle;
  final DrawingStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..isAntiAlias = true;

    final y = size.height / 2;
    paintStyledLine(
      canvas,
      Offset(6, y),
      Offset(size.width - 6, y),
      paint,
      style: lineStyle,
      dashLength: style.dashLength,
      dashGap: style.dashGap,
      dotGap: style.dotGap,
    );
  }

  @override
  bool shouldRepaint(_StrokePreviewPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.thickness != thickness ||
      oldDelegate.lineStyle != lineStyle;
}

/// A compact slider with its value printed beside it.
class _ValueSlider extends StatelessWidget {
  const _ValueSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.accent,
    required this.labelColor,
    required this.format,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double value;
  final double min;
  final double max;
  final Color accent;
  final Color labelColor;
  final String Function(double) format;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: accent,
              inactiveTrackColor: labelColor.withValues(alpha: .3),
              thumbColor: accent,
              overlayColor: accent.withValues(alpha: .15),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            format(value),
            textAlign: TextAlign.end,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              color: labelColor,
              fontSize: 11,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
