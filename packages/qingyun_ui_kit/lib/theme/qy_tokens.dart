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
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusXl = 24;
  static const double radiusCard = 26;
  static const double radiusPill = 999;

  static const double buttonHeight = 52;
  static const double statusBarHeight = 62;
  static const double navHeight = 84;
  static const double navPillHeight = 62;

  static const Duration shortMotion = Duration(milliseconds: 200);
  static const Duration mediumMotion = Duration(milliseconds: 320);
  static const Duration entranceMotion = Duration(milliseconds: 460);
  static const int entranceStepMilliseconds = 70;
  static const Duration toastDuration = Duration(seconds: 2);

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

  /// 卡片专用：更大模糊半径、更大负扩散，投影更轻更柔。
  static BoxShadow cardShadowSoft(Color color) => BoxShadow(
        color: color,
        offset: const Offset(0, 10),
        blurRadius: 30,
        spreadRadius: -10,
      );
}
