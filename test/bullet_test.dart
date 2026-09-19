import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

const _rows = [
  BulletRow(
    label: 'Win rate',
    value: 58,
    target: 55,
    max: 100,
    bands: [
      BulletBand(to: 40, color: Color(0x33E03131)),
      BulletBand(to: 55, color: Color(0x33F59F00)),
      BulletBand(to: 100, color: Color(0x332F9E44)),
    ],
  ),
  BulletRow(label: 'Profit factor', value: 1.6, target: 2, max: 3),
];

void main() {
  group('a row', () {
    test('takes the largest of value, target and bands for its top', () {
      const row = BulletRow(
        label: 'x',
        value: 3,
        target: 7,
        bands: [BulletBand(to: 5, color: Color(0xFF000000))],
      );
      expect(row.resolvedMax, 7);
    });

    test('leaves room over a bare bar, but not over given bands', () {
      const bare = BulletRow(label: 'x', value: 10);
      expect(bare.resolvedMax, greaterThan(10));
      const banded = BulletRow(
        label: 'x',
        value: 10,
        bands: [BulletBand(to: 10, color: Color(0xFF000000))],
      );
      expect(banded.resolvedMax, 10);
    });

    test('a flat row still has a range to draw in', () {
      const flat = BulletRow(label: 'x', value: 0, max: 0);
      expect(flat.resolvedMax, 1);
    });
  });

  group('the layout', () {
    test('rows stack down the box, a track each', () {
      final layout = layOutBullet(
        _rows,
        size: const Size(400, 200),
        rowHeight: 20,
        rowGap: 10,
      );
      expect(layout.rows, hasLength(2));
      expect(layout.rows[0].trackRect.top, 0);
      expect(layout.rows[0].trackRect.height, 20);
      expect(layout.rows[1].trackRect.top, 30);
    });

    test('values run along the track, the target where it belongs', () {
      final layout = layOutBullet(
        _rows,
        size: const Size(400, 200),
        labelWidth: 0,
        valueWidth: 0,
      );
      final row = layout.rows.first;
      final track = row.trackRect;
      // 58 of 100 along a track that starts at zero.
      expect(row.barRect.right, closeTo(track.left + track.width * 0.58, 1e-6));
      expect(row.targetX, closeTo(track.left + track.width * 0.55, 1e-6));
    });

    test('bands run from where the one before them ended', () {
      final layout = layOutBullet(
        _rows,
        size: const Size(400, 200),
        labelWidth: 0,
      );
      final bands = layout.rows.first.bandRects;
      expect(bands, hasLength(3));
      expect(bands[1].left, closeTo(bands[0].right, 1e-9));
      expect(bands[2].right, closeTo(layout.rows.first.trackRect.right, 1e-9));
    });

    test('the bar is thinner than the track and centred in it', () {
      final layout = layOutBullet(
        _rows,
        size: const Size(400, 200),
        rowHeight: 20,
        barThickness: 0.5,
      );
      final row = layout.rows.first;
      expect(row.barRect.height, closeTo(10, 1e-9));
      expect(row.barRect.center.dy, closeTo(row.trackRect.center.dy, 1e-9));
    });

    test('progress shortens the bars but leaves the targets alone', () {
      final half = layOutBullet(
        _rows,
        size: const Size(400, 200),
        labelWidth: 0,
        progress: 0.5,
      );
      final full = layOutBullet(
        _rows,
        size: const Size(400, 200),
        labelWidth: 0,
      );
      expect(
        half.rows.first.barRect.width,
        closeTo(full.rows.first.barRect.width / 2, 1e-6),
      );
      expect(half.rows.first.targetX, full.rows.first.targetX);
    });

    test('rows shrink to fit a box too short for them', () {
      final layout = layOutBullet(
        _rows,
        size: const Size(400, 30),
        rowHeight: 20,
        rowGap: 10,
      );
      expect(layout.rows.last.trackRect.bottom, lessThanOrEqualTo(30.001));
    });

    test('nothing to show lays out nothing', () {
      expect(layOutBullet(const [], size: const Size(400, 200)).isEmpty, true);
      expect(layOutBullet(_rows, size: Size.zero).isEmpty, true);
      expect(
        layOutBullet(
          _rows,
          size: const Size(20, 200),
          labelWidth: 200,
          labelGap: 30,
        ).isEmpty,
        true,
      );
    });

    test('a point finds the row it is over, and nothing past the last', () {
      final layout = layOutBullet(
        _rows,
        size: const Size(400, 200),
        rowHeight: 20,
        rowGap: 10,
      );
      expect(layout.rowAt(const Offset(200, 10))?.index, 0);
      expect(layout.rowAt(const Offset(200, 35))?.index, 1);
      expect(layout.rowAt(const Offset(200, 180)), isNull);
    });
  });

  group('the widget', () {
    testWidgets('draws and reports the row under the finger', (tester) async {
      BulletRow? touched;
      var cleared = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 200,
              child: BulletChart(
                rows: _rows,
                onRowTap: (row) {
                  if (row == null) {
                    cleared = true;
                  } else {
                    touched = row;
                  }
                },
              ),
            ),
          ),
        ),
      );
      expect(find.byType(BulletChart), findsOneWidget);

      final gesture = await tester.startGesture(
        tester.getTopLeft(find.byType(BulletChart)) + const Offset(200, 10),
      );
      await tester.pump();
      expect(touched?.label, 'Win rate');

      await gesture.up();
      await tester.pump();
      expect(cleared, true);
    });

    testWidgets('takes its own height in an unbounded box', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BulletChart(rows: _rows, rowHeight: 20, rowGap: 10),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(BulletChart)).height, 50);
    });

    testWidgets('animates the bars in', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 200,
              child: BulletChart(
                rows: _rows,
                animationDuration: Duration(milliseconds: 200),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
