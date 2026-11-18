import 'package:flutter/material.dart';

/// 全局页面背景：白底 + 顶部极淡冷调光晕。
///
/// 作为磨砂玻璃体系的"空气层"——为玻璃卡片、面板提供柔和的背景层次，
/// 使玻璃面与背景之间形成自然的明度过渡。纯装饰性静态渐变：
/// 不含模糊层、不遮挡内容、不参与命中测试之外的任何交互。
class QyPageBackground extends StatelessWidget {
  const QyPageBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: <double>[0, 0.32, 1],
          colors: <Color>[
            Color(0xFFE9F0F4), // 顶部：极淡钢青蓝灰光晕
            Color(0xFFF6F9FB), // 中段过渡
            Color(0xFFFFFFFF), // 底部：回归纯白
          ],
        ),
      ),
      child: child,
    );
  }
}
