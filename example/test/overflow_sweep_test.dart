import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ohlcv_chart_example/src/demo_state.dart';
import 'package:ohlcv_chart_example/src/gallery/gallery_entries.dart';
import 'package:ohlcv_chart_example/src/gallery/gallery_page.dart';

void main() {
  const widths = [240.0, 280.0, 320.0, 360.0, 420.0, 600.0, 900.0, 1400.0];
  for (final entry in galleryEntries()) {
    for (final width in widths) {
      testWidgets('${entry.id} at $width wide', (tester) async {
        final state = DemoState();
        addTearDown(state.dispose);
        tester.view.physicalSize = Size(width, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final errors = <FlutterErrorDetails>[];
        final original = FlutterError.onError;
        FlutterError.onError = errors.add;
        await tester.pumpWidget(
          MaterialApp(
            home: GalleryDetailPage(entry: entry, state: state),
          ),
        );
        await tester.pumpAndSettle();
        FlutterError.onError = original;

        expect(
          errors.map((e) => e.exceptionAsString().split('\n').first).toList(),
          isEmpty,
          reason: '${entry.id} at $width',
        );
      });
    }
  }
}
