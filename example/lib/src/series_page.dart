import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

import 'demo_state.dart';

/// Business charts drawn with `SeriesChart`: a sparkline, several series over
/// a window of long data, two panels sharing one crosshair, and a line split
/// at zero.
class SeriesPage extends StatefulWidget {
  /// Creates the series demo over [state].
  const SeriesPage({required this.state, super.key});

  /// The demo's settings, shared with the other pages.
  final DemoState state;

  @override
  State<SeriesPage> createState() => _SeriesPageState();
}

class _SeriesPageState extends State<SeriesPage> {
  static const _days = 120;
  static const _purple = Color(0xFF9775FA);
  static const _blue = Color(0xFF4DABF7);
  static const _amber = Color(0xFFFAB005);
  static const _green = Color(0xFF12B886);
  static const _red = Color(0xFFFA5252);
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  final SeriesChartController _crosshair = SeriesChartController();
  SeriesWindow _window = const SeriesWindow(_days - 30, _days - 1);
  int? _sparkIndex;

  late final List<DateTime> _dates = [
    for (var i = 0; i < _days; i++) DateTime(2026).add(Duration(days: i)),
  ];
  late final List<String> _monthLabels = [
    for (final d in _dates) d.day == 1 ? _months[d.month - 1] : '',
  ];
  late final List<double> _deposits = _walk(1800, 0.2, 0);
  late final List<double> _withdrawals = _walk(1100, 0.3, 2);
  late final List<double> _balance = _walk(12000, 0.08, 1);
  late final List<double> _average = [
    for (var i = 0; i < _days; i++)
      _balance.sublist(math.max(0, i - 9), i + 1).reduce((a, b) => a + b) /
          (i - math.max(0, i - 9) + 1),
  ];
  late final List<double> _profit = [
    0,
    for (var i = 1; i < _days; i++) _balance[i] - _balance[i - 1],
  ];
  late final List<double> _roi = [
    for (var i = 0; i < 40; i++) math.sin(i / 5) * 12 + i * 0.25 - 4,
  ];

  static List<double> _walk(double base, double swing, double phase) => [
    for (var i = 0; i < _days; i++)
      base +
          math.sin(i / 9 + phase) * base * swing +
          math.cos(i / 2.5 + phase) * base * swing * 0.3,
  ];

  static String _usd(double v) =>
      '\$${v.abs() >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0)}';

  String _date(int index) {
    final d = _dates[index.clamp(0, _days - 1)];
    return '${_months[d.month - 1]} ${d.day}';
  }

  @override
  void dispose() {
    _crosshair.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        final dark = widget.state.dark;
        final grid = dark ? const Color(0xFF2C2E33) : const Color(0xFFDEE2E6);
        final paper = dark ? const Color(0xFF16191F) : Colors.white;
        final tooltip = SeriesTooltip(
          backgroundColor: dark ? const Color(0xFF25282E) : Colors.white,
          borderColor: grid,
          valueStyle: TextStyle(color: dark ? Colors.white : Colors.black87),
          titleStyle: TextStyle(color: dark ? Colors.white60 : Colors.black54),
          valueFormatter: (v) => _usd(v.value),
          title: (d) => _date(d.index),
        );

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _card(context, paper, grid, 'Balance sparkline — press and drag', [
              SizedBox(
                height: 58,
                child: SeriesChart(
                  series: [
                    LineSeries.values(
                      _balance,
                      color: _purple,
                      width: _sparkIndex == null ? 1 : 2,
                      curve: LineCurve.monotone,
                      fill: SeriesFill.fade(_purple, opacity: 0.3),
                      dotBuilder: _sparkIndex == null
                          ? null
                          : (i, _) => i == _sparkIndex
                                ? const SeriesDot(radius: 3)
                                : null,
                    ),
                  ],
                  xAxis: SeriesXAxis.hidden,
                  yAxis: SeriesYAxis.hidden,
                  grid: SeriesGrid.none,
                  touch: SeriesTouch(
                    line: null,
                    showMarkers: false,
                    tooltip: SeriesTooltip(
                      placement: SeriesTooltipPlacement.above,
                      backgroundColor: tooltip.backgroundColor,
                      borderColor: grid,
                      valueStyle: tooltip.valueStyle,
                      titleStyle: tooltip.titleStyle,
                      valueFormatter: tooltip.valueFormatter,
                      title: tooltip.title,
                    ),
                  ),
                  onTouch: (d) => setState(() => _sparkIndex = d?.index),
                  animationDuration: const Duration(milliseconds: 600),
                ),
              ),
            ]),
            _card(
              context,
              paper,
              grid,
              'Deposits and withdrawals — long-press',
              [
                SizedBox(
                  height: 220,
                  child: SeriesChart(
                    series: [
                      LineSeries.values(
                        _deposits,
                        label: 'Deposits',
                        color: _blue,
                        fill: SeriesFill.fade(_blue),
                      ),
                      LineSeries.values(
                        _withdrawals,
                        label: 'Withdrawals',
                        color: _amber,
                        fill: SeriesFill.fade(_amber),
                      ),
                    ],
                    minX: _window.start - 0.5,
                    maxX: _window.end + 0.5,
                    xAxis: SeriesXAxis(labels: _labelsFor(_window)),
                    yAxis: SeriesYAxis(width: 40, formatter: _usd),
                    grid: SeriesGrid(color: grid, dashPattern: const [4, 4]),
                    border: BorderSide(color: grid),
                    touch: SeriesTouch(
                      trigger: SeriesTouchTrigger.longPress,
                      tooltip: tooltip,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(left: 40),
                  child: SeriesRangeSelector(
                    series: [
                      LineSeries.values(_deposits, color: _blue, width: 1),
                      LineSeries.values(_withdrawals, color: _amber, width: 1),
                    ],
                    window: _window,
                    minSpan: 4,
                    border: BorderSide(color: grid),
                    maskColor: paper.withValues(alpha: 0.6),
                    handleColor: paper,
                    onChanged: (next) => setState(() => _window = next),
                  ),
                ),
              ],
            ),
            _card(context, paper, grid, 'Balance and profit — one crosshair', [
              SizedBox(
                height: 180,
                child: SeriesChart(
                  series: [
                    LineSeries.values(
                      _balance,
                      label: 'Balance',
                      color: _purple,
                      fill: SeriesFill.fade(_purple, opacity: 0.14),
                    ),
                    LineSeries.values(
                      _average,
                      label: 'Average',
                      color: _amber,
                      dashPattern: const [6, 4],
                    ),
                  ],
                  xPadding: 0.5,
                  xAxis: SeriesXAxis.hidden,
                  yAxis: SeriesYAxis(width: 40, formatter: _usd),
                  grid: SeriesGrid(color: grid, dashPattern: const [4, 4]),
                  border: BorderSide(color: grid),
                  controller: _crosshair,
                  touch: SeriesTouch(
                    trigger: SeriesTouchTrigger.longPress,
                    tooltip: SeriesTooltip(
                      builder: (context, d) => DecoratedBox(
                        decoration: BoxDecoration(
                          color: tooltip.backgroundColor,
                          border: Border.all(color: grid),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            '${_date(d.index)}\n'
                            'Balance ${_usd(_balance[d.index])}\n'
                            'P/L ${_usd(_profit[d.index])}',
                            style: tooltip.valueStyle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 96,
                child: SeriesChart(
                  series: [
                    BarSeries.values(
                      _profit,
                      color: _green,
                      negativeColor: _red,
                      radius: 3,
                      minWidth: 1,
                      maxWidth: 12,
                    ),
                  ],
                  xAxis: SeriesXAxis(labels: _monthLabels),
                  yAxis: SeriesYAxis(width: 40, formatter: _usd, tickCount: 3),
                  grid: SeriesGrid(
                    vertical: false,
                    color: grid,
                    dashPattern: const [4, 4],
                  ),
                  border: BorderSide(color: grid),
                  controller: _crosshair,
                  touch: const SeriesTouch(
                    trigger: SeriesTouchTrigger.longPress,
                    tooltip: null,
                  ),
                  animationDuration: const Duration(milliseconds: 450),
                ),
              ),
            ]),
            _card(context, paper, grid, 'ROI — split at zero', [
              SizedBox(
                height: 80,
                child: SeriesChart(
                  series: [
                    LineSeries.values(
                      _roi,
                      color: _green,
                      negativeColor: _red,
                      width: 1.5,
                      curve: LineCurve.monotone,
                      fill: SeriesFill.fade(_green, negativeColor: _red),
                    ),
                  ],
                  includeZero: true,
                  xAxis: SeriesXAxis.hidden,
                  yAxis: SeriesYAxis.hidden,
                  grid: SeriesGrid.none,
                  referenceLines: [
                    SeriesReferenceLine.horizontal(
                      0,
                      color: grid,
                      dashPattern: const [3, 3],
                    ),
                  ],
                  touch: SeriesTouch(
                    markerBuilder: (v) => SeriesDot(radius: 3, color: v.color),
                    tooltip: SeriesTooltip(
                      placement: SeriesTooltipPlacement.above,
                      backgroundColor: tooltip.backgroundColor,
                      borderColor: grid,
                      valueStyle: tooltip.valueStyle,
                      valueFormatter: (v) =>
                          '${v.value >= 0 ? '+' : ''}${v.value.toStringAsFixed(2)}%',
                    ),
                  ),
                  animationDuration: const Duration(milliseconds: 300),
                ),
              ),
            ]),
          ],
        );
      },
    );
  }

  /// Month names inside a window; on a short window, every fifth day instead.
  List<String> _labelsFor(SeriesWindow window) {
    if (window.span > 45) return _monthLabels;
    return [for (var i = 0; i < _days; i++) i % 5 == 0 ? _date(i) : ''];
  }

  Widget _card(
    BuildContext context,
    Color paper,
    Color border,
    String title,
    List<Widget> children,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: paper,
      border: Border.all(color: border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
}
