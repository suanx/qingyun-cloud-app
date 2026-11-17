/// 全局配置。后端对接方式见 docs/BACKEND.md。
abstract final class AppConfig {
  static const String appName = '轻云';

  /// 后端服务基地址。替换为真实服务地址后，将 [useMockData] 置为 false。
  static const String apiBaseUrl = 'https://api.qingyun.example.com';

  /// true：使用内置示例数据展示 UI（无后端也可运行）。
  /// false：所有页面走 [ApiClient] 请求真实后端。
  static const bool useMockData = true;

  /// 是否启用设计稿字体（Noto Sans SC / Outfit）。
  /// 需要先在 pubspec.yaml 声明字体资源，详见 docs/BUILD.md。
  static const bool useDesignFonts = false;

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
