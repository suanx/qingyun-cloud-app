import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 登录凭证存储（持久化到 shared_preferences）。
///
/// 支持两类 lanflare 凭证，[credential] 按前缀自动区分：
/// - `lf_...` API 令牌 → 请求头 `Authorization: Bearer <token>`
/// - `basic:<base64(u:p)>` 账号密码凭证 → 请求头 `Authorization: Basic <b64>`
///
/// 正式发布可替换为 flutter_secure_storage 等加密存储（接口保持一致）。
abstract final class TokenStore {
  static const String _prefKey = 'lanflare_credential';

  static String? _credential;

  /// 当前凭证（可能为空；[load] 之后才有值）。
  static String? get credential => _credential;

  /// 兼容旧调用方（demo 页）：等同于 [credential]。
  static String? get accessToken => _credential;

  /// App 启动时恢复持久化凭证（main 里 await）。
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _credential = prefs.getString(_prefKey);
  }

  /// 保存凭证并立即持久化。
  static Future<void> save(String credential) async {
    _credential = credential;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, credential);
  }

  /// 由账号密码生成 Basic 凭证（登录成功后调用）。
  static String basicCredential(String account, String password) =>
      'basic:${base64Encode(utf8.encode('$account:$password'))}';

  /// 清除凭证（退出登录 / 401 失效）。
  static Future<void> clear() async {
    _credential = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }
}
