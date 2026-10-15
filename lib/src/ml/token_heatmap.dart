import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../heatmap/heatmap_data.dart';
import '../utils/plot_scaffold.dart';

/// One token of a model's text, with a number that says something about it.
@immutable
class TokenScore {
  /// Creates a token [token] scored [value] — a surprisal, an entropy, an
  /// attribution, a probability.
  const TokenScore(this.token, this.value, {this.data});

  /// Creates a token from the log-probability the model gave it, scored as its
  /// surprisal `-logProb`: the less likely the model thought it, the higher.
  factory TokenScore.fromLogProb(
    String token,
    double logProb, {
    Object? data,
  }) => TokenScore(token, -logProb, data: data);

  /// The token's text, as the tokenizer produced it. A newline in it ends the
  /// line.
  final String token;

  /// The score; a value that is not finite is left uncoloured.
  final double value;

  /// Anything the app wants back when this token is touched.
  final Object? data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenScore &&
          other.token == token &&
          other.value == value &&
          other.data == data;

  @override
  int get hashCode => Object.hash(token, value, data);
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
/// [measure] gives the size of one token's text, so the layout can be worked
/// out — and tested — without a renderer. A token that contains a newline ends
/// its line; one wider than a whole line sits alone on its own. Returns the
/// boxes and the height the lines take.
({List<TokenBox> boxes, double height}) flowTokens(
  List<TokenScore> tokens,
  double width,
  Size Function(String token) measure, {
  double lineGap = 4,
}) {
  final boxes = <TokenBox>[];
  var x = 0.0;
  var y = 0.0;
  var lineHeight = 0.0;
  var any = false;

  for (var i = 0; i < tokens.length; i++) {
    final text = tokens[i].token.replaceAll('\n', '').replaceAll('\r', '');
    final size = text.isEmpty ? const Size(0, 0) : measure(text);
    final h = size.height.isFinite ? size.height : 0.0;
    final w = size.width.isFinite ? size.width : 0.0;

    if (x > 0 && x + w > width) {
      y += lineHeight + lineGap;
      x = 0;
      lineHeight = 0;
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

/// What a touch on a [TokenHeatmap] landed on.
@immutable
class TokenTouchDetails {
  /// Creates the details of a touch on the token at [index].
  const TokenTouchDetails({
    required this.index,
    required this.token,
    required this.rect,
  });

  /// The token's position.
  final int index;

  /// The token.
  final TokenScore token;

  /// Where it was drawn, in the chart's local pixels.
  final Rect rect;
}

/// A model's text with each token shaded by a number — where it was unsure, what
/// a prediction leaned on.
///
/// ```dart
/// TokenHeatmap(
///   tokens: [
///     for (final t in completion.tokens)
///       TokenScore.fromLogProb(t.text, t.logProb),
///   ],
/// );
/// ```
///
/// Tokens flow and wrap like text, each over a rectangle coloured by its score
/// on [scale]; a legend under them runs from the lowest score to the highest.
/// The chart takes the height its text needs, unless the box it is given is
/// shorter, when the text is cut off.
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
    this.tokenRadius = const BorderRadius.all(Radius.circular(3)),
    this.verticalPadding = 3,
    this.lineGap = 4,
    this.showLegend = true,
    this.lowLabel,
    this.highLabel,
    this.showSummary = false,
    this.summaryLabel = 'perplexity',
    this.legendStyle,
    this.valueFormatter,
    this.hoverBorder = const BorderSide(color: Color(0xFFFFFFFF), width: 1.5),
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

  /// The rounding of each token's rectangle.
  final BorderRadius tokenRadius;

  /// Space above and below a token's text inside its rectangle.
  final double verticalPadding;

  /// The gap between lines.
  final double lineGap;

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

  /// Called as a touch moves over the tokens, and with null when it leaves.
  final ValueChanged<TokenTouchDetails?>? onTouch;

  /// Builds a card shown beside the touched token; null shows none.
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
  ({List<TokenBox> boxes, double height})? _flow;

  static const _space = ' ';

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
        _flowPadding == pad) {
      return _flow!;
    }
    final painter = TextPainter(textDirection: TextDirection.ltr);
    final result = flowTokens(widget.tokens, width, (token) {
      painter
        ..text = TextSpan(text: token.replaceAll(' ', _space), style: style)
        ..layout();
      return Size(painter.width, painter.height + pad * 2);
    }, lineGap: widget.lineGap);
    painter.dispose();
    _flowTokens = widget.tokens;
    _flowWidth = width;
    _flowStyle = style;
    _flowPadding = pad;
    return _flow = result;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final summary = summarizeTokens(tokens);
    var low = widget.minValue;
    var high = widget.maxValue;
    low ??= tokens.any((t) => t.value.isFinite)
        ? tokens
              .where((t) => t.value.isFinite)
              .map((t) => t.value)
              .reduce(math.min)
        : 0;
    high ??= tokens.any((t) => t.value.isFinite)
        ? tokens
              .where((t) => t.value.isFinite)
              .map((t) => t.value)
              .reduce(math.max)
        : 1;
    final lo = low;
    final hi = high;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.maybeSizeOf(context)?.width ?? 400;
        final inner = math.max(0.0, width - widget.padding.horizontal);
        final flow = _layOut(inner);
        final legendHeight = widget.showLegend ? 34.0 : 0.0;
        final wanted =
            widget.padding.vertical +
            flow.height +
            (widget.showLegend ? 12 : 0) +
            legendHeight;
        final height = constraints.hasBoundedHeight
            ? math.min(constraints.maxHeight, wanted)
            : wanted;

        TokenTouchDetails? hit(Offset local, Rect plot) {
          final box = tokenBoxAt(flow.boxes, local - plot.topLeft);
          if (box == null) return null;
          return TokenTouchDetails(
            index: box.index,
            token: tokens[box.index],
            rect: box.rect.shift(plot.topLeft),
          );
        }

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
            tooltipBuilder: widget.tooltipBuilder,
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
      final color = scored
          ? chart.scale.colorAt(token.value, low, high)
          : chart.scale.emptyColor;
      final rrect = chart.tokenRadius.toRRect(rect);
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = color
          ..isAntiAlias = true,
      );

      // Dark text on a light colour, and the other way round.
      final opaque = Color.alphaBlend(color, const Color(0xFF161B22));
      final onColor = opaque.computeLuminance() > 0.5
          ? const Color(0xFF10151C)
          : const Color(0xFFF1F3F5);
      final tp = text.get(
        token.token
            .replaceAll('\n', '')
            .replaceAll('\r', '')
            .replaceAll(' ', ' '),
        style.copyWith(color: scored ? onColor : style.color),
      );
      tp.paint(
        canvas,
        Offset(rect.left, rect.top + (rect.height - tp.height) / 2),
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
    }
    canvas.restore();

    if (chart.showLegend) _legend(canvas);
  }

  void _legend(Canvas canvas) {
    final top = plot.top + flowHeight + 12;
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

    if (chart.showSummary && summary.count > 0) {
      final tp = text.get(
        'mean ${_format(summary.mean)}  ·  ${chart.summaryLabel} '
        '${_format(summary.perplexity)}',
        labelStyle,
      );
      tp.paint(canvas, Offset(bar.right + 16, bar.top - 2));
    }
  }
}
