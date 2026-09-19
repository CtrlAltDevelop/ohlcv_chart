import 'package:material_ui/material_ui.dart';

import '../entity/k_line_entity.dart';
import '../entity/line.dart';
import 'drawing_anchors.dart';
import 'drawing_translations.dart';

/// Opens the dialog that reads out and edits [line]'s exact anchors.
///
/// A drawing placed by hand lands on whichever candle the pointer was over,
/// which is close enough to read a chart by and not close enough to hand to
/// someone else. This is where a level is typed in exactly: each anchor's price
/// and the candle it sits on, one row apiece.
///
/// Answers whether anything was changed, so the caller knows whether to save
/// the drawing and repaint. The drawing is edited in place, the same way the
/// editing toolbar edits it.
Future<bool> showDrawingCoordinatesDialog({
  required BuildContext context,
  required ChartLine line,
  required List<KLineEntity> candles,
  DrawingTranslations translations = const DrawingTranslations(),
  int fixedLength = 2,
}) async {
  final changed = await showDialog<bool>(
    context: context,
    builder: (context) => DrawingCoordinatesDialog(
      line: line,
      candles: candles,
      translations: translations,
      fixedLength: fixedLength,
    ),
  );
  return changed ?? false;
}

/// A form over one drawing's anchors: a price and a candle for each.
///
/// Usually reached through [showDrawingCoordinatesDialog], but usable on its
/// own — inside a side panel, say, rather than a dialog.
class DrawingCoordinatesDialog extends StatefulWidget {
  /// Creates a form over [line]'s anchors.
  const DrawingCoordinatesDialog({
    required this.line,
    required this.candles,
    this.translations = const DrawingTranslations(),
    this.fixedLength = 2,
    super.key,
  });

  /// The drawing being edited, in place.
  final ChartLine line;

  /// The candles the anchors are chosen from, so a time is always a real one.
  final List<KLineEntity> candles;

  /// Text for every label and button.
  final DrawingTranslations translations;

  /// How many decimal places a price is shown to.
  final int fixedLength;

  @override
  State<DrawingCoordinatesDialog> createState() =>
      _DrawingCoordinatesDialogState();
}

class _DrawingCoordinatesDialogState extends State<DrawingCoordinatesDialog> {
  late final List<DrawingAnchor> _anchors = drawingAnchors(widget.line);
  late final List<TextEditingController> _prices;
  late final List<int?> _indices;

  @override
  void initState() {
    super.initState();
    _prices = [
      for (final anchor in _anchors)
        TextEditingController(
          text: anchor.price?.toStringAsFixed(widget.fixedLength) ?? '',
        ),
    ];
    _indices = [for (final anchor in _anchors) _indexOf(anchor.time)];
  }

  @override
  void dispose() {
    for (final controller in _prices) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Where [time] sits in the candles, or null when it is not one of them.
  int? _indexOf(DateTime? time) {
    if (time == null) return null;
    final index = widget.candles.indexWhere((e) => e.dateTime == time);
    return index == -1 ? null : index;
  }

  /// Writes every row back onto the drawing, and reports whether any took.
  bool _apply() {
    var changed = false;
    for (var i = 0; i < _anchors.length; i++) {
      final price = double.tryParse(_prices[i].text.trim());
      final index = _indices[i];
      final time = index == null ? null : widget.candles[index].dateTime;

      // A row left as it was, or typed into with something that is not a
      // number, writes nothing.
      final samePrice = price == null || price == _anchors[i].price;
      final sameTime = time == null || time == _anchors[i].time;
      if (samePrice && sameTime) continue;

      if (setDrawingAnchor(
        widget.line,
        i,
        time: sameTime ? null : time,
        price: samePrice ? null : price,
      )) {
        changed = true;
      }
    }
    return changed;
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.translations;
    final editable = drawingAnchorsAreEditable(widget.line);

    return AlertDialog(
      title: Text(
        '${text.coordinatesTitle} — ${text.nameOf(widget.line)}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!editable)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(text.readOnlyAnchors),
              ),
            for (var i = 0; i < _anchors.length; i++)
              _buildRow(context, i, enabled: editable),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(text.cancel),
        ),
        FilledButton(
          onPressed: editable
              ? () => Navigator.of(context).pop(_apply())
              : null,
          child: Text(text.apply),
        ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, int index, {required bool enabled}) {
    final anchor = _anchors[index];
    final text = widget.translations;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(anchor.name, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Row(
            children: [
              // A drawing with no price of its own — a vertical line — has no
              // price to type in either.
              if (anchor.price != null)
                Expanded(
                  child: TextField(
                    controller: _prices[index],
                    enabled: enabled,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: InputDecoration(
                      labelText: text.price,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              if (anchor.price != null && anchor.time != null)
                const SizedBox(width: 8),
              if (anchor.time != null)
                Expanded(child: _buildCandleField(index, enabled: enabled)),
            ],
          ),
        ],
      ),
    );
  }

  /// A dropdown of the loaded candles, so an anchor always lands on a real one.
  Widget _buildCandleField(int index, {required bool enabled}) {
    final text = widget.translations;
    final selected = _indices[index];

    return DropdownButtonFormField<int>(
      initialValue: selected,
      isDense: true,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: text.candle,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (var i = 0; i < widget.candles.length; i++)
          if (widget.candles[i].dateTime case final time?)
            DropdownMenuItem(
              value: i,
              child: Text(
                time.toIso8601String(),
                overflow: TextOverflow.ellipsis,
              ),
            ),
      ],
      onChanged: enabled
          ? (value) => setState(() => _indices[index] = value)
          : null,
    );
  }
}
