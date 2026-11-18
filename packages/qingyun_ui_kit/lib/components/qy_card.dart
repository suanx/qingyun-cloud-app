import 'package:flutter/material.dart';
import '../theme/qy_colors.dart';
import '../theme/qy_tokens.dart';
import 'qy_frost.dart';

/// 玻璃面卡片：半透明白玻璃面 + 极淡描边 + 大圆角 + 柔投影，无模糊层。
class QyCard extends StatelessWidget {
  const QyCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
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
      borderRadius: const BorderRadius.all(Radius.circular(QyTokens.radiusCard)),
      color: glass,
      borderColor: QyColors.divider,
      shadows: elevated
          ? <BoxShadow>[QyTokens.cardShadowSoft(QyColors.softShadow)]
          : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(QyTokens.radiusCard)),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
