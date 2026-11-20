/// 统一业务异常。
///
/// lanflare 返回原生 JSON，业务失败 `{ "error": "..." }` 与 HTTP 4xx/5xx
/// 均由 `ApiClient` 映射为 `ApiException`，页面只需处理本类型。
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  /// 错误码：HTTP 状态码 × 100，网络层本地错误使用负数。
  final int code;

  /// 用户可读的错误信息。
  final String message;

  /// HTTP 状态码（仅当存在 HTTP 响应时提供）。
  final int? statusCode;

  factory ApiException.network() =>
      const ApiException(code: -1, message: '网络连接不可用，请检查网络后重试');

  factory ApiException.timeout() =>
      const ApiException(code: -2, message: '请求超时，请稍后重试');

  factory ApiException.cancelled() =>
      const ApiException(code: -3, message: '请求已取消');

  factory ApiException.badResponse(int statusCode, String message) =>
      ApiException(code: statusCode * 100, message: message, statusCode: statusCode);

  factory ApiException.unknown(String message) =>
      ApiException(code: -99, message: message);

  /// 本地主动取消（用户暂停 / 取消传输），不是网络或服务端失败。
  static const int cancelledCode = -3;

  bool get isCancelled => code == cancelledCode;

  @override
  String toString() => 'ApiException($code, $message${statusCode == null ? '' : ', http:$statusCode'})';
}
