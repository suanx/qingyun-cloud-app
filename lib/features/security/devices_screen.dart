import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';
import '../../core/models/cloud_models.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/cloud_repository.dart';
import '../../core/network/token_store.dart';
import '../../core/utils/error_reporter.dart';
import '../../widgets/proto_widgets.dart';

/// 登录设备 / 凭证管理：`GET /api/tokens` + `POST /api/tokens` +
/// `PATCH /api/tokens/:id` + `DELETE /api/tokens/:id`。
///
/// lanflare 没有独立设备表；每次 App 登录会签发一个 `lf_` 令牌，
/// 令牌列表就是真实的登录凭证列表，吊销即让对应设备下线。
class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final CloudRepository _repo = CloudRepository();
  late Future<ApiTokenList> _future = _repo.listTokens();
  String? _busyId;

  void _reload() {
    if (!mounted) return;
    setState(() => _future = _repo.listTokens());
  }

  bool _isCurrent(ApiTokenItem item) =>
      TokenStore.tokenId != null && item.id == TokenStore.tokenId;

  Future<void> _createToken() async {
    final TextEditingController controller =
        TextEditingController(text: '我的设备');
    bool readonly = false;
    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (BuildContext dialogContext) => StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setDialogState) =>
              AlertDialog(
            title: const Text('新建访问令牌'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '用于脚本或第三方集成；明文仅显示一次，请立即复制保存。',
                  style: TextStyle(fontSize: 11.5, color: QyColors.muted),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: 40,
                  decoration: const InputDecoration(
                    labelText: '名称 / 设备备注',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('只读权限（ro）',
                      style: TextStyle(fontSize: 12.5)),
                  subtitle: const Text('不能上传、删除或改设置',
                      style: TextStyle(fontSize: 11, color: QyColors.muted)),
                  value: readonly,
                  onChanged: (bool value) =>
                      setDialogState(() => readonly = value),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(<String, dynamic>{
                  'name': controller.text.trim(),
                  'readonly': readonly,
                }),
                child: const Text('创建'),
              ),
            ],
          ),
        ),
      );
      if (result == null || !mounted) return;
      final created = await _repo.createToken(
        name: result['name']?.toString() ?? '',
        readonly: result['readonly'] == true,
      );
      if (!mounted) return;
      await _showPlainToken(created.token, created.info.name);
      _reload();
    } on ApiException catch (error) {
      if (mounted) {
        showQyToast(context, '创建失败：${error.message}', success: false);
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'devices#create');
      if (mounted) {
        showQyToast(context, '创建失败，请稍后重试', success: false);
      }
    } finally {
      controller.dispose();
    }
  }

  /// 明文令牌只在这一次展示：可选中 + 一键复制。
  Future<void> _showPlainToken(String token, String name) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('请立即保存令牌'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('「$name」的明文令牌只显示这一次，关闭后无法再次查看。',
                style: const TextStyle(fontSize: 12, color: QyColors.muted)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: QyColors.canvas,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              child: SelectableText(
                token,
                style: const TextStyle(
                    fontSize: 11.5, fontFamily: 'monospace', color: QyColors.ink),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: token));
              if (dialogContext.mounted) {
                showQyToast(dialogContext, '已复制到剪贴板', success: true);
              }
            },
            child: const Text('复制'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('我已保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _rename(ApiTokenItem item) async {
    final TextEditingController controller =
        TextEditingController(text: item.name);
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('设备备注'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: '名称',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('保存'),
            ),
          ],
        ),
      );
      if (name == null || name.isEmpty || name == item.name || !mounted) return;
      setState(() => _busyId = item.id);
      await _repo.renameToken(item.id, name);
      if (!mounted) return;
      showQyToast(context, '备注已更新', success: true);
      _reload();
    } on ApiException catch (error) {
      if (mounted) {
        showQyToast(context, '重命名失败：${error.message}', success: false);
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'devices#rename');
      if (mounted) {
        showQyToast(context, '重命名失败，请稍后重试', success: false);
      }
    } finally {
      controller.dispose();
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _revoke(ApiTokenItem item) async {
    if (_isCurrent(item)) {
      showQyToast(context, '这是当前登录凭证，请用「退出登录」吊销', success: false);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('吊销令牌'),
        content: Text(
            '确定让「${item.name}」下线吗？该凭证（${item.maskedToken}）将立即失效，且无法恢复。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认吊销'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyId = item.id);
    try {
      await _repo.revokeToken(item.id);
      if (!mounted) return;
      showQyToast(context, '已吊销，该设备已下线', success: true);
      _reload();
    } on ApiException catch (error) {
      if (mounted) {
        showQyToast(context, '吊销失败：${error.message}', success: false);
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'devices#revoke');
      if (mounted) {
        showQyToast(context, '吊销失败，请稍后重试', success: false);
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: QyColors.canvas,
      child: RefreshIndicator(
        onRefresh: () async {
          _reload();
        },
        child: ListView(
          physics: qyProtoScrollPhysics,
          padding: const EdgeInsets.only(bottom: 96),
          children: <Widget>[
            ProtoNav(
              title: '登录设备',
              subtitle: '管理登录设备与访问令牌',
              leading: ProtoIconButton(
                icon: Icons.arrow_back,
                onTap: () => context.pop(),
              ),
              actions: <Widget>[
                QyTapScale(
                  onTap: _createToken,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Text('新建令牌', style: ProtoText.sectionMore),
                  ),
                ),
              ],
            ),
            const _InfoCard(),
            FutureBuilder<ApiTokenList>(
              future: _future,
              builder: (BuildContext context, AsyncSnapshot<ApiTokenList> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: QyEmptyState(
                      icon: QyIcons.empty,
                      title: '加载失败',
                      description: '${snapshot.error}',
                      actionLabel: '重试',
                      onAction: _reload,
                    ),
                  );
                }
                final items = snapshot.data?.items ?? <ApiTokenItem>[];
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: QyEmptyState(
                      icon: QyIcons.empty,
                      title: '暂无登录凭证',
                      description: '登录后会签发一个访问令牌',
                      actionLabel: '刷新',
                      onAction: _reload,
                    ),
                  );
                }
                return Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                      child: Text('共 ${items.length} 个凭证',
                          style: const TextStyle(
                              fontSize: 11.5, color: QyColors.muted)),
                    ),
                    for (final ApiTokenItem item in items)
                      _TokenCard(
                        item: item,
                        isCurrent: _isCurrent(item),
                        busy: _busyId == item.id,
                        onRename: () => _rename(item),
                        onRevoke: () => _revoke(item),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: QyColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.devices, size: 18, color: QyColors.primary),
              SizedBox(width: 8),
              Text('登录凭证即设备',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: QyColors.ink)),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '每次在 App 登录都会生成一个登录凭证。创建时间即登录时间，最后活跃即最近使用时间；'
            '吊销后该凭证立即失效，对应设备需要重新登录。完整令牌只在创建时显示一次，请妥善保存。',
            style: TextStyle(fontSize: 11.5, color: QyColors.muted, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _TokenCard extends StatelessWidget {
  const _TokenCard({
    required this.item,
    required this.isCurrent,
    required this.busy,
    required this.onRename,
    required this.onRevoke,
  });

  final ApiTokenItem item;
  final bool isCurrent;
  final bool busy;
  final VoidCallback onRename;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final created = CloudRepository.relativeTime(item.createdAt);
    final lastUsed = item.lastUsedAt <= 0
        ? '从未使用'
        : CloudRepository.relativeTime(item.lastUsedAt);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: const BoxDecoration(
        color: QyColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: QyColors.primaryLight,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                child: const Icon(Icons.smartphone, size: 18, color: QyColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: QyColors.ink),
                          ),
                        ),
                        if (isCurrent) ...<Widget>[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: const BoxDecoration(
                              color: QyColors.mintSoft,
                              borderRadius: BorderRadius.all(Radius.circular(6)),
                            ),
                            child: const Text('当前设备',
                                style: TextStyle(
                                    fontSize: 9.5, color: QyColors.mintDeep)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.maskedToken} · ${item.scopeLabel} · 登录 $created · 活跃 $lastUsed',
                      style: const TextStyle(
                          fontSize: 10.5, color: QyColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton(
                onPressed: busy ? null : onRename,
                child: const Text('备注', style: TextStyle(fontSize: 11.5)),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: busy || isCurrent ? null : onRevoke,
                child: Text(
                  busy ? '处理中…' : '吊销',
                  style: const TextStyle(fontSize: 11.5, color: QyColors.coral),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
