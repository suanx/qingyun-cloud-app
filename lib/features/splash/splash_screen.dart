import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

import '../../core/config/app_config.dart';

/// 启动页：纯白背景 + 钢青蓝灰品牌标识，停顿后进入首页。
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) context.go(QyRoutes.home);
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: QyColors.canvas,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const QyTintedIconCircle(QyIcons.cloud, hue: QyHues.slate, size: 96),
              const SizedBox(height: QyTokens.spaceXxl),
              Text(AppConfig.appName, style: textTheme.displayLarge),
              const SizedBox(height: QyTokens.spaceSm),
              Text('把每一份文件，轻轻放进云里', style: textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
