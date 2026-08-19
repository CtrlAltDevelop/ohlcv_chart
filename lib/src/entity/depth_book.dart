import 'dart:math';

import 'depth_entity.dart';

/// One price level of an order book, with both readings of its volume.
///
/// [size] is what rests on this rung alone and [cumulative] the running total
/// out to it — the two things a depth chart can draw, and what the readout
/// shows either way.
class DepthLevel {
  /// Creates a level.
  const DepthLevel({
    required this.price,
    required this.size,
    required this.cumulative,
  });

  /// Price of the rung, in quote currency.
  final double price;

  /// Volume resting on this rung alone, in base currency.
  final double size;

  /// Volume resting between the mid price and this rung, inclusive.
  final double cumulative;

  @override
  String toString() => 'DepthLevel($price, size: $size, total: $cumulative)';
}

/// An order book prepared for drawing: both sides, each rung's own size, and
/// the totals out to it.
///
/// Built from the cumulative curves [DepthChart] takes, so the per-rung sizes
/// are recovered by differencing rather than asked for twice.
class DepthBook {
  /// Creates a book from levels that already carry both readings.
  const DepthBook({required this.bids, required this.asks});

  /// A book with nothing in it.
  static const DepthBook empty = DepthBook(
    bids: <DepthLevel>[],
    asks: <DepthLevel>[],
  );

  /// Bid levels, ascending by price: the deepest first, the best bid last.
  final List<DepthLevel> bids;

  /// Ask levels, ascending by price: the best ask first.
  final List<DepthLevel> asks;

  /// Whether either side has anything to draw.
  bool get isEmpty => bids.isEmpty || asks.isEmpty;

  /// The price halfway between the best bid and the best ask.
  double get mid {
    if (bids.isEmpty && asks.isEmpty) return 0;
    if (bids.isEmpty) return asks.first.price;
    if (asks.isEmpty) return bids.last.price;
    return (bids.last.price + asks.first.price) / 2;
  }

  /// The largest running total on either side.
  double get maxCumulative => _maxOf((level) => level.cumulative);

  /// The largest single rung on either side.
  double get maxSize => _maxOf((level) => level.size);

  double _maxOf(double Function(DepthLevel) value) {
    var most = 0.0;
    for (final level in bids) {
      most = max(most, value(level));
    }
    for (final level in asks) {
      most = max(most, value(level));
    }
    return most;
  }

  /// Reads a book from the two cumulative curves the chart is given.
  ///
  /// Each rung's own size is the step between it and the neighbour nearer the
  /// mid, which is exactly what [DepthEntity.bids] and [DepthEntity.asks]
  /// accumulated on the way out.
  ///
  /// [zoom] keeps only the levels within that fraction of the mid price — 0.05
  /// for the book within five percent of it — so a deep book can be read where
  /// the trading actually happens. Null keeps everything.
  factory DepthBook.fromCurves(
    List<DepthEntity> bids,
    List<DepthEntity> asks, {
    double? zoom,
  }) {
    final bidLevels = <DepthLevel>[
      for (var i = 0; i < bids.length; i++)
        DepthLevel(
          price: bids[i].price,
          // Bids accumulate downwards from the best bid, so the rung nearer the
          // mid is the next one along.
          size: bids[i].vol - (i + 1 < bids.length ? bids[i + 1].vol : 0),
          cumulative: bids[i].vol,
        ),
    ];
    final askLevels = <DepthLevel>[
      for (var i = 0; i < asks.length; i++)
        DepthLevel(
          price: asks[i].price,
          size: asks[i].vol - (i > 0 ? asks[i - 1].vol : 0),
          cumulative: asks[i].vol,
        ),
    ];

    final book = DepthBook(bids: bidLevels, asks: askLevels);
    if (zoom == null || zoom <= 0) return book;

    final mid = book.mid;
    if (mid <= 0) return book;
    final reach = mid * zoom;
    final near = DepthBook(
      bids: [
        for (final level in bidLevels)
          if ((mid - level.price).abs() <= reach) level,
      ],
      asks: [
        for (final level in askLevels)
          if ((level.price - mid).abs() <= reach) level,
      ],
    );

    // A zoom tighter than the spread would leave nothing to draw; the whole
    // book is more use than an empty chart.
    return near.isEmpty ? book : near;
  }
}
