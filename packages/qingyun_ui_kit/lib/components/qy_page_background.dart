import 'package:flutter/material.dart';

import '../theme/qy_colors.dart';

/// 全局页面背景：纯白不透明底。
///
/// 早期版本叠加过一层冷调渐变作为玻璃面"空气层"，但在真机上会让页面顶部
/// 出现整片淡蓝雾感、与纯白基调冲突。现统一收敛为纯白 [ColoredBox]：
/// 既保证所有页面（含被 push 的独立页）背景不透明，也让卡片只靠极淡描边
/// 与柔投影浮起，观感更干净。
class QyPageBackground extends StatelessWidget {
  const QyPageBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: QyColors.canvas, child: child);
  }
}
