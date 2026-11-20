import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/settings_store.dart';
import '../../core/models/cloud_models.dart';
import '../../core/models/transfer_store.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/cloud_repository.dart';
import '../../core/utils/error_reporter.dart';
import '../../widgets/proto_widgets.dart';

/// 05 搜索（对齐 screen-search）。
///
/// - 关键字搜索走 lanflare `GET /api/search?q=`（仅文件名匹配）。
/// - 「快捷筛选」计数与「最近文件」取自 `GET /api/stats/quick` 的真实统计。
/// - 「传输记录」取本地 `LocalTransferStore` 的真实运行中任务数。
/// 全页无任何写死数值、编造热搜或假徽章。
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final CloudRepository _repo = CloudRepository();

  List<String> _history = <String>[];

  bool _searching = false;
  String _query = '';
  List<CloudFile> _results = <CloudFile>[];

  /// 快捷筛选 / 最近文件的真实统计（lanflare GET /api/stats/quick）。
  /// 失败时保持 null，页面显示中性文案，不回退到任何编造数值。
  QuickStats? _stats;
  bool _statsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadStats();
    // 传输任务数来自本地真实任务模型；任务状态变化时刷新该数字。
    LocalTransferStore.instance.addListener(_onTransferChanged);
  }

  void _onTransferChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _repo.quickStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _statsLoading = false;
      });
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'search_screen#stats');
      if (!mounted) return;
      setState(() {
        _stats = null;
        _statsLoading = false;
      });
    }
  }

  Future<void> _loadHistory() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _history = prefs.getStringList(SettingsStore.searchHistoryKey) ?? <String>[]);
  }

  Future<void> _addHistory(String query) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> updated = <String>[
      query,
      ..._history.where((String item) => item != query),
    ].take(8).toList();
    await prefs.setStringList(SettingsStore.searchHistoryKey, updated);
    if (mounted) setState(() => _history = updated);
  }

  Future<void> _clearHistory() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(SettingsStore.searchHistoryKey);
    if (!mounted) return;
    setState(() => _history = <String>[]);
    showQyToast(context, '搜索历史已清空', success: true);
  }

  @override
  void dispose() {
    LocalTransferStore.instance.removeListener(_onTransferChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    _controller.text = q;
    setState(() {
      _searching = true;
      _query = q;
    });
    await _addHistory(q);
    try {
      final files = await _repo.files(keyword: q);
      if (!mounted) return;
      setState(() {
        _results = files;
        _searching = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _results = const <CloudFile>[];
        _searching = false;
      });
      showQyToast(context, error.message, success: false);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'search_screen#1');
      if (!mounted) return;
      setState(() {
        _results = const <CloudFile>[];
        _searching = false;
      });
      showQyToast(context, '搜索失败，请检查网络后重试', success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: QyColors.canvas,
      child: ListView(
        physics: qyProtoScrollPhysics,
        padding: const EdgeInsets.only(bottom: 26),
        children: <Widget>[
          _SearchBar(controller: _controller, onSubmitted: _search),
          const SizedBox(height: 6),
          if (_searching)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_query.isNotEmpty) ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
              child: Text(
                _results.isEmpty ? '没有找到与「$_query」匹配的文件' : '「$_query」 · ${_results.length} 个结果',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: QyColors.heroLabel),
              ),
            ),
            if (_results.isNotEmpty) _ResultList(files: _results),
          ] else ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
              child: Row(
                children: <Widget>[
                  const Text('搜索历史',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: QyColors.heroLabel)),
                  const Spacer(),
                  QyTapScale(
                    onTap: _clearHistory,
                    child: const Icon(Icons.delete_outline, size: 17, color: QyColors.hint),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final String tag in _history)
                    _Tag(label: tag, onTap: () => _search(tag)),
                ],
              ),
            ),
            _RecentSection(
              stats: _stats,
              loading: _statsLoading,
              onRetry: () {
                _loadStats();
              },
              onTapFile: (RecentFile file) => _search(file.searchTerm),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 20, 18, 0),
              child: Text('快捷筛选',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: QyColors.heroLabel)),
            ),
            const SizedBox(height: 12),
            _ResultHint(
              icon: Icons.image,
              prefix: '图片 · ',
              bold: _statsLoading
                  ? '—'
                  : (_stats == null ? '?' : '${_stats!.counts.image}'),
              suffix: _statsLoading
                  ? ' 个文件 · 统计加载中'
                  : (_stats == null
                      ? ' 个文件 · 统计不可用'
                      : ' 个文件 · 查看全部图片'),
              onTap: () => context.push(QyRoutes.album),
            ),
            _ResultHint(
              icon: Icons.description,
              prefix: '文档 · ',
              bold: _statsLoading
                  ? '—'
                  : (_stats == null ? '?' : '${_stats!.counts.doc}'),
              suffix: _statsLoading
                  ? ' 个文件 · 统计加载中'
                  : (_stats == null
                      ? ' 个文件 · 统计不可用'
                      : ' 个文件 · 最近更新 ${_stats!.recentUpdatedLabel}'),
              onTap: () => context.go(QyRoutes.files),
            ),
            _ResultHint(
              icon: Icons.swap_vert,
              prefix: '传输记录 · ',
              bold: '${LocalTransferStore.instance.running.length}',
              suffix: ' 个任务进行中',
              onTap: () => context.go(QyRoutes.transfers),
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onSubmitted});

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 54, 16, 14),
      child: Row(
        children: <Widget>[
          ProtoIconButton(
            icon: Icons.arrow_back,
            onTap: () => context.go(QyRoutes.files),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: QyColors.surface,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                border: Border.all(color: const Color(0xFFE6EDFA)),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Color(0x0A1F4899), blurRadius: 8, offset: Offset(0, 2)),
                ],
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.search, size: 19, color: QyColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      textInputAction: TextInputAction.search,
                      onSubmitted: onSubmitted,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: '搜索文件名',
                        hintStyle: TextStyle(fontSize: 14, color: Color(0xFFA9B4C6)),
                      ),
                      style: const TextStyle(fontSize: 14, color: QyColors.ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          QyTapScale(
            onTap: () => context.go(QyRoutes.files),
            child: const Text('取消', style: TextStyle(fontSize: 13, color: QyColors.sub)),
          ),
        ],
      ),
    );
  }
}

/// 搜索结果列表（lanflare 返回的是全局匹配，含所在路径）。
class _ResultList extends StatelessWidget {
  const _ResultList({required this.files});

  final List<CloudFile> files;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: const BoxDecoration(
          color: QyColors.surface,
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: <Widget>[
            for (final file in files)
              QyTapScale(
                onTap: () => context.push(QyRoutes.preview, extra: file),
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: QyColors.divider)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: <Widget>[
                      const ProtoTypeIcon(
                        icon: Icons.insert_drive_file,
                        color: QyColors.primary,
                        background: QyColors.primaryLight,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(file.name,
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: ProtoText.name135),
                            if (file.sizeLabel.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 3),
                              Text(file.sizeLabel, style: ProtoText.label105),
                            ],
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 17, color: QyColors.chevron),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return QyTapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: QyColors.surface,
          border: Border.all(color: QyColors.border),
          borderRadius: const BorderRadius.all(Radius.circular(20)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF475467)),
        ),
      ),
    );
  }
}

/// 「最近文件」区：数据全部来自 `GET /api/stats/quick` 的 recent_files。
///
/// 原型这里的几条带「热」「新」徽章的编造热搜词都已移除；
/// 私有网盘没有全站热度，改为展示本人最近上传的真实文件。
class _RecentSection extends StatelessWidget {
  const _RecentSection({
    required this.stats,
    required this.loading,
    required this.onRetry,
    required this.onTapFile,
  });

  final QuickStats? stats;
  final bool loading;
  final VoidCallback onRetry;
  final ValueChanged<RecentFile> onTapFile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 4),
          child: Row(
            children: <Widget>[
              const Text('最近文件',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: QyColors.heroLabel)),
              const Spacer(),
              QyTapScale(
                onTap: loading ? () {} : onRetry,
                child: const Icon(Icons.refresh, size: 16, color: QyColors.hint),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 0, 18, 8),
          child: Text('来自你的云端文件，点击可按文件名搜索',
              style: TextStyle(fontSize: 11, color: QyColors.hint)),
        ),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )),
          )
        else if (stats == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: QyTapScale(
                onTap: onRetry,
                child: const Text('统计加载失败，点击重试',
                    style: TextStyle(fontSize: 11.5, color: QyColors.coral)),
              ),
            ),
          )
        else if (stats!.recentFiles.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: Text('暂无文件，上传后可在此快速定位',
                  style: TextStyle(fontSize: 11.5, color: QyColors.hint)),
            ),
          )
        else
          for (final RecentFile file in stats!.recentFiles)
            _RecentFileRow(file: file, onTap: () => onTapFile(file)),
      ],
    );
  }
}

class _RecentFileRow extends StatelessWidget {
  const _RecentFileRow({required this.file, required this.onTap});

  final RecentFile file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = CloudRepository.relativeTime(file.createdAt);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: QyTapScale(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: <Widget>[
              Icon(_iconFor(FileCategoryX.fromFileName(file.name)),
                  size: 18, color: QyColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, color: QyColors.ink),
                    ),
                    if (label.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(label, style: ProtoText.label105),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 17, color: QyColors.chevron),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _iconFor(FileCategory category) => switch (category) {
      FileCategory.image => Icons.image_outlined,
      FileCategory.doc => Icons.description_outlined,
      FileCategory.video => Icons.movie_outlined,
      FileCategory.music => Icons.audiotrack_outlined,
      FileCategory.zip => Icons.folder_zip_outlined,
      FileCategory.all || FileCategory.other =>
        Icons.insert_drive_file_outlined,
    };
class _ResultHint extends StatelessWidget {
  const _ResultHint({
    required this.icon,
    required this.prefix,
    required this.bold,
    required this.suffix,
    required this.onTap,
  });

  final IconData icon;
  final String prefix;
  final String bold;
  final String suffix;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: QyTapScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: const BoxDecoration(
            color: QyColors.surface,
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 19, color: QyColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: ProtoText.body125,
                    children: <TextSpan>[
                      TextSpan(text: prefix),
                      TextSpan(
                        text: bold,
                        style: const TextStyle(fontWeight: FontWeight.w600, color: QyColors.primary),
                      ),
                      TextSpan(text: suffix),
                    ],
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, size: 17, color: QyColors.chevron),
            ],
          ),
        ),
      ),
    );
  }
}
