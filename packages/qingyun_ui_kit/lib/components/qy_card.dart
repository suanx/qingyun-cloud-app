import 'package:flutter/material.dart';
import '../theme/qy_colors.dart';
import '../theme/qy_tokens.dart';

class QyCard extends StatelessWidget {
  const QyCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.gradient,
    this.color = QyColors.surface,
    this.elevated = true,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final List<Color>? gradient;
  final Color color;
  final bool elevated;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: gradient == null ? color : null,
      gradient: gradient == null
          ? null
          : LinearGradient(colors: gradient!, begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(QyTokens.radiusLg),
      boxShadow: elevated ? <BoxShadow>[QyTokens.softShadow(QyColors.warmShadow)] : null,
    );

    return DecoratedBox(
      decoration: decoration,
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
