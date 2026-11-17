/// REST 接口约定（与 docs/BACKEND.md 一一对应）。
abstract final class ApiEndpoints {
  // ---- 认证 ----
  static const String login = '/api/v1/auth/login';
  static const String refreshToken = '/api/v1/auth/token/refresh';
  static const String logout = '/api/v1/auth/logout';

  // ---- 容量 ----
  static const String storageSummary = '/api/v1/storage/summary';

  // ---- 文件 ----
  static const String files = '/api/v1/files';
  static String fileDetail(String id) => '/api/v1/files/$id';
  static String fileDownload(String id) => '/api/v1/files/$id/download';
  static String fileShare(String id) => '/api/v1/files/$id/share';
  static const String trash = '/api/v1/trash';
  static String trashRestore(String id) => '/api/v1/trash/$id/restore';

  // ---- 传输任务 ----
  static const String transfers = '/api/v1/transfers';
  static String transferPause(String id) => '/api/v1/transfers/$id/pause';
  static String transferResume(String id) => '/api/v1/transfers/$id/resume';
  static String transferCancel(String id) => '/api/v1/transfers/$id/cancel';
}
