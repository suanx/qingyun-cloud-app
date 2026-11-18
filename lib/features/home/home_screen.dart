import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

import '../../core/models/cloud_models.dart';
import '../../core/network/cloud_repository.dart';
import '../../core/router/app_router.dart';

/// 首页概览卡片数量（横向 PageView 页数，与下方指示器一一对应）。
const int _overviewCount = 3;

/// 分类胶囊对应的落地页；第 4 项「分类」为空，表示切换到文件 Tab。
/// 早期实现 push 到 `/files`，而该页没有不透明背景，转场途中会透出
/// 下层首页形成灰色浮层，现改为切 Tab，从根上消除这个叠加画面。
const List<String?> _entryRoutes = <String?>[
  AppRouter.gallery,
  AppRouter.allFiles,
  AppRouter.videos,
  null,
];

const List<String> _entryLabels = <String>['相册', '文件', '视频', '分类'];

/// 首页：品牌抬头 + 概览卡片轮播 + 分类胶囊 + 最近文件。
///
/// 纯白画布、玻璃面卡片（无真实模糊层）、横向可滑动的概览卡、扁平
/// 分隔线式最近文件列表。各区块带交错淡入上滑动画，交互统一使用
/// [QyTapScale] 的圆润按压回弹。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CloudRepository _repository = CloudRepository();
  final PageController _overviewController = PageController(viewportFraction: 0.46);

  List<CloudFile> _recent = const <CloudFile>[];
  StorageSummary _summary = MockData.storageSummary;
  int _entry = 0;
  int _overviewPage = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _overviewController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final files = await _repository.files();
      final summary = await _repository.storageSummary();
      if (!mounted) return;
      setState(() {
        _recent = files;
        _summary = summary;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _onEntrySelected(int index) {
    setState(() => _entry = index);
    final String? route = _entryRoutes[index];
    if (route == null) {
      context.go(QyRoutes.files);
      return;
    }
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: QyColors.canvas,
      child: SafeArea(
        child: RefreshIndicator(
          color: QyColors.primaryDeep,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: <Widget>[
              _Enter(
                step: 0,
                child: _Header(
                  onSearch: () => context.push(QyRoutes.search),
                  onNotice: () => context.push(QyRoutes.states),
                ),
              ),
              const SizedBox(height: 28),
              _Enter(
                step: 1,
                child: _OverviewCarousel(
                  controller: _overviewController,
                  page: _overviewPage,
                  summary: _summary,
                  onPageChanged: (int page) => setState(() => _overviewPage = page),
                ),
              ),
              const SizedBox(height: QyTokens.spaceXxl),
              _Enter(
                step: 2,
                child: _CategoryBar(selected: _entry, onSelected: _onEntrySelected),
              ),
              const SizedBox(height: QyTokens.spaceXxxl),
              _Enter(
                step: 3,
                child: _SectionHeader(
                  title: '最近文件',
                  actionLabel: '全部',
                  onAction: () => context.push(AppRouter.allFiles),
                ),
              ),
              const SizedBox(height: QyTokens.spaceMd),
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
                  for (var i = 0; i < _recent.take(2).length; i++)
                    _Enter(
                      step: 4 + i,
                      child: _RecentFileRow(file: _recent[i]),
                    ),
                ],
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}

/// 交错入场：按区块序号延迟播放淡入 + 轻微上滑，曲线柔和。
class _Enter extends StatefulWidget {
  const _Enter({required this.step, required this.child});

  final int step;
  final Widget child;

  @override
  State<_Enter> createState() => _EnterState();
}

class _EnterState extends State<_Enter> with SingleTickerProviderStateMixin {
  Timer? _timer;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: QyTokens.entranceMotion,
  );

  @override
  void initState() {
    super.initState();
    _timer = Timer(qyEntranceStep(widget.step), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}

/// 品牌抬头：大标题 + 问候语 + 两枚圆形浅底图标按钮。
class _Header extends StatelessWidget {
  const _Header({required this.onSearch, required this.onNotice});

  final VoidCallback onSearch;
  final VoidCallback onNotice;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '轻云',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.5,
                    ),
              ),
            ),
            _RoundIconButton(icon: QyIcons.search, onTap: onSearch),
            const SizedBox(width: 10),
            _RoundIconButton(icon: QyIcons.bell, onTap: onNotice),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '上午好，今天也要轻轻存文件',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                color: QyColors.sub,
                letterSpacing: 0.2,
              ),
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return QyTapScale(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
          color: QyColors.surfaceSoft,
          shape: BoxShape.circle,
        ),
        child: Center(child: QyIcon(icon, size: 21, color: QyColors.ink)),
      ),
    );
  }
}

/// 概览卡片轮播：每张卡占约 46% 屏宽，第一屏两张完整卡 + 第三张露角。
class _OverviewCarousel extends StatelessWidget {
  const _OverviewCarousel({
    required this.controller,
    required this.page,
    required this.summary,
    required this.onPageChanged,
  });

  final PageController controller;
  final int page;
  final StorageSummary summary;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SizedBox(
          height: 206,
          child: PageView(
            controller: controller,
            padEnds: false,
            onPageChanged: onPageChanged,
            children: <Widget>[
              _OverviewCard(
                onTap: () => context.push(AppRouter.gallery),
                child: const _PhotoOverview(),
              ),
              _OverviewCard(
                color: QyColors.surfaceSoft,
                onTap: () => context.push(QyRoutes.storage),
                child: _StorageOverview(summary: summary),
              ),
              _OverviewCard(
                onTap: () => context.go(QyRoutes.transfers),
                child: const _TransferOverview(),
              ),
            ],
          ),
        ),
        const SizedBox(height: QyTokens.spaceLg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (var i = 0; i < _overviewCount; i++) _PageDot(active: i == page),
          ],
        ),
      ],
    );
  }
}

/// 统一的玻璃面概览卡：大圆角 + 极淡描边 + 柔投影 + 按压回弹。
class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.child,
    required this.onTap,
    this.color = QyColors.surface,
  });

  final Widget child;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: QyTokens.spaceMd),
      child: QyTapScale(
        onTap: onTap,
        child: QyCard(
          color: color,
          padding: const EdgeInsets.all(18),
          child: child,
        ),
      ),
    );
  }
}

/// 大数字：固定高度 + scaleDown，保证「8.2」这类小数永远单行不折行。
Widget _bigNumber(String value) => SizedBox(
      height: 52,
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          softWrap: false,
          maxLines: 1,
          style: const TextStyle(
            fontSize: 52,
            height: 1,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.5,
            color: QyColors.ink,
          ),
        ),
      ),
    );

Widget _overviewTitle(BuildContext context, String label) => Text(
      label,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
    );

Widget _overviewUnit(BuildContext context, String label) => Text(
      label,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
    );

/// 最近照片卡：大数字 + 右下角海边日落缩略图。
class _PhotoOverview extends StatelessWidget {
  const _PhotoOverview();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _overviewTitle(context, '最近照片'),
        const Spacer(),
        _bigNumber(MockData.recentPhotoCount.toString()),
        const SizedBox(height: 4),
        _overviewUnit(context, '张'),
        const Spacer(),
        const Align(alignment: Alignment.bottomRight, child: _SunsetThumb(size: 64)),
      ],
    );
  }
}

/// 存储空间卡：已用容量 + 占比进度条。
class _StorageOverview extends StatelessWidget {
  const _StorageOverview({required this.summary});

  final StorageSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _overviewTitle(context, '存储空间'),
        const Spacer(),
        _bigNumber(summary.usedGb.toStringAsFixed(1)),
        const SizedBox(height: 4),
        _overviewUnit(context, 'GB 已用'),
        const Spacer(),
        QyProgressBar(value: summary.ratio),
      ],
    );
  }
}

/// 传输任务卡：进行中任务数 + 进度。
class _TransferOverview extends StatelessWidget {
  const _TransferOverview();

  @override
  Widget build(BuildContext context) {
    final int running = MockData.transfers
        .where((TransferTask task) => task.status == TransferStatus.running)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _overviewTitle(context, '传输任务'),
        const Spacer(),
        _bigNumber('$running'),
        const SizedBox(height: 4),
        _overviewUnit(context, '个进行中'),
        const Spacer(),
        const QyProgressBar(value: 0.62),
      ],
    );
  }
}

/// 设计稿「海边日落」缩略图：纯 Dart 渐变绘制，不引入图片资源。
class _SunsetThumb extends StatelessWidget {
  const _SunsetThumb({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: <Widget>[
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: <double>[0, 0.58, 1],
                    colors: <Color>[
                      Color(0xFFF6C489),
                      Color(0xFFFCE7C7),
                      Color(0xFF7FA9C4),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: size * 0.39,
              top: size * 0.28,
              child: Container(
                width: size * 0.22,
                height: size * 0.22,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF6DC),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: size * 0.42,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0x6687B2CB), Color(0xFF5A89A6)],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 轮播指示器：当前页为胶囊，其余为小圆点，宽度带动画。
class _PageDot extends StatelessWidget {
  const _PageDot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: QyTokens.mediumMotion,
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: active ? 18 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: active ? QyColors.primary : QyColors.border,
        borderRadius: const BorderRadius.all(Radius.circular(3)),
      ),
    );
  }
}

/// 分类胶囊：选中高亮块在四个槽位间滑动，右侧「已同步」状态点。
class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double slot = constraints.maxWidth / _entryLabels.length;
              return Container(
                height: 54,
                decoration: BoxDecoration(
                  border: Border.all(color: QyColors.border, width: 1),
                  borderRadius: const BorderRadius.all(Radius.circular(QyTokens.radiusPill)),
                ),
                child: Stack(
                  children: <Widget>[
                    AnimatedPositioned(
                      duration: QyTokens.mediumMotion,
                      curve: Curves.easeOutCubic,
                      left: 4 + selected * slot,
                      top: 4,
                      bottom: 4,
                      width: slot - 8,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          color: QyColors.primaryDeep,
                          borderRadius: BorderRadius.all(Radius.circular(QyTokens.radiusPill)),
                        ),
                      ),
                    ),
                    Row(
                      children: <Widget>[
                        for (var i = 0; i < _entryLabels.length; i++)
                          _CategoryChip(
                            label: _entryLabels[i],
                            icon: i == 3 ? QyIcons.list : null,
                            selected: i == selected,
                            onTap: () => onSelected(i),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(width: QyTokens.spaceMd),
        Text(
          '已同步',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(fontSize: 12),
        ),
        const SizedBox(width: 6),
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(color: QyColors.primary, shape: BoxShape.circle),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: QyTapScale(
        onTap: onTap,
        child: SizedBox(
          height: 46,
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: QyTokens.shortMotion,
              curve: Curves.easeOutCubic,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? QyColors.onDark : QyColors.sub,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    QyIcon(
                      icon!,
                      size: 15,
                      color: selected ? QyColors.onDark : QyColors.sub,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(label),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 区块标题 + 右侧文字动作。
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
        ),
        const Spacer(),
        QyTapScale(
          onTap: onAction,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              actionLabel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 14,
                    color: QyColors.primary,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 最近文件行：浅色圆角图标底 + 扁平布局 + 极淡分割线 + 按压回弹。
class _RecentFileRow extends StatelessWidget {
  const _RecentFileRow({required this.file});

  final CloudFile file;

  @override
  Widget build(BuildContext context) {
    return QyTapScale(
      onTap: () => context.push(QyRoutes.preview),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 88,
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: QyColors.surfaceSoft,
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                  ),
                  child: Center(
                    child: QyIcon(file.category.iconName, size: 24, color: file.category.tint),
                  ),
                ),
                const SizedBox(width: QyTokens.spaceLg),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${file.updatedLabel} · ${file.sizeLabel}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const QyIcon(QyIcons.more, size: 20, color: QyColors.muted),
              ],
            ),
          ),
          const Divider(color: QyColors.divider, height: 1),
        ],
      ),
    );
  }
}
