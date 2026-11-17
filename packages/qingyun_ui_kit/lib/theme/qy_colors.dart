import 'package:flutter/material.dart';

/// Warm yellow palette. No purple is used anywhere in the design.
abstract final class QyColors {
  static const Color primary = Color(0xFFFFC94A);
  static const Color primaryDeep = Color(0xFFF5A623);
  static const Color primaryLight = Color(0xFFFFF0BF);
  static const Color canvas = Color(0xFFFFF8E7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFFFF6DE);
  static const Color coral = Color(0xFFFF9F7A);
  static const Color mint = Color(0xFF7FD1B9);
  static const Color sky = Color(0xFF8EC5E8);
  static const Color ink = Color(0xFF2E2A22);
  static const Color sub = Color(0xFF7C7566);
  static const Color muted = Color(0xFFA9A08C);
  static const Color border = Color(0xFFF2E7CC);
  static const Color divider = Color(0xFFF5EFE0);
  static const Color success = Color(0xFF49B58C);
  static const Color error = Color(0xFFE96A5B);
  static const Color onDark = Color(0xFFFFFFFF);

  /// 12% warm shadow.
  static const Color warmShadow = Color(0x1FB78A2E);

  static const List<Color> warmGradient = <Color>[
    Color(0xFFFFD86B),
    Color(0xFFFFEBAF),
    Color(0xFFFFF6DC),
  ];

  static const List<Color> primaryGradient = <Color>[
    primaryLight,
    Color(0xFFFFF6DC),
  ];
}
