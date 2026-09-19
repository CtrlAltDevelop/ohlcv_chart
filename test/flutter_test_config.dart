import 'dart:async';

import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

/// Fails a test file whose widgets leave a disposable behind.
///
/// A laid-out `TextPainter` holds a native paragraph, and a chart lays out a
/// few dozen labels a frame, so a painter the chart forgets to dispose is real
/// memory rather than a tidiness point. This catches that class of bug at the
/// only moment it is cheap to find.
///
/// `ChartDrawingController` and `KChartController` are left out: they are
/// `ChangeNotifier`s the caller makes and owns — the chart attaches to one and
/// detaches on teardown but never disposes it — and the tests hand them to the
/// garbage collector rather than disposing each one.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  LeakTesting.enable();
  LeakTesting.settings = LeakTesting.settings.withTrackedAll().withIgnored(
    classes: const ['ChartDrawingController', 'KChartController'],
  );
  await testMain();
}
