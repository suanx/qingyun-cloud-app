import 'dart:ui';

import 'package:flutter/material.dart';
import '../theme/qy_colors.dart';

/// 磨砂玻璃容器——全局玻璃质感的统一入口。
///
/// 提供两种模式：
/// - **玻璃面模式**（`backdrop: false`，默认）：半透明填充 + 细描边 + 圆角裁切。
///   不产生真实模糊，内容 100% 清晰、无额外合成开销。用于卡片、面板、
///   列表项、分类胶囊等自身承载内容的组件。
/// - **真磨砂模式**（`backdrop: true`）：在玻璃面之下叠加 [BackdropFilter]
///   高斯模糊，透出并虚化组件背后的滚动内容。仅用于 AppBar、底部导航栏、
///   Toast 浮层等"悬浮于内容之上"的栏体/浮层，避免大面积模糊遮挡页面内容。
class QyFrost extends StatelessWidget {
  /// 全局真磨砂（BackdropFilter）总开关。
  ///
  /// 默认开启，按原设计范围生效：仅 AppBar / 底部导航 / Toast 三类
  /// 悬浮栏体使用真磨砂；承载内容的卡片、面板、列表项始终为玻璃面模式，
  /// 不会出现整片区域被磨砂覆盖的效果。
  /// 真磨砂层统一包裹 [RepaintBoundary]，将背景采样隔离在独立图层内，
  /// 规避部分设备 BackdropFilter 模糊区域异常扩大导致整页雾化的问题。
  static bool realBlurEnabled = true;

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
    this.backdrop = false,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// 玻璃面填充色（默认 90% 白）。
  final Color color;

  /// 高斯模糊半径；仅在 [backdrop] 为 true 时生效。
  final double blur;

  final Color borderColor;
  final bool showBorder;
  final List<BoxShadow>? shadows;
  final EdgeInsetsGeometry? padding;

  /// 是否对组件背后的内容做真实高斯模糊。
  ///
  /// 仅栏体（AppBar / 底部导航）与浮层（Toast）应开启；
  /// 承载内容的卡片、面板保持默认 false，确保内容清晰可读。
  final bool backdrop;

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
    if (!backdrop || !realBlurEnabled) {
      return body;
    }
    // RepaintBoundary：把真磨砂层的背景采样限制在独立重绘边界内，
    // 防止模糊效果泄漏到整个页面（部分机型的合成器兼容性问题）。
    return RepaintBoundary(
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: const SizedBox.expand(),
            ),
          ),
          body,
        ],
      ),
    );
  }
}
