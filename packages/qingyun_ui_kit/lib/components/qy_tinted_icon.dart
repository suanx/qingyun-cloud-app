import 'package:flutter/material.dart';
import 'qy_icon.dart';

/// 彩色图标色族：每个色族由「深色图形 + 浅色底」组成，饱和度统一，
/// 保证不同颜色的图标放在一起风格一致、清晰可识别。
class QyIconHue {
  const QyIconHue(this.color, this.soft);

  /// 图形（描边）颜色。
  final Color color;

  /// 圆角底色。
  final Color soft;
}

/// 预置色族。
abstract final class QyHues {
  static const QyIconHue blue = QyIconHue(Color(0xFF4E8FD9), Color(0xFFEAF2FC));
  static const QyIconHue teal = QyIconHue(Color(0xFF2FB5A3), Color(0xFFE3F5F2));
  static const QyIconHue orange = QyIconHue(Color(0xFFF09A4E), Color(0xFFFDF0E2));
  static const QyIconHue purple = QyIconHue(Color(0xFF8B7CD8), Color(0xFFEFEAFB));
  static const QyIconHue green = QyIconHue(Color(0xFF43AE7C), Color(0xFFE5F4EC));
  static const QyIconHue coral = QyIconHue(Color(0xFFE96A5B), Color(0xFFFCEAE7));
  static const QyIconHue gold = QyIconHue(Color(0xFFD9A441), Color(0xFFFAF1DD));
  static const QyIconHue slate = QyIconHue(Color(0xFF4A7386), Color(0xFFE3EDF2));
  static const QyIconHue gray = QyIconHue(Color(0xFF8B959E), Color(0xFFF1F4F6));
}

/// 彩色图标：圆角浅色底 + 同族深色描边图形。
///
/// 全 App 的功能入口、菜单、分类等处统一使用本组件呈现彩色图标，
/// 替代原先的单色线性图标。
class QyTintedIcon extends StatelessWidget {
  const QyTintedIcon(
    this.icon, {
    super.key,
    this.hue = QyHues.slate,
    this.size = 44,
    double? radius,
  }) : _radius = radius;

  final String icon;
  final QyIconHue hue;

  /// 外框边长（正方形）。
  final double size;

  /// 圆角，默认取边长的 30%。
  final double? _radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: hue.soft,
        borderRadius: BorderRadius.circular(_radius ?? size * 0.3),
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.25),
        child: QyIcon(icon, size: size * 0.5, color: hue.color),
      ),
    );
  }
}

/// 圆形彩色图标（部分场景需要圆形轮廓）。
class QyTintedIconCircle extends StatelessWidget {
  const QyTintedIconCircle(
    this.icon, {
    super.key,
    this.hue = QyHues.slate,
    this.size = 44,
  });

  final String icon;
  final QyIconHue hue;
  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: hue.soft, shape: BoxShape.circle),
      child: Padding(
        padding: EdgeInsets.all(size * 0.27),
        child: QyIcon(icon, size: size * 0.46, color: hue.color),
      ),
    );
  }
}

/// 阴影便捷引用（供需要与彩色图标搭配的卡片使用）。
const List<BoxShadow> qyCardShadows = <BoxShadow>[
  BoxShadow(
    color: Color(0x14809AAB),
    offset: Offset(0, 4),
    blurRadius: 16,
    spreadRadius: -2,
  ),
];
