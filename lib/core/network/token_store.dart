/// 极简登录态存储。接入真实后端后可替换为
/// flutter_secure_storage / shared_preferences 等实现（接口保持一致）。
abstract final class TokenStore {
  static String? _accessToken;

  static String? get accessToken => _accessToken;

  static void save(String token) => _accessToken = token;

  static void clear() => _accessToken = null;
}
