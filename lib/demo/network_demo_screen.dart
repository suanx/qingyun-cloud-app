import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

import '../core/config/app_config.dart';
import '../core/models/cloud_models.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/network/token_store.dart';

/// 网络层演示：在设备内启动一个本地 HTTP 演示服务（127.0.0.1 随机端口），
/// 通过 [ApiClient] 完整走一遍「请求 → envelop 解析 → 鉴权头 → 错误映射」链路。
///
/// 每个用例都标注了预期结果，点击按钮即执行并展示实际返回。
class NetworkDemoScreen extends StatefulWidget {
  const NetworkDemoScreen({super.key});

  @override
  State<NetworkDemoScreen> createState() => _NetworkDemoScreenState();
}

class _NetworkDemoScreenState extends State<NetworkDemoScreen> {
  final _LocalDemoApi _localApi = _LocalDemoApi();
  final List<_CaseResult> _results = <_CaseResult>[];
  String? _baseUrl;
  bool _starting = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // 演示登录态：写入 token 后，ApiClient 会自动携带 Bearer 头
    TokenStore.save('demo-token-abc123');
    final url = await _localApi.start();
    if (!mounted) return;
    setState(() {
      _baseUrl = url;
      _starting = false;
    });
  }

  @override
  void dispose() {
    _localApi.stop();
    super.dispose();
  }

  ApiClient _client({Duration? timeout}) {
    return ApiClient(
      baseUrl: _baseUrl,
      dioOverride: Dio(BaseOptions(
        baseUrl: _baseUrl ?? '',
        connectTimeout: timeout ?? AppConfig.connectTimeout,
        receiveTimeout: timeout ?? AppConfig.receiveTimeout,
      )),
    );
  }

  Future<void> _runCase(String name, String expected, Future<String> Function() action) async {
    final watch = Stopwatch()..start();
    String detail;
    var ok = true;
    try {
      detail = await action();
    } on ApiException catch (error) {
      ok = false;
      detail = 'ApiException(code=${error.code}, ${error.message})';
    } catch (error) {
      ok = false;
      detail = 'Unexpected: $error';
    }
    watch.stop();
    if (!mounted) return;
    setState(() {
      _results.insert(
        0,
        _CaseResult(
          name: name,
          expected: expected,
          detail: detail,
          ok: ok,
          elapsedMs: watch.elapsedMilliseconds,
        ),
      );
    });
  }

  // ---- 各用例 ----

  Future<String> _caseStorage() async {
    final data = await _client().get('/api/v1/storage/summary') as Map<String, dynamic>;
    final summary = StorageSummary.fromJson(data);
    return '解析成功：${summary.label}（占比 ${(summary.ratio * 100).toStringAsFixed(0)}%）';
  }

  Future<String> _caseWhoAmI() async {
    final data = await _client().get('/api/v1/whoami') as Map<String, dynamic>;
    return '服务端收到鉴权头：${data['authorization']}';
  }

  Future<String> _caseFiles() async {
    final data = await _client().get('/api/v1/files');
    final files = (data as List<dynamic>)
        .map((e) => CloudFile.fromJson(e as Map<String, dynamic>))
        .toList();
    return '解析成功：共 ${files.length} 个文件 — ${files.map((f) => f.name).join('、')}';
  }

  Future<String> _caseBusinessError() async {
    try {
      await _client().get('/api/v1/error');
      throw ApiException.badResponse(500, '未按预期抛出业务异常');
    } on ApiException catch (error) {
      if (error.code == 50001) {
        return '已捕获业务失败：${error.message}（code=${error.code}）';
      }
      rethrow;
    }
  }

  Future<String> _caseUnauthorized() async {
    try {
      await _client().get('/api/v1/secure');
      throw ApiException.badResponse(500, '未按预期抛出 401 异常');
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        return '已识别为登录态失效（isUnauthorized=true，code=${error.code}）';
      }
      rethrow;
    }
  }

  Future<String> _caseTimeout() async {
    // 演示服务 /slow 延迟 3 秒；此处客户端超时 2 秒 → 必然触发超时异常
    try {
      await _client(timeout: const Duration(seconds: 2)).get('/api/v1/slow');
      throw ApiException.badResponse(500, '未按预期触发超时');
    } on ApiException catch (error) {
      if (error.code == -2) {
        return '已触发超时异常：${error.message}';
      }
      rethrow;
    }
  }

  Future<String> _caseNotFound() async {
    try {
      await _client().get('/api/v1/notfound');
      throw ApiException.badResponse(500, '未按预期抛出 404 异常');
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        return '已捕获 404：${error.message}';
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: QyColors.canvas,
      appBar: AppBar(
        title: Text('网络层演示', style: textTheme.titleLarge),
        leading: IconButton(
          icon: const QyIcon(QyIcons.back, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: _starting
          ? const Center(child: CircularProgressIndicator(color: QyColors.primaryDeep))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                QyCard(
                  gradient: QyColors.primaryGradient,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('本地演示服务已启动', style: textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text('Base URL：$_baseUrl', style: textTheme.bodyMedium),
                      Text('Bearer Token：demo-token-abc123', style: textTheme.bodyMedium),
                      const SizedBox(height: 4),
                      Text(
                        '服务内置于 App（dart:io HttpServer），无需任何外部后端，'
                        '点击用例按钮即发起真实 HTTP 请求并展示解析/异常映射结果。',
                        style: textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: QyTokens.spaceLg),

                Text('用例', style: textTheme.titleLarge),
                const SizedBox(height: QyTokens.spaceMd),
                _CaseButton(
                  label: '1. envelop 解析（容量概览）',
                  expected: 'code=0 → data 解析为 StorageSummary',
                  onTap: () => _runCase('envelop 解析', 'code=0 → StorageSummary', _caseStorage),
                ),
                _CaseButton(
                  label: '2. 鉴权头携带（whoami）',
                  expected: '服务端收到 Authorization: Bearer demo-token-abc123',
                  onTap: () => _runCase('鉴权头', '自动携带 Bearer Token', _caseWhoAmI),
                ),
                _CaseButton(
                  label: '3. 列表解析（文件列表）',
                  expected: 'data 数组 → List<CloudFile>',
                  onTap: () => _runCase('列表解析', 'data → List<CloudFile>', _caseFiles),
                ),
                _CaseButton(
                  label: '4. 业务失败（code=50001）',
                  expected: '抛 ApiException，message 透出后端文案',
                  onTap: () => _runCase('业务失败', '抛 ApiException(50001)', _caseBusinessError),
                ),
                _CaseButton(
                  label: '5. 登录态失效（HTTP 401）',
                  expected: 'isUnauthorized == true',
                  onTap: () => _runCase('401 识别', 'isUnauthorized == true', _caseUnauthorized),
                ),
                _CaseButton(
                  label: '6. 超时（2s 超时 vs 3s 接口）',
                  expected: '抛 ApiException.timeout',
                  onTap: () => _runCase('超时', '抛 ApiException.timeout', _caseTimeout),
                ),
                _CaseButton(
                  label: '7. 接口不存在（HTTP 404）',
                  expected: '抛 ApiException.badResponse(404)',
                  onTap: () => _runCase('404', '抛 ApiException(404)', _caseNotFound),
                ),

                const SizedBox(height: QyTokens.spaceLg),
                Text('执行结果（最新在前）', style: textTheme.titleLarge),
                const SizedBox(height: QyTokens.spaceMd),
                if (_results.isEmpty)
                  const QyEmptyState(
                    icon: QyIcons.info,
                    title: '尚未执行用例',
                    description: '点击上方任意用例按钮开始演示',
                  )
                else
                  for (final result in _results)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CaseResultCard(result: result),
                    ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }
}

class _CaseButton extends StatelessWidget {
  const _CaseButton({required this.label, required this.expected, required this.onTap});

  final String label;
  final String expected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: QyCard(
        onTap: onTap,
        child: Row(
          children: <Widget>[
            const QyIcon(QyIcons.play, size: 20, color: QyColors.primaryDeep),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: textTheme.bodyLarge),
                  const SizedBox(height: 2),
                  Text('预期：$expected', style: textTheme.labelMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaseResult {
  const _CaseResult({
    required this.name,
    required this.expected,
    required this.detail,
    required this.ok,
    required this.elapsedMs,
  });

  final String name;
  final String expected;
  final String detail;
  final bool ok;
  final int elapsedMs;
}

class _CaseResultCard extends StatelessWidget {
  const _CaseResultCard({required this.result});

  final _CaseResult result;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return QyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              QyIcon(
                result.ok ? QyIcons.check : QyIcons.warning,
                size: 18,
                color: result.ok ? QyColors.success : QyColors.error,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(result.name, style: textTheme.bodyLarge)),
              Text('${result.elapsedMs} ms', style: textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: 6),
          Text('实际：${result.detail}', style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// 设备内嵌的本地演示服务：实现演示用 REST 端点，返回标准 envelop。
class _LocalDemoApi {
  HttpServer? _server;

  String? get baseUrl => _server == null ? null : 'http://127.0.0.1:${_server!.port}';

  Future<String> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen((request) async {
      try {
        await _handle(request);
      } catch (_) {
        await _json(request, 500, <String, dynamic>{'code': 50000, 'message': 'demo server error'});
      }
    });
    return baseUrl!;
  }

  void stop() {
    _server?.close(force: true);
    _server = null;
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    final auth = request.headers.value('authorization') ?? '（未携带）';

    switch (path) {
      case '/api/v1/storage/summary':
        await _json(request, 200, <String, dynamic>{
          'code': 0,
          'message': 'ok',
          'data': <String, dynamic>{'used_gb': 47.2, 'total_gb': 128},
        });
      case '/api/v1/whoami':
        await _json(request, 200, <String, dynamic>{
          'code': 0,
          'message': 'ok',
          'data': <String, dynamic>{'authorization': auth},
        });
      case '/api/v1/files':
        await _json(request, 200, <String, dynamic>{
          'code': 0,
          'message': 'ok',
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'f1',
              'name': '海边日落.JPG',
              'category': 'image',
              'size_label': '4.2 MB',
              'updated_label': '今天 14:32',
              'starred': true,
            },
            <String, dynamic>{
              'id': 'f2',
              'name': '产品需求文档.docx',
              'category': 'doc',
              'size_label': '860 KB',
              'updated_label': '今天 11:05',
            },
          ],
        });
      case '/api/v1/error':
        // 业务失败：HTTP 200 + envelop code != 0
        await _json(request, 200, <String, dynamic>{
          'code': 50001,
          'message': '演示：服务端业务失败',
        });
      case '/api/v1/secure':
        // 登录态失效：HTTP 401
        await _json(request, 401, <String, dynamic>{
          'code': 40100,
          'message': '登录态已失效（演示）',
        });
      case '/api/v1/slow':
        await Future<void>.delayed(const Duration(seconds: 3));
        await _json(request, 200, <String, dynamic>{'code': 0, 'message': 'ok', 'data': null});
      default:
        await _json(request, 404, <String, dynamic>{'code': 40400, 'message': '接口不存在（演示）'});
    }
  }

  Future<void> _json(HttpRequest request, int status, Map<String, dynamic> body) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    await request.response.close();
  }
}
