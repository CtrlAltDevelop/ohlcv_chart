import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';

import '../heatmap/heatmap_data.dart';
import '../utils/plot_scaffold.dart';

/// A token the model could have written instead of the one it did.
@immutable
class TokenAlternative {
  /// Creates the alternative [token], which the model gave [probability].
  const TokenAlternative(this.token, this.probability);

  /// The alternative's text.
  final String token;

  /// The probability the model gave it, 0 to 1.
  final double probability;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenAlternative &&
          other.token == token &&
          other.probability == probability;

  @override
  int get hashCode => Object.hash(token, probability);
}

/// One token of a model's text, with a number that says something about it.
@immutable
class TokenScore {
  /// Creates a token [token] scored [value] — a surprisal, an entropy, an
  /// attribution, a probability.
  ///
  /// [probability] is the probability the model gave the token itself, and
  /// [alternatives] what else it was weighing, most likely first; both are for
  /// the readout.
  const TokenScore(
    this.token,
    this.value, {
    this.probability,
    this.alternatives = const [],
    this.data,
  });

  /// Creates a token from the log-probability the model gave it, scored as its
  /// surprisal `-logProb`: the less likely the model thought it, the higher.
  /// Its [probability] is `exp(logProb)`.
  factory TokenScore.fromLogProb(
    String token,
    double logProb, {
    List<TokenAlternative> alternatives = const [],
    Object? data,
  }) => TokenScore(
    token,
    -logProb,
    probability: logProb.isFinite ? math.exp(logProb) : null,
    alternatives: alternatives,
    data: data,
  );

  /// The token's text, as the tokenizer produced it. A newline in it ends the
  /// line.
  final String token;

  /// The score; a value that is not finite is left uncoloured.
  final double value;

  /// The probability the model gave this token, 0 to 1, if known.
  final double? probability;

  /// What else the model was weighing at this position, most likely first.
  final List<TokenAlternative> alternatives;

  /// Anything the app wants back when this token is touched.
  final Object? data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenScore &&
          other.token == token &&
          other.value == value &&
          other.probability == probability &&
          listEquals(other.alternatives, alternatives) &&
          other.data == data;

  @override
  int get hashCode => Object.hash(
    token,
    value,
    probability,
    Object.hashAll(alternatives),
    data,
  );
}

/// How [token] is written on screen.
///
/// A space is a no-break space, so the width of a leading space is kept, and a
/// newline is dropped. With [showWhitespace] a space is a `·` and a newline a
/// `↵`, so what the tokenizer really produced can be read.
String tokenDisplay(String token, {bool showWhitespace = false}) {
  final clean = token.replaceAll('\r', '');
  if (showWhitespace) {
    return clean.replaceAll(' ', '·').replaceAll('\n', '↵');
  }
  return clean.replaceAll('\n', '').replaceAll(' ', ' ');
}

/// The text of [token] without the space it begins with, as it is drawn inside
/// its box — the space is the gap before the box, not part of it.
///
/// Spaces inside the token are no-break ones, so they keep their width. With
/// [showWhitespace] nothing is trimmed: the spaces and line breaks are written
/// as `·` and `↵` inside the box.
String tokenText(String token, {bool showWhitespace = false}) {
  if (showWhitespace) return tokenDisplay(token, showWhitespace: true);
  return token
      .replaceAll('\r', '')
      .replaceAll('\n', '')
      .trim()
      .replaceAll(' ', '\u00A0');
}

/// How the colour of a token is drawn.
enum TokenShading {
  /// A tint of the colour behind the text, and a line of the full colour under
  /// it: the text stays easy to read, and the tokens stay apart.
  soft,

  /// The full colour behind the text, which turns dark or light to suit it.
  solid,
}

/// Where one token was laid out.
@immutable
class TokenBox {
  /// Creates the box of the token at [index].
  const TokenBox({required this.index, required this.rect});

  /// The token's position in the list it was given in.
  final int index;

  /// Where it sits, in the chart's local pixels.
  final Rect rect;
}

/// Flows [tokens] into lines no wider than [width], in the way text wraps.
///
/// [measure] gives the size of one token's text as it is displayed — see
/// [tokenDisplay] — so the layout can be worked out, and tested, without a
/// renderer. A token that contains a newline ends its line; one wider than a
/// whole line sits alone on its own. With [showWhitespace] a token that is only
/// a newline still takes a box, to show the `↵`. Returns the boxes and the
/// height the lines take.
({List<TokenBox> boxes, double height}) flowTokens(
  List<TokenScore> tokens,
  double width,
  Size Function(String token) measure, {
  double lineGap = 4,
  bool showWhitespace = false,
  bool trimSpaces = false,
  double horizontalPadding = 0,
  double wordGap = 0,
  double tokenGap = 0,
}) {
  final boxes = <TokenBox>[];
  var x = 0.0;
  var y = 0.0;
  var lineHeight = 0.0;
  var any = false;

  for (var i = 0; i < tokens.length; i++) {
    final raw = tokens[i].token;
    // With [trimSpaces] a leading space is the gap before the box rather than
    // a part of it, so the boxes of one word sit close and words sit apart.
    final text = trimSpaces
        ? tokenText(raw, showWhitespace: showWhitespace)
        : tokenDisplay(raw, showWhitespace: showWhitespace);
    final startsWord = trimSpaces && !showWhitespace && raw.startsWith(' ');
    final size = text.isEmpty ? const Size(0, 0) : measure(text);
    final h = size.height.isFinite ? size.height : 0.0;
    final w =
        (size.width.isFinite ? size.width : 0.0) +
        (text.isEmpty ? 0 : horizontalPadding * 2);
    final gap = x == 0 ? 0.0 : (startsWord ? wordGap : tokenGap);

    if (x > 0 && x + gap + w > width) {
      y += lineHeight + lineGap;
      x = 0;
      lineHeight = 0;
    } else {
      x += gap;
    }
    lineHeight = math.max(lineHeight, h);
    if (text.isNotEmpty) {
      boxes.add(TokenBox(index: i, rect: Rect.fromLTWH(x, y, w, h)));
      x += w;
      any = true;
    }
    if (tokens[i].token.contains('\n')) {
      y += (lineHeight > 0 ? lineHeight : h) + lineGap;
      x = 0;
      lineHeight = 0;
    }
  }
  final height = !any ? 0.0 : y + lineHeight;
  return (boxes: boxes, height: math.max(0, height));
}

/// The box under [local] among [boxes], or null.
TokenBox? tokenBoxAt(List<TokenBox> boxes, Offset local) {
  for (final box in boxes) {
    if (box.rect.contains(local)) return box;
  }
  return null;
}

/// What a list of token scores add up to.
@immutable
class TokenSummary {
  /// Creates a summary; see [summarizeTokens].
  const TokenSummary({
    required this.count,
    required this.mean,
    required this.max,
    required this.maxIndex,
  });

  /// How many tokens had a score.
  final int count;

  /// Their mean.
  final double mean;

  /// The highest.
  final double max;

  /// The index of the highest, or null with no score.
  final int? maxIndex;

  /// `exp(mean)` — the perplexity, when the scores are surprisals in nats.
  double get perplexity => math.exp(mean);
}

/// Summarises [tokens]: how many were scored, their mean, and the highest.
TokenSummary summarizeTokens(List<TokenScore> tokens) {
  var count = 0;
  var sum = 0.0;
  var max = double.negativeInfinity;
  int? at;
  for (var i = 0; i < tokens.length; i++) {
    final v = tokens[i].value;
    if (!v.isFinite) continue;
    count++;
    sum += v;
    if (v > max) {
      max = v;
      at = i;
    }
  }
  return TokenSummary(
    count: count,
    mean: count == 0 ? 0 : sum / count,
    max: count == 0 ? 0 : max,
    maxIndex: at,
  );
}

/// Each token's rank by score: 1 for the highest. Null for a token whose score
/// is not finite. Equal scores share the better rank.
List<int?> tokenRanks(List<TokenScore> tokens) {
  final values = [
    for (final t in tokens)
      if (t.value.isFinite) t.value,
  ]..sort((a, b) => b.compareTo(a));
  return [
    for (final t in tokens)
      if (!t.value.isFinite) null else values.indexOf(t.value) + 1,
  ];
}

/// The indices of the [count] highest-scoring tokens, highest first. Ties go to
/// the earlier token. Fewer when fewer have a score.
List<int> topTokens(List<TokenScore> tokens, int count) {
  if (count <= 0) return const [];
  final order =
      [
        for (var i = 0; i < tokens.length; i++)
          if (tokens[i].value.isFinite) i,
      ]..sort((a, b) {
        final c = tokens[b].value.compareTo(tokens[a].value);
        return c != 0 ? c : a.compareTo(b);
      });
  return order.take(count).toList();
}

/// The maximum score of each of [bins] equal slices of [tokens], in order —
/// what the strip over a long text draws. A slice with no score is null.
List<double?> binTokenScores(List<TokenScore> tokens, int bins) {
  if (bins <= 0) return const [];
  final out = List<double?>.filled(bins, null);
  if (tokens.isEmpty) return out;
  for (var i = 0; i < tokens.length; i++) {
    final v = tokens[i].value;
    if (!v.isFinite) continue;
    final bin = math.min(bins - 1, i * bins ~/ tokens.length);
    final current = out[bin];
    if (current == null || v > current) out[bin] = v;
  }
  return out;
}

/// What a touch on a [TokenHeatmap] landed on.
@immutable
class TokenTouchDetails {
  /// Creates the details of a touch on the token at [index].
  const TokenTouchDetails({
    required this.index,
    required this.token,
    required this.rect,
    required this.rank,
    required this.scored,
  });

  /// The token's position.
  final int index;

  /// The token.
  final TokenScore token;

  /// Where it was drawn, in the chart's local pixels.
  final Rect rect;

  /// Its rank by score among the tokens, 1 for the highest; null when it has
  /// none.
  final int? rank;

  /// How many tokens have a score.
  final int scored;
}

/// A model's text with each token shaded by a number — where it was unsure, what
/// a prediction leaned on.
///
/// ```dart
/// TokenHeatmap(
///   tokens: [
///     for (final t in completion.tokens)
///       TokenScore.fromLogProb(
///         t.text,
///         t.logProb,
///         alternatives: [
///           for (final a in t.topLogProbs)
///             TokenAlternative(a.text, exp(a.logProb)),
///         ],
///       ),
///   ],
///   highlightTop: 3,
///   showStrip: true,
/// );
/// ```
///
/// Tokens flow and wrap like text, each over a rectangle coloured by its score
/// on [scale]. Touching one opens a readout — its score, its rank, and what the
/// model was weighing instead — unless [tooltipBuilder] says otherwise. A
/// legend under the text runs from the lowest score to the highest, and a strip
/// above it shows the score of every token in order, which is how a long text is
/// read at a glance. The chart takes the height its text needs, unless the box it
/// is given is shorter, when the text is cut off.
class TokenHeatmap extends StatefulWidget {
  /// Creates a heatmap of [tokens].
  const TokenHeatmap({
    super.key,
    required this.tokens,
    this.scale = const HeatmapGradientScale(
      colors: [Color(0xFF2F9E44), Color(0xFFE8C547), Color(0xFFE03131)],
    ),
    this.minValue,
    this.maxValue,
    this.textStyle,
    this.shading = TokenShading.soft,
    this.tokenRadius = const BorderRadius.all(Radius.circular(5)),
    this.horizontalPadding = 5,
    this.verticalPadding = 4,
    this.wordGap = 7,
    this.tokenGap = 2,
    this.lineGap = 10,
    this.showWhitespace = false,
    this.focusAbove,
    this.dimColor = const Color(0xFF6B7480),
    this.highlightTop = 0,
    this.highlightColor = const Color(0xFFFFFFFF),
    this.selectedIndex,
    this.showStrip = false,
    this.stripHeight = 28,
    this.showLegend = true,
    this.lowLabel,
    this.highLabel,
    this.showSummary = false,
    this.summaryLabel = 'perplexity',
    this.legendStyle,
    this.valueFormatter,
    this.hoverBorder = const BorderSide(color: Color(0xFFFFFFFF), width: 1.5),
    this.showReadout = true,
    this.scoreLabel = 'surprisal',
    this.onTouch,
    this.tooltipBuilder,
    this.tooltipMargin = 8,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.semanticLabel,
  });

  /// The tokens, in order.
  final List<TokenScore> tokens;

  /// How a score becomes a colour.
  final HeatmapScale scale;

  /// The score painted in the scale's first colour; null takes the lowest.
  final double? minValue;

  /// The score painted in the scale's last colour; null takes the highest.
  final double? maxValue;

  /// Style of the text; null is 14 px, in the default font.
  final TextStyle? textStyle;

  /// How the colour is drawn: a soft tint with a line under the text, or the
  /// full colour behind it.
  final TokenShading shading;

  /// The rounding of each token's rectangle.
  final BorderRadius tokenRadius;

  /// Space to the left and right of a token's text inside its rectangle.
  final double horizontalPadding;

  /// The gap before a token that begins a word, where the tokenizer put a
  /// space.
  final double wordGap;

  /// The gap before a token that carries on a word.
  final double tokenGap;

  /// Space above and below a token's text inside its rectangle.
  final double verticalPadding;

  /// The gap between lines.
  final double lineGap;

  /// Whether spaces and line breaks are made visible, as `·` and `↵`, so that
  /// what the tokenizer produced can be read.
  final bool showWhitespace;

  /// A score below which a token is left unshaded and dimmed, so that only the
  /// doubtful ones are lit. Null shades every token.
  final double? focusAbove;

  /// The colour of the text of a token left out by [focusAbove].
  final Color dimColor;

  /// How many of the highest-scoring tokens are ringed and numbered, 1 for the
  /// highest; zero marks none.
  final int highlightTop;

  /// The colour of that ring.
  final Color highlightColor;

  /// A token to hold outlined whatever the pointer does — one the app has
  /// selected; null holds none.
  final int? selectedIndex;

  /// Whether a strip of every token's score, in order, is drawn above the
  /// legend. Over a text longer than the strip is wide, each bar is the highest
  /// of the tokens it covers.
  final bool showStrip;

  /// How tall the strip is.
  final double stripHeight;

  /// Whether the legend bar is drawn under the text.
  final bool showLegend;

  /// What the low end of the legend is called; null writes its value.
  final String? lowLabel;

  /// What the high end is called; null writes its value.
  final String? highLabel;

  /// Whether the mean, and the perplexity it implies, are written in the legend.
  final bool showSummary;

  /// What the summary calls `exp(mean)`.
  final String summaryLabel;

  /// Style of the legend.
  final TextStyle? legendStyle;

  /// Writes a score; null writes at most two decimals.
  final String Function(double value)? valueFormatter;

  /// Drawn round the token under the pointer; null marks none.
  final BorderSide? hoverBorder;

  /// Whether touching a token opens the built-in readout. Ignored when
  /// [tooltipBuilder] is given.
  final bool showReadout;

  /// What the score is called in the readout.
  final String scoreLabel;

  /// Called as a touch moves over the tokens, and with null when it leaves.
  final ValueChanged<TokenTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched token, in place of the readout.
  final Widget? Function(BuildContext context, TokenTouchDetails details)?
  tooltipBuilder;

  /// How far the card sits from the token.
  final double tooltipMargin;

  /// Space kept clear around the chart.
  final EdgeInsets padding;

  /// Painted behind the whole chart.
  final Color? backgroundColor;

  /// What a screen reader announces; null reads the text.
  final String? semanticLabel;

  @override
  State<TokenHeatmap> createState() => _TokenHeatmapState();
}

class _TokenHeatmapState extends State<TokenHeatmap> {
  // Measuring every token is the costly part, so the layout is kept until the
  // tokens, the width or the style change.
  List<TokenScore>? _flowTokens;
  double _flowWidth = -1;
  TextStyle? _flowStyle;
  double _flowPadding = -1;
  double _flowGap = -1;
  bool _flowWhitespace = false;
  double _flowHPad = -1;
  double _flowWord = -1;
  double _flowToken = -1;
  ({List<TokenBox> boxes, double height})? _flow;

  TextStyle get _style => const TextStyle(
    fontSize: 14,
    color: Color(0xFFE9ECEF),
  ).merge(widget.textStyle);

  ({List<TokenBox> boxes, double height}) _layOut(double width) {
    final style = _style;
    final pad = widget.verticalPadding;
    if (_flow != null &&
        identical(_flowTokens, widget.tokens) &&
        _flowWidth == width &&
        _flowStyle == style &&
        _flowPadding == pad &&
        _flowGap == widget.lineGap &&
        _flowWhitespace == widget.showWhitespace &&
        _flowHPad == widget.horizontalPadding &&
        _flowWord == widget.wordGap &&
        _flowToken == widget.tokenGap) {
      return _flow!;
    }
    final painter = TextPainter(textDirection: TextDirection.ltr);
    final result = flowTokens(
      widget.tokens,
      width,
      (text) {
        painter
          ..text = TextSpan(text: text, style: style)
          ..layout();
        return Size(painter.width, painter.height + pad * 2);
      },
      lineGap: widget.lineGap,
      showWhitespace: widget.showWhitespace,
      trimSpaces: true,
      horizontalPadding: widget.horizontalPadding,
      wordGap: widget.wordGap,
      tokenGap: widget.tokenGap,
    );
    painter.dispose();
    _flowTokens = widget.tokens;
    _flowWidth = width;
    _flowStyle = style;
    _flowPadding = pad;
    _flowGap = widget.lineGap;
    _flowWhitespace = widget.showWhitespace;
    _flowHPad = widget.horizontalPadding;
    _flowWord = widget.wordGap;
    _flowToken = widget.tokenGap;
    return _flow = result;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final summary = summarizeTokens(tokens);
    final finite = [
      for (final t in tokens)
        if (t.value.isFinite) t.value,
    ];
    final lo =
        widget.minValue ?? (finite.isEmpty ? 0.0 : finite.reduce(math.min));
    final hi =
        widget.maxValue ?? (finite.isEmpty ? 1.0 : finite.reduce(math.max));
    final ranks = tokenRanks(tokens);
    final top = topTokens(tokens, widget.highlightTop);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.maybeSizeOf(context)?.width ?? 400;
        final inner = math.max(0.0, width - widget.padding.horizontal);
        final flow = _layOut(inner);
        final stripHeight = widget.showStrip && tokens.isNotEmpty
            ? widget.stripHeight + 10
            : 0.0;
        final legendHeight = widget.showLegend
            ? (widget.showSummary ? 52.0 : 34.0)
            : 0.0;
        final wanted =
            widget.padding.vertical +
            flow.height +
            stripHeight +
            (widget.showLegend ? 12 : 0) +
            legendHeight;
        final height = constraints.hasBoundedHeight
            ? math.min(constraints.maxHeight, wanted)
            : wanted;

        TokenTouchDetails details(TokenBox box, Rect plot) => TokenTouchDetails(
          index: box.index,
          token: tokens[box.index],
          rect: box.rect.shift(plot.topLeft),
          rank: ranks[box.index],
          scored: summary.count,
        );

        TokenTouchDetails? hit(Offset local, Rect plot) {
          final box = tokenBoxAt(flow.boxes, local - plot.topLeft);
          return box == null ? null : details(box, plot);
        }

        final custom = widget.tooltipBuilder;
        return SizedBox(
          width: width,
          height: height,
          child: PlotScaffold<TokenTouchDetails>(
            restartKey: Object.hashAll(tokens),
            padding: widget.padding,
            backgroundColor: widget.backgroundColor,
            defaultHeight: height,
            semanticLabel:
                widget.semanticLabel ??
                tokens.map((t) => t.token).join().trim(),
            tooltipMargin: widget.tooltipMargin,
            onTouch: widget.onTouch,
            tooltipBuilder:
                custom ??
                (widget.showReadout
                    ? (context, d) => _Readout(
                        details: d,
                        scoreLabel: widget.scoreLabel,
                        format: _format,
                        scale: widget.scale,
                        low: lo,
                        high: hi,
                        showWhitespace: widget.showWhitespace,
                      )
                    : null),
            hitTest: hit,
            keyOf: (d) => d.index,
            anchorOf: (d, plot) => d.rect,
            painter: (plot, t, text, hovered) => _TokenPainter(
              chart: widget,
              boxes: flow.boxes,
              flowHeight: flow.height,
              style: _style,
              low: lo,
              high: hi,
              summary: summary,
              top: top,
              hovered: hovered?.index,
              plot: plot,
              animation: t,
              text: text,
              backgroundColor: widget.backgroundColor,
            ),
          ),
        );
      },
    );
  }

  String _format(double v) {
    if (widget.valueFormatter != null) return widget.valueFormatter!(v);
    final r = double.parse(v.toStringAsFixed(2));
    return r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toString();
  }
}

/// The card shown over a touched token: its text, its score, how it ranks, how
/// likely the model thought it, and what it was weighing instead.
class _Readout extends StatelessWidget {
  const _Readout({
    required this.details,
    required this.scoreLabel,
    required this.format,
    required this.scale,
    required this.low,
    required this.high,
    required this.showWhitespace,
  });

  final TokenTouchDetails details;
  final String scoreLabel;
  final String Function(double) format;
  final HeatmapScale scale;
  final double low;
  final double high;
  final bool showWhitespace;

  static String _percent(double p) {
    final v = p * 100;
    if (v >= 10) return '${v.toStringAsFixed(0)}%';
    if (v >= 1) return '${v.toStringAsFixed(1)}%';
    if (v > 0) return '<1%';
    return '0%';
  }

  @override
  Widget build(BuildContext context) {
    final token = details.token;
    const muted = Color(0xFF8B95A1);
    const text = Color(0xFFF1F3F5);
    final swatch = token.value.isFinite
        ? scale.colorAt(token.value, low, high)
        : scale.emptyColor;
    final shown = tokenDisplay(token.token, showWhitespace: true);

    final lines = <Widget>[
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: swatch,
              borderRadius: const BorderRadius.all(Radius.circular(2)),
            ),
            child: const SizedBox(width: 10, height: 10),
          ),
          const SizedBox(width: 6),
          Text(
            shown.isEmpty ? '∅' : shown,
            style: const TextStyle(
              color: text,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        token.value.isFinite
            ? '$scoreLabel ${format(token.value)}'
            : 'no $scoreLabel',
        style: const TextStyle(color: text, fontSize: 12),
      ),
      if (details.rank != null)
        Text(
          'rank ${details.rank} of ${details.scored}',
          style: const TextStyle(color: muted, fontSize: 11),
        ),
      if (token.probability != null)
        Text(
          'probability ${_percent(token.probability!)}',
          style: const TextStyle(color: muted, fontSize: 11),
        ),
    ];

    if (token.alternatives.isNotEmpty) {
      lines
        ..add(const SizedBox(height: 6))
        ..add(
          const Text('instead', style: TextStyle(color: muted, fontSize: 10)),
        );
      for (final a in token.alternatives.take(5)) {
        lines.add(
          Text(
            '${tokenDisplay(a.token, showWhitespace: true)}  '
            '${_percent(a.probability)}',
            style: const TextStyle(color: text, fontSize: 11),
          ),
        );
      }
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xF2161B22),
        borderRadius: BorderRadius.all(Radius.circular(6)),
        border: Border.fromBorderSide(BorderSide(color: Color(0x33FFFFFF))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lines,
        ),
      ),
    );
  }
}

class _TokenPainter extends PlotPainter {
  _TokenPainter({
    required this.chart,
    required this.boxes,
    required this.flowHeight,
    required this.style,
    required this.low,
    required this.high,
    required this.summary,
    required this.top,
    required this.hovered,
    required super.plot,
    required super.animation,
    required super.text,
    super.backgroundColor,
  });

  final TokenHeatmap chart;
  final List<TokenBox> boxes;
  final double flowHeight;
  final TextStyle style;
  final double low, high;
  final TokenSummary summary;
  final List<int> top;
  final int? hovered;

  String _format(double v) {
    if (chart.valueFormatter != null) return chart.valueFormatter!(v);
    final r = double.parse(v.toStringAsFixed(2));
    return r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toString();
  }

  @override
  void paintPlot(Canvas canvas, Size size) {
    canvas
      ..save()
      ..clipRect(Rect.fromLTWH(plot.left, plot.top, plot.width, plot.height));

    for (final box in boxes) {
      final token = chart.tokens[box.index];
      final rect = box.rect.shift(plot.topLeft);
      if (rect.top > plot.bottom) break;
      final scored = token.value.isFinite;
      final focused =
          chart.focusAbove == null ||
          (scored && token.value >= chart.focusAbove!);
      final rrect = chart.tokenRadius.toRRect(rect);
      final base = style.color ?? const Color(0xFFE9ECEF);

      var textColor = base;
      if (!focused) {
        textColor = chart.dimColor;
      } else if (scored) {
        final color = chart.scale.colorAt(token.value, low, high);
        if (chart.shading == TokenShading.soft) {
          // A tint behind the text, and a line of the full colour under it.
          canvas.drawRRect(
            rrect,
            Paint()
              ..color = color.withValues(alpha: 0.4)
              ..isAntiAlias = true,
          );
          canvas
            ..save()
            ..clipRRect(rrect)
            ..drawRect(
              Rect.fromLTWH(rect.left, rect.bottom - 3, rect.width, 3),
              Paint()..color = color,
            )
            ..restore();
        } else {
          canvas.drawRRect(
            rrect,
            Paint()
              ..color = color
              ..isAntiAlias = true,
          );
          // Dark text on a light colour, and the other way round.
          final opaque = Color.alphaBlend(color, const Color(0xFF161B22));
          textColor = opaque.computeLuminance() > 0.5
              ? const Color(0xFF10151C)
              : const Color(0xFFF1F3F5);
        }
      } else {
        // No score: a faint outline, so the token is still a token.
        canvas.drawRRect(
          rrect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = const Color(0x33FFFFFF)
            ..isAntiAlias = true,
        );
      }

      final shown = tokenText(
        token.token,
        showWhitespace: chart.showWhitespace,
      );
      final tp = text.get(shown, style.copyWith(color: textColor));
      tp.paint(
        canvas,
        Offset(
          rect.left + chart.horizontalPadding,
          rect.top + (rect.height - tp.height) / 2 - 1,
        ),
      );

      final hover = chart.hoverBorder;
      if (hovered == box.index && hover != null && hover.width > 0) {
        canvas.drawRRect(
          rrect.inflate(hover.width / 2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = hover.width
            ..color = hover.color
            ..isAntiAlias = true,
        );
      }
      if (chart.selectedIndex == box.index) {
        canvas.drawRRect(
          rrect.inflate(1.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = chart.highlightColor
            ..isAntiAlias = true,
        );
      }
    }

    canvas.restore();
    // After the clip: a badge on the first line sits partly above the text.
    _paintTop(canvas);

    var y = plot.top + flowHeight + 10;
    if (chart.showStrip && chart.tokens.isNotEmpty) {
      _strip(canvas, y);
      y += chart.stripHeight + 10;
    }
    if (chart.showLegend) _legend(canvas, y + 2);
  }

  /// A ring and a rank on each of the highest-scoring tokens.
  void _paintTop(Canvas canvas) {
    for (var rank = 0; rank < top.length; rank++) {
      final box = boxes.where((b) => b.index == top[rank]).firstOrNull;
      if (box == null) continue;
      final rect = box.rect.shift(plot.topLeft);
      canvas.drawRRect(
        chart.tokenRadius.toRRect(rect.deflate(0.5)).inflate(1.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = chart.highlightColor
          ..isAntiAlias = true,
      );
      final badge = text.get(
        '${rank + 1}',
        const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: Color(0xFF10151C),
        ),
      );
      final centre = Offset(rect.right - 1, rect.top + 1);
      canvas.drawCircle(
        centre,
        math.max(badge.width, badge.height) / 2 + 2,
        Paint()
          ..color = chart.highlightColor
          ..isAntiAlias = true,
      );
      badge.paint(canvas, centre - Offset(badge.width / 2, badge.height / 2));
    }
  }

  /// One bar per slice of the text, the height of its highest score.
  void _strip(Canvas canvas, double top) {
    final height = chart.stripHeight;
    final bins = math.max(1, math.min(chart.tokens.length, plot.width ~/ 4));
    final values = binTokenScores(chart.tokens, bins);
    final width = plot.width / bins;
    final range = high - low;

    canvas.drawRect(
      Rect.fromLTWH(plot.left, top, plot.width, height),
      Paint()..color = const Color(0x10FFFFFF),
    );
    for (var i = 0; i < bins; i++) {
      final v = values[i];
      if (v == null) continue;
      final f = range <= 0 ? 1.0 : ((v - low) / range).clamp(0.0, 1.0);
      final h = math.max(1.5, height * f);
      canvas.drawRect(
        Rect.fromLTWH(plot.left + i * width, top + height - h, width, h),
        Paint()..color = chart.scale.colorAt(v, low, high),
      );
    }

    final at = hovered;
    if (at != null && chart.tokens.isNotEmpty) {
      final bin = math.min(bins - 1, at * bins ~/ chart.tokens.length);
      canvas.drawRect(
        Rect.fromLTWH(
          plot.left + bin * width - 1,
          top - 2,
          width + 2,
          height + 4,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFFFFFFFF),
      );
    }
  }

  void _legend(Canvas canvas, double top) {
    if (top + 10 > plot.bottom + 40) return;
    const barHeight = 8.0;
    final barWidth = math.min(plot.width, 220.0);
    final bar = Rect.fromLTWH(plot.left, top, barWidth, barHeight);
    const steps = 32;
    for (var i = 0; i < steps; i++) {
      final f = i / (steps - 1);
      canvas.drawRect(
        Rect.fromLTWH(
          bar.left + bar.width * i / steps,
          bar.top,
          bar.width / steps + 0.5,
          barHeight,
        ),
        Paint()..color = chart.scale.colorAt(low + (high - low) * f, low, high),
      );
    }
    final labelStyle = const TextStyle(
      fontSize: 10,
      color: Color(0xFF8B95A1),
    ).merge(chart.legendStyle);
    final lowText = text.get(chart.lowLabel ?? _format(low), labelStyle);
    final highText = text.get(chart.highLabel ?? _format(high), labelStyle);
    lowText.paint(canvas, Offset(bar.left, bar.bottom + 3));
    highText.paint(canvas, Offset(bar.right - highText.width, bar.bottom + 3));

    // Where the mean falls on the scale.
    if (summary.count > 0 && high > low) {
      final f = ((summary.mean - low) / (high - low)).clamp(0.0, 1.0);
      final x = bar.left + bar.width * f;
      canvas.drawPath(
        Path()
          ..moveTo(x - 4, bar.top - 5)
          ..lineTo(x + 4, bar.top - 5)
          ..lineTo(x, bar.top - 1)
          ..close(),
        Paint()
          ..color = const Color(0xFFE9ECEF)
          ..isAntiAlias = true,
      );
    }

    if (chart.showSummary && summary.count > 0) {
      final tp = text.get(
        'mean ${_format(summary.mean)}  ·  ${chart.summaryLabel} '
        '${_format(summary.perplexity)}',
        labelStyle,
      );
      // Under the scale, where there is room however narrow the chart is.
      tp.paint(canvas, Offset(bar.left, bar.bottom + 20));
    }
  }
}
