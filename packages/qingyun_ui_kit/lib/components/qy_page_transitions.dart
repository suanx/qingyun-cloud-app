import 'package:flutter/material.dart';

import '../theme/qy_tokens.dart';

/// 全局页面转场：淡入 + 轻微上滑 + 微小缩放，全程柔和曲线。
///
/// 替代系统默认带灰色 scrim 的硬切换，让所有页面的进入 / 返回都保持
/// 连续、圆润、无遮挡的观感；也不会在转场途中透出下层页面的内容。
class QyPageTransitionsBuilder extends PageTransitionsBuilder {
  const QyPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final Animation<double> curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.024),
          end: Offset.zero,
        ).animate(curved),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.978, end: 1).animate(curved),
          child: child,
        ),
      ),
    );
  }
}

/// 供主题注册用的全平台转场表，避免各端表现不一致。
const PageTransitionsTheme qyPageTransitionsTheme = PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: QyPageTransitionsBuilder(),
    TargetPlatform.iOS: QyPageTransitionsBuilder(),
    TargetPlatform.macOS: QyPageTransitionsBuilder(),
    TargetPlatform.windows: QyPageTransitionsBuilder(),
    TargetPlatform.linux: QyPageTransitionsBuilder(),
    TargetPlatform.fuchsia: QyPageTransitionsBuilder(),
  },
);

/// 交错入场动效的单步时长，供页面按序号错开播放。
Duration qyEntranceStep(int index) => Duration(
      milliseconds: QyTokens.entranceStepMilliseconds * index,
    );
