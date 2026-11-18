import 'package:flutter/material.dart';

/// Cool slate-blue palette on a pure white canvas.
///
/// 视觉规范（对齐参考图）：
/// - 页面背景一律纯白，不再使用暖黄画布、渐变与装饰底纹；
/// - 主色为钢青蓝灰（参考图进度条 / 底部导航选中态）；
/// - 文字近黑 + 冷灰两级；
/// - 另定义一组同饱和度的彩色强调色，供彩色图标系统使用。
abstract final class QyColors {
  static const Color primary = Color(0xFF4A7386);
  static const Color primaryDeep = Color(0xFF39596A);
  static const Color primaryLight = Color(0xFFE3EDF2);

  /// 纯白画布（所有页面背景）。
  static const Color canvas = Color(0xFFFFFFFF);

  static const Color surface = Color(0xFFFFFFFF);

  /// 浅灰蓝卡片底（用于强调卡片，替代原暖黄渐变）。
  static const Color surfaceSoft = Color(0xFFF4F7F9);

  // ---- 彩色强调色族（彩色图标专用，饱和度统一） ----
  static const Color coral = Color(0xFFE96A5B);
  static const Color mint = Color(0xFF2FB5A3);
  static const Color sky = Color(0xFF4E8FD9);
  static const Color gold = Color(0xFFD9A441);
  static const Color violet = Color(0xFF8B7CD8);
  static const Color leaf = Color(0xFF43AE7C);

  static const Color ink = Color(0xFF20262B);
  static const Color sub = Color(0xFF8B959E);
  static const Color muted = Color(0xFFB7BFC6);
  static const Color border = Color(0xFFE9EDF0);
  static const Color divider = Color(0xFFF1F4F6);
  static const Color success = Color(0xFF43AE7C);
  static const Color error = Color(0xFFE96A5B);
  static const Color onDark = Color(0xFFFFFFFF);

  /// 8% 冷灰蓝投影（替代原暖黄投影）。
  static const Color softShadow = Color(0x14809AAB);

  // ---- 磨砂玻璃（frosted glass） ----
  /// 玻璃面：72% 半透明白。
  static const Color frost = Color(0xB8FFFFFF);

  /// 强玻璃面：90% 半透明白（应用栏、底部导航）。
  static const Color frostStrong = Color(0xE6FFFFFF);

  /// 深色玻璃面：72% 墨色（Toast）。
  static const Color frostDark = Color(0xB820262B);
}
