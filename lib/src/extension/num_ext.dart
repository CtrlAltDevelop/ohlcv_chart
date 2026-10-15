extension NumExt on num? {
  bool get notNullOrZero {
    if (this == null || this == 0) {
      return false;
    }
    return this!.abs().toStringAsFixed(4) != '0.0000';
  }
}

extension SafeClamp on double {
  /// [clamp], except that a range turned inside out — a pane squeezed below
  /// its own padding, say — collapses to [lower] instead of throwing.
  double clampWithin(double lower, double upper) =>
      clamp(lower, upper < lower ? lower : upper).toDouble();
}
