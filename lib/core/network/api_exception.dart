/// 统一业务异常。
///
/// 后端响应采用统一 envelop：
/// ```json
/// { "code": 0, "message": "ok", "data": { } }
/// ```
/// `code == 0` 表示成功；非 0 抛出 [ApiException]。
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  /// 业务错误码（后端 envelop.code），网络层本地错误使用负数。
  final int code;

  /// 用户可读的错误信息。
  final String message;

  /// HTTP 状态码（仅当存在 HTTP 响应时提供）。
  final int? statusCode;

  /// 登录态失效（后端约定：401 或业务码 40100）。
  bool get isUnauthorized => statusCode == 401 || code == 40100;

  /// 服务端错误（5xx 或业务码 >= 50000）。
  bool get isServerError => (statusCode != null && statusCode! >= 500) || code >= 50000;

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

  @override
  String toString() => 'ApiException($code, $message${statusCode == null ? '' : ', http:$statusCode'})';
}
