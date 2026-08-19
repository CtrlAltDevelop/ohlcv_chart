import 'package:flutter/material.dart';

import 'src/chart_page.dart';
import 'src/demo_state.dart';
import 'src/depth_page.dart';

void main() => runApp(const ExampleApp());

/// A tour of everything `ohlcv_chart` can draw.
class ExampleApp extends StatefulWidget {
  /// Creates the demo app.
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  final DemoState _state = DemoState();

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _state,
      builder: (context, _) => MaterialApp(
        title: 'ohlcv_chart',
        debugShowCheckedModeBanner: false,
        // The chart is painted from ChartColors, not the Material theme, so the
        // two are switched together here.
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF4DABF7),
          brightness: _state.dark ? Brightness.dark : Brightness.light,
          scaffoldBackgroundColor: _state.dark
              ? const Color(0xFF0B0E13)
              : const Color(0xFFF7F8FA),
        ),
        home: _Home(state: _state),
      ),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home({required this.state});

  final DemoState state;

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ohlcv_chart'),
        actions: [
          IconButton(
            tooltip: widget.state.dark ? 'Light palette' : 'Dark palette',
            icon: Icon(
              widget.state.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            onPressed: () => widget.state.update(
              () => widget.state.dark = !widget.state.dark,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.candlestick_chart_outlined), text: 'Candles'),
            Tab(icon: Icon(Icons.area_chart_outlined), text: 'Depth'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          ChartPage(state: widget.state),
          DepthPage(state: widget.state),
        ],
      ),
    );
  }
}
