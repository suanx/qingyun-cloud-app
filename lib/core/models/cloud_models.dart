import 'package:flutter/material.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';
import '../network/api_exception.dart';
import '../utils/json_utils.dart';

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
    int val(String key) => JsonUtils.asInt(json[key]);
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
    final used = JsonUtils.asDouble(json['used_gb']);
    var total = JsonUtils.asDouble(json['total_gb'], 1);
    // 容错：非法 total（0/负数）按 1 处理，避免除零与展示异常
    if (total <= 0) total = 1;
    return StorageSummary(
      usedGb: used < 0 ? 0 : used,
      totalGb: total,
      byCategory: StorageCategoryStats.fromJson(
        json['by_category'] is Map
            ? Map<String, dynamic>.from(json['by_category'] as Map)
            : null,
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
        sizeBytes: JsonUtils.asInt(json['size_bytes']),
        contentType: json['content_type']?.toString() ?? 'application/octet-stream',
        expiresAt: JsonUtils.asInt(json['expires_at']),
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
        progress: JsonUtils.asDouble(json['progress']).clamp(0.0, 1.0),
        sizeLabel: json['size_label']?.toString() ?? '',
      );

  /// 与 [fromJson] 对称，用于 `LocalTransferStore` 持久化已结束的传输记录。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'direction': direction.name,
        'status': status.name,
        'progress': progress,
        'size_label': sizeLabel,
      };
}

/// 存储清理建议分组（`GET /api/storage/analyze` 的 groups[]）。
class CleanGroup {
  const CleanGroup({
    required this.key,
    required this.label,
    required this.count,
    required this.sizeBytes,
    required this.itemIds,
  });

  final String key;
  final String label;
  final int count;
  final int sizeBytes;

  /// 该组可清理的节点 id；一键清理时提交给 `/api/storage/clean`。
  final List<int> itemIds;

  static CleanGroup fromJson(Map<String, dynamic> json) {
    final rawIds = json['item_ids'];
    final ids = <int>[];
    if (rawIds is List) {
      for (final value in rawIds) {
        final id = JsonUtils.asInt(value);
        if (id > 0) ids.add(id);
      }
    }
    return CleanGroup(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      count: JsonUtils.asInt(json['count']),
      sizeBytes: JsonUtils.asInt(json['size_bytes']),
      itemIds: ids,
    );
  }
}

/// 存储清理建议汇总。
class StorageAnalysis {
  const StorageAnalysis({
    required this.groups,
    required this.totalCount,
    required this.totalReclaimableBytes,
    required this.largeThresholdBytes,
  });

  final List<CleanGroup> groups;
  final int totalCount;
  final int totalReclaimableBytes;
  final int largeThresholdBytes;

  bool get isEmpty => totalCount <= 0;

  /// 按 key 查找分组；不存在时返回 null（页面据此显示占位）。
  CleanGroup? group(String key) {
    for (final group in groups) {
      if (group.key == key) return group;
    }
    return null;
  }

  /// 三组去重后的全部可清理 id。
  List<int> get allItemIds {
    final seen = <int>{};
    final result = <int>[];
    for (final group in groups) {
      for (final id in group.itemIds) {
        if (seen.add(id)) result.add(id);
      }
    }
    return result;
  }

  static StorageAnalysis fromJson(Map<String, dynamic> json) {
    final rawGroups = json['groups'];
    final groups = <CleanGroup>[];
    if (rawGroups is List) {
      for (final value in rawGroups) {
        if (value is Map) {
          groups.add(CleanGroup.fromJson(Map<String, dynamic>.from(value)));
        }
      }
    }
    return StorageAnalysis(
      groups: groups,
      totalCount: JsonUtils.asInt(json['total_count']),
      totalReclaimableBytes: JsonUtils.asInt(json['total_reclaimable_bytes']),
      largeThresholdBytes: JsonUtils.asInt(json['large_threshold_bytes']),
    );
  }
}

/// 清理执行结果（`POST /api/storage/clean`）。
class StorageCleanResult {
  const StorageCleanResult({required this.count, required this.freedBytes});

  final int count;
  final int freedBytes;

  static StorageCleanResult fromJson(Map<String, dynamic> json) =>
      StorageCleanResult(
        count: JsonUtils.asInt(json['count']),
        freedBytes: JsonUtils.asInt(json['freed_bytes']),
      );
}

/// 毫秒 epoch → `yyyy-MM-dd`（本地时区）；`0` 返回空串。
String formatEpochDate(int milliseconds) {
  if (milliseconds <= 0) return '';
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  final y = date.year.toString();
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// 会员状态值对象：`AccountStatus` 与 `AdminUser` 共用同一套三态逻辑。
class VipInfo {
  const VipInfo({required this.vipUntil, this.isAdmin = false});

  /// 到期时间（毫秒 epoch）；0 = 从未开通。
  final int vipUntil;
  final bool isAdmin;

  bool get everVip => vipUntil > 0;

  bool get isVip => vipUntil > DateTime.now().millisecondsSinceEpoch;

  bool get isVipExpired => everVip && !isVip;

  /// 剩余天数（向上取整）；未开通 / 已过期返回 0。
  int get remainingDays {
    if (!isVip) return 0;
    final delta = vipUntil - DateTime.now().millisecondsSinceEpoch;
    return (delta / Duration.millisecondsPerDay).ceil();
  }

  String get expiryLabel => formatEpochDate(vipUntil);

  String get tagLabel => isVip ? 'VIP' : (isVipExpired ? '已过期' : '未开通');

  String get title {
    if (isVip) return '轻云会员 · 剩余 $remainingDays 天';
    if (isVipExpired) return '轻云会员 · 已过期';
    return '轻云会员';
  }

  String get subtitle {
    if (isVip) return '有效期至 $expiryLabel · 不限速传输';
    if (isVipExpired) return '$expiryLabel 到期 · 续期后恢复不限速';
    return isAdmin
        ? '管理员账号 · 可在 App 内设置会员天数'
        : '未开通会员 · 请联系管理员设置';
  }

  /// 列表用的紧凑状态描述。
  String get statusLabel {
    if (isVip) return '有效至 $expiryLabel（剩余 $remainingDays 天）';
    if (isVipExpired) return '$expiryLabel 已过期';
    return '未开通';
  }
}

/// 当前账户状态（lanflare `GET /api/status`）。
///
/// [vipUntil] 为毫秒时间戳，`0` 表示从未开通；小于当前时间表示已过期。
class AccountStatus {
  const AccountStatus({
    required this.username,
    required this.role,
    required this.vipUntil,
    required this.storageConnected,
    required this.fileCount,
    required this.shareCount,
    required this.trashCount,
    required this.tokenCount,
    this.storagePool = const <String, dynamic>{},
  });

  final String username;
  final String role;

  /// 会员到期时间（毫秒 epoch）；0 = 未开通。
  final int vipUntil;
  final bool storageConnected;
  final int fileCount;
  final int shareCount;
  final int trashCount;
  final int tokenCount;

  /// `GET /api/status` 的全局账号池概览（管理员配置，与用户无关）。
  final Map<String, dynamic> storagePool;

  bool get isAdmin => role == 'admin';

  int get poolAccounts => JsonUtils.asInt(storagePool['total_accounts']);
  int get autoAccounts => JsonUtils.asInt(storagePool['auto_accounts']);
  String get balanceMode => storagePool['balance_mode']?.toString() ?? 'off';
  String get effectiveMode => storagePool['effective_mode']?.toString() ?? 'legacy';
  bool get legacyFallback => storagePool['legacy_fallback'] == true;
  String get balanceModeLabel => <String, String>{
        'off': '关闭（单账号）',
        'random': '随机均衡',
        'weighted': '按权重随机',
      }[balanceMode] ?? balanceMode;
  String get effectiveModeLabel => <String, String>{
        'off': '单账号',
        'single': '单账号',
        'random': '随机均衡',
        'weighted': '按权重随机',
        'legacy': '旧绑定兼容',
      }[effectiveMode] ?? effectiveMode;

  /// 与管理员列表共用同一套会员三态逻辑。
  VipInfo get vipInfo => VipInfo(vipUntil: vipUntil, isAdmin: isAdmin);

  bool get everVip => vipInfo.everVip;
  bool get isVip => vipInfo.isVip;
  bool get isVipExpired => vipInfo.isVipExpired;
  int get vipRemainingDays => vipInfo.remainingDays;
  String get vipExpiryLabel => vipInfo.expiryLabel;
  String get vipTagLabel => vipInfo.tagLabel;
  String get vipTitle => vipInfo.title;
  String get vipSubtitle => vipInfo.subtitle;

  /// 头图展示名：优先真实用户名，未加载时用中性占位。
  String get displayName => username.isEmpty ? '轻云用户' : username;

  static AccountStatus fromJson(Map<String, dynamic> json) => AccountStatus(
        username: json['username']?.toString() ?? '',
        role: json['role']?.toString() ?? 'user',
        vipUntil: JsonUtils.asInt(json['vip_until']),
        storageConnected: json['storage_connected'] == true,
        fileCount: JsonUtils.asInt(json['file_count']),
        shareCount: JsonUtils.asInt(json['share_count']),
        trashCount: JsonUtils.asInt(json['trash_count']),
        tokenCount: JsonUtils.asInt(json['token_count']),
        storagePool: json['storage_pool'] is Map
            ? Map<String, dynamic>.from(json['storage_pool'] as Map)
            : const <String, dynamic>{},
      );
}

/// 管理员视角的用户行（`GET /api/admin/users` 的 items[]）。
class AdminUser {
  const AdminUser({
    required this.id,
    required this.username,
    required this.role,
    required this.vipUntil,
    required this.disabled,
    required this.createdAt,
    required this.files,
  });

  final int id;
  final String username;
  final String role;
  final int vipUntil;
  final bool disabled;
  final int createdAt;
  final int files;

  bool get isAdmin => role == 'admin';
  VipInfo get vipInfo => VipInfo(vipUntil: vipUntil, isAdmin: isAdmin);

  String get roleLabel => isAdmin ? '管理员' : '普通用户';

  static AdminUser fromJson(Map<String, dynamic> json) => AdminUser(
        id: JsonUtils.asInt(json['id']),
        username: json['username']?.toString() ?? '',
        role: json['role']?.toString() ?? 'user',
        vipUntil: JsonUtils.asInt(json['vip_until']),
        disabled: json['disabled'] == true || JsonUtils.asInt(json['disabled']) > 0,
        createdAt: JsonUtils.asInt(json['created_at']),
        files: JsonUtils.asInt(json['files']),
      );
}

/// 管理员用户列表（含当前登录者 uid，用于标注「我」）。
class AdminUserList {
  const AdminUserList({required this.items, required this.currentUid});

  final List<AdminUser> items;
  final int currentUid;

  static AdminUserList fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final items = <AdminUser>[];
    if (raw is List) {
      for (final value in raw) {
        if (value is Map) {
          items.add(AdminUser.fromJson(Map<String, dynamic>.from(value)));
        }
      }
    }
    return AdminUserList(
      items: items,
      currentUid: JsonUtils.asInt(json['current_uid']),
    );
  }
}

/// 会员天数设置结果（`POST /api/admin/users/:id/vip`）。
class VipUpdateResult {
  const VipUpdateResult({
    required this.username,
    required this.days,
    required this.vipUntil,
  });

  final String username;
  final int days;
  final int vipUntil;

  /// days=0 表示取消会员。
  bool get cancelled => days <= 0;

  String get message => cancelled
      ? '已取消 ${username} 的会员'
      : '已为 ${username} 增加 $days 天，有效期至 ${formatEpochDate(vipUntil)}';

  static VipUpdateResult fromJson(Map<String, dynamic> json) =>
      VipUpdateResult(
        username: json['username']?.toString() ?? '',
        days: JsonUtils.asInt(json['days']),
        vipUntil: JsonUtils.asInt(json['vip_until']),
      );
}

/// 登录凭证 / 设备（`GET /api/tokens` 的 items[]）。
///
/// lanflare 没有独立设备表：每次 App 登录会签发一个 `lf_` 令牌，
/// 因此令牌列表就是真实的「登录设备」列表，吊销 = 让该设备下线。
class ApiTokenItem {
  const ApiTokenItem({
    required this.id,
    required this.name,
    required this.prefix,
    required this.scope,
    required this.createdAt,
    required this.lastUsedAt,
  });

  final String id;
  final String name;
  final String prefix;

  /// 'rw' | 'ro'
  final String scope;
  final int createdAt;
  final int lastUsedAt;

  bool get isReadonly => scope == 'ro';
  String get scopeLabel => isReadonly ? '只读' : '读写';

  /// 脱敏展示：后端只返回前 12 位，不会下发完整令牌。
  String get maskedToken => prefix.isEmpty ? '—' : '$prefix••••';

  ApiTokenItem copyWith({String? name, int? lastUsedAt}) => ApiTokenItem(
        id: id,
        name: name ?? this.name,
        prefix: prefix,
        scope: scope,
        createdAt: createdAt,
        lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      );

  static ApiTokenItem fromJson(Map<String, dynamic> json) => ApiTokenItem(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '未命名设备',
        prefix: json['prefix']?.toString() ?? '',
        scope: json['scope']?.toString() == 'ro' ? 'ro' : 'rw',
        createdAt: JsonUtils.asInt(json['created_at']),
        lastUsedAt: JsonUtils.asInt(json['last_used_at']),
      );
}

class ApiTokenList {
  const ApiTokenList({required this.items, required this.count});

  final List<ApiTokenItem> items;
  final int count;

  static ApiTokenList fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final items = <ApiTokenItem>[];
    if (raw is List) {
      for (final value in raw) {
        if (value is Map) {
          items.add(ApiTokenItem.fromJson(Map<String, dynamic>.from(value)));
        }
      }
    }
    return ApiTokenList(
      items: items,
      count: JsonUtils.asInt(json['count'], items.length),
    );
  }
}

/// 新建令牌结果：明文只返回这一次，之后服务端只存 SHA-256 哈希。
class ApiTokenCreated {
  const ApiTokenCreated({required this.token, required this.info});

  final String token;
  final ApiTokenItem info;

  static ApiTokenCreated fromJson(Map<String, dynamic> json) {
    final info = json['info'];
    if (info is! Map) {
      throw ApiException.unknown('创建令牌响应缺少 info（/api/tokens）');
    }
    return ApiTokenCreated(
      token: json['token']?.toString() ?? '',
      info: ApiTokenItem.fromJson(Map<String, dynamic>.from(info)),
    );
  }
}

/// 两步验证状态（`GET /api/security/2fa`）。
class TwoFactorStatus {
  const TwoFactorStatus({required this.enabled, required this.pendingSetup});

  final bool enabled;
  final bool pendingSetup;

  String get label => enabled ? '已开启' : '未开启';

  static TwoFactorStatus fromJson(Map<String, dynamic> json) => TwoFactorStatus(
        enabled: json['enabled'] == true,
        pendingSetup: json['pending_setup'] == true,
      );
}

/// 两步验证绑定信息（`POST /api/security/2fa/setup`）。
class TwoFactorSetup {
  const TwoFactorSetup({
    required this.alreadyEnabled,
    required this.secret,
    required this.uri,
    required this.qrSize,
    required this.qrModules,
  });

  /// 绑定前就已开启：本次属于「重新绑定」，会替换验证器里的旧条目。
  final bool alreadyEnabled;
  final String secret;
  final String uri;

  /// 二维码模块矩阵，交给 `QrCodeView` 零依赖绘制。
  final int qrSize;
  final String qrModules;

  bool get hasQr => qrSize > 0 && qrModules.length >= qrSize * qrSize;

  /// Base32 密钥按 4 位分组，方便人工抄写。
  String get groupedSecret {
    final buffer = StringBuffer();
    for (int i = 0; i < secret.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(secret[i]);
    }
    return buffer.toString();
  }

  static TwoFactorSetup fromJson(Map<String, dynamic> json) {
    final qr = json['qr'];
    int size = 0;
    String modules = '';
    if (qr is Map) {
      size = JsonUtils.asInt(qr['size']);
      modules = qr['modules']?.toString() ?? '';
    }
    return TwoFactorSetup(
      alreadyEnabled: json['enabled'] == true,
      secret: json['secret']?.toString() ?? '',
      uri: json['uri']?.toString() ?? '',
      qrSize: size,
      qrModules: modules,
    );
  }
}

/// 毫秒 epoch → `yyyy-MM-dd HH:mm`（本地时区）；`0` 返回空串。
String formatEpochDateTime(int milliseconds) {
  if (milliseconds <= 0) return '';
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  final y = date.year.toString();
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  final hh = date.hour.toString().padLeft(2, '0');
  final mm = date.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $hh:$mm';
}

/// 搜索页「快捷筛选」的真实分类计数（lanflare `GET /api/stats/quick`）。
///
/// 扩展名分组与 [FileCategoryX.fromFileName] 完全一致，只统计活跃文件。
class QuickCounts {
  const QuickCounts({
    required this.image,
    required this.doc,
    required this.video,
    required this.music,
    required this.zip,
    required this.other,
  });

  final int image;
  final int doc;
  final int video;
  final int music;
  final int zip;
  final int other;

  int get total => image + doc + video + music + zip + other;

  static QuickCounts fromJson(Map<String, dynamic> json) => QuickCounts(
        image: JsonUtils.asInt(json['image']),
        doc: JsonUtils.asInt(json['doc']),
        video: JsonUtils.asInt(json['video']),
        music: JsonUtils.asInt(json['music']),
        zip: JsonUtils.asInt(json['zip']),
        other: JsonUtils.asInt(json['other']),
      );
}

/// 「最近文件」条目：只含定位所需的最小字段，不构造完整 CloudFile。
class RecentFile {
  const RecentFile({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final int id;
  final String name;
  final int createdAt;

  /// 去掉扩展名的主名，作为快捷搜索词（搜索页点击时使用）。
  String get searchTerm {
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  static RecentFile fromJson(Map<String, dynamic> json) => RecentFile(
        id: JsonUtils.asInt(json['id']),
        name: json['name']?.toString() ?? '',
        createdAt: JsonUtils.asInt(json['created_at']),
      );
}

/// 搜索页首页真实统计（替代原型写死的假数值与编造的热搜词）。
class QuickStats {
  const QuickStats({
    required this.totalFiles,
    required this.counts,
    required this.recentUpdatedAt,
    required this.recentFiles,
  });

  final int totalFiles;
  final QuickCounts counts;

  /// 最近一个活跃文件的创建时间（毫秒）；无文件为 0。
  final int recentUpdatedAt;
  final List<RecentFile> recentFiles;

  String get recentUpdatedLabel {
    if (recentUpdatedAt <= 0) return '暂无文件';
    final date = DateTime.fromMillisecondsSinceEpoch(recentUpdatedAt);
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(date.year, date.month, date.day))
        .inDays;
    if (diff <= 0 || diff == 1) {
      final hh = date.hour.toString().padLeft(2, '0');
      final mm = date.minute.toString().padLeft(2, '0');
      return '${diff <= 0 ? '今天' : '昨天'} $hh:$mm';
    }
    return formatEpochDateTime(recentUpdatedAt);
  }

  static QuickStats fromJson(Map<String, dynamic> json) {
    final countsRaw = json['counts'];
    final counts = countsRaw is Map
        ? QuickCounts.fromJson(Map<String, dynamic>.from(countsRaw))
        : const QuickCounts(
            image: 0, doc: 0, video: 0, music: 0, zip: 0, other: 0);
    final raw = json['recent_files'];
    final files = <RecentFile>[];
    if (raw is List) {
      for (final value in raw) {
        if (value is Map) {
          files.add(RecentFile.fromJson(Map<String, dynamic>.from(value)));
        }
      }
    }
    return QuickStats(
      totalFiles: JsonUtils.asInt(json['total_files']),
      counts: counts,
      recentUpdatedAt: JsonUtils.asInt(json['recent_updated_at']),
      recentFiles: files,
    );
  }
}

/// 文件页排序方式（lanflare `GET /api/list?sort=`）。
///
/// [query] 必须与后端 `LIST_SORT_ORDERS` 的键逐字一致；后端用白名单映射为
/// 固定 SQL 片段，未知值会回退默认，不会拼接客户端字符串。
enum FileSort { nameAsc, nameDesc, timeDesc, timeAsc, sizeDesc, sizeAsc }

extension FileSortX on FileSort {
  String get query => switch (this) {
        FileSort.nameAsc => 'name_asc',
        FileSort.nameDesc => 'name_desc',
        FileSort.timeDesc => 'time_desc',
        FileSort.timeAsc => 'time_asc',
        FileSort.sizeDesc => 'size_desc',
        FileSort.sizeAsc => 'size_asc',
      };

  /// 文件页排序菜单 / SectionHead 的展示文案，始终与真实排序一致。
  String get label => switch (this) {
        FileSort.nameAsc => '按名称 A→Z',
        FileSort.nameDesc => '按名称 Z→A',
        FileSort.timeDesc => '按时间（新→旧）',
        FileSort.timeAsc => '按时间（旧→新）',
        FileSort.sizeDesc => '按大小（大→小）',
        FileSort.sizeAsc => '按大小（小→大）',
      };

  String get description => switch (this) {
        FileSort.nameAsc => '文件名升序，不区分大小写',
        FileSort.nameDesc => '文件名降序，不区分大小写',
        FileSort.timeDesc => '最近创建的文件排在前面',
        FileSort.timeAsc => '最早创建的文件排在前面',
        FileSort.sizeDesc => '占用空间大的排在前面',
        FileSort.sizeAsc => '占用空间小的排在前面',
      };
}

/// 目录节点（lanflare `GET /api/folders`），用于「移动到…」选择器。
class FolderEntry {
  const FolderEntry({
    required this.id,
    required this.pid,
    required this.name,
    required this.path,
  });

  final int id;
  final int pid;
  final String name;
  final String path;

  /// 选择器里的缩进层级（由 path 的段数得出，最多 6 级避免溢出）。
  int get depth => path.split('/').where((String s) => s.isNotEmpty).length;

  static FolderEntry fromJson(Map<String, dynamic> json) => FolderEntry(
        id: JsonUtils.asInt(json['id']),
        pid: JsonUtils.asInt(json['pid']),
        name: json['name']?.toString() ?? '',
        path: json['path']?.toString() ?? '',
      );
}

// ---------------------------------------------------------------------------
// 设置页 / 帮助与反馈（lanflare /api/server-info、/api/feedback）
// ---------------------------------------------------------------------------

/// 服务端自检信息（`GET /api/server-info`，公开端点、无需登录）。
///
/// 全部为服务端真实字段，用于自建 VPS 的连通性诊断；不含任何账号或密钥。
class ServerInfo {
  const ServerInfo({
    required this.service,
    required this.version,
    required this.runtime,
    required this.serverTime,
    required this.schemaVersion,
    required this.maxUploadBytes,
    required this.storageTotalConfigured,
    required this.features,
    required this.signingMode,
  });

  final String service;
  final String version;
  final String runtime;
  final int serverTime;
  final int schemaVersion;
  final int maxUploadBytes;
  final bool storageTotalConfigured;
  final List<String> features;

  /// 签名密钥模式（`GET /api/server-info` 的 `signing_mode`）。
  ///
  /// - `dedicated`：已配置独立高熵 `APP_SIGNING_KEY`，与登录口令分离；
  /// - `legacy`：仍从 `APP_PASSWORD` 派生（口令泄露可伪造会话/预览链接）；
  /// - 空字符串或未知值：旧版服务端未返回该字段，**不猜测、不编造**。
  final String signingMode;

  bool get isSigningDedicated => signingMode == 'dedicated';

  bool get isSigningLegacy => signingMode == 'legacy';

  String get signingModeLabel => switch (signingMode) {
        'dedicated' => '独立密钥 · 安全',
        'legacy' => '兼容模式 · 与登录口令同源',
        _ => signingMode.isEmpty
            ? '未知（服务端未返回）'
            : '未知（$signingMode）',
      };

  String get runtimeLabel => switch (runtime) {
        'node-sqlite' => 'VPS / SQLite',
        'cloudflare-workers' => 'Cloudflare Workers / D1',
        _ => runtime.isEmpty ? '未知' : runtime,
      };

  String get serverTimeLabel => serverTime <= 0
      ? '—'
      : formatEpochDateTime(serverTime);

  /// 单请求上传上限（MB）；模型层不反向依赖仓库层。
  String get maxUploadLabel => maxUploadBytes <= 0
      ? '—'
      : '${(maxUploadBytes / (1024 * 1024)).round()} MB';

  static ServerInfo fromJson(Map<String, dynamic> json) {
    final raw = json['features'];
    final List<String> features = <String>[];
    if (raw is List) {
      for (final Object? item in raw) {
        if (item != null) features.add(item.toString());
      }
    }
    return ServerInfo(
      service: json['service']?.toString() ?? '',
      version: json['version']?.toString() ?? '',
      runtime: json['runtime']?.toString() ?? '',
      serverTime: JsonUtils.asInt(json['server_time']),
      schemaVersion: JsonUtils.asInt(json['schema_version']),
      maxUploadBytes: JsonUtils.asInt(json['max_upload_bytes']),
      storageTotalConfigured: json['storage_total_configured'] == true,
      features: features,
      signingMode: json['signing_mode']?.toString() ?? '',
    );
  }
}

/// 反馈分类（key 与后端 `FEEDBACK_CATEGORIES` 逐字一致）。
enum FeedbackCategory { bug, feature, question, other }

extension FeedbackCategoryX on FeedbackCategory {
  String get key => switch (this) {
        FeedbackCategory.bug => 'bug',
        FeedbackCategory.feature => 'feature',
        FeedbackCategory.question => 'question',
        FeedbackCategory.other => 'other',
      };

  String get label => switch (this) {
        FeedbackCategory.bug => '问题反馈',
        FeedbackCategory.feature => '功能建议',
        FeedbackCategory.question => '使用咨询',
        FeedbackCategory.other => '其他',
      };

  IconData get icon => switch (this) {
        FeedbackCategory.bug => Icons.bug_report_outlined,
        FeedbackCategory.feature => Icons.lightbulb_outline,
        FeedbackCategory.question => Icons.help_outline,
        FeedbackCategory.other => Icons.chat_bubble_outline,
      };

  static FeedbackCategory fromKey(String? key) => switch (key) {
        'bug' => FeedbackCategory.bug,
        'feature' => FeedbackCategory.feature,
        'question' => FeedbackCategory.question,
        _ => FeedbackCategory.other,
      };
}

/// 反馈状态（key 与后端 `FEEDBACK_STATUSES` 逐字一致）。
enum FeedbackStatus { open, replied, closed }

extension FeedbackStatusX on FeedbackStatus {
  String get key => switch (this) {
        FeedbackStatus.open => 'open',
        FeedbackStatus.replied => 'replied',
        FeedbackStatus.closed => 'closed',
      };

  String get label => switch (this) {
        FeedbackStatus.open => '待处理',
        FeedbackStatus.replied => '已回复',
        FeedbackStatus.closed => '已关闭',
      };

  static FeedbackStatus fromKey(String? key) => switch (key) {
        'replied' => FeedbackStatus.replied,
        'closed' => FeedbackStatus.closed,
        _ => FeedbackStatus.open,
      };
}

/// 一条真实反馈（`GET /api/feedback` / `GET /api/admin/feedback`）。
class FeedbackItem {
  const FeedbackItem({
    required this.id,
    required this.uid,
    required this.category,
    required this.content,
    required this.contact,
    required this.status,
    required this.adminReply,
    required this.createdAt,
    required this.repliedAt,
    this.username,
  });

  final int id;
  final int uid;
  final FeedbackCategory category;
  final String content;
  final String contact;
  final FeedbackStatus status;
  final String adminReply;
  final int createdAt;
  final int repliedAt;

  /// 仅管理员列表返回。
  final String? username;

  String get createdLabel =>
      createdAt <= 0 ? '—' : formatEpochDateTime(createdAt);

  String get repliedLabel =>
      repliedAt <= 0 ? '' : formatEpochDateTime(repliedAt);

  static FeedbackItem fromJson(Map<String, dynamic> json) => FeedbackItem(
        id: JsonUtils.asInt(json['id']),
        uid: JsonUtils.asInt(json['uid']),
        category: FeedbackCategoryX.fromKey(json['category']?.toString()),
        content: json['content']?.toString() ?? '',
        contact: json['contact']?.toString() ?? '',
        status: FeedbackStatusX.fromKey(json['status']?.toString()),
        adminReply: json['admin_reply']?.toString() ?? '',
        createdAt: JsonUtils.asInt(json['created_at']),
        repliedAt: JsonUtils.asInt(json['replied_at']),
        username: json['username']?.toString(),
      );
}

// ---------------------------------------------------------------------------
// 扫一扫 / 分享转存（lanflare /api/resolve-share、/api/rent）
// ---------------------------------------------------------------------------

/// 转存结果（`POST /api/rent`）。文件夹分享返回新建 / 跳过的文件数。
class RentResult {
  const RentResult({
    required this.kind,
    required this.created,
    required this.skipped,
    this.nodeId,
  });

  final String kind;
  final int created;
  final int skipped;
  final String? nodeId;

  String get summary {
    if (kind == 'folder') {
      return '新建 $created 个文件'
          '${skipped > 0 ? '，跳过 $skipped 个同名项' : ''}';
    }
    return created > 0 ? '已转存 1 个文件' : '未创建文件';
  }

  static RentResult fromJson(Map<String, dynamic> json) {
    final Object? node = json['node'];
    return RentResult(
      kind: json['kind']?.toString() ?? 'file',
      created: JsonUtils.asInt(json['created']),
      skipped: JsonUtils.asInt(json['skipped']),
      nodeId: node is Map ? node['id']?.toString() : null,
    );
  }
}

// ---------------------------------------------------------------------------
// 统一扫码解析（lanflare /api/scan/resolve）
// ---------------------------------------------------------------------------

/// 后端自动判别的分享来源；前端不猜、不拼码。
enum ScanSource { lanflare, lanzou }

extension ScanSourceX on ScanSource {
  String get key => switch (this) {
        ScanSource.lanflare => 'lanflare',
        ScanSource.lanzou => 'lanzou',
      };

  String get label => switch (this) {
        ScanSource.lanflare => '轻云分享码',
        ScanSource.lanzou => '蓝奏云原生分享',
      };

  static ScanSource fromKey(String? key) =>
      key == 'lanzou' ? ScanSource.lanzou : ScanSource.lanflare;
}

/// `POST /api/scan/resolve` 的判别联合结果。
///
/// 蓝奏链接由服务端抓分享页探测，探测结果留在服务端、只回一个一次性
/// `importId`；[needsPassword] / [probed] / [error] 决定能否直接转存。
/// 探测失败时 [name] / [sizeBytes] 可能为 0，前端如实显示，不编造数值。
class ScanResolution {
  const ScanResolution({
    required this.source,
    required this.name,
    required this.sizeBytes,
    required this.chunks,
    this.code,
    this.importId,
    this.kind,
    this.files,
    this.needsPassword = false,
    this.probed = true,
    this.error = '',
    this.host = '',
  });

  final ScanSource source;
  final String name;
  final int sizeBytes;
  final int chunks;

  /// lanflare：规范化后原样回传 `/api/rent` 的标准码。
  final String? code;

  /// 蓝奏：服务端暂存的探测结果凭证，传给 `/api/import-lanzou`。
  final String? importId;
  final String? kind;
  final int? files;

  /// 分享页要求提取码但未提供。
  final bool needsPassword;

  /// 外呼探测是否成功（失败时 [error] 是真实原因）。
  final bool probed;
  final String error;
  final String host;

  bool get isLanzou => source == ScanSource.lanzou;
  bool get isFolder => kind == 'folder';

  /// 是否可以直接提交转存（有 code 或 importId）。
  bool get ready => isLanzou
      ? (importId != null && importId!.isNotEmpty)
      : (code != null && code!.isNotEmpty);

  /// 阻止转存的原因；为空表示可以转存。
  String get blocker {
    if (ready) return '';
    if (isLanzou && needsPassword) return '该分享需要提取码';
    if (!probed) return error.isEmpty ? '无法读取蓝奏分享页' : error;
    if (error.isNotEmpty) return error;
    return '解析结果不完整，请重新识别';
  }

  String get typeLabel => isFolder
      ? '文件夹 · ${files ?? 0} 个文件'
      : (isLanzou ? '蓝奏云文件' : '文件');

  static ScanResolution fromJson(Map<String, dynamic> json) => ScanResolution(
        source: ScanSourceX.fromKey(json['source']?.toString()),
        name: json['name']?.toString() ?? '',
        sizeBytes: JsonUtils.asInt(json['sizeBytes']),
        chunks: JsonUtils.asInt(json['chunks']),
        code: json['code']?.toString(),
        importId: json['importId']?.toString(),
        kind: json['kind']?.toString(),
        files: json['files'] == null ? null : JsonUtils.asInt(json['files']),
        needsPassword: json['needsPassword'] == true,
        probed: json['probed'] != false,
        error: json['error']?.toString() ?? '',
        host: json['host']?.toString() ?? '',
      );
}

// ---------------------------------------------------------------------------
// 为你推荐 · 每日照片回忆（lanflare /api/recall/daily）
// ---------------------------------------------------------------------------

/// 回忆卡中的一张真实照片（后端已为它签发短期预览 URL）。
class RecallPhoto {
  const RecallPhoto({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.previewUrl,
  });

  final String id;
  final String name;
  final int createdAt;
  final String previewUrl;

  bool get hasPreview => previewUrl.isNotEmpty;

  static RecallPhoto fromJson(Map<String, dynamic> json) => RecallPhoto(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        createdAt: JsonUtils.asInt(json['created_at']),
        previewUrl: json['preview_url']?.toString() ?? '',
      );
}

/// 基于本人真实图片上传日期聚合出的回忆；无任何编造的地点 / 文案 / 数值。
class DailyRecall {
  const DailyRecall({
    required this.hasMemory,
    required this.kind,
    required this.date,
    required this.title,
    required this.count,
    required this.truncated,
    required this.photos,
  });

  final bool hasMemory;
  final String kind;
  final String date;
  final String title;
  final int count;
  final bool truncated;
  final List<RecallPhoto> photos;

  bool get isOnThisDay => kind == 'on_this_day';

  /// 小标签：只描述真实来源类型，不含编造数值。
  String get tag => isOnThisDay ? '往年的这一天' : '照片回忆';

  /// 真实张数；count 异常归零时退回真实条目数，绝不写死。
  String get subtitle {
    final int n = count > 0 ? count : photos.length;
    return '上传了 $n 张照片';
  }

  static DailyRecall fromJson(Map<String, dynamic> json) {
    final Object? raw = json['items'];
    final List<RecallPhoto> photos = raw is List<dynamic>
        ? raw
            .whereType<Map<String, dynamic>>()
            .map(RecallPhoto.fromJson)
            .toList()
        : <RecallPhoto>[];
    return DailyRecall(
      hasMemory: json['has_memory'] == true,
      kind: json['kind']?.toString() ?? 'none',
      date: json['date']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      count: JsonUtils.asInt(json['count']),
      truncated: json['truncated'] == true,
      photos: photos,
    );
  }
}

// ---------------------------------------------------------------------------
// 我的照片回忆 · 真实照片轮播（lanflare /api/recall/album）
// ---------------------------------------------------------------------------

/// 按上传日分组的一组真实照片。
class RecallAlbumGroup {
  const RecallAlbumGroup({
    required this.date,
    required this.title,
    required this.count,
    required this.photos,
  });

  final String date;
  final String title;
  final int count;
  final List<RecallPhoto> photos;

  static RecallAlbumGroup fromJson(Map<String, dynamic> json) {
    final Object? raw = json['items'];
    final List<RecallPhoto> photos = raw is List<dynamic>
        ? raw
            .whereType<Map<String, dynamic>>()
            .map(RecallPhoto.fromJson)
            .toList()
        : <RecallPhoto>[];
    return RecallAlbumGroup(
      date: json['date']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      count: JsonUtils.asInt(json['count']),
      photos: photos,
    );
  }
}

/// 相册页「我的照片回忆」的真实数据源：无视频生成、无编造数值。
class RecallAlbum {
  const RecallAlbum({
    required this.hasPhotos,
    required this.totalGroups,
    required this.totalPhotos,
    required this.truncated,
    required this.groups,
    required this.previewExpiresAt,
  });

  final bool hasPhotos;
  final int totalGroups;
  final int totalPhotos;
  final bool truncated;
  final List<RecallAlbumGroup> groups;
  final int previewExpiresAt;

  /// 横幅文案：全部为真实计数，不写死。
  String get summary => '已收录 $totalPhotos 张照片 · $totalGroups 个回忆日';

  static RecallAlbum fromJson(Map<String, dynamic> json) {
    final Object? raw = json['groups'];
    final List<RecallAlbumGroup> groups = raw is List<dynamic>
        ? raw
            .whereType<Map<String, dynamic>>()
            .map(RecallAlbumGroup.fromJson)
            .toList()
        : <RecallAlbumGroup>[];
    return RecallAlbum(
      hasPhotos: json['has_photos'] == true,
      totalGroups: JsonUtils.asInt(json['total_groups']),
      totalPhotos: JsonUtils.asInt(json['total_photos']),
      truncated: json['truncated'] == true,
      groups: groups,
      previewExpiresAt: JsonUtils.asInt(json['preview_expires_at']),
    );
  }
}
