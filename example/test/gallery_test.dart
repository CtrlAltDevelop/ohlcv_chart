import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart_example/src/demo_state.dart';
import 'package:ohlcv_chart_example/src/gallery/gallery_entries.dart';
import 'package:ohlcv_chart_example/src/gallery/gallery_page.dart';

void main() {
  group('the catalogue', () {
    test('every entry has an id, a doc page and something to show', () {
      final entries = galleryEntries();
      expect(entries, isNotEmpty);
      for (final entry in entries) {
        expect(entry.id, isNotEmpty, reason: entry.title);
        expect(entry.variants, isNotEmpty, reason: entry.title);
        expect(entry.doc, endsWith('.md'), reason: entry.title);
        expect(entry.blurb, isNotEmpty, reason: entry.title);
      }
    });

    test('ids are unique, so a screenshot cannot overwrite another', () {
      final ids = [for (final e in galleryEntries()) e.id];
      expect(ids.toSet().length, ids.length);
    });

    test('an entry can be found by its id, and a stranger cannot', () {
      expect(galleryEntryById('treemap')?.title, 'Treemap');
      expect(galleryEntryById('nothing-by-that-name'), isNull);
    });

    test('every group has entries in it', () {
      for (final group in GalleryGroup.values) {
        expect(
          galleryEntries().where((e) => e.group == group),
          isNotEmpty,
          reason: group.title,
        );
      }
    });
  });

  group('the page', () {
    testWidgets('lists every chart, grouped', (tester) async {
      final state = DemoState();
      addTearDown(state.dispose);
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GalleryPage(state: state)),
        ),
      );
      await tester.pumpAndSettle();

      // The list is lazy, so the later groups only exist once scrolled to.
      for (final group in GalleryGroup.values) {
        await tester.scrollUntilVisible(
          find.text(group.title),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text(group.title), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('searching narrows the list', (tester) async {
      final state = DemoState();
      addTearDown(state.dispose);
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GalleryPage(state: state)),
        ),
      );
      await tester.enterText(find.byType(TextField), 'waffle');
      await tester.pumpAndSettle();

      expect(find.text('Waffle'), findsOneWidget);
      expect(find.text('Treemap'), findsNothing);

      await tester.enterText(find.byType(TextField), 'nothing at all');
      await tester.pumpAndSettle();
      expect(find.text('Nothing by that name.'), findsOneWidget);
    });

    testWidgets('a card opens the chart on its own page', (tester) async {
      final state = DemoState();
      addTearDown(state.dispose);
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GalleryPage(state: state)),
        ),
      );
      // Searched for rather than scrolled to: the list is lazy, and the card
      // is a long way down it.
      await tester.enterText(find.byType(TextField), 'treemap');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Treemap'));
      await tester.pumpAndSettle();

      expect(find.byType(GalleryDetailPage), findsOneWidget);
      expect(find.text('Market map'), findsOneWidget);
      expect(find.textContaining('doc/treemap-chart.md'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('every chart', () {
    // The point of the gallery: each of these really builds, at a phone width
    // as well as a desktop one, and none of them throws while painting.
    for (final entry in galleryEntries()) {
      testWidgets('${entry.title} draws', (tester) async {
        final state = DemoState();
        addTearDown(state.dispose);
        for (final size in [const Size(1100, 1600), const Size(400, 1600)]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            MaterialApp(
              home: GalleryDetailPage(entry: entry, state: state),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: entry.id);
          // At least one: a chart whose variant is called what the chart is
          // called has the title in the app bar as well.
          expect(
            find.text(entry.variants.first.title),
            findsWidgets,
            reason: entry.id,
          );
        }
      });
    }
  });
}
