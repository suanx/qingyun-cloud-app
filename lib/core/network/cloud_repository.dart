import 'dart:typed_data';

import '../config/app_config.dart';
import '../models/cloud_models.dart';
import '../models/transfer_store.dart';
import 'api_client.dart';
import 'token_store.dart';

/// 数据仓库：统一「本地示例数据」与「lanflare 后端」两条路径。
///
/// 页面只依赖本仓库。lanflare 接口约定（Bearer/Basic 鉴权、原生 JSON）见
/// https://github.com/suanx/lanflare 的 /docs；mock 行为与旧版一致。
class CloudRepository {
  CloudRepository({ApiClient? client}) : _client = client ?? ApiClient.shared;

  final ApiClient _client;

  // ---------------------------------------------------------------------------
  // 登录 / 登出
  // ---------------------------------------------------------------------------

  /// 账号密码登录 lanflare（`POST /api/auth/login`）。
  ///
  /// 成功后保存 Basic 凭证（lanflare 的 /api/* 同样接受 HTTP Basic，
  /// 与网页会话等价、权限为 rw）。开启 TOTP 时传 [totpCode]。
  /// 返回登录用户名；失败抛 [ApiException]（401 = 账号/密码/验证码错误）。
  Future<String> login(String account, String password, {String? totpCode}) async {
    final response = await _client.raw((dio) => dio.post<dynamic>(
          '/api/auth/login',
          data: <String, dynamic>{
            'u': account,
            'p': password,
            if (totpCode != null && totpCode.isNotEmpty) 'code': totpCode,
          },
        ));
    await TokenStore.save(TokenStore.basicCredential(account, password));
    final data = response.data;
    return data is Map<String, dynamic>
        ? (data['username']?.toString() ?? account)
        : account;
  }

  /// 退出登录：清除本地凭证。
  Future<void> logout() => TokenStore.clear();

  // ---------------------------------------------------------------------------
  // 容量概览
  // ---------------------------------------------------------------------------

  /// 容量概览：lanflare `GET /api/storage/summary`。
  /// 后端未配置总容量时使用 [AppConfig.fallbackTotalGb] 兜底。
  Future<StorageSummary> storageSummary() async {
    if (AppConfig.useMockData) return MockData.storageSummary;
    final data =
        await _client.getRaw('/api/storage/summary') as Map<String, dynamic>;
    final usedBytes = (data['used_bytes'] as num? ?? 0).toDouble();
    var totalBytes = (data['total_bytes'] as num? ?? 0).toDouble();
    if (totalBytes <= 0) {
      totalBytes = AppConfig.fallbackTotalGb * _bytesPerGb;
    }
    return StorageSummary(
      usedGb: usedBytes / _bytesPerGb,
      totalGb: totalBytes / _bytesPerGb,
    );
  }

  // ---------------------------------------------------------------------------
  // 文件列表 / 搜索
  // ---------------------------------------------------------------------------

  /// 文件列表：lanflare `GET /api/list?pid=0`；有关键字时走
  /// `GET /api/search?q=`（全局搜索）。目录节点暂不进入列表页。
  Future<List<CloudFile>> files({
    FileCategory category = FileCategory.all,
    String? keyword,
  }) async {
    if (AppConfig.useMockData) {
      return MockData.files(category: category, keyword: keyword);
    }
    final query = keyword?.trim() ?? '';
    final Map<String, dynamic> data;
    if (query.isEmpty) {
      data = await _client.getRaw('/api/list', query: <String, dynamic>{'pid': 0})
          as Map<String, dynamic>;
    } else {
      data = await _client.getRaw('/api/search', query: <String, dynamic>{'q': query})
          as Map<String, dynamic>;
    }
    final items = _itemsOf(data);
    return items
        .where((node) => node['type'] == 'file')
        .map(_fileFromNode)
        .where((file) => category == FileCategory.all || file.category == category)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // 回收站
  // ---------------------------------------------------------------------------

  Future<List<CloudFile>> trashFiles() async {
    if (AppConfig.useMockData) return MockData.trashFiles;
    final data = await _client.getRaw('/api/bin') as Map<String, dynamic>;
    return _itemsOf(data)
        .where((node) => node['type'] == 'file')
        .map(_fileFromNode)
        .toList();
  }

  Future<void> restoreFiles(List<String> ids) async {
    await _client.postRaw('/api/restore', body: <String, dynamic>{'ids': _toIntIds(ids)});
  }

  Future<void> hardDeleteFiles(List<String> ids) async {
    await _client.postRaw('/api/hard-delete', body: <String, dynamic>{'ids': _toIntIds(ids)});
  }

  Future<void> deleteFiles(List<String> ids) async {
    await _client.postRaw('/api/delete', body: <String, dynamic>{'ids': _toIntIds(ids)});
  }

  /// 清空回收站（lanflare `POST /api/empty-bin`）。
  Future<void> emptyTrash() async {
    await _client.postRaw('/api/empty-bin');
  }

  // ---------------------------------------------------------------------------
  // 分享
  // ---------------------------------------------------------------------------

  /// 我的分享数量（lanflare `GET /api/my-shares`）。
  Future<int> shareCount() async {
    if (AppConfig.useMockData) return 6;
    final data = await _client.getRaw('/api/my-shares') as Map<String, dynamic>;
    return _itemsOf(data).length;
  }

  /// 回收站中的文件数量（lanflare `GET /api/bin`）。
  Future<int> trashCount() async {
    if (AppConfig.useMockData) return MockData.trashFiles.length;
    final data = await _client.getRaw('/api/bin') as Map<String, dynamic>;
    return _itemsOf(data).where((node) => node['type'] == 'file').length;
  }

  /// 生成分享链接（lanflare `POST /api/share`），返回公开下载网址。
  Future<String> shareFile(String fileId, {String? password, int expireDays = 0}) async {
    final data = await _client.postRaw('/api/share', body: <String, dynamic>{
      'id': int.parse(fileId),
      'expiresInDays': expireDays,
      if (password != null && password.isNotEmpty) 'password': password,
    }) as Map<String, dynamic>;
    return data['url']?.toString() ?? data['code']?.toString() ?? '';
  }

  // ---------------------------------------------------------------------------
  // 下载 / 上传
  // ---------------------------------------------------------------------------

  /// 下载地址：VIP 走 302 直连蓝奏云 CDN；非 VIP 返回 Worker 代理流地址。
  Future<String> downloadUrl(String fileId) async {
    final response = await _client
        .getNoRedirect('/api/download', query: <String, dynamic>{'id': int.parse(fileId)});
    final location = response.headers.value('location');
    if (response.statusCode == 302 && location != null && location.isNotEmpty) {
      return location.startsWith('http') ? location : AppConfig.apiBaseUrl + location;
    }
    // 兜底：流式代理端点（支持 Range）
    return '${AppConfig.apiBaseUrl}/api/stream?id=$fileId';
  }

  /// 上传文件（lanflare `POST /api/upload?pid=`，raw body + `X-Heri-Name` 头）。
  /// 单请求上限 90MB；进度经 [onProgress] 回调并写入本地任务模型。
  Future<CloudFile> upload({
    required String name,
    required Stream<Uint8List> bytes,
    required int length,
    int pid = 0,
    void Function(int sent, int total)? onProgress,
  }) async {
    final taskId = LocalTransferStore.instance.start(
      name: name,
      direction: TransferDirection.upload,
      sizeLabel: humanSize(length),
    );
    try {
      final data = await _client.uploadStream(
        '/api/upload?pid=$pid',
        body: bytes,
        length: length,
        headers: <String, String>{'X-Heri-Name': Uri.encodeComponent(name)},
        onSendProgress: (sent, total) {
          final ratio = total <= 0 ? 0.0 : sent / total;
          LocalTransferStore.instance.updateProgress(taskId, ratio);
          onProgress?.call(sent, total);
        },
      ) as Map<String, dynamic>;
      LocalTransferStore.instance.complete(taskId);
      final node = data['node'];
      if (node is Map<String, dynamic>) return _fileFromNode(node);
      return CloudFile(
        id: '',
        name: name,
        category: FileCategoryX.fromFileName(name),
        sizeLabel: humanSize(length),
        updatedLabel: '刚刚',
      );
    } on ApiException {
      LocalTransferStore.instance.fail(taskId);
      rethrow;
    } catch (_) {
      LocalTransferStore.instance.fail(taskId);
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // 传输任务（本地模型）
  // ---------------------------------------------------------------------------

  /// lanflare 无服务端任务列表；返回 App 本地记录的任务。
  Future<List<TransferTask>> transfers() async {
    if (AppConfig.useMockData) return MockData.transfers;
    return LocalTransferStore.instance.tasks;
  }

  // ---------------------------------------------------------------------------
  // 映射与工具
  // ---------------------------------------------------------------------------

  CloudFile _fileFromNode(Map<String, dynamic> node) {
    final name = node['name']?.toString() ?? '（未命名文件）';
    return CloudFile(
      id: node['id']?.toString() ?? '',
      name: name,
      category: FileCategoryX.fromFileName(name),
      sizeLabel: humanSize((node['size_bytes'] as num?)?.toInt() ?? 0),
      updatedLabel: relativeTime((node['created_at'] as num?)?.toInt() ?? 0),
      starred: false,
    );
  }

  static List<Map<String, dynamic>> _itemsOf(Map<String, dynamic> data) {
    final items = data['items'];
    if (items is! List<dynamic>) return const <Map<String, dynamic>>[];
    return items.whereType<Map<String, dynamic>>().toList();
  }

  static List<int> _toIntIds(List<String> ids) =>
      ids.map((id) => int.tryParse(id) ?? 0).where((id) => id > 0).toList();

  static const double _bytesPerGb = 1024 * 1024 * 1024;

  /// 字节数 → 展示文案（860 KB / 1.2 GB）。
  static String humanSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final label = value >= 100 || unit == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$label ${units[unit]}';
  }

  /// 毫秒时间戳 → 展示文案（今天 14:32 / 昨天 09:20 / 11-14）。
  static String relativeTime(int millis) {
    if (millis <= 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(date.year, date.month, date.day);
    final diff = today.difference(that).inDays;
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    if (diff <= 0) return '今天 $hh:$mm';
    if (diff == 1) return '昨天 $hh:$mm';
    final mo = date.month.toString().padLeft(2, '0');
    final dy = date.day.toString().padLeft(2, '0');
    return '$mo-$dy';
  }
}

/// 内置示例数据：与设计稿场景一致，用于无后端时展示完整 UI。
abstract final class MockData {
  /// 与首页概览卡一致：8.2 GB 已用 / 10 GB 总量，进度条约 82%。
  static const StorageSummary storageSummary = StorageSummary(usedGb: 8.2, totalGb: 10);

  /// 设计稿「最近照片」数量；接入真实相册后改由数据仓库提供。
  static const int recentPhotoCount = 12;

  static const List<CloudFile> _allFiles = <CloudFile>[
    CloudFile(id: 'f1', name: '海边日落.JPG', category: FileCategory.image, sizeLabel: '860 KB', updatedLabel: '今天 14:32', starred: true),
    CloudFile(id: 'f3', name: '团队 Trip 精华剪辑.MP4', category: FileCategory.video, sizeLabel: '326 MB', updatedLabel: '昨天 21:47', starred: true),
    CloudFile(id: 'f2', name: '产品需求文档.docx', category: FileCategory.doc, sizeLabel: '1.4 MB', updatedLabel: '昨天 10:05'),
    CloudFile(id: 'f4', name: '轻云主题曲 Demo.mp3', category: FileCategory.music, sizeLabel: '7.8 MB', updatedLabel: '昨天 09:20'),
    CloudFile(id: 'f5', name: '设计资源打包.zip', category: FileCategory.zip, sizeLabel: '1.2 GB', updatedLabel: '11-14'),
    CloudFile(id: 'f6', name: '桌面整理.png', category: FileCategory.image, sizeLabel: '2.1 MB', updatedLabel: '11-13'),
    CloudFile(id: 'f7', name: '会议纪要 1112.pdf', category: FileCategory.doc, sizeLabel: '410 KB', updatedLabel: '11-12'),
  ];

  static List<CloudFile> files({FileCategory category = FileCategory.all, String? keyword}) {
    final query = keyword?.trim() ?? '';
    return _allFiles.where((file) {
      final matchCategory = category == FileCategory.all || file.category == category;
      final matchKeyword = query.isEmpty || file.name.toLowerCase().contains(query.toLowerCase());
      return matchCategory && matchKeyword;
    }).toList();
  }

  static const List<CloudFile> trashFiles = <CloudFile>[
    CloudFile(id: 't1', name: '旧版安装包.apk', category: FileCategory.zip, sizeLabel: '96 MB', updatedLabel: '11-01 删除'),
    CloudFile(id: 't2', name: '草稿截图.png', category: FileCategory.image, sizeLabel: '540 KB', updatedLabel: '10-28 删除'),
    CloudFile(id: 't3', name: '过期活动方案.docx', category: FileCategory.doc, sizeLabel: '220 KB', updatedLabel: '10-21 删除'),
  ];

  static const List<TransferTask> transfers = <TransferTask>[
    TransferTask(id: 'tr1', name: '团队 Trip 精华剪辑.MP4', direction: TransferDirection.upload, status: TransferStatus.running, progress: 0.62, sizeLabel: '326 MB'),
    TransferTask(id: 'tr2', name: '设计资源打包.zip', direction: TransferDirection.download, status: TransferStatus.paused, progress: 0.35, sizeLabel: '1.2 GB'),
    TransferTask(id: 'tr3', name: '产品需求文档.docx', direction: TransferDirection.upload, status: TransferStatus.done, progress: 1, sizeLabel: '860 KB'),
    TransferTask(id: 'tr4', name: '轻云主题曲 Demo.mp3', direction: TransferDirection.download, status: TransferStatus.failed, progress: 0.8, sizeLabel: '7.8 MB'),
  ];
}
