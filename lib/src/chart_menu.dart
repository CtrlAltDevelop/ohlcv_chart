import 'package:flutter/material.dart';

import 'entity/k_line_entity.dart';
import 'entity/line.dart';

/// One line of the chart's right-click menu.
///
/// [ChartMenuItem] is something to do; [ChartMenuDivider] is the rule between
/// one group of them and the next.
sealed class ChartMenuEntry {
  const ChartMenuEntry();
}

/// A rule between two groups of menu items.
class ChartMenuDivider extends ChartMenuEntry {
  /// Creates a divider.
  const ChartMenuDivider();
}

/// Something the right-click menu offers to do.
class ChartMenuItem extends ChartMenuEntry {
  /// Creates an item labelled [label] that runs [onSelected] when picked.
  const ChartMenuItem({
    required this.label,
    required this.onSelected,
    this.icon,
    this.enabled = true,
    this.checked,
    this.destructive = false,
  });

  /// What the item says.
  final String label;

  /// What picking it does.
  final VoidCallback onSelected;

  /// An icon shown before the label, or null for none.
  final IconData? icon;

  /// Whether the item can be picked at all.
  final bool enabled;

  /// Whether the item is a toggle, and which way it is set.
  ///
  /// Null for an item that is not a toggle. A tick is shown when it is true.
  final bool? checked;

  /// Whether the item throws something away, and is coloured to say so.
  final bool destructive;
}

/// What the user right-clicked, handed to a [ChartMenuBuilder].
///
/// [drawing] is the drawing under the pointer, or null for empty chart. The
/// rest says where the click landed, so an item of your own can act on the
/// candle or the price beneath it.
typedef ChartMenuRequest = ({
  Offset position,
  ChartLine? drawing,
  KLineEntity? candle,
  double? price,
  List<ChartMenuEntry> defaults,
});

/// Builds the menu for one right-click.
///
/// The request's `defaults` are what the chart would have shown, so returning
/// them with something appended adds an item, and returning a list of your own
/// replaces the menu entirely. An empty list shows no menu at all.
typedef ChartMenuBuilder = List<ChartMenuEntry> Function(
  ChartMenuRequest request,
);

/// Shows [entries] as a Material menu at [position] on the screen.
///
/// Used by the chart for its own right-click menu; usable on its own if you
/// would rather open the same menu from a button.
Future<void> showChartMenu({
  required BuildContext context,
  required Offset position,
  required List<ChartMenuEntry> entries,
}) async {
  if (entries.isEmpty) return;

  final overlay = Overlay.of(context).context.findRenderObject();
  if (overlay is! RenderBox) return;

  final theme = Theme.of(context);
  final picked = await showMenu<ChartMenuItem>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromLTWH(position.dx, position.dy, 0, 0),
      Offset.zero & overlay.size,
    ),
    items: [
      for (final entry in entries)
        switch (entry) {
          ChartMenuDivider() => const PopupMenuDivider(),
          ChartMenuItem(
            :final label,
            :final icon,
            :final enabled,
            :final checked,
            :final destructive,
          ) =>
            PopupMenuItem<ChartMenuItem>(
              value: entry,
              enabled: enabled,
              height: 36,
              child: _MenuRow(
                label: label,
                icon: icon,
                checked: checked,
                color: destructive ? theme.colorScheme.error : null,
              ),
            ),
        },
    ],
  );

  picked?.onSelected();
}

/// One row of the menu: a tick or an icon, then the label.
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.label,
    required this.icon,
    required this.checked,
    required this.color,
  });

  final String label;
  final IconData? icon;
  final bool? checked;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // A toggle shows a tick where it is set and nothing where it is not, so the
    // labels stay in one column either way.
    final leading = checked != null
        ? (checked! ? Icons.check_rounded : null)
        : icon;

    return Row(
      children: [
        SizedBox(
          width: 26,
          child: leading == null ? null : Icon(leading, size: 17, color: color),
        ),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
