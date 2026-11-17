import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'api_exception.dart';
import 'token_store.dart';

/// 统一 HTTP 客户端。
///
/// - 自动拼接 [AppConfig.apiBaseUrl]
/// - 自动携带 `Authorization: Bearer <token>`
/// - 统一解析后端 envelop：`{ code, message, data }`，code != 0 抛 [ApiException]
/// - 网络/超时/HTTP 错误统一映射为 [ApiException]
class ApiClient {
  ApiClient({String? baseUrl, Dio? dioOverride})
      : _dio = dioOverride ??
            Dio(BaseOptions(
              baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
              connectTimeout: AppConfig.connectTimeout,
              receiveTimeout: AppConfig.receiveTimeout,
              headers: <String, String>{
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
            )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = TokenStore.accessToken;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  final Dio _dio;

  /// 全局共享实例（示例工程从简；正式迭代可改为依赖注入）。
  static final ApiClient shared = ApiClient();

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final response = await _guard(() => _dio.get<dynamic>(path, queryParameters: query));
    return _unwrap(response);
  }

  Future<dynamic> post(String path, {Object? body}) async {
    final response = await _guard(() => _dio.post<dynamic>(path, data: body));
    return _unwrap(response);
  }

  Future<dynamic> put(String path, {Object? body}) async {
    final response = await _guard(() => _dio.put<dynamic>(path, data: body));
    return _unwrap(response);
  }

  Future<dynamic> delete(String path, {Object? body}) async {
    final response = await _guard(() => _dio.delete<dynamic>(path, data: body));
    return _unwrap(response);
  }

  /// 直接暴露原始请求能力（文件上传等场景）。
  Future<Response<T>> raw<T>(Future<Response<T>> Function(Dio dio) send) =>
      _guard(() => send(_dio));

  Future<Response<T>> _guard<T>(Future<Response<T>> Function() send) async {
    try {
      return await send();
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  dynamic _unwrap(Response<dynamic> response) {
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      return data;
    }
    final code = data['code'];
    final message = data['message'];
    if (code is num && code != 0) {
      throw ApiException(
        code: code.toInt(),
        message: message is String && message.isNotEmpty ? message : '请求失败（code=$code）',
        statusCode: response.statusCode,
      );
    }
    return data['data'];
  }

  ApiException _toApiException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return ApiException.timeout();
      case DioExceptionType.cancel:
        return ApiException.cancelled();
      case DioExceptionType.connectionError:
        return ApiException.network();
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode ?? 0;
        final message = _extractMessage(error.response?.data) ?? _httpMessage(statusCode);
        return ApiException.badResponse(statusCode, message);
      case DioExceptionType.badCertificate:
        return const ApiException(code: -4, message: '证书校验失败，连接已中止');
      case DioExceptionType.unknown:
        return ApiException.network();
    }
  }

  String? _extractMessage(Object? data) {
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    return null;
  }

  String _httpMessage(int statusCode) {
    switch (statusCode) {
      case 400:
        return '请求参数有误';
      case 401:
        return '登录态已失效，请重新登录';
      case 403:
        return '没有权限执行该操作';
      case 404:
        return '接口不存在';
      case 429:
        return '请求过于频繁，请稍后再试';
      default:
        return statusCode >= 500 ? '服务暂不可用，请稍后重试' : '请求失败（HTTP $statusCode）';
    }
  }
}
