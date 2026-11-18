import 'package:flutter/material.dart';

import '../theme/qy_tokens.dart';

/// 统一的圆润按压反馈：按下轻微缩小，松手弹性回弹。
///
/// 用于卡片、列表行、胶囊等自定义布局；child 内部请勿再放带 onTap 的
/// InkWell，避免手势竞技场里两个 recognizer 互相抢占。
class QyTapScale extends StatefulWidget {
  const QyTapScale({
    super.key,
    required this.child,
    required this.onTap,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool enabled;

  @override
  State<QyTapScale> createState() => _QyTapScaleState();
}

class _QyTapScaleState extends State<QyTapScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: QyTokens.shortMotion,
    lowerBound: 0.955,
    upperBound: 1,
    value: 1,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _press() {
    if (widget.enabled) _controller.reverse();
  }

  void _release() {
    if (widget.enabled) _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? widget.onTap : null,
      onTapDown: (_) => _press(),
      onTapUp: (_) => _release(),
      onTapCancel: _release,
      child: ScaleTransition(scale: _controller, child: widget.child),
    );
  }
}
