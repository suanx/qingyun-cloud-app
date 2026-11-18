import 'package:flutter/material.dart';

/// 轻云高保真原型 v1 色板。
///
/// 与《轻云-云盘App原型-v1.html》的 :root 变量一一对应：
/// --primary #2F6BFF / --mint #22C7AC / --amber #FFB020 /
/// --violet #8C7BFF / --pink #FF7AA2 / --bg #F5F7FB。
abstract final class QyColors {
  static const Color primary = Color(0xFF2F6BFF);
  static const Color primaryDeep = Color(0xFF1E4FD8);
  static const Color primaryLight = Color(0xFFEAF1FF);

  /// 页面背景（原型 --bg）。
  static const Color canvas = Color(0xFFF5F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFF5F7FB);

  // ---- 原型五组强调色 ----
  static const Color blueLight = Color(0xFF4C8DFF);
  static const Color mint = Color(0xFF22C7AC);
  static const Color mintSoft = Color(0xFFE4F8F4);
  static const Color amber = Color(0xFFFFB020);
  static const Color amberSoft = Color(0xFFFFF4E0);
  static const Color violet = Color(0xFF8C7BFF);
  static const Color violetSoft = Color(0xFFF0EDFF);
  static const Color pink = Color(0xFFFF7AA2);
  static const Color pinkSoft = Color(0xFFFFEDF2);

  // 深色变体（图标/文字用）
  static const Color mintDeep = Color(0xFF12A88F);
  static const Color amberDeep = Color(0xFFE08A00);
  static const Color violetDeep = Color(0xFF7B67F0);
  static const Color pinkDeep = Color(0xFFE04F7C);

  // 兼容旧组件的同族 token
  static const Color sky = blueLight;
  static const Color gold = amber;
  static const Color coral = pink;
  static const Color leaf = mintDeep;

  static const Color ink = Color(0xFF101828);
  static const Color sub = Color(0xFF667085);
  static const Color muted = Color(0xFF98A2B3);
  static const Color border = Color(0xFFEEF2F7);
  static const Color divider = Color(0xFFF6F8FC);
  static const Color success = mint;
  static const Color error = Color(0xFFE04F7C);
  static const Color onDark = Color(0xFFFFFFFF);

  /// 原型辅助色
  static const Color heroLabel = Color(0xFF7A8AA8);
  static const Color hint = Color(0xFFC3CBD9);
  static const Color track = Color(0xFFEFF3FA);
  static const Color chevron = Color(0xFFD2D9E5);
  static const Color darkBg = Color(0xFF0B0F16);

  /// 8% 冷蓝投影基色（原型 rgba(31,72,153,.16)）。
  static const Color softShadow = Color(0x291F4899);

  // ---- 玻璃面（真磨砂保持全局关闭）----
  static const Color frost = Color(0xE6FFFFFF);
  static const Color frostStrong = Color(0xF0FFFFFF);
  static const Color frostDark = Color(0xDB101828);
  static const Color navWhite = Color(0xF0FFFFFF);
}
