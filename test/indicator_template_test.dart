import 'dart:convert';

import 'package:material_ui/material_ui.dart' show Color, Colors;
import 'package:flutter_test/flutter_test.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

void main() {
  group('IndicatorTemplate', () {
    test('round-trips through JSON text', () {
      final template = IndicatorTemplate(
        name: 'Swing',
        indicators: [
          MaIndicator(period: 50, color: Colors.amber),
          RsiIndicator(period: 14),
          MacdIndicator(),
        ],
      );

      final back = IndicatorTemplate.fromJson(
        jsonDecode(jsonEncode(template.toJson())) as Map<String, dynamic>,
      );

      expect(back.name, 'Swing');
      expect(back.indicators, template.indicators);
      expect(
        back.indicators.first.colors!.first.toARGB32(),
        Colors.amber.toARGB32(),
      );
      expect(back, template);
    });

    test('two of the same name and contents are the same template', () {
      IndicatorTemplate build() => IndicatorTemplate(
        name: 'Trend',
        indicators: [MaIndicator(period: 20)],
      );

      expect(build(), build());
      expect(build().hashCode, build().hashCode);
      expect(build(), isNot(build().copyWith(name: 'Other')));
      expect(
        build(),
        isNot(build().copyWith(indicators: [MaIndicator(period: 21)])),
      );
    });

    test('reports what it cannot save, and leaves it out', () {
      final mine = _Mine();
      final template = IndicatorTemplate(
        name: 'Mixed',
        indicators: [MaIndicator(period: 20), mine],
      );

      expect(template.unsaveable, [mine]);

      final back = IndicatorTemplate.fromJson(template.toJson());
      expect(back.indicators, [MaIndicator(period: 20)]);
    });

    test('skips an indicator it does not recognise', () {
      final back = IndicatorTemplate.fromJson({
        'name': 'From the future',
        'indicators': [
          {
            'kind': 'MA',
            'values': {'period': 9},
          },
          {'kind': 'SOMETHING_NEW'},
          'not even a map',
        ],
      });

      expect(back.name, 'From the future');
      expect(back.indicators, [MaIndicator(period: 9)]);
    });

    test('survives a map with nothing in it', () {
      final back = IndicatorTemplate.fromJson(const {});
      expect(back.name, '');
      expect(back.indicators, isEmpty);
    });

    test('the starters are all saveable, and all different', () {
      final names = <String>{};
      for (final template in IndicatorTemplate.starters) {
        expect(template.indicators, isNotEmpty, reason: template.name);
        expect(
          template.unsaveable,
          isEmpty,
          reason: '${template.name} holds something that cannot be saved',
        );
        expect(names.add(template.name), isTrue, reason: template.name);
      }
      expect(names, hasLength(greaterThan(1)));
    });
  });

  group('IndicatorTemplates', () {
    test('saving under a taken name replaces it, in its place', () {
      final saved = IndicatorTemplates([
        IndicatorTemplate(name: 'A', indicators: [MaIndicator(period: 5)]),
        IndicatorTemplate(name: 'B', indicators: [RsiIndicator()]),
      ]);

      saved.save(
        IndicatorTemplate(name: 'A', indicators: [MaIndicator(period: 99)]),
      );

      expect(saved.length, 2);
      expect(saved.all.map((t) => t.name), ['A', 'B'], reason: 'order holds');
      expect(saved['A']!.indicators, [MaIndicator(period: 99)]);
    });

    test('removing answers whether there was one', () {
      final saved = IndicatorTemplates([
        IndicatorTemplate(name: 'A', indicators: [RsiIndicator()]),
      ]);

      expect(saved.remove('A'), isTrue);
      expect(saved.remove('A'), isFalse);
      expect(saved.isEmpty, isTrue);
    });

    test('round-trips a whole library through JSON text', () {
      final saved = IndicatorTemplates(IndicatorTemplate.starters);
      final back = IndicatorTemplates.fromJson(
        jsonDecode(jsonEncode(saved.toJson())) as Map<String, dynamic>,
      );

      expect(back.length, saved.length);
      for (final template in saved.all) {
        expect(back[template.name], template, reason: template.name);
      }
    });

    test('an empty library round-trips to an empty one', () {
      final back = IndicatorTemplates.fromJson(IndicatorTemplates().toJson());
      expect(back.isEmpty, isTrue);
      expect(back.all, isEmpty);
    });

    test('reads past a template it cannot make sense of', () {
      final back = IndicatorTemplates.fromJson({
        'templates': [
          {
            'name': 'Good',
            'indicators': [
              {'kind': 'RSI'},
            ],
          },
          'not a template',
          42,
        ],
      });

      expect(back.length, 1);
      expect(back['Good']!.indicators, [RsiIndicator()]);
    });

    test('the list it hands out cannot be edited behind its back', () {
      final saved = IndicatorTemplates(IndicatorTemplate.starters);
      expect(
        () => saved.all.add(IndicatorTemplate(name: 'X', indicators: const [])),
        throwsUnsupportedError,
      );
    });
  });
}

/// An indicator of somebody's own, which the catalog knows nothing about.
class _Mine extends Indicator {
  @override
  IndicatorPlacement get placement => IndicatorPlacement.pane;

  @override
  String get name => 'MINE';

  @override
  String get label => 'MINE';

  @override
  List<IndicatorLine> get lines => [const IndicatorLine('MINE')];

  @override
  List<Object?> get settings => const ['bespoke'];

  @override
  IndicatorSeries compute(List<KLineEntity> candles) =>
      IndicatorSeries([List<double?>.filled(candles.length, 1)]);

  @override
  Color defaultColor(int line, ChartColors theme, int ordinal) =>
      theme.ma5Color;
}
