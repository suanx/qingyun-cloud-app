import 'package:flutter/material.dart';
import '../theme/qy_colors.dart';
import '../theme/qy_tokens.dart';
import 'qy_button.dart';
import 'qy_icon.dart';

class QyEmptyState extends StatelessWidget {
  const QyEmptyState({
    super.key,
    this.icon = QyIcons.empty,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final String icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: QyColors.surfaceSoft,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            QyIcon(icon, size: 48, color: const Color(0xFF6B5A2A)),
            const SizedBox(height: 24),
            Text(title, style: textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: QyTokens.spaceSm),
            Text(description, style: textTheme.bodyMedium, textAlign: TextAlign.center),
            if (actionLabel != null) ...<Widget>[
              const SizedBox(height: QyTokens.spaceXxl),
              SizedBox(
                width: 150,
                child: QyButton(actionLabel!, onPressed: onAction),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
