import 'package:flutter/material.dart';

/// Minimum / comfortable touch sizes for POS touchscreens.
abstract final class TouchTargets {
  static const double min = 48;
  static const double comfortable = 56;
  static const double large = 64;

  static const EdgeInsets buttonPadding =
      EdgeInsets.symmetric(horizontal: 22, vertical: 16);

  static const EdgeInsets chipPadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 14);

  static const Size buttonMin = Size(64, comfortable);
  static const Size iconButtonMin = Size(comfortable, comfortable);
}
