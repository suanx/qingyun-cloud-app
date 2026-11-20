import 'package:flutter/foundation.dart';

/// 全局错误上报入口。
///
/// 默认把未捕获异常打到开发日志；接入崩溃上报服务时，只需在 [hook] 里
/// 转发到对应 SDK，无需改动 main / 页面中的捕获点。
abstract final class ErrorReporter {
  /// 自定义上报钩子（context 用于区分来源，如 FlutterError / runZonedGuarded）。
  static void Function(Object error, StackTrace stack, {String? context})? hook;

  static void report(Object error, StackTrace? stack, {String? context}) {
    final resolved = stack ?? StackTrace.current;
    final handler = hook;
    if (handler != null) {
      handler(error, resolved, context: context);
      return;
    }
    debugPrint('[QingyunError] ${context ?? 'unhandled'}: $error\n$resolved');
  }
}
