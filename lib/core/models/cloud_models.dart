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
        FileCategory.image => QyColors.coral,
        FileCategory.doc => QyColors.sky,
        FileCategory.video => QyColors.mint,
        FileCategory.music => QyColors.primaryDeep,
        FileCategory.zip => const Color(0xFF6B5A2A),
        FileCategory.all || FileCategory.other => QyColors.sub,
      };
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
  });

  final String id;
  final String name;
  final FileCategory category;
  final String sizeLabel;
  final String updatedLabel;
  final bool starred;

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

/// 容量概览（首页 / 容量管理共用）。
class StorageSummary {
  const StorageSummary({
    required this.usedGb,
    required this.totalGb,
  });

  final double usedGb;
  final double totalGb;

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
    );
  }
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
