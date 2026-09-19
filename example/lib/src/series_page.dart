import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
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

  /// What each asset is worth, for the pie.
  static const _holdings = [42.0, 26.0, 18.0, 14.0];
  static const _holdingNames = ['BTC', 'ETH', 'SOL', 'Cash'];

  /// Two strategies scored over the same five measures, for the radar.
  static const _scores = [
    [4.4, 3.1, 4.8, 2.2, 3.6],
    [3.0, 4.7, 2.4, 4.1, 4.4],
  ];
  static const _measures = ['Return', 'Sharpe', 'Win rate', 'Cost', 'Drawdown'];

  int? _slice;
  String? _corner;
  HeatmapTouchDetails? _square;

  /// Orders per weekday and hour of the day, for the heatmap.
  static final _byHourAndDay = [
    for (var hour = 0; hour < 12; hour++)
      [
        for (var day = 0; day < 7; day++)
          hour < 2 && day > 4
              ? null
              : (math.sin(hour / 2.4) + 1.4) *
                        (math.cos(day / 2.1 + 1) + 1.6) *
                        14 +
                    (hour * day % 5) * 2.0,
      ],
  ];
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

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
                      radius: const BorderRadius.vertical(
                        top: Radius.circular(3),
                      ),
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
            _card(context, paper, grid, 'Flows per month, stacked and turned', [
              SizedBox(
                height: 200,
                child: SeriesChart(
                  orientation: SeriesOrientation.horizontal,
                  series: [
                    BarSeries.values(
                      const [3.2, 4.1, 2.6, 5.4, 4.8, 6.1],
                      color: _green,
                      stack: 'flow',
                      label: 'In',
                    ),
                    BarSeries.values(
                      const [1.4, 2.2, 3.1, 1.8, 2.6, 2.1],
                      color: _red,
                      stack: 'flow',
                      radius: const BorderRadius.vertical(
                        top: Radius.circular(3),
                      ),
                      label: 'Out',
                    ),
                  ],
                  xAxis: SeriesXAxis(
                    labels: _months.take(6).toList(),
                    title: 'Month',
                  ),
                  yAxis: SeriesYAxis(
                    formatter: (v) => '${v.toStringAsFixed(0)}k',
                    title: 'Flow',
                  ),
                  grid: SeriesGrid(color: grid, dashPattern: const [4, 4]),
                  animationDuration: const Duration(milliseconds: 400),
                ),
              ),
            ]),
            _card(context, paper, grid, 'Trades: size against return', [
              SizedBox(
                height: 220,
                child: SeriesChart(
                  series: [
                    ScatterSeries(
                      points: [
                        for (var i = 0; i < 40; i++)
                          SeriesPoint(
                            1 + (i * 7 % 23).toDouble(),
                            math.sin(i / 3) * 8 + math.cos(i / 1.7) * 4,
                          ),
                      ],
                      dotBuilder: (index, point) => SeriesDot(
                        radius: 3 + (point.x / 12),
                        shape: point.y! < 0
                            ? SeriesDotShape.cross
                            : SeriesDotShape.circle,
                        color: point.y! < 0 ? _red : _green,
                      ),
                    ),
                  ],
                  xAxis: SeriesXAxis(
                    tickCount: 5,
                    title: 'Size',
                    labelBuilder: (v) => v.toStringAsFixed(0),
                  ),
                  yAxis: SeriesYAxis(
                    title: 'Return',
                    formatter: (v) => '${v.toStringAsFixed(0)}%',
                  ),
                  grid: SeriesGrid(color: grid),
                  referenceLines: [
                    SeriesReferenceLine.horizontal(0, color: grid, width: 1),
                  ],
                  touch: const SeriesTouch(
                    snap: SeriesTouchSnap.nearestPoint,
                    tooltip: SeriesTooltip(),
                  ),
                ),
              ),
            ]),
            _card(context, paper, grid, 'Holdings — hover a slice', [
              SizedBox(
                height: 220,
                child: PieChart(
                  sections: [
                    for (var i = 0; i < _holdings.length; i++)
                      PieSection(
                        value: _holdings[i],
                        color: [_purple, _blue, _amber, _green][i],
                        label: '${_holdings[i].toStringAsFixed(0)}%',
                        offset: i == _slice ? 6 : 0,
                      ),
                  ],
                  centerSpaceRadius: 46,
                  centerSpaceColor: paper,
                  centerChild: Text(
                    _slice == null ? 'Holdings' : _holdingNames[_slice!],
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  sectionsSpace: 2,
                  onTouch: (d) => setState(() => _slice = d?.index),
                  animationDuration: const Duration(milliseconds: 600),
                ),
              ),
            ]),
            _card(
              context,
              paper,
              grid,
              _square == null
                  ? 'Orders by hour and weekday'
                  : '${_weekdays[_square!.x]} '
                        '${(_square!.y + 9).toString().padLeft(2, '0')}:00 — '
                        '${_square!.value?.round() ?? 0} orders',
              [
                SizedBox(
                  height: 280,
                  child: HeatmapChart.matrix(
                    _byHourAndDay,
                    scale: HeatmapGradientScale.of(_blue),
                    xAxis: const HeatmapAxis(labels: _weekdays),
                    yAxis: HeatmapAxis(
                      size: 36,
                      labelBuilder: (index) =>
                          '${(index + 9).toString().padLeft(2, '0')}:00',
                    ),
                    spacing: 3,
                    radius: const BorderRadius.all(Radius.circular(3)),
                    onTouch: (d) => setState(() => _square = d),
                    animationDuration: const Duration(milliseconds: 500),
                  ),
                ),
                const SizedBox(height: 10),
                HeatmapLegend(
                  scale: HeatmapGradientScale.of(_blue),
                  low: 'Quiet',
                  high: 'Busy',
                  width: 120,
                ),
              ],
            ),
            _card(
              context,
              paper,
              grid,
              _corner == null ? 'Two strategies scored' : 'Scored: $_corner',
              [
                SizedBox(
                  height: 260,
                  child: RadarChart(
                    features: _measures,
                    series: [
                      RadarSeries(
                        values: _scores[0],
                        color: _blue,
                        label: 'Momentum',
                        dot: const SeriesDot(radius: 2.5),
                      ),
                      RadarSeries(
                        values: _scores[1],
                        color: _amber,
                        label: 'Mean reversion',
                        dot: const SeriesDot(radius: 2.5),
                      ),
                    ],
                    maxValue: 5,
                    gridColor: grid,
                    spokeColor: grid,
                    showTicks: true,
                    onTouch: (d) => setState(
                      () => _corner = d == null
                          ? null
                          : '${_measures[d.featureIndex]} '
                                '${d.value.toStringAsFixed(1)}',
                    ),
                    animationDuration: const Duration(milliseconds: 600),
                  ),
                ),
              ],
            ),
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
