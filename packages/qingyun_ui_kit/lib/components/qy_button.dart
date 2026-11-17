import 'package:flutter/material.dart';
import '../theme/qy_colors.dart';
import '../theme/qy_tokens.dart';

enum QyButtonVariant { primary, secondary, outline, disabled }

class QyButton extends StatelessWidget {
  const QyButton(
    this.label, {
    super.key,
    this.onPressed,
    this.variant = QyButtonVariant.primary,
    this.icon,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final QyButtonVariant variant;
  final Widget? icon;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final enabled = variant != QyButtonVariant.disabled && onPressed != null;

    final Color background;
    final Color foreground;
    final BorderSide? side;
    switch (variant) {
      case QyButtonVariant.primary:
        background = QyColors.primary;
        foreground = QyColors.ink;
        side = null;
      case QyButtonVariant.secondary:
        background = QyColors.primaryLight;
        foreground = const Color(0xFF6B5A2A);
        side = null;
      case QyButtonVariant.outline:
        background = Colors.transparent;
        foreground = QyColors.sub;
        side = const BorderSide(color: QyColors.border, width: 1.5);
      case QyButtonVariant.disabled:
        background = const Color(0xFFF3EFE4);
        foreground = const Color(0xFFBDB5A3);
        side = null;
    }

    final child = SizedBox(
      height: QyTokens.buttonHeight,
      width: expanded ? double.infinity : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(QyTokens.radiusXl),
          border: side == null ? null : Border.fromBorderSide(side),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(QyTokens.radiusXl),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (icon != null) ...<Widget>[icon!, const SizedBox(width: 8)],
                  Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: foreground)),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return AnimatedScale(
      scale: enabled ? 1 : 0.98,
      duration: QyTokens.shortMotion,
      child: child,
    );
  }
}
