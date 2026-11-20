import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';
import '../../core/config/app_config.dart';
import '../../core/config/settings_store.dart';
import '../../core/models/cloud_models.dart';
import '../../core/models/transfer_store.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/cloud_repository.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/error_reporter.dart';
import '../../widgets/proto_widgets.dart';

/// 设置：服务地址（自建 VPS）、连接自检、本地数据清理、版本信息。
///
/// 全部是真实可操作项：
/// - 服务地址覆盖写入 SharedPreferences 并立即同步 [ApiClient]；
/// - 「测试连接」请求公开的 `GET /api/server-info`，展示真实版本、延迟、
///   运行模式与签名密钥模式（`signing_mode`，见 docs/BACKEND.md 2.17）；
/// - 清除搜索历史 / 传输记录调用各自真实存储；
/// - 关于区显示 [AppConfig] 版本与真实 `/docs` 地址（可复制）。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final CloudRepository _repo = CloudRepository();
  final TextEditingController _urlController = TextEditingController();

  bool _loading = true;
  bool _custom = false;
  bool _testing = false;
  bool _saving = false;
  ServerInfo? _serverInfo;
  String? _testError;
  int? _latencyMs;
  int _transferCount = 0;

  @override
  void initState() {
    super.initState();
    _init();
    LocalTransferStore.instance.addListener(_onTransfersChanged);
  }

  void _onTransfersChanged() {
    if (mounted) {
      setState(() => _transferCount = LocalTransferStore.instance.tasks.length);
    }
  }

  @override
  void dispose() {
    LocalTransferStore.instance.removeListener(_onTransfersChanged);
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final String effective = await SettingsStore.effectiveBaseUrl();
    final bool custom = await SettingsStore.hasCustomBaseUrl();
    if (!mounted) return;
    setState(() {
      _urlController.text = effective;
      _custom = custom;
      _transferCount = LocalTransferStore.instance.tasks.length;
      _loading = false;
    });
  }

  /// 用公开自检端点验证地址是否真的指向 lanflare，并测量往返延迟。
  Future<void> _testConnection() async {
    if (_testing) return;
    setState(() {
      _testing = true;
      _testError = null;
    });
    final Stopwatch watch = Stopwatch()..start();
    try {
      final ServerInfo info = await _repo.serverInfo();
      watch.stop();
      if (!mounted) return;
      if (info.service != 'lanflare') {
        setState(() {
          _serverInfo = null;
          _latencyMs = null;
          _testError = '该地址返回的不是 lanflare 服务，请检查域名或反向代理';
          _testing = false;
        });
        return;
      }
      setState(() {
        _serverInfo = info;
        _latencyMs = watch.elapsedMilliseconds;
        _testError = null;
        _testing = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _serverInfo = null;
        _latencyMs = null;
        _testError = error.message;
        _testing = false;
      });
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'settings#testConnection');
      if (!mounted) return;
      setState(() {
        _serverInfo = null;
        _latencyMs = null;
        _testError = '连接失败：$error';
        _testing = false;
      });
    }
  }

  Future<void> _saveUrl() async {
    if (_saving) return;
    final String? normalized =
        SettingsStore.normalizeBaseUrl(_urlController.text);
    if (normalized == null) {
      showQyToast(context, '请输入完整的 http(s) 服务地址，且不带路径',
          success: false);
      return;
    }
    final String before = await SettingsStore.effectiveBaseUrl();
    setState(() => _saving = true);
    await SettingsStore.setApiBaseUrl(normalized);
    final bool custom = await SettingsStore.hasCustomBaseUrl();
    if (!mounted) return;
    setState(() {
      _urlController.text = normalized;
      _custom = custom;
      _saving = false;
    });
    if (before != normalized) {
      showQyToast(context, '服务地址已更新，请重新登录新服务', success: true);
    } else {
      showQyToast(context, '服务地址已保存', success: true);
    }
    // 保存后立即验证新地址，避免用户填错后到登录页才发现。
    await _testConnection();
  }

  Future<void> _resetUrl() async {
    await SettingsStore.setApiBaseUrl(null);
    if (!mounted) return;
    setState(() {
      _urlController.text = AppConfig.apiBaseUrl;
      _custom = false;
    });
    showQyToast(context, '已恢复默认服务地址', success: true);
    await _testConnection();
  }

  Future<void> _clearHistory() async {
    final bool ok = await _confirm(
      title: '清除搜索历史？',
      message: '将删除本机保存的全部搜索关键词，云端文件不受影响。',
      confirmLabel: '清除',
    );
    if (!ok || !mounted) return;
    final int count = await SettingsStore.clearSearchHistory();
    if (!mounted) return;
    showQyToast(context, '已清除 $count 条搜索历史', success: true);
  }

  Future<void> _clearTransfers() async {
    final bool ok = await _confirm(
      title: '清除传输记录？',
      message: '将清空本机保存的全部传输记录（含重启后保留的历史），云端文件与搜索历史不受影响。',
      confirmLabel: '清除',
    );
    if (!ok || !mounted) return;
    final int count = SettingsStore.clearTransfers();
    if (!mounted) return;
    _onTransfersChanged();
    showQyToast(context, '已清除 $count 条传输记录', success: true);
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _logout() async {
    await _repo.logout();
    if (!mounted) return;
    context.go(AppRouter.login);
  }

  Future<void> _copyDocs() async {
    final String url = '${ApiClient.shared.baseUrl}/docs';
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    showQyToast(context, '接口文档地址已复制', success: true);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: QyColors.canvas,
      child: ListView(
        physics: qyProtoScrollPhysics,
        padding: const EdgeInsets.only(bottom: 30),
        children: <Widget>[
          ProtoNav(
            title: '设置',
            subtitle: '服务地址 · 本地数据 · 关于',
            leading: ProtoIconButton(
              icon: Icons.arrow_back,
              onTap: () => context.pop(),
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...<Widget>[
            const _SectionTitle('服务地址'),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.dns_outlined,
                          size: 18, color: QyColors.primary),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('后端服务',
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: QyColors.ink)),
                      ),
                      if (_custom)
                        const _Badge(text: '自定义')
                      else
                        const _Badge(text: '默认'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '部署到自己的 VPS 时填写完整域名（https:// 开头，不带路径）。'
                    '修改后立即生效，但新服务需要重新登录。',
                    style: TextStyle(fontSize: 11, color: QyColors.muted),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _urlController,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: '服务地址',
                      hintText: 'https://your-domain.example',
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 12.5, color: QyColors.ink),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      ElevatedButton.icon(
                        onPressed: _saving ? null : () => _saveUrl(),
                        icon: const Icon(Icons.save_outlined, size: 16),
                        label: Text(_saving ? '保存中…' : '保存'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _testing ? null : () => _testConnection(),
                        icon: const Icon(Icons.network_check, size: 16),
                        label: Text(_testing ? '检测中…' : '测试连接'),
                      ),
                      TextButton.icon(
                        onPressed: _saving ? null : () => _resetUrl(),
                        icon: const Icon(Icons.restore, size: 16),
                        label: const Text('恢复默认'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ConnectionResult(
                    testing: _testing,
                    info: _serverInfo,
                    error: _testError,
                    latencyMs: _latencyMs,
                    onRetry: () => _testConnection(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _SectionTitle('本地数据'),
            _Card(
              child: Column(
                children: <Widget>[
                  _ActionRow(
                    icon: Icons.history,
                    title: '清除搜索历史',
                    subtitle: '删除本机保存的搜索关键词',
                    onTap: () => _clearHistory(),
                  ),
                  const Divider(height: 1),
                  _ActionRow(
                    icon: Icons.swap_vert,
                    title: '清除传输记录',
                    subtitle: '当前 $_transferCount 条任务记录',
                    onTap: () => _clearTransfers(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _SectionTitle('关于'),
            _Card(
              child: Column(
                children: <Widget>[
                  const _InfoRow(label: '应用版本', value: AppConfig.versionLabel),
                  const _InfoRow(label: '应用名称', value: AppConfig.appName),
                  _InfoRow(
                    label: '后端版本',
                    value: _serverInfo == null
                        ? '未检测'
                        : (_serverInfo!.version.isEmpty
                            ? '—'
                            : _serverInfo!.version),
                  ),
                  _InfoRow(
                    label: '服务地址',
                    value: ApiClient.shared.baseUrl,
                  ),
                  const Divider(height: 1),
                  _ActionRow(
                    icon: Icons.description_outlined,
                    title: '复制接口文档地址',
                    subtitle: '${ApiClient.shared.baseUrl}/docs',
                    onTap: () => _copyDocs(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: () => _logout(),
                icon: const Icon(Icons.logout, size: 16, color: QyColors.coral),
                label: const Text('退出登录并切换服务',
                    style: TextStyle(fontSize: 12.5, color: QyColors.coral)),
              ),
            ),
            const ProtoFootNote(
              '切换服务地址后，原服务的登录凭证在新服务上不可用',
              padding: EdgeInsets.fromLTRB(0, 14, 0, 10),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 12.5, fontWeight: FontWeight.w500, color: QyColors.heroLabel),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(15),
      decoration: const BoxDecoration(
        color: QyColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: child,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: const BoxDecoration(
        color: QyColors.primaryLight,
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      child: Text(text,
          style: const TextStyle(fontSize: 10, color: QyColors.primary)),
    );
  }
}

class _ConnectionResult extends StatelessWidget {
  const _ConnectionResult({
    required this.testing,
    required this.info,
    required this.error,
    required this.latencyMs,
    required this.onRetry,
  });

  final bool testing;
  final ServerInfo? info;
  final String? error;
  final int? latencyMs;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (testing) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: <Widget>[
            SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 10),
            Text('正在连接服务…',
                style: TextStyle(fontSize: 11.5, color: QyColors.muted)),
          ],
        ),
      );
    }
    if (error != null) {
      return Container(
        padding: const EdgeInsets.all(11),
        decoration: const BoxDecoration(
          color: QyColors.pinkSoft,
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('连接失败',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: QyColors.coral)),
            const SizedBox(height: 4),
            Text(error!,
                style: const TextStyle(fontSize: 11, color: QyColors.ink)),
            const SizedBox(height: 6),
            QyTapScale(
              onTap: onRetry,
              child: const Text('重新检测',
                  style: TextStyle(fontSize: 11, color: QyColors.primary)),
            ),
          ],
        ),
      );
    }
    if (info == null) {
      return const Text('尚未检测，点击「测试连接」查看服务端真实信息',
          style: TextStyle(fontSize: 11, color: QyColors.muted));
    }
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: const BoxDecoration(
        color: QyColors.mintSoft,
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.check_circle_outline,
                  size: 15, color: QyColors.mintDeep),
              const SizedBox(width: 6),
              const Text('连接正常',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: QyColors.mintDeep)),
              const Spacer(),
              Text('${latencyMs ?? 0} ms',
                  style: const TextStyle(fontSize: 11, color: QyColors.muted)),
            ],
          ),
          const SizedBox(height: 8),
          _ResultLine(label: '运行模式', value: info!.runtimeLabel),
          _ResultLine(label: '服务端版本', value: info!.version),
          _ResultLine(label: '数据库结构', value: 'v${info!.schemaVersion}'),
          _ResultLine(label: '服务端时间', value: info!.serverTimeLabel),
          _ResultLine(label: '单请求上限', value: info!.maxUploadLabel),
          _ResultLine(
            label: '容量配额',
            value: info!.storageTotalConfigured ? '已配置' : '未配置（用默认值）',
          ),
          // 第 18 步：`GET /api/server-info` 的 signing_mode 真实状态。
          // dedicated 用安全色、legacy 用警示色；旧版服务端未返回时如实显示
          // 「未知」，不猜测成 legacy。
          _ResultLine(
            label: '签名密钥',
            value: info!.signingModeLabel,
            valueColor: info!.isSigningDedicated
                ? QyColors.mintDeep
                : (info!.isSigningLegacy ? QyColors.coral : QyColors.muted),
          ),
          if (info!.isSigningLegacy)
            const Padding(
              padding: EdgeInsets.only(left: 78, bottom: 3),
              child: Text(
                '建议在服务端配置 APP_SIGNING_KEY 后重启（切换会使网页端需重新登录）',
                style: TextStyle(fontSize: 10, color: QyColors.coral),
              ),
            ),
          _ResultLine(
              label: '已启用能力', value: '${info!.features.length} 项'),
        ],
      ),
    );
  }
}

class _ResultLine extends StatelessWidget {
  const _ResultLine({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 78,
            child: Text(label,
                style: const TextStyle(fontSize: 10.5, color: QyColors.muted)),
          ),
          Expanded(
            child: Text(value.isEmpty ? '—' : value,
                style: TextStyle(
                    fontSize: 10.5, color: valueColor ?? QyColors.ink)),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 76,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: QyColors.muted)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 12, color: QyColors.ink)),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return QyTapScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 19, color: QyColors.primary),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title,
                      style: const TextStyle(
                          fontSize: 12.5, color: QyColors.ink)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10.5, color: QyColors.muted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 17, color: QyColors.chevron),
          ],
        ),
      ),
    );
  }
}
