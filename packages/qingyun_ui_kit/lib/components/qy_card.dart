import 'package:flutter/material.dart';
import '../theme/qy_colors.dart';
import '../theme/qy_tokens.dart';
import 'qy_frost.dart';

/// 玻璃面卡片：半透明白玻璃面 + 细描边 + 浅色投影，无模糊层、内容清晰。
class QyCard extends StatelessWidget {
  const QyCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = QyColors.surface,
    this.elevated = true,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// 玻璃底色：默认白色玻璃；传入其他颜色时以 86% 不透明度呈现彩色玻璃。
  final Color color;
  final bool elevated;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    final glass = color == QyColors.surface ? QyColors.frost : color.withOpacity(0.86);
    return QyFrost(
      borderRadius: BorderRadius.circular(QyTokens.radiusLg),
      color: glass,
      shadows: elevated ? <BoxShadow>[QyTokens.softShadow(QyColors.softShadow)] : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(QyTokens.radiusLg),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
