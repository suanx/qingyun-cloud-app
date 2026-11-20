import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';
import '../../core/config/app_config.dart';
import '../../core/config/settings_store.dart';
import '../../core/models/transfer_store.dart';
import '../../core/network/cloud_repository.dart';
import '../../core/router/app_router.dart';
import '../../widgets/proto_widgets.dart';

/// 设置：本地数据清理、版本信息、退出登录。
///
/// 服务地址等后端配置不在 App 内展示（服务地址已内置），本页只保留
/// 与本机数据和账号直接相关的真实可操作项：
/// - 清除搜索历史 / 传输记录调用各自真实存储；
/// - 关于区显示 [AppConfig] 的版本与应用名。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final CloudRepository _repo = CloudRepository();

  int _transferCount = 0;

  @override
  void initState() {
    super.initState();
    _transferCount = LocalTransferStore.instance.tasks.length;
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
    super.dispose();
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
            subtitle: '本地数据 · 关于',
            leading: ProtoIconButton(
              icon: Icons.arrow_back,
              onTap: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(QyRoutes.profile);
                }
              },
            ),
          ),
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
          const _Card(
            child: Column(
              children: <Widget>[
                _InfoRow(label: '应用版本', value: AppConfig.versionLabel),
                _InfoRow(label: '应用名称', value: AppConfig.appName),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () => _logout(),
              icon: const Icon(Icons.logout, size: 16, color: QyColors.coral),
              label: const Text('退出登录',
                  style: TextStyle(fontSize: 12.5, color: QyColors.coral)),
            ),
          ),
          const ProtoFootNote(
            '退出后需要重新登录才能继续使用',
            padding: EdgeInsets.fromLTRB(0, 14, 0, 10),
          ),
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
