import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'api_exception.dart';
import 'token_store.dart';

/// 统一 HTTP 客户端（对接 lanflare，同时保留原 envelop 解析能力）。
///
/// - 自动拼接 [AppConfig.apiBaseUrl]
/// - 按凭证类型自动附加鉴权头：
///   - `lf_...` → `Authorization: Bearer <token>`
///   - `basic:<b64>` → `Authorization: Basic <b64>`
///   - 其他 → `Cookie: lf_session=<value>`（旧式会话兜底）
/// - `getRaw/postRaw/...`：lanflare 原生 JSON（成功直接返回 body，
///   失败 `{ "error": ... }` 映射为 [ApiException]）
/// - `get/post/...`：保留原 envelop `{code,message,data}` 解析（演示页使用）
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
        final credential = TokenStore.credential;
        if (credential != null && credential.isNotEmpty) {
          if (credential.startsWith('lf_')) {
            options.headers['Authorization'] = 'Bearer $credential';
          } else if (credential.startsWith('basic:')) {
            options.headers['Authorization'] = 'Basic ${credential.substring(6)}';
          } else {
            options.headers['Cookie'] = 'lf_session=$credential';
          }
        }
        handler.next(options);
      },
    ));
  }

  final Dio _dio;

  /// 全局共享实例（示例工程从简；正式迭代可改为依赖注入）。
  static final ApiClient shared = ApiClient();

  /// 登录态失效回调（HTTP 401 时触发一次）。
  /// 由路由层设置：清除凭证并跳转登录页。
  static void Function()? onUnauthorized;

  static void _notifyUnauthorized() {
    final callback = onUnauthorized;
    if (callback != null) {
      Future<void>.microtask(callback);
    }
  }

  // ---------------------------------------------------------------------------
  // lanflare 原生 JSON（无 envelop）
  // ---------------------------------------------------------------------------

  Future<dynamic> getRaw(String path, {Map<String, dynamic>? query}) async {
    final response =
        await _guard(() => _dio.get<dynamic>(path, queryParameters: query));
    return _unwrapPlain(response);
  }

  Future<dynamic> postRaw(String path, {Object? body}) async {
    final response = await _guard(() => _dio.post<dynamic>(path, data: body));
    return _unwrapPlain(response);
  }

  Future<dynamic> deleteRaw(String path, {Object? body}) async {
    final response =
        await _guard(() => _dio.delete<dynamic>(path, data: body));
    return _unwrapPlain(response);
  }

  /// 不跟随重定向的 GET（用于 lanflare /api/download 的 302 直链）。
  Future<Response<dynamic>> getNoRedirect(String path,
      {Map<String, dynamic>? query}) async {
    return _guard(() => _dio.get<dynamic>(
          path,
          queryParameters: query,
          options: Options(
            followRedirects: false,
            validateStatus: (int? status) => status != null && status < 400,
          ),
        ));
  }

  /// 流式下载（支持服务端 Range / 分块重组）。
  Future<Response<dynamic>> downloadStream(String path,
      {Map<String, dynamic>? query, ProgressCallback? onReceiveProgress}) async {
    return _guard(() => _dio.get<ResponseBody>(
          path,
          queryParameters: query,
          options: Options(responseType: ResponseType.stream),
          onReceiveProgress: onReceiveProgress,
        ));
  }

  /// 上传原始字节流（lanflare /api/upload：raw body + `X-Heri-Name` 头）。
  Future<dynamic> uploadStream(
    String path, {
    required Stream<Uint8List> body,
    required int length,
    Map<String, String> headers = const <String, String>{},
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final response = await _guard(() => _dio.post<dynamic>(
          path,
          data: body,
          options: Options(
            headers: <String, Object?>{
              ...headers,
              Headers.contentLengthHeader: length,
            },
            contentType: 'application/octet-stream',
          ),
          onSendProgress: onSendProgress,
        ));
    return _unwrapPlain(response);
  }

  // ---------------------------------------------------------------------------
  // 原 envelop 约定（`{code, message, data}`，功能演示页仍在使用）
  // ---------------------------------------------------------------------------

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

  /// 直接暴露原始请求能力（特殊场景）。
  Future<Response<T>> raw<T>(Future<Response<T>> Function(Dio dio) send) =>
      _guard(() => send(_dio));

  // ---------------------------------------------------------------------------
  // 内部工具
  // ---------------------------------------------------------------------------

  Future<Response<T>> _guard<T>(Future<Response<T>> Function() send) async {
    try {
      return await send();
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  /// lanflare 响应解包：2xx 直接返回 body；`{error}` 视为业务失败。
  dynamic _unwrapPlain(Response<dynamic> response) {
    final statusCode = response.statusCode ?? 0;
    final data = response.data;
    if (statusCode >= 400) {
      throw ApiException.badResponse(statusCode, _plainError(data, statusCode));
    }
    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is String && error.isNotEmpty) {
        throw ApiException.badResponse(statusCode, error);
      }
    }
    return data;
  }

  String _plainError(Object? data, int statusCode) {
    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is String && error.isNotEmpty) return error;
    }
    return _httpMessage(statusCode);
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
        if (statusCode == 401) {
          _notifyUnauthorized();
        }
        final message =
            _extractMessage(error.response?.data) ?? _httpMessage(statusCode);
        return ApiException.badResponse(statusCode, message);
      case DioExceptionType.badCertificate:
        return const ApiException(code: -4, message: '证书校验失败，连接已中止');
      case DioExceptionType.unknown:
        return ApiException.network();
    }
  }

  String? _extractMessage(Object? data) {
    if (data is Map<String, dynamic>) {
      final message = data['message'] ?? data['error'];
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
      case 413:
        return '文件超出大小限制';
      case 429:
        return '请求过于频繁，请稍后再试';
      case 503:
        return '存储账号未绑定，请先在网页端绑定蓝奏云账号';
      default:
        return statusCode >= 500 ? '服务暂不可用，请稍后重试' : '请求失败（HTTP $statusCode）';
    }
  }
}
