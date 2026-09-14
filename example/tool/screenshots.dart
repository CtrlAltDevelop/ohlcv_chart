// Renders the screenshots used by the README and the pub.dev listing.
//
// Run it against the desktop target, from the example directory:
//
// ```sh
// flutter run -d macos -t tool/screenshots.dart
// ```
//
// `--dart-define=only=depth-ratio,depth` shoots just those scenes, for a run
// that is adding one rather than redoing the set.
//
// Each scene is laid out at a fixed size, captured straight off the raster
// boundary and written into `../screenshots/`, then the app exits. A film is
// the same thing sampled over and over and written out as one looping GIF —
// `buildFilms` holds those, and `--dart-define=only=` names them alongside the
// stills. Rendering
// the real widgets in a real engine is what keeps the images honest — text,
// anti-aliasing and all — rather than a headless golden, which draws every
// glyph as a box.
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as gif;
import 'package:ohlcv_chart/ohlcv_chart.dart';
import 'package:ohlcv_chart_example/src/chart_theme.dart';
import 'package:ohlcv_chart_example/src/indicator_sheet.dart';
import 'package:ohlcv_chart_example/src/market_data.dart';

/// The scenes to shoot, comma-separated, or every one of them when left unset.
///
/// A run that adds one image should not rewrite the other thirty:
///
/// ```sh
/// flutter run -d macos -t tool/screenshots.dart --dart-define=only=depth-ratio
/// ```
const String requestedScenes = String.fromEnvironment('only');

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
      // Creating a directory that already exists succeeds even when writing
      // into it is refused, so the probe has to be an actual write.
      File('${requested.path}/.probe')
        ..writeAsStringSync('')
        ..deleteSync();
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

/// One animation to record: the same as a [Scene], but [roll] is handed a
/// shutter it is expected to call many times, and the frames are written out
/// as a single looping GIF rather than a still.
///
/// Recorded at 1x rather than the stills' 2x: a GIF carries a 256-colour
/// palette and every frame whole, so the file grows with the pixels far faster
/// than a PNG does.
typedef Film = ({
  String name,
  Size size,
  int fps,
  Widget Function() build,
  Future<void> Function(Future<void> Function() frame) roll,
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

/// Moves the mouse to [at] and leaves it there.
///
/// The crosshair follows a hover without waiting for a press, so a scene that
/// wants it up — and the OHLC legend that reads from it — hovers rather than
/// holds, which would open the readout card instead.
Future<void> hover(Offset at) async {
  final pointer = _pointer++;
  GestureBinding.instance.handlePointerEvent(
    PointerHoverEvent(
      pointer: pointer,
      kind: PointerDeviceKind.mouse,
      position: at,
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 400));
}

/// The replay transport, as an app would build one: the buttons and the
/// position readout all come off the controller, so a still says what is being
/// looked at and the film's counter ticks along with the candles.
class ReplayBar extends StatelessWidget {
  /// Creates a transport bar over [replay].
  const ReplayBar({required this.replay, super.key});

  /// The controller the bar reads and drives.
  final ChartReplayController replay;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: replay,
        builder: (context, _) {
          final position = replay.position ?? replay.length;
          Widget button(IconData icon, {bool on = true}) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  icon,
                  size: 20,
                  color: on ? const Color(0xFFDCE3EB) : const Color(0xFF4A5361),
                ),
              );
          return ColoredBox(
            color: const Color(0xFF161B23),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  button(Icons.replay, on: true),
                  button(Icons.skip_previous, on: replay.isActive),
                  button(
                    replay.isPlaying ? Icons.pause : Icons.play_arrow,
                    on: true,
                  ),
                  button(Icons.skip_next, on: replay.isActive),
                  button(Icons.stop, on: replay.isActive),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value:
                            replay.length == 0 ? 0 : position / replay.length,
                        minHeight: 6,
                        backgroundColor: const Color(0xFF2A313C),
                        valueColor:
                            const AlwaysStoppedAnimation(Color(0xFF26A69A)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 148,
                    child: Text(
                      replay.isActive
                          ? 'Candle $position of ${replay.length}'
                          : 'Live — all ${replay.length} candles',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Color(0xFFB6C0CC),
                        fontSize: 12,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
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

  /// The names asked for, or empty when the whole set was.
  late final Set<String> _names = requestedScenes.isEmpty
      ? const {}
      : requestedScenes.split(',').map((name) => name.trim()).toSet();

  late final List<Scene> _scenes = _asked(buildScenes(), (s) => s.name);
  late final List<Film> _films = _asked(buildFilms(), (f) => f.name);

  /// The entries [requestedScenes] names, or all of them when it names none.
  List<T> _asked<T>(List<T> all, String Function(T) name) => _names.isEmpty
      ? all
      : all.where((e) => _names.contains(name(e))).toList();

  /// Where in the run we are: scenes first, then films.
  int _index = 0;

  /// What is on screen right now, whichever list it came from.
  ({Size size, Widget Function() build}) get _showing => _index < _scenes.length
      ? (size: _scenes[_index].size, build: _scenes[_index].build)
      : (
          size: _films[_index - _scenes.length].size,
          build: _films[_index - _scenes.length].build,
        );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  late final Directory _output = resolveOutputDirectory();

  Future<void> _run() async {
    if (_scenes.isEmpty && _films.isEmpty) {
      stdout.writeln('no scene goes by ${_names.join(', ')}');
      exit(1);
    }
    stdout.writeln(
      'writing ${_scenes.length} scenes and ${_films.length} films '
      'to ${_output.path}',
    );

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
    for (var i = 0; i < _films.length; i++) {
      setState(() => _index = _scenes.length + i);
      await Future<void>.delayed(const Duration(milliseconds: 900));
      await _record(_films[i]);
    }
    if (_stale.isNotEmpty) {
      stdout.writeln('stale, and not written: ${_stale.join(', ')}');
      exit(1);
    }
    exit(0);
  }

  /// The digest of the last image written, so a stale frame can be spotted.
  int _previous = 0;

  /// Scenes that never produced a frame of their own.
  final List<String> _stale = [];

  /// Cheap digest of an image, enough to tell one scene from another.
  int _digest(Uint8List bytes) {
    var hash = 17;
    for (var i = 0; i < bytes.length; i += 97) {
      hash = (hash * 31 + bytes[i]) & 0x3FFFFFFF;
    }
    return hash * 31 + bytes.length;
  }

  /// Rasterises the boundary afresh.
  ///
  /// macOS throttles a window that is not in front, and `toImage` then hands
  /// back whatever was last rasterised — which is how a run writes the same
  /// picture into every file. Marking the boundary dirty and waiting for the
  /// frame that schedules is what asks for a new one.
  Future<Uint8List> _raster(
    RenderRepaintBoundary boundary, {
    double pixelRatio = 2,
    ui.ImageByteFormat format = ui.ImageByteFormat.png,
  }) async {
    boundary.markNeedsPaint();
    WidgetsBinding.instance.scheduleFrame();
    await WidgetsBinding.instance.endOfFrame;

    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: format);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  /// Records [film] frame by frame and writes the lot out as one looping GIF.
  Future<void> _record(Film film) async {
    final boundary =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final width = film.size.width.round();
    final height = film.size.height.round();
    final frames = <gif.Image>[];

    Future<void> shoot() async {
      final raw = await _raster(
        boundary,
        pixelRatio: 1,
        format: ui.ImageByteFormat.rawRgba,
      );
      frames.add(
        gif.Image.fromBytes(
          width: width,
          height: height,
          bytes: raw.buffer,
          numChannels: 4,
          frameDuration: (1000 / film.fps).round(),
        ),
      );
    }

    await film.roll(shoot);
    if (frames.isEmpty) {
      stdout.writeln('${film.name} rolled no frames — left alone');
      _stale.add(film.name);
      return;
    }

    final reel = frames.first;
    for (final frame in frames.skip(1)) {
      reel.addFrame(frame);
    }
    // A chart is mostly flat background and a handful of hues, so a coarse
    // sampling factor costs it nothing and keeps the file down.
    final bytes = gif.encodeGif(reel, repeat: 0, samplingFactor: 20);

    final file = File('${_output.path}/${film.name}.gif');
    file.writeAsBytesSync(bytes);
    stdout.writeln(
      'wrote ${file.path} '
      '(${frames.length} frames at ${width}x$height, '
      '${(file.lengthSync() / 1024).round()} KiB)',
    );
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

    // A frame identical to the one before it is the last scene over again, not
    // this one: ask for another, and give up loudly rather than write it.
    var bytes = await _raster(boundary);
    for (var attempt = 0;
        _digest(bytes) == _previous && attempt < 4;
        attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      bytes = await _raster(boundary);
    }
    if (_digest(bytes) == _previous) {
      stdout.writeln('${scene.name} came back stale — left alone');
      _stale.add(scene.name);
      return;
    }
    _previous = _digest(bytes);

    final file = File('${_output.path}/${scene.name}.png');
    file.writeAsBytesSync(bytes);
    stdout.writeln(
      'wrote ${file.path} '
      '(${scene.size.width.round()}x${scene.size.height.round()} at 2x, '
      '${(file.lengthSync() / 1024).round()} KiB)',
    );
  }

  @override
  Widget build(BuildContext context) {
    final showing = _showing;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ColoredBox(
        color: const Color(0xFF10141A),
        child: Center(
          child: RepaintBoundary(
            key: _boundary,
            child: SizedBox.fromSize(
              size: showing.size,
              child: MediaQuery(
                data: MediaQueryData(size: showing.size),
                child: Material(
                  type: MaterialType.transparency,
                  child: showing.build(),
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

/// A single row of panels, for the charts that do not need the height.
const Size shortWide = Size(1180, 400);

/// A phone-shaped scene, for the settings sheet.
const Size portrait = Size(392, 700);

List<Scene> buildScenes() {
  final candles = MarketData.candles(count: 220);
  final last = candles.last.close;

  /// A longer run, for the scenes that need several sessions to show anything.
  ///
  /// 15-minute candles, so 420 of them is a bit over four days: enough for a
  /// session VWAP to reset a few times and a four-hour average to step.
  final longRun = MarketData.candles(count: 420);

  // One controller per chart, made once rather than per build, so the strip and
  // the linked charts are talking to the same chart across every frame the
  // shutter waits through.
  final overviewChart = KChartController();
  // Held at one candle for the still; the moving version is its own film.
  final replay = ChartReplayController();
  final linkedTop = KChartController();
  final linkedBottom = KChartController();
  // The same market shown twice, so the price axis and the crosshair's height
  // are worth carrying as well as the window.
  ChartLink.all()
    ..add(linkedTop)
    ..add(linkedBottom);

  Widget chart({
    required List<Indicator> indicators,
    bool volHidden = false,
    List<SignalEntity> signals = const [],
    List<TrendLine> trendLines = const [],
    List<HorizontalLine> horizontalLines = const [],
    List<VerticalLine> verticalLines = const [],
    List<RectangleDrawing> rectangles = const [],
    List<FibRetracement> fibRetracements = const [],
    List<ChartLine> drawings = const [],
    List<KLineEntity>? data,
    ChartType? chartType,
    PriceAxisScale priceAxisScale = PriceAxisScale.linear,
    bool showOhlcLegend = false,
    bool sessionDividers = false,
    bool light = false,
    VerticalTextAlignment axis = VerticalTextAlignment.left,
    List<ComparisonSeries> comparisons = const [],
    List<ChartEvent> events = const [],
    List<ChartOrder> orders = const [],
    List<ChartPosition> positions = const [],
    TradingSession? session,
    Color? Function(CandleEntity candle, int index)? candleColor,
    bool invertPriceAxis = false,
    bool showAverageClose = false,
    bool showHighLowOnAxis = false,
    Color? extendedHoursColor,
    KChartController? controller,
    bool showInfoDialog = true,
    ChartReplayController? replay,
    double? mBaseHeight,
    String Function(KLineEntity candle, bool longForm)? dateFormatter,
    double xFrontPadding = 80,
  }) {
    final colors = light ? ChartTheme.lightColors() : ChartTheme.darkColors();
    // The default wash is 7% of the text colour — right on a chart being read,
    // too faint to survive a screenshot.
    if (extendedHoursColor != null) {
      colors.extendedHoursColor = extendedHoursColor;
    }
    return ColoredBox(
      color: colors.bgColor,
      child: KChartWidget(
        data ?? candles,
        colors,
        chartStyle: ChartTheme.filled.copyWith(
          showSessionDividers: sessionDividers,
        ),
        chartType: chartType,
        priceAxisScale: priceAxisScale,
        showOhlcLegend: showOhlcLegend,
        controller: controller,
        showInfoDialog: showInfoDialog,
        showScrollToNowButton: false,
        drawings: drawings,
        isTrendLine: trendLines.isNotEmpty ||
            horizontalLines.isNotEmpty ||
            rectangles.isNotEmpty ||
            fibRetracements.isNotEmpty ||
            drawings.isNotEmpty,
        watermark: const FittedBox(
          child: Text('OHLCV', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
        timeFrame: MarketData.timeFrame,
        timeFormat: TimeFormat.YEAR_MONTH_DAY_WITH_HOUR,
        indicators: indicators,
        signals: signals,
        trendLines: trendLines,
        horizontalLines: horizontalLines,
        verticalLines: verticalLines,
        rectangles: rectangles,
        fibRetracements: fibRetracements,
        volHidden: volHidden,
        verticalTextAlignment: axis,
        comparisons: comparisons,
        events: events,
        orders: orders,
        positions: positions,
        session: session,
        candleColor: candleColor,
        invertPriceAxis: invertPriceAxis,
        showAverageClose: showAverageClose,
        showHighLowOnAxis: showHighLowOnAxis,
        replay: replay,
        mBaseHeight: mBaseHeight,
        dateFormatter: dateFormatter,
        xFrontPadding: xFrontPadding,
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

  /// Names a panel in a scene that holds several of them side by side.
  ///
  /// [centred] moves the name off the top-left corner, for a panel whose chart
  /// already draws a legend or an extreme's label there.
  Widget titled(
    String text,
    Widget child, {
    bool centred = false,
    double top = 8,
  }) =>
      Stack(
        children: [
          Positioned.fill(child: child),
          Positioned(
            left: centred ? 0 : 10,
            right: centred ? 0 : null,
            top: top,
            // On a chip, because the chart draws its own labels in the same corner.
            child: Align(
              alignment: centred ? Alignment.topCenter : Alignment.topLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF10141A).withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: Color(0xFFB6C0CC),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );

  /// The chart with the overview strip beneath it.
  Widget overviewScene() {
    final colors = ChartTheme.darkColors();
    return ColoredBox(
      color: colors.bgColor,
      child: Column(
        children: [
          Expanded(
            child: chart(
              volHidden: true,
              data: longRun,
              controller: overviewChart,
              indicators: [MaIndicator(period: 20), MacdIndicator()],
            ),
          ),
          ChartOverview(
            longRun,
            controller: overviewChart,
            colors: colors,
            height: 68,
          ),
        ],
      ),
    );
  }

  /// The same market twice, on one link.
  Widget linkedScene() {
    final colors = ChartTheme.darkColors();
    return ColoredBox(
      color: colors.bgColor,
      child: Column(
        children: [
          Expanded(
            flex: 3,
            child: chart(
              volHidden: true,
              data: longRun,
              controller: linkedTop,
              showOhlcLegend: true,
              // The popup would sit over the legend, and the crosshair is
              // what this picture is about.
              showInfoDialog: false,
              indicators: [MaIndicator(period: 20), BollIndicator()],
            ),
          ),
          const SizedBox(height: 1),
          Expanded(
            flex: 2,
            child: chart(
              volHidden: true,
              data: longRun,
              controller: linkedBottom,
              showInfoDialog: false,
              // One pane, so the candles below still have room to be candles.
              indicators: [RsiIndicator(period: 14)],
            ),
          ),
        ],
      ),
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
      // A four-hour average over fifteen-minute candles: it steps once a bar
      // and holds flat between, which is the whole point of the thing.
      name: 'higher-timeframe',
      size: wide,
      act: null,
      build: () => chart(
            volHidden: true,
            data: longRun,
            indicators: [
              // Both cover about twenty hours, so they sit in the same stretch of
              // price and the only difference on show is the stepping. A 4h MA20
              // would reach back eighty hours and drag the whole axis down with it.
              MaIndicator(period: 80),
              TimeframeIndicator(
                timeframe: const Duration(hours: 4),
                applied: MaIndicator(period: 5),
                // A colour of its own, so the stepped line and the smooth one are
                // told apart at a glance rather than by their shape.
                colors: const [Color(0xFF4DABF7)],
              ),
              TimeframeIndicator(
                timeframe: const Duration(hours: 4),
                applied: RsiIndicator(period: 14),
              ),
            ],
          ),
    ),
    (
      name: 'session-vwap',
      size: wide,
      act: null,
      build: () => chart(
            volHidden: true,
            data: longRun,
            sessionDividers: true,
            indicators: [
              // One deviation rather than two: the band still says where the
              // session has been trading without stretching the axis to fit it.
              SessionVwapIndicator(),
              AroonIndicator(period: 14),
            ],
          ),
    ),
    (
      name: 'overview',
      size: wide,
      // Parked mid-history, so both handles of the window are in the picture
      // rather than the right-hand one sitting off the end of the strip.
      act: (area, shoot) async {
        overviewChart.showRange(150, 300);
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await shoot();
      },
      build: () => overviewScene(),
    ),
    (
      // Held on the upper chart, so the crosshair the link carries down to the
      // lower one is in the picture.
      name: 'linked-charts',
      size: wide,
      act: (area, shoot) => hold(
            Offset(
                area.left + area.width * 0.62, area.top + area.height * 0.24),
            shoot,
          ),
      build: () => linkedScene(),
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
      name: 'shapes',
      size: wide,
      act: null,
      build: () => chart(
            volHidden: true,
            axis: VerticalTextAlignment.right,
            indicators: [],
            horizontalLines: [
              HorizontalLine(
                price: candles[candles.length - 60].high,
                startTime: candles[candles.length - 60].dateTime,
                title: 'broken',
                color: const Color(0xFFEF5350),
                style: LineStyle.dashed,
                showLabel: true,
              ),
            ],
            trendLines: [
              TrendLine(
                time1: candles[candles.length - 150].dateTime!,
                price1: candles[candles.length - 150].low,
                time2: candles[candles.length - 110].dateTime!,
                price2: candles[candles.length - 110].high,
                extend: LineExtension.right,
                color: const Color(0xFFF5C26B),
              ),
              TrendLine(
                time1: candles[candles.length - 95].dateTime!,
                price1: candles[candles.length - 95].high,
                time2: candles[candles.length - 75].dateTime!,
                price2: candles[candles.length - 75].low,
                arrow: true,
                color: const Color(0xFFB197FC),
              ),
            ],
            rectangles: [
              RectangleDrawing(
                time1: candles[candles.length - 58].dateTime!,
                // The box covers the whole range the market held over that span,
                // which is what a range box is for.
                price1: candles
                    .sublist(candles.length - 58, candles.length - 38)
                    .map((candle) => candle.high)
                    .reduce(max),
                time2: candles[candles.length - 38].dateTime!,
                price2: candles
                    .sublist(candles.length - 58, candles.length - 38)
                    .map((candle) => candle.low)
                    .reduce(min),
                label: 'range',
                showLabel: true,
              ),
            ],
            fibRetracements: [
              FibRetracement(
                time1: candles[candles.length - 30].dateTime!,
                price1: candles[candles.length - 30].low,
                time2: candles[candles.length - 12].dateTime!,
                price2: candles[candles.length - 12].high,
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
      name: 'chart-types',
      size: wide,
      act: null,
      build: () => ColoredBox(
            color: ChartTheme.darkColors().bgColor,
            child: Column(
              children: [
                for (final row in const [
                  [
                    (ChartType.bars, 'bars'),
                    (ChartType.baseline, 'baseline'),
                    (ChartType.area, 'area'),
                  ],
                  [
                    (ChartType.stepLine, 'step line'),
                    (ChartType.hlcArea, 'HLC area'),
                    (ChartType.columns, 'columns'),
                  ],
                ])
                  Expanded(
                    child: Row(
                      children: [
                        for (final (type, name) in row)
                          Expanded(
                            child: titled(
                              name,
                              chart(
                                indicators: [],
                                volHidden: true,
                                chartType: type,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
    ),
    (
      name: 'aggregations',
      size: wide,
      act: null,
      build: () {
        final ha = CandleTransforms.heikinAshi(candles);
        DataUtil.calculate(ha);
        final bricks = CandleTransforms.renko(
          candles,
          brickSize: CandleTransforms.atrBrickSize(candles)!,
        );
        DataUtil.calculate(bricks);

        return ColoredBox(
          color: ChartTheme.darkColors().bgColor,
          child: Row(
            children: [
              Expanded(
                child: chart(indicators: [], volHidden: true, data: ha),
              ),
              Expanded(
                child: chart(indicators: [], volHidden: true, data: bricks),
              ),
            ],
          ),
        );
      },
    ),
    (
      name: 'log-axis',
      size: wide,
      act: null,
      build: () => chart(
            indicators: [EmaIndicator(period: 50)],
            volHidden: true,
            priceAxisScale: PriceAxisScale.logarithmic,
            showOhlcLegend: true,
            sessionDividers: true,
          ),
    ),
    (
      name: 'planning',
      size: wide,
      act: null,
      build: () => chart(
            indicators: [],
            volHidden: true,
            axis: VerticalTextAlignment.right,
            showOhlcLegend: true,
            drawings: [
              PositionDrawing(
                time1: candles[candles.length - 60].dateTime!,
                price1: candles[candles.length - 60].close,
                time2: candles[candles.length - 8].dateTime!,
                price2: candles[candles.length - 60].close * 1.06,
                time3: candles[candles.length - 8].dateTime!,
                price3: candles[candles.length - 60].close * 0.98,
                profitColor: const Color(0xFF26A69A),
                lossColor: const Color(0xFFEF5350),
              ),
              ParallelChannel(
                time1: candles[candles.length - 150].dateTime!,
                price1: candles[candles.length - 150].low,
                time2: candles[candles.length - 70].dateTime!,
                price2: candles[candles.length - 70].low,
                time3: candles[candles.length - 110].dateTime!,
                price3: candles[candles.length - 110].high,
                color: const Color(0xFF4DABF7),
              ),
              MeasureDrawing(
                time1: candles[candles.length - 40].dateTime!,
                price1: candles[candles.length - 40].low,
                time2: candles[candles.length - 20].dateTime!,
                price2: candles[candles.length - 20].high,
              ),
              TextAnnotation(
                time: candles[candles.length - 30].dateTime!,
                price: candles[candles.length - 30].high * 1.02,
                text: 'CPI print',
                color: const Color(0xFFF5C26B),
              ),
            ],
          ),
    ),
    (
      name: 'comparison',
      size: wide,
      act: null,
      build: () => chart(
            indicators: [],
            volHidden: true,
            showOhlcLegend: true,
            axis: VerticalTextAlignment.right,
            comparisons: [MarketData.comparison(candles)],
          ),
    ),
    (
      name: 'trading',
      size: wide,
      act: null,
      build: () => chart(
            indicators: [EmaIndicator(period: 21)],
            volHidden: true,
            axis: VerticalTextAlignment.right,
            orders: [
              ChartOrder(
                id: 'working',
                price: last * 0.985,
                side: TradeSide.buy,
                quantity: 0.5,
              ),
              ChartOrder(
                id: 'target',
                price: last * 1.008,
                side: TradeSide.sell,
                quantity: 0.5,
              ),
            ],
            positions: [
              ChartPosition(
                id: 'open',
                entryPrice: candles[candles.length - 40].close,
                side: TradeSide.buy,
                quantity: 1,
                unrealisedPnl: last - candles[candles.length - 40].close,
              ),
            ],
          ),
    ),
    (
      name: 'events',
      size: wide,
      act: null,
      build: () => chart(
            indicators: [MaIndicator(period: 20)],
            showOhlcLegend: true,
            // The demo's own events are spread over the whole history, and the
            // window only holds the last half of it: these sit where they can be
            // seen, one of each kind.
            events: [
              for (final (back, kind, detail) in [
                (78, ChartEventKind.earnings, 'Q3 earnings, after the close'),
                (56, ChartEventKind.dividend, r'$0.24 goes ex'),
                (34, ChartEventKind.split, '2-for-1'),
                (12, ChartEventKind.news, 'Added to the index'),
              ])
                ChartEvent(
                  time: candles[candles.length - back].dateTime!,
                  kind: kind,
                  detail: detail,
                ),
            ],
          ),
    ),
    (
      name: 'sessions',
      size: wide,
      act: null,
      build: () => chart(
            indicators: [],
            showOhlcLegend: true,
            // Kept every day, weekend included: the demo's market never closes,
            // and a weekday-only set washes the whole picture when the data runs
            // over a Saturday.
            session: const TradingSession(
              open: Duration(hours: 9, minutes: 30),
              close: Duration(hours: 16),
              weekdays: {
                DateTime.monday,
                DateTime.tuesday,
                DateTime.wednesday,
                DateTime.thursday,
                DateTime.friday,
                DateTime.saturday,
                DateTime.sunday,
              },
            ),
            extendedHoursColor: const Color(0x2494A9C0),
            // The kind of thing a per-bar colour is for: pick out the handful of
            // bars that travelled much further than the ones around them.
            candleColor: (candle, index) =>
                candle.high - candle.low > candle.close * 0.015
                    ? const Color(0xFFFFD54F)
                    : null,
          ),
    ),
    (
      name: 'profile',
      size: wide,
      act: null,
      build: () => chart(
            volHidden: true,
            showOhlcLegend: true,
            axis: VerticalTextAlignment.right,
            indicators: [
              VolumeProfileIndicator(bins: 28),
              AnchoredVwapIndicator(anchor: candles.length - 90),
            ],
          ),
    ),
    (
      name: 'bar-types',
      size: wide,
      act: null,
      build: () {
        final box = CandleTransforms.atrBrickSize(candles)!;
        final panels = <(String, List<KLineEntity>)>[
          ('line break', CandleTransforms.lineBreak(candles)),
          ('Kagi', CandleTransforms.kagi(candles, reversal: box * 0.25)),
          (
            'point & figure',
            CandleTransforms.pointAndFigure(candles, boxSize: box * 0.4),
          ),
          ('range bars', CandleTransforms.rangeBars(candles, range: box * 0.6)),
        ];
        for (final (_, data) in panels) {
          DataUtil.calculate(data);
        }

        return ColoredBox(
          color: ChartTheme.darkColors().bgColor,
          child: Column(
            children: [
              for (final row in [panels.sublist(0, 2), panels.sublist(2)])
                Expanded(
                  child: Row(
                    children: [
                      for (final (name, data) in row)
                        Expanded(
                          child: titled(
                            name,
                            chart(indicators: [], volHidden: true, data: data),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    ),
    (
      name: 'price-scales',
      size: wide,
      act: null,
      build: () => ColoredBox(
            color: ChartTheme.darkColors().bgColor,
            child: Row(
              children: [
                Expanded(
                  child: titled(
                    'indexed to 100',
                    centred: true,
                    chart(
                      indicators: [],
                      volHidden: true,
                      axis: VerticalTextAlignment.right,
                      priceAxisScale: PriceAxisScale.indexedTo100,
                      comparisons: [MarketData.comparison(candles)],
                    ),
                  ),
                ),
                Expanded(
                  child: titled(
                    'inverted',
                    centred: true,
                    chart(
                      indicators: [],
                      volHidden: true,
                      axis: VerticalTextAlignment.right,
                      invertPriceAxis: true,
                      showAverageClose: true,
                      showHighLowOnAxis: true,
                    ),
                  ),
                ),
              ],
            ),
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
      name: 'depth-ratio',
      size: wide,
      act: null,
      build: () {
        // A book with a wall of bids under the market and the weight of the
        // asks further out, which is what makes the three readings differ.
        final random = Random(11);
        final rungs = [
          for (var i = 1; i <= 40; i++)
            (
              bid: DepthEntity(
                last * (1 - i * 0.0015),
                9 - i * 0.2 + random.nextDouble() * 1.5,
              ),
              ask: DepthEntity(
                last * (1 + i * 0.0015),
                0.6 + i * 0.28 + random.nextDouble() * 1.5,
              ),
            ),
        ];
        final bids = DepthEntity.bids([for (final rung in rungs) rung.bid]);
        final asks = DepthEntity.asks([for (final rung in rungs) rung.ask]);

        // Two readings, not three: a third panel narrows each one until the
        // price labels along the bottom run into each other.
        const panels = <(String, double?)>[
          ('the whole book', null),
          ('within 1% of the mid', 0.01),
        ];

        return ColoredBox(
          color: ChartTheme.darkColors().bgColor,
          child: Row(
            children: [
              for (final (label, zoom) in panels)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                    child: titled(
                      label,
                      DepthChart(
                        bids,
                        asks,
                        chartColors: ChartTheme.darkDepth,
                        quoteUnit: 0,
                        zoom: zoom,
                        showRatioBar: true,
                        chartStyle: const DepthChartStyle(
                          ratioBarHeight: 8,
                          ratioFontSize: 14,
                          padding: 10,
                        ),
                      ),
                      centred: true,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
    (
      // Rewound to the 150th candle of 420: the market to the right of it has
      // not happened yet, and the indicators only know what has arrived.
      name: 'bar-replay',
      size: wide,
      act: (area, shoot) async {
        replay.start(at: 150);
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await shoot();
      },
      build: () => Column(
            children: [
              Expanded(
                child: chart(
                  data: longRun,
                  replay: replay,
                  indicators: [MaIndicator(period: 20), RsiIndicator()],
                ),
              ),
              ReplayBar(replay: replay),
            ],
          ),
    ),
    (
      // Hovered rather than held: the crosshair follows a mouse without a
      // press, and the legend row reads from wherever it is.
      name: 'legend-and-crosshair',
      size: wide,
      act: (area, shoot) async {
        await hover(
          Offset(area.left + area.width * 0.58, area.top + area.height * 0.35),
        );
        await shoot();
      },
      build: () => chart(
            showOhlcLegend: true,
            indicators: [MaIndicator(period: 20), MacdIndicator()],
          ),
    ),
    (
      // The axis it picks for itself beside one taken over wholesale, on the
      // same candles, so the difference is the formatting and nothing else.
      name: 'date-axis',
      size: wide,
      act: null,
      build: () => Column(
            children: [
              Expanded(
                child: titled(
                  'the format it picks: clock times, the date where the day turns',
                  chart(
                      volHidden: true, indicators: [EmaIndicator(period: 21)]),
                  top: 30,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: titled(
                  'dateFormatter taking it over, xFrontPadding: 120',
                  chart(
                    volHidden: true,
                    indicators: [EmaIndicator(period: 21)],
                    xFrontPadding: 120,
                    dateFormatter: (candle, longForm) {
                      final at = candle.dateTime!;
                      final hour = at.hour.toString().padLeft(2, '0');
                      return longForm
                          ? 'Sep ${at.day}, ${hour}h${at.minute}'
                          : '${at.day} Sep · ${hour}h';
                    },
                  ),
                  top: 30,
                ),
              ),
            ],
          ),
    ),
    (
      // The same chart under both palettes: ChartColors is the whole
      // difference between them.
      name: 'theming',
      size: wide,
      act: null,
      build: () => Row(
            children: [
              Expanded(
                child: titled(
                  'ChartTheme.darkColors()',
                  chart(indicators: [BollIndicator(), MacdIndicator()]),
                  top: 30,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: titled(
                  'ChartTheme.lightColors()',
                  chart(
                    light: true,
                    indicators: [BollIndicator(), MacdIndicator()],
                  ),
                  top: 30,
                ),
              ),
            ],
          ),
    ),
    (
      // Left to itself the candle area takes what the panes do not want;
      // pinned, it keeps its height and the panes stack under it.
      name: 'sizing',
      size: wide,
      act: null,
      build: () => Row(
            children: [
              Expanded(
                child: titled(
                  'mBaseHeight unset — fills the box',
                  chart(indicators: [MacdIndicator()]),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: titled(
                  'mBaseHeight: 220',
                  chart(mBaseHeight: 220, indicators: [MacdIndicator()]),
                ),
              ),
            ],
          ),
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
    (
      // Four business charts at once, one of them reading out a day, so the
      // listing shows what SeriesChart is for before any code.
      name: 'series-charts',
      size: wide,
      act: (area, shoot) async {
        seriesGalleryCrosshair.show(30);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await shoot();
        seriesGalleryCrosshair.clear();
      },
      build: seriesGalleryScene,
    ),
    (
      // A window over five months of data, with the strip that moves it and a
      // day held under the crosshair.
      name: 'series-window',
      size: wide,
      act: (area, shoot) async {
        seriesWindowCrosshair.show(118);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await shoot();
        seriesWindowCrosshair.clear();
      },
      build: seriesWindowScene,
    ),
    (
      // Two panels on one controller: the crosshair in both, one tooltip.
      name: 'series-panels',
      size: wide,
      act: (area, shoot) async {
        seriesPanelsCrosshair.show(41);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await shoot();
        seriesPanelsCrosshair.clear();
      },
      build: seriesPanelsScene,
    ),
    (
      // The two shapes an axis cannot draw: a pie and a radar.
      name: 'pie-radar',
      size: shortWide,
      act: null,
      build: pieRadarScene,
    ),
    (
      // Dots placed freely on both axes, read out one at a time.
      name: 'series-scatter',
      size: shortWide,
      act: (area, shoot) async {
        seriesScatterCrosshair.show(18, seriesIndex: 0, pointIndex: 12);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await shoot();
        seriesScatterCrosshair.clear();
      },
      build: seriesScatterScene,
    ),
    (
      // A chart turned on its side, with bars stacked on each other.
      name: 'series-horizontal',
      size: shortWide,
      act: null,
      build: seriesHorizontalScene,
    ),
    (
      // Bars that float between two values, and a band between two lines.
      name: 'series-ranges',
      size: shortWide,
      act: null,
      build: seriesRangesScene,
    ),
    (name: 'watermark', size: wide, act: null, build: watermarkScene),
  ];
}

/// The animations to record. Same shape as [buildScenes], but each one is
/// handed a shutter to call repeatedly.
List<Film> buildFilms() {
  final candles = MarketData.candles(count: 420);
  final replay = ChartReplayController();

  return [
    (
      // Stepping the replay forward a candle at a time, which is the one thing
      // a still of it cannot say.
      name: 'bar-replay',
      // Smaller than a still and at 1x: a GIF carries every frame whole.
      size: const Size(680, 400),
      fps: 8,
      roll: (frame) async {
        replay.start(at: 150);
        await Future<void>.delayed(const Duration(milliseconds: 600));
        // Played rather than stepped, so the transport reads as running: the
        // timer moves the candles while the shutter samples alongside it.
        replay.play(interval: const Duration(milliseconds: 125));
        for (var i = 0; i < 30; i++) {
          await frame();
          await Future<void>.delayed(const Duration(milliseconds: 125));
        }
        replay.pause();
        await frame();
      },
      build: () {
        final colors = ChartTheme.darkColors();
        return ColoredBox(
          color: colors.bgColor,
          child: Column(
            children: [
              Expanded(
                child: KChartWidget(
                  candles,
                  colors,
                  chartStyle: ChartTheme.filled,
                  isTrendLine: false,
                  watermark: const FittedBox(
                    child: Text(
                      'OHLCV',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  timeFrame: MarketData.timeFrame,
                  timeFormat: TimeFormat.YEAR_MONTH_DAY_WITH_HOUR,
                  indicators: [MaIndicator(period: 20), RsiIndicator()],
                  replay: replay,
                  showScrollToNowButton: false,
                  showInfoDialog: false,
                  fixedLength: 0,
                  showNowPrice: true,
                ),
              ),
              ReplayBar(replay: replay),
            ],
          ),
        );
      },
    ),
  ];
}

// ── Series charts ────────────────────────────────────────────────────────────

const _seriesBackground = Color(0xFF0D1117);
const _seriesPaper = Color(0xFF161B22);
const _seriesGrid = Color(0xFF252C35);
const _seriesMuted = Color(0xFF5C6570);
const _seriesPurple = Color(0xFF9775FA);
const _seriesBlue = Color(0xFF4DABF7);
const _seriesAmber = Color(0xFFFAB005);
const _seriesGreen = Color(0xFF12B886);
const _seriesRed = Color(0xFFFA5252);
const _seriesAxis = TextStyle(color: Color(0xFF8B95A1), fontSize: 11);
const _seriesMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// The crosshairs the series scenes hold still for the shutter.
final seriesGalleryCrosshair = SeriesChartController();
final seriesWindowCrosshair = SeriesChartController();
final seriesPanelsCrosshair = SeriesChartController();
final seriesScatterCrosshair = SeriesChartController();

/// A drifting wave: no randomness, so the pictures never change between runs.
List<double> seriesWave(
  int count, {
  double base = 0,
  double swing = 1,
  double drift = 0,
  double phase = 0,
}) =>
    [
      for (var i = 0; i < count; i++)
        base +
            sin(i / 5 + phase) * swing +
            cos(i / 2.3 + phase) * swing * 0.35 +
            i * drift,
    ];

/// Day [index] of 2026, written the way a dashboard axis would.
String seriesDate(int index) {
  final day = DateTime(2026).add(Duration(days: index));
  return '${_seriesMonths[day.month - 1]} ${day.day}';
}

/// Dollars, shortened to thousands past a thousand.
String seriesUsd(double value) {
  final sign = value < 0 ? '-' : '';
  final amount = value.abs();
  final digits = amount >= 1000
      ? '${(amount / 1000).toStringAsFixed(1)}k'
      : amount.toStringAsFixed(0);
  return '$sign\$$digits';
}

/// A card with a title, a figure on the right, and a chart filling the rest.
Widget seriesPanel(
  String title,
  Widget child, {
  String? figure,
  Color figureColor = Colors.white,
}) =>
    Container(
      margin: const EdgeInsets.all(6),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: _seriesPaper,
        border: Border.all(color: _seriesGrid),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFB6C0CC),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (figure != null)
                Text(
                  figure,
                  style: TextStyle(
                    color: figureColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: child),
        ],
      ),
    );

/// The tooltip the series scenes draw: a date, then a coloured row per value.
Widget seriesCard(String title, List<(String, String, Color)> rows) =>
    DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xF21C2128),
        border: Border.all(color: _seriesGrid),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 10)],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: _seriesAxis),
            const SizedBox(height: 4),
            for (final (label, value, color) in rows)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('$label  ', style: _seriesAxis.copyWith(fontSize: 12)),
                    Text(
                      value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );

SeriesTooltip _seriesTooltip({String Function(int index)? title}) =>
    SeriesTooltip(
      builder: (context, details) =>
          seriesCard((title ?? seriesDate)(details.index), [
        for (final value in details.values)
          (value.series.label ?? '', seriesUsd(value.value), value.color),
      ]),
    );

/// Four business charts in a grid.
Widget seriesGalleryScene() {
  final roi = [
    for (final v in seriesWave(60, swing: 9, drift: 0.14, phase: 1.2)) v - 3,
  ];
  final profits = seriesWave(28, swing: 120, phase: 0.4);
  final deposits = seriesWave(45, base: 1600, swing: 380, drift: 6);
  final withdrawals = seriesWave(45, base: 900, swing: 220, drift: 3, phase: 2);
  final balance = seriesWave(
    90,
    base: 12000,
    swing: 900,
    drift: 14,
    phase: 0.8,
  );

  return ColoredBox(
    color: _seriesBackground,
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: seriesPanel(
                    'Return, split at zero',
                    figure:
                        '${roi.last >= 0 ? '+' : ''}${roi.last.toStringAsFixed(1)}%',
                    figureColor: roi.last >= 0 ? _seriesGreen : _seriesRed,
                    SeriesChart(
                      series: [
                        LineSeries.values(
                          roi,
                          color: _seriesGreen,
                          negativeColor: _seriesRed,
                          curve: LineCurve.monotone,
                          fill: SeriesFill.fade(
                            _seriesGreen,
                            negativeColor: _seriesRed,
                            opacity: 0.3,
                          ),
                        ),
                      ],
                      includeZero: true,
                      xAxis: SeriesXAxis(
                        labels: [
                          for (var i = 0; i < 60; i++)
                            i % 15 == 0 ? seriesDate(i) : '',
                        ],
                        style: _seriesAxis,
                      ),
                      yAxis: SeriesYAxis(
                        width: 38,
                        formatter: (v) => '${v.toStringAsFixed(0)}%',
                        style: _seriesAxis,
                      ),
                      grid: const SeriesGrid(
                        vertical: false,
                        color: _seriesGrid,
                        dashPattern: [4, 4],
                      ),
                      referenceLines: const [
                        SeriesReferenceLine.horizontal(
                          0,
                          color: _seriesMuted,
                          dashPattern: [3, 3],
                        ),
                      ],
                      touch: null,
                    ),
                  ),
                ),
                Expanded(
                  child: seriesPanel(
                    'Profit per trade',
                    figure: seriesUsd(profits.reduce((a, b) => a + b)),
                    SeriesChart(
                      series: [
                        BarSeries.values(
                          profits,
                          color: _seriesGreen,
                          negativeColor: _seriesRed,
                          radius: 3,
                          maxWidth: 14,
                        ),
                      ],
                      xAxis: SeriesXAxis(
                        labels: [
                          for (var i = 0; i < 28; i++)
                            i % 7 == 0 ? '#${i + 1}' : '',
                        ],
                        style: _seriesAxis,
                      ),
                      yAxis: const SeriesYAxis(
                        width: 38,
                        formatter: seriesUsd,
                        style: _seriesAxis,
                      ),
                      grid: const SeriesGrid(
                        vertical: false,
                        color: _seriesGrid,
                        dashPattern: [4, 4],
                      ),
                      touch: null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: seriesPanel(
                    'Deposits and withdrawals',
                    SeriesChart(
                      series: [
                        LineSeries.values(
                          deposits,
                          label: 'Deposits',
                          color: _seriesBlue,
                          fill: SeriesFill.fade(_seriesBlue),
                        ),
                        LineSeries.values(
                          withdrawals,
                          label: 'Withdrawals',
                          color: _seriesAmber,
                          fill: SeriesFill.fade(_seriesAmber),
                        ),
                      ],
                      xAxis: SeriesXAxis(
                        labels: [
                          for (var i = 0; i < 45; i++)
                            i % 10 == 0 ? seriesDate(i) : '',
                        ],
                        style: _seriesAxis,
                      ),
                      yAxis: const SeriesYAxis(
                        width: 38,
                        formatter: seriesUsd,
                        style: _seriesAxis,
                      ),
                      grid: const SeriesGrid(
                        color: _seriesGrid,
                        dashPattern: [4, 4],
                      ),
                      controller: seriesGalleryCrosshair,
                      touch: SeriesTouch(
                        trigger: SeriesTouchTrigger.longPress,
                        line: const SeriesCrosshairLine(color: _seriesMuted),
                        tooltip: _seriesTooltip(),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: seriesPanel(
                    'Balance',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '\$${(balance.last / 1000).toStringAsFixed(2)}k',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Text(
                          '+9.8% over the quarter',
                          style: TextStyle(color: _seriesGreen, fontSize: 12),
                        ),
                        const Spacer(),
                        SizedBox(
                          height: 96,
                          child: SeriesChart(
                            series: [
                              LineSeries.values(
                                balance,
                                color: _seriesPurple,
                                curve: LineCurve.monotone,
                                fill: SeriesFill.fade(
                                  _seriesPurple,
                                  opacity: 0.35,
                                ),
                                dotBuilder: (i, _) => i == balance.length - 1
                                    ? const SeriesDot(
                                        radius: 4,
                                        strokeColor: _seriesPaper,
                                        strokeWidth: 2,
                                      )
                                    : null,
                              ),
                            ],
                            xAxis: SeriesXAxis.hidden,
                            yAxis: SeriesYAxis.hidden,
                            grid: SeriesGrid.none,
                            clipToPlot: false,
                            padding: const EdgeInsets.all(4),
                            touch: null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Three series over a window of five months, with the strip that moves it.
Widget seriesWindowScene() {
  const days = 150;
  const window = SeriesWindow(95, 134);
  final deposits = seriesWave(days, base: 2100, swing: 520, drift: 4);
  final withdrawals = seriesWave(
    days,
    base: 1200,
    swing: 300,
    drift: 2,
    phase: 2.2,
  );
  final rebates = seriesWave(days, base: 420, swing: 140, drift: 1, phase: 4);

  List<PlotSeries> lines({required bool small}) => [
        for (final (label, values, color) in [
          ('Deposits', deposits, _seriesBlue),
          ('Withdrawals', withdrawals, _seriesAmber),
          ('Rebates', rebates, _seriesGreen),
        ])
          LineSeries.values(
            values,
            label: label,
            color: color,
            width: small ? 1 : 2,
            fill: SeriesFill.fade(color, opacity: small ? 0.18 : 0.24),
          ),
      ];

  return ColoredBox(
    color: _seriesBackground,
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: seriesPanel(
        'Activity trend',
        figure: '${seriesDate(window.start.round())} – '
            '${seriesDate(window.end.round())}',
        figureColor: const Color(0xFF8B95A1),
        Column(
          children: [
            Expanded(
              child: SeriesChart(
                series: lines(small: false),
                minX: window.start - 0.5,
                maxX: window.end + 0.5,
                xAxis: SeriesXAxis(
                  labels: [
                    for (var i = 0; i < days; i++)
                      i % 7 == 0 ? seriesDate(i) : '',
                  ],
                  style: _seriesAxis,
                ),
                yAxis: const SeriesYAxis(
                  width: 44,
                  formatter: seriesUsd,
                  style: _seriesAxis,
                ),
                grid: const SeriesGrid(color: _seriesGrid, dashPattern: [4, 4]),
                border: const BorderSide(color: _seriesGrid),
                controller: seriesWindowCrosshair,
                touch: SeriesTouch(
                  trigger: SeriesTouchTrigger.longPress,
                  line: const SeriesCrosshairLine(color: _seriesMuted),
                  tooltip: _seriesTooltip(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 44),
              child: SeriesRangeSelector(
                series: lines(small: true),
                window: window,
                onChanged: (_) {},
                minSpan: 4,
                height: 60,
                border: const BorderSide(color: _seriesGrid),
                maskColor: const Color(0xB30D1117),
                windowBorderColor: _seriesMuted,
                handleColor: _seriesPaper,
                handleBorderColor: _seriesMuted,
                handleGripColor: const Color(0xFF8B95A1),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A balance panel over a profit panel, holding one crosshair between them.
Widget seriesPanelsScene() {
  const count = 60;
  final balance = seriesWave(
    count,
    base: 10400,
    swing: 700,
    drift: 22,
    phase: 0.5,
  );
  final average = [
    for (var i = 0; i < count; i++)
      balance.sublist(max(0, i - 9), i + 1).reduce((a, b) => a + b) /
          (i - max(0, i - 9) + 1),
  ];
  final profit = [
    0.0,
    for (var i = 1; i < count; i++) balance[i] - balance[i - 1],
  ];

  Widget key(String label, Color color, {bool dashed = false}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < (dashed ? 3 : 1); i++)
            Container(
              width: dashed ? 5 : 20,
              height: 3,
              margin: EdgeInsets.only(right: dashed ? 2.5 : 0),
              color: color,
            ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      );

  return ColoredBox(
    color: _seriesBackground,
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: seriesPanel(
        'Balance and profit — one crosshair, two panels',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                key('Balance', _seriesPurple),
                const SizedBox(width: 18),
                key('10-day average', _seriesAmber, dashed: true),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              flex: 3,
              child: SeriesChart(
                series: [
                  LineSeries.values(
                    balance,
                    label: 'Balance',
                    color: _seriesPurple,
                    fill: SeriesFill.fade(_seriesPurple, opacity: 0.2),
                  ),
                  LineSeries.values(
                    average,
                    label: 'Average',
                    color: _seriesAmber,
                    dashPattern: const [6, 4],
                  ),
                ],
                xPadding: 0.5,
                xAxis: SeriesXAxis.hidden,
                yAxis: const SeriesYAxis(
                  width: 46,
                  formatter: seriesUsd,
                  style: _seriesAxis,
                ),
                grid: const SeriesGrid(color: _seriesGrid, dashPattern: [4, 4]),
                border: const BorderSide(color: _seriesGrid),
                controller: seriesPanelsCrosshair,
                touch: SeriesTouch(
                  trigger: SeriesTouchTrigger.longPress,
                  line: const SeriesCrosshairLine(color: _seriesMuted),
                  tooltip: SeriesTooltip(
                    builder: (context, details) {
                      final i = details.index;
                      return seriesCard(seriesDate(i), [
                        ('Balance', seriesUsd(balance[i]), _seriesPurple),
                        ('Average', seriesUsd(average[i]), _seriesAmber),
                        (
                          'P/L',
                          seriesUsd(profit[i]),
                          profit[i] < 0 ? _seriesRed : _seriesGreen,
                        ),
                      ]);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Profit / loss',
              style: TextStyle(color: Color(0xFFB6C0CC), fontSize: 12),
            ),
            const SizedBox(height: 6),
            Expanded(
              flex: 2,
              child: SeriesChart(
                series: [
                  BarSeries.values(
                    profit,
                    label: 'P/L',
                    color: _seriesGreen,
                    negativeColor: _seriesRed,
                    radius: 3,
                    minWidth: 3.5,
                    maxWidth: 12,
                  ),
                ],
                xAxis: SeriesXAxis(
                  labels: [
                    for (var i = 0; i < count; i++)
                      i % 10 == 0 ? seriesDate(i) : '',
                  ],
                  style: _seriesAxis,
                ),
                yAxis: const SeriesYAxis(
                  width: 46,
                  formatter: seriesUsd,
                  tickCount: 3,
                  style: _seriesAxis,
                ),
                grid: const SeriesGrid(
                  vertical: false,
                  color: _seriesGrid,
                  dashPattern: [4, 4],
                ),
                border: const BorderSide(color: _seriesGrid),
                controller: seriesPanelsCrosshair,
                touch: const SeriesTouch(
                  trigger: SeriesTouchTrigger.longPress,
                  line: SeriesCrosshairLine(color: _seriesMuted),
                  tooltip: null,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Candles under a watermark that is a widget: an icon and a name.
/// Two panels the axis charts cannot draw: a doughnut and a radar web.
Widget pieRadarScene() {
  const holdings = [42.0, 26.0, 18.0, 14.0];
  const names = ['BTC', 'ETH', 'SOL', 'Cash'];
  const colors = [_seriesPurple, _seriesBlue, _seriesAmber, _seriesGreen];

  return ColoredBox(
    color: _seriesBackground,
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Expanded(
            child: seriesPanel(
              'Holdings',
              figure: seriesUsd(48200),
              PieChart(
                sections: [
                  for (var i = 0; i < holdings.length; i++)
                    PieSection(
                      value: holdings[i],
                      color: colors[i],
                      label: '${holdings[i].toStringAsFixed(0)}%',
                      labelStyle: const TextStyle(fontSize: 12),
                      // The biggest holding is pulled out of the ring.
                      offset: i == 0 ? 8 : 0,
                      badge: i == 0 ? seriesChip(names[i], colors[i]) : null,
                      badgePosition: 1.18,
                    ),
                ],
                centerSpaceRadius: 52,
                centerSpaceColor: _seriesPaper,
                sectionsSpace: 2,
                startDegreeOffset: -18,
                centerChild: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Total', style: _seriesAxis),
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
          ),
          Expanded(
            child: seriesPanel(
              'Two strategies scored',
              RadarChart(
                features: const [
                  'Return',
                  'Sharpe',
                  'Win rate',
                  'Cost',
                  'Drawdown',
                ],
                series: const [
                  RadarSeries(
                    values: [4.4, 3.1, 4.8, 2.2, 3.6],
                    color: _seriesBlue,
                    label: 'Momentum',
                    dot: SeriesDot(radius: 2.5),
                  ),
                  RadarSeries(
                    values: [3.0, 4.7, 2.4, 4.1, 4.4],
                    color: _seriesAmber,
                    label: 'Mean reversion',
                    dot: SeriesDot(radius: 2.5),
                  ),
                ],
                maxValue: 5,
                tickCount: 5,
                gridColor: _seriesGrid,
                spokeColor: _seriesGrid,
                featureStyle: _seriesAxis,
                tickStyle: _seriesAxis,
                showTicks: true,
                padding: const EdgeInsets.only(bottom: 6),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// A small rounded label, for a badge pinned to a pie section.
Widget seriesChip(String text, Color color) => DecoratedBox(
      decoration: BoxDecoration(
        color: _seriesPaper,
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

/// Every trade as a dot: how big it was against what it returned.
Widget seriesScatterScene() {
  final wins = <SeriesPoint>[];
  final losses = <SeriesPoint>[];
  for (var i = 0; i < 46; i++) {
    final size = 2 + (i * 7 % 23).toDouble();
    final ret = sin(i / 3.1) * 7 + cos(i / 1.7) * 3.4 + size * 0.12 - 1.6;
    final point = SeriesPoint(size, double.parse(ret.toStringAsFixed(2)));
    (ret >= 0 ? wins : losses).add(point);
  }
  wins.sort((a, b) => a.x.compareTo(b.x));
  losses.sort((a, b) => a.x.compareTo(b.x));

  return ColoredBox(
    color: _seriesBackground,
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: seriesPanel(
        'Every trade: size against return',
        figure: '46 trades',
        SeriesChart(
          series: [
            ScatterSeries(
              points: wins,
              label: 'Win',
              color: _seriesGreen,
              dot: const SeriesDot(radius: 4.5),
            ),
            ScatterSeries(
              points: losses,
              label: 'Loss',
              color: _seriesRed,
              dot: const SeriesDot(
                radius: 4.5,
                shape: SeriesDotShape.cross,
                strokeWidth: 1.6,
              ),
            ),
          ],
          xAxis: SeriesXAxis(
            tickCount: 6,
            title: 'Size, lots',
            titleStyle: _seriesAxis,
            style: _seriesAxis,
            labelBuilder: (v) => v.toStringAsFixed(0),
          ),
          yAxis: SeriesYAxis(
            width: 44,
            title: 'Return',
            titleStyle: _seriesAxis,
            style: _seriesAxis,
            formatter: (v) => '${v.toStringAsFixed(0)}%',
          ),
          grid: const SeriesGrid(color: _seriesGrid, dashPattern: [4, 4]),
          // Room either side, so the end dots are drawn whole.
          xPadding: 1.5,
          referenceLines: const [
            SeriesReferenceLine.horizontal(
              0,
              color: _seriesMuted,
              dashPattern: [3, 3],
            ),
          ],
          controller: seriesScatterCrosshair,
          touch: SeriesTouch(
            snap: SeriesTouchSnap.nearestPoint,
            line: null,
            tooltip: SeriesTooltip(
              placement: SeriesTooltipPlacement.above,
              builder: (context, details) => seriesCard(
                '${details.values.first.point.x.toStringAsFixed(0)} lots',
                [
                  for (final value in details.values)
                    (
                      value.series.label ?? '',
                      '${value.value.toStringAsFixed(2)}%',
                      value.color,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The same bars a dashboard stacks, on a chart turned on its side.
Widget seriesHorizontalScene() {
  const income = [6.4, 5.1, 7.2, 4.6, 6.8, 7.9];
  const spending = [3.1, 4.2, 2.8, 3.9, 3.2, 2.6];

  return ColoredBox(
    color: _seriesBackground,
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: seriesPanel(
        'Flow per month — stacked, and turned on its side',
        figure: seriesUsd(25400),
        SeriesChart(
          orientation: SeriesOrientation.horizontal,
          series: [
            BarSeries.values(
              income,
              label: 'In',
              color: _seriesGreen,
              stack: 'flow',
              maxWidth: 18,
            ),
            BarSeries.values(
              spending,
              label: 'Out',
              color: _seriesRed,
              stack: 'flow',
              radius: 3,
              maxWidth: 18,
              labelBuilder: (index, point) =>
                  seriesUsd((income[index] + point.y!) * 1000),
              labelStyle: _seriesAxis,
            ),
          ],
          xAxis: SeriesXAxis(
            labels: _seriesMonths.take(6).toList(),
            style: _seriesAxis,
            height: 34,
          ),
          yAxis: SeriesYAxis(
            title: 'Thousands',
            titleStyle: _seriesAxis,
            style: _seriesAxis,
            interval: 2,
            formatter: (v) => v.toStringAsFixed(0),
          ),
          grid: const SeriesGrid(
            horizontal: true,
            vertical: false,
            color: _seriesGrid,
            dashPattern: [4, 4],
          ),
          maxY: 12,
          touch: null,
        ),
      ),
    ),
  );
}

/// Bars that float between two values, and a band between two lines.
Widget seriesRangesScene() {
  // Each step runs from where the last one ended to where it leaves the
  // balance; the first and the last are whole bars off zero.
  const steps = [
    (0.0, 4.0),
    (4.0, 9.4),
    (9.4, 8.1),
    (8.1, 7.2),
    (7.2, 5.9),
    (0.0, 5.9),
  ];
  final forecast = seriesWave(30, base: 62, swing: 6, drift: 0.35);
  final high = [for (var i = 0; i < 30; i++) forecast[i] + 3 + i * 0.22];
  final low = [for (var i = 0; i < 30; i++) forecast[i] - 3 - i * 0.22];

  return ColoredBox(
    color: _seriesBackground,
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Expanded(
            child: seriesPanel(
              'Where the quarter went',
              figure: r'$5.9k',
              SeriesChart(
                series: [
                  BarSeries(
                    points: [
                      for (var i = 0; i < steps.length; i++)
                        SeriesPoint(
                          i.toDouble(),
                          steps[i].$2,
                          low: steps[i].$1,
                        ),
                    ],
                    color: _seriesGreen,
                    radius: 3,
                    maxWidth: 34,
                    colorBuilder: (index, point) =>
                        index == 0 || index == steps.length - 1
                            ? _seriesBlue
                            : point.y! >= (point.low ?? 0)
                                ? _seriesGreen
                                : _seriesRed,
                    labelBuilder: (index, point) => point.y!.toStringAsFixed(1),
                    labelStyle: _seriesAxis,
                  ),
                ],
                xAxis: const SeriesXAxis(
                  labels: ['Open', 'Sales', 'Refunds', 'Fees', 'Tax', 'Close'],
                  style: _seriesAxis,
                ),
                yAxis: const SeriesYAxis(
                  width: 34,
                  style: _seriesAxis,
                  formatter: seriesUsd,
                ),
                grid: const SeriesGrid(
                  vertical: false,
                  color: _seriesGrid,
                  dashPattern: [4, 4],
                ),
                touch: null,
              ),
            ),
          ),
          Expanded(
            child: seriesPanel(
              'Forecast, with its band and its error',
              figure: '± 2σ',
              SeriesChart(
                series: [
                  LineSeries.values(
                    high,
                    color: _seriesBlue.withValues(alpha: 0.7),
                    width: 1,
                    dashPattern: const [5, 4],
                  ),
                  LineSeries.values(
                    low,
                    color: _seriesBlue.withValues(alpha: 0.7),
                    width: 1,
                    dashPattern: const [5, 4],
                  ),
                  LineSeries(
                    points: [
                      for (var i = 0; i < 30; i++)
                        SeriesPoint(
                          i.toDouble(),
                          forecast[i],
                          yError: i % 6 == 5
                              ? SeriesErrorRange.symmetric(2.4 + i * 0.06)
                              : null,
                        ),
                    ],
                    label: 'Forecast',
                    color: _seriesBlue,
                    curve: LineCurve.monotone,
                    errorBars: const SeriesErrorBars(
                      color: _seriesAmber,
                      capLength: 8,
                    ),
                  ),
                ],
                betweenFills: [
                  SeriesBetweenFill(
                    from: 0,
                    to: 1,
                    color: _seriesBlue.withValues(alpha: 0.14),
                  ),
                ],
                xPadding: 0.8,
                xAxis: SeriesXAxis(
                  labels: [
                    for (var i = 0; i < 30; i++)
                      i % 7 == 0 ? seriesDate(i) : '',
                  ],
                  style: _seriesAxis,
                ),
                yAxis: const SeriesYAxis(
                  width: 34,
                  style: _seriesAxis,
                  formatter: seriesUsd,
                ),
                grid: const SeriesGrid(
                  vertical: false,
                  color: _seriesGrid,
                  dashPattern: [4, 4],
                ),
                touch: null,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget watermarkScene() {
  final colors = ChartTheme.darkColors()
    ..watermarkColor = const Color(0x1FFFFFFF);
  return ColoredBox(
    color: colors.bgColor,
    child: KChartWidget(
      MarketData.candles(count: 160),
      colors,
      chartStyle: ChartTheme.filled.copyWith(watermarkScale: 0.6),
      timeFrame: MarketData.timeFrame,
      timeFormat: TimeFormat.YEAR_MONTH_DAY_WITH_HOUR,
      indicators: [MaIndicator(period: 20)],
      showInfoDialog: false,
      showScrollToNowButton: false,
      fixedLength: 0,
      watermark: const FittedBox(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.candlestick_chart, size: 96),
            SizedBox(width: 16),
            Text(
              'ACME MARKETS',
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
