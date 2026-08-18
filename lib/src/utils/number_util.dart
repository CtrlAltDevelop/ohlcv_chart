import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

class NumberUtil {
  static String formatCompact(double value, [int precision = 2]) {
    double n = value;
    try {
      if (n >= 1e9) {
        n /= 1e9;
        return '${n.toStringAsFixed(precision)}B';
      } else if (n >= 1e6) {
        n /= 1e6;
        return '${n.toStringAsFixed(precision)}M';
      } else if (n >= 1e4) {
        n /= 1e3;
        return '${n.toStringAsFixed(precision)}K';
      } else {
        return n.toStringAsFixed(precision);
      }
    } catch (e) {
      return n.toString();
    }
  }

  static bool checkNotNullOrZero(double? a) {
    if (a == null || a == 0) {
      return false;
    } else if (a.abs().toStringAsFixed(4) == '0.0000') {
      return false;
    } else {
      return true;
    }
  }

  static String? formatFixed(
    dynamic value,
    int precision, [
    String pattern = '#,##0',
  ]) {
    try {
      final number = Decimal.parse(value.toString())
          .toString(); // avoid scientific notation format e-10
      final parts = number.split('.');
      final integerPart = NumberFormat(
        pattern,
        'en_US',
      ).format(num.parse(parts.first));
      if (precision == 0) {
        return integerPart;
      }
      String fractionalPart = (parts.length <= 1 ? '' : parts.last).padRight(
        precision,
        '0',
      );
      fractionalPart = fractionalPart.substring(0, precision);
      return '$integerPart.$fractionalPart';
    } catch (e) {
      return null;
    }
  }

  static String? format(
    dynamic value, [
    int precision = 2,
    String pattern = '#,##0',
  ]) {
    try {
      // avoid scientific notation format e-10
      final number = Decimal.parse(value.toString())
          .floor(scale: precision)
          .toString();
      final parts = number.split('.');
      final integerPart = NumberFormat(
        pattern,
        'en_US',
      ).format(num.parse(parts.first));
      if (precision == 0 && parts.length == 1) {
        return integerPart;
      }
      final fractionalPart = parts.last;
      return '$integerPart.$fractionalPart';
    } catch (e) {
      return null;
    }
  }
}
