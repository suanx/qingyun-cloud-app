import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import '../models/cloud_models.dart';
import '../models/transfer_store.dart';
import '../utils/error_reporter.dart';
import '../utils/json_utils.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'token_store.dart';

/// 数据仓库：统一对接 lanflare 后端。
///
/// 页面只依赖本仓库，全部数据来自真实接口。lanflare 接口约定
/// （Bearer/Basic 鉴权、原生 JSON）见 https://github.com/suanx/lanflare 的 /docs。
class CloudRepository {
  CloudRepository({ApiClient? client}) : _client = client ?? ApiClient.shared;

  final ApiClient _client;

  // ---------------------------------------------------------------------------
  // 登录 / 登出
  // ---------------------------------------------------------------------------

  /// 本 App 签发的 API 令牌名称（可在网页端「API 令牌」中识别）。
  static const String _apiTokenName = 'qingyun-android';

  /// 账号密码登录 lanflare（`POST /api/auth/login`）。
  ///
  /// 流程：校验业务失败 → 读取 `Set-Cookie: lf_session` → 用该会话调用
  /// `POST /api/tokens` 换发可吊销的 `lf_...` 令牌 → 加密保存令牌与其 id。
  /// 令牌换发失败时降级保留会话凭证，登录仍成功；**任何情况都不再保存账号口令**。
  /// 开启 TOTP 时传 [totpCode]；失败抛 [ApiException]。
  Future<String> login(String account, String password, {String? totpCode}) async {
    final previousTokenId = TokenStore.tokenId;
    // 先清旧凭证：登录失败时设备上不会残留上一次的登录态。
    await TokenStore.clear();
    final response = await _client.raw((dio) => dio.post<dynamic>(
          '/api/auth/login',
          data: <String, dynamic>{
            'u': account,
            'p': password,
            if (totpCode != null && totpCode.isNotEmpty) 'code': totpCode,
          },
        ));
    final body = response.data;

    // raw 绕过了 ApiClient 的解包，这里补上与 _unwrapPlain 等价的业务失败校验。
    if (body is Map<String, dynamic>) {
      final error = body['error'];
      if (error is String && error.isNotEmpty) {
        throw ApiException.badResponse(response.statusCode ?? 200, error);
      }
    }

    // 后端登录必定下发 HttpOnly 会话 cookie；缺失即视为异常，不写入任何凭证。
    final session = _sessionFromLogin(response);
    if (session == null || session.isEmpty) {
      throw ApiException.unknown('登录响应缺少会话凭证，未保存登录态');
    }
    await TokenStore.save(session);

    final issued = await _issueApiToken();
    if (issued != null) {
      await TokenStore.save(issued.token, tokenId: issued.id);
    }
    // 吊销上一次登录签发的令牌，避免服务端无限累积；失败不影响本次登录。
    if (previousTokenId != null && previousTokenId.isNotEmpty) {
      await _safeRevokeToken(previousTokenId);
    }

    return body is Map<String, dynamic>
        ? (body['username']?.toString() ?? account)
        : account;
  }

  /// 从登录响应提取 `lf_session` 会话值。
  static String? _sessionFromLogin(Response<dynamic> response) {
    for (final cookie in response.headers['set-cookie'] ?? const <String>[]) {
      final match = RegExp(r'lf_session=([^;]+)').firstMatch(cookie);
      final value = match?.group(1)?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  /// 用当前会话换发 `lf_` API 令牌（服务端只存哈希，可单独吊销）。
  /// 失败返回 null，由调用方降级到会话凭证。
  Future<({String token, String id})?> _issueApiToken() async {
    try {
      final data = _mapOf(
        await _client.postRaw('/api/tokens', body: <String, dynamic>{
          'name': _apiTokenName,
          'scope': 'rw',
        }),
        '/api/tokens',
      );
      final token = data['token'];
      final info = data['info'];
      final id = info is Map ? info['id']?.toString() : null;
      if (token is String && token.startsWith('lf_') && id != null && id.isNotEmpty) {
        return (token: token, id: id);
      }
      return null;
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'login#issueApiToken');
      return null;
    }
  }

  /// 尽力吊销令牌：网络 / 权限异常只上报，不阻断登录或退出。
  Future<void> _safeRevokeToken(String id) async {
    try {
      await _client.deleteRaw('/api/tokens/$id');
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'revokeApiToken');
    }
  }

  /// 退出登录：先吊销服务端令牌（此时仍有鉴权），再清除本地凭证。
  Future<void> logout() async {
    final id = TokenStore.tokenId;
    if (id != null && id.isNotEmpty) {
      await _safeRevokeToken(id);
    }
    await TokenStore.clear();
  }

  // ---------------------------------------------------------------------------
  // 容量概览
  // ---------------------------------------------------------------------------

  /// 容量概览：lanflare `GET /api/storage/summary`。
  /// 后端未配置总容量时使用 [AppConfig.fallbackTotalGb] 兜底。
  Future<StorageSummary> storageSummary() async {
    final data = _mapOf(
      await _client.getRaw('/api/storage/summary'),
      '/api/storage/summary',
    );
    final usedBytes = JsonUtils.asDouble(data['used_bytes']);
    var totalBytes = JsonUtils.asDouble(data['total_bytes']);
    if (totalBytes <= 0) {
      totalBytes = AppConfig.fallbackTotalGb * _bytesPerGb;
    }
    return StorageSummary(
      usedGb: usedBytes / _bytesPerGb,
      totalGb: totalBytes / _bytesPerGb,
      byCategory: StorageCategoryStats.fromJson(
        _optionalMapOf(data['by_category']),
      ),
    );
  }

  /// 当前账户状态：lanflare `GET /api/status`。
  /// 返回真实用户名、角色、会员到期时间与本人文件/分享/回收站/令牌计数。
  Future<AccountStatus> accountStatus() async {
    final data = _mapOf(
      await _client.getRaw('/api/status'),
      '/api/status',
    );
    return AccountStatus.fromJson(data);
  }

  /// 管理员用户列表：lanflare `GET /api/admin/users`（仅 admin 可用）。
  Future<AdminUserList> adminUsers() async {
    final data = _mapOf(
      await _client.getRaw('/api/admin/users'),
      '/api/admin/users',
    );
    return AdminUserList.fromJson(data);
  }

  /// 设置会员天数：lanflare `POST /api/admin/users/:id/vip`。
  /// [days] 为 0 时取消会员，正数时从 max(now, 现有到期) 累加；
  /// 后端限定 0~3650 的整数，不接任何支付渠道。
  Future<VipUpdateResult> setUserVipDays(int userId, int days) async {
    if (userId <= 0 || days < 0 || days > 3650) {
      throw ApiException.unknown('天数需为 0 ~ 3650 的整数（0 表示取消会员）');
    }
    final data = _mapOf(
      await _client.postRaw(
        '/api/admin/users/$userId/vip',
        body: <String, dynamic>{'days': days},
      ),
      '/api/admin/users/:id/vip',
    );
    return VipUpdateResult.fromJson(data);
  }

  /// 搜索页快捷筛选的真实统计：lanflare `GET /api/stats/quick`。
  /// 分类计数、最近更新时间与最近文件均来自本人活跃 nodes，
  /// 不再使用原型写死的假数值。
  Future<QuickStats> quickStats() async {
    final data = _mapOf(
      await _client.getRaw('/api/stats/quick'),
      '/api/stats/quick',
    );
    return QuickStats.fromJson(data);
  }

  /// 首页「为你推荐」回忆卡：lanflare `GET /api/recall/daily`。
  ///
  /// [today] 传设备本地日期（YYYY-MM-DD），后端据此判断「往年的这一天」；
  /// 分组用节点 `created_at` 的 UTC 日历日。全部字段来自本人活跃图片节点，
  /// 无图片时返回 `hasMemory=false`，由页面显示中性文案。
  Future<DailyRecall> dailyRecall() async {
    final DateTime now = DateTime.now();
    final String today = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final data = _mapOf(
      await _client.getRaw(
        '/api/recall/daily',
        query: <String, dynamic>{'today': today},
      ),
      '/api/recall/daily',
    );
    return DailyRecall.fromJson(data);
  }

  /// 相册页「我的照片回忆」：lanflare `GET /api/recall/album`。
  ///
  /// 按真实上传日期分组的本人活跃图片，每张带 15 分钟签名预览 URL；
  /// 无图片时返回 `hasPhotos=false`，由页面显示中性文案。
  /// 返回的 [RecallAlbum.previewExpiresAt] 供轮播页在过期前自动续签。
  Future<RecallAlbum> recallAlbum() async {
    final data = _mapOf(
      await _client.getRaw('/api/recall/album'),
      '/api/recall/album',
    );
    return RecallAlbum.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // 设置 / 帮助与反馈
  // ---------------------------------------------------------------------------

  /// 服务端自检：lanflare `GET /api/server-info`（公开，登录前也可用）。
  /// 设置页「测试连接」用它验证自建 VPS 地址是否指向真正的 lanflare 实例。
  Future<ServerInfo> serverInfo() async {
    final data = _mapOf(
      await _client.getRaw('/api/server-info'),
      '/api/server-info',
    );
    return ServerInfo.fromJson(data);
  }

  /// 提交反馈：lanflare `POST /api/feedback`。
  /// 后端统一校验长度、60 秒冷却与每用户上限，前端只做即时提示。
  Future<FeedbackItem> submitFeedback({
    required FeedbackCategory category,
    required String content,
    String contact = '',
  }) async {
    final data = _mapOf(
      await _client.postRaw('/api/feedback', body: <String, dynamic>{
        'category': category.key,
        'content': content,
        'contact': contact,
      }),
      '/api/feedback',
    );
    final item = data['item'];
    if (item is Map) {
      return FeedbackItem.fromJson(Map<String, dynamic>.from(item));
    }
    throw ApiException.unknown('反馈提交响应缺少条目（/api/feedback）');
  }

  /// 本人反馈列表：lanflare `GET /api/feedback`。
  Future<List<FeedbackItem>> myFeedback() async {
    final data = _mapOf(
      await _client.getRaw('/api/feedback'),
      '/api/feedback',
    );
    return _itemsOf(data).map(FeedbackItem.fromJson).toList();
  }

  /// 管理员全量反馈：lanflare `GET /api/admin/feedback`（仅 admin）。
  Future<List<FeedbackItem>> adminFeedback() async {
    final data = _mapOf(
      await _client.getRaw('/api/admin/feedback'),
      '/api/admin/feedback',
    );
    return _itemsOf(data).map(FeedbackItem.fromJson).toList();
  }

  /// 管理员回复 / 改状态：lanflare `PATCH /api/admin/feedback/:id`。
  Future<FeedbackItem> replyFeedback(
    int id, {
    required FeedbackStatus status,
    required String reply,
  }) async {
    if (id <= 0) throw ApiException.unknown('反馈标识无效');
    final data = _mapOf(
      await _client.patchRaw('/api/admin/feedback/$id', body: <String, dynamic>{
        'status': status.key,
        'reply': reply,
      }),
      '/api/admin/feedback/:id',
    );
    final item = data['item'];
    if (item is Map) {
      return FeedbackItem.fromJson(Map<String, dynamic>.from(item));
    }
    throw ApiException.unknown('回复响应缺少条目（/api/admin/feedback/:id）');
  }

  // ---------------------------------------------------------------------------
  // 登录设备 / API 令牌 / 两步验证
  // ---------------------------------------------------------------------------
  //
  // 注：旧版「每用户绑定存储账号」的仓库方法（storageAccount /
  // bindStorageAccount / unbindStorageAccount）已删除。后端自存储账号池
  // 改造后，账号由管理员在网页端统一管理，App 无绑定入口，池状态统一
  // 经 accountStatus() 的 storage_pool 展示；/api/storage/account 等旧
  // 端点仅为管理员运维兼容保留，App 不再调用，避免留下无入口的死代码。

  /// 登录凭证列表：lanflare `GET /api/tokens`（仅本人）。
  Future<ApiTokenList> listTokens() async {
    final data = _mapOf(
      await _client.getRaw('/api/tokens'),
      '/api/tokens',
    );
    return ApiTokenList.fromJson(data);
  }

  /// 创建令牌：明文只返回一次，服务端仅存 SHA-256 哈希。
  Future<ApiTokenCreated> createToken({
    required String name,
    bool readonly = false,
  }) async {
    final clean = name.trim();
    if (clean.isEmpty || clean.length > 40) {
      throw ApiException.unknown('设备名称需为 1 ~ 40 个字符');
    }
    final data = _mapOf(
      await _client.postRaw('/api/tokens', body: <String, dynamic>{
        'name': clean,
        'scope': readonly ? 'ro' : 'rw',
      }),
      '/api/tokens',
    );
    final created = ApiTokenCreated.fromJson(data);
    if (created.token.isEmpty) {
      throw ApiException.unknown('创建令牌响应缺少明文（/api/tokens）');
    }
    return created;
  }

  /// 重命名令牌（设备备注）：lanflare `PATCH /api/tokens/:id`。
  Future<void> renameToken(String id, String name) async {
    _checkTokenId(id, api: '/api/tokens/:id');
    final clean = name.trim();
    if (clean.isEmpty || clean.length > 40) {
      throw ApiException.unknown('设备名称需为 1 ~ 40 个字符');
    }
    await _client.patchRaw('/api/tokens/$id', body: <String, dynamic>{
      'name': clean,
    });
  }

  /// 吊销令牌（让该设备下线）：lanflare `DELETE /api/tokens/:id`。
  Future<void> revokeToken(String id) async {
    _checkTokenId(id, api: '/api/tokens/:id');
    await _client.deleteRaw('/api/tokens/$id');
  }

  /// 自助修改本人登录密码：`POST /api/auth/change-password`。
  ///
  /// 后端校验当前密码后才写入（目标用户恒为当前登录者），普通用户可用；
  /// 成功后现有会话与令牌继续有效，无需重新登录。
  Future<void> changePassword({
    required String current,
    required String next,
  }) async {
    if (current.isEmpty) {
      throw ApiException.unknown('请输入当前密码');
    }
    if (next.length < 6) {
      throw ApiException.unknown('新密码至少 6 位');
    }
    if (next == current) {
      throw ApiException.unknown('新密码不能与当前密码相同');
    }
    await _client.postRaw('/api/auth/change-password', body: <String, dynamic>{
      'current': current,
      'next': next,
    });
  }

  static void _checkTokenId(String id, {required String api}) {
    final clean = id.trim();
    if (clean.isEmpty ||
        clean.contains('/') ||
        clean.contains('?') ||
        clean.contains('#')) {
      throw ApiException.unknown('令牌标识无效（$api）');
    }
  }

  /// 两步验证状态：lanflare `GET /api/security/2fa`。
  Future<TwoFactorStatus> twoFactorStatus() async {
    final data = _mapOf(
      await _client.getRaw('/api/security/2fa'),
      '/api/security/2fa',
    );
    return TwoFactorStatus.fromJson(data);
  }

  /// 开始绑定：返回 Base32 密钥、otpauth URI 与二维码模块矩阵。
  Future<TwoFactorSetup> twoFactorSetup() async {
    final data = _mapOf(
      await _client.postRaw('/api/security/2fa/setup'),
      '/api/security/2fa/setup',
    );
    final setup = TwoFactorSetup.fromJson(data);
    if (setup.secret.isEmpty) {
      throw ApiException.unknown('绑定信息响应缺少密钥（/api/security/2fa/setup）');
    }
    return setup;
  }

  /// 确认绑定 / 关闭两步验证：[enable] 为 true 时走 enable，否则 disable。
  Future<void> submitTwoFactorCode(String code, {required bool enable}) async {
    final clean = code.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(clean)) {
      throw ApiException.unknown('请输入 6 位数字验证码');
    }
    final path = enable
        ? '/api/security/2fa/enable'
        : '/api/security/2fa/disable';
    await _client.postRaw(path, body: <String, dynamic>{'code': clean});
  }

  /// 存储清理建议：lanflare `GET /api/storage/analyze`（只读分析）。
  Future<StorageAnalysis> storageAnalysis() async {
    final data = _mapOf(
      await _client.getRaw('/api/storage/analyze'),
      '/api/storage/analyze',
    );
    return StorageAnalysis.fromJson(data);
  }

  /// 执行清理：把分析结果中的节点移入回收站（可在回收站恢复）。
  /// 后端会二次校验 id 是否仍属于建议集合，客户端传任意 id 不会误删。
  Future<StorageCleanResult> cleanStorage(List<int> ids) async {
    final data = _mapOf(
      await _client.postRaw('/api/storage/clean', body: <String, dynamic>{
        'ids': ids,
      }),
      '/api/storage/clean',
    );
    return StorageCleanResult.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // 文件列表 / 搜索
  // ---------------------------------------------------------------------------

  /// 文件列表：lanflare `GET /api/list?pid=0`；有关键字时走
  /// `GET /api/search?q=`（全局搜索）。目录节点暂不进入列表页。
  Future<List<CloudFile>> files({
    FileCategory category = FileCategory.all,
    String? keyword,
    int pid = 0,
    bool includeDirs = false,
    FileSort sort = FileSort.timeDesc,
  }) async {
    final query = keyword?.trim() ?? '';
    final Map<String, dynamic> data;
    if (query.isEmpty) {
      // 排序由后端 SQL 完成（白名单 sort 键），前端不重复排序，避免双份规则漂移。
      data = _mapOf(
        await _client.getRaw('/api/list', query: <String, dynamic>{
          'pid': pid,
          'sort': sort.query,
        }),
        '/api/list',
      );
    } else {
      // /api/search 只做全局文件名匹配、不支持 sort；搜索页用默认顺序即可。
      data = _mapOf(
        await _client.getRaw('/api/search', query: <String, dynamic>{'q': query}),
        '/api/search',
      );
    }
    final items = _itemsOf(data);
    return items
        .where((node) => includeDirs || node['type'] == 'file')
        .map(_fileFromNode)
        .where((file) => category == FileCategory.all || file.category == category)
        .toList();
  }

  /// 全部活跃目录：lanflare `GET /api/folders`（供「移动到…」选择器）。
  Future<List<FolderEntry>> listFolders() async {
    final data = _mapOf(
      await _client.getRaw('/api/folders'),
      '/api/folders',
    );
    final items = _itemsOf(data);
    return items.map(FolderEntry.fromJson).toList();
  }

  /// 新建文件夹（lanflare `POST /api/mkdir`，`ensure:true` 复用同名目录）。
  Future<CloudFile> createFolder(String name, {int pid = 0}) async {
    final data = _mapOf(
      await _client.postRaw('/api/mkdir', body: <String, dynamic>{
        'pid': pid,
        'name': name,
        'ensure': true,
      }),
      '/api/mkdir',
    );
    final node = data['node'];
    if (node is Map<String, dynamic>) return _fileFromNode(node);
    throw ApiException.unknown('新建文件夹响应缺少节点（/api/mkdir）');
  }

  /// 重命名（lanflare `POST /api/rename`）。
  Future<void> renameFile(String fileId, String newName) async {
    await _client.postRaw('/api/rename', body: <String, dynamic>{
      'id': _requireId(fileId, api: '/api/rename'),
      'name': newName,
    });
  }

  /// 移动文件（lanflare `POST /api/move`）。
  Future<void> moveFiles(List<String> ids, int targetPid) async {
    await _client.postRaw('/api/move', body: <String, dynamic>{
      'ids': _toIntIds(ids, api: '/api/move'),
      'pid': targetPid,
    });
  }

  // ---------------------------------------------------------------------------
  // 回收站
  // ---------------------------------------------------------------------------

  Future<List<CloudFile>> trashFiles() async {
    final data = _mapOf(await _client.getRaw('/api/bin'), '/api/bin');
    return _itemsOf(data)
        .where((node) => node['type'] == 'file')
        .map(_fileFromNode)
        .toList();
  }

  Future<void> restoreFiles(List<String> ids) async {
    await _client.postRaw('/api/restore', body: <String, dynamic>{'ids': _toIntIds(ids, api: '/api/restore')});
  }

  Future<void> hardDeleteFiles(List<String> ids) async {
    await _client.postRaw('/api/hard-delete', body: <String, dynamic>{'ids': _toIntIds(ids, api: '/api/hard-delete')});
  }

  Future<void> deleteFiles(List<String> ids) async {
    await _client.postRaw('/api/delete', body: <String, dynamic>{'ids': _toIntIds(ids, api: '/api/delete')});
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
    final data =
        _mapOf(await _client.getRaw('/api/my-shares'), '/api/my-shares');
    return _itemsOf(data).length;
  }

  /// 回收站中的文件数量（lanflare `GET /api/bin`）。
  Future<int> trashCount() async {
    final data = _mapOf(await _client.getRaw('/api/bin'), '/api/bin');
    return _itemsOf(data).where((node) => node['type'] == 'file').length;
  }

  /// 我的分享列表（lanflare `GET /api/my-shares`）。
  Future<List<ShareItem>> myShares() async {
    final data =
        _mapOf(await _client.getRaw('/api/my-shares'), '/api/my-shares');
    return _itemsOf(data).map((item) {
      return ShareItem(
        id: item['id']?.toString() ?? '',
        name: item['name']?.toString() ?? '未命名分享',
        kind: item['kind']?.toString() ?? 'file',
        createdAt: JsonUtils.asInt(item['created_at']),
        expiresAt: JsonUtils.asInt(item['expires_at']),
        downloads: JsonUtils.asInt(item['downloads']),
        maxDownloads: JsonUtils.asInt(item['max_downloads']),
        hasPassword: (item['password']?.toString().isNotEmpty ?? false),
      );
    }).toList();
  }

  /// 撤销分享（lanflare `DELETE /api/shares/:id`）。
  Future<void> deleteShare(String shareId) async {
    final id = shareId.trim();
    if (id.isEmpty || id.contains('/') || id.contains('?') || id.contains('#')) {
      throw ApiException.unknown('分享标识无效（/api/shares/:id）');
    }
    await _client.deleteRaw('/api/shares/$id');
  }

  /// 生成分享链接（lanflare `POST /api/share`），返回公开下载网址。
  Future<String> shareFile(String fileId, {String? password, int expireDays = 0}) async {
    final data = _mapOf(
      await _client.postRaw('/api/share', body: <String, dynamic>{
        'id': _requireId(fileId, api: '/api/share'),
        'expiresInDays': expireDays,
        if (password != null && password.isNotEmpty) 'password': password,
      }),
      '/api/share',
    );
    return data['url']?.toString() ?? data['code']?.toString() ?? '';
  }

  // ---------------------------------------------------------------------------
  // 扫一扫 / 分享转存
  // ---------------------------------------------------------------------------

  /// 转存分享到目标目录（lanflare `POST /api/rent`）。
  /// [pid] 为 0 表示根目录；`ro` 令牌会被后端守卫拒绝。
  Future<RentResult> rentShare(String code, int pid) async {
    if (code.trim().isEmpty) throw ApiException.unknown('分享码为空（/api/rent）');
    if (pid < 0) throw ApiException.unknown('目标目录标识无效（/api/rent）');
    final data = _mapOf(
      await _client.postRaw('/api/rent', body: <String, dynamic>{
        'code': code,
        'pid': pid,
      }),
      '/api/rent',
    );
    return RentResult.fromJson(data);
  }

  /// 统一扫码解析（lanflare `POST /api/scan/resolve`）。
  ///
  /// [raw] 原样传给后端：可以是 lanflare 分享码 / 链接，也可以是蓝奏云原生
  /// 分享链接（含提取码文本）。后端自动判别，前端不猜、不拼码。
  /// [pwd] 仅在蓝奏分享要求提取码时由用户输入，重新发起解析。
  Future<ScanResolution> scanResolve(String raw, {String pwd = ''}) async {
    final String value = raw.trim();
    if (value.isEmpty) throw ApiException.unknown('扫码内容为空（/api/scan/resolve）');
    final data = _mapOf(
      await _client.postRaw('/api/scan/resolve', body: <String, dynamic>{
        'raw': value,
        if (pwd.isNotEmpty) 'pwd': pwd,
      }),
      '/api/scan/resolve',
    );
    return ScanResolution.fromJson(data);
  }

  /// 提交蓝奏导入（lanflare `POST /api/import-lanzou`）。
  /// [importId] 是服务端暂存探测结果的一次性凭证，10 分钟过期、用完即毁。
  Future<RentResult> importLanzou(String importId, int pid) async {
    if (importId.trim().isEmpty) {
      throw ApiException.unknown('导入凭证为空（/api/import-lanzou）');
    }
    if (pid < 0) {
      throw ApiException.unknown('目标目录标识无效（/api/import-lanzou）');
    }
    final data = _mapOf(
      await _client.postRaw('/api/import-lanzou', body: <String, dynamic>{
        'importId': importId,
        'pid': pid,
      }),
      '/api/import-lanzou',
    );
    return RentResult.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // 下载 / 上传
  // ---------------------------------------------------------------------------

  /// 下载地址：VIP 走 302 直连蓝奏云 CDN；非 VIP 返回 Worker 代理流地址。
  Future<String> downloadUrl(String fileId) async {
    final id = _requireId(fileId, api: '/api/download');
    final response = await _client
        .getNoRedirect('/api/download', query: <String, dynamic>{'id': id});
    final location = response.headers.value('location');
    // 用当前生效的基地址（设置页可覆盖为自建 VPS），不能用编译默认值。
    final String baseUrl = _client.baseUrl;
    if (response.statusCode == 302 && location != null && location.isNotEmpty) {
      return location.startsWith('http') ? location : baseUrl + location;
    }
    // 兜底：流式代理端点（支持 Range）
    return '$baseUrl/api/stream?id=$id';
  }

  /// 上传文件（lanflare `POST /api/upload?pid=`，raw body + `X-Heri-Name` 头）。
  /// 单请求直传（仅小文件，见 [AppConfig.directUploadMaxBytes]）；进度写入本地任务模型。
  ///
  /// [taskId] 必须由 [uploadPath] 提供——只有那条链路注册了真实的
  /// CancelToken 与重发闭包，单独调用会产生「暂停点了没反应」的假能力。
  Future<CloudFile> upload({
    required String name,
    required Stream<Uint8List> bytes,
    required int length,
    required String taskId,
    required CancelToken cancelToken,
    int pid = 0,
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      final data = _mapOf(
        await _client.uploadStream(
          '/api/upload?pid=$pid',
          body: bytes,
          length: length,
          headers: <String, String>{'X-Heri-Name': Uri.encodeComponent(name)},
          cancelToken: cancelToken,
          onSendProgress: (sent, total) {
            final ratio = total <= 0 ? 0.0 : sent / total;
            LocalTransferStore.instance.updateProgress(taskId, ratio);
            onProgress?.call(sent, total);
          },
        ),
        '/api/upload',
      );
      final node = data['node'];
      if (node is! Map<String, dynamic>) {
        throw ApiException.unknown('上传响应缺少文件节点（/api/upload）');
      }
      LocalTransferStore.instance.complete(taskId);
      return _fileFromNode(node);
    } on ApiException catch (error) {
      // 用户主动暂停：store.pause 已把状态设为 paused 并取消了请求，
      // 这里不能覆盖成 failed，也不落盘。
      if (!error.isCancelled) {
        LocalTransferStore.instance
            .fail(taskId, _transferFailMessage(error, '上传'));
      }
      rethrow;
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'cloud_repository#1');
      LocalTransferStore.instance
          .fail(taskId, _transferFailMessage(error, '上传'));
      rethrow;
    }
  }

  /// 传输失败时给用户看的原因：接口错误自带可读消息，其余归为网络异常。
  static String _transferFailMessage(Object error, String action) {
    if (error is ApiException) return error.message;
    return '$action失败：网络或服务异常，请重试';
  }

  /// 在线预览：换取短期签名 URL（`GET /api/preview/url`）。
  ///
  /// 该 URL 可直接交给 Image.network / video_player，无需 Authorization 头；
  /// 15 分钟后过期，重新调用本方法即可续期。
  Future<PreviewInfo> previewInfo(String fileId) async {
    final data = _mapOf(
      await _client.getRaw(
        '/api/preview/url',
        query: <String, dynamic>{'id': _requireId(fileId, api: '/api/preview/url')},
      ),
      '/api/preview/url',
    );
    return PreviewInfo.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // PDF 内联预览（把签名 URL 的内容安全落到本地文件）
  // ---------------------------------------------------------------------------

  /// 私有临时目录（`getTemporaryDirectory` 下的 `pdf_preview/`）。
  /// 系统可在存储紧张时回收，缓存失效后自动重新下载，不影响正确性。
  static Future<String> _pdfCacheDirectory() async {
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}pdf_preview');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  /// 缓存键只由（文件 id、服务端 size_bytes）组成，**不取用户文件名**，
  /// 避免路径穿越与特殊字符；id 只保留数字。
  static String _pdfCacheName(String fileId, int sizeBytes) {
    final id = fileId.replaceAll(RegExp(r'[^0-9]'), '');
    return 'pdf_${id}_$sizeBytes.pdf';
  }

  /// 为 PDF 内联预览准备本地文件，返回可交给原生 PDFView 的路径。
  ///
  /// - 命中缓存且字节数一致时直接复用（**已看过的 PDF 断网也能打开**）；
  /// - 签名 URL 剩余不足 60 秒（或 `expires_at` 缺失）时重新签发**一次**；
  /// - 先写 `.part`、校验长度后再原子改名，中途失败不会留下「半份 PDF」
  ///   被误当成有效缓存；
  /// - 该下载只用于查看，**不写入 `LocalTransferStore`**——否则每打开一次
  ///   PDF 就会在传输页产生一条噪声记录；进度由页面内进度条展示。
  Future<String> preparePdfPreview({
    required String fileId,
    required PreviewInfo info,
    required void Function(double progress) onProgress,
    bool forceRefresh = false,
  }) async {
    if (fileId.replaceAll(RegExp(r'[^0-9]'), '').isEmpty) {
      throw ApiException.unknown('文件 ID 无效');
    }
    final String dir = await _pdfCacheDirectory();
    String cachePath =
        '$dir${Platform.pathSeparator}${_pdfCacheName(fileId, info.sizeBytes)}';
    File cache = File(cachePath);
    if (!forceRefresh && await cache.exists()) {
      final int length = await cache.length();
      if (info.sizeBytes <= 0 || length == info.sizeBytes) return cachePath;
      // 服务端记录的大小变了（文件被替换），旧缓存作废。
      await cache.delete();
    }

    // 缓存未命中才判断续签，命中缓存时零网络请求。
    PreviewInfo signed = info;
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (signed.expiresAt <= 0 || signed.expiresAt - now < 60000) {
      signed = await previewInfo(fileId);
    }
    if (signed.url.isEmpty) throw ApiException.unknown('预览地址为空');

    // 续签期间云端文件若被替换，改用新的 size_bytes 作为缓存键与校验基准，
    // 避免「下载了新内容却按旧大小校验」误报下载不完整。
    if (signed.sizeBytes != info.sizeBytes) {
      cachePath =
          '$dir${Platform.pathSeparator}${_pdfCacheName(fileId, signed.sizeBytes)}';
      cache = File(cachePath);
    }
    final int expectedSize = signed.sizeBytes;
    final String partPath = '$cachePath.part';
    final File part = File(partPath);
    if (await part.exists()) await part.delete();

    try {
      await _client.downloadCapabilityUrl(
        signed.url,
        partPath,
        onReceiveProgress: (int received, int total) {
          if (total > 0) onProgress((received / total).clamp(0.0, 1.0));
        },
      );
      final int length = await part.length();
      if (expectedSize > 0 && length != expectedSize) {
        throw ApiException.unknown(
          'PDF 下载不完整（$length / $expectedSize 字节）',
        );
      }
      if (await cache.exists()) await cache.delete();
      await part.rename(cachePath);
      return cachePath;
    } catch (error) {
      // 清理失败只上报，不覆盖真正的下载错误。
      try {
        if (await part.exists()) await part.delete();
      } catch (cleanupError, cleanupStack) {
        ErrorReporter.report(cleanupError, cleanupStack,
            context: 'cloud_repository#pdf-cache-cleanup');
      }
      rethrow;
    }
  }

  /// 「重新加载」时丢弃该文件的 PDF 缓存，强制重新签发并下载。
  Future<void> clearPdfPreviewCache({
    required String fileId,
    required int sizeBytes,
  }) async {
    final String dir = await _pdfCacheDirectory();
    final File cache = File(
      '$dir${Platform.pathSeparator}${_pdfCacheName(fileId, sizeBytes)}',
    );
    if (await cache.exists()) await cache.delete();
  }

  /// 下载文件到应用私有目录（`GET /api/stream` + Dio 直写文件），
  /// 并返回本地路径供 open_filex 打开。进度写入本地传输任务模型。
  Future<String> downloadFile({
    required String fileId,
    required String name,
    String? directory,
    String? reuseTaskId,
  }) async {
    final saveDir = directory ?? await _downloadDirectory();
    final safeName = _safeFileName(name);
    final savePath = '$saveDir${Platform.pathSeparator}$safeName';
    final String taskId = LocalTransferStore.instance.startOrReset(
      id: reuseTaskId,
      name: name,
      direction: TransferDirection.download,
      sizeLabel: '下载中',
    );
    final CancelToken token = CancelToken();
    LocalTransferStore.instance.attachRuntime(
      id: taskId,
      cancel: () {
        if (!token.isCancelled) token.cancel();
      },
      // 下载重试不需要重新选文件：fileId + name 已经足够重新发起请求。
      restart: () => _restartDownload(
        fileId: fileId,
        name: name,
        directory: directory,
        taskId: taskId,
      ),
    );
    try {
      await _client.downloadToFile(
        '/api/stream',
        savePath,
        query: <String, dynamic>{'id': _requireId(fileId, api: '/api/stream')},
        cancelToken: token,
        onReceiveProgress: (int received, int total) {
          LocalTransferStore.instance.updateProgress(
            taskId,
            total <= 0 ? 0 : received / total,
          );
        },
      );
      LocalTransferStore.instance.complete(taskId);
      return savePath;
    } on ApiException catch (error) {
      if (!error.isCancelled) {
        LocalTransferStore.instance
            .fail(taskId, _transferFailMessage(error, '下载'));
      }
      rethrow;
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'cloud_repository#2');
      LocalTransferStore.instance
          .fail(taskId, _transferFailMessage(error, '下载'));
      rethrow;
    }
  }

  /// 重试下载：重新发起一整次 `GET /api/stream`，复用同一个任务 id。
  ///
  /// 没有调用方 await（由 store.resume / retry 异步触发），异常必须在此吞掉：
  /// 状态已由 [downloadFile] 内部落地，ApiException（含取消）不再重复上报。
  Future<void> _restartDownload({
    required String fileId,
    required String name,
    required String? directory,
    required String taskId,
  }) async {
    try {
      await downloadFile(
        fileId: fileId,
        name: name,
        directory: directory,
        reuseTaskId: taskId,
      );
    } on ApiException {
      // 已处理。
    } catch (error, stack) {
      ErrorReporter.report(error, stack,
          context: 'cloud_repository#restart-download');
    }
  }

  /// 应用私有下载目录（不存在则创建）。
  static Future<String> _downloadDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}downloads');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  /// 跨平台安全文件名：替换路径分隔符与 Windows 保留字符。
  static String _safeFileName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return cleaned.isEmpty ? 'download.bin' : cleaned;
  }

  /// 从本地路径上传：≤8MB 走单请求直传，更大的文件自动分块（8MB/块），
  /// 避免大文件直传时整条连接中途断开导致整文件失败。
  ///
  /// [reuseTaskId] 由重试闭包传入，复用同一条任务记录重新从头上传。
  /// 源路径只保留在**内存中的重发闭包**里，不落盘；重启后的历史记录
  /// 无法重发（传输页只提供「移除记录」），不会造出假的重试按钮。
  Future<CloudFile> uploadPath({
    required String path,
    required String name,
    int pid = 0,
    String? reuseTaskId,
  }) async {
    final File file = File(path);
    final int length;
    try {
      length = await file.length();
    } catch (error, stack) {
      ErrorReporter.report(error, stack,
          context: 'cloud_repository#upload-source');
      throw ApiException.unknown('源文件不可读，请重新选择文件');
    }
    if (length <= 0) {
      throw ApiException.badResponse(400, '文件为空，无法上传');
    }

    final String taskId = LocalTransferStore.instance.startOrReset(
      id: reuseTaskId,
      name: name,
      direction: TransferDirection.upload,
      sizeLabel: humanSize(length),
    );
    final CancelToken token = CancelToken();
    LocalTransferStore.instance.attachRuntime(
      id: taskId,
      cancel: () {
        if (!token.isCancelled) token.cancel();
      },
      restart: () => _restartUpload(
        path: path,
        name: name,
        pid: pid,
        taskId: taskId,
      ),
    );

    if (length <= AppConfig.directUploadMaxBytes) {
      return upload(
        name: name,
        bytes: file.openRead().map((List<int> b) => Uint8List.fromList(b)),
        length: length,
        pid: pid,
        taskId: taskId,
        cancelToken: token,
      );
    }
    return _uploadChunked(
      file: file,
      name: name,
      length: length,
      pid: pid,
      taskId: taskId,
      cancelToken: token,
    );
  }

  /// 重试上传：用内存里保留的源路径重新发起一整次上传，复用同一个任务 id。
  /// 若原文件已被删除 / 移动，[uploadPath] 会抛出真实错误，任务落为 failed，
  /// 用户可改用传输页的「重新选择文件」入口。
  Future<void> _restartUpload({
    required String path,
    required String name,
    required int pid,
    required String taskId,
  }) async {
    try {
      await uploadPath(
        path: path,
        name: name,
        pid: pid,
        reuseTaskId: taskId,
      );
    } on ApiException {
      // 状态已由 upload()/ _uploadChunked() 落地；取消不当作错误。
    } catch (error, stack) {
      ErrorReporter.report(error, stack,
          context: 'cloud_repository#restart-upload');
    }
  }

  /// 分块上传（lanflare `POST /api/upload/chunk`）。
  /// 头：X-Heri-Upload-Id / Chunk-Index / Chunk-Total / File-Size / Finalize。
  /// `X-Heri-File-Size` 是真实文件总字节数，后端据此校验累计分块并写入
  /// 正确的 `size_bytes`（此前只记录最后一块大小）。
  Future<CloudFile> _uploadChunked({
    required File file,
    required String name,
    required int length,
    required int pid,
    required String taskId,
    required CancelToken cancelToken,
  }) async {
    const int chunkSize = 8 * 1024 * 1024;
    final int total = (length / chunkSize).ceil();
    // 每次重发都开一个新批次：旧批次的上传会话在取消/失败时已被 abort 清理。
    final String uploadId = DateTime.now().microsecondsSinceEpoch.toString();
    int sent = 0;
    Map<String, dynamic>? lastData;
    try {
      for (int i = 0; i < total; i++) {
        final int start = i * chunkSize;
        final int end = (start + chunkSize > length) ? length : start + chunkSize;
        final Map<String, String> headers = <String, String>{
          'X-Heri-Name': Uri.encodeComponent(name),
          'X-Heri-Upload-Id': uploadId,
          'X-Heri-Chunk-Index': '$i',
          'X-Heri-Chunk-Total': '$total',
          'X-Heri-File-Size': '$length',
          if (i == total - 1) 'X-Heri-Finalize': '1',
        };
        Future<Map<String, dynamic>> sendChunk() async => _mapOf(
              await _client.uploadStream(
                '/api/upload/chunk?pid=$pid',
                body: file
                    .openRead(start, end)
                    .map((List<int> b) => Uint8List.fromList(b)),
                length: end - start,
                headers: headers,
                cancelToken: cancelToken,
                onSendProgress: (int chunkSent, int _) {
                  final double ratio = (sent + chunkSent) / length;
                  LocalTransferStore.instance.updateProgress(
                    taskId,
                    ratio > 0.99 ? 0.99 : ratio,
                  );
                },
              ),
              '/api/upload/chunk',
            );
        Map<String, dynamic> data;
        try {
          data = await sendChunk();
        } on ApiException catch (e) {
          if (e.isCancelled) rethrow;
          // 单块抖动自动重试一次：同一 uploadId + 块序号在服务端按序号
          // 幂等覆盖，不会产生重复数据；避免整文件因一块失败从头再来。
          data = await sendChunk();
        }
        sent = end;
        lastData = data;
      }
      final Object? node = lastData?['node'];
      if (node is! Map<String, dynamic>) {
        throw ApiException.unknown('分块上传未返回文件节点，请重试');
      }
      LocalTransferStore.instance.complete(taskId);
      return _fileFromNode(node);
    } on ApiException catch (error) {
      // 暂停：请求已取消，状态由 store.pause 落地为 paused；仍要 abort，
      // 清掉云端 .chunk-<uploadId> 残留目录（后端 abort 幂等且有护栏）。
      if (!error.isCancelled) {
        LocalTransferStore.instance
            .fail(taskId, _transferFailMessage(error, '上传'));
      }
      unawaited(_abortChunkUpload(uploadId));
      rethrow;
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'cloud_repository#3');
      LocalTransferStore.instance
          .fail(taskId, _transferFailMessage(error, '上传'));
      unawaited(_abortChunkUpload(uploadId));
      rethrow;
    }
  }

  /// 分块上传失败时尽力清理云端残留的 `.chunk-<uploadId>` 目录。
  ///
  /// 不 await、不覆盖原始异常；后端 abort 是幂等的，且会保护已被文件节点
  /// 引用的目录（含回收站），所以「finalize 成功但响应丢失」时不会误删文件。
  Future<void> _abortChunkUpload(String uploadId) async {
    try {
      await _client.postRaw(
        '/api/upload/chunk/abort',
        body: <String, dynamic>{'uploadId': uploadId},
      );
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'cloud_repository#abortChunk');
    }
  }

  // ---------------------------------------------------------------------------
  // 传输任务（本地模型）
  // ---------------------------------------------------------------------------

  /// lanflare 无服务端任务列表；返回 App 本地记录的任务。
  Future<List<TransferTask>> transfers() async {
    return LocalTransferStore.instance.tasks;
  }

  // ---------------------------------------------------------------------------
  // 映射与工具
  // ---------------------------------------------------------------------------

  CloudFile _fileFromNode(Map<String, dynamic> node) {
    final name = node['name']?.toString() ?? '（未命名文件）';
    final bool isDir = node['type']?.toString() == 'dir';
    final int sizeBytes = JsonUtils.asInt(node['size_bytes']);
    return CloudFile(
      id: node['id']?.toString() ?? '',
      name: name,
      category: isDir ? FileCategory.other : FileCategoryX.fromFileName(name),
      sizeLabel: isDir ? '文件夹' : humanSize(sizeBytes),
      updatedLabel: relativeTime(JsonUtils.asInt(node['created_at'])),
      starred: false,
      sizeBytes: sizeBytes,
      createdAt: JsonUtils.asInt(node['created_at']),
      isDir: isDir,
      pid: JsonUtils.asInt(node['pid']),
    );
  }

  /// 接口响应安全解析：非 Map 时转为可展示的业务异常，避免裸 cast 崩溃。
  static Map<String, dynamic> _mapOf(Object? data, String api) {
    if (data is Map) return Map<String, dynamic>.from(data);
    throw ApiException.unknown('接口返回格式异常（$api）');
  }

  /// 可选的对象字段解析：类型不符时按缺省处理，不抛异常。
  static Map<String, dynamic>? _optionalMapOf(Object? data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  static List<Map<String, dynamic>> _itemsOf(Map<String, dynamic> data) {
    final items = data['items'];
    if (items is! List<dynamic>) return const <Map<String, dynamic>>[];
    return items.whereType<Map<String, dynamic>>().toList();
  }

  /// 单个文件 id：必须是正整数字符串，非法值直接抛异常而非静默传 0。
  static int _requireId(String id, {required String api}) {
    final parsed = int.tryParse(id.trim());
    if (parsed == null || parsed <= 0) {
      throw ApiException.unknown('文件标识无效（$api）');
    }
    return parsed;
  }

  /// 批量 id：任一非法值即中止，避免「选了 3 个只处理 2 个」的静默丢失。
  static List<int> _toIntIds(List<String> ids, {required String api}) {
    if (ids.isEmpty) return const <int>[];
    return ids.map((id) => _requireId(id, api: api)).toList();
  }

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
