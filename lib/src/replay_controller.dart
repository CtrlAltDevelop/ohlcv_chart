import 'dart:async';

import 'package:flutter/foundation.dart';

/// Plays a chart back candle by candle, as if the market were moving again.
///
/// The chart draws only as far as [position], so everything after it — the
/// candles, the indicators computed from them, the now-price line — is as it
/// was at that moment. Nothing is thrown away: [stop] hands the whole series
/// back.
///
/// ```dart
/// final replay = ChartReplayController();
///
/// KChartWidget(candles, ChartColors(), replay: replay, /* … */);
///
/// replay.start(at: 200);   // rewind to the 200th candle
/// replay.stepForward();    // one candle at a time
/// replay.play();           // or let it run
/// replay.stop();           // back to the live chart
/// ```
///
/// It is a [ChangeNotifier], so a toolbar of replay buttons can rebuild itself
/// from the same controller the chart is driven by. Remember to [dispose] it.
class ChartReplayController extends ChangeNotifier {
  /// Creates a controller that is not replaying anything yet.
  ///
  /// [interval] is how long each candle is held for while [play] runs.
  ChartReplayController({
    Duration interval = const Duration(milliseconds: 500),
  }) {
    _interval = interval;
  }

  int? _position;
  int _length = 0;
  late Duration _interval;
  Timer? _timer;

  /// How many candles the chart is drawing, or null while the whole series is.
  ///
  /// Never less than 1: a chart of no candles is nothing to look at, so the
  /// first candle is always in play.
  int? get position => _position;

  /// Whether the chart is being played back rather than shown in full.
  bool get isActive => _position != null;

  /// Whether the candles are advancing on their own.
  bool get isPlaying => _timer != null;

  /// How long each candle is held for while [play] runs.
  Duration get interval => _interval;

  /// How many candles there are in total, as the chart last reported it.
  int get length => _length;

  /// Whether the playback has reached the newest candle.
  bool get isAtEnd => _position != null && _position! >= _length;

  /// Called by the chart as the candles change, so the controller knows where
  /// the end is. An app has no reason to call this.
  ///
  /// Deliberately quiet: it runs while the chart is building, which is no time
  /// to tell everyone to rebuild. A series that shrank under a running replay
  /// — a different symbol, say — is pulled back to its new end here, and the
  /// chart is about to draw that anyway.
  void reportLength(int length) {
    if (length == _length) return;
    _length = length;
    if (_position != null && _position! > length) _position = length;
  }

  /// Rewinds to [at] and holds the chart there.
  ///
  /// [at] is a count of candles, not an index: `start(at: 200)` draws the
  /// oldest 200. Out-of-range values are pulled back into it.
  void start({required int at}) {
    final next = _clamp(at);
    if (_position == next) return;
    _position = next;
    notifyListeners();
  }

  /// Hands the whole series back and stops any playback.
  void stop() {
    if (_position == null && _timer == null) return;
    _stopTimer();
    _position = null;
    notifyListeners();
  }

  /// Moves the playback to [position] candles, starting a replay if none is
  /// running.
  void jumpTo(int position) => start(at: position);

  /// Adds the next candle, stopping at the newest one.
  ///
  /// Does nothing once the playback has caught up with the market, which is
  /// also where [play] gives up.
  void stepForward([int by = 1]) {
    if (_position == null || by <= 0) return;
    final next = _clamp(_position! + by);
    if (next == _position) {
      _stopTimer();
      return;
    }
    _position = next;
    if (isAtEnd) _stopTimer();
    notifyListeners();
  }

  /// Takes the last candle back off again.
  void stepBack([int by = 1]) {
    if (_position == null || by <= 0) return;
    final next = _clamp(_position! - by);
    if (next == _position) return;
    _position = next;
    notifyListeners();
  }

  /// Lets the candles arrive on their own, one every [interval].
  ///
  /// Starts a replay from the halfway point if none is running, so a play
  /// button works without a bar having been picked first. Does nothing once
  /// the playback is at the end — [stepBack] or [start] first.
  void play({Duration? interval}) {
    if (interval != null) _interval = interval;
    if (_position == null) start(at: (_length / 2).round());
    if (isAtEnd || _timer != null) return;

    _timer = Timer.periodic(_interval, (_) => stepForward());
    notifyListeners();
  }

  /// Holds the playback where it is, leaving the chart replaying.
  void pause() {
    if (_timer == null) return;
    _stopTimer();
    notifyListeners();
  }

  /// Plays or pauses, whichever the controller is not doing.
  void toggle() => isPlaying ? pause() : play();

  /// How long each candle is held for from now on.
  ///
  /// Takes effect immediately, restarting the timer if one is running.
  void setInterval(Duration value) {
    if (value == _interval) return;
    _interval = value;
    if (_timer != null) {
      _stopTimer();
      _timer = Timer.periodic(_interval, (_) => stepForward());
    }
    notifyListeners();
  }

  int _clamp(int value) => _length == 0 ? 1 : value.clamp(1, _length);

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}
