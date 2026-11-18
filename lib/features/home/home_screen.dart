import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

import '../../core/models/cloud_models.dart';
import '../../core/network/cloud_repository.dart';
import '../../core/router/app_router.dart';

/// 首页：功能入口 + 最近文件。
///
/// 云端空间模块已迁移至「我的」页面（用户信息下方）；
/// 原快捷操作区域移除，改为相册 / 文件 / 视频 / 同步 / 分类 五项卡片式入口。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CloudRepository _repository = CloudRepository();
  List<CloudFile> _recent = const <CloudFile>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final files = await _repository.files();
      if (!mounted) return;
      setState(() {
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
                  onPressed: () => context.push(QyRoutes.search),
                  icon: const QyIcon(QyIcons.search, size: 22),
                ),
                IconButton(
                  onPressed: () => context.push(QyRoutes.states),
                  icon: const QyIcon(QyIcons.bell, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('上午好，今天也要轻轻存文件', style: textTheme.bodyMedium),
            const SizedBox(height: QyTokens.spaceXl),

            // 卡片式功能入口：相册 / 文件 / 视频 / 同步 / 分类
            QyCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              child: Row(
                children: const <Widget>[
                  _HomeEntry(icon: QyIcons.image, label: '相册', route: AppRouter.gallery),
                  _HomeEntry(icon: QyIcons.folder, label: '文件', route: AppRouter.allFiles),
                  _HomeEntry(icon: QyIcons.video, label: '视频', route: AppRouter.videos),
                  _HomeEntry(icon: QyIcons.refresh, label: '同步', route: QyRoutes.transferFiles),
                  _HomeEntry(icon: QyIcons.grid, label: '分类', route: QyRoutes.storage),
                ],
              ),
            ),
            const SizedBox(height: QyTokens.spaceXl),

            // 最近文件
            Row(
              children: <Widget>[
                Text('最近文件', style: textTheme.titleLarge),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push(AppRouter.allFiles),
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
                onAction: () => context.push(QyRoutes.transferFiles),
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
                      onTap: () => context.push(QyRoutes.preview),
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

/// 首页功能入口：圆形图标 + 文字标签，点击 push 对应功能页（可返回）。
class _HomeEntry extends StatelessWidget {
  const _HomeEntry({required this.icon, required this.label, required this.route});

  final String icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: () => context.push(route),
        borderRadius: BorderRadius.circular(QyTokens.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: QyColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: QyColors.border),
                  boxShadow: <BoxShadow>[QyTokens.softShadow(QyColors.warmShadow)],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: QyIcon(icon, size: 22, color: QyColors.primaryDeep),
                ),
              ),
              const SizedBox(height: 6),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}
