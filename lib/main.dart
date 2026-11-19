import 'app/app.dart';
import 'core/network/api_client.dart';
import 'core/network/token_store.dart';
import 'core/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 恢复持久化的登录凭证（lanflare Basic / Bearer）。
  await TokenStore.load();
  // 任意接口返回 401 时：清凭证并回到登录页。
  ApiClient.onUnauthorized = AppRouter.handleUnauthorized;
  // 原型头图渐变铺满到状态栏：启用 edgeToEdge + 透明状态栏。
  // 各页面顶部自带 54~58 的 padding，系统状态栏图标不会与标题重叠。
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const QingyunApp());
}
