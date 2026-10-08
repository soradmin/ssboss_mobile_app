import 'package:flutter/animation.dart';

/// Shared motion tokens (Emil Kowalski / emil-design-eng).
abstract final class AppMotion {
  /// Strong ease-out for UI enter/exit and press feedback.
  static const Curve easeOut = Cubic(0.23, 1.0, 0.32, 1.0);

  /// Strong ease-in-out for on-screen movement / morph.
  static const Curve easeInOut = Cubic(0.77, 0.0, 0.175, 1.0);

  /// iOS-like sheet / drawer curve.
  static const Curve easeDrawer = Cubic(0.32, 0.72, 0.0, 1.0);

  static const Duration press = Duration(milliseconds: 120);
  static const Duration chip = Duration(milliseconds: 180);
  static const Duration sheet = Duration(milliseconds: 280);

  /// Press-in scale — subtle (0.95–0.98).
  static const double pressScale = 0.97;
}
