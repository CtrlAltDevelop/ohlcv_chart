// The scenes for the chart gallery: one image per chart doc page.
//
// Kept apart from screenshots.dart only for length — it is a part of it, so
// these share the palette, the panel card and the rest of the scene helpers.
part of 'screenshots.dart';

/// A gallery scene: wide enough for two panels, tall enough for a chart that
/// needs the height.
const Size gallery = Size(1180, 460);

/// A squarer scene, for the charts that draw a circle and would otherwise sit
/// in the middle of two empty halves.
const Size square = Size(720, 460);

/// The gallery palette, in the order the charts hand colours out.
const _galleryPalette = [
  _seriesBlue,
  _seriesGreen,
  _seriesAmber,
  _seriesPurple,
  _seriesRed,
  Color(0xFF3BC9DB),
];

/// A smooth, repeatable series: no randomness, so the images never change
/// between runs.
List<double> _galleryWave(
  int count, {
  double base = 0,
  double swing = 1,
  double drift = 0,
  double phase = 0,
}) =>
    [
      for (var i = 0; i < count; i++)
        base +
            sin(i / 6.1 + phase) * swing +
            cos(i / 2.7 + phase * 1.3) * swing * 0.4 +
            i * drift,
    ];

/// The gallery's scenes, added to the set [buildScenes] shoots.
List<Scene> buildGalleryScenes() => [
      (name: 'treemap', size: gallery, act: null, build: treemapScene),
      (name: 'gauge', size: shortWide, act: null, build: gaugeScene),
      (name: 'funnel', size: shortWide, act: null, build: funnelScene),
      (name: 'sankey', size: gallery, act: null, build: sankeyScene),
      (name: 'sunburst', size: square, act: null, build: sunburstScene),
      (name: 'waffle', size: shortWide, act: null, build: waffleScene),
      (name: 'bullet', size: shortWide, act: null, build: bulletScene),
      (name: 'dumbbell', size: shortWide, act: null, build: dumbbellScene),
      (name: 'slope', size: gallery, act: null, build: slopeScene),
      (name: 'marimekko', size: gallery, act: null, build: marimekkoScene),
      (name: 'chord', size: square, act: null, build: chordScene),
      (name: 'parallel', size: gallery, act: null, build: parallelScene),
      (
        name: 'sparkline-grid',
        size: gallery,
        act: null,
        build: sparklineGridScene,
      ),
      (name: 'stream', size: gallery, act: null, build: streamScene),
      (name: 'waterfall', size: shortWide, act: null, build: waterfallScene),
      (name: 'calendar', size: gallery, act: null, build: calendarScene),
      (name: 'box-plot', size: shortWide, act: null, build: boxPlotScene),
      (name: 'histogram', size: shortWide, act: null, build: histogramScene),
      (name: 'violin', size: gallery, act: null, build: violinScene),
      (name: 'bubble', size: gallery, act: null, build: bubbleScene),
      (name: 'r-multiple', size: gallery, act: null, build: rMultipleScene),
      (
        name: 'equity-curve',
        size: gallery,
        act: null,
        build: equityCurveScene,
      ),
      (name: 'monte-carlo', size: gallery, act: null, build: monteCarloScene),
      (name: 'seasonality', size: gallery, act: null, build: seasonalityScene),
      (
        name: 'option-payoff',
        size: gallery,
        act: null,
        build: optionPayoffScene,
      ),
      (
        name: 'volatility-curve',
        size: gallery,
        act: null,
        build: volatilityScene,
      ),
      (
        name: 'market-profile',
        size: gallery,
        act: null,
        build: marketProfileScene,
      ),
      (name: 'footprint', size: gallery, act: null, build: footprintScene),
      (
        name: 'book-heatmap',
        size: gallery,
        act: null,
        build: bookHeatmapScene,
      ),
      (
        name: 'cumulative-delta',
        size: gallery,
        act: null,
        build: cumulativeDeltaScene,
      ),
      (
        name: 'trade-timeline',
        size: gallery,
        act: null,
        build: tradeTimelineScene,
      ),
      (name: 'pair-spread', size: gallery, act: null, build: pairSpreadScene),
      (
        name: 'liquidity-map',
        size: gallery,
        act: null,
        build: liquidityMapScene,
      ),
      (
        name: 'open-interest',
        size: gallery,
        act: null,
        build: openInterestScene,
      ),
    ];

/// The frame every gallery scene sits in.
Widget _gallery(List<Widget> panels) => ColoredBox(
      color: _seriesBackground,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          children: [for (final panel in panels) Expanded(child: panel)],
        ),
      ),
    );

/// A market map: sectors as groups, symbols coloured by what they did.
Widget treemapScene() {
  TreemapItem symbol(String name, double weight, double change) => TreemapItem(
        value: weight,
        label: '$name\n${change >= 0 ? '+' : ''}'
            '${change.toStringAsFixed(1)}%',
        colorValue: change,
      );

  return _gallery([
    seriesPanel(
      'Market map',
      figure: '+0.8%',
      figureColor: _seriesGreen,
      TreemapChart(
        items: [
          TreemapItem.group(
            label: 'Majors',
            children: [
              symbol('BTC', 38, 2.4),
              symbol('ETH', 22, 1.1),
              symbol('SOL', 9, -1.8),
            ],
          ),
          TreemapItem.group(
            label: 'DeFi',
            children: [
              symbol('UNI', 9, -3.2),
              symbol('AAVE', 7, 0.6),
            ],
          ),
          TreemapItem.group(
            label: 'Layer 2',
            children: [
              symbol('ARB', 9, 4.6),
              symbol('OP', 6, 3.1),
            ],
          ),
        ],
        scale: const HeatmapGradientScale(
          colors: [_seriesRed, Color(0xFF2A313B), _seriesGreen],
        ),
        minColorValue: -5,
        maxColorValue: 5,
        groupLabelStyle: _seriesAxis,
        labelStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
        spacing: 3,
        radius: 3,
      ),
    ),
    seriesPanel(
      'Portfolio weight',
      figure: seriesUsd(48200),
      TreemapChart(
        items: const [
          TreemapItem(value: 42, label: 'BTC\n42%', color: _seriesPurple),
          TreemapItem(value: 26, label: 'ETH\n26%', color: _seriesBlue),
          TreemapItem(value: 18, label: 'SOL\n18%', color: _seriesAmber),
          TreemapItem(value: 14, label: 'Cash\n14%', color: _seriesGreen),
        ],
        labelStyle: const TextStyle(
          color: Color(0xFF10151C),
          fontSize: 13,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
        spacing: 3,
        radius: 3,
      ),
    ),
  ]);
}

/// Three dials: a risk score, a margin level and a progress ring.
Widget gaugeScene() => _gallery([
      seriesPanel(
        'Account risk',
        figure: '72',
        figureColor: _seriesAmber,
        const GaugeChart(
          value: 72,
          showValueBar: false,
          label: 'Risk score',
          labelStyle: _seriesAxis,
          ranges: [
            GaugeRange(from: 0, to: 40, color: _seriesGreen),
            GaugeRange(from: 40, to: 75, color: _seriesAmber),
            GaugeRange(from: 75, to: 100, color: _seriesRed),
          ],
          needle: GaugeNeedle(),
          ticks: GaugeTicks(count: 4, labelStyle: _seriesAxis),
          valueStyle: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      seriesPanel(
        'Margin level',
        figure: '318%',
        figureColor: _seriesGreen,
        const GaugeChart(
          value: 318,
          max: 500,
          startAngle: -90,
          sweepAngle: 180,
          thickness: 18,
          valueColor: _seriesGreen,
          ticks: GaugeTicks(count: 5, labelStyle: _seriesAxis),
          label: 'Equity over margin',
          labelStyle: _seriesAxis,
          valueFormatter: _gaugePercent,
          valueStyle: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      seriesPanel(
        'Monthly target',
        figure: '64%',
        figureColor: _seriesBlue,
        const GaugeChart(
          value: 64,
          sweepAngle: 360,
          startAngle: 0,
          thickness: 16,
          valueColor: _seriesBlue,
          needle: null,
          ticks: GaugeTicks.none,
          label: 'of \$12k',
          labelStyle: _seriesAxis,
          valueFormatter: _gaugePercent,
          valueStyle: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ]);

String _gaugePercent(double value) => '${value.toStringAsFixed(0)}%';

/// Sign-up to funded: where the people go.
Widget funnelScene() => _gallery([
      seriesPanel(
        'Onboarding',
        figure: '12.4% funded',
        FunnelChart(
          stages: const [
            FunnelStage(value: 9840, label: 'Signed up'),
            FunnelStage(value: 6120, label: 'Verified email'),
            FunnelStage(value: 3410, label: 'Passed KYC'),
            FunnelStage(value: 1900, label: 'Deposited'),
            FunnelStage(value: 1220, label: 'First trade'),
          ],
          palette: _galleryPalette,
          labelStyle: const TextStyle(
            color: Color(0xFF10151C),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          sideLabelStyle: _seriesAxis,
        ),
      ),
      seriesPanel(
        'Straight-sided',
        figure: '5 stages',
        FunnelChart(
          stages: const [
            FunnelStage(value: 100, label: 'Impressions'),
            FunnelStage(value: 64, label: 'Clicks'),
            FunnelStage(value: 38, label: 'Sign-ups'),
            FunnelStage(value: 21, label: 'Trials'),
            FunnelStage(value: 9, label: 'Paid'),
          ],
          shape: FunnelShape.stepped,
          palette: _galleryPalette,
          labelStyle: const TextStyle(
            color: Color(0xFF10151C),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          sideLabelStyle: _seriesAxis,
        ),
      ),
    ]);

/// Where the money goes: income into costs and profit.
Widget sankeyScene() => _gallery([
      seriesPanel(
        'Where the money went',
        figure: seriesUsd(184000),
        SankeyChart(
          nodes: const [
            SankeyNode(id: 'spot', label: 'Spot fees', color: _seriesBlue),
            SankeyNode(id: 'perps', label: 'Perp fees', color: _seriesPurple),
            SankeyNode(id: 'funding', label: 'Funding', color: _seriesAmber),
            SankeyNode(id: 'revenue', label: 'Revenue', color: _seriesGreen),
            SankeyNode(id: 'infra', label: 'Infrastructure'),
            SankeyNode(id: 'staff', label: 'Salaries'),
            SankeyNode(id: 'market', label: 'Market making'),
            SankeyNode(id: 'profit', label: 'Profit', color: _seriesGreen),
          ],
          links: const [
            SankeyLink(source: 'spot', target: 'revenue', value: 82),
            SankeyLink(source: 'perps', target: 'revenue', value: 64),
            SankeyLink(source: 'funding', target: 'revenue', value: 38),
            SankeyLink(source: 'revenue', target: 'infra', value: 34),
            SankeyLink(source: 'revenue', target: 'staff', value: 71),
            SankeyLink(source: 'revenue', target: 'market', value: 42),
            SankeyLink(source: 'revenue', target: 'profit', value: 37),
          ],
          palette: _galleryPalette,
          labelStyle: _seriesAxis,
          valueFormatter: _galleryThousands,
        ),
      ),
    ]);

String _galleryThousands(double value) => '\$${value.toStringAsFixed(0)}k';

/// The same holdings a treemap shows, as rings.
Widget sunburstScene() => _gallery([
      seriesPanel(
        'Book by desk and symbol',
        figure: seriesUsd(48200),
        SunburstChart(
          items: [
            TreemapItem.group(
              label: 'Majors',
              color: _seriesBlue,
              children: const [
                TreemapItem(value: 38, label: 'BTC'),
                TreemapItem(value: 22, label: 'ETH'),
                TreemapItem(value: 9, label: 'SOL'),
              ],
            ),
            TreemapItem.group(
              label: 'DeFi',
              color: _seriesPurple,
              children: const [
                TreemapItem(value: 7, label: 'UNI'),
                TreemapItem(value: 5, label: 'AAVE'),
                TreemapItem(value: 4, label: 'LDO'),
              ],
            ),
            TreemapItem.group(
              label: 'Layer 2',
              color: _seriesAmber,
              children: const [
                TreemapItem(value: 6, label: 'ARB'),
                TreemapItem(value: 5, label: 'OP'),
              ],
            ),
          ],
          labelStyle: const TextStyle(
            color: Color(0xFF10151C),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          center: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Book', style: _seriesAxis),
              SizedBox(height: 2),
              Text(
                r'$48.2k',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ]);

/// A hundred squares: shares you can count.
Widget waffleScene() => _gallery([
      seriesPanel(
        'Portfolio',
        figure: '100 cells',
        const WaffleChart(
          slices: [
            WaffleSlice(label: 'Crypto', value: 45, color: _seriesPurple),
            WaffleSlice(label: 'Equities', value: 35, color: _seriesBlue),
            WaffleSlice(label: 'Cash', value: 20, color: _seriesGreen),
          ],
          cellGap: 4,
          cellRadius: 3,
        ),
      ),
      seriesPanel(
        'Winning trades',
        figure: '38 of 100',
        const WaffleChart(
          slices: [
            WaffleSlice(label: 'Winners', value: 38, color: _seriesGreen),
          ],
          total: 100,
          cellGap: 4,
          cellRadius: 3,
          emptyColor: Color(0x22FA5252),
        ),
      ),
    ]);

/// KPIs against their targets, a row each.
Widget bulletScene() => _gallery([
      seriesPanel(
        'This quarter against target',
        figure: '4 of 5 met',
        figureColor: _seriesGreen,
        const Center(
          child: BulletChart(
            rows: [
              BulletRow(
                label: 'Win rate',
                value: 58,
                target: 55,
                max: 100,
                bands: [
                  BulletBand(to: 40, color: Color(0x33FA5252)),
                  BulletBand(to: 55, color: Color(0x33FAB005)),
                  BulletBand(to: 100, color: Color(0x3312B886)),
                ],
              ),
              BulletRow(
                label: 'Profit factor',
                value: 1.62,
                target: 2,
                max: 3,
                bands: [
                  BulletBand(to: 1, color: Color(0x33FA5252)),
                  BulletBand(to: 2, color: Color(0x33FAB005)),
                  BulletBand(to: 3, color: Color(0x3312B886)),
                ],
              ),
              BulletRow(
                label: 'Sharpe',
                value: 1.9,
                target: 1.5,
                max: 3,
                bands: [
                  BulletBand(to: 1, color: Color(0x33FA5252)),
                  BulletBand(to: 1.5, color: Color(0x33FAB005)),
                  BulletBand(to: 3, color: Color(0x3312B886)),
                ],
              ),
              BulletRow(
                label: 'Max DD',
                value: 11.4,
                target: 15,
                max: 30,
                bands: [
                  BulletBand(to: 15, color: Color(0x3312B886)),
                  BulletBand(to: 22, color: Color(0x33FAB005)),
                  BulletBand(to: 30, color: Color(0x33FA5252)),
                ],
              ),
              BulletRow(
                label: 'Trades',
                value: 184,
                target: 150,
                max: 250,
                bands: [
                  BulletBand(to: 80, color: Color(0x33FA5252)),
                  BulletBand(to: 150, color: Color(0x33FAB005)),
                  BulletBand(to: 250, color: Color(0x3312B886)),
                ],
              ),
            ],
            rowHeight: 34,
            rowGap: 20,
            labelWidth: 96,
            labelStyle: _seriesAxis,
            barColor: _seriesBlue,
          ),
        ),
      ),
    ]);

/// Before and after, joined by a bar.
Widget dumbbellScene() => _gallery([
      seriesPanel(
        'Quarter on quarter',
        figure: 'Q3 → Q4',
        const DumbbellChart(
          rows: [
            DumbbellRow(label: 'BTC', from: 61200, to: 68400),
            DumbbellRow(label: 'ETH', from: 3400, to: 3120),
            DumbbellRow(label: 'SOL', from: 142, to: 198),
            DumbbellRow(label: 'ARB', from: 1.8, to: 1.2),
          ],
          min: 0,
          max: 70000,
          showValues: true,
          labelStyle: _seriesAxis,
          axisStyle: _seriesAxis,
          riseColor: _seriesGreen,
          fallColor: _seriesRed,
          fromColor: _seriesMuted,
        ),
      ),
      seriesPanel(
        'Day range',
        figure: 'low → high',
        const DumbbellChart(
          rows: [
            DumbbellRow(label: 'Mon', from: 66100, to: 68900),
            DumbbellRow(label: 'Tue', from: 67200, to: 69400),
            DumbbellRow(label: 'Wed', from: 65800, to: 68100),
            DumbbellRow(label: 'Thu', from: 66400, to: 70200),
            DumbbellRow(label: 'Fri', from: 68300, to: 71500),
          ],
          labelStyle: _seriesAxis,
          axisStyle: _seriesAxis,
          toColor: _seriesBlue,
          fromColor: _seriesMuted,
          barColor: Color(0x554DABF7),
        ),
      ),
    ]);

/// Places changing hands, quarter by quarter.
Widget slopeScene() => _gallery([
      seriesPanel(
        'Return by quarter',
        figure: 'value scale',
        const SlopeChart(
          periodLabels: ['Q1', 'Q2', 'Q3', 'Q4'],
          series: [
            SlopeSeries(label: 'BTC', values: [4.2, 19.0, 11.5, 22.4]),
            SlopeSeries(label: 'ETH', values: [12.1, 8.4, 2.0, 9.6]),
            SlopeSeries(label: 'SOL', values: [9.7, 1.2, 18.3, 14.1]),
          ],
          palette: _galleryPalette,
          labelStyle: _seriesAxis,
          headerStyle: _seriesAxis,
        ),
      ),
      seriesPanel(
        'The same, by rank',
        figure: 'bump scale',
        const SlopeChart(
          periodLabels: ['Q1', 'Q2', 'Q3', 'Q4'],
          scale: SlopeScale.rank,
          series: [
            SlopeSeries(label: 'BTC', values: [4.2, 19.0, 11.5, 22.4]),
            SlopeSeries(label: 'ETH', values: [12.1, 8.4, 2.0, 9.6]),
            SlopeSeries(label: 'SOL', values: [9.7, 1.2, 18.3, 14.1]),
          ],
          palette: _galleryPalette,
          showValues: false,
          labelStyle: _seriesAxis,
          headerStyle: _seriesAxis,
        ),
      ),
    ]);

/// Two dimensions: how big each venue is, and what it trades.
Widget marimekkoScene() => _gallery([
      seriesPanel(
        'Volume by venue and instrument',
        figure: seriesUsd(920000),
        const MarimekkoChart(
          columns: [
            MarimekkoColumn(
              label: 'Binance',
              cells: [
                MarimekkoCell(label: 'Perps', value: 210),
                MarimekkoCell(label: 'Spot', value: 120),
                MarimekkoCell(label: 'Options', value: 40),
              ],
            ),
            MarimekkoColumn(
              label: 'OKX',
              cells: [
                MarimekkoCell(label: 'Perps', value: 130),
                MarimekkoCell(label: 'Spot', value: 60),
                MarimekkoCell(label: 'Options', value: 30),
              ],
            ),
            MarimekkoColumn(
              label: 'Bybit',
              cells: [
                MarimekkoCell(label: 'Perps', value: 96),
                MarimekkoCell(label: 'Spot', value: 34),
              ],
            ),
            MarimekkoColumn(
              label: 'Deribit',
              cells: [
                MarimekkoCell(label: 'Options', value: 88),
                MarimekkoCell(label: 'Perps', value: 22),
              ],
            ),
          ],
          palette: _galleryPalette,
          headerStyle: _seriesAxis,
          cellStyle: TextStyle(
            color: Color(0xFF10151C),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ]);

/// Flow that goes both ways round a ring.
Widget chordScene() => _gallery([
      seriesPanel(
        'Flow between venues',
        figure: '24h',
        const ChordChart(
          nodes: [
            ChordNode(label: 'Binance', color: _seriesAmber),
            ChordNode(label: 'OKX', color: _seriesBlue),
            ChordNode(label: 'Bybit', color: _seriesGreen),
            ChordNode(label: 'Deribit', color: _seriesPurple),
          ],
          flows: [
            ChordFlow(from: 'Binance', to: 'OKX', value: 40),
            ChordFlow(from: 'OKX', to: 'Binance', value: 31),
            ChordFlow(from: 'OKX', to: 'Bybit', value: 25),
            ChordFlow(from: 'Bybit', to: 'Binance', value: 30),
            ChordFlow(from: 'Binance', to: 'Deribit', value: 22),
            ChordFlow(from: 'Deribit', to: 'Bybit', value: 18),
            ChordFlow(from: 'Bybit', to: 'OKX', value: 14),
            ChordFlow(from: 'Deribit', to: 'Binance', value: 11),
          ],
          ringThickness: 14,
          ribbonOpacity: 0.3,
          labelStyle: _seriesAxis,
        ),
      ),
    ]);

/// Five strategies on five measures at once.
Widget parallelScene() => _gallery([
      seriesPanel(
        'Strategies on five measures',
        figure: 'best is highest',
        const ParallelChart(
          axes: [
            ParallelAxis(label: 'Return'),
            ParallelAxis(label: 'Drawdown', inverted: true),
            ParallelAxis(label: 'Win rate'),
            ParallelAxis(label: 'Profit factor'),
            ParallelAxis(label: 'Trades'),
          ],
          lines: [
            ParallelLine(label: 'Trend', values: [34, 18, 41, 1.9, 184]),
            ParallelLine(label: 'Revert', values: [21, 9, 63, 1.4, 420]),
            ParallelLine(label: 'Breakout', values: [48, 27, 38, 2.2, 96]),
            ParallelLine(label: 'Carry', values: [12, 5, 71, 1.7, 61]),
            ParallelLine(label: 'Scalp', values: [26, 14, 55, 1.2, 980]),
          ],
          palette: _galleryPalette,
          showLegend: true,
          headerStyle: _seriesAxis,
          endStyle: _seriesAxis,
          dotRadius: 4,
        ),
      ),
    ]);

/// A watchlist: a name, a shape and a number each.
Widget sparklineGridScene() {
  SparklineTile tile(String name, String venue, double phase, double drift) {
    final values = _galleryWave(
      40,
      base: 100,
      swing: 5,
      drift: drift,
      phase: phase,
    );
    final change = (values.last - values.first) / values.first * 100;
    return SparklineTile(
      label: name,
      subtitle: venue,
      values: values,
      valueLabel: '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%',
    );
  }

  return _gallery([
    seriesPanel(
      'Watchlist',
      figure: '8 symbols',
      SparklineGrid(
        columns: 2,
        tileHeight: 58,
        tileGap: 6,
        tiles: [
          tile('BTC', 'Binance', 0.2, 0.28),
          tile('ETH', 'Binance', 1.4, -0.16),
          tile('SOL', 'OKX', 2.6, 0.34),
          tile('ARB', 'OKX', 0.9, -0.22),
          tile('OP', 'Bybit', 3.1, 0.12),
          tile('LDO', 'Bybit', 1.9, -0.3),
          tile('UNI', 'Binance', 2.2, 0.06),
          tile('AAVE', 'Deribit', 0.5, 0.19),
          tile('DOGE', 'Binance', 1.1, 0.41),
          tile('AVAX', 'OKX', 2.8, -0.11),
          tile('LINK', 'Bybit', 0.7, 0.24),
          tile('DOT', 'Binance', 3.4, -0.27),
        ],
        riseColor: _seriesGreen,
        fallColor: _seriesRed,
        labelStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        subtitleStyle: const TextStyle(color: _seriesMuted, fontSize: 9),
        valueStyle: _seriesAxis,
        tileColor: const Color(0xFF11161D),
      ),
    ),
  ]);
}

/// A stack that flows: what the book was made of, month by month.
Widget streamScene() {
  List<double> band(double base, double phase, double drift) => [
        for (var i = 0; i < 24; i++)
          (base + sin(i / 3.4 + phase) * base * 0.45 + i * drift)
              .clamp(2.0, 200.0),
      ];

  return _gallery([
    seriesPanel(
      'Book by symbol, two years',
      figure: 'wiggle baseline',
      StreamChart(
        periodLabels: [
          for (var i = 0; i < 24; i++)
            i % 3 == 0 ? _seriesMonths[i % 12] : '',
        ],
        series: [
          StreamSeries(label: 'BTC', values: band(60, 0.2, 0.9)),
          StreamSeries(label: 'ETH', values: band(38, 1.6, -0.4)),
          StreamSeries(label: 'SOL', values: band(22, 2.9, 1.1)),
          StreamSeries(label: 'ARB', values: band(14, 0.8, 0.3)),
          StreamSeries(label: 'Cash', values: band(30, 2.1, -0.2)),
        ],
        palette: _galleryPalette,
        axisStyle: _seriesAxis,
      ),
    ),
  ]);
}

/// A total built up step by step.
Widget waterfallScene() => _gallery([
      seriesPanel(
        'From opening to closing balance',
        figure: seriesUsd(52400),
        figureColor: _seriesGreen,
        WaterfallChart(
          steps: const [
            WaterfallStep(
              value: 42000,
              label: 'Opening',
              kind: WaterfallKind.total,
            ),
            WaterfallStep(value: 18400, label: 'Wins'),
            WaterfallStep(value: -9100, label: 'Losses'),
            WaterfallStep(value: 3200, label: 'Funding'),
            WaterfallStep(value: -2100, label: 'Fees'),
            WaterfallStep(value: 0, label: 'Closing', kind: WaterfallKind.total),
          ],
          riseColor: _seriesGreen,
          fallColor: _seriesRed,
          totalColor: _seriesBlue,
          labelStyle: _seriesAxis,
          valueStyle: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          valueFormatter: seriesUsd,
        ),
      ),
    ]);

/// Daily profit and loss, on a real calendar.
Widget calendarScene() {
  final days = [
    for (var i = 0; i < 92; i++)
      CalendarDay(
        date: DateTime(2026, 4, 1).add(Duration(days: i)),
        value: (i % 7 == 5 || i % 7 == 6)
            ? 0
            : sin(i / 4.1) * 900 + cos(i / 1.7) * 420 + (i % 5 - 2) * 130,
      ),
  ];

  return _gallery([
    seriesPanel(
      'Daily profit and loss',
      figure: seriesUsd(14800),
      figureColor: _seriesGreen,
      CalendarChart(
        days: days,
        monthsPerRow: 2,
        scale: const HeatmapGradientScale(
          colors: [_seriesRed, Color(0xFF1B222B), _seriesGreen],
        ),
        cellSpacing: 3,
        cellRadius: 3,
        showDayNumbers: true,
        showWeekdayHeader: true,
        headerStyle: _seriesAxis,
        dayNumberStyle: const TextStyle(color: Colors.white, fontSize: 9),
        valueFormatter: seriesUsd,
      ),
    ),
  ]);
}

/// Samples for the distribution scenes: a fat-tailed return series.
List<double> _galleryReturns({
  double mean = 0.4,
  double spread = 2.2,
  int count = 400,
  double skew = 0,
}) =>
    [
      for (var i = 0; i < count; i++)
        mean +
            sin(i * 2.399) * spread +
            cos(i * 0.733) * spread * 0.6 +
            sin(i * 0.211) * spread * skew,
    ];

/// Four strategies' returns, as quartiles and whiskers.
Widget boxPlotScene() => _gallery([
      seriesPanel(
        'Daily returns by strategy',
        figure: '400 days each',
        BoxPlotChart(
          entries: [
            BoxPlotEntry(
              label: 'Trend',
              stats: BoxPlotStats.fromSamples(_galleryReturns()),
              color: _seriesBlue,
            ),
            BoxPlotEntry(
              label: 'Revert',
              stats: BoxPlotStats.fromSamples(
                _galleryReturns(mean: 0.2, spread: 1.1),
              ),
              color: _seriesGreen,
            ),
            BoxPlotEntry(
              label: 'Breakout',
              stats: BoxPlotStats.fromSamples(
                _galleryReturns(mean: 0.6, spread: 3.4, skew: 0.5),
              ),
              color: _seriesAmber,
            ),
            BoxPlotEntry(
              label: 'Carry',
              stats: BoxPlotStats.fromSamples(
                _galleryReturns(mean: 0.15, spread: 0.7),
              ),
              color: _seriesPurple,
            ),
          ],
          axisLabelStyle: _seriesAxis,
          entryLabelStyle: _seriesAxis,
          valueFormatter: _galleryPercent,
        ),
      ),
    ]);

String _galleryPercent(double value) => '${value.toStringAsFixed(1)}%';

/// The shape of a return distribution, in counted bins.
Widget histogramScene() => _gallery([
      seriesPanel(
        'Daily returns',
        figure: '400 days',
        HistogramChart(
          bins: histogramBins(_galleryReturns(), binCount: 26),
          barColor: _seriesBlue,
          negativeColor: _seriesRed,
          axisLabelStyle: _seriesAxis,
          valueFormatter: _galleryPercent,
          referenceLines: const [0],
          gridColor: const Color(0x14FFFFFF),
        ),
      ),
      seriesPanel(
        'Trade size',
        figure: '1,284 trades',
        HistogramChart(
          bins: histogramBins(
            [
              for (var i = 0; i < 600; i++)
                (2 + sin(i * 1.77).abs() * 6 + cos(i * 0.41).abs() * 3) * 1000,
            ],
            binCount: 20,
          ),
          barColor: _seriesPurple,
          axisLabelStyle: _seriesAxis,
          valueFormatter: seriesUsd,
          gridColor: const Color(0x14FFFFFF),
        ),
      ),
    ]);

/// The shape of a distribution, not just its quartiles.
Widget violinScene() => _gallery([
      seriesPanel(
        'Violins',
        figure: 'four strategies',
        ViolinChart(
          series: [
            ViolinSeries(label: 'Trend', samples: _galleryReturns()),
            ViolinSeries(
              label: 'Revert',
              samples: _galleryReturns(mean: 0.2, spread: 1.1),
            ),
            ViolinSeries(
              label: 'Breakout',
              samples: _galleryReturns(mean: 0.6, spread: 2.9, skew: 0.3),
            ),
            ViolinSeries(
              label: 'Carry',
              samples: _galleryReturns(mean: 0.15, spread: 0.7),
            ),
          ],
          palette: _galleryPalette,
          labelStyle: _seriesAxis,
          axisStyle: _seriesAxis,
          axisFormatter: _galleryPercent,
        ),
      ),
      seriesPanel(
        'Ridgeline',
        figure: 'by month',
        ViolinChart(
          shape: ViolinShape.ridgeline,
          series: [
            for (var i = 0; i < 5; i++)
              ViolinSeries(
                label: _seriesMonths[i],
                samples: _galleryReturns(
                  mean: 0.1 + i * 0.25,
                  spread: 1.2 + i * 0.5,
                ),
              ),
          ],
          palette: _galleryPalette,
          labelWidth: 44,
          labelStyle: _seriesAxis,
          axisStyle: _seriesAxis,
          axisFormatter: _galleryPercent,
        ),
      ),
    ]);

/// Risk against return, with size as the third number.
Widget bubbleScene() => _gallery([
      seriesPanel(
        'Risk against return',
        figure: 'size is capital',
        const BubbleChart(
          points: [
            BubblePoint(x: 18, y: 34, size: 120, label: 'Trend'),
            BubblePoint(x: 9, y: 21, size: 90, label: 'Revert'),
            BubblePoint(x: 27, y: 48, size: 76, label: 'Break'),
            BubblePoint(x: 5, y: 12, size: 180, label: 'Carry'),
            BubblePoint(x: 14, y: 26, size: 64, label: 'Scalp'),
            BubblePoint(x: 31, y: 19, size: 52, label: 'News'),
          ],
          minRadius: 16,
          maxRadius: 34,
          palette: _galleryPalette,
          xAxisTitle: 'Max drawdown %',
          yAxisTitle: 'Return %',
          axisLabelStyle: _seriesAxis,
          axisTitleStyle: _seriesAxis,
          labelStyle: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          gridColor: Color(0x14FFFFFF),
        ),
      ),
    ]);

/// Trade results in R, with the expectancy over them.
Widget rMultipleScene() {
  final rs = [
    for (var i = 0; i < 180; i++)
      // Most losers stop out at about -1R; the winners spread out into a tail.
      i % 5 < 3
          ? -1.05 + sin(i * 2.7) * 0.22
          : (0.3 + sin(i * 1.13).abs() * 2.9 + cos(i * 0.47).abs() * 1.4),
  ];
  return _gallery([
    seriesPanel(
      'Trade results in R',
      figure: '180 trades',
      RMultipleChart(
        results: rs,
        binWidth: 0.5,
        profitColor: _seriesGreen,
        lossColor: _seriesRed,
        axisLabelStyle: _seriesAxis,
        statLabelStyle: _seriesAxis,
        statValueStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  ]);
}

/// The curve, and how far under water it went.
Widget equityCurveScene() {
  final points = [
    for (var i = 0; i < 260; i++)
      EquityPoint(
        time: DateTime(2026).add(Duration(days: i)),
        equity: 40000 +
            i * 62 +
            sin(i / 17.0) * 3400 +
            cos(i / 5.3) * 900 -
            (i > 150 && i < 200 ? (i - 150) * 74 : 0),
      ),
  ];
  return _gallery([
    seriesPanel(
      'Equity and drawdown',
      figure: seriesUsd(56400),
      figureColor: _seriesGreen,
      EquityCurveChart(
        points: points,
        lineColor: _seriesGreen,
        fillOpacity: 0.18,
        drawdownColor: _seriesRed,
        axisLabelStyle: _seriesAxis,
        valueFormatter: seriesUsd,
        gridColor: const Color(0x14FFFFFF),
      ),
    ),
  ]);
}

/// A thousand futures, as percentile bands.
Widget monteCarloScene() {
  final trades = [
    for (var i = 0; i < 180; i++)
      // A real edge, but a thin one: three losers to two winners.
      i % 5 < 3 ? -640.0 - (i % 7) * 30 : 1180.0 + sin(i * 1.31).abs() * 520,
  ];
  final result = runMonteCarlo(
    trades,
    pathCount: 800,
    startingEquity: 40000,
    sizing: MonteCarloSizing.fixed,
    seed: 7,
    ruinLevel: 20000,
  );
  return _gallery([
    seriesPanel(
      'A thousand futures',
      figure: 'p5 – p95',
      MonteCarloChart(
        result: result,
        bandColor: _seriesGreen,
        medianColor: _seriesGreen,
        actualColor: Colors.white,
        ruinColor: _seriesRed,
        axisLabelStyle: _seriesAxis,
        valueFormatter: seriesUsd,
        summaryStyle: _seriesAxis,
        gridColor: const Color(0x14FFFFFF),
      ),
    ),
  ]);
}

/// Results across the calendar.
Widget seasonalityScene() {
  final samples = [
    for (var year = 2022; year <= 2026; year++)
      for (var month = 1; month <= 12; month++)
        SeasonalSample(
          time: DateTime(year, month, 15),
          value: (sin(month / 1.9 + year * 0.7) * 0.05 +
                  cos(month / 3.3) * 0.03 +
                  (month == 9 ? -0.04 : 0.01))
              .toDouble(),
        ),
  ];
  return _gallery([
    seriesPanel(
      'Month by year',
      figure: 'compounded',
      SeasonalityChart(
        samples: samples,
        grid: SeasonalityGrid.monthByYear,
        aggregate: SeasonalityAggregate.compound,
        profitColor: _seriesGreen,
        lossColor: _seriesRed,
        axisLabelStyle: _seriesAxis,
        labelStyle: const TextStyle(color: Colors.white, fontSize: 10),
      ),
    ),
  ]);
}

/// What a strategy makes at expiry, across the price.
Widget optionPayoffScene() => _gallery([
      seriesPanel(
        'Bull call spread',
        figure: 'max \$3.1k',
        figureColor: _seriesGreen,
        OptionPayoffChart(
          legs: const [
            OptionLeg(
              kind: OptionKind.call,
              strike: 65000,
              premium: 2400,
              label: 'Long 65k call',
            ),
            OptionLeg(
              kind: OptionKind.call,
              strike: 72000,
              premium: 900,
              quantity: -1,
              label: 'Short 72k call',
            ),
          ],
          profitColor: _seriesGreen,
          lossColor: _seriesRed,
          axisLabelStyle: _seriesAxis,
          priceFormatter: _galleryPrice,
          payoffFormatter: seriesUsd,
          gridColor: const Color(0x14FFFFFF),
        ),
      ),
      seriesPanel(
        'Long straddle',
        figure: 'both ways',
        OptionPayoffChart(
          legs: const [
            OptionLeg(
              kind: OptionKind.call,
              strike: 68000,
              premium: 2100,
              label: 'Long call',
            ),
            OptionLeg(
              kind: OptionKind.put,
              strike: 68000,
              premium: 1900,
              label: 'Long put',
            ),
          ],
          profitColor: _seriesGreen,
          lossColor: _seriesRed,
          axisLabelStyle: _seriesAxis,
          priceFormatter: _galleryPrice,
          payoffFormatter: seriesUsd,
          gridColor: const Color(0x14FFFFFF),
        ),
      ),
    ]);

String _galleryPrice(double value) =>
    '\$${(value / 1000).toStringAsFixed(0)}k';

/// The smile, and the term structure beside it.
Widget volatilityScene() => _gallery([
      seriesPanel(
        'Volatility smile',
        figure: 'three expiries',
        VolatilityCurveChart(
          slices: [
            for (var e = 0; e < 3; e++)
              VolatilitySlice(
                label: ['7d', '30d', '90d'][e],
                color: _galleryPalette[e],
                points: [
                  for (var i = 0; i < 11; i++)
                    VolatilityPoint(
                      x: 56000 + i * 2400,
                      volatility: 0.42 +
                          e * 0.04 +
                          pow((i - 5) / 5, 2) * (0.22 - e * 0.05) -
                          (i - 5) * 0.006,
                    ),
                ],
              ),
          ],
          axisLabelStyle: _seriesAxis,
          xFormatter: _galleryPrice,
          gridColor: const Color(0x14FFFFFF),
          legendStyle: _seriesAxis,
        ),
      ),
      seriesPanel(
        'Term structure',
        figure: 'at the money',
        VolatilityCurveChart(
          slices: [
            VolatilitySlice(
              label: 'ATM',
              color: _seriesGreen,
              points: [
                for (var i = 0; i < 8; i++)
                  VolatilityPoint(
                    x: [1, 7, 14, 30, 60, 90, 180, 365][i].toDouble(),
                    volatility: 0.62 - i * 0.03 + sin(i / 2.2) * 0.02,
                  ),
              ],
            ),
          ],
          axisLabelStyle: _seriesAxis,
          xFormatter: _galleryDays,
          gridColor: const Color(0x14FFFFFF),
          legendStyle: _seriesAxis,
        ),
      ),
    ]);

String _galleryDays(double value) => '${value.toStringAsFixed(0)}d';

/// Synthetic order flow: the bars every market-microstructure scene is built
/// from, so the profile, footprint and delta scenes all show the same market.
List<FootprintBar> _galleryFootprint({int bars = 22, double tick = 20}) {
  final out = <FootprintBar>[];
  double pathAt(int i) =>
      68000 + sin(i / 3.1) * 240 + cos(i / 1.3) * 90 - sin(i / 7.7) * 120;
  for (var b = 0; b < bars; b++) {
    final open = pathAt(b);
    final close = pathAt(b + 1);
    final drift = close - open;
    final high = max(open, close) + 40 + (b % 3) * 20;
    final low = min(open, close) - 40 - (b % 4) * 15;
    final levels = <FootprintLevel>[];
    for (var p = low; p <= high; p += tick) {
      final fromMid = (p - (open + close) / 2).abs() / 120;
      final weight = (2.4 - fromMid).clamp(0.2, 2.4);
      final lean = drift >= 0 ? 1.35 : 0.72;
      levels.add(
        FootprintLevel(
          price: p,
          bidVolume: (weight * 34 * (2 - lean) + (p ~/ tick) % 7).toDouble(),
          askVolume: (weight * 34 * lean + (p ~/ tick) % 5).toDouble(),
        ),
      );
    }
    out.add(
      FootprintBar(
        time: DateTime(2026, 4, 2, 9, 30).add(Duration(minutes: b * 5)),
        levels: levels,
        open: open,
        high: high,
        low: low,
        close: close,
      ),
    );
  }
  return out;
}

/// Time at price, with the point of control and the value area.
Widget marketProfileScene() {
  final bars = _galleryFootprint();
  final profile = buildMarketProfile(
    [
      for (final bar in bars)
        KLineEntity.fromCustom(
          dateTime: bar.time,
          vol: 0,
          open: bar.open ?? 0,
          high: bar.high ?? 0,
          low: bar.low ?? 0,
          close: bar.close ?? 0,
        ),
    ],
    tickSize: 40,
  );
  return _gallery([
    seriesPanel(
      'Time at price',
      figure: 'POC and 70% value area',
      MarketProfileChart(
        profile: profile,
        blockColor: const Color(0xFF2A3644),
        letterStyle: const TextStyle(
          color: Color(0xFF9BB5D6),
          fontSize: 10,
          height: 1,
        ),
        valueAreaColor: const Color(0x224DABF7),
        pointOfControlColor: _seriesAmber,
        axisLabelStyle: _seriesAxis,
        priceFormatter: _galleryFullPrice,
      ),
    ),
  ]);
}

String _galleryFullPrice(double value) => value.toStringAsFixed(0);

/// Bid against ask at every price, inside every candle.
Widget footprintScene() => _gallery([
      seriesPanel(
        'Order flow',
        figure: 'bid × ask per level',
        FootprintChart(
          bars: _galleryFootprint(bars: 10, tick: 40),
          tickSize: 40,
          buyColor: _seriesGreen,
          sellColor: _seriesRed,
          numberStyle: const TextStyle(
            color: Color(0xFFD6DEE8),
            fontSize: 9,
            height: 1,
          ),
          axisLabelStyle: _seriesAxis,
          priceFormatter: _galleryFullPrice,
        ),
      ),
    ]);

/// Resting liquidity, over time.
Widget bookHeatmapScene() {
  final snapshots = [
    for (var t = 0; t < 80; t++)
      () {
        final mid = 68000 + sin(t / 9.1) * 180;
        return BookSnapshot(
          time: DateTime(2026, 4, 2, 9, 30).add(Duration(seconds: t * 15)),
          mid: mid,
          levels: [
            for (var i = 1; i <= 24; i++) ...[
              () {
                final price = mid - i * 20;
                return BookLevel(
                  price: price,
                  // A wall resting at a price of its own, which the mid
                  // wanders past rather than dragging along with it.
                  size: (price >= 67740 && price < 67760 ? 900.0 : 0) +
                      120 +
                      sin(i / 2.3 + t / 7) * 70 +
                      (i % 5) * 12,
                  side: BookSide.bid,
                );
              }(),
              () {
                final price = mid + i * 20;
                return BookLevel(
                  price: price,
                  size: (price >= 68300 && price < 68320 && t > 24
                          ? 820.0
                          : 0) +
                      120 +
                      cos(i / 2.1 + t / 6) * 70 +
                      (i % 4) * 15,
                  side: BookSide.ask,
                );
              }(),
            ],
          ],
        );
      }(),
  ];
  return _gallery([
    seriesPanel(
      'Resting liquidity',
      figure: '20 minutes',
      BookHeatmapChart(
        snapshots: snapshots,
        tickSize: 20,
        bidColor: _seriesGreen,
        askColor: _seriesRed,
        midColor: Colors.white,
        axisLabelStyle: _seriesAxis,
        priceFormatter: _galleryFullPrice,
      ),
    ),
  ]);
}

/// Running delta, with the divergences against price marked.
Widget cumulativeDeltaScene() {
  final bars = _galleryFootprint(bars: 60);
  return _gallery([
    seriesPanel(
      'Cumulative delta',
      figure: 'buying less selling',
      CumulativeDeltaChart(
        bars: deltaBarsFromFootprint(bars),
        lineColor: _seriesBlue,
        buyColor: _seriesGreen,
        sellColor: _seriesRed,
        axisLabelStyle: _seriesAxis,
        gridColor: const Color(0x14FFFFFF),
      ),
    ),
  ]);
}

/// Every trade, from entry to exit.
Widget tradeTimelineScene() {
  final start = DateTime(2026, 4, 6, 9);
  TimelineTrade trade(
    String symbol,
    int startHour,
    int hours,
    double pnl, {
    bool long = true,
  }) =>
      TimelineTrade(
        entryTime: start.add(Duration(hours: startHour)),
        exitTime: start.add(Duration(hours: startHour + hours)),
        lane: symbol,
        side: long ? TradeSide.buy : TradeSide.sell,
        pnl: pnl,
      );

  return _gallery([
    seriesPanel(
      'When each trade was open',
      figure: '19 trades',
      TradeTimelineChart(
        trades: [
          trade('BTC', 0, 9, 1840),
          trade('BTC', 14, 6, -620, long: false),
          trade('BTC', 26, 12, 2400),
          trade('ETH', 2, 18, -940),
          trade('ETH', 24, 8, 1120),
          trade('ETH', 40, 5, 310),
          trade('SOL', 6, 22, 3200),
          trade('SOL', 34, 7, -480, long: false),
          trade('ARB', 10, 14, 760),
          trade('ARB', 30, 9, -210),
          trade('OP', 4, 26, 1580),
          trade('OP', 38, 10, 640),
          trade('LINK', 8, 16, 890),
          trade('LINK', 32, 11, -340, long: false),
          trade('AVAX', 12, 20, 1460),
          trade('DOGE', 0, 13, -780, long: false),
          trade('DOGE', 28, 15, 2100),
        ],
        now: start.add(const Duration(hours: 50)),
        profitColor: _seriesGreen,
        lossColor: _seriesRed,
        exposureColor: _seriesBlue,
        pnlFormatter: seriesUsd,
        laneLabelStyle: _seriesAxis,
        axisLabelStyle: _seriesAxis,
        gridColor: const Color(0x14FFFFFF),
      ),
    ),
  ]);
}

/// Two symbols as one spread, with the z-score beneath.
Widget pairSpreadScene() {
  final points = [
    for (var i = 0; i < 160; i++)
      PairPoint(
        time: DateTime(2026).add(Duration(days: i)),
        a: 100 + i * 0.22 + sin(i / 11.0) * 4 + cos(i / 3.1) * 1.2,
        b: 40 + i * 0.08 + sin(i / 13.0) * 1.1,
      ),
  ];
  return _gallery([
    seriesPanel(
      'BTC against ETH',
      figure: 'log ratio, 30d',
      PairSpreadChart(
        points: points,
        mode: PairSpreadMode.logRatio,
        lookback: 30,
        spreadColor: _seriesBlue,
        bandColor: const Color(0x334DABF7),
        meanColor: _seriesMuted,
        zColor: _seriesPurple,
        longColor: _seriesGreen,
        shortColor: _seriesRed,
        axisLabelStyle: _seriesAxis,
        gridColor: const Color(0x14FFFFFF),
      ),
    ),
  ]);
}

/// Where the leveraged stops sit.
Widget liquidityMapScene() {
  final levels = [
    for (var i = 0; i < 260; i++)
      LiquidityLevel(
        price: 62000 + i * 46,
        size: (i % 17 == 0 ? 900.0 : 120) +
            sin(i / 6.1).abs() * 260 +
            cos(i / 2.3).abs() * 90,
        side: 62000 + i * 46 < 68000
            ? LiquiditySide.long
            : LiquiditySide.short,
        leverage: [5.0, 10.0, 25.0, 50.0][i % 4],
      ),
  ];
  return _gallery([
    seriesPanel(
      'Liquidation map',
      figure: 'price 68,000',
      LiquidityMapChart(
        bins: liquidityBins(levels, binCount: 42),
        currentPrice: 68000,
        longColor: _seriesGreen,
        shortColor: _seriesRed,
        axisStyle: _seriesAxis,
        priceFormatter: _galleryFullPrice,
        gridColor: const Color(0x10909196),
      ),
    ),
  ]);
}

/// Open interest over price, funding beneath.
Widget openInterestScene() {
  final points = [
    for (var i = 0; i < 120; i++)
      OpenInterestPoint(
        time: DateTime(2026, 4)
            .add(Duration(hours: i * 8))
            .millisecondsSinceEpoch,
        openInterest: 820e6 +
            sin(i / 14.0) * 90e6 +
            cos(i / 4.1) * 24e6 +
            i * 1.1e6,
        funding: (sin(i / 9.0) * 0.00045 + cos(i / 3.3) * 0.00012),
        price: 66000 + sin(i / 11.0) * 2600 + cos(i / 3.7) * 600 + i * 12,
      ),
  ];
  return _gallery([
    seriesPanel(
      'Open interest and funding',
      figure: '40 days',
      OpenInterestChart(
        points: points,
        interestColor: _seriesBlue,
        priceColor: const Color(0x99FFFFFF),
        positiveFundingColor: _seriesGreen,
        negativeFundingColor: _seriesRed,
        axisStyle: _seriesAxis,
        interestFormatter: _galleryMillions,
        gridColor: const Color(0x14FFFFFF),
      ),
    ),
  ]);
}

String _galleryMillions(double value) =>
    '\$${(value / 1e6).toStringAsFixed(0)}M';
