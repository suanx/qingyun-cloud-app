import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

import '../../core/models/cloud_models.dart';
import '../../core/network/cloud_repository.dart';
import '../../core/router/app_router.dart';

/// 首页概览卡片数量（横向 PageView 页数，与下方小圆点一一对应）。
const int _overviewCount = 3;

/// 分类胶囊对应的落地页：相册 / 文件 / 视频 / 分类。
const List<String> _entryRoutes = <String>[
  AppRouter.gallery,
  AppRouter.allFiles,
  AppRouter.videos,
  QyRoutes.files,
];

const List<String> _entryLabels = <String>['相册', '文件', '视频', '分类'];

/// 首页：品牌抬头 + 概览卡片轮播 + 分类胶囊 + 最近文件。
///
/// 对齐高保真设计稿：纯白画布、玻璃面卡片（无真实模糊层）、横向可滑动的
/// 概览卡、扁平分隔线式最近文件列表。云端空间容量同时保留在「我的」页面，
/// 此处仅作概览入口；版本指纹只在启动页与「我的」页展示。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CloudRepository _repository = CloudRepository();
  final PageController _overviewController = PageController(viewportFraction: 0.44);

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
    context.push(_entryRoutes[index]);
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
                  child: Text(
                    '轻云',
                    style: textTheme.displayLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: () => context.push(QyRoutes.search),
                  icon: const QyIcon(QyIcons.search, size: 24),
                ),
                IconButton(
                  onPressed: () => context.push(QyRoutes.states),
                  icon: const QyIcon(QyIcons.bell, size: 24),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '上午好，今天也要轻轻存文件',
              style: textTheme.bodyLarge?.copyWith(color: QyColors.sub),
            ),
            const SizedBox(height: QyTokens.spaceXxl),

            _OverviewCarousel(
              controller: _overviewController,
              page: _overviewPage,
              summary: _summary,
              onPageChanged: (int page) => setState(() => _overviewPage = page),
            ),
            const SizedBox(height: QyTokens.spaceXl),

            _CategoryBar(selected: _entry, onSelected: _onEntrySelected),
            const SizedBox(height: QyTokens.spaceXxxl),

            Row(
              children: <Widget>[
                Text('最近文件', style: textTheme.headlineMedium),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push(AppRouter.allFiles),
                  child: const Text('全部'),
                ),
              ],
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
                for (final file in _recent.take(2)) _RecentFileRow(file: file),
              ],
            const SizedBox(height: 96),
          ],
        ),
      ),
    );
  }
}

/// 概览卡片轮播：每张卡占约 44% 屏宽，第一屏呈现两张完整卡 + 第三张露角。
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
          height: 214,
          child: PageView(
            controller: controller,
            padEnds: false,
            onPageChanged: onPageChanged,
            children: <Widget>[
              const _OverviewCard(child: _PhotoOverview()),
              _OverviewCard(color: QyColors.surfaceSoft, child: _StorageOverview(summary: summary)),
              const _OverviewCard(child: _TransferOverview()),
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

/// 统一的玻璃面概览卡：圆角 20 + 细描边 + 柔投影，不含任何模糊层。
class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.child, this.color = QyColors.surface});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: QyTokens.spaceMd),
      child: QyCard(
        color: color,
        padding: const EdgeInsets.all(20),
        child: child,
      ),
    );
  }
}

/// 最近照片卡：大数字 + 右下角海边日落缩略图。
class _PhotoOverview extends StatelessWidget {
  const _PhotoOverview();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '最近照片',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        Text(
          MockData.recentPhotoCount.toString(),
          style: const TextStyle(
            fontSize: 58,
            height: 1,
            fontWeight: FontWeight.w700,
            color: QyColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text('张', style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
        const Align(alignment: Alignment.bottomRight, child: _SunsetThumb(size: 76)),
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
        Text(
          '存储空间',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        Text(
          summary.usedGb.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 58,
            height: 1,
            fontWeight: FontWeight.w700,
            color: QyColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text('GB 已用', style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
        QyProgressBar(value: summary.ratio),
      ],
    );
  }
}

/// 传输任务卡：进行中任务数 + 平均进度。
class _TransferOverview extends StatelessWidget {
  const _TransferOverview();

  @override
  Widget build(BuildContext context) {
    final running = MockData.transfers
        .where((TransferTask task) => task.status == TransferStatus.running)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '传输任务',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        Text(
          '$running',
          style: const TextStyle(
            fontSize: 58,
            height: 1,
            fontWeight: FontWeight.w700,
            color: QyColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text('个进行中', style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
        const QyProgressBar(value: 0.62),
      ],
    );
  }
}

/// 设计稿「海边日落」缩略图：纯 Dart 渐变绘制，不引入图片资源，避免打包缺资源。
class _SunsetThumb extends StatelessWidget {
  const _SunsetThumb({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(10)),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: <Widget>[
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: <double>[0, 0.58, 1],
                    colors: <Color>[
                      Color(0xFFF3B978),
                      Color(0xFFFBE3BE),
                      Color(0xFF6E9FBE),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: size * 0.38,
              top: size * 0.30,
              child: Container(
                width: size * 0.22,
                height: size * 0.22,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF4D2),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: size * 0.40,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0x667FAEC8), Color(0xFF4C7FA0)],
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

/// 轮播小圆点指示器。
class _PageDot extends StatelessWidget {
  const _PageDot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: active ? 8 : 7,
      height: active ? 8 : 7,
      decoration: BoxDecoration(
        color: active ? QyColors.primary : QyColors.border,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// 分类胶囊：描边胶囊内四个快捷入口，右侧「已同步」状态点。
class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              border: Border.all(color: QyColors.border, width: 1),
              borderRadius: const BorderRadius.all(Radius.circular(QyTokens.radiusPill)),
            ),
            child: Row(
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
          ),
        ),
        const SizedBox(width: QyTokens.spaceMd),
        Text('已同步', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(width: 6),
        Container(
          width: 8,
          height: 8,
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
    final Color fg = selected ? QyColors.onDark : QyColors.sub;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: selected ? QyColors.primaryDeep : Colors.transparent,
            borderRadius: const BorderRadius.all(Radius.circular(QyTokens.radiusPill)),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                QyIcon(icon!, size: 16, color: fg),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 最近文件行：扁平布局 + 细分割线，不使用玻璃卡片。
class _RecentFileRow extends StatelessWidget {
  const _RecentFileRow({required this.file});

  final CloudFile file;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        InkWell(
          onTap: () => context.push(QyRoutes.preview),
          child: SizedBox(
            height: 92,
            child: Row(
              children: <Widget>[
                const QyIcon(QyIcons.doc, size: 40, color: QyColors.primary),
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
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${file.updatedLabel} · ${file.sizeLabel}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const QyIcon(QyIcons.more, size: 20, color: QyColors.muted),
              ],
            ),
          ),
        ),
        const Divider(color: QyColors.divider, height: 1),
      ],
    );
  }
}
