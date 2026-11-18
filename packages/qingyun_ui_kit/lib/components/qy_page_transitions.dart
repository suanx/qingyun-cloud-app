import 'package:flutter/material.dart';

import '../theme/qy_tokens.dart';

/// 原型 screenIn 动画曲线：cubic-bezier(.22,.9,.3,1)。
const Curve qyProtoCurve = Cubic(0.22, 0.9, 0.3, 1);

/// 全局页面转场：与原型 `.screen.active` 一致——
/// 淡入 + 上滑 10px + 缩放 .995，320ms，无灰色 scrim，不遮挡下层内容。
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
      curve: qyProtoCurve,
      reverseCurve: qyProtoCurve,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.0123),
          end: Offset.zero,
        ).animate(curved),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.995, end: 1).animate(curved),
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
