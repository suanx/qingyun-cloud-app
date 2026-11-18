import 'package:flutter/material.dart';

import '../components/qy_page_transitions.dart';
import 'qy_colors.dart';
import 'qy_tokens.dart';
import 'qy_typography.dart';

ThemeData qyLightTheme() {
  const scheme = ColorScheme.light(
    primary: QyColors.primary,
    onPrimary: QyColors.onDark,
    primaryContainer: QyColors.primaryLight,
    onPrimaryContainer: QyColors.primaryDeep,
    secondary: QyColors.mint,
    onSecondary: QyColors.onDark,
    secondaryContainer: QyColors.primaryLight,
    onSecondaryContainer: QyColors.primaryDeep,
    tertiary: QyColors.sky,
    onTertiary: QyColors.onDark,
    surface: QyColors.surface,
    onSurface: QyColors.ink,
    onSurfaceVariant: QyColors.sub,
    outline: QyColors.border,
    outlineVariant: QyColors.divider,
    error: QyColors.error,
    onError: QyColors.onDark,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: QyColors.canvas,
    textTheme: qyTextTheme(),
    // 不显式指定 splashFactory：M3 默认 InkSparkle 波纹比 InkRipple 更圆润。
    pageTransitionsTheme: qyPageTransitionsTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: QyColors.canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: QyColors.ink),
    ),
    cardTheme: CardTheme(
      color: QyColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(QyTokens.radiusCard),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: QyColors.primary,
        foregroundColor: QyColors.onDark,
        elevation: 0,
        minimumSize: const Size.fromHeight(QyTokens.buttonHeight),
        shape: const StadiumBorder(),
        textStyle: qyTextTheme().labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: QyColors.sub,
        side: const BorderSide(color: QyColors.border, width: 1.5),
        minimumSize: const Size.fromHeight(QyTokens.buttonHeight),
        shape: const StadiumBorder(),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: QyColors.surfaceSoft,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(QyTokens.radiusXl),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(QyTokens.radiusXl),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(QyTokens.radiusXl),
        borderSide: const BorderSide(color: QyColors.primary, width: 1.5),
      ),
    ),
  );
}
