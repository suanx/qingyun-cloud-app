import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app/app.dart';
import 'core/config/settings_store.dart';
import 'core/models/transfer_store.dart';
import 'core/network/api_client.dart';
import 'core/network/token_store.dart';
import 'core/router/app_router.dart';
import 'core/utils/error_reporter.dart';
import 'config/admin_gate.dart';

void main() {
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // 框架内异常（构建 / 布局 / 绘制）。
      FlutterError.onError = (FlutterErrorDetails details) {
        if (kDebugMode) FlutterError.presentError(details);
        ErrorReporter.report(details.exception, details.stack,
            context: 'FlutterError');
      };
      // 平台层未处理异常；返回 true 表示已接管，避免进程直接退出前无日志。
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        ErrorReporter.report(error, stack, context: 'PlatformDispatcher');
        return true;
      };

      // 恢复持久化的登录凭证（加密存储）。
      await TokenStore.load();
      // 恢复已结束的传输记录（本机历史，必须在传输页首帧之前）。
      await LocalTransferStore.instance.load();
      // 应用自建 VPS 时保存的服务地址（必须在首个请求之前）。
      await SettingsStore.applyToApiClient();
      // 读取真实角色：普通用户对文件树只读，App 据此隐藏写入口。
      // 失败时按普通用户处理（安全默认），不阻断启动。
      await AdminGate.instance.refresh();
      // 任意接口返回 401 时：清凭证并回到登录页。
      ApiClient.onUnauthorized = AppRouter.handleUnauthorized;
      // 原型头图渐变铺满到状态栏：启用 edgeToEdge + 透明状态栏。
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ));
      runApp(const QingyunApp());
    },
    (Object error, StackTrace stack) =>
        ErrorReporter.report(error, stack, context: 'runZonedGuarded'),
  );
}
