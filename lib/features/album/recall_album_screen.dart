import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';
import '../../core/models/cloud_models.dart';
import '../../core/network/cloud_repository.dart';
import '../../core/utils/error_reporter.dart';
import '../../widgets/proto_widgets.dart';

/// 我的照片回忆 · 真实照片轮播（方案 A）。
///
/// 数据来自 `GET /api/recall/album`：按真实上传日期分组的本人活跃图片，
/// 每张带后端签发的 15 分钟预览 URL。
///
/// **零新增依赖**：PageView + Timer + Image.network 全部是 Flutter SDK 自带；
/// **不生成视频**：只播放真实照片，无媒体编码依赖。
/// 预览 URL 过期前 60 秒静默续签，且只在服务端返回新的过期时间才继续
/// 调度，避免时钟异常时的请求放大。
class RecallAlbumScreen extends StatefulWidget {
  const RecallAlbumScreen({super.key});

  @override
  State<RecallAlbumScreen> createState() => _RecallAlbumScreenState();
}

class _RecallAlbumScreenState extends State<RecallAlbumScreen> {
  final CloudRepository _repo = CloudRepository();

  static const Duration _slideInterval = Duration(seconds: 4);
  static const int _refreshLeadMs = 60 * 1000;
  static const int _minRefreshDelayMs = 30 * 1000;

  RecallAlbum? _album;
  bool _loading = true;
  bool _failed = false;
  bool _playing = true;

  int _groupIndex = 0;
  int _photoIndex = 0;
  PageController? _pageController;
  Timer? _slideshow;
  Timer? _refresh;
  int _lastScheduledExp = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _slideshow?.cancel();
    _refresh?.cancel();
    _pageController?.dispose();
    super.dispose();
  }

  static int _clamp(int value, int low, int high) =>
      value < low ? low : (value > high ? high : value);

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _failed = false;
      });
    }
    try {
      final RecallAlbum album = await _repo.recallAlbum();
      if (!mounted) return;
      if (silent) {
        // 续签不改变结构：保持当前组 / 张与 PageController，只做边界兜底，
        // 这样 URL 换新但播放不跳帧。分组与顺序在两次调用间是稳定的。
        final List<RecallAlbumGroup> groups = album.groups;
        if (groups.isEmpty) {
          _groupIndex = 0;
          _photoIndex = 0;
        } else {
          _groupIndex = _clamp(_groupIndex, 0, groups.length - 1);
          final int count = groups[_groupIndex].photos.length;
          _photoIndex = count > 0 ? _clamp(_photoIndex, 0, count - 1) : 0;
        }
      } else {
        _groupIndex = 0;
        _photoIndex = 0;
      }
      setState(() {
        _album = album;
        _loading = false;
        _failed = false;
      });
      if (!silent) {
        _resetController();
        _restartSlideshow();
      }
      _scheduleRefresh();
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'recall_album#load');
      if (!mounted) return;
      if (silent) {
        // 静默续签失败：保留旧签名 URL 继续播放，稍后再试，不打断轮播。
        _scheduleRefresh();
        return;
      }
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _resetController() {
    final RecallAlbum? album = _album;
    final int count = (album != null && album.groups.isNotEmpty)
        ? album.groups[_clamp(_groupIndex, 0, album.groups.length - 1)]
            .photos
            .length
        : 0;
    _photoIndex = count > 0 ? _clamp(_photoIndex, 0, count - 1) : 0;
    _pageController?.dispose();
    _pageController = count > 0 ? PageController(initialPage: _photoIndex) : null;
  }

  void _restartSlideshow() {
    _slideshow?.cancel();
    final RecallAlbum? album = _album;
    if (!mounted || !_playing || album == null || !album.hasPhotos) return;
    _slideshow = Timer.periodic(_slideInterval, (_) => _next());
  }

  void _scheduleRefresh() {
    _refresh?.cancel();
    final int exp = _album?.previewExpiresAt ?? 0;
    // 服务端未给出新的过期时间（时钟异常或响应异常）时停止自动轮询，
    // 避免每 30 秒无限续签造成请求放大。
    if (exp <= 0 || exp == _lastScheduledExp) return;
    _lastScheduledExp = exp;
    final int delta =
        exp - DateTime.now().millisecondsSinceEpoch - _refreshLeadMs;
    final int delay =
        delta < _minRefreshDelayMs ? _minRefreshDelayMs : delta;
    _refresh = Timer(Duration(milliseconds: delay), () => _load(silent: true));
  }

  void _next() {
    if (!mounted || !_playing) return;
    final RecallAlbum? album = _album;
    if (album == null || album.groups.isEmpty) return;
    final RecallAlbumGroup group =
        album.groups[_clamp(_groupIndex, 0, album.groups.length - 1)];
    if (group.photos.isEmpty) return;
    if (_photoIndex + 1 < group.photos.length) {
      _pageController?.animateToPage(
        _photoIndex + 1,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    } else {
      _switchGroup((_groupIndex + 1) % album.groups.length);
    }
  }

  void _prev() {
    final RecallAlbum? album = _album;
    if (album == null || album.groups.isEmpty) return;
    if (_photoIndex > 0) {
      _pageController?.animateToPage(
        _photoIndex - 1,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    } else {
      _switchGroup(
        (_groupIndex - 1 + album.groups.length) % album.groups.length,
        last: true,
      );
    }
  }

  void _switchGroup(int index, {bool last = false}) {
    final RecallAlbum? album = _album;
    if (album == null || album.groups.isEmpty) return;
    final int gi = _clamp(index, 0, album.groups.length - 1);
    final int count = album.groups[gi].photos.length;
    if (count == 0) return;
    setState(() {
      _groupIndex = gi;
      _photoIndex = last ? count - 1 : 0;
    });
    _resetController();
    _restartSlideshow();
  }

  void _togglePlay() {
    setState(() => _playing = !_playing);
    _restartSlideshow();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: QyColors.canvas,
      child: ListView(
        physics: qyProtoScrollPhysics,
        padding: const EdgeInsets.only(bottom: 26),
        children: <Widget>[
          ProtoNav(
            title: '照片回忆',
            subtitle: '按上传日期整理 · 真实云端照片',
            leading: ProtoIconButton(
              icon: Icons.arrow_back,
              onTap: () {
                context.pop();
              },
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_failed)
            _StatusCard(
              title: '回忆暂时无法加载',
              description: '请检查服务连接后重试',
              actionLabel: '重新加载',
              onAction: () => _load(),
            )
          else if (_album == null || !_album!.hasPhotos)
            const QyEmptyState(
              icon: QyIcons.image,
              title: '还没有云端照片',
              description: '上传图片后会在这里生成回忆',
            )
          else
            _Player(
              album: _album!,
              groupIndex: _clamp(_groupIndex, 0, _album!.groups.length - 1),
              photoIndex: _photoIndex,
              playing: _playing,
              controller: _pageController,
              onGroupSelected: (int i) => _switchGroup(i),
              onPageChanged: (int i) {
                _photoIndex = i;
                _restartSlideshow();
                setState(() {});
              },
              onPrev: () => _prev(),
              onNext: () => _next(),
              onTogglePlay: () => _togglePlay(),
            ),
        ],
      ),
    );
  }
}

/// 轮播主体：日期胶囊 + 真实大图 + 真实信息 + 控制条。
class _Player extends StatelessWidget {
  const _Player({
    required this.album,
    required this.groupIndex,
    required this.photoIndex,
    required this.playing,
    required this.controller,
    required this.onGroupSelected,
    required this.onPageChanged,
    required this.onPrev,
    required this.onNext,
    required this.onTogglePlay,
  });

  final RecallAlbum album;
  final int groupIndex;
  final int photoIndex;
  final bool playing;
  final PageController? controller;
  final ValueChanged<int> onGroupSelected;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onTogglePlay;

  @override
  Widget build(BuildContext context) {
    final RecallAlbumGroup group = album.groups[groupIndex];
    final int count = group.photos.length;
    final int current = count > 0
        ? (photoIndex < 0 ? 0 : (photoIndex >= count ? count - 1 : photoIndex))
        : 0;
    final RecallPhoto? photo = count > 0 ? group.photos[current] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 设计稿约束：横滑行一律 SingleChildScrollView + Row。
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: <Widget>[
              for (int i = 0; i < album.groups.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: 8),
                _DayChip(
                  label: album.groups[i].title,
                  count: album.groups[i].count,
                  selected: i == groupIndex,
                  onTap: () => onGroupSelected(i),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          height: 320,
          decoration: BoxDecoration(
            color: QyColors.sky,
            borderRadius: const BorderRadius.all(Radius.circular(18)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                  color: Color(0x1A2F6BFF),
                  blurRadius: 22,
                  offset: Offset(0, 10),
                  spreadRadius: -8),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(18)),
            child: count == 0
                ? const _SlideFallback()
                : PageView.builder(
                    key: ValueKey<int>(groupIndex),
                    controller: controller,
                    onPageChanged: onPageChanged,
                    itemCount: count,
                    itemBuilder: (BuildContext _, int i) {
                      final RecallPhoto item = group.photos[i];
                      return item.hasPreview
                          ? Image.network(
                              item.previewUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const _SlideFallback(),
                            )
                          : const _SlideFallback();
                    },
                  ),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                group.title.isEmpty ? group.date : group.title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: QyColors.ink),
              ),
              const SizedBox(height: 4),
              Text(
                photo == null ? '暂无照片' : photo.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: QyColors.muted),
              ),
              const SizedBox(height: 4),
              Text(
                '第 ${current + 1} / $count 张 · 当天共 ${group.count} 张',
                style: const TextStyle(fontSize: 11, color: QyColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            IconButton(
              onPressed: onPrev,
              icon: const Icon(Icons.skip_previous_rounded),
              color: QyColors.ink,
              tooltip: '上一张',
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: onTogglePlay,
              child: Icon(playing ? Icons.pause : Icons.play_arrow),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.skip_next_rounded),
              color: QyColors.ink,
              tooltip: '下一张',
            ),
          ],
        ),
        const SizedBox(height: 10),
        ProtoFootNote(
          album.truncated
              ? '照片按上传日期聚合 · 图片较多，仅展示最近部分 · 预览链接自动续期'
              : '照片按上传日期聚合 · 预览链接自动续期',
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
        ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return QyTapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? QyColors.primary : QyColors.sky,
          borderRadius: const BorderRadius.all(Radius.circular(18)),
        ),
        child: Text(
          '$label · $count 张',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? QyColors.onDark : QyColors.ink,
          ),
        ),
      ),
    );
  }
}

/// 预览过期 / VPS 暂时取不到直链时的兜底：只显示中性色块，不显示假图。
class _SlideFallback extends StatelessWidget {
  const _SlideFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[QyColors.mint, QyColors.sky],
        ),
      ),
      child: const Center(
        child: Icon(Icons.image_outlined, size: 40, color: Color(0xCCFFFFFF)),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: Column(
        children: <Widget>[
          const Icon(Icons.cloud_off_outlined, size: 34, color: QyColors.muted),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: QyColors.ink)),
          const SizedBox(height: 6),
          Text(description,
              style: const TextStyle(fontSize: 11.5, color: QyColors.muted)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
