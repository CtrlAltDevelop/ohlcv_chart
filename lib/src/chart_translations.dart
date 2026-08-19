import 'drawing/drawing_translations.dart';

/// Every piece of text the candlestick chart shows.
///
/// Build one from your own localisations to translate the chart:
///
/// ```dart
/// ChartTranslations(date: l10n.date, open: l10n.open /* … */);
/// ```
class ChartTranslations {
  /// Creates a translation set, defaulting to English.
  const ChartTranslations({
    this.date = 'Date',
    this.open = 'Open',
    this.high = 'High',
    this.low = 'Low',
    this.close = 'Close',
    this.changeAmount = 'Change',
    this.change = 'Change%',
    this.changeLive = 'Change% Live',
    this.amount = 'Amount',
    this.vol = 'Volume',
    this.drawing = const DrawingTranslations(),
  });

  final String date;
  final String open;
  final String high;
  final String low;
  final String close;
  final String changeAmount;
  final String change;
  final String changeLive;
  final String amount;
  final String vol;

  /// Text shown by the drawing tools' editing toolbar.
  final DrawingTranslations drawing;
}
