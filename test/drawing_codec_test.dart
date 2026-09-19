import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

DateTime _at(int minute) =>
    DateTime.utc(2024, 1, 1).add(Duration(minutes: minute));

void main() {
  group('drawing serialisation', () {
    test('a horizontal line round-trips through JSON', () {
      final line = HorizontalLine(
        price: 101.5,
        title: 'entry',
        alert: true,
        color: const Color(0xAAFF0000),
        thickness: 3,
        style: LineStyle.dotted,
        locked: true,
        showLabel: true,
        hidden: true,
      );

      final restored = drawingFromJson(line.toJson())! as HorizontalLine;

      expect(restored.price, 101.5);
      expect(restored.title, 'entry');
      expect(restored.alert, isTrue);
      expect(restored.color, const Color(0xAAFF0000));
      expect(restored.thickness, 3);
      expect(restored.style, LineStyle.dotted);
      expect(restored.locked, isTrue);
      expect(restored.showLabel, isTrue);
      expect(restored.hidden, isTrue);
      expect(restored.isRay, isFalse);
    });

    test('a horizontal ray keeps the candle it starts at', () {
      final ray = HorizontalLine(price: 7, startTime: _at(30));
      final restored = drawingFromJson(ray.toJson())! as HorizontalLine;

      expect(restored.startTime, _at(30));
      expect(restored.isRay, isTrue);
    });

    test('a vertical line round-trips', () {
      final line = VerticalLine(time: _at(12), title: 'open');
      final restored = drawingFromJson(line.toJson())! as VerticalLine;

      expect(restored.time, _at(12));
      expect(restored.title, 'open');
    });

    test('every trend-line variant keeps what makes it one', () {
      for (final extend in LineExtension.values) {
        final line = TrendLine(
          time1: _at(1),
          price1: 10,
          time2: _at(9),
          price2: 20,
          extend: extend,
          arrow: extend == LineExtension.none,
          label1: 'a',
          label2: 'b',
        );

        final restored = drawingFromJson(line.toJson())! as TrendLine;

        expect(restored.extend, extend);
        expect(restored.arrow, extend == LineExtension.none);
        expect(restored.time1, _at(1));
        expect(restored.time2, _at(9));
        expect(restored.price1, 10);
        expect(restored.price2, 20);
        expect(restored.label1, 'a');
        expect(restored.label2, 'b');
      }
    });

    test('a rectangle keeps its wash and label', () {
      final box = RectangleDrawing(
        time1: _at(2),
        price1: 5,
        time2: _at(8),
        price2: 15,
        fillOpacity: 0.4,
        label: 'range',
      );

      final restored = drawingFromJson(box.toJson())! as RectangleDrawing;

      expect(restored.fillOpacity, 0.4);
      expect(restored.label, 'range');
      expect(restored.fillColor.a, closeTo(box.fillColor.a, 1e-9));
    });

    test('a retracement keeps its own levels', () {
      final fib = FibRetracement(
        time1: _at(3),
        price1: 100,
        time2: _at(20),
        price2: 200,
        levels: const [0, 0.5, 1, 1.618],
        fillLevels: false,
      );

      final restored = drawingFromJson(fib.toJson())! as FibRetracement;

      expect(restored.levels, [0, 0.5, 1, 1.618]);
      expect(restored.fillLevels, isFalse);
      expect(restored.priceAt(0.5), 150);
    });

    test('a half-placed drawing round-trips without its second anchor', () {
      final half = TrendLine(time1: _at(4), price1: 3);
      final restored = drawingFromJson(half.toJson())! as TrendLine;

      expect(restored.isComplete, isFalse);
      expect(restored.time2, isNull);
      expect(restored.price2, isNull);
    });

    test('an unknown kind is skipped rather than thrown', () {
      expect(drawingFromJson({'type': 'gann-fan-from-the-future'}), isNull);
      expect(drawingFromJson(const <String, dynamic>{}), isNull);
    });

    test('a malformed map still yields a usable drawing', () {
      final restored = drawingFromJson({
        'type': 'horizontal',
        'price': 'not a number',
        'color': 'blue',
      });

      expect(restored, isA<HorizontalLine>());
      expect((restored! as HorizontalLine).price, 0);
    });

    test('copyDrawing shares nothing with the original', () {
      final line = HorizontalLine(price: 10, title: 'a');
      final clone = copyDrawing(line);

      clone
        ..price = 20
        ..title = 'b';

      expect(line.price, 10);
      expect(line.title, 'a');
      expect(clone, isA<HorizontalLine>());
    });
  });

  group('ChartDrawings', () {
    ChartDrawings sample() => ChartDrawings([
      HorizontalLine(price: 1),
      VerticalLine(time: _at(1)),
      TrendLine(time1: _at(1), price1: 1, time2: _at(2), price2: 2),
      RectangleDrawing(time1: _at(1), price1: 1, time2: _at(2), price2: 2),
      FibRetracement(time1: _at(1), price1: 1, time2: _at(2), price2: 2),
    ]);

    test('sorts a restored set back into its typed views', () {
      final restored = ChartDrawings.fromJson(sample().toJson());

      expect(restored.length, 5);
      expect(restored.horizontalLines, hasLength(1));
      expect(restored.verticalLines, hasLength(1));
      expect(restored.trendLines, hasLength(1));
      expect(restored.rectangles, hasLength(1));
      expect(restored.fibRetracements, hasLength(1));
    });

    test('survives a trip through a JSON string', () {
      final encoded = jsonEncode(sample().toJson());
      final restored = ChartDrawings.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );

      expect(restored.length, 5);
      expect(restored.toJson()['version'], ChartDrawings.formatVersion);
    });

    test('save adds a new drawing and leaves a known one where it is', () {
      final drawings = ChartDrawings();
      final line = HorizontalLine(price: 1);

      drawings
        ..save(line)
        ..save(VerticalLine(time: _at(1)))
        ..save(line);

      // Saving an edit must not restack the drawing over the one that was
      // drawn after it.
      expect(drawings.length, 2);
      expect(drawings.all.first, same(line));
      expect(drawings.indexOf(line), 0);
    });

    test('a drawing can be moved up and down the stack', () {
      final bottom = HorizontalLine(price: 1);
      final middle = HorizontalLine(price: 2);
      final top = HorizontalLine(price: 3);
      final drawings = ChartDrawings([bottom, middle, top]);

      expect(drawings.moveToFront(bottom), isTrue);
      expect(drawings.all, [middle, top, bottom]);

      expect(drawings.moveToBack(bottom), isTrue);
      expect(drawings.all, [bottom, middle, top]);

      expect(drawings.moveForward(bottom), isTrue);
      expect(drawings.all, [middle, bottom, top]);

      expect(drawings.moveBackward(bottom), isTrue);
      expect(drawings.all, [bottom, middle, top]);
    });

    test('a drawing already at the end of the stack does not move', () {
      final bottom = HorizontalLine(price: 1);
      final top = HorizontalLine(price: 2);
      final drawings = ChartDrawings([bottom, top]);

      expect(drawings.moveBackward(bottom), isFalse);
      expect(drawings.moveToBack(bottom), isFalse);
      expect(drawings.moveForward(top), isFalse);
      expect(drawings.moveToFront(top), isFalse);
      expect(drawings.all, [bottom, top]);
    });

    test('a stranger cannot be restacked, and is nowhere in the stack', () {
      final drawings = ChartDrawings([HorizontalLine(price: 1)]);
      final stranger = HorizontalLine(price: 9);

      expect(drawings.indexOf(stranger), -1);
      expect(drawings.moveToFront(stranger), isFalse);
      expect(drawings.moveForward(stranger), isFalse);
      expect(drawings.moveBackward(stranger), isFalse);
    });

    test('an empty or malformed payload loads as an empty set', () {
      expect(ChartDrawings.fromJson(const {}).isEmpty, isTrue);
      expect(ChartDrawings.fromJson(const {'drawings': 7}).isEmpty, isTrue);
    });

    test('copy leaves the original alone', () {
      final drawings = sample();
      final clone = drawings.copy();

      clone.horizontalLines.first.price = 999;
      clone.clear();

      expect(drawings.length, 5);
      expect(drawings.horizontalLines.first.price, 1);
    });
  });
}
