// Every chart in the gallery: what it is called, what it is for, and the
// widget itself.
//
// The gallery page in the app and the screenshot tool both build from this
// list, so a chart is described and drawn in one place. A chart with more than
// one thing worth showing has a variant each; the app stacks them down the
// page, and the tool sets them side by side in panels.
import 'package:material_ui/material_ui.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

import 'gallery_data.dart';

/// Which part of the package a chart belongs to.
enum GalleryGroup {
  /// The order book, the tape and the derivatives around them.
  orderFlow('Order flow and derivatives'),

  /// What a strategy did, after the fact.
  results('Backtests and results'),

  /// The charts a dashboard or a report is built from.
  dashboard('Dashboards and reports'),

  /// How far things have got towards a goal.
  progress('Progress and goals'),

  /// Training runs, evaluations and what models cost to serve.
  models('Models and training');

  const GalleryGroup(this.title);

  /// What the group is called on screen.
  final String title;
}

/// One thing a chart can show — a chart, and what to call it.
@immutable
class GalleryVariant {
  /// Creates a variant called [title].
  const GalleryVariant({
    required this.title,
    required this.build,
    this.figure,
    this.figureColor,
    this.height = 300,
  });

  /// What this particular chart shows, written over it.
  final String title;

  /// The chart itself.
  final Widget Function() build;

  /// A number worth putting beside the title.
  final String? figure;

  /// What that number is painted in.
  final Color? figureColor;

  /// How tall the chart wants to be on the page.
  final double height;
}

/// One chart in the gallery.
@immutable
class GalleryEntry {
  /// Creates an entry for the chart called [title].
  const GalleryEntry({
    required this.id,
    required this.title,
    required this.blurb,
    required this.group,
    required this.doc,
    required this.variants,
  });

  /// What the entry is called in code, in a screenshot's file name and in a
  /// deep link. Matches the screenshot and the doc page.
  final String id;

  /// What the chart is called.
  final String title;

  /// One line on what it is for.
  final String blurb;

  /// Which part of the package it belongs to.
  final GalleryGroup group;

  /// Its page under `doc/`.
  final String doc;

  /// What there is to show, in the order it should be shown.
  final List<GalleryVariant> variants;
}

/// Every chart the gallery knows about.
///
/// Built fresh on each call: the charts hold no state between them, and a page
/// that rebuilds should not be handed widgets a previous build was using.
List<GalleryEntry> galleryEntries() => [
  ..._orderFlow(),
  ..._results(),
  ..._dashboard(),
  ..._models(),
];

/// The entry with this [id], or null when there is none.
GalleryEntry? galleryEntryById(String id) {
  for (final entry in galleryEntries()) {
    if (entry.id == id) return entry;
  }
  return null;
}

const _axisStyle = TextStyle(color: Color(0xFF8B95A1), fontSize: 11);
const _smallAxisStyle = TextStyle(color: Color(0xFF8B95A1), fontSize: 10);
const _darkLabel = TextStyle(
  color: Color(0xFF10151C),
  fontSize: 12,
  fontWeight: FontWeight.w700,
);
const _grid = Color(0x14FFFFFF);

List<GalleryEntry> _orderFlow() => [
  GalleryEntry(
    id: 'volatility-surface',
    title: 'Volatility surface',
    blurb:
        'Implied volatility across strike and expiry at once, with the '
        'skew against the at-the-money strike on touch.',
    group: GalleryGroup.orderFlow,
    doc: 'volatility-surface-chart.md',
    variants: [
      GalleryVariant(
        title: 'Strike by expiry',
        figure: 'spot 100',
        height: 360,
        build: () {
          final surface = galleryVolatilitySurface();
          return VolatilitySurfaceChart(
            strikes: surface.strikes,
            expiries: surface.expiries,
            volatilities: surface.vols,
            spot: 100,
            lowColor: galleryBlue,
            midColor: galleryAmber,
            highColor: galleryRed,
            axisLabelStyle: _smallAxisStyle,
            labelStyle: _darkLabel,
          );
        },
      ),
    ],
  ),
  GalleryEntry(
    id: 'futures-curve',
    title: 'Futures curve',
    blurb:
        'Prices against delivery month, with contango or backwardation '
        'read off the curve and last month\'s drawn dashed behind it.',
    group: GalleryGroup.orderFlow,
    doc: 'futures-curve-chart.md',
    variants: [
      GalleryVariant(
        title: 'Crude, today and a month ago',
        figure: '12 months out',
        height: 340,
        build: () {
          final curves = galleryFuturesCurves();
          return FuturesCurveChart(
            curves: [
              FuturesCurve(
                label: 'Today',
                contracts: curves.today,
                color: galleryBlue,
              ),
              FuturesCurve(
                label: 'A month ago',
                contracts: curves.before,
                color: galleryAmber,
                dashed: true,
              ),
            ],
            priceFormatter: (v) => '\$${v.toStringAsFixed(1)}',
            axisLabelStyle: _smallAxisStyle,
            gridColor: _grid,
          );
        },
      ),
    ],
  ),
  GalleryEntry(
    id: 'market-profile',
    title: 'Market profile',
    blurb:
        'Time at price as TPO letters, with the point of control and '
        'the 70% value area.',
    group: GalleryGroup.orderFlow,
    doc: 'market-profile-chart.md',
    variants: [
      GalleryVariant(
        title: 'Time at price',
        figure: 'POC and value area',
        height: 420,
        build: () => MarketProfileChart(
          profile: buildMarketProfile(galleryCandles(), tickSize: 40),
          blockColor: const Color(0xFF2A3644),
          valueAreaColor: const Color(0x224DABF7),
          pointOfControlColor: galleryAmber,
          letterStyle: const TextStyle(
            color: Color(0xFF9BB5D6),
            fontSize: 10,
            height: 1,
          ),
          axisLabelStyle: _smallAxisStyle,
          priceFormatter: galleryFullPrice,
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'footprint',
    title: 'Footprint',
    blurb:
        'Bid against ask volume at every price, inside each candle, '
        'with imbalances marked.',
    group: GalleryGroup.orderFlow,
    doc: 'footprint-chart.md',
    variants: [
      GalleryVariant(
        title: 'Order flow',
        figure: 'bid × ask per level',
        height: 420,
        build: () => FootprintChart(
          bars: galleryFootprint(bars: 10, tick: 40),
          tickSize: 40,
          buyColor: galleryGreen,
          sellColor: galleryRed,
          numberStyle: const TextStyle(
            color: Color(0xFFD6DEE8),
            fontSize: 9,
            height: 1,
          ),
          axisLabelStyle: _smallAxisStyle,
          priceFormatter: galleryFullPrice,
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'book-heatmap',
    title: 'Order-book heatmap',
    blurb:
        'Resting liquidity over time. A wall holds its price while the '
        'mid wanders past it.',
    group: GalleryGroup.orderFlow,
    doc: 'book-heatmap-chart.md',
    variants: [
      GalleryVariant(
        title: 'Resting liquidity',
        figure: '20 minutes',
        height: 400,
        build: () => BookHeatmapChart(
          snapshots: galleryBook(),
          tickSize: 20,
          bidColor: galleryGreen,
          askColor: galleryRed,
          midColor: Colors.white,
          axisLabelStyle: _smallAxisStyle,
          priceFormatter: galleryFullPrice,
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'cumulative-delta',
    title: 'Cumulative delta',
    blurb:
        'Buying less selling, running through the session, with '
        'divergences against price marked.',
    group: GalleryGroup.orderFlow,
    doc: 'cumulative-delta-chart.md',
    variants: [
      GalleryVariant(
        title: 'Cumulative delta',
        figure: 'buying less selling',
        height: 360,
        build: () => CumulativeDeltaChart(
          bars: deltaBarsFromFootprint(galleryFootprint(bars: 60)),
          lineColor: galleryBlue,
          buyColor: galleryGreen,
          sellColor: galleryRed,
          axisLabelStyle: _smallAxisStyle,
          gridColor: _grid,
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'liquidity-map',
    title: 'Liquidity map',
    blurb:
        'Where the leveraged stops sit, and what a move that far would '
        'set off.',
    group: GalleryGroup.orderFlow,
    doc: 'liquidity-map-chart.md',
    variants: [
      GalleryVariant(
        title: 'Liquidation map',
        figure: 'price 68,000',
        height: 420,
        build: () => LiquidityMapChart(
          bins: liquidityBins(galleryLiquidity(), binCount: 42),
          currentPrice: 68000,
          longColor: galleryGreen,
          shortColor: galleryRed,
          axisStyle: _smallAxisStyle,
          priceFormatter: galleryFullPrice,
          gridColor: const Color(0x10909196),
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'open-interest',
    title: 'Open interest and funding',
    blurb:
        'How much money is in the trade, and which side is paying to '
        'be there.',
    group: GalleryGroup.orderFlow,
    doc: 'open-interest-chart.md',
    variants: [
      GalleryVariant(
        title: 'Open interest and funding',
        figure: '40 days',
        height: 360,
        build: () => OpenInterestChart(
          points: galleryOpenInterest(),
          interestColor: galleryBlue,
          priceColor: const Color(0x99FFFFFF),
          positiveFundingColor: galleryGreen,
          negativeFundingColor: galleryRed,
          axisStyle: _smallAxisStyle,
          interestFormatter: galleryMillions,
          gridColor: _grid,
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'option-payoff',
    title: 'Options payoff',
    blurb:
        'What a strategy makes at expiry, across every price, with the '
        'break-evens solved exactly.',
    group: GalleryGroup.orderFlow,
    doc: 'option-payoff-chart.md',
    variants: [
      GalleryVariant(
        title: 'Bull call spread',
        figure: 'max \$3.1k',
        figureColor: galleryGreen,
        build: () => OptionPayoffChart(
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
          profitColor: galleryGreen,
          lossColor: galleryRed,
          axisLabelStyle: _smallAxisStyle,
          priceFormatter: galleryPrice,
          payoffFormatter: galleryUsd,
          gridColor: _grid,
        ),
      ),
      GalleryVariant(
        title: 'Long straddle',
        figure: 'both ways',
        build: () => OptionPayoffChart(
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
          profitColor: galleryGreen,
          lossColor: galleryRed,
          axisLabelStyle: _smallAxisStyle,
          priceFormatter: galleryPrice,
          payoffFormatter: galleryUsd,
          gridColor: _grid,
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'volatility-curve',
    title: 'Volatility curves',
    blurb:
        'Implied volatility by strike or by expiry — a smile, a skew '
        'or a term structure.',
    group: GalleryGroup.orderFlow,
    doc: 'volatility-curve-chart.md',
    variants: [
      GalleryVariant(
        title: 'Volatility smile',
        figure: 'three expiries',
        build: () => VolatilityCurveChart(
          slices: [
            for (var e = 0; e < 3; e++)
              VolatilitySlice(
                label: ['7d', '30d', '90d'][e],
                color: galleryPalette[e],
                points: [
                  for (var i = 0; i < 11; i++)
                    VolatilityPoint(
                      x: 56000 + i * 2400,
                      volatility:
                          0.42 +
                          e * 0.04 +
                          ((i - 5) / 5) * ((i - 5) / 5) * (0.22 - e * 0.05) -
                          (i - 5) * 0.006,
                    ),
                ],
              ),
          ],
          axisLabelStyle: _smallAxisStyle,
          xFormatter: galleryPrice,
          gridColor: _grid,
          legendStyle: _axisStyle,
        ),
      ),
      GalleryVariant(
        title: 'Term structure',
        figure: 'at the money',
        build: () => VolatilityCurveChart(
          slices: [
            VolatilitySlice(
              label: 'ATM',
              color: galleryGreen,
              points: [
                for (var i = 0; i < 8; i++)
                  VolatilityPoint(
                    x: [1, 7, 14, 30, 60, 90, 180, 365][i].toDouble(),
                    volatility: 0.62 - i * 0.03,
                  ),
              ],
            ),
          ],
          axisLabelStyle: _smallAxisStyle,
          xFormatter: (value) => '${value.toStringAsFixed(0)}d',
          gridColor: _grid,
          legendStyle: _axisStyle,
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'pair-spread',
    title: 'Pair spread',
    blurb:
        'Two symbols read as one spread, with bands round its mean and '
        'a z-score to trade off.',
    group: GalleryGroup.orderFlow,
    doc: 'pair-spread-chart.md',
    variants: [
      GalleryVariant(
        title: 'BTC against ETH',
        figure: 'log ratio, 30d',
        height: 400,
        build: () => PairSpreadChart(
          points: galleryPair(),
          mode: PairSpreadMode.logRatio,
          lookback: 30,
          spreadColor: galleryBlue,
          bandColor: const Color(0x334DABF7),
          meanColor: const Color(0xFF5C6570),
          zColor: galleryPurple,
          longColor: galleryGreen,
          shortColor: galleryRed,
          exitColor: galleryRed,
          axisLabelStyle: _smallAxisStyle,
          gridColor: _grid,
        ),
      ),
    ],
  ),
];

List<GalleryEntry> _results() => [
  GalleryEntry(
    id: 'mae-mfe',
    title: 'MAE / MFE scatter',
    blurb:
        'Every trade by how far it went against you, or for you, and what '
        'it finally made — to place a stop and a target.',
    group: GalleryGroup.results,
    doc: 'mae-mfe-chart.md',
    variants: [
      GalleryVariant(
        title: 'Max adverse excursion',
        figure: 'stop at 1R',
        height: 360,
        build: () => MaeMfeChart(
          trades: galleryExcursions(),
          xReferenceLines: const [1],
          winnerColor: galleryGreen,
          loserColor: galleryRed,
          xFormatter: (v) => '${v.toStringAsFixed(1)}R',
          yFormatter: (v) => '${v.toStringAsFixed(0)}R',
          axisLabelStyle: _smallAxisStyle,
          axisTitleStyle: _smallAxisStyle,
          yAxisTitle: 'Result',
          gridColor: _grid,
        ),
      ),
      GalleryVariant(
        title: 'Max favourable excursion',
        figure: 'the limit line',
        height: 360,
        build: () => MaeMfeChart(
          trades: galleryExcursions(),
          kind: ExcursionKind.favourable,
          winnerColor: galleryGreen,
          loserColor: galleryRed,
          xFormatter: (v) => '${v.toStringAsFixed(1)}R',
          yFormatter: (v) => '${v.toStringAsFixed(0)}R',
          axisLabelStyle: _smallAxisStyle,
          axisTitleStyle: _smallAxisStyle,
          yAxisTitle: 'Result',
          gridColor: _grid,
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'var',
    title: 'Value at risk',
    blurb:
        'The shape of the returns, with the loss tail picked out and the '
        'value at risk and expected shortfall marked.',
    group: GalleryGroup.results,
    doc: 'var-chart.md',
    variants: [
      GalleryVariant(
        title: 'Daily returns, 95%',
        figure: '400 days',
        height: 380,
        build: () => VarChart(
          returns: [for (final r in galleryReturns()) r / 100],
          barColor: galleryBlue,
          tailColor: galleryRed,
          axisLabelStyle: _smallAxisStyle,
          statLabelStyle: _smallAxisStyle,
          statValueStyle: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          gridColor: _grid,
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'efficient-frontier',
    title: 'Efficient frontier',
    blurb:
        'Portfolios by risk and return, with the frontier, the best Sharpe '
        'ratio, the least risky portfolio and the one held now.',
    group: GalleryGroup.results,
    doc: 'efficient-frontier-chart.md',
    variants: [
      GalleryVariant(
        title: 'Risk and return',
        figure: 'risk-free 2%',
        height: 400,
        build: () => EfficientFrontierChart(
          points: galleryPortfolios(),
          riskFreeRate: 0.02,
          current: const PortfolioPoint(risk: 0.19, expectedReturn: 0.083),
          portfolioColor: const Color(0x664DABF7),
          frontierColor: galleryGreen,
          maxSharpeColor: galleryAmber,
          minRiskColor: galleryTeal,
          currentColor: galleryRed,
          riskFormatter: (v) => '${(v * 100).toStringAsFixed(0)}%',
          returnFormatter: (v) => '${(v * 100).toStringAsFixed(0)}%',
          axisLabelStyle: _smallAxisStyle,
          axisTitleStyle: _smallAxisStyle,
          gridColor: _grid,
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'activity-clock',
    title: 'Activity clock',
    blurb:
        'A week as a clock face — an hour round the dial, a weekday on '
        'each ring — coloured by when the trades were opened.',
    group: GalleryGroup.results,
    doc: 'activity-clock-chart.md',
    variants: [
      GalleryVariant(
        title: 'Trades opened by hour',
        figure: 'Mon is innermost',
        height: 420,
        build: () => ActivityClockChart(
          samples: galleryActivity(),
          aggregate: SeasonalityAggregate.mean,
          scale: HeatmapGradientScale(
            colors: [
              galleryBlue.withValues(alpha: 0.12),
              galleryBlue,
              galleryAmber,
            ],
          ),
          labelStyle: _smallAxisStyle,
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'equity-curve',
    title: 'Equity curve',
    blurb:
        'The curve, with an underwater panel under it showing how far '
        'below the high water mark it ran.',
    group: GalleryGroup.results,
    doc: 'equity-curve-chart.md',
    variants: [
      GalleryVariant(
        title: 'Equity and drawdown',
        figure: galleryUsd(56400),
        figureColor: galleryGreen,
        height: 400,
        build: () => EquityCurveChart(
          points: galleryEquity(),
          lineColor: galleryGreen,
          fillOpacity: 0.18,
          drawdownColor: galleryRed,
          axisLabelStyle: _smallAxisStyle,
          valueFormatter: galleryUsd,
          gridColor: _grid,
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'monte-carlo',
    title: 'Monte Carlo fan',
    blurb:
        'The same trades dealt in a thousand other orders, as '
        'percentile bands, with the odds of loss and ruin.',
    group: GalleryGroup.results,
    doc: 'monte-carlo-chart.md',
    variants: [
      GalleryVariant(
        title: 'A thousand futures',
        figure: 'p5 – p95',
        height: 400,
        build: () => MonteCarloChart(
          result: runMonteCarlo(
            galleryTradePnl(),
            pathCount: 800,
            startingEquity: 40000,
            sizing: MonteCarloSizing.fixed,
            seed: 7,
            ruinLevel: 20000,
          ),
          bandColor: galleryGreen,
          medianColor: galleryGreen,
          actualColor: Colors.white,
          ruinColor: galleryRed,
          axisLabelStyle: _smallAxisStyle,
          valueFormatter: galleryUsd,
          summaryStyle: _smallAxisStyle,
          gridColor: _grid,
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'r-multiple',
    title: 'R-multiple distribution',
    blurb:
        'Trade results in R, with win rate, expectancy, profit factor '
        'and SQN over them.',
    group: GalleryGroup.results,
    doc: 'r-multiple-chart.md',
    variants: [
      GalleryVariant(
        title: 'Trade results in R',
        figure: '180 trades',
        height: 380,
        build: () => RMultipleChart(
          results: galleryRMultiples(),
          binWidth: 0.5,
          profitColor: galleryGreen,
          lossColor: galleryRed,
          axisLabelStyle: _smallAxisStyle,
          statLabelStyle: _smallAxisStyle,
          statValueStyle: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'trade-timeline',
    title: 'Trade timeline',
    blurb:
        'Every trade from entry to exit, a lane per symbol, with how '
        'many were open underneath.',
    group: GalleryGroup.results,
    doc: 'trade-timeline-chart.md',
    variants: [
      GalleryVariant(
        title: 'When each trade was open',
        figure: '17 trades',
        height: 420,
        build: () => TradeTimelineChart(
          trades: galleryTrades(),
          now: galleryTimelineNow,
          profitColor: galleryGreen,
          lossColor: galleryRed,
          exposureColor: galleryBlue,
          pnlFormatter: galleryUsd,
          laneLabelStyle: _smallAxisStyle,
          axisLabelStyle: _smallAxisStyle,
          gridColor: _grid,
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'seasonality',
    title: 'Seasonality',
    blurb:
        'Results across the calendar: month by year, weekday by hour, '
        'with a total per row.',
    group: GalleryGroup.results,
    doc: 'seasonality-chart.md',
    variants: [
      GalleryVariant(
        title: 'Month by year',
        figure: 'compounded',
        height: 400,
        build: () => SeasonalityChart(
          samples: gallerySeasonality(),
          aggregate: SeasonalityAggregate.compound,
          profitColor: galleryGreen,
          lossColor: galleryRed,
          axisLabelStyle: _smallAxisStyle,
          labelStyle: const TextStyle(color: Colors.white, fontSize: 10),
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'calendar',
    title: 'Calendar',
    blurb:
        'Daily profit and loss on real month panels, each month '
        'totalled in its header.',
    group: GalleryGroup.results,
    doc: 'calendar-chart.md',
    variants: [
      GalleryVariant(
        title: 'Daily profit and loss',
        figure: galleryUsd(14800),
        figureColor: galleryGreen,
        height: 420,
        build: () => CalendarChart(
          days: galleryCalendar(),
          monthsPerRow: 2,
          scale: const HeatmapGradientScale(
            colors: [galleryRed, Color(0xFF1B222B), galleryGreen],
          ),
          cellSpacing: 3,
          cellRadius: const BorderRadius.all(Radius.circular(3)),
          showDayNumbers: true,
          showWeekdayHeader: true,
          headerStyle: _smallAxisStyle,
          dayNumberStyle: const TextStyle(color: Colors.white, fontSize: 9),
          valueFormatter: galleryUsd,
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'waterfall',
    title: 'Waterfall',
    blurb:
        'A total built up step by step, from the opening balance to '
        'the closing one.',
    group: GalleryGroup.results,
    doc: 'waterfall-chart.md',
    variants: [
      GalleryVariant(
        title: 'From opening to closing balance',
        figure: galleryUsd(52400),
        figureColor: galleryGreen,
        height: 360,
        build: () => WaterfallChart(
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
            WaterfallStep(
              value: 0,
              label: 'Closing',
              kind: WaterfallKind.total,
            ),
          ],
          riseColor: galleryGreen,
          fallColor: galleryRed,
          totalColor: galleryBlue,
          labelStyle: _smallAxisStyle,
          valueStyle: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          valueFormatter: galleryUsd,
        ),
      ),
    ],
  ),
];

List<GalleryEntry> _dashboard() => [
  GalleryEntry(
    id: 'treemap',
    title: 'Treemap',
    blurb:
        'A rectangle split into tiles sized by value — a market map, '
        'or what a portfolio is made of.',
    group: GalleryGroup.dashboard,
    doc: 'treemap-chart.md',
    variants: [
      GalleryVariant(
        title: 'Market map',
        figure: '+0.8%',
        figureColor: galleryGreen,
        height: 360,
        build: () => TreemapChart(
          items: [
            TreemapItem.group(
              label: 'Majors',
              children: [
                _symbol('BTC', 38, 2.4),
                _symbol('ETH', 22, 1.1),
                _symbol('SOL', 9, -1.8),
              ],
            ),
            TreemapItem.group(
              label: 'DeFi',
              children: [_symbol('UNI', 9, -3.2), _symbol('AAVE', 7, 0.6)],
            ),
            TreemapItem.group(
              label: 'Layer 2',
              children: [_symbol('ARB', 9, 4.6), _symbol('OP', 6, 3.1)],
            ),
          ],
          scale: const HeatmapGradientScale(
            colors: [galleryRed, Color(0xFF2A313B), galleryGreen],
          ),
          minColorValue: -5,
          maxColorValue: 5,
          groupLabelStyle: _smallAxisStyle,
          labelStyle: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
          spacing: 3,
          radius: const BorderRadius.all(Radius.circular(3)),
        ),
      ),
      GalleryVariant(
        title: 'Portfolio weight',
        figure: galleryUsd(48200),
        height: 300,
        build: () => TreemapChart(
          items: const [
            TreemapItem(value: 42, label: 'BTC\n42%', color: galleryPurple),
            TreemapItem(value: 26, label: 'ETH\n26%', color: galleryBlue),
            TreemapItem(value: 18, label: 'SOL\n18%', color: galleryAmber),
            TreemapItem(value: 14, label: 'Cash\n14%', color: galleryGreen),
          ],
          labelStyle: TextStyle(
            color: Color(0xFF10151C),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
          spacing: 3,
          radius: const BorderRadius.all(Radius.circular(3)),
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'sunburst',
    title: 'Sunburst',
    blurb:
        'The same hierarchy as a treemap, drawn as rings from the '
        'middle out.',
    group: GalleryGroup.dashboard,
    doc: 'sunburst-chart.md',
    variants: [
      GalleryVariant(
        title: 'Book by desk and symbol',
        figure: galleryUsd(48200),
        height: 400,
        build: () => SunburstChart(
          items: [
            TreemapItem.group(
              label: 'Majors',
              color: galleryBlue,
              children: const [
                TreemapItem(value: 38, label: 'BTC'),
                TreemapItem(value: 22, label: 'ETH'),
                TreemapItem(value: 9, label: 'SOL'),
              ],
            ),
            TreemapItem.group(
              label: 'DeFi',
              color: galleryPurple,
              children: const [
                TreemapItem(value: 7, label: 'UNI'),
                TreemapItem(value: 5, label: 'AAVE'),
                TreemapItem(value: 4, label: 'LDO'),
              ],
            ),
            TreemapItem.group(
              label: 'Layer 2',
              color: galleryAmber,
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
              Text('Book', style: _smallAxisStyle),
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
    ],
  ),
  GalleryEntry(
    id: 'sankey',
    title: 'Sankey',
    blurb: 'Flow between nodes, each link as thick as what it carries.',
    group: GalleryGroup.dashboard,
    doc: 'sankey-chart.md',
    variants: [
      GalleryVariant(
        title: 'Where the money went',
        figure: galleryUsd(184000),
        height: 400,
        build: () => SankeyChart(
          nodes: const [
            SankeyNode(id: 'spot', label: 'Spot fees', color: galleryBlue),
            SankeyNode(id: 'perps', label: 'Perp fees', color: galleryPurple),
            SankeyNode(id: 'funding', label: 'Funding', color: galleryAmber),
            SankeyNode(id: 'revenue', label: 'Revenue', color: galleryGreen),
            SankeyNode(id: 'infra', label: 'Infrastructure'),
            SankeyNode(id: 'staff', label: 'Salaries'),
            SankeyNode(id: 'market', label: 'Market making'),
            SankeyNode(id: 'profit', label: 'Profit', color: galleryGreen),
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
          palette: galleryPalette,
          labelStyle: _smallAxisStyle,
          valueFormatter: (value) => '\$${value.toStringAsFixed(0)}k',
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'chord',
    title: 'Chord',
    blurb:
        'Flow between nodes both ways round a ring — cycles drawn '
        'rather than broken.',
    group: GalleryGroup.dashboard,
    doc: 'chord-chart.md',
    variants: [
      GalleryVariant(
        title: 'Flow between venues',
        figure: '24h',
        height: 420,
        build: () => const ChordChart(
          nodes: [
            ChordNode(label: 'Binance', color: galleryAmber),
            ChordNode(label: 'OKX', color: galleryBlue),
            ChordNode(label: 'Bybit', color: galleryGreen),
            ChordNode(label: 'Deribit', color: galleryPurple),
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
          labelStyle: _smallAxisStyle,
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'marimekko',
    title: 'Marimekko',
    blurb:
        'Two dimensions at once: every column as wide as it is big, '
        'split by its own shares.',
    group: GalleryGroup.dashboard,
    doc: 'marimekko-chart.md',
    variants: [
      GalleryVariant(
        title: 'Volume by venue and instrument',
        figure: galleryUsd(920000),
        height: 400,
        build: () => const MarimekkoChart(
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
          palette: galleryPalette,
          headerStyle: _smallAxisStyle,
          cellStyle: _darkLabel,
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'stream',
    title: 'Stream graph',
    blurb:
        'A stack that flows: what a whole was made of, period by '
        'period, on a wiggle baseline.',
    group: GalleryGroup.dashboard,
    doc: 'stream-chart.md',
    variants: [
      GalleryVariant(
        title: 'Book by symbol, two years',
        figure: 'wiggle baseline',
        height: 380,
        build: () => StreamChart(
          periodLabels: [
            for (var i = 0; i < 24; i++)
              i % 3 == 0 ? galleryMonths[i % 12] : '',
          ],
          series: [
            StreamSeries(label: 'BTC', values: galleryBand(60, 0.2, 0.9)),
            StreamSeries(label: 'ETH', values: galleryBand(38, 1.6, -0.4)),
            StreamSeries(label: 'SOL', values: galleryBand(22, 2.9, 1.1)),
            StreamSeries(label: 'ARB', values: galleryBand(14, 0.8, 0.3)),
            StreamSeries(label: 'Cash', values: galleryBand(30, 2.1, -0.2)),
          ],
          palette: galleryPalette,
          axisStyle: _smallAxisStyle,
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'parallel',
    title: 'Parallel coordinates',
    blurb:
        'Many things compared on many measures at once, an axis each, '
        'invertible so the best is highest.',
    group: GalleryGroup.dashboard,
    doc: 'parallel-chart.md',
    variants: [
      GalleryVariant(
        title: 'Strategies on five measures',
        figure: 'best is highest',
        height: 400,
        build: () => const ParallelChart(
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
          palette: galleryPalette,
          showLegend: true,
          headerStyle: _smallAxisStyle,
          endStyle: _smallAxisStyle,
          dotRadius: 4,
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'slope',
    title: 'Slope and bump',
    blurb:
        'How things moved between periods — by value, or by the ranks '
        'changing hands.',
    group: GalleryGroup.dashboard,
    doc: 'slope-chart.md',
    variants: [
      GalleryVariant(
        title: 'Return by quarter',
        figure: 'value scale',
        build: () => const SlopeChart(
          periodLabels: ['Q1', 'Q2', 'Q3', 'Q4'],
          series: [
            SlopeSeries(label: 'BTC', values: [4.2, 19.0, 11.5, 22.4]),
            SlopeSeries(label: 'ETH', values: [12.1, 8.4, 2.0, 9.6]),
            SlopeSeries(label: 'SOL', values: [9.7, 1.2, 18.3, 14.1]),
          ],
          palette: galleryPalette,
          labelStyle: _smallAxisStyle,
          headerStyle: _smallAxisStyle,
        ),
      ),
      GalleryVariant(
        title: 'The same, by rank',
        figure: 'bump scale',
        build: () => const SlopeChart(
          periodLabels: ['Q1', 'Q2', 'Q3', 'Q4'],
          scale: SlopeScale.rank,
          series: [
            SlopeSeries(label: 'BTC', values: [4.2, 19.0, 11.5, 22.4]),
            SlopeSeries(label: 'ETH', values: [12.1, 8.4, 2.0, 9.6]),
            SlopeSeries(label: 'SOL', values: [9.7, 1.2, 18.3, 14.1]),
          ],
          palette: galleryPalette,
          showValues: false,
          labelStyle: _smallAxisStyle,
          headerStyle: _smallAxisStyle,
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'bubble',
    title: 'Bubble',
    blurb:
        'Three numbers at once: two for position, one for the area of '
        'the bubble.',
    group: GalleryGroup.dashboard,
    doc: 'bubble-chart.md',
    variants: [
      GalleryVariant(
        title: 'Risk against return',
        figure: 'size is capital',
        height: 400,
        build: () => const BubbleChart(
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
          palette: galleryPalette,
          xAxisTitle: 'Max drawdown %',
          yAxisTitle: 'Return %',
          axisLabelStyle: _smallAxisStyle,
          axisTitleStyle: _smallAxisStyle,
          labelStyle: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          gridColor: _grid,
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'box-plot',
    title: 'Box plot',
    blurb: 'Quartiles, whiskers and outliers, a box per thing compared.',
    group: GalleryGroup.dashboard,
    doc: 'box-plot-chart.md',
    variants: [
      GalleryVariant(
        title: 'Daily returns by strategy',
        figure: '400 days each',
        height: 380,
        build: () => BoxPlotChart(
          entries: [
            BoxPlotEntry(
              label: 'Trend',
              stats: BoxPlotStats.fromSamples(galleryReturns()),
              color: galleryBlue,
            ),
            BoxPlotEntry(
              label: 'Revert',
              stats: BoxPlotStats.fromSamples(
                galleryReturns(mean: 0.2, spread: 1.1),
              ),
              color: galleryGreen,
            ),
            BoxPlotEntry(
              label: 'Breakout',
              stats: BoxPlotStats.fromSamples(
                galleryReturns(mean: 0.6, spread: 2.9, skew: 0.3),
              ),
              color: galleryAmber,
            ),
            BoxPlotEntry(
              label: 'Carry',
              stats: BoxPlotStats.fromSamples(
                galleryReturns(mean: 0.15, spread: 0.7),
              ),
              color: galleryPurple,
            ),
          ],
          axisLabelStyle: _smallAxisStyle,
          entryLabelStyle: _smallAxisStyle,
          valueFormatter: galleryPercent,
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'histogram',
    title: 'Histogram',
    blurb: 'The shape of a distribution, counted into bins.',
    group: GalleryGroup.dashboard,
    doc: 'histogram-chart.md',
    variants: [
      GalleryVariant(
        title: 'Daily returns',
        figure: '400 days',
        build: () => HistogramChart(
          bins: histogramBins(galleryReturns(), binCount: 26),
          barColor: galleryBlue,
          negativeColor: galleryRed,
          axisLabelStyle: _smallAxisStyle,
          valueFormatter: galleryPercent,
          referenceLines: const [0],
          gridColor: _grid,
        ),
      ),
      GalleryVariant(
        title: 'Trade size',
        figure: '600 trades',
        build: () => HistogramChart(
          bins: histogramBins(
            galleryWave(
              600,
              base: 6000,
              swing: 3000,
              phase: 0.7,
            ).map((v) => v.abs()).toList(),
            binCount: 20,
          ),
          barColor: galleryPurple,
          axisLabelStyle: _smallAxisStyle,
          valueFormatter: galleryUsd,
          gridColor: _grid,
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'violin',
    title: 'Violin and ridgeline',
    blurb:
        'The shape of a distribution, not just its quartiles — side by '
        'side, or stacked as a ridgeline.',
    group: GalleryGroup.dashboard,
    doc: 'violin-chart.md',
    variants: [
      GalleryVariant(
        title: 'Violins',
        figure: 'four strategies',
        height: 380,
        build: () => ViolinChart(
          series: [
            ViolinSeries(label: 'Trend', samples: galleryReturns()),
            ViolinSeries(
              label: 'Revert',
              samples: galleryReturns(mean: 0.2, spread: 1.1),
            ),
            ViolinSeries(
              label: 'Breakout',
              samples: galleryReturns(mean: 0.6, spread: 2.9, skew: 0.3),
            ),
            ViolinSeries(
              label: 'Carry',
              samples: galleryReturns(mean: 0.15, spread: 0.7),
            ),
          ],
          palette: galleryPalette,
          labelStyle: _smallAxisStyle,
          axisStyle: _smallAxisStyle,
          axisFormatter: galleryPercent,
        ),
      ),
      GalleryVariant(
        title: 'Ridgeline',
        figure: 'by month',
        height: 380,
        build: () => ViolinChart(
          shape: ViolinShape.ridgeline,
          series: [
            for (var i = 0; i < 5; i++)
              ViolinSeries(
                label: galleryMonths[i],
                samples: galleryReturns(
                  mean: 0.1 + i * 0.25,
                  spread: 1.2 + i * 0.5,
                ),
              ),
          ],
          palette: galleryPalette,
          labelWidth: 44,
          labelStyle: _smallAxisStyle,
          axisStyle: _smallAxisStyle,
          axisFormatter: galleryPercent,
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'dumbbell',
    title: 'Dumbbell',
    blurb: 'Two values a row joined by a bar, when the gap is the point.',
    group: GalleryGroup.dashboard,
    doc: 'dumbbell-chart.md',
    variants: [
      GalleryVariant(
        title: 'Quarter on quarter',
        figure: 'Q3 → Q4',
        build: () => const DumbbellChart(
          rows: [
            DumbbellRow(label: 'BTC', from: 61200, to: 68400),
            DumbbellRow(label: 'ETH', from: 3400, to: 3120),
            DumbbellRow(label: 'SOL', from: 142, to: 198),
            DumbbellRow(label: 'ARB', from: 1.8, to: 1.2),
          ],
          min: 0,
          max: 70000,
          showValues: true,
          labelStyle: _smallAxisStyle,
          axisStyle: _smallAxisStyle,
          riseColor: galleryGreen,
          fallColor: galleryRed,
          fromColor: Color(0xFF5C6570),
        ),
      ),
      GalleryVariant(
        title: 'Day range',
        figure: 'low → high',
        build: () => const DumbbellChart(
          rows: [
            DumbbellRow(label: 'Mon', from: 66100, to: 68900),
            DumbbellRow(label: 'Tue', from: 67200, to: 69400),
            DumbbellRow(label: 'Wed', from: 65800, to: 68100),
            DumbbellRow(label: 'Thu', from: 66400, to: 70200),
            DumbbellRow(label: 'Fri', from: 68300, to: 71500),
          ],
          labelStyle: _smallAxisStyle,
          axisStyle: _smallAxisStyle,
          toColor: galleryBlue,
          fromColor: Color(0xFF5C6570),
          barColor: Color(0x554DABF7),
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'bullet',
    title: 'Bullet',
    blurb:
        'A measure against its target on a banded track — a gauge in '
        'the space of a line.',
    group: GalleryGroup.dashboard,
    doc: 'bullet-chart.md',
    variants: [
      GalleryVariant(
        title: 'This quarter against target',
        figure: '4 of 5 met',
        figureColor: galleryGreen,
        height: 300,
        build: () => const BulletChart(
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
          labelStyle: _smallAxisStyle,
          barColor: galleryBlue,
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'gauge',
    title: 'Gauge',
    blurb: 'One value on a dial, with coloured ranges, a needle and ticks.',
    group: GalleryGroup.dashboard,
    doc: 'gauge-chart.md',
    variants: [
      GalleryVariant(
        title: 'Account risk',
        figure: '72',
        figureColor: galleryAmber,
        build: () => const GaugeChart(
          value: 72,
          showValueBar: false,
          label: 'Risk score',
          labelStyle: _smallAxisStyle,
          ranges: [
            GaugeRange(from: 0, to: 40, color: galleryGreen),
            GaugeRange(from: 40, to: 75, color: galleryAmber),
            GaugeRange(from: 75, to: 100, color: galleryRed),
          ],
          needle: GaugeNeedle(),
          ticks: GaugeTicks(count: 4, labelStyle: _smallAxisStyle),
          valueStyle: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      GalleryVariant(
        title: 'Margin level',
        figure: '318%',
        figureColor: galleryGreen,
        build: () => GaugeChart(
          value: 318,
          max: 500,
          startAngle: -90,
          sweepAngle: 180,
          thickness: 18,
          valueColor: galleryGreen,
          ticks: const GaugeTicks(count: 5, labelStyle: _smallAxisStyle),
          label: 'Equity over margin',
          labelStyle: _smallAxisStyle,
          valueFormatter: (value) => '${value.toStringAsFixed(0)}%',
          valueStyle: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      GalleryVariant(
        title: 'Monthly target',
        figure: '64%',
        figureColor: galleryBlue,
        build: () => GaugeChart(
          value: 64,
          sweepAngle: 360,
          startAngle: 0,
          thickness: 16,
          valueColor: galleryBlue,
          ticks: GaugeTicks.none,
          label: 'of \$12k',
          labelStyle: _smallAxisStyle,
          valueFormatter: (value) => '${value.toStringAsFixed(0)}%',
          valueStyle: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'waffle',
    title: 'Waffle',
    blurb:
        'Shares as a hundred squares, counted rather than judged by '
        'angle.',
    group: GalleryGroup.dashboard,
    doc: 'waffle-chart.md',
    variants: [
      GalleryVariant(
        title: 'Portfolio',
        figure: '100 cells',
        build: () => const WaffleChart(
          slices: [
            WaffleSlice(label: 'Crypto', value: 45, color: galleryPurple),
            WaffleSlice(label: 'Equities', value: 35, color: galleryBlue),
            WaffleSlice(label: 'Cash', value: 20, color: galleryGreen),
          ],
          cellGap: 4,
          cellRadius: BorderRadius.all(Radius.circular(3)),
        ),
      ),
      GalleryVariant(
        title: 'Winning trades',
        figure: '38 of 100',
        build: () => const WaffleChart(
          slices: [
            WaffleSlice(label: 'Winners', value: 38, color: galleryGreen),
          ],
          total: 100,
          cellGap: 4,
          cellRadius: BorderRadius.all(Radius.circular(3)),
          emptyColor: Color(0x22FA5252),
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'funnel',
    title: 'Funnel',
    blurb:
        'Where the people go, stage by stage, tapered or '
        'straight-sided.',
    group: GalleryGroup.dashboard,
    doc: 'funnel-chart.md',
    variants: [
      GalleryVariant(
        title: 'Onboarding',
        figure: '12.4% funded',
        height: 380,
        build: () => FunnelChart(
          stages: const [
            FunnelStage(value: 9840, label: 'Signed up'),
            FunnelStage(value: 6120, label: 'Verified email'),
            FunnelStage(value: 3410, label: 'Passed KYC'),
            FunnelStage(value: 1900, label: 'Deposited'),
            FunnelStage(value: 1220, label: 'First trade'),
          ],
          palette: galleryPalette,
          labelStyle: _darkLabel,
          sideLabelStyle: _smallAxisStyle,
        ),
      ),
      GalleryVariant(
        title: 'Straight-sided',
        figure: '5 stages',
        height: 380,
        build: () => FunnelChart(
          stages: const [
            FunnelStage(value: 100, label: 'Impressions'),
            FunnelStage(value: 64, label: 'Clicks'),
            FunnelStage(value: 38, label: 'Sign-ups'),
            FunnelStage(value: 21, label: 'Trials'),
            FunnelStage(value: 9, label: 'Paid'),
          ],
          shape: FunnelShape.stepped,
          palette: galleryPalette,
          labelStyle: _darkLabel,
          sideLabelStyle: _smallAxisStyle,
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'sparkline-grid',
    title: 'Sparkline grid',
    blurb:
        'Small multiples for a watchlist: a name, a shape and a number '
        'each, every tile on its own scale.',
    group: GalleryGroup.dashboard,
    doc: 'sparkline-grid.md',
    variants: [
      GalleryVariant(
        title: 'Watchlist',
        figure: '12 symbols',
        height: 420,
        build: () => SparklineGrid(
          columns: 2,
          tileHeight: 58,
          tileGap: 6,
          tiles: galleryWatchlist(),
          riseColor: galleryGreen,
          fallColor: galleryRed,
          labelStyle: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          subtitleStyle: const TextStyle(color: Color(0xFF5C6570), fontSize: 9),
          valueStyle: _smallAxisStyle,
          tileColor: const Color(0xFF11161D),
        ),
      ),
    ],
  ),
];

TreemapItem _symbol(String name, double weight, double change) => TreemapItem(
  value: weight,
  label: '$name\n${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%',
  colorValue: change,
);

List<GalleryEntry> _models() => [
  GalleryEntry(
    id: 'training-curve',
    title: 'Training curves',
    blurb:
        'Loss and accuracy of one or more runs, with smoothing, a log axis, '
        'the best checkpoint and the step a run diverged.',
    group: GalleryGroup.models,
    doc: 'training-curve-chart.md',
    variants: [
      GalleryVariant(
        title: 'Train and validation',
        figure: 'overfits at 2,250',
        height: 380,
        build: () {
          final curves = galleryLossCurves();
          return TrainingCurveChart(
            runs: [
              TrainingRun(
                label: 'train',
                points: curves.train,
                color: galleryBlue,
              ),
              TrainingRun(
                label: 'validation',
                points: curves.validation,
                color: galleryAmber,
                dashed: true,
              ),
            ],
            smoothing: 0.85,
            gapBetween: (0, 1),
            gapColor: const Color(0x33FA5252),
            yAxisTitle: 'Loss',
            axisLabelStyle: _smallAxisStyle,
            axisTitleStyle: _smallAxisStyle,
            gridColor: _grid,
          );
        },
      ),
      GalleryVariant(
        title: 'Three learning rates',
        figure: 'log axis',
        height: 380,
        build: () => TrainingCurveChart(
          runs: galleryLearningRates(),
          logY: true,
          smoothing: 0.4,
          yAxisTitle: 'Loss (log)',
          axisLabelStyle: _smallAxisStyle,
          axisTitleStyle: _smallAxisStyle,
          gridColor: _grid,
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'scaling-law',
    title: 'Scaling laws',
    blurb:
        'Loss against compute on log-log axes, with the power law fitted '
        'and carried to where it reaches a target.',
    group: GalleryGroup.models,
    doc: 'scaling-law-chart.md',
    variants: [
      GalleryVariant(
        title: 'Loss against FLOPs',
        figure: 'fit and extrapolation',
        height: 400,
        build: () => ScalingLawChart(
          points: galleryScaling(),
          extrapolateTo: 1e26,
          targetLoss: 2.0,
          pointColor: galleryBlue,
          fitColor: galleryAmber,
          bandColor: const Color(0x22FAB005),
          targetColor: galleryGreen,
          xAxisTitle: 'Training compute (FLOPs)',
          yAxisTitle: 'Loss',
          axisLabelStyle: _smallAxisStyle,
          axisTitleStyle: _smallAxisStyle,
          gridColor: _grid,
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'sweep',
    title: 'Hyperparameter sweep',
    blurb:
        'A learning-rate by batch-size grid of validation losses, the best '
        'combination starred and the mean of each setting alongside.',
    group: GalleryGroup.models,
    doc: 'sweep-chart.md',
    variants: [
      GalleryVariant(
        title: 'Validation loss',
        figure: '5 × 5',
        height: 340,
        build: () => SweepChart(
          trials: gallerySweep(),
          goodColor: galleryGreen,
          midColor: galleryAmber,
          badColor: galleryRed,
          labelStyle: _darkLabel,
          axisLabelStyle: _smallAxisStyle,
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'training-timeline',
    title: 'Training timeline',
    blurb:
        'Training jobs by machine, coloured by how each finished, with how '
        'many were running underneath.',
    group: GalleryGroup.models,
    doc: 'training-timeline-chart.md',
    variants: [
      GalleryVariant(
        title: 'Two days on four pods',
        figure: '13 jobs',
        height: 360,
        build: () => TrainingTimelineChart(
          jobs: galleryJobs(),
          runningColor: galleryBlue,
          completedColor: galleryGreen,
          failedColor: galleryRed,
          preemptedColor: galleryAmber,
          cancelledColor: const Color(0xFF6B7480),
          axisLabelStyle: _smallAxisStyle,
          laneLabelStyle: _smallAxisStyle,
          gridColor: _grid,
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'benchmark-matrix',
    title: 'Benchmark matrix',
    blurb:
        'Models against benchmarks, each score coloured by where it stands '
        'in its column, the leaders starred.',
    group: GalleryGroup.models,
    doc: 'benchmark-matrix-chart.md',
    variants: [
      GalleryVariant(
        title: 'Six models, six benchmarks',
        figure: 'perplexity: lower wins',
        height: 340,
        build: () {
          final data = galleryBenchmarkScores();
          return BenchmarkMatrixChart(
            models: data.models,
            benchmarks: data.benchmarks,
            scores: data.scores,
            lowerIsBetter: const {5},
            lowColor: galleryRed,
            midColor: galleryAmber,
            highColor: galleryGreen,
            labelStyle: _darkLabel,
            axisLabelStyle: _smallAxisStyle,
            modelAxisWidth: 96,
          );
        },
      ),
    ],
  ),
  GalleryEntry(
    id: 'model-pareto',
    title: 'Model cost against quality',
    blurb:
        'Models by price and score on a log axis, with the Pareto frontier '
        'through the ones nothing beats.',
    group: GalleryGroup.models,
    doc: 'model-pareto-chart.md',
    variants: [
      GalleryVariant(
        title: 'Price against MMLU',
        figure: 'size = context window',
        height: 420,
        build: () => ModelParetoChart(
          models: galleryModels(),
          palette: galleryPalette,
          costFormatter: (v) => '\$${v < 1 ? v : v.toStringAsFixed(0)}',
          xAxisTitle: 'Price per 1M tokens',
          yAxisTitle: 'MMLU',
          axisLabelStyle: _smallAxisStyle,
          axisTitleStyle: _smallAxisStyle,
          legendStyle: _axisStyle,
          gridColor: _grid,
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'latency-band',
    title: 'Latency bands',
    blurb:
        'p50, p95 and p99 latency over a day as bands, with an objective '
        'drawn across and the intervals that broke it marked.',
    group: GalleryGroup.models,
    doc: 'latency-band-chart.md',
    variants: [
      GalleryVariant(
        title: 'Time to first token',
        figure: 'SLO 1,200 ms on p95',
        figureColor: galleryAmber,
        height: 380,
        build: () => LatencyBandChart(
          samples: galleryLatency(),
          slo: 1200,
          medianColor: galleryBlue,
          p95Color: galleryBlue,
          p99Color: galleryPurple,
          sloColor: galleryAmber,
          breachColor: galleryRed,
          valueFormatter: (v) => '${v.round()} ms',
          axisLabelStyle: _smallAxisStyle,
          gridColor: _grid,
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'token-usage',
    title: 'Token usage',
    blurb:
        'Cached, input and output tokens over two weeks as stacked columns, '
        'with the cost as a line on its own axis.',
    group: GalleryGroup.models,
    doc: 'token-usage-chart.md',
    variants: [
      GalleryVariant(
        title: 'Tokens and spend',
        figure: 'cache warming up',
        height: 380,
        build: () => TokenUsageChart(
          buckets: galleryUsage(),
          inputColor: galleryBlue,
          outputColor: galleryPurple,
          cachedColor: galleryTeal,
          costColor: galleryAmber,
          costFormatter: (v) => '\$${v.toStringAsFixed(0)}',
          axisLabelStyle: _smallAxisStyle,
          legendStyle: _axisStyle,
          gridColor: _grid,
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'eval-breakdown',
    title: 'Evaluation breakdown',
    blurb:
        'An evaluation by category as bars of passed, failed and skipped '
        'tasks, the worst first, with a threshold held across.',
    group: GalleryGroup.models,
    doc: 'eval-breakdown-chart.md',
    variants: [
      GalleryVariant(
        title: 'Pass rate by category',
        figure: 'threshold 80%',
        figureColor: galleryAmber,
        height: 380,
        build: () => EvalBreakdownChart(
          categories: galleryEval(),
          threshold: 0.8,
          passedColor: galleryGreen,
          failedColor: galleryRed,
          skippedColor: const Color(0xFF6B7480),
          thresholdColor: galleryAmber,
          labelStyle: const TextStyle(color: Color(0xFFD0D5DB), fontSize: 12),
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'token-heatmap',
    title: 'Token heatmap',
    blurb:
        'A completion with each token shaded by how surprised the model was '
        'by it — the doubtful ones ringed and numbered, what it weighed '
        'instead on touch.',
    group: GalleryGroup.models,
    doc: 'token-heatmap.md',
    variants: [
      GalleryVariant(
        title: 'Surprisal per token',
        figure: 'top 3 ringed',
        height: 300,
        build: () => TokenHeatmap(
          tokens: galleryTokens(),
          showSummary: true,
          showStrip: true,
          highlightTop: 3,
          textStyle: const TextStyle(fontSize: 15),
          legendStyle: _axisStyle,
        ),
      ),
      GalleryVariant(
        title: 'Only the doubtful',
        figure: 'above 2 nats',
        height: 300,
        build: () => TokenHeatmap(
          tokens: galleryTokens(),
          focusAbove: 2,
          showWhitespace: true,
          showStrip: true,
          textStyle: const TextStyle(fontSize: 15),
          legendStyle: _axisStyle,
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'progress',
    title: 'Progress bars',
    blurb:
        'How far each goal has got, as pills, blocks or cells, with a mark '
        'for where it should be by now.',
    group: GalleryGroup.progress,
    doc: 'progress-bars.md',
    variants: [
      GalleryVariant(
        title: 'Goals this month',
        figure: '3 of 4',
        figureColor: galleryGreen,
        height: 300,
        build: () => const ProgressBars(
          items: [
            ProgressItem(
              label: 'Net profit',
              value: 72,
              target: 60,
              color: galleryGreen,
            ),
            ProgressItem(
              label: 'Trades taken',
              value: 64,
              target: 50,
              color: galleryBlue,
            ),
            ProgressItem(
              label: 'Journal entries',
              value: 88,
              target: 75,
              color: galleryPurple,
            ),
            ProgressItem(
              label: 'Risk reviews',
              value: 35,
              target: 60,
              color: galleryAmber,
            ),
          ],
          barHeight: 14,
          rowGap: 34,
          labelStyle: TextStyle(color: Color(0xFFD0D5DB), fontSize: 13),
          valueStyle: TextStyle(
            color: Color(0xFFE9ECEF),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
        ),
      ),
      GalleryVariant(
        title: 'In cells',
        figure: '7 of 10',
        height: 300,
        build: () => const ProgressBars(
          shape: ProgressShape.segmented,
          items: [
            ProgressItem(
              label: 'Backtest coverage',
              value: 70,
              valueLabel: '7 / 10',
              color: galleryBlue,
            ),
            ProgressItem(
              label: 'Walk-forward windows',
              value: 40,
              valueLabel: '4 / 10',
              color: galleryTeal,
            ),
            ProgressItem(
              label: 'Paper-trading days',
              value: 95,
              valueLabel: '19 / 20',
              color: galleryGreen,
            ),
          ],
          segments: 10,
          barHeight: 16,
          rowGap: 48,
          labelStyle: TextStyle(color: Color(0xFFD0D5DB), fontSize: 13),
          valueStyle: TextStyle(
            color: Color(0xFFE9ECEF),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
        ),
      ),
      GalleryVariant(
        title: 'Budgets used',
        figure: '1 over',
        figureColor: galleryRed,
        height: 300,
        build: () => const ProgressBars(
          shape: ProgressShape.block,
          items: [
            ProgressItem(
              label: 'Daily loss limit',
              value: 41,
              color: galleryGreen,
            ),
            ProgressItem(label: 'Margin used', value: 78, color: galleryAmber),
            ProgressItem(label: 'Order rate', value: 100, color: galleryRed),
            ProgressItem(label: 'API quota', value: 22, color: galleryBlue),
          ],
          barHeight: 14,
          rowGap: 34,
          labelStyle: TextStyle(color: Color(0xFFD0D5DB), fontSize: 13),
          valueStyle: TextStyle(
            color: Color(0xFFE9ECEF),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
        ),
      ),
    ],
  ),
  GalleryEntry(
    id: 'progress-card',
    title: 'Progress card',
    blurb:
        'A card around any widget whose whole background is the progress — '
        'swept round like a clock, grown as a circle, or filled along the '
        'card.',
    group: GalleryGroup.progress,
    doc: 'progress-bars.md',
    variants: [
      GalleryVariant(
        title: 'Sweep, like a clock',
        figure: 'sweep',
        height: 300,
        build: () => const _CourseCards(mode: ProgressCardMode.sweep),
      ),
      GalleryVariant(
        title: 'A growing circle',
        figure: 'circle',
        height: 300,
        build: () => const _CourseCards(mode: ProgressCardMode.circle),
      ),
      GalleryVariant(
        title: 'Along the card',
        figure: 'linear',
        height: 300,
        build: () => const _CourseCards(mode: ProgressCardMode.linear),
      ),
    ],
  ),
];

/// Two courses as cards, one just begun and one nearly done, filled in as
/// [mode] says.
class _CourseCards extends StatelessWidget {
  const _CourseCards({required this.mode});

  final ProgressCardMode mode;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CourseCard(title: 'Chart patterns', lessons: 3, of: 20, mode: mode),
        const SizedBox(height: 14),
        _CourseCard(
          title: 'Order flow',
          lessons: 9,
          of: 12,
          color: galleryGreen,
          mode: mode,
        ),
      ],
    );
  }
}

/// A course as a card: its name, how many lessons are done and the share.
class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.title,
    required this.lessons,
    required this.of,
    required this.mode,
    this.color = galleryBlue,
  });

  final String title;
  final int lessons;
  final int of;
  final ProgressCardMode mode;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = lessons / of;
    return ProgressCard(
      progress: progress,
      mode: mode,
      color: color,
      semanticLabel: '$title, $lessons of $of lessons',
      child: SizedBox(
        height: 76,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFF1F3F5),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(
                    color: Color(0xFFF1F3F5),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Text(
              '$lessons of $of lessons',
              style: const TextStyle(color: Color(0xFFD0D5DB), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
