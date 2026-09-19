import 'package:material_ui/material_ui.dart';

/// What kind of thing happened, which decides the mark's default look.
enum ChartEventKind {
  /// An earnings release.
  earnings,

  /// A dividend going ex.
  dividend,

  /// A share split or reverse split.
  split,

  /// A news item.
  news,

  /// Anything else — a note of your own.
  custom,
}

/// Something that happened to the instrument, marked under the candle it
/// happened on.
///
/// Hand a list to `KChartWidget.events` and each is drawn as a small badge
/// below the candles, at the candle nearest its own time. Tapping one reports
/// through `KChartWidget.onEventTapped`, which is where a panel or a link to
/// the filing goes.
///
/// ```dart
/// KChartWidget(
///   candles,
///   ChartColors(),
///   events: [
///     ChartEvent(time: reportedAt, kind: ChartEventKind.earnings, label: 'E'),
///     ChartEvent(
///       time: exDate,
///       kind: ChartEventKind.dividend,
///       label: 'D',
///       detail: r'$0.24 per share',
///     ),
///   ],
///   onEventTapped: (event) => showAboutEvent(event),
/// );
/// ```
class ChartEvent {
  /// Creates an event at [time].
  const ChartEvent({
    required this.time,
    this.kind = ChartEventKind.custom,
    this.label,
    this.detail,
    this.color,
    this.icon,
  });

  /// When it happened.
  ///
  /// Matched to the nearest candle, so an event stamped mid-bar still marks the
  /// bar it fell in.
  final DateTime time;

  /// What kind of thing it was, which picks the default colour and letter.
  final ChartEventKind kind;

  /// The letter or two shown in the badge, or null for the kind's own.
  final String? label;

  /// A longer description, for a tooltip or a panel of your own.
  final String? detail;

  /// The badge's colour, or null for the kind's own.
  final Color? color;

  /// An icon drawn instead of the label, if you would rather have one.
  final IconData? icon;

  /// What the badge says: [label] where it has one, and the kind's letter
  /// otherwise.
  String get badgeText => label ?? defaultLabelOf(kind);

  /// The single letter each kind is marked with by default.
  static String defaultLabelOf(ChartEventKind kind) => switch (kind) {
    ChartEventKind.earnings => 'E',
    ChartEventKind.dividend => 'D',
    ChartEventKind.split => 'S',
    ChartEventKind.news => 'N',
    ChartEventKind.custom => '•',
  };

  @override
  bool operator ==(Object other) =>
      other is ChartEvent &&
      other.time == time &&
      other.kind == kind &&
      other.label == label &&
      other.detail == detail &&
      other.color == color &&
      other.icon == icon;

  @override
  int get hashCode => Object.hash(time, kind, label, detail, color, icon);
}

/// An event lined up against the chart's own candles.
///
/// `index` is the candle the event marks — the nearest one to its time — so the
/// painter does not have to search for it on every frame.
typedef ResolvedEvent = ({ChartEvent event, int index});

/// Where each of [events] falls among [candles].
///
/// Each event takes the candle closest in time to it, so an event stamped
/// mid-bar marks the bar it fell in. Events with no candle to attach to — an
/// empty chart, or candles with no timestamps — are dropped. The result is in
/// candle order, so marks are drawn left to right.
List<ResolvedEvent> resolveEvents(
  List<KLineTime> candles,
  List<ChartEvent> events,
) {
  if (candles.isEmpty || events.isEmpty) return const [];

  final resolved = <ResolvedEvent>[];
  for (final event in events) {
    int? best;
    Duration? closest;
    for (var i = 0; i < candles.length; i++) {
      final time = candles[i];
      if (time == null) continue;
      final gap = time.difference(event.time).abs();
      if (closest == null || gap < closest) {
        closest = gap;
        best = i;
      }
    }
    if (best != null) resolved.add((event: event, index: best));
  }

  resolved.sort((a, b) => a.index.compareTo(b.index));
  return resolved;
}

/// A candle's instant, or null where it has none.
///
/// [resolveEvents] only needs the times, so it takes them rather than the whole
/// candles — which keeps it usable over any list you can produce times from.
typedef KLineTime = DateTime?;
