import 'package:flutter/material.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

/// 文件分类，与设计稿「文件分类与列表」场景的分组一致。
enum FileCategory { all, image, doc, video, music, zip, other }

extension FileCategoryX on FileCategory {
  String get label => switch (this) {
        FileCategory.all => '全部',
        FileCategory.image => '图片',
        FileCategory.doc => '文档',
        FileCategory.video => '视频',
        FileCategory.music => '音乐',
        FileCategory.zip => '压缩包',
        FileCategory.other => '其他',
      };

  String get iconName => switch (this) {
        FileCategory.image => QyIcons.image,
        FileCategory.doc => QyIcons.doc,
        FileCategory.video => QyIcons.video,
        FileCategory.music => QyIcons.music,
        FileCategory.zip => QyIcons.zip,
        FileCategory.all || FileCategory.other => QyIcons.folder,
      };

  Color get tint => switch (this) {
        FileCategory.image => QyColors.sky,
        FileCategory.doc => QyColors.gold,
        FileCategory.video => QyColors.violet,
        FileCategory.music => QyColors.mint,
        FileCategory.zip => QyColors.coral,
        FileCategory.all || FileCategory.other => QyColors.sub,
      };

  /// 由文件扩展名推断分类（lanflare 节点无分类字段，按名称映射）。
  static FileCategory fromFileName(String name) {
    final ext =
        name.contains('.') ? name.split('.').last.toLowerCase() : '';
    const image = <String>['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'svg'];
    const video = <String>['mp4', 'm4v', 'webm', 'mov', 'avi', 'mkv', 'flv'];
    const music = <String>['mp3', 'wav', 'ogg', 'flac', 'm4a', 'aac'];
    const doc = <String>['doc', 'docx', 'pdf', 'ppt', 'pptx', 'xls', 'xlsx', 'txt', 'md', 'csv'];
    const zip = <String>['zip', 'rar', '7z', 'tar', 'gz'];
    if (image.contains(ext)) return FileCategory.image;
    if (video.contains(ext)) return FileCategory.video;
    if (music.contains(ext)) return FileCategory.music;
    if (doc.contains(ext)) return FileCategory.doc;
    if (zip.contains(ext)) return FileCategory.zip;
    return FileCategory.other;
  }
}

/// 云端文件条目。
class CloudFile {
  const CloudFile({
    required this.id,
    required this.name,
    required this.category,
    required this.sizeLabel,
    required this.updatedLabel,
    this.starred = false,
    this.sizeBytes = 0,
    this.createdAt = 0,
    this.isDir = false,
    this.pid = 0,
  });

  final String id;
  final String name;
  final FileCategory category;
  final String sizeLabel;
  final String updatedLabel;
  final bool starred;

  /// 后端原始字节数与创建时间（毫秒），用于预览/下载与排序。
  final int sizeBytes;
  final int createdAt;

  /// true = 目录节点（lanflare type='dir'），前端可做目录钻取。
  final bool isDir;
  final int pid;

  static CloudFile fromJson(Map<String, dynamic> json) => CloudFile(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '（未命名文件）',
        category: FileCategory.values.firstWhere(
          (c) => c.name == (json['category']?.toString()),
          orElse: () => FileCategory.other,
        ),
        sizeLabel: json['size_label']?.toString() ?? '',
        updatedLabel: json['updated_label']?.toString() ?? '',
        starred: json['starred'] as bool? ?? false,
      );
}

/// 容量分类统计（后端 `GET /api/storage/summary` 的 by_category 字段，单位字节）。
class StorageCategoryStats {
  const StorageCategoryStats({
    this.image = 0,
    this.video = 0,
    this.music = 0,
    this.doc = 0,
    this.archive = 0,
  });

  final int image;
  final int video;
  final int music;
  final int doc;
  final int archive;

  factory StorageCategoryStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const StorageCategoryStats();
    int val(String key) => (json[key] as num? ?? 0).toInt();
    return StorageCategoryStats(
      image: val('image'),
      video: val('video'),
      music: val('music'),
      doc: val('doc'),
      archive: val('archive'),
    );
  }
}

/// 容量概览（首页 / 容量管理共用）。
class StorageSummary {
  const StorageSummary({
    required this.usedGb,
    required this.totalGb,
    this.byCategory = const StorageCategoryStats(),
  });

  final double usedGb;
  final double totalGb;
  final StorageCategoryStats byCategory;

  double get ratio => totalGb <= 0 ? 0 : (usedGb / totalGb).clamp(0.0, 1.0);

  String get label => '${usedGb.toStringAsFixed(1)} / ${totalGb.toStringAsFixed(0)} GB';

  static StorageSummary fromJson(Map<String, dynamic> json) {
    final used = (json['used_gb'] as num? ?? 0).toDouble();
    var total = (json['total_gb'] as num? ?? 1).toDouble();
    // 容错：非法 total（0/负数）按 1 处理，避免除零与展示异常
    if (total <= 0) total = 1;
    return StorageSummary(
      usedGb: used < 0 ? 0 : used,
      totalGb: total,
      byCategory: StorageCategoryStats.fromJson(
        json['by_category'] as Map<String, dynamic>?,
      ),
    );
  }
}

/// 在线预览信息（后端 `GET /api/preview/url`）。
///
/// [url] 为短期签名地址，图片/视频组件可直接加载（无需 Authorization 头）；
/// 过期后需重新调用仓库的 previewInfo() 换取新链接。
class PreviewInfo {
  const PreviewInfo({
    required this.url,
    required this.name,
    required this.sizeBytes,
    required this.contentType,
    required this.expiresAt,
  });

  final String url;
  final String name;
  final int sizeBytes;
  final String contentType;
  final int expiresAt;

  bool get isImage => contentType.startsWith('image/');
  bool get isVideo => contentType.startsWith('video/');
  bool get isAudio => contentType.startsWith('audio/');
  bool get isText =>
      contentType.startsWith('text/') || contentType == 'application/json';
  bool get isPdf => contentType == 'application/pdf';

  factory PreviewInfo.fromJson(Map<String, dynamic> json) => PreviewInfo(
        url: json['url']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        sizeBytes: (json['size_bytes'] as num? ?? 0).toInt(),
        contentType: json['content_type']?.toString() ?? 'application/octet-stream',
        expiresAt: (json['expires_at'] as num? ?? 0).toInt(),
      );
}

/// 我的分享条目（后端 `GET /api/my-shares`）。
class ShareItem {
  const ShareItem({
    required this.id,
    required this.name,
    required this.kind,
    required this.createdAt,
    required this.downloads,
    required this.maxDownloads,
    this.expiresAt = 0,
    this.hasPassword = false,
  });

  final String id;
  final String name;
  final String kind;
  final int createdAt;
  final int downloads;
  final int maxDownloads;
  final int expiresAt;
  final bool hasPassword;
}

/// 传输任务（传输任务场景）。
enum TransferDirection { upload, download }

enum TransferStatus { running, paused, done, failed }

class TransferTask {
  const TransferTask({
    required this.id,
    required this.name,
    required this.direction,
    required this.status,
    required this.progress,
    required this.sizeLabel,
  });

  final String id;
  final String name;
  final TransferDirection direction;
  final TransferStatus status;
  final double progress;
  final String sizeLabel;

  TransferTask copyWith({TransferStatus? status, double? progress}) => TransferTask(
        id: id,
        name: name,
        direction: direction,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        sizeLabel: sizeLabel,
      );

  static TransferTask fromJson(Map<String, dynamic> json) => TransferTask(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '（未命名任务）',
        direction: (json['direction']?.toString() ?? 'upload') == 'download'
            ? TransferDirection.download
            : TransferDirection.upload,
        status: TransferStatus.values.firstWhere(
          (s) => s.name == (json['status']?.toString()),
          orElse: () => TransferStatus.running,
        ),
        progress: ((json['progress'] as num? ?? 0).toDouble()).clamp(0.0, 1.0),
        sizeLabel: json['size_label']?.toString() ?? '',
      );
}
