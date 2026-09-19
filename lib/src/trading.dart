import 'package:material_ui/material_ui.dart';

import 'entity/line.dart';

/// Which way an order or a position points.
enum TradeSide {
  /// Long: bought, or waiting to buy.
  buy,

  /// Short: sold, or waiting to sell.
  sell,
}

/// What kind of working order rests at a price.
///
/// Only used to name and colour the line; the chart does not act on it.
enum OrderKind {
  /// A resting limit order.
  limit,

  /// A stop order.
  stop,

  /// A stop with a limit price.
  stopLimit,

  /// A take-profit order.
  takeProfit,
}

/// A working order resting at a price, drawn across the chart.
///
/// Hand a list to `KChartWidget.orders` and each is drawn as a line the full
/// width of the candles, tagged on the axis side. Where [draggable] is set and
/// the chart has an `onOrderMoved`, the line can be dragged to a new price —
/// which is how an order is modified from the chart.
///
/// ```dart
/// KChartWidget(
///   candles,
///   ChartColors(),
///   orders: [
///     ChartOrder(id: '17', price: 64_500, side: TradeSide.buy, quantity: 0.5),
///   ],
///   onOrderMoved: (order, price) => broker.amend(order.id, price),
/// );
/// ```
class ChartOrder {
  /// Creates an order resting at [price].
  const ChartOrder({
    required this.id,
    required this.price,
    required this.side,
    this.kind = OrderKind.limit,
    this.quantity,
    this.label,
    this.color,
    this.draggable = true,
  });

  /// What the venue calls this order, and what a move is reported against.
  final String id;

  /// The price it rests at.
  final double price;

  /// Which way it points.
  final TradeSide side;

  /// What kind of order it is, which names and colours the line.
  final OrderKind kind;

  /// How much is working, or null to leave it off the tag.
  final double? quantity;

  /// What the tag says, or null for one built from the kind, side and quantity.
  final String? label;

  /// The line's colour, or null for the side's own.
  final Color? color;

  /// Whether the line can be dragged to a new price.
  final bool draggable;

  /// What the tag says.
  String get tagText {
    final own = label;
    if (own != null) return own;

    final name = switch (kind) {
      OrderKind.limit => side == TradeSide.buy ? 'Buy' : 'Sell',
      OrderKind.stop => 'Stop',
      OrderKind.stopLimit => 'Stop limit',
      OrderKind.takeProfit => 'Target',
    };
    final size = quantity;
    return size == null ? name : '$name ${_trim(size)}';
  }

  /// A copy of this order resting at [price].
  ///
  /// What the chart draws while one is being dragged, before the host has said
  /// anything about the move.
  ChartOrder movedTo(double price) => ChartOrder(
    id: id,
    price: price,
    side: side,
    kind: kind,
    quantity: quantity,
    label: label,
    color: color,
    draggable: draggable,
  );

  @override
  bool operator ==(Object other) =>
      other is ChartOrder &&
      other.id == id &&
      other.price == price &&
      other.side == side &&
      other.kind == kind &&
      other.quantity == quantity &&
      other.label == label &&
      other.color == color &&
      other.draggable == draggable;

  @override
  int get hashCode =>
      Object.hash(id, price, side, kind, quantity, label, color, draggable);
}

/// An open position, drawn at its average entry.
///
/// Hand a list to `KChartWidget.positions` and each is drawn as a line across
/// the candles, tagged with its size and — where you hand one over — what it is
/// currently worth. A stop or a target attached to it is an order of its own;
/// see [ChartOrder].
class ChartPosition {
  /// Creates a position entered at [entryPrice].
  const ChartPosition({
    required this.id,
    required this.entryPrice,
    required this.side,
    this.quantity,
    this.unrealisedPnl,
    this.label,
    this.color,
  });

  /// What the venue calls this position.
  final String id;

  /// The average price it was entered at.
  final double entryPrice;

  /// Which way it points.
  final TradeSide side;

  /// How much is open, or null to leave it off the tag.
  final double? quantity;

  /// What it is currently worth, or null to leave it off the tag.
  ///
  /// The chart does not work this out: only the caller knows the contract size,
  /// the fees and what currency the answer should be in.
  final double? unrealisedPnl;

  /// What the tag says, or null for one built from the side and quantity.
  final String? label;

  /// The line's colour, or null for the side's own.
  final Color? color;

  /// Whether the position is making money, or null when that is not known.
  bool? get isUp {
    final pnl = unrealisedPnl;
    return pnl == null ? null : pnl >= 0;
  }

  /// What the tag says.
  String get tagText {
    final own = label;
    final size = quantity;
    final name = own ?? (side == TradeSide.buy ? 'Long' : 'Short');
    final head = own != null || size == null ? name : '$name ${_trim(size)}';

    final pnl = unrealisedPnl;
    if (pnl == null) return head;
    return '$head  ${pnl >= 0 ? '+' : ''}${_trim(pnl)}';
  }

  @override
  bool operator ==(Object other) =>
      other is ChartPosition &&
      other.id == id &&
      other.entryPrice == entryPrice &&
      other.side == side &&
      other.quantity == quantity &&
      other.unrealisedPnl == unrealisedPnl &&
      other.label == label &&
      other.color == color;

  @override
  int get hashCode =>
      Object.hash(id, entryPrice, side, quantity, unrealisedPnl, label, color);
}

/// How the order and position lines are drawn.
///
/// Held on `ChartStyle.trading`, so the whole of it can be replaced at once.
class TradingStyle {
  /// Creates a trading style.
  const TradingStyle({
    this.lineWidth = 1.0,
    this.orderStyle = LineStyle.dashed,
    this.positionStyle = LineStyle.solid,
    this.dashLength = 5,
    this.dashGap = 4,
    this.grabTolerance = 10,
  });

  /// Stroke width of both kinds of line.
  final double lineWidth;

  /// How an order's line is stroked.
  final LineStyle orderStyle;

  /// How a position's line is stroked.
  final LineStyle positionStyle;

  /// Length of one dash, where the stroke is broken.
  final double dashLength;

  /// Gap between dashes.
  final double dashGap;

  /// How near an order's line a press has to land to pick it up.
  final double grabTolerance;

  /// A copy of this style with the fields given replaced.
  TradingStyle copyWith({
    double? lineWidth,
    LineStyle? orderStyle,
    LineStyle? positionStyle,
    double? dashLength,
    double? dashGap,
    double? grabTolerance,
  }) => TradingStyle(
    lineWidth: lineWidth ?? this.lineWidth,
    orderStyle: orderStyle ?? this.orderStyle,
    positionStyle: positionStyle ?? this.positionStyle,
    dashLength: dashLength ?? this.dashLength,
    dashGap: dashGap ?? this.dashGap,
    grabTolerance: grabTolerance ?? this.grabTolerance,
  );
}

/// Writes 0.5 as `0.5` and 2.0 as `2`, so a tag reads `Buy 2`.
String _trim(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  // A tag is a small label pinned to a line, and an unrealised P&L is rarely a
  // round number: printed raw, `1415.882446718504` runs off the end of it. Two
  // decimals, with nothing trailing.
  var text = value.toStringAsFixed(2);
  while (text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  return text.endsWith('.') ? text.substring(0, text.length - 1) : text;
}

/// The hours a market keeps, in the time zone the chart is showing.
///
/// Hand one to `KChartWidget.session` and the candles outside it — the pre-market
/// and after-hours stretches — are washed, so what is on screen says which of it
/// is the regular session and which is not.
///
/// ```dart
/// // 09:30 to 16:00, weekdays: a US equity session.
/// const session = TradingSession(
///   open: Duration(hours: 9, minutes: 30),
///   close: Duration(hours: 16),
/// );
/// ```
///
/// A session whose [close] is at or before its [open] runs overnight, which is
/// how a market that opens in one day and closes in the next is described.
class TradingSession {
  /// Creates a session running from [open] to [close] on [weekdays].
  const TradingSession({
    required this.open,
    required this.close,
    this.weekdays = const {
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
    },
  });

  /// When the session opens, measured from midnight.
  final Duration open;

  /// When it closes, measured from midnight.
  final Duration close;

  /// Which days it is kept on, as `DateTime.monday` through `DateTime.sunday`.
  final Set<int> weekdays;

  /// Whether the session runs past midnight into the next day.
  bool get isOvernight => close <= open;

  /// Whether [time] falls inside the regular session.
  ///
  /// [time] is expected in the zone the chart is showing, which is what
  /// `KChartWidget.timeZoneOffset` puts it in.
  bool contains(DateTime time) {
    final since = Duration(
      hours: time.hour,
      minutes: time.minute,
      seconds: time.second,
    );

    if (!isOvernight) {
      return weekdays.contains(time.weekday) && since >= open && since < close;
    }

    // Overnight: the evening belongs to the day it opened on, and the morning
    // to the day before it.
    if (since >= open) return weekdays.contains(time.weekday);
    if (since < close) {
      final yesterday = time.weekday == DateTime.monday
          ? DateTime.sunday
          : time.weekday - 1;
      return weekdays.contains(yesterday);
    }
    return false;
  }

  @override
  bool operator ==(Object other) =>
      other is TradingSession &&
      other.open == open &&
      other.close == close &&
      other.weekdays.length == weekdays.length &&
      other.weekdays.containsAll(weekdays);

  @override
  int get hashCode =>
      Object.hash(open, close, Object.hashAllUnordered(weekdays));
}
