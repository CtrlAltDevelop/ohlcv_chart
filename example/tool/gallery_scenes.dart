// The scenes for the chart gallery: one image per chart doc page.
//
// The charts themselves come from `src/gallery/gallery_entries.dart`, which is
// what the example app's Gallery tab is built from as well — so the pictures in
// the documentation are of the charts the example actually runs, and there is
// one place to change a chart rather than two that drift apart.
part of 'screenshots.dart';

/// A gallery scene: wide enough for two panels, tall enough for a chart that
/// needs the height.
const Size gallery = Size(1180, 460);

/// A squarer scene, for the charts that draw a circle and would otherwise sit
/// in the middle of two empty halves.
const Size square = Size(720, 460);

/// The charts that want the squarer frame.
const _squareScenes = {'sunburst', 'chord'};

/// The charts that fit the shorter frame, having no great height to fill.
const _shortScenes = {
  'gauge',
  'funnel',
  'waffle',
  'bullet',
  'dumbbell',
  'waterfall',
  'box-plot',
  'histogram',
};

/// The gallery's scenes, added to the set [buildScenes] shoots.
///
/// One per entry, named after it, so `--dart-define=only=treemap` shoots the
/// treemap and `screenshots/treemap.png` is what the treemap's doc page shows.
List<Scene> buildGalleryScenes() => [
      for (final entry in galleryEntries())
        (
          name: entry.id,
          size: _squareScenes.contains(entry.id)
              ? square
              : _shortScenes.contains(entry.id)
                  ? shortWide
                  : gallery,
          act: null,
          build: () => _galleryScene(entry),
        ),
    ];

/// One entry, as a row of panels — a panel per variant.
Widget _galleryScene(GalleryEntry entry) => ColoredBox(
      color: _seriesBackground,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          children: [
            for (final variant in entry.variants)
              Expanded(
                child: seriesPanel(
                  variant.title,
                  figure: variant.figure,
                  figureColor: variant.figureColor ?? Colors.white,
                  variant.build(),
                ),
              ),
          ],
        ),
      ),
    );
