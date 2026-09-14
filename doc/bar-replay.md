# Bar replay

Rewind the chart and let the market happen again. `ChartReplayController` holds
the chart at a candle in the past: everything after it — the candles, the
indicators computed from them, the now-price line and the legend — is as it was
at that moment, so a setup can be studied without the answer already on screen.

![The replay running, a candle at a time](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/bar-replay.gif)

```dart
final replay = ChartReplayController(interval: const Duration(milliseconds: 300));

KChartWidget(
  candles,
  ChartColors(),
  isTrendLine: false,
  timeFrame: const Duration(minutes: 15),
  replay: replay,
);

replay.start(at: 200);   // draw the oldest 200 candles and hold there
replay.stepForward();    // one more
replay.stepBack();       // one fewer
replay.play();           // or let them arrive on their own
replay.pause();
replay.stop();           // hand the whole series back
```

`play()` from cold starts halfway through, so a play button works without a
candle having been picked first, and it gives up on its own at the newest one —
`isPlaying`, `isActive`, `position`, `length` and `isAtEnd` are all there to
drive a transport bar from. It is a `ChangeNotifier`, so those buttons rebuild
themselves; dispose it with the widget that owns it.

![The chart held at the 150th candle of 420, under a transport bar](https://raw.githubusercontent.com/CtrlAltDevelop/ohlcv_chart/main/screenshots/bar-replay.png)

Nothing is thrown away while a replay runs: the candle list is untouched and
the drawings stay where they were placed, including any on candles still to
arrive.

---

[← All docs](README.md) · [Package README](../README.md)
