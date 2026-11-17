import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

import '../../core/models/cloud_models.dart';
import '../../core/network/cloud_repository.dart';

/// 首页：容量卡片 + 快捷操作 + 最近文件。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CloudRepository _repository = CloudRepository();
  StorageSummary _summary = MockData.storageSummary;
  List<CloudFile> _recent = const <CloudFile>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final summary = await _repository.storageSummary();
      final files = await _repository.files();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _recent = files.take(3).toList();
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
    return SafeArea(
      child: RefreshIndicator(
        color: QyColors.primaryDeep,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text('轻云', style: textTheme.headlineLarge),
                ),
                IconButton(
                  onPressed: () => context.go(QyRoutes.search),
                  icon: const QyIcon(QyIcons.search, size: 22),
                ),
                IconButton(
                  onPressed: () => context.go(QyRoutes.states),
                  icon: const QyIcon(QyIcons.bell, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('上午好，今天也要轻轻存文件', style: textTheme.bodyMedium),
            const SizedBox(height: QyTokens.spaceXl),

            // 容量卡片
            QyCard(
              gradient: QyColors.primaryGradient,
              onTap: () => context.go(QyRoutes.storage),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const QyIcon(QyIcons.cloud, size: 20, color: QyColors.primaryDeep),
                      const SizedBox(width: 8),
                      Text('云端空间', style: textTheme.bodyLarge),
                      const Spacer(),
                      Text('管理', style: textTheme.labelMedium),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(_summary.label, style: textTheme.headlineMedium),
                  const SizedBox(height: 16),
                  QyProgressBar(value: _summary.ratio),
                ],
              ),
            ),
            const SizedBox(height: QyTokens.spaceXl),

            // 快捷操作
            Text('快捷操作', style: textTheme.titleLarge),
            const SizedBox(height: QyTokens.spaceMd),
            Row(
              children: <Widget>[
                _QuickAction(icon: QyIcons.upload, label: '上传', onTap: () => context.go(QyRoutes.transferFiles)),
                _QuickAction(icon: QyIcons.download, label: '下载', onTap: () => context.go(QyRoutes.transferFiles)),
                _QuickAction(icon: QyIcons.share, label: '分享', onTap: () => context.go(QyRoutes.share)),
                _QuickAction(icon: QyIcons.trash, label: '回收站', onTap: () => context.go(QyRoutes.trash)),
              ],
            ),
            const SizedBox(height: QyTokens.spaceXl),

            // 最近文件
            Row(
              children: <Widget>[
                Text('最近文件', style: textTheme.titleLarge),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go(QyRoutes.files),
                  child: const Text('全部'),
                ),
              ],
            ),
            const SizedBox(height: QyTokens.spaceSm),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator(color: QyColors.primaryDeep)),
              )
            else if (_recent.isEmpty)
              QyEmptyState(
                title: '这里还没有文件',
                description: '上传第一份文件，开始你的轻云之旅',
                actionLabel: '上传第一个文件',
                onAction: () => context.go(QyRoutes.transferFiles),
              )
            else
              ...<Widget>[
                for (final file in _recent)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: QyListTile(
                      leading: QyIcon(file.category.iconName, size: 32, color: file.category.tint),
                      title: file.name,
                      subtitle: '${file.updatedLabel} · ${file.sizeLabel}',
                      trailing: const QyIcon(QyIcons.more, size: 20, color: QyColors.muted),
                      onTap: () => context.go(QyRoutes.preview),
                    ),
                  ),
              ],
            const SizedBox(height: 96),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: QyColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: QyColors.border),
                boxShadow: <BoxShadow>[QyTokens.softShadow(QyColors.warmShadow)],
              ),
              child: IconButton(
                onPressed: onTap,
                icon: QyIcon(icon, size: 22, color: QyColors.primaryDeep),
              ),
            ),
            const SizedBox(height: 6),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}
