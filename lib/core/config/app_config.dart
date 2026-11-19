/// 全局配置。后端对接方式见 docs/BACKEND.md。
abstract final class AppConfig {
  static const String appName = '轻云';

  /// 应用版本号（与 pubspec.yaml 的 version 保持一致；Android/iOS 随之同步）。
  static const String appVersion = '0.1.12';
  static const int buildNumber = 13;
  static const String versionLabel = 'v0.1.12 (build 13)';

  /// 后端服务基地址：lanflare（Cloudflare Workers，自定义域，国内可达）。
  /// 登录账号密码 = lanflare 的 APP_USERNAME / APP_PASSWORD。
  static const String apiBaseUrl = 'https://lz.miro.us.ci';

  /// true：使用内置示例数据展示 UI（无后端也可运行）。
  /// false：所有页面走 [ApiClient] 请求 lanflare 后端。
  static const bool useMockData = false;

  /// lanflare 未配置 STORAGE_TOTAL_BYTES 时，容量卡使用该兜底总量（GB）。
  static const double fallbackTotalGb = 100;

  /// lanflare 单请求上传上限（与 Worker 端 MAX_UPLOAD_BYTES 一致）。
  static const int maxUploadBytes = 90 * 1024 * 1024;

  /// 是否启用设计稿字体（Noto Sans SC / Outfit）。
  /// 需要先在 pubspec.yaml 声明字体资源，详见 docs/BUILD.md。
  static const bool useDesignFonts = false;

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
