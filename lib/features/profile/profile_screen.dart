import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';
import '../../core/models/cloud_models.dart';
import '../../core/models/transfer_store.dart';
import '../../core/network/cloud_repository.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/error_reporter.dart';
import '../../widgets/proto_widgets.dart';

/// 04 我的（对齐 screen-mine）。
///
/// 存储 / 分享 / 回收站等数据接入 lanflare；传输任务取本地任务模型。
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final CloudRepository _repo = CloudRepository();

  late final Future<StorageSummary> _summaryFuture = _repo.storageSummary();
  late final Future<int> _shareCountFuture = _repo.shareCount();
  late final Future<int> _trashCountFuture = _repo.trashCount();

  AccountStatus? _status;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final status = await _repo.accountStatus();
      if (!mounted) return;
      setState(() => _status = status);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'profile_screen#status');
      // 加载失败时保留中性占位，不打断其它真实数据。
    }
  }

  Future<void> _logout() async {
    await _repo.logout();
    if (!mounted) return;
    context.go(AppRouter.login);
  }

  /// 打开会员管理页；返回后刷新账户状态（会员天数可能已变化）。
  Future<void> _openAdminVip() async {
    await context.push<bool>(AppRouter.adminVip);
    // 不依赖返回值：点左上角、系统返回键都刷新，避免会员状态残留旧值。
    await _loadStatus();
  }

  /// 安全中心（两步验证）；返回后刷新账户状态。
  Future<void> _openSecurity() async {
    await context.push<bool>(AppRouter.security);
    if (mounted) await _loadStatus();
  }

  /// 登录设备 / 令牌管理；返回后刷新令牌计数。
  Future<void> _openDevices() async {
    await context.push<bool>(AppRouter.devices);
    if (mounted) await _loadStatus();
  }

  /// 会员横幅「查看」：展示真实账户详情。
  void _showAccountDetail() {
    final status = _status;
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('账户与会员'),
        content: status == null
            ? const Text('账户信息加载中，请稍后重试')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('账号：${status.username}'),
                  const SizedBox(height: 6),
                  Text('角色：${status.isAdmin ? '管理员' : '普通用户'}'),
                  const SizedBox(height: 6),
                  Text('会员：${status.vipTitle}'),
                  if (status.everVip) ...<Widget>[
                    const SizedBox(height: 6),
                    Text('到期日：${status.vipExpiryLabel}'),
                  ],
                  const SizedBox(height: 6),
                  Text(
                      '存储账号：${status.storageConnected ? '已连接' : '未连接 / 连接异常'}'),
                  const SizedBox(height: 6),
                  Text('文件 ${status.fileCount} · 分享 ${status.shareCount} · '
                      '回收站 ${status.trashCount} · 令牌 ${status.tokenCount}'),
                ],
              ),
        actions: <Widget>[
          if (status?.isAdmin ?? false)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _openAdminVip();
              },
              child: const Text('管理会员'),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 红框区域（渐变个人头图 + VIP 会员横幅）固定不滚动，下方三组设置卡片
    // 与页脚单独滚动。等价原型 .me-hero / .vip-banner 的 flex-shrink:0 +
    // .scroll flex:1；固定区末尾保留 14 间距，滚动内容不会贴死横幅。
    return ColoredBox(
      color: QyColors.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _MeHero(status: _status, onSettings: _openSecurity),
          _VipBanner(status: _status, onTap: _showAccountDetail),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              physics: qyProtoScrollPhysics,
              padding: const EdgeInsets.only(bottom: 100),
              children: <Widget>[
                _MeBlock(
                  children: <Widget>[
                    _MeCell(
                      icon: Icons.pie_chart,
                      iconColor: QyColors.primary,
                      background: QyColors.primaryLight,
                      label: '存储空间',
                      value: FutureBuilder<StorageSummary>(
                        future: _summaryFuture,
                        builder: (_, snapshot) {
                          final summary = snapshot.data;
                          if (summary == null) return const Text('—', style: _cellValueStyle);
                          return Text(
                            '${summary.usedGb.toStringAsFixed(1)} / ${summary.totalGb.toStringAsFixed(0)} GB',
                            style: _cellValueStyle,
                          );
                        },
                      ),
                      onTap: () => context.go(QyRoutes.storage),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _MeBlock(
                  children: <Widget>[
                    _MeCell(
                      icon: Icons.share,
                      iconColor: QyColors.primary,
                      background: QyColors.primaryLight,
                      label: '我的分享',
                      value: _countText(_shareCountFuture, suffix: ' 个链接'),
                      onTap: () => context.go('/my-shares'),
                    ),
                    _MeCell(
                      icon: Icons.delete_outline,
                      iconColor: QyColors.pinkDeep,
                      background: QyColors.pinkSoft,
                      label: '回收站',
                      value: _countText(_trashCountFuture, suffix: ''),
                      onTap: () => context.go(QyRoutes.trash),
                    ),
                    _MeCell(
                      icon: Icons.cloud_download,
                      iconColor: QyColors.mintDeep,
                      background: QyColors.mintSoft,
                      label: '传输任务',
                      value: AnimatedBuilder(
                        animation: LocalTransferStore.instance,
                        builder: (_, __) {
                          final count = LocalTransferStore.instance.tasks.length;
                          return Text('$count 个任务', style: _cellValueStyle);
                        },
                      ),
                      onTap: () => context.go(QyRoutes.transfers),
                    ),
                    _MeCell(
                      icon: Icons.devices,
                      iconColor: QyColors.amberDeep,
                      background: QyColors.amberSoft,
                      label: '设备管理',
                      value: Text(
                        _status == null
                            ? '—'
                            : '${_status!.tokenCount} 个凭证',
                        style: _cellValueStyle,
                      ),
                      onTap: _openDevices,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _MeBlock(
                  children: <Widget>[
                    if (_status?.isAdmin ?? false)
                      _MeCell(
                        icon: Icons.admin_panel_settings,
                        iconColor: QyColors.violetDeep,
                        background: QyColors.violetSoft,
                        label: '会员管理',
                        value: const Text('仅管理员', style: _cellValueStyle),
                        onTap: _openAdminVip,
                      ),
                    _MeCell(
                      icon: Icons.verified_user,
                      iconColor: QyColors.violetDeep,
                      background: QyColors.violetSoft,
                      label: '安全中心',
                      value: const Text(
                        '两步验证 · 登录设备',
                        style: _cellValueStyle,
                      ),
                      onTap: _openSecurity,
                    ),
                    _MeCell(
                      icon: Icons.help_outline,
                      iconColor: QyColors.sub,
                      background: QyColors.canvas,
                      label: '帮助与反馈',
                      value: const Text('常见问题 · 提交反馈', style: _cellValueStyle),
                      onTap: () => context.push(AppRouter.help),
                    ),
                    _MeCell(
                      icon: Icons.settings,
                      iconColor: QyColors.sub,
                      background: QyColors.canvas,
                      label: '设置',
                      value: const Text('服务地址 · 本地数据', style: _cellValueStyle),
                      onTap: () => context.push(AppRouter.settings),
                    ),
                    _MeCell(
                      icon: Icons.logout,
                      iconColor: QyColors.coral,
                      background: QyColors.canvas,
                      label: '退出登录',
                      onTap: _logout,
                    ),
                  ],
                ),
                const ProtoFootNote(
                  '轻云 v3.2.0 · 你的文件，随时在云上',
                  padding: EdgeInsets.fromLTRB(0, 22, 0, 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 数值单元：加载中显示占位，失败显示 —。
  Widget _countText(Future<int> future, {required String suffix}) {
    return FutureBuilder<int>(
      future: future,
      builder: (_, snapshot) {
        if (!snapshot.hasData) {
          return const Text('—', style: _cellValueStyle);
        }
        return Text('${snapshot.data}$suffix', style: _cellValueStyle);
      },
    );
  }

  static const TextStyle _cellValueStyle =
      TextStyle(fontSize: 11.5, color: QyColors.muted);
}

class _MeHero extends StatelessWidget {
  const _MeHero({required this.status, required this.onSettings});

  final AccountStatus? status;

  /// 头图右上齿轮：进入安全中心（账户安全设置）。
  final VoidCallback onSettings;

  /// 数据未到 / 加载失败时用 — 占位，绝不显示编造数值。
  static String _count(int? value) => value == null ? '—' : '$value';

  @override
  Widget build(BuildContext context) {
    final s = status;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 58, 18, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-0.342, -0.94),
          end: Alignment(0.342, 0.94),
          stops: <double>[0, 0.6, 1],
          colors: <Color>[Color(0xFFE2EDFF), Color(0xFFEFF5FF), QyColors.canvas],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xD9FFFFFF), width: 3),
                  gradient: const LinearGradient(
                    begin: Alignment(-0.77, -0.64),
                    end: Alignment(0.77, 0.64),
                    colors: <Color>[Color(0xFF4C8DFF), Color(0xFF7FD9CE)],
                  ),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(color: Color(0x802F6BFF), blurRadius: 18, offset: Offset(0, 8), spreadRadius: -6),
                  ],
                ),
                child: Center(
                  child: Text(
                    s == null || s.username.isEmpty
                        ? '轻'
                        : String.fromCharCode(s.username.runes.first).toUpperCase(),
                    style: const TextStyle(
                        fontSize: 21, fontWeight: FontWeight.w600, color: QyColors.onDark),
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            s?.displayName ?? '轻云用户',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: QyColors.ink),
                          ),
                        ),
                        const SizedBox(width: 7),
                        _VipTag(label: s?.vipTagLabel ?? '未开通'),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      s == null ? '轻云号：—' : '轻云号：${s.username}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, letterSpacing: 0.2, color: QyColors.heroLabel),
                    ),
                  ],
                ),
              ),
              ProtoIconButton(
                icon: Icons.settings,
                onTap: onSettings,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Row(
              children: <Widget>[
                _MeStat(value: _count(s?.fileCount), label: '文件'),
                const SizedBox(width: 26),
                _MeStat(value: _count(s?.shareCount), label: '分享'),
                const SizedBox(width: 26),
                // 原「3 设备」是写死的假数值；lanflare 无设备表，
                // 改用真实存在的 API 令牌数，语义对应「登录凭证」。
                _MeStat(value: _count(s?.tokenCount), label: '令牌'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VipTag extends StatelessWidget {
  const _VipTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(6)),
        gradient: LinearGradient(
          begin: Alignment(-0.5, -0.87),
          end: Alignment(0.5, 0.87),
          colors: <Color>[Color(0xFFFFD37A), Color(0xFFF5A623)],
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.workspace_premium, size: 10, color: Color(0xFF7A4A00)),
          const SizedBox(width: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: Color(0xFF7A4A00))),
        ],
      ),
    );
  }
}

class _MeStat extends StatelessWidget {
  const _MeStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: QyColors.ink)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10.5, color: QyColors.heroLabel)),
      ],
    );
  }
}

class _VipBanner extends StatelessWidget {
  const _VipBanner({required this.status, required this.onTap});

  final AccountStatus? status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: QyTapScale(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(18)),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-0.88, -0.47),
                end: Alignment(0.88, 0.47),
                stops: <double>[0, 0.55, 1],
                colors: <Color>[Color(0xFF2B3244), Color(0xFF3C4761), QyColors.primary],
              ),
            ),
            child: Stack(
              children: <Widget>[
                Positioned(
                  right: -24,
                  top: -38,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: const BoxDecoration(color: Color(0x12FFFFFF), shape: BoxShape.circle),
                  ),
                ),
                Row(
                  children: <Widget>[
                    const Icon(Icons.workspace_premium, size: 26, color: Color(0xFFFFD37A)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            status?.vipTitle ?? '轻云会员',
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: QyColors.onDark),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            status?.vipSubtitle ?? '账户状态加载中',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 10.5, color: Color(0xFFB9C4DB)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                        gradient: LinearGradient(
                          begin: Alignment(-0.5, -0.87),
                          end: Alignment(0.5, 0.87),
                          colors: <Color>[Color(0xFFFFD37A), Color(0xFFF5A623)],
                        ),
                      ),
                      child: const Text('查看',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF5A3600))),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MeBlock extends StatelessWidget {
  const _MeBlock({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: QyColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _MeCell extends StatelessWidget {
  const _MeCell({
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.label,
    this.value,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color background;
  final String label;

  /// 右侧数值区：支持任意 Widget（实时数据用 FutureBuilder/AnimatedBuilder）。
  final Widget? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return QyTapScale(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: QyColors.divider)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        child: Row(
          children: <Widget>[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: background,
                borderRadius: const BorderRadius.all(Radius.circular(10)),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 13.5, color: QyColors.ink)),
            ),
            if (value != null)
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: value,
              ),
            const Icon(Icons.chevron_right, size: 18, color: QyColors.chevron),
          ],
        ),
      ),
    );
  }
}
