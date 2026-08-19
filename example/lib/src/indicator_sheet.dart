import 'package:flutter/material.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

/// The sheet behind "Add indicator": pick a type, set it up, colour it.
///
/// Everything it shows comes from [indicatorCatalog], so an indicator added to
/// the package turns up here with its own settings and colour slots and no
/// change to this file.
class IndicatorSheet extends StatefulWidget {
  /// Creates the sheet, editing [existing] when one is given.
  const IndicatorSheet({required this.theme, this.existing, super.key});

  /// The chart's palette, used to show what each line's default colour is.
  final ChartColors theme;

  /// The indicator being edited, or null when adding a new one.
  final Indicator? existing;

  /// Opens the sheet and returns the configured indicator, or null if the
  /// user backed out.
  static Future<Indicator?> show(
    BuildContext context, {
    required ChartColors theme,
    Indicator? existing,
  }) {
    return showModalBottomSheet<Indicator>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => IndicatorSheet(theme: theme, existing: existing),
    );
  }

  @override
  State<IndicatorSheet> createState() => _IndicatorSheetState();
}

class _IndicatorSheetState extends State<IndicatorSheet> {
  /// Colours offered per line, alongside the theme's own.
  static const _swatches = [
    Color(0xFF4DABF7),
    Color(0xFF51CF66),
    Color(0xFFFF6B6B),
    Color(0xFFFFD43B),
    Color(0xFFDA77F2),
    Color(0xFF20C997),
    Color(0xFFFF922B),
  ];

  late IndicatorType _type;
  late Map<String, num> _values;

  /// Chosen colour per line; null means "leave it to the theme".
  late List<Color?> _colors;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _type = existing == null
        ? indicatorCatalog.first
        : indicatorTypeOf(existing) ?? indicatorCatalog.first;
    _values =
        (existing == null ? null : _type.valuesOf(existing)) ?? _type.defaults;
    _colors = List<Color?>.generate(
      _type.create(values: _values).lines.length,
      (line) => existing?.colors?.elementAtOrNull(line),
    );
  }

  void _selectType(IndicatorType type) {
    setState(() {
      _type = type;
      _values = type.defaults;
      _colors = List<Color?>.filled(type.lineLabels().length, null);
    });
  }

  void _setValue(IndicatorSetting setting, num value) {
    setState(() {
      _values = Map<String, num>.from(_values)
        ..[setting.key] = setting.coerce(value);
      // A setting can change how many lines there are, so keep them in step.
      final lines = _type.lineLabels(values: _values).length;
      if (_colors.length != lines) {
        _colors = List<Color?>.generate(
          lines,
          (i) => i < _colors.length ? _colors[i] : null,
        );
      }
    });
  }

  /// The colours to hand the indicator: null when nothing was overridden, so
  /// the theme keeps its say.
  List<Color>? get _chosenColors {
    if (_colors.every((color) => color == null)) return null;
    final defaults = _type.defaultColors(widget.theme, values: _values);
    return [
      for (var line = 0; line < _colors.length; line++)
        _colors[line] ?? defaults[line],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final preview = _type.create(values: _values, colors: _chosenColors);
    final lineLabels = _type.lineLabels(values: _values);
    final defaults = _type.defaultColors(widget.theme, values: _values);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existing == null ? 'Add indicator' : 'Edit indicator',
                style: text.titleMedium,
              ),
              const SizedBox(height: 12),
              if (widget.existing == null) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final type in indicatorCatalog)
                      ChoiceChip(
                        label: Text(type.name),
                        selected: type.name == _type.name,
                        onSelected: (_) => _selectType(type),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Text(_type.description, style: text.bodySmall),
              const SizedBox(height: 12),
              for (final setting in _type.settings)
                _SettingField(
                  setting: setting,
                  value: _values[setting.key] ?? setting.defaultValue,
                  onChanged: (value) => _setValue(setting, value),
                ),
              if (_type.settings.isEmpty)
                Text('No settings to choose.', style: text.bodySmall),
              const SizedBox(height: 12),
              Text('Colours', style: text.labelLarge),
              for (var line = 0; line < lineLabels.length; line++)
                _ColorRow(
                  label: lineLabels[line],
                  themeColor: defaults[line],
                  selected: _colors[line],
                  swatches: _swatches,
                  onChanged: (color) => setState(() => _colors[line] = color),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      preview.label,
                      style: text.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(preview),
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(widget.existing == null ? 'Add' : 'Update'),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Adding an indicator that is already on the chart updates it '
                  'instead of stacking a second copy.',
                  style: text.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One setting, as a slider with its current value beside it.
class _SettingField extends StatelessWidget {
  const _SettingField({
    required this.setting,
    required this.value,
    required this.onChanged,
  });

  final IndicatorSetting setting;
  final num value;
  final ValueChanged<num> onChanged;

  @override
  Widget build(BuildContext context) {
    final divisions = ((setting.max - setting.min) / setting.step).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              setting.label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: Slider(
              value: value.toDouble().clamp(
                setting.min.toDouble(),
                setting.max.toDouble(),
              ),
              min: setting.min.toDouble(),
              max: setting.max.toDouble(),
              divisions: divisions > 0 ? divisions : null,
              label: _format(value),
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(_format(value), textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }

  String _format(num value) => setting.isInteger
      ? value.round().toString()
      : value.toDouble().toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
}

/// One line's colour: the theme's own, or a swatch chosen for it.
class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.label,
    required this.themeColor,
    required this.selected,
    required this.swatches,
    required this.onChanged,
  });

  final String label;
  final Color themeColor;
  final Color? selected;
  final List<Color> swatches;
  final ValueChanged<Color?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Swatch(
                  color: themeColor,
                  isSelected: selected == null,
                  isDefault: true,
                  onTap: () => onChanged(null),
                ),
                for (final color in swatches)
                  _Swatch(
                    color: color,
                    isSelected: selected == color,
                    onTap: () => onChanged(color),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.isSelected,
    required this.onTap,
    this.isDefault = false,
  });

  final Color color;
  final bool isSelected;
  final bool isDefault;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isDefault ? 'Theme default' : '',
      child: InkResponse(
        onTap: onTap,
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: isDefault
              ? const Icon(Icons.auto_awesome, size: 12, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}
