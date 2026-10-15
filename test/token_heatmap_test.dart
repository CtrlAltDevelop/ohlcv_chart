import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ohlcv_chart/ohlcv_chart.dart';

/// Ten pixels a character, twenty high.
Size _measure(String token) => Size(token.length * 10.0, 20);

List<TokenScore> _tokens(List<String> words) => [
  for (final w in words) TokenScore(w, 1),
];

void main() {
  group('flowing tokens', () {
    test('sit side by side until the line is full', () {
      final flow = flowTokens(_tokens(['aaaa', 'bbbb', 'cc']), 100, _measure);

      expect(flow.boxes[0].rect, const Rect.fromLTWH(0, 0, 40, 20));
      expect(flow.boxes[1].rect, const Rect.fromLTWH(40, 0, 40, 20));
      // Eighty used; two more characters fit exactly.
      expect(flow.boxes[2].rect, const Rect.fromLTWH(80, 0, 20, 20));
      expect(flow.height, 20);
    });

    test('wrap to the next line when a token does not fit', () {
      final flow = flowTokens(
        _tokens(['aaaa', 'bbbb', 'cccc']),
        100,
        _measure,
        lineGap: 4,
      );

      expect(flow.boxes[2].rect, const Rect.fromLTWH(0, 24, 40, 20));
      expect(flow.height, 44);
    });

    test('a newline ends the line, and is not drawn', () {
      final flow = flowTokens(
        [const TokenScore('a\n', 1), const TokenScore('b', 1)],
        200,
        _measure,
        lineGap: 4,
      );

      expect(flow.boxes[0].rect.width, 10);
      expect(flow.boxes[1].rect.top, 24);
      expect(flow.boxes[1].rect.left, 0);
    });

    test('a blank line has a height of its own', () {
      final flow = flowTokens(
        [
          const TokenScore('a\n', 1),
          const TokenScore('\n', 1),
          const TokenScore('b', 1),
        ],
        200,
        _measure,
        lineGap: 4,
      );

      expect(flow.boxes, hasLength(2));
      expect(flow.boxes[1].rect.top, greaterThan(24));
    });

    test('a token wider than the line sits alone', () {
      final flow = flowTokens(
        _tokens(['a', 'bbbbbbbbbbbb', 'c']),
        50,
        _measure,
      );

      expect(flow.boxes[1].rect.left, 0);
      expect(flow.boxes[1].rect.top, greaterThan(0));
      expect(flow.boxes[2].rect.top, greaterThan(flow.boxes[1].rect.top));
    });

    test('indices point back at the tokens, skipping empty ones', () {
      final flow = flowTokens(_tokens(['a', '', 'b']), 100, _measure);

      expect([for (final b in flow.boxes) b.index], [0, 2]);
    });

    test('nothing is no height', () {
      expect(flowTokens(const [], 100, _measure).height, 0);
      expect(flowTokens(const [], 100, _measure).boxes, isEmpty);
    });

    test('a size that is not finite is read as zero', () {
      final flow = flowTokens(
        _tokens(['a']),
        100,
        (_) => const Size(double.nan, double.infinity),
      );

      expect(flow.boxes.single.rect.width, 0);
    });

    test('a box is found by position', () {
      final flow = flowTokens(_tokens(['aaaa', 'bbbb']), 100, _measure);

      expect(tokenBoxAt(flow.boxes, const Offset(50, 5))?.index, 1);
      expect(tokenBoxAt(flow.boxes, const Offset(95, 5)), isNull);
    });
  });

  group('scores', () {
    test('a log-probability is scored as its surprisal', () {
      final t = TokenScore.fromLogProb('the', -2.5);

      expect(t.value, 2.5);
    });

    test('the summary has a mean, a maximum and its place', () {
      final s = summarizeTokens(const [
        TokenScore('a', 1),
        TokenScore('b', 5),
        TokenScore('c', double.nan),
        TokenScore('d', 3),
      ]);

      expect(s.count, 3);
      expect(s.mean, closeTo(3, 1e-9));
      expect(s.max, 5);
      expect(s.maxIndex, 1);
      expect(s.perplexity, closeTo(math.exp(3), 1e-9));
    });

    test('with nothing scored the summary is empty', () {
      final s = summarizeTokens(const [TokenScore('a', double.nan)]);

      expect(s.count, 0);
      expect(s.maxIndex, isNull);
      expect(summarizeTokens(const []).count, 0);
    });
  });

  group('the widget', () {
    Widget host(Widget chart, {double height = 200}) => MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 400, height: height, child: chart),
      ),
    );

    testWidgets('reports the token under the pointer', (tester) async {
      TokenTouchDetails? touched;
      await tester.pumpWidget(
        host(
          TokenHeatmap(
            tokens: const [
              TokenScore('The', 0.2),
              TokenScore(' capital', 1.1),
              TokenScore(' is', 0.1),
              TokenScore(' Paris', 4.2),
            ],
            onTouch: (d) => touched = d,
          ),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      final origin = tester.getTopLeft(find.byType(TokenHeatmap));
      // Inside the first token's rectangle.
      await gesture.moveTo(origin + const Offset(3, 8));

      expect(touched, isNotNull);
      expect(touched!.index, 0);
      expect(touched!.token.token, 'The');

      await gesture.moveTo(origin + const Offset(390, 150));
      expect(touched, isNull);
    });

    testWidgets('takes the height its text needs in a box with no height', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                TokenHeatmap(
                  tokens: [
                    for (var i = 0; i < 80; i++) TokenScore(' word$i', i / 10),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(TokenHeatmap));
      expect(size.height, greaterThan(40));
      expect(tester.takeException(), isNull);
    });

    testWidgets('survives nothing, unscored tokens and a tiny box', (
      tester,
    ) async {
      await tester.pumpWidget(host(const TokenHeatmap(tokens: [])));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        host(
          const TokenHeatmap(
            tokens: [
              TokenScore('a', double.nan),
              TokenScore('\n', double.infinity),
              TokenScore('b', 1),
            ],
            showSummary: true,
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        host(
          const TokenHeatmap(tokens: [TokenScore('hello world', 1)]),
          height: 4,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
