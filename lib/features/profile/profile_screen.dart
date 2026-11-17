import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

/// 个人中心场景。
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: <Widget>[
          Text('我的', style: textTheme.headlineLarge),
          const SizedBox(height: QyTokens.spaceLg),
          QyCard(
            gradient: QyColors.primaryGradient,
            child: Row(
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: QyColors.surface,
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[QyTokens.softShadow(QyColors.warmShadow)],
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: QyIcon(QyIcons.user, size: 28, color: QyColors.primaryDeep),
                  ),
                ),
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
                  onPressed: () => context.go(QyRoutes.storage),
                  child: const Text('容量管理'),
                ),
              ],
            ),
          ),
          const SizedBox(height: QyTokens.spaceXl),
          Text('常用功能', style: textTheme.titleLarge),
          const SizedBox(height: QyTokens.spaceMd),
          QyCard(
            child: Column(
              children: <Widget>[
                _MenuRow(icon: QyIcons.chart, label: '容量管理', onTap: () => context.go(QyRoutes.storage)),
                const Divider(color: QyColors.divider, height: 1),
                _MenuRow(icon: QyIcons.trash, label: '回收站', onTap: () => context.go(QyRoutes.trash)),
                const Divider(color: QyColors.divider, height: 1),
                _MenuRow(icon: QyIcons.star, label: '收藏文件', onTap: () => showQyToast(context, '收藏功能开发中')),
              ],
            ),
          ),
          const SizedBox(height: QyTokens.spaceLg),
          Text('设置', style: textTheme.titleLarge),
          const SizedBox(height: QyTokens.spaceMd),
          QyCard(
            child: Column(
              children: <Widget>[
                _MenuRow(icon: QyIcons.settings, label: '通用设置', onTap: () => showQyToast(context, '设置功能开发中')),
                const Divider(color: QyColors.divider, height: 1),
                _MenuRow(icon: QyIcons.lock, label: '账号与安全', onTap: () => showQyToast(context, '安全中心开发中')),
                const Divider(color: QyColors.divider, height: 1),
                _MenuRow(icon: QyIcons.info, label: '关于轻云', onTap: () => showQyToast(context, '轻云 v0.1.0')),
              ],
            ),
          ),
          const SizedBox(height: 96),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, required this.onTap});

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(QyTokens.radiusSm),
        child: Row(
          children: <Widget>[
            QyIcon(icon, size: 20, color: QyColors.primaryDeep),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
            const QyIcon(QyIcons.back, size: 16, color: QyColors.muted),
          ],
        ),
      ),
    );
  }
}
