import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

import '../../core/config/app_config.dart';
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
                Text(AppConfig.versionLabel, style: textTheme.labelSmall),
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

            // 卡片式功能入口：相册 / 文件 / 视频 / 同步 / 分类（彩色图标）
            // 卡片式功能入口幻灯片：上下导航箭头 + 垂直翻页
            QyCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: _EntryCarousel(),
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

/// 首页功能入口：彩色图标 + 文字标签，点击 push 对应功能页（可返回）。
class _HomeEntry extends StatelessWidget {
  const _HomeEntry({
    required this.icon,
    required this.hue,
    required this.label,
    required this.route,
  });

  final String icon;
  final QyIconHue hue;
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
              QyTintedIcon(icon, hue: hue, size: 46),
              const SizedBox(height: 8),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}

/// 首页功能入口幻灯片：垂直翻页 + 上/下两个导航箭头。
///
/// 第一页为五大核心入口（相册/文件/视频/同步/分类）；
/// 第二页为更多已有功能入口（回收站/容量管理/搜索/消息），不新增功能。
/// 上方箭头：小尺寸，处于第一页时置灰且不可点击；
/// 下方箭头：大尺寸，处于末页时置灰且不可点击。
class _EntryCarousel extends StatefulWidget {
  const _EntryCarousel();

  @override
  State<_EntryCarousel> createState() => _EntryCarouselState();
}

class _EntryCarouselState extends State<_EntryCarousel> {
  final PageController _controller = PageController();
  int _page = 0;

  static const int _pageCount = 2;

  void _go(int delta) {
    final int target = (_page + delta).clamp(0, _pageCount - 1);
    _controller.animateToPage(
      target,
      duration: QyTokens.shortMotion,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Center(
          child: _ArrowButton(
            size: 28,
            iconSize: 16,
            up: true,
            enabled: _page > 0,
            onTap: () => _go(-1),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 88,
          child: PageView(
            controller: _controller,
            scrollDirection: Axis.vertical,
            onPageChanged: (int page) => setState(() => _page = page),
            children: const <Widget>[
              _EntryPage(entries: <_HomeEntry>[
                _HomeEntry(icon: QyIcons.image, hue: QyHues.blue, label: '相册', route: AppRouter.gallery),
                _HomeEntry(icon: QyIcons.folder, hue: QyHues.gold, label: '文件', route: AppRouter.allFiles),
                _HomeEntry(icon: QyIcons.video, hue: QyHues.purple, label: '视频', route: AppRouter.videos),
                _HomeEntry(icon: QyIcons.refresh, hue: QyHues.teal, label: '同步', route: QyRoutes.transferFiles),
                _HomeEntry(icon: QyIcons.grid, hue: QyHues.orange, label: '分类', route: QyRoutes.storage),
              ]),
              _EntryPage(entries: <_HomeEntry>[
                _HomeEntry(icon: QyIcons.trash, hue: QyHues.coral, label: '回收站', route: QyRoutes.trash),
                _HomeEntry(icon: QyIcons.chart, hue: QyHues.slate, label: '容量管理', route: QyRoutes.storage),
                _HomeEntry(icon: QyIcons.search, hue: QyHues.blue, label: '搜索', route: QyRoutes.search),
                _HomeEntry(icon: QyIcons.bell, hue: QyHues.green, label: '消息', route: QyRoutes.states),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: _ArrowButton(
            size: 46,
            iconSize: 24,
            up: false,
            enabled: _page < _pageCount - 1,
            onTap: () => _go(1),
          ),
        ),
      ],
    );
  }
}

/// 幻灯片单页：一行均分的功能入口。
class _EntryPage extends StatelessWidget {
  const _EntryPage({required this.entries});

  final List<_HomeEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Row(children: entries);
  }
}

/// 幻灯片导航箭头按钮：玻璃面圆形按钮。
///
/// [up] 为 true 时显示向上箭头（小尺寸），false 为向下箭头（大尺寸）；
/// [enabled] 为 false 时置灰且不可点击。
class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.size,
    required this.iconSize,
    required this.up,
    required this.enabled,
    required this.onTap,
  });

  final double size;
  final double iconSize;
  final bool up;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color fg = enabled ? QyColors.primary : QyColors.muted;
    // QyIcons.back 为左箭头：顺时针旋转 90° 得向上箭头，逆时针 90° 得向下箭头。
    final Widget icon = Transform.rotate(
      angle: (up ? 90 : -90) * math.pi / 180,
      child: QyIcon(QyIcons.back, size: iconSize, color: fg),
    );
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(size / 2),
      child: QyFrost(
        color: enabled ? QyColors.frost : QyColors.surfaceSoft,
        borderRadius: BorderRadius.circular(size / 2),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(child: icon),
        ),
      ),
    );
  }
}
