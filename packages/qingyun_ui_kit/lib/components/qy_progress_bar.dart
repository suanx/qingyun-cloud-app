import 'package:flutter/material.dart';
import '../theme/qy_colors.dart';

class QyProgressBar extends StatelessWidget {
  const QyProgressBar({
    super.key,
    required this.value,
    this.color = QyColors.primaryDeep,
    this.backgroundColor = const Color(0xFFF3DFA8),
    this.height = 6,
  });

  /// 0.0 - 1.0
  final double value;
  final Color color;
  final Color backgroundColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: ColoredBox(color: backgroundColor)),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: clamped,
                child: ColoredBox(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
