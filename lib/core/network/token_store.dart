import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 登录凭证存储：加密保存到系统密钥库（Android Keystore / iOS Keychain）。
///
/// 实际保存的是 lanflare 签发的可吊销 `lf_...` API 令牌；令牌换发失败时
/// 降级保存会话值（`Cookie: lf_session=`）。`basic:` 前缀仅用于兼容历史版本
/// 已写入加密存储的旧凭证，客户端不再生成该格式。
///
/// 旧版本曾把凭证明文写入 `shared_preferences`，[load] 会一并清除该旧键，
/// 避免升级后仍残留可还原的账号口令。
abstract final class TokenStore {
  static const String _key = 'lanflare_credential';
  static const String _tokenIdKey = 'lanflare_api_token_id';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static String? _credential;
  static String? _tokenId;

  /// 当前凭证（可能为空；[load] 之后才有值）。
  static String? get credential => _credential;

  /// 当前 API 令牌的服务端 id，用于退出登录时吊销；session 降级时为 null。
  static String? get tokenId => _tokenId;

  /// App 启动时恢复凭证，并清理旧版明文数据。
  static Future<void> load() async {
    _credential = await _storage.read(key: _key);
    _tokenId = await _storage.read(key: _tokenIdKey);
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_key)) {
      await prefs.remove(_key);
    }
  }

  /// 保存凭证并立即加密持久化；[tokenId] 为对应的服务端令牌 id。
  static Future<void> save(String credential, {String? tokenId}) async {
    _credential = credential;
    await _storage.write(key: _key, value: credential);
    if (tokenId != null && tokenId.isNotEmpty) {
      _tokenId = tokenId;
      await _storage.write(key: _tokenIdKey, value: tokenId);
    } else {
      _tokenId = null;
      await _storage.delete(key: _tokenIdKey);
    }
  }

  /// 清除凭证（退出登录 / 401 失效）。
  static Future<void> clear() async {
    _credential = null;
    _tokenId = null;
    await _storage.delete(key: _key);
    await _storage.delete(key: _tokenIdKey);
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_key)) {
      await prefs.remove(_key);
    }
  }
}
