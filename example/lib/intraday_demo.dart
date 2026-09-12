// A chart with no gestures: one session, drawn as an area, sitting still.
//
// The kind of chart a stock app puts at the top of a symbol's page -- it shows
// today and nothing else, so there is nothing to scroll to and nothing to zoom
// into. An entry point of its own rather than a tab, since the point is a chart
// with no controls around it:
//
//   cd example
//   flutter run -t lib/intraday_demo.dart
//
// The two switches are there to show the difference; a real one would just set
// `scrollEnabled: false` and `zoomEnabled: false` and leave them.
import 'package:flutter/material.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

import 'src/market_data.dart';

void main() => runApp(const IntradayDemo());

class IntradayDemo extends StatefulWidget {
  const IntradayDemo({super.key});

  @override
  State<IntradayDemo> createState() => _IntradayDemoState();
}

class _IntradayDemoState extends State<IntradayDemo> {
  /// One session: 78 five-minute candles.
  late final List<KLineEntity> _session = () {
    final data = MarketData.candles(count: 78);
    DataUtil.calculate(data);
    return data;
  }();

  bool _static = true;
  bool _fitWidth = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        appBar: AppBar(title: const Text('Intraday — static area chart')),
        body: Column(
          children: [
            SwitchListTile(
              title: const Text('Static (no scroll, no zoom)'),
              subtitle: Text(
                _static
                    ? 'Try dragging and pinching — nothing should move'
                    : 'Now it drags and pinches like a normal chart',
              ),
              value: _static,
              onChanged: (v) => setState(() => _static = v),
            ),
            SwitchListTile(
              title: const Text('Fit the whole session to the width'),
              subtitle: Text(
                _fitWidth
                    ? 'ChartStyle.fitContent: all 78 candles, evenly spread'
                    : 'Default spacing: only part of the session fits',
              ),
              value: _fitWidth,
              onChanged: (v) => setState(() => _fitWidth = v),
            ),
            const Divider(height: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: KChartWidget(
                  _session,
                  ChartColors(),
                  isTrendLine: false,
                  watermarkAssetPath: 'assets/none.svg',
                  timeFrame: const Duration(minutes: 5),
                  chartType: ChartType.area,

                  // What makes it sit still.
                  scrollEnabled: !_static,
                  zoomEnabled: !_static,

                  // The whole point: each candle takes an equal share of the
                  // width, so the session fills the box exactly. The chart
                  // works the spacing out from its own width, so nothing here
                  // has to know how wide it ended up.
                  chartStyle: ChartStyle(fitContent: _fitWidth),
                  xFrontPadding: 0,

                  // Everything else a plain intraday figure does not want.
                  volHidden: true,
                  hideGrid: true,
                  showNowPrice: false,
                  showInfoDialog: false,
                  crosshairOnHover: false,
                  showContextMenu: false,
                  showScrollToNowButton: false,
                  priceScaleDrag: false,
                  // A page that never scrolls has nothing to page in.
                  onLoadMore: (isRight) => debugPrint(
                    'onLoadMore($isRight) — should never print while static',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
