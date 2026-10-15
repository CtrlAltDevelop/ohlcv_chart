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

  group('displaying a token', () {
    test('keeps a leading space as a no-break one, and drops the newline', () {
      expect(tokenDisplay(' the\n'), '\u00A0the');
    });

    test('can show the whitespace as it is', () {
      expect(tokenDisplay(' a b\n', showWhitespace: true), '·a·b↵');
    });

    test('a token of only a newline takes a box when whitespace is shown', () {
      final tokens = [const TokenScore('a', 1), const TokenScore('\n', 1)];

      expect(flowTokens(tokens, 100, _measure).boxes, hasLength(1));
      expect(
        flowTokens(tokens, 100, _measure, showWhitespace: true).boxes,
        hasLength(2),
      );
    });
  });

  group('the spacing', () {
    // Ten pixels a character, so padding and gaps are easy to read off.
    final tokens = [
      const TokenScore('The', 1),
      const TokenScore(' cap', 1),
      const TokenScore('ital', 1),
    ];

    test('a leading space is the gap before the box, not part of it', () {
      final flow = flowTokens(
        tokens,
        500,
        _measure,
        trimSpaces: true,
        horizontalPadding: 5,
        wordGap: 8,
        tokenGap: 2,
      );

      // "The": 30 + 10 padding. " cap" starts a word, so 8 px after it.
      expect(flow.boxes[0].rect, const Rect.fromLTWH(0, 0, 40, 20));
      expect(flow.boxes[1].rect.left, 48);
      expect(flow.boxes[1].rect.width, 40);
      // "ital" carries the word on: 2 px after "cap".
      expect(flow.boxes[2].rect.left, 90);
    });

    test('no gap is left at the start of a line', () {
      final flow = flowTokens(
        tokens,
        60,
        _measure,
        trimSpaces: true,
        horizontalPadding: 5,
        wordGap: 8,
        tokenGap: 2,
      );

      // " cap" does not fit after "The", so it begins the next line flush left.
      expect(flow.boxes[1].rect.left, 0);
      expect(flow.boxes[1].rect.top, greaterThan(0));
    });

    test('tokenText has no leading space, and keeps inner ones', () {
      expect(tokenText(' hello world\n'), 'hello\u00A0world');
      expect(tokenText(' a', showWhitespace: true), '·a');
    });

    test('the defaults leave tokens as they were', () {
      final flow = flowTokens(tokens, 500, _measure);

      expect(flow.boxes[1].rect.left, 30);
    });
  });

  group('ranks', () {
    test('rank by score, highest first, equal scores sharing a rank', () {
      final ranks = tokenRanks(const [
        TokenScore('a', 1),
        TokenScore('b', 5),
        TokenScore('c', 5),
        TokenScore('d', 3),
        TokenScore('e', double.nan),
      ]);

      expect(ranks, [4, 1, 1, 3, null]);
    });

    test('the top tokens are the highest, earlier first on a tie', () {
      final top = topTokens(const [
        TokenScore('a', 1),
        TokenScore('b', 5),
        TokenScore('c', 5),
        TokenScore('d', 3),
        TokenScore('e', double.nan),
      ], 3);

      expect(top, [1, 2, 3]);
      expect(topTokens(const [TokenScore('a', 1)], 0), isEmpty);
      expect(topTokens(const [TokenScore('a', 1)], 5), [0]);
    });
  });

  group('the strip', () {
    test('takes the highest score of each slice', () {
      final bins = binTokenScores([
        for (final v in [1.0, 4.0, 2.0, 2.0, 9.0, 1.0]) TokenScore('t', v),
      ], 3);

      expect(bins, [4.0, 2.0, 9.0]);
    });

    test('has fewer bins than tokens when there are fewer tokens', () {
      final bins = binTokenScores(const [TokenScore('a', 1)], 4);

      expect(bins.where((b) => b != null), hasLength(1));
    });

    test('a slice with nothing scored is null', () {
      final bins = binTokenScores(const [
        TokenScore('a', double.nan),
        TokenScore('b', 2),
      ], 2);

      expect(bins, [null, 2.0]);
      expect(binTokenScores(const [], 3), [null, null, null]);
      expect(binTokenScores(const [TokenScore('a', 1)], 0), isEmpty);
    });
  });

  group('scores', () {
    test('a log-probability gives the probability too', () {
      final t = TokenScore.fromLogProb('the', -0.6931471805599453);

      expect(t.probability, closeTo(0.5, 1e-9));
    });

    test('tokens with the same alternatives are equal', () {
      const a = TokenScore('x', 1, alternatives: [TokenAlternative('y', 0.2)]);
      const b = TokenScore('x', 1, alternatives: [TokenAlternative('y', 0.2)]);
      const c = TokenScore('x', 1, alternatives: [TokenAlternative('z', 0.2)]);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

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

    testWidgets('opens a readout with the score, rank and alternatives', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          TokenHeatmap(
            tokens: [
              const TokenScore('The', 0.2),
              TokenScore.fromLogProb(
                ' Paris',
                -2.3,
                alternatives: const [
                  TokenAlternative(' Lyon', 0.4),
                  TokenAlternative(' Nice', 0.05),
                ],
              ),
            ],
          ),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      final origin = tester.getTopLeft(find.byType(TokenHeatmap));
      // Past "The", inside " Paris".
      await gesture.moveTo(origin + const Offset(60, 8));
      await tester.pump();

      expect(find.text('·Paris'), findsOneWidget);
      expect(find.textContaining('rank 1 of 2'), findsOneWidget);
      expect(find.textContaining('probability 10%'), findsOneWidget);
      expect(find.text('instead'), findsOneWidget);
      expect(find.textContaining('Lyon'), findsOneWidget);
      expect(find.textContaining('40%'), findsOneWidget);
    });

    testWidgets('the readout can be turned off, or replaced', (tester) async {
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: const Offset(399, 299));
      addTearDown(gesture.removePointer);

      Future<void> hover() async {
        final origin = tester.getTopLeft(find.byType(TokenHeatmap));
        await gesture.moveTo(origin + const Offset(3, 8));
        await tester.pump();
      }

      await tester.pumpWidget(
        host(
          const TokenHeatmap(
            tokens: [TokenScore('Hello', 1)],
            showReadout: false,
          ),
        ),
      );
      await hover();
      expect(find.textContaining('surprisal'), findsNothing);

      // Off the token and back on, so the new chart sees a fresh hover.
      await gesture.moveTo(const Offset(399, 299));
      await tester.pumpWidget(
        host(
          TokenHeatmap(
            tokens: const [TokenScore('Hello', 1)],
            tooltipBuilder: (context, d) => const Text('mine'),
          ),
        ),
      );
      await hover();
      expect(find.text('mine'), findsOneWidget);
    });

    testWidgets('a readout wider than the chart shrinks to fit it', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 60,
                height: 120,
                child: TokenHeatmap(
                  tokens: [
                    TokenScore.fromLogProb(
                      'tokenizer',
                      -3,
                      alternatives: const [
                        TokenAlternative(' another long alternative', 0.3),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(const Offset(5, 8));
      await tester.pump();

      expect(find.text('instead'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a strip adds height, and the extras draw', (tester) async {
      Future<double> heightOf(TokenHeatmap chart) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: ListView(children: [chart])),
          ),
        );
        return tester.getSize(find.byType(TokenHeatmap)).height;
      }

      final tokens = [
        for (var i = 0; i < 30; i++) TokenScore(' w$i', (i % 7).toDouble()),
      ];
      final plain = await heightOf(TokenHeatmap(tokens: tokens));
      final strip = await heightOf(
        TokenHeatmap(tokens: tokens, showStrip: true),
      );
      expect(strip, greaterThan(plain));

      await tester.pumpWidget(
        host(
          TokenHeatmap(
            tokens: tokens,
            showStrip: true,
            highlightTop: 3,
            focusAbove: 4,
            showWhitespace: true,
            selectedIndex: 5,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
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
