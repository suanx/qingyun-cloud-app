import 'dart:ui';

import 'package:flutter/material.dart';
import '../theme/qy_colors.dart';

/// 磨砂玻璃容器：背景高斯模糊 + 半透明填充 + 细描边。
///
/// 全局玻璃质感的基础组件——卡片、应用栏、底部导航、Toast 等
/// 均通过本组件获得统一的磨砂效果。
class QyFrost extends StatelessWidget {
  const QyFrost({
    super.key,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.color = QyColors.frost,
    this.blur = 18,
    this.borderColor = QyColors.border,
    this.showBorder = true,
    this.shadows,
    this.padding,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// 半透明填充色（默认 72% 白）。
  final Color color;

  /// 高斯模糊半径。
  final double blur;

  final Color borderColor;
  final bool showBorder;
  final List<BoxShadow>? shadows;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    Widget body = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        border: showBorder ? Border.all(color: borderColor, width: 1) : null,
        borderRadius: borderRadius,
        boxShadow: shadows,
      ),
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
    if (borderRadius != BorderRadius.zero) {
      body = ClipRRect(borderRadius: borderRadius, child: body);
    }
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: const SizedBox.expand(),
          ),
        ),
        body,
      ],
    );
  }
}
