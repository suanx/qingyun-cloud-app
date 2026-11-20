import 'package:flutter/material.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';
import '../core/config/app_config.dart';
import '../core/router/app_router.dart';

class QingyunApp extends StatelessWidget {
  const QingyunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: qyLightTheme(),
      routerConfig: AppRouter.router,
      // 全局 Material 祖先：多数二级页以 ColoredBox 为根、没有 Scaffold，
      // 其 Text 缺少 Material 祖先时框架会套用兜底文本样式（黄色下划线、
      // 渲染发虚）。在这里统一包一层透明 Material，所有路由（含登录页、
      // 二级页与后续新页）都继承主题文本样式，页面自身背景照常绘制。
      builder: (BuildContext context, Widget? child) => Material(
        type: MaterialType.transparency,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
