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
  /// 默认关闭：部分 Android 设备的 Skia/GPU 合成存在 BackdropFilter
  /// 模糊区域异常扩大的问题，模糊会泄漏到整个页面，导致整页内容被雾化。
  /// 该问题已复发过一次（1370ffc6ea 关闭 → 5ef54af7a5 重新启用 → 复发），
  /// 且 [RepaintBoundary] 隔离不足以在所有机型上兜住，故以总开关短路为准。
  ///
  /// 关闭后全 App 仅保留玻璃面质感（半透明面 + 细描边 + 柔投影），
  /// 内容 100% 清晰；AppBar / 底部导航 / Toast 的调用点已统一改为
  /// `backdrop: false`，运行时不再创建任何 BackdropFilter，总开关仅作兜底。
  ///
  /// 请勿在未经多机型真机回归验证前重新开启；恢复时须同步更新
  /// docs/DESIGN_SPEC.md 的「当前实现状态」说明。
  static bool realBlurEnabled = false;

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
  /// 当前全 App 调用点均为 false：整页雾化问题在多机型上无法稳定兜底，
  /// 已按 DESIGN_SPEC 统一收敛为玻璃面模式。见 [realBlurEnabled]。
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
    // 注意：realBlurEnabled 当前为 false，以下分支不会执行；保留实现
    // 以便按 DESIGN_SPEC 的流程完成多机型验证后再评估恢复。
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
