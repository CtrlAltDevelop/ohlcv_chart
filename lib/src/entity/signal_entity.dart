import 'dart:ui';

class SignalEntity {
  SignalEntity({
    required this.title,
    required this.price,
    required this.color,
    this.useDash = false,
  });

  final String title;
  final double price;
  final Color color;
  final bool useDash;
}
