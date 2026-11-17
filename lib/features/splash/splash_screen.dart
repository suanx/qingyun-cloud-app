import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

import '../../core/config/app_config.dart';

/// 启动页：暖黄渐变 + 云朵标识，停顿后进入首页。
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
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: QyColors.warmGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: QyColors.surface,
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[QyTokens.softShadow(QyColors.warmShadow)],
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(28),
                    child: QyIcon(QyIcons.cloud, size: 56, color: QyColors.primaryDeep),
                  ),
                ),
                const SizedBox(height: QyTokens.spaceXxl),
                Text(AppConfig.appName, style: textTheme.displayLarge),
                const SizedBox(height: QyTokens.spaceSm),
                Text('把每一份文件，轻轻放进云里', style: textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
