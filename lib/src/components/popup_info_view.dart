import 'dart:ui';

import 'package:flutter/material.dart';

import '../chart_style.dart';
import '../chart_translations.dart';
import '../entity/k_line_entity.dart';
import '../utils/date_format_util.dart';
import '../utils/number_util.dart';

class PopupInfoView extends StatelessWidget {
  const PopupInfoView({
    required this.entity,
    required this.width,
    required this.chartColors,
    required this.chartTranslations,
    required this.materialInfoDialog,
    required this.timeFormat,
    required this.fixedLength,
    required this.livePrice,
    super.key,
  });

  final KLineEntity entity;
  final double width;
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Container(
          width: width,
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
            child: _buildContent(),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                chartTranslations.date,
                style: TextStyle(
                  color: chartColors.infoWindowTitleColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                getDate(entity.dateTime),
                style: TextStyle(
                  color: chartColors.infoWindowNormalColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: chartColors.infoWindowTitleColor,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: chartColors.infoWindowNormalColor,
              fontSize: 9,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColoredRow({
    required String label,
    required String value,
    required bool isUp,
    String prefix = '',
  }) {
    final color = isUp
        ? chartColors.infoWindowUpColor
        : chartColors.infoWindowDnColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: chartColors.infoWindowTitleColor,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            '$prefix$value',
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String getDate(DateTime? date) =>
      dateFormat(date ?? DateTime.now(), timeFormat);
}
