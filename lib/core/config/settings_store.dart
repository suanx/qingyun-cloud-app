import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/transfer_store.dart';
import '../network/api_client.dart';

/// 应用级本地设置（不上传、不与账号绑定）。
///
/// 自建 VPS 部署时，用户需要把 [AppConfig.apiBaseUrl] 指向自己的域名；
/// 覆盖值只存在本地，[ApiClient] 启动时与修改后立即同步。
abstract final class SettingsStore {
  static const String baseUrlOverrideKey = 'qingyun_api_base_url_override';

  /// 与搜索页共用同一个 key，避免「清除了历史但搜索页还读另一份」。
  static const String searchHistoryKey = 'qingyun_search_history';

  /// 当前生效的基地址：有覆盖值用覆盖值，否则用编译默认值。
  static Future<String> effectiveBaseUrl() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String saved = prefs.getString(baseUrlOverrideKey)?.trim() ?? '';
    return saved.isEmpty ? AppConfig.apiBaseUrl : saved;
  }

  static Future<bool> hasCustomBaseUrl() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String saved = prefs.getString(baseUrlOverrideKey)?.trim() ?? '';
    return saved.isNotEmpty;
  }

  /// App 启动时把持久化地址同步给全局 ApiClient（必须在首个请求之前调用）。
  static Future<void> applyToApiClient() async {
    ApiClient.shared.baseUrl = await effectiveBaseUrl();
  }

  /// 规范化并校验用户填写的服务地址：只接受 http/https 的 origin，
  /// 不带路径、查询、用户名密码；尾部斜杠统一去掉。
  /// 非法输入返回 null，由 UI 提示，不写入任何配置。
  static String? normalizeBaseUrl(String raw) {
    String value = raw.trim();
    if (value.isEmpty) return null;
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    final Uri? uri = Uri.tryParse(value);
    if (uri == null) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    if (uri.host.isEmpty) return null;
    if (uri.userInfo.isNotEmpty || uri.query.isNotEmpty || uri.fragment.isNotEmpty) {
      return null;
    }
    if (uri.hasPort && (uri.port <= 0 || uri.port > 65535)) return null;
    if (uri.path.isNotEmpty && uri.path != '/') return null;
    return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  }

  /// 保存覆盖值；传 null / 空串恢复编译默认值。保存后立即改变全局基地址。
  static Future<void> setApiBaseUrl(String? normalized) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (normalized == null || normalized.isEmpty || normalized == AppConfig.apiBaseUrl) {
      await prefs.remove(baseUrlOverrideKey);
    } else {
      await prefs.setString(baseUrlOverrideKey, normalized);
    }
    ApiClient.shared.baseUrl = await effectiveBaseUrl();
  }

  /// 清除搜索页历史；返回被删除的词条数。
  static Future<int> clearSearchHistory() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> existing = prefs.getStringList(searchHistoryKey) ?? <String>[];
    await prefs.remove(searchHistoryKey);
    return existing.length;
  }

  /// 清除传输任务记录；返回被删除的任务数。
  static int clearTransfers() => LocalTransferStore.instance.clear();
}
