import 'package:flutter/material.dart';
import 'qy_colors.dart';
import 'qy_tokens.dart';
import 'qy_typography.dart';

ThemeData qyLightTheme() {
  const scheme = ColorScheme.light(
    primary: QyColors.primary,
    onPrimary: QyColors.ink,
    primaryContainer: QyColors.primaryLight,
    onPrimaryContainer: QyColors.ink,
    secondary: QyColors.coral,
    onSecondary: QyColors.ink,
    secondaryContainer: QyColors.mint,
    onSecondaryContainer: QyColors.ink,
    tertiary: QyColors.sky,
    onTertiary: QyColors.ink,
    surface: QyColors.canvas,
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
    splashFactory: InkRipple.splashFactory,
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
        borderRadius: BorderRadius.circular(QyTokens.radiusLg),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: QyColors.primary,
        foregroundColor: QyColors.ink,
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
      fillColor: QyColors.primaryLight,
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
        borderSide: const BorderSide(color: QyColors.primaryDeep, width: 1.5),
      ),
    ),
  );
}
