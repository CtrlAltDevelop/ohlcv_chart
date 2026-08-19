// Renders the screenshots used by the README and the pub.dev listing.
//
// Run it against the desktop target, from the example directory:
//
// ```sh
// flutter run -d macos -t tool/screenshots.dart
// ```
//
// Each scene is laid out at a fixed size, captured straight off the raster
// boundary and written into `../screenshots/`, then the app exits. Rendering
// the real widgets in a real engine is what keeps the images honest — text,
// anti-aliasing and all — rather than a headless golden, which draws every
// glyph as a box.
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart_example/src/chart_theme.dart';
import 'package:ohlcv_chart_example/src/indicator_sheet.dart';
import 'package:ohlcv_chart_example/src/market_data.dart';

/// Where the images are written.
///
/// A macOS app runs from its bundle, not from the directory it was launched in,
/// so the path has to be an absolute one handed in at build time:
///
/// ```sh
/// flutter run -d macos -t tool/screenshots.dart \
///     --dart-define=out=/absolute/path/to/screenshots
/// ```
const String requestedDirectory = String.fromEnvironment('out');

/// The directory actually written to.
///
/// The macOS app is sandboxed, so a path anywhere else on disk is refused; it
/// falls back to its own container and prints where that is, ready to copy out.
Directory resolveOutputDirectory() {
  if (requestedDirectory.isNotEmpty) {
    final requested = Directory(requestedDirectory);
    try {
      requested.createSync(recursive: true);
      return requested;
    } on FileSystemException {
      stdout.writeln('$requestedDirectory is out of reach — sandboxed?');
    }
  }
  final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
  return Directory('$home/Documents/ohlcv_chart_screenshots')
    ..createSync(recursive: true);
}

/// One image to render: its file name, the size it is laid out at, what goes
/// in it, and optionally how to work it before the shutter.
///
/// [act] receives the scene's rectangle in global coordinates and the shutter
/// itself, so a scene that has to be held — a long-press readout — can capture
/// mid-gesture and let go afterwards.
typedef Scene = ({
  String name,
  Size size,
  Widget Function() build,
  Future<void> Function(Rect area, Future<void> Function() shoot)? act,
});

/// The next pointer id, so each synthetic gesture is its own.
int _pointer = 1;

/// Presses at [at], runs [during], and lets go.
Future<void> hold(
  Offset at,
  Future<void> Function() during, {
  Duration settle = const Duration(milliseconds: 800),
}) async {
  final pointer = _pointer++;
  final binding = GestureBinding.instance;
  binding.handlePointerEvent(PointerDownEvent(pointer: pointer, position: at));
  // Long presses need half a second; give the readout a little longer to
  // lay itself out.
  await Future<void>.delayed(settle);
  await during();
  binding.handlePointerEvent(PointerUpEvent(pointer: pointer, position: at));
  await Future<void>.delayed(const Duration(milliseconds: 200));
}

/// Taps at [at], the way a finger selecting something would.
Future<void> tap(Offset at) async {
  final pointer = _pointer++;
  final binding = GestureBinding.instance;
  binding.handlePointerEvent(PointerDownEvent(pointer: pointer, position: at));
  await Future<void>.delayed(const Duration(milliseconds: 60));
  binding.handlePointerEvent(PointerUpEvent(pointer: pointer, position: at));
  await Future<void>.delayed(const Duration(milliseconds: 400));
}

void main() {
  runApp(const ScreenshotApp());
}

/// Runs every scene in turn, capturing each one once it has settled.
class ScreenshotApp extends StatefulWidget {
  /// Creates the runner.
  const ScreenshotApp({super.key});

  @override
  State<ScreenshotApp> createState() => _ScreenshotAppState();
}

class _ScreenshotAppState extends State<ScreenshotApp> {
  final GlobalKey _boundary = GlobalKey();
  late final List<Scene> _scenes = buildScenes();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  late final Directory _output = resolveOutputDirectory();

  Future<void> _run() async {
    stdout.writeln('writing ${_scenes.length} scenes to ${_output.path}');

    for (var i = 0; i < _scenes.length; i++) {
      setState(() => _index = i);
      // The chart loads its watermark and lays itself out asynchronously, so
      // give each scene a moment before the shutter.
      await Future<void>.delayed(const Duration(milliseconds: 900));

      final scene = _scenes[i];
      final act = scene.act;
      if (act == null) {
        await _capture(scene);
      } else {
        await act(_area, () => _capture(scene));
      }
    }
    exit(0);
  }

  /// Where the scene sits on screen, so a synthetic gesture can find it.
  Rect get _area {
    final boundary =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    return boundary.localToGlobal(Offset.zero) & boundary.size;
  }

  Future<void> _capture(Scene scene) async {
    final boundary =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    final file = File('${_output.path}/${scene.name}.png');
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    stdout.writeln(
      'wrote ${file.path} '
      '(${scene.size.width.round()}x${scene.size.height.round()} at 2x, '
      '${(file.lengthSync() / 1024).round()} KiB)',
    );
  }

  @override
  Widget build(BuildContext context) {
    final scene = _scenes[_index];
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ColoredBox(
        color: const Color(0xFF10141A),
        child: Center(
          child: RepaintBoundary(
            key: _boundary,
            child: SizedBox.fromSize(
              size: scene.size,
              child: MediaQuery(
                data: MediaQueryData(size: scene.size),
                child: Material(
                  type: MaterialType.transparency,
                  child: scene.build(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A wide scene, for the README.
const Size wide = Size(1180, 660);

/// A phone-shaped scene, for the settings sheet.
const Size portrait = Size(392, 700);

List<Scene> buildScenes() {
  final candles = MarketData.candles(count: 220);
  final last = candles.last.close;

  Widget chart({
    required List<Indicator> indicators,
    bool volHidden = false,
    List<SignalEntity> signals = const [],
    List<TrendLine> trendLines = const [],
    List<HorizontalLine> horizontalLines = const [],
    List<VerticalLine> verticalLines = const [],
    bool light = false,
    VerticalTextAlignment axis = VerticalTextAlignment.left,
  }) {
    final colors = light ? ChartTheme.lightColors() : ChartTheme.darkColors();
    return ColoredBox(
      color: colors.bgColor,
      child: KChartWidget(
        candles,
        colors,
        chartStyle: ChartTheme.filled,
        isTrendLine: trendLines.isNotEmpty || horizontalLines.isNotEmpty,
        watermarkAssetPath: 'assets/watermark.svg',
        timeFrame: MarketData.timeFrame,
        timeFormat: TimeFormat.YEAR_MONTH_DAY_WITH_HOUR,
        indicators: indicators,
        signals: signals,
        trendLines: trendLines,
        horizontalLines: horizontalLines,
        verticalLines: verticalLines,
        volHidden: volHidden,
        verticalTextAlignment: axis,
        fixedLength: 0,
        showNowPrice: true,
      ),
    );
  }

  /// A plausible order book either side of [mid].
  (List<DepthEntity>, List<DepthEntity>) book(double mid) {
    final random = Random(7);
    final rungs = [
      for (var i = 1; i <= 40; i++)
        (
          bid: DepthEntity(mid * (1 - i * 0.0015), 1 + random.nextDouble() * 6),
          ask: DepthEntity(mid * (1 + i * 0.0015), 1 + random.nextDouble() * 6),
        ),
    ];
    return (
      DepthEntity.bids([for (final rung in rungs) rung.bid]),
      DepthEntity.asks([for (final rung in rungs) rung.ask]),
    );
  }

  return [
    (
      name: 'candles',
      size: wide,
      act: null,
      build: () => chart(
        indicators: [
          MaIndicator(period: 5),
          MaIndicator(period: 10),
          MaIndicator(period: 20),
          MacdIndicator(),
        ],
        signals: [
          SignalEntity(
            title: 'TP',
            price: last * 1.05,
            color: const Color(0xFF26A69A),
          ),
          SignalEntity(
            title: 'SL',
            price: last * 0.96,
            color: const Color(0xFFEF5350),
            useDash: true,
          ),
        ],
      ),
    ),
    (
      name: 'overlays',
      size: wide,
      act: null,
      build: () => chart(
        volHidden: true,
        indicators: [
          IchimokuIndicator(),
          SupertrendIndicator(),
          StochRsiIndicator(),
          AwesomeIndicator(),
        ],
      ),
    ),
    (
      name: 'swings',
      size: wide,
      act: null,
      build: () => chart(
        volHidden: true,
        indicators: [
          ZigZagIndicator(),
          FibonacciIndicator(),
          ElliottWaveIndicator(),
          RsiIndicator(),
        ],
      ),
    ),
    (
      name: 'panes',
      size: wide,
      act: null,
      build: () => chart(
        light: true,
        volHidden: true,
        indicators: [
          BollIndicator(),
          AtrIndicator(period: 8),
          AtrIndicator(period: 14),
          AtrIndicator(period: 20),
        ],
      ),
    ),
    (
      name: 'drawing',
      size: wide,
      act: null,
      build: () => chart(
        volHidden: true,
        // The drawn lines label themselves on the left, so the price axis
        // moves over to the right rather than fighting them for the space.
        axis: VerticalTextAlignment.right,
        indicators: [EmaIndicator(period: 21)],
        horizontalLines: [
          HorizontalLine(
            price: last * 1.008,
            title: 'resistance',
            color: const Color(0xFFEF5350),
            style: LineStyle.dashed,
            showLabel: true,
          ),
          HorizontalLine(
            price: last * 0.975,
            title: 'entry',
            color: const Color(0xFF4DABF7),
            showLabel: true,
          ),
        ],
        trendLines: [
          TrendLine(
            time1: candles[candles.length - 90].dateTime!,
            price1: candles[candles.length - 90].low,
            time2: candles[candles.length - 20].dateTime!,
            price2: candles[candles.length - 20].high,
            color: const Color(0xFFF5C26B),
            label2: 'trend',
            showLabel: true,
          ),
        ],
      ),
    ),
    (
      name: 'readout',
      size: wide,
      // Hold the chart still while the shutter goes: the readout only exists
      // while a finger is down.
      act: (area, shoot) => hold(area.center, shoot),
      build: () => chart(
        indicators: [
          MaIndicator(period: 5),
          MaIndicator(period: 10),
          MaIndicator(period: 20),
          MacdIndicator(),
        ],
      ),
    ),
    (
      name: 'line-editor',
      size: wide,
      // Tapping a drawn line selects it, which is what opens the editor.
      act: (area, shoot) async {
        // The resistance line sits just under the top of the price scale;
        // tapping it is what opens the editor.
        await tap(Offset(area.left + area.width * 0.45, area.top + 66));
        await shoot();
      },
      build: () => chart(
        volHidden: true,
        axis: VerticalTextAlignment.right,
        indicators: [EmaIndicator(period: 21)],
        horizontalLines: [
          HorizontalLine(
            price: last * 1.008,
            title: 'resistance',
            color: const Color(0xFFEF5350),
            style: LineStyle.dashed,
            showLabel: true,
          ),
        ],
      ),
    ),
    (
      name: 'depth-modes',
      size: wide,
      act: null,
      build: () {
        final (bids, asks) = book(last);
        return ColoredBox(
          color: ChartTheme.darkColors().bgColor,
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 14, 6),
                  child: DepthChart(
                    bids,
                    asks,
                    chartColors: ChartTheme.darkDepth,
                    quoteUnit: 0,
                    mode: DepthChartMode.combined,
                    zoom: 0.03,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: DepthChart(
                    bids,
                    asks,
                    chartColors: ChartTheme.darkDepth,
                    quoteUnit: 2,
                    baseUnit: 2,
                    mode: DepthChartMode.ladder,
                    ladderLevels: 8,
                    chartStyle: const DepthChartStyle(
                      ladderRowHeight: 26,
                      ladderFontSize: 12,
                      padding: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
    (
      name: 'depth',
      size: wide,
      act: null,
      build: () {
        final (bids, asks) = book(last);
        return ColoredBox(
          color: ChartTheme.darkColors().bgColor,
          child: Padding(
            // The depth chart sets its labels flush with its own edges, so the
            // shot gives it a margin to breathe in.
            padding: const EdgeInsets.fromLTRB(12, 14, 14, 6),
            child: DepthChart(
              bids,
              asks,
              chartColors: ChartTheme.darkDepth,
              quoteUnit: 0,
            ),
          ),
        );
      },
    ),
    (
      name: 'indicator-settings',
      size: portrait,
      act: null,
      build: () => Theme(
        data: ThemeData.dark(useMaterial3: true),
        child: Scaffold(
          backgroundColor: const Color(0xFF10141A),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: IndicatorSheet(theme: ChartTheme.darkColors()),
            ),
          ),
        ),
      ),
    ),
  ];
}
