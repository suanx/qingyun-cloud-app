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
    );
  }
}
