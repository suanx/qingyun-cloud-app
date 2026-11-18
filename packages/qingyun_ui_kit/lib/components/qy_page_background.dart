import 'package:flutter/material.dart';

/// 全局页面背景：纯白 + 顶部近乎不可见的冷调光晕。
///
/// 作为玻璃面体系的"空气层"——为玻璃卡片、面板提供柔和的明度过渡，
/// 不遮挡内容、不含模糊层、不参与命中测试之外的任何交互。
/// 渐变已收敛到近乎纯白，避免在浅色页面上出现整片冷色雾感。
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
            Color(0xFFF8FBFD), // 顶部：近乎纯白的冷调光晕
            Color(0xFFFCFDFE), // 中段过渡
            Color(0xFFFFFFFF), // 底部：纯白
          ],
        ),
      ),
      child: child,
    );
  }
}
