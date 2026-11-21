/// 全局配置。后端对接方式见 docs/BACKEND.md。
abstract final class AppConfig {
  static const String appName = '轻云';

  /// 应用版本号（与 pubspec.yaml 的 version 保持一致；Android 随之同步）。
  static const String appVersion = '0.1.12';
  static const int buildNumber = 13;
  static const String versionLabel = 'v0.1.12 (build 13)';

  /// 后端服务基地址：lanflare（Cloudflare Workers，自定义域，国内可达）。
  /// 具体账号与服务端密钥由后端自行管理，客户端不保存、不描述。
  static const String apiBaseUrl = 'https://lz.miro.us.ci';

  /// lanflare 未配置 STORAGE_TOTAL_BYTES 时，容量卡使用该兜底总量（GB）。
  static const double fallbackTotalGb = 100;

  /// lanflare 单请求上传上限（与 Worker 端 MAX_UPLOAD_BYTES 一致）。
  static const int maxUploadBytes = 90 * 1024 * 1024;

  /// 直传 / 分块的分界：不超过此大小走单请求直传，更大的文件自动分块。
  /// 直传要把一条连接保持到存储端收完整个文件，大文件在弱网或存储端
  /// 限速时连接中途断开就整文件失败（实测 50MB 直传必挂）；分块每块
  /// 独立请求、失败只重发当前块，可靠得多。
  static const int directUploadMaxBytes = 8 * 1024 * 1024;

  /// 是否启用设计稿字体（Noto Sans SC / Outfit）。
  /// 需要先在 pubspec.yaml 声明字体资源，详见 docs/BUILD.md。
  static const bool useDesignFonts = false;

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
