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

  // 原型：--r-sm 10 / --r-md 14 / --r-lg 18 / --r-xl 24
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 18;
  static const double radiusXl = 24;
  static const double radiusCard = 20;
  static const double radiusPill = 999;

  static const double buttonHeight = 52;
  static const double statusBarHeight = 48;
  static const double navHeight = 74;
  static const double navPillHeight = 62;

  static const Duration shortMotion = Duration(milliseconds: 200);
  static const Duration mediumMotion = Duration(milliseconds: 320);
  static const Duration entranceMotion = Duration(milliseconds: 320);
  static const int entranceStepMilliseconds = 70;
  static const Duration toastDuration = Duration(milliseconds: 1900);

  static BoxShadow softShadow(Color color) => BoxShadow(
        color: color,
        offset: const Offset(0, 4),
        blurRadius: 16,
        spreadRadius: -2,
      );

  static BoxShadow cardShadow(Color color) => BoxShadow(
        color: color,
        offset: const Offset(0, 6),
        blurRadius: 20,
        spreadRadius: -4,
      );

  static BoxShadow cardShadowSoft(Color color) => BoxShadow(
        color: color,
        offset: const Offset(0, 10),
        blurRadius: 26,
        spreadRadius: -8,
      );
}
