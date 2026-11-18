import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

import '../../core/config/app_config.dart';
import '../../core/models/cloud_models.dart';
import '../../core/network/cloud_repository.dart';
import '../../core/router/app_router.dart';

/// 个人中心场景。
///
/// 云端空间容量卡片自首页迁入，展示在用户信息下方。
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final CloudRepository _repository = CloudRepository();
  StorageSummary _summary = MockData.storageSummary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final summary = await _repository.storageSummary();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ColoredBox(
      color: QyColors.canvas,
      child: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('我的', style: textTheme.headlineLarge),
              const Spacer(),
              Text(AppConfig.versionLabel, style: textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: QyTokens.spaceLg),

          // 用户信息卡片
          QyCard(
            child: Row(
              children: <Widget>[
                const QyTintedIconCircle(QyIcons.user, hue: QyHues.slate, size: 52),
                const SizedBox(width: QyTokens.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('轻云用户', style: textTheme.titleLarge),
                      const SizedBox(height: 2),
                      Text('免费版 · 已陪伴你 128 天', style: textTheme.labelMedium),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.push(QyRoutes.storage),
                  child: const Text('容量管理'),
                ),
              ],
            ),
          ),
          const SizedBox(height: QyTokens.spaceMd),

          // 云端空间卡片（自首页迁入，展示在用户信息下方）
          QyCard(
            color: QyColors.surfaceSoft,
            onTap: () => context.push(QyRoutes.storage),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const QyIcon(QyIcons.cloud, size: 20, color: QyColors.primary),
                    const SizedBox(width: 8),
                    Text('云端空间', style: textTheme.bodyLarge),
                    const Spacer(),
                    Text('管理', style: textTheme.labelMedium),
                  ],
                ),
                const SizedBox(height: 10),
                Text(_loading ? '加载中…' : _summary.label, style: textTheme.headlineMedium),
                const SizedBox(height: 16),
                QyProgressBar(value: _summary.ratio),
              ],
            ),
          ),
          const SizedBox(height: QyTokens.spaceXl),

          Text('常用功能', style: textTheme.titleLarge),
          const SizedBox(height: QyTokens.spaceMd),
          QyCard(
            child: Column(
              children: <Widget>[
                _MenuRow(icon: QyIcons.play, hue: QyHues.purple, label: '功能演示（全量）', onTap: () => context.push(AppRouter.demo)),
                const Divider(color: QyColors.divider, height: 1),
                _MenuRow(icon: QyIcons.chart, hue: QyHues.blue, label: '容量管理', onTap: () => context.push(QyRoutes.storage)),
                const Divider(color: QyColors.divider, height: 1),
                _MenuRow(icon: QyIcons.trash, hue: QyHues.coral, label: '回收站', onTap: () => context.push(QyRoutes.trash)),
                const Divider(color: QyColors.divider, height: 1),
                _MenuRow(icon: QyIcons.star, hue: QyHues.gold, label: '收藏文件', onTap: () => showQyToast(context, '收藏功能开发中')),
              ],
            ),
          ),
          const SizedBox(height: QyTokens.spaceLg),
          Text('设置', style: textTheme.titleLarge),
          const SizedBox(height: QyTokens.spaceMd),
          QyCard(
            child: Column(
              children: <Widget>[
                _MenuRow(icon: QyIcons.settings, hue: QyHues.slate, label: '通用设置', onTap: () => showQyToast(context, '设置功能开发中')),
                const Divider(color: QyColors.divider, height: 1),
                _MenuRow(icon: QyIcons.lock, hue: QyHues.teal, label: '账号与安全', onTap: () => showQyToast(context, '安全中心开发中')),
                const Divider(color: QyColors.divider, height: 1),
                _MenuRow(icon: QyIcons.info, hue: QyHues.green, label: '关于轻云', onTap: () => showQyToast(context, '轻云 ${AppConfig.versionLabel}')),
              ],
            ),
          ),
          const SizedBox(height: 96),
        ],
      ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.hue,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final QyIconHue hue;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(QyTokens.radiusSm),
        child: Row(
          children: <Widget>[
            QyTintedIcon(icon, hue: hue, size: 34),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
            const QyIcon(QyIcons.back, size: 16, color: QyColors.muted),
          ],
        ),
      ),
    );
  }
}
