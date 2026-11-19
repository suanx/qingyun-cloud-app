/// 全局配置。后端对接方式见 docs/BACKEND.md。
abstract final class AppConfig {
  static const String appName = '轻云';

  /// 应用版本号（与 pubspec.yaml 的 version 保持一致；Android/iOS 随之同步）。
  static const String appVersion = '0.1.11';
  static const int buildNumber = 12;
  static const String versionLabel = 'v0.1.11 (build 12)';

  /// 后端服务基地址：lanflare（Cloudflare Workers / VPS Docker 均可）。
  /// 替换为你的实际部署地址，例如 https://lanflare.<你的子域>.workers.dev
  static const String apiBaseUrl = 'https://lanflare.example.workers.dev';

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
