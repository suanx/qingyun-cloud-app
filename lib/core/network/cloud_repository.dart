import '../config/app_config.dart';
import '../models/cloud_models.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';

/// 数据仓库：统一「本地示例数据」与「真实后端」两条路径。
///
/// 页面只依赖本仓库；切换真实后端时仅需将 [AppConfig.useMockData] 置为 false，
/// 并按 docs/BACKEND.md 调整接口实现。
class CloudRepository {
  CloudRepository({ApiClient? client}) : _client = client ?? ApiClient.shared;

  final ApiClient _client;

  Future<StorageSummary> storageSummary() async {
    if (AppConfig.useMockData) return MockData.storageSummary;
    final data = await _client.get(ApiEndpoints.storageSummary) as Map<String, dynamic>;
    return StorageSummary.fromJson(data);
  }

  Future<List<CloudFile>> files({FileCategory category = FileCategory.all, String? keyword}) async {
    if (AppConfig.useMockData) return MockData.files(category: category, keyword: keyword);
    final data = await _client.get(ApiEndpoints.files, query: <String, dynamic>{
      if (category != FileCategory.all) 'category': category.name,
      if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
    });
    return _asList(data).map((e) => CloudFile.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<CloudFile>> trashFiles() async {
    if (AppConfig.useMockData) return MockData.trashFiles;
    final data = await _client.get(ApiEndpoints.trash);
    return _asList(data).map((e) => CloudFile.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<TransferTask>> transfers() async {
    if (AppConfig.useMockData) return MockData.transfers;
    final data = await _client.get(ApiEndpoints.transfers);
    return _asList(data).map((e) => TransferTask.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 容错：后端 data 缺失或类型异常时返回空列表，避免页面崩溃。
  static List<dynamic> _asList(Object? data) => data is List<dynamic> ? data : const <dynamic>[];
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
