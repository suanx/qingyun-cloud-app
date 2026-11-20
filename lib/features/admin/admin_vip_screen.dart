import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';
import '../../core/models/cloud_models.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/cloud_repository.dart';
import '../../core/utils/error_reporter.dart';
import '../../widgets/proto_widgets.dart';

/// 会员管理（仅 admin）：`GET /api/admin/users` +
/// `POST /api/admin/users/:id/vip`。
///
/// 不接支付渠道，由 VPS 管理员在 App 内直接设置会员天数；
/// days=0 取消会员，正数从 max(now, 现有到期) 累加。
class AdminVipScreen extends StatefulWidget {
  const AdminVipScreen({super.key});

  @override
  State<AdminVipScreen> createState() => _AdminVipScreenState();
}

enum _Permission { checking, granted, denied }

class _AdminVipScreenState extends State<AdminVipScreen> {
  final CloudRepository _repo = CloudRepository();
  _Permission _permission = _Permission.checking;
  Future<AdminUserList>? _future;
  int? _busyUserId;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  /// 先确认当前账号是 admin：后端 requireAdmin 是最终防线，前端这里
  /// 只是避免普通用户点进来看到一个 403 空列表。
  Future<void> _checkPermission() async {
    try {
      final status = await _repo.accountStatus();
      if (!mounted) return;
      if (!status.isAdmin) {
        setState(() => _permission = _Permission.denied);
        return;
      }
      setState(() {
        _permission = _Permission.granted;
        _future = _repo.adminUsers();
      });
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'admin_vip#permission');
      if (!mounted) return;
      setState(() => _permission = _Permission.denied);
    }
  }

  void _reload() {
    if (!mounted) return;
    setState(() => _future = _repo.adminUsers());
  }

  Future<String?> _promptDays(AdminUser user) async {
    final TextEditingController controller = TextEditingController(text: '30');
    try {
      return await showDialog<String>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text('为 ${user.username} 设置会员'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('当前状态：${user.vipInfo.statusLabel}',
                  style: const TextStyle(fontSize: 12, color: QyColors.muted)),
              const SizedBox(height: 4),
              const Text('天数为累加（在现有到期时间上增加），范围 1 ~ 3650。',
                  style: TextStyle(fontSize: 11.5, color: QyColors.muted)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '会员天数',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  for (final int days in const <int>[30, 90, 180, 365, 730])
                    ActionChip(
                      label: Text('$days 天', style: const TextStyle(fontSize: 11)),
                      onPressed: () => controller.text = '$days',
                    ),
                ],
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('确认'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _apply(AdminUser user, int days) async {
    if (_busyUserId != null) return;
    setState(() => _busyUserId = user.id);
    try {
      final result = await _repo.setUserVipDays(user.id, days);
      if (!mounted) return;
      showQyToast(context, result.message, success: true);
      _reload();
    } on ApiException catch (error) {
      if (mounted) {
        showQyToast(context, '设置失败：${error.message}', success: false);
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'admin_vip#apply');
      if (mounted) {
        showQyToast(context, '设置失败，请稍后重试', success: false);
      }
    } finally {
      if (mounted) setState(() => _busyUserId = null);
    }
  }

  Future<void> _setDays(AdminUser user) async {
    final raw = await _promptDays(user);
    if (raw == null || !mounted) return;
    final days = int.tryParse(raw);
    if (days == null || days < 1 || days > 3650) {
      showQyToast(context, '请输入 1 ~ 3650 的整数', success: false);
      return;
    }
    await _apply(user, days);
  }

  Future<void> _cancelVip(AdminUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('取消会员'),
        content: Text('确定取消 ${user.username} 的会员资格吗？可再次设置天数恢复。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('返回'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认取消'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _apply(user, 0);
  }

  @override
  Widget build(BuildContext context) {
    if (_permission == _Permission.checking) {
      return const ColoredBox(
        color: QyColors.canvas,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_permission == _Permission.denied) {
      return ColoredBox(
        color: QyColors.canvas,
        child: ListView(
          physics: qyProtoScrollPhysics,
          children: <Widget>[
            _nav(context),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: QyEmptyState(
                icon: QyIcons.empty,
                title: '仅管理员可用',
                description: '当前账号不是管理员，无法设置会员天数',
              ),
            ),
          ],
        ),
      );
    }
    return ColoredBox(
      color: QyColors.canvas,
      child: RefreshIndicator(
        onRefresh: () async {
          _reload();
        },
        child: ListView(
          physics: qyProtoScrollPhysics,
          padding: const EdgeInsets.only(bottom: 26),
          children: <Widget>[
            _nav(context),
            const _HintCard(),
            FutureBuilder<AdminUserList>(
              future: _future,
              builder: (BuildContext context, AsyncSnapshot<AdminUserList> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 50),
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
                final list = snapshot.data;
                final users = list?.items ?? <AdminUser>[];
                if (users.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: QyEmptyState(
                      icon: QyIcons.empty,
                      title: '暂无用户',
                      description: '在网页端或注册页创建用户后即可在此设置会员',
                    ),
                  );
                }
                return Column(
                  children: <Widget>[
                    for (final AdminUser user in users)
                      _UserCard(
                        user: user,
                        isMe: user.id == list?.currentUid,
                        busy: _busyUserId == user.id,
                        onSetDays: () => _setDays(user),
                        onCancel: () => _cancelVip(user),
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

  Widget _nav(BuildContext context) => ProtoNav(
        title: '会员管理',
        subtitle: '仅管理员可见',
        leading: ProtoIconButton(
          icon: Icons.arrow_back,
          onTap: () => context.pop(true),
        ),
      );
}

class _HintCard extends StatelessWidget {
  const _HintCard();

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
              Icon(Icons.admin_panel_settings, size: 18, color: QyColors.primary),
              SizedBox(width: 8),
              Text('管理员设置会员',
                  style: TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600, color: QyColors.ink)),
            ],
          ),
          SizedBox(height: 8),
          Text('管理员可直接为用户设置会员天数（不经过支付）；'
              '正数在现有到期时间上累加，取消会员后可以随时重新设置。',
              style: TextStyle(fontSize: 11.5, color: QyColors.muted, height: 1.5)),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.isMe,
    required this.busy,
    required this.onSetDays,
    required this.onCancel,
  });

  final AdminUser user;
  final bool isMe;
  final bool busy;
  final VoidCallback onSetDays;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final vip = user.vipInfo;
    final initial = user.username.isEmpty
        ? '?'
        : String.fromCharCode(user.username.runes.first).toUpperCase();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: const BoxDecoration(
        color: QyColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 18,
                backgroundColor: QyColors.primaryLight,
                child: Text(initial,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: QyColors.primary)),
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
                            user.username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: QyColors.ink),
                          ),
                        ),
                        if (isMe) ...<Widget>[
                          const SizedBox(width: 6),
                          const Text('（我）',
                              style: TextStyle(fontSize: 10.5, color: QyColors.muted)),
                        ],
                        const SizedBox(width: 6),
                        Text(user.roleLabel,
                            style: const TextStyle(fontSize: 10.5, color: QyColors.muted)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '会员：${vip.statusLabel} · 文件 ${user.files}'
                      '${user.disabled ? ' · 已禁用' : ''}',
                      style: const TextStyle(fontSize: 11, color: QyColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              if (vip.everVip)
                TextButton(
                  onPressed: busy ? null : onCancel,
                  child: const Text('取消会员',
                      style: TextStyle(fontSize: 11.5, color: QyColors.coral)),
                ),
              const SizedBox(width: 6),
              QyTapScale(
                onTap: busy ? () {} : onSetDays,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    gradient: LinearGradient(
                      begin: Alignment(-0.5, -0.87),
                      end: Alignment(0.5, 0.87),
                      colors: <Color>[Color(0xFF3C7CFF), QyColors.primary],
                    ),
                  ),
                  child: Text(
                    busy ? '处理中…' : (vip.everVip ? '续期 / 加天数' : '设置天数'),
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: QyColors.onDark),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
