import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../renderer/text_painter_cache.dart';

/// One tile of a [SparklineGrid] — a name and a little line.
@immutable
class SparklineTile {
  /// Creates a tile called [label] drawn from [values].
  const SparklineTile({
    required this.label,
    required this.values,
    this.color,
    this.valueLabel,
    this.subtitle,
    this.tooltip,
  });

  /// What the tile is called — the symbol, the account, the strategy.
  final String label;

  /// The line, oldest first. Non-finite values are breaks in it.
  final List<double> values;

  /// What the line is painted in; null takes the chart's rise or fall colour
  /// by which way the series went.
  final Color? color;

  /// Written at the right of the tile; null writes the last value.
  final String? valueLabel;

  /// Written under the label — the change, the venue, whatever else.
  final String? subtitle;

  /// Shown when the tile is touched; null shows its label and last value.
  final String? tooltip;

  /// Its first finite value; null when it has none.
  double? get first {
    for (final value in values) {
      if (value.isFinite) return value;
    }
    return null;
  }

  /// Its last finite value; null when it has none.
  double? get last {
    for (final value in values.reversed) {
      if (value.isFinite) return value;
    }
    return null;
  }

  /// How far it moved from its first value to its last, as a share of the
  /// first; null when either end is missing or the first is zero.
  double? get change {
    final from = first, to = last;
    if (from == null || to == null || from == 0) return null;
    return (to - from) / from.abs();
  }

  /// Whether it ended at or above where it started.
  bool get rose {
    final from = first, to = last;
    if (from == null || to == null) return true;
    return to >= from;
  }
}

/// Where one tile of a [SparklineGrid] sits.
@immutable
class SparklineTileLayout {
  /// Creates the layout of the tile at [index].
  const SparklineTileLayout({
    required this.index,
    required this.tile,
    required this.rect,
    required this.labelRect,
    required this.sparkRect,
    required this.valueRect,
    required this.points,
    required this.min,
    required this.max,
  });

  /// Which tile this is, into the grid's tiles.
  final int index;

  /// The tile itself.
  final SparklineTile tile;

  /// The whole tile.
  final Rect rect;

  /// Where its name is written.
  final Rect labelRect;

  /// Where its line is drawn.
  final Rect sparkRect;

  /// Where its value is written.
  final Rect valueRect;

  /// Its line, a point per value; null where the value was not finite.
  final List<Offset?> points;

  /// The smallest value the line was scaled to.
  final double min;

  /// The largest.
  final double max;

  /// The line's last drawn point, for a dot at its end.
  Offset? get lastPoint {
    for (final at in points.reversed) {
      if (at != null) return at;
    }
    return null;
  }
}

/// Where every tile of a [SparklineGrid] sits.
@immutable
class SparklineGridLayout {
  /// Creates a laid-out grid.
  const SparklineGridLayout({
    required this.size,
    required this.tiles,
    required this.columns,
    required this.rows,
  });

  /// Nothing to draw.
  static const empty = SparklineGridLayout(
    size: Size.zero,
    tiles: [],
    columns: 0,
    rows: 0,
  );

  /// The box the grid was laid out in.
  final Size size;

  /// The tiles, in the order they were given.
  final List<SparklineTileLayout> tiles;

  /// How many tiles across.
  final int columns;

  /// How many rows of them.
  final int rows;

  /// Whether there is anything to draw.
  bool get isEmpty => tiles.isEmpty;

  /// The tile under [point]; null when none is.
  SparklineTileLayout? tileAt(Offset point) {
    for (final tile in tiles) {
      if (tile.rect.contains(point)) return tile;
    }
    return null;
  }

  /// Where in [tile]'s series [point] falls, as an index; null when the point
  /// is not over the tile's line.
  int? sampleAt(SparklineTileLayout tile, Offset point) {
    if (tile.points.isEmpty) return null;
    if (tile.points.length == 1) return 0;
    final width = tile.sparkRect.width;
    if (!(width > 0)) return 0;
    final fraction = ((point.dx - tile.sparkRect.left) / width).clamp(0.0, 1.0);
    return (fraction * (tile.points.length - 1)).round();
  }
}

/// Lays out [tiles] as a grid of [columns] in [size].
///
/// Every tile is scaled to its own series, which is the point of small
/// multiples: the shape of each line is what is being compared, not its level.
/// Pass [sharedScale] to put them all on one scale instead.
///
/// [progress] reveals each line left to right, for a draw-in animation.
SparklineGridLayout layOutSparklineGrid(
  List<SparklineTile> tiles, {
  required Size size,
  int columns = 2,
  double tileHeight = 48,
  double tileGap = 8,
  double labelWidth = 64,
  double valueWidth = 56,
  double sparkPadding = 4,
  bool sharedScale = false,
  EdgeInsets padding = EdgeInsets.zero,
  double progress = 1,
}) {
  if (tiles.isEmpty || columns <= 0) return SparklineGridLayout.empty;
  final box = padding.deflateRect(Offset.zero & size);
  if (box.width <= 0 || box.height <= 0) return SparklineGridLayout.empty;

  final rows = (tiles.length / columns).ceil();
  final tileWidth = (box.width - tileGap * (columns - 1)) / columns;
  if (!(tileWidth > 0)) return SparklineGridLayout.empty;

  double? sharedMin, sharedMax;
  if (sharedScale) {
    var lo = double.infinity, hi = double.negativeInfinity;
    for (final tile in tiles) {
      for (final value in tile.values) {
        if (!value.isFinite) continue;
        lo = math.min(lo, value);
        hi = math.max(hi, value);
      }
    }
    if (lo.isFinite && hi.isFinite) {
      sharedMin = lo;
      sharedMax = hi;
    }
  }

  final t = progress.clamp(0.0, 1.0);
  final laid = <SparklineTileLayout>[];
  for (var i = 0; i < tiles.length; i++) {
    final tile = tiles[i];
    final column = i % columns;
    final row = i ~/ columns;
    final rect = Rect.fromLTWH(
      box.left + column * (tileWidth + tileGap),
      box.top + row * (tileHeight + tileGap),
      tileWidth,
      tileHeight,
    );

    final labels = math.min(labelWidth, rect.width * 0.5);
    final values = math.min(valueWidth, rect.width * 0.4);
    final spark = Rect.fromLTRB(
      rect.left + labels,
      rect.top + sparkPadding,
      math.max(rect.left + labels, rect.right - values),
      rect.bottom - sparkPadding,
    );

    var low = sharedMin, high = sharedMax;
    if (low == null || high == null) {
      var lo = double.infinity, hi = double.negativeInfinity;
      for (final value in tile.values) {
        if (!value.isFinite) continue;
        lo = math.min(lo, value);
        hi = math.max(hi, value);
      }
      low = lo;
      high = hi;
    }
    if (!low.isFinite || !high.isFinite) {
      low = 0;
      high = 1;
    }
    // A flat line sits in the middle of its tile rather than on an edge.
    if (!(high > low)) {
      final pad = math.max(1e-9, low.abs() * 0.05);
      low -= pad;
      high += pad;
    }

    final shown = spark.left + spark.width * t;
    final points = <Offset?>[];
    for (var v = 0; v < tile.values.length; v++) {
      final value = tile.values[v];
      final x = tile.values.length == 1
          ? spark.center.dx
          : spark.left + spark.width * v / (tile.values.length - 1);
      if (!value.isFinite || x > shown + 0.001) {
        points.add(null);
        continue;
      }
      final fraction = ((value - low) / (high - low)).clamp(0.0, 1.0);
      points.add(Offset(x, spark.bottom - fraction * spark.height));
    }

    laid.add(
      SparklineTileLayout(
        index: i,
        tile: tile,
        rect: rect,
        labelRect: Rect.fromLTWH(rect.left, rect.top, labels, rect.height),
        sparkRect: spark,
        valueRect: Rect.fromLTRB(
          spark.right,
          rect.top,
          rect.right,
          rect.bottom,
        ),
        points: points,
        min: low,
        max: high,
      ),
    );
  }

  return SparklineGridLayout(
    size: size,
    tiles: laid,
    columns: columns,
    rows: rows,
  );
}

/// Dozens of little charts in one table — small multiples.
///
/// A watchlist, a book of accounts, every strategy in a portfolio: one row
/// each, a name, its shape and its number. Every tile is scaled to its own
/// series, so what is compared is the shape of the line, not its level.
///
/// ```dart
/// SparklineGrid(
///   columns: 2,
///   tiles: [
///     SparklineTile(label: 'BTC', values: btcCloses),
///     SparklineTile(label: 'ETH', values: ethCloses),
///   ],
/// );
/// ```
class SparklineGrid extends StatefulWidget {
  /// Creates a grid of [tiles].
  const SparklineGrid({
    super.key,
    required this.tiles,
    this.columns = 1,
    this.tileHeight = 48,
    this.tileGap = 8,
    this.labelWidth = 64,
    this.valueWidth = 56,
    this.sparkPadding = 4,
    this.sharedScale = false,
    this.riseColor = const Color(0xFF2F9E44),
    this.fallColor = const Color(0xFFE03131),
    this.lineWidth = 1.5,
    this.fillOpacity = 0.12,
    this.showEndDot = true,
    this.endDotRadius = 2.5,
    this.showBaseline = false,
    this.baselineColor = const Color(0x22909196),
    this.labelStyle,
    this.subtitleStyle,
    this.valueStyle,
    this.valueFormatter,
    this.tileColor,
    this.highlightColor = const Color(0x14FFFFFF),
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.animationDuration = Duration.zero,
    this.animationCurve = Curves.easeOutCubic,
    this.animateOnMount = true,
    this.onTileTap,
    this.tooltipBuilder,
    this.semanticLabel,
  });

  /// The tiles, filled left to right and then down.
  final List<SparklineTile> tiles;

  /// How many tiles across.
  final int columns;

  /// How tall one tile is.
  final double tileHeight;

  /// Space between neighbouring tiles.
  final double tileGap;

  /// How wide the label column of a tile is.
  final double labelWidth;

  /// How wide its value column is.
  final double valueWidth;

  /// Space kept clear above and below a line inside its tile.
  final double sparkPadding;

  /// Whether every tile shares one scale rather than taking its own.
  final bool sharedScale;

  /// What a line that ended up is painted in.
  final Color riseColor;

  /// What a line that ended down is painted in.
  final Color fallColor;

  /// How thick the lines are.
  final double lineWidth;

  /// How solid the wash under a line is; 0 draws none.
  final double fillOpacity;

  /// Whether a dot marks the end of each line.
  final bool showEndDot;

  /// How large that dot is.
  final double endDotRadius;

  /// Whether a line is drawn at each tile's first value, to read the move
  /// against.
  final bool showBaseline;

  /// What that line is painted in.
  final Color baselineColor;

  /// Style of the tile names.
  final TextStyle? labelStyle;

  /// Style of the subtitles under them.
  final TextStyle? subtitleStyle;

  /// Style of the values at the right.
  final TextStyle? valueStyle;

  /// Writes a tile's value; null writes its last value.
  final String Function(SparklineTile tile)? valueFormatter;

  /// Painted behind each tile; null paints none.
  final Color? tileColor;

  /// Painted over the tile under the finger.
  final Color highlightColor;

  /// Space kept clear around the grid.
  final EdgeInsets padding;

  /// Painted behind the whole grid.
  final Color? backgroundColor;

  /// How long the lines take to draw in; zero draws them at once.
  final Duration animationDuration;

  /// The easing of [animationDuration].
  final Curve animationCurve;

  /// Whether the first build draws the lines in.
  final bool animateOnMount;

  /// Called with a tile and the sample under the finger when one is touched,
  /// and with nulls when the touch leaves.
  final void Function(SparklineTile? tile, int? sample)? onTileTap;

  /// Builds the card shown over a touched tile; null shows its label and the
  /// value under the finger.
  final Widget Function(BuildContext context, SparklineTile tile, int sample)?
  tooltipBuilder;

  /// What a screen reader announces for the grid.
  final String? semanticLabel;

  /// How many rows the grid takes.
  int get rows => columns <= 0 ? 0 : (tiles.length / columns).ceil();

  /// How tall the grid is in a box that sets no height.
  double get intrinsicHeight => tiles.isEmpty
      ? padding.vertical
      : padding.vertical + rows * tileHeight + (rows - 1) * tileGap;

  @override
  State<SparklineGrid> createState() => _SparklineGridState();
}

class _SparklineGridState extends State<SparklineGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final TextPainterCache _text = TextPainterCache(capacity: 512);
  SparklineGridLayout _layout = SparklineGridLayout.empty;
  int? _touched;
  int? _sample;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
      value: 1,
    )..addListener(() => setState(() {}));
    if (widget.animateOnMount && widget.animationDuration > Duration.zero) {
      _animation.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(SparklineGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animation.duration = widget.animationDuration;
    if (!identical(oldWidget.tiles, widget.tiles) &&
        widget.animationDuration > Duration.zero) {
      _animation.forward(from: 0);
    }
    if (_touched != null && _touched! >= widget.tiles.length) _touched = null;
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  void _touch(Offset point) {
    final tile = _layout.tileAt(point);
    final sample = tile == null ? null : _layout.sampleAt(tile, point);
    if (tile?.index == _touched && sample == _sample) return;
    setState(() {
      _touched = tile?.index;
      _sample = sample;
    });
    widget.onTileTap?.call(tile?.tile, sample);
  }

  void _clear() {
    if (_touched == null) return;
    setState(() {
      _touched = null;
      _sample = null;
    });
    widget.onTileTap?.call(null, null);
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.animationCurve.transform(_animation.value);

    return Semantics(
      container: true,
      label: widget.semanticLabel,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : 320.0;
          final height =
              constraints.hasBoundedHeight && constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : widget.intrinsicHeight;
          _layout = layOutSparklineGrid(
            widget.tiles,
            size: Size(width, height),
            columns: widget.columns,
            tileHeight: widget.tileHeight,
            tileGap: widget.tileGap,
            labelWidth: widget.labelWidth,
            valueWidth: widget.valueWidth,
            sparkPadding: widget.sparkPadding,
            sharedScale: widget.sharedScale,
            padding: widget.padding,
            progress: progress,
          );

          final touched = _touched;
          return SizedBox(
            width: width,
            height: height,
            child: Listener(
              onPointerDown: (event) => _touch(event.localPosition),
              onPointerMove: (event) => _touch(event.localPosition),
              onPointerUp: (_) => _clear(),
              onPointerCancel: (_) => _clear(),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: SparklineGridPainter(
                        grid: widget,
                        layout: _layout,
                        touched: touched,
                        sample: _sample,
                        textCache: _text,
                      ),
                    ),
                  ),
                  if (touched != null && touched < _layout.tiles.length)
                    _tooltip(context, touched),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tooltip(BuildContext context, int index) {
    final laid = _layout.tiles[index];
    final sample = _sample ?? 0;
    final value = sample >= 0 && sample < laid.tile.values.length
        ? laid.tile.values[sample]
        : null;
    final build = widget.tooltipBuilder;
    final child = build != null
        ? build(context, laid.tile, sample)
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xEE1B1D22),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              laid.tile.tooltip ??
                  '${laid.tile.label}  '
                      '${value == null ? '—' : _number(value)}',
              style: const TextStyle(color: Color(0xFFE9ECEF), fontSize: 11),
            ),
          );
    return Positioned(
      left: math.max(0, laid.sparkRect.left),
      top: math.max(0, laid.rect.top - 24),
      child: IgnorePointer(child: child),
    );
  }
}

String _number(double value) {
  if (!value.isFinite) return '';
  if (value.abs() >= 1000) return value.toStringAsFixed(0);
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2);
}

/// Paints a [SparklineGrid]: a name, a little line and a number per tile.
class SparklineGridPainter extends CustomPainter {
  /// Creates the painter for [grid], laid out as [layout].
  SparklineGridPainter({
    required this.grid,
    required this.layout,
    required this.touched,
    required this.sample,
    required this.textCache,
  });

  final SparklineGrid grid;
  final SparklineGridLayout layout;

  /// The tile under the finger, into [SparklineGrid.tiles]; null when none is.
  final int? touched;

  /// Which sample of that tile is under it.
  final int? sample;
  final TextPainterCache textCache;

  @override
  void paint(Canvas canvas, Size size) {
    final background = grid.backgroundColor;
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
    }
    if (layout.isEmpty) return;

    final labelStyle =
        grid.labelStyle ??
        const TextStyle(color: Color(0xFFE9ECEF), fontSize: 11);
    final subtitleStyle =
        grid.subtitleStyle ??
        const TextStyle(color: Color(0xFF909196), fontSize: 9);
    final valueStyle =
        grid.valueStyle ??
        const TextStyle(color: Color(0xFFB4B8C0), fontSize: 11);

    for (final laid in layout.tiles) {
      final tile = laid.tile;
      final color = tile.color ?? (tile.rose ? grid.riseColor : grid.fallColor);

      final tileColor = grid.tileColor;
      if (tileColor != null) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(laid.rect, const Radius.circular(4)),
          Paint()..color = tileColor,
        );
      }
      if (touched == laid.index) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(laid.rect, const Radius.circular(4)),
          Paint()..color = grid.highlightColor,
        );
      }

      if (grid.showBaseline) {
        final from = tile.first;
        if (from != null && laid.max > laid.min) {
          final y =
              laid.sparkRect.bottom -
              (from - laid.min) / (laid.max - laid.min) * laid.sparkRect.height;
          canvas.drawLine(
            Offset(laid.sparkRect.left, y),
            Offset(laid.sparkRect.right, y),
            Paint()
              ..color = grid.baselineColor
              ..strokeWidth = 1,
          );
        }
      }

      // The line, broken wherever a value was not finite.
      final path = Path();
      final fill = Path();
      Offset? previous;
      Offset? runStart;
      for (final at in laid.points) {
        if (at == null) {
          if (runStart != null && previous != null) {
            fill
              ..lineTo(previous.dx, laid.sparkRect.bottom)
              ..lineTo(runStart.dx, laid.sparkRect.bottom)
              ..close();
          }
          previous = null;
          runStart = null;
          continue;
        }
        if (previous == null) {
          path.moveTo(at.dx, at.dy);
          fill.moveTo(at.dx, at.dy);
          runStart = at;
        } else {
          path.lineTo(at.dx, at.dy);
          fill.lineTo(at.dx, at.dy);
        }
        previous = at;
      }
      if (runStart != null && previous != null) {
        fill
          ..lineTo(previous.dx, laid.sparkRect.bottom)
          ..lineTo(runStart.dx, laid.sparkRect.bottom)
          ..close();
      }

      if (grid.fillOpacity > 0) {
        canvas.drawPath(
          fill,
          Paint()..color = color.withValues(alpha: grid.fillOpacity),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = grid.lineWidth
          ..strokeJoin = StrokeJoin.round,
      );

      if (grid.showEndDot) {
        final end = laid.lastPoint;
        if (end != null) {
          canvas.drawCircle(end, grid.endDotRadius, Paint()..color = color);
        }
      }

      if (touched == laid.index &&
          sample != null &&
          sample! < laid.points.length) {
        final at = laid.points[sample!];
        if (at != null) {
          canvas.drawCircle(
            at,
            grid.endDotRadius + 1,
            Paint()..color = const Color(0xFFE9ECEF),
          );
        }
      }

      if (laid.labelRect.width > 4) {
        canvas.save();
        canvas.clipRect(laid.labelRect);
        final label = textCache.get(tile.label, labelStyle);
        final subtitle = tile.subtitle;
        if (subtitle == null) {
          label.paint(
            canvas,
            Offset(
              laid.labelRect.left,
              laid.labelRect.center.dy - label.height / 2,
            ),
          );
        } else {
          final under = textCache.get(subtitle, subtitleStyle);
          final total = label.height + under.height;
          label.paint(
            canvas,
            Offset(laid.labelRect.left, laid.labelRect.center.dy - total / 2),
          );
          under.paint(
            canvas,
            Offset(
              laid.labelRect.left,
              laid.labelRect.center.dy - total / 2 + label.height,
            ),
          );
        }
        canvas.restore();
      }

      if (laid.valueRect.width > 4) {
        final text =
            grid.valueFormatter?.call(tile) ??
            tile.valueLabel ??
            (tile.last == null ? '' : _number(tile.last!));
        if (text.isNotEmpty) {
          final painter = textCache.get(text, valueStyle);
          canvas.save();
          canvas.clipRect(laid.valueRect);
          painter.paint(
            canvas,
            Offset(
              laid.valueRect.right - painter.width,
              laid.valueRect.center.dy - painter.height / 2,
            ),
          );
          canvas.restore();
        }
      }
    }
  }

  @override
  bool shouldRepaint(SparklineGridPainter old) =>
      old.grid != grid ||
      old.layout != layout ||
      old.touched != touched ||
      old.sample != sample;
}
