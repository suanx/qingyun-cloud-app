import 'package:flutter/material.dart';

/// Spacing, radius, elevation and motion tokens shared by the whole app.
abstract final class QyTokens {
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 20;
  static const double spaceXxl = 24;
  static const double spaceXxxl = 32;

  static const double radiusSm = 12;
  static const double radiusMd = 18;
  static const double radiusLg = 22;
  static const double radiusXl = 26;
  static const double radiusPill = 999;

  static const double buttonHeight = 52;
  static const double statusBarHeight = 62;
  static const double navHeight = 95;
  static const double navPillHeight = 62;

  static const Duration shortMotion = Duration(milliseconds: 180);
  static const Duration mediumMotion = Duration(milliseconds: 280);
  static const Duration toastDuration = Duration(seconds: 2);

  static BoxShadow softShadow(Color color) => BoxShadow(
        color: color,
        offset: const Offset(0, 6),
        blurRadius: 18,
        spreadRadius: -4,
      );

  static BoxShadow cardShadow(Color color) => BoxShadow(
        color: color,
        offset: const Offset(0, 8),
        blurRadius: 24,
        spreadRadius: -6,
      );
}
