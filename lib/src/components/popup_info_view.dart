import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../chart_style.dart';
import '../chart_translations.dart';
import '../entity/k_line_entity.dart';
import '../utils/date_format_util.dart';
import '../utils/number_util.dart';

/// The readout shown while the crosshair is up.
///
/// Sizes itself to its content between [width] and [maxWidth]; labels and
/// values ellipsise rather than overflow, so long translations, intraday
/// timestamps and large volumes all stay inside the card.
class PopupInfoView extends StatelessWidget {
  /// Creates a readout for [entity].
  const PopupInfoView({
    required this.entity,
    required this.width,
    required this.maxWidth,
    required this.chartColors,
    required this.chartTranslations,
    required this.materialInfoDialog,
    required this.timeFormat,
    required this.fixedLength,
    required this.livePrice,
    super.key,
  });

  final KLineEntity entity;

  /// Narrowest the card may be.
  final double width;

  /// Widest the card may grow before its rows ellipsise.
  final double maxWidth;
  final ChartColors chartColors;
  final ChartTranslations chartTranslations;
  final bool materialInfoDialog;
  final List<String> timeFormat;
  final int fixedLength;
  final double? livePrice;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? chartColors.selectFillColor.withAlpha(180)
        : chartColors.selectFillColor.withAlpha(180);

    final minWidth = math.min(width, maxWidth);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Container(
          constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: chartColors.selectBorderColor.withAlpha(65),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withAlpha(45)
                    : Colors.grey.withAlpha(30),
                blurRadius: 6,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            // Lets the card hug its widest row instead of always filling the
            // maximum width.
            child: IntrinsicWidth(child: _buildContent()),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final upDown = entity.change ?? entity.close - entity.open;
    final upDownPercent = entity.ratio ?? (upDown / entity.open) * 100;
    final bool isUp = upDown > 0;
    final double? entityAmount = entity.amount;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header / Date
        Container(
          padding: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: chartColors.selectBorderColor.withAlpha(90),
                width: 0.5,
              ),
            ),
          ),
          child: _InfoRow(
            label: chartTranslations.date,
            value: getDate(entity.dateTime),
            labelColor: chartColors.infoWindowTitleColor,
            valueColor: chartColors.infoWindowNormalColor,
            fontSize: 10,
            labelWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 4),

        _buildRow(
          label: chartTranslations.open,
          value: entity.open.toStringAsFixed(fixedLength),
        ),
        _buildRow(
          label: chartTranslations.high,
          value: entity.high.toStringAsFixed(fixedLength),
        ),
        _buildRow(
          label: chartTranslations.low,
          value: entity.low.toStringAsFixed(fixedLength),
        ),
        _buildRow(
          label: chartTranslations.close,
          value: entity.close.toStringAsFixed(fixedLength),
          isBold: true,
        ),

        const SizedBox(height: 3),
        Divider(
          height: 1,
          thickness: 0.4,
          color: chartColors.selectBorderColor.withAlpha(90),
        ),

        const SizedBox(height: 3),

        _buildColoredRow(
          label: chartTranslations.changeAmount,
          value: upDown.toStringAsFixed(fixedLength),
          isUp: isUp,
          prefix: isUp ? '+' : '',
        ),

        _buildColoredRow(
          label: chartTranslations.change,
          value: '${upDownPercent.toStringAsFixed(2)}%',
          isUp: isUp,
          prefix: isUp ? '+' : '',
        ),

        if (livePrice != null) ...[
          const SizedBox(height: 3),
          () {
            final liveChange = livePrice! - entity.close;
            final liveChangePercent = (liveChange / entity.close) * 100;
            final isLiveUp = liveChange > 0;
            return _buildColoredRow(
              label: chartTranslations.changeLive,
              value: '${liveChangePercent.toStringAsFixed(2)}%',
              isUp: isLiveUp,
              prefix: isLiveUp ? '+' : '',
            );
          }(),
        ],

        const SizedBox(height: 3),
        _buildRow(
          label: chartTranslations.vol,
          value: NumberUtil.formatCompact(entity.vol),
        ),

        if (entityAmount != null) ...[
          const SizedBox(height: 1),
          _buildRow(
            label: chartTranslations.amount,
            value: entityAmount.toInt().toString(),
          ),
        ],

        const SizedBox(height: 1),
      ],
    );
  }

  Widget _buildRow({
    required String label,
    required String value,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: _InfoRow(
        label: label,
        value: value,
        labelColor: chartColors.infoWindowTitleColor,
        valueColor: chartColors.infoWindowNormalColor,
        valueWeight: isBold ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }

  Widget _buildColoredRow({
    required String label,
    required String value,
    required bool isUp,
    String prefix = '',
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: _InfoRow(
        label: label,
        value: '$prefix$value',
        labelColor: chartColors.infoWindowTitleColor,
        valueColor: isUp
            ? chartColors.infoWindowUpColor
            : chartColors.infoWindowDnColor,
        valueWeight: FontWeight.w600,
      ),
    );
  }

  String getDate(DateTime? date) =>
      dateFormat(date ?? DateTime.now(), timeFormat);
}

/// One label-and-value line of the readout.
///
/// Both halves shrink and ellipsise before the row can overflow, and the gap
/// between them survives even when the card is at its narrowest.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.labelColor,
    required this.valueColor,
    this.fontSize = 9,
    this.labelWeight = FontWeight.w500,
    this.valueWeight = FontWeight.w500,
  });

  final String label;
  final String value;
  final Color labelColor;
  final Color valueColor;
  final double fontSize;
  final FontWeight labelWeight;
  final FontWeight valueWeight;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: labelColor,
              fontSize: fontSize,
              fontWeight: labelWeight,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor,
              fontSize: fontSize,
              fontWeight: valueWeight,
            ),
          ),
        ),
      ],
    );
  }
}
