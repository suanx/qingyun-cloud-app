import 'package:flutter/material.dart';
import 'qy_colors.dart';

/// Fonts in the design are Noto Sans SC for Chinese and Outfit for numerals.
/// Add the font files to pubspec.yaml if you want an exact match, then set
/// `fontFamily` on the corresponding styles below.
TextTheme qyTextTheme() => const TextTheme(
      displayLarge: TextStyle(
        fontSize: 40,
        height: 48 / 40,
        fontWeight: FontWeight.w700,
        color: QyColors.ink,
      ),
      headlineLarge: TextStyle(
        fontSize: 28,
        height: 36 / 28,
        fontWeight: FontWeight.w700,
        color: QyColors.ink,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        height: 30 / 22,
        fontWeight: FontWeight.w600,
        color: QyColors.ink,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        height: 26 / 18,
        fontWeight: FontWeight.w600,
        color: QyColors.ink,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        height: 22 / 15,
        fontWeight: FontWeight.w400,
        color: QyColors.ink,
      ),
      bodyMedium: TextStyle(
        fontSize: 13,
        height: 18 / 13,
        fontWeight: FontWeight.w400,
        color: QyColors.sub,
      ),
      labelLarge: TextStyle(
        fontSize: 15,
        height: 20 / 15,
        fontWeight: FontWeight.w600,
        color: QyColors.ink,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w500,
        color: QyColors.sub,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        height: 16 / 11,
        fontWeight: FontWeight.w500,
        color: QyColors.muted,
      ),
    );
