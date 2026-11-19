import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

import '../../core/models/cloud_models.dart';
import '../../core/models/transfer_store.dart';
import '../../core/network/cloud_repository.dart';
import '../../core/router/app_router.dart';
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

  Future<void> _logout() async {
    await _repo.logout();
    if (!mounted) return;
    context.go(AppRouter.login);
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
          const _MeHero(),
          _VipBanner(onTap: () => showQyToast(context, '轻云会员：2TB 空间 / 极速传输')),
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
                      value: const Text('1 台', style: _cellValueStyle),
                      onTap: () => showQyToast(context, '设备管理：当前设备在线'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _MeBlock(
                  children: <Widget>[
                    _MeCell(
                      icon: Icons.verified_user,
                      iconColor: QyColors.violetDeep,
                      background: QyColors.violetSoft,
                      label: '安全中心',
                      onTap: () => showQyToast(context, '安全中心'),
                    ),
                    _MeCell(
                      icon: Icons.help_outline,
                      iconColor: QyColors.sub,
                      background: QyColors.canvas,
                      label: '帮助与反馈',
                      onTap: () => showQyToast(context, '帮助与反馈'),
                    ),
                    _MeCell(
                      icon: Icons.settings,
                      iconColor: QyColors.sub,
                      background: QyColors.canvas,
                      label: '设置',
                      onTap: () => showQyToast(context, '设置'),
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
  const _MeHero();

  @override
  Widget build(BuildContext context) {
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
                child: const Center(
                  child: Text(
                    '轻',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600, color: QyColors.onDark),
                  ),
                ),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text('林小轻',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: QyColors.ink)),
                        SizedBox(width: 7),
                        _VipTag(),
                      ],
                    ),
                    SizedBox(height: 5),
                    Text('轻云号：qingyun_88',
                        style: TextStyle(fontSize: 11, letterSpacing: 0.2, color: QyColors.heroLabel)),
                  ],
                ),
              ),
              ProtoIconButton(
                icon: Icons.settings,
                onTap: () => showQyToast(context, '设置'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.only(left: 2),
            child: Row(
              children: <Widget>[
                _MeStat(value: '1,284', label: '文件'),
                SizedBox(width: 26),
                _MeStat(value: '6', label: '分享'),
                SizedBox(width: 26),
                _MeStat(value: '3', label: '设备'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VipTag extends StatelessWidget {
  const _VipTag();

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
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.workspace_premium, size: 10, color: Color(0xFF7A4A00)),
          SizedBox(width: 2),
          Text('VIP',
              style: TextStyle(
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
  const _VipBanner({required this.onTap});

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
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('轻云会员 · 剩余 286 天',
                              style: TextStyle(
                                  fontSize: 13.5, fontWeight: FontWeight.w600, color: QyColors.onDark)),
                          SizedBox(height: 3),
                          Text('2TB 空间 · 不限速 · 30 天回收站',
                              style: TextStyle(fontSize: 10.5, color: Color(0xFFB9C4DB))),
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
                      child: const Text('续费',
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
