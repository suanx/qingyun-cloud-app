import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

import '../../core/models/cloud_models.dart';
import '../../core/network/cloud_repository.dart';

/// 文件分类与列表场景。
///
/// [initialCategory] 指定初始分类（供首页相册 / 视频等入口复用）；
/// [showHeader] 控制是否展示页内大标题（嵌入带 AppBar 的浏览器页时关闭）。
class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key, this.initialCategory, this.showHeader = true});

  final FileCategory? initialCategory;
  final bool showHeader;

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  final CloudRepository _repository = CloudRepository();
  late FileCategory _category = widget.initialCategory ?? FileCategory.all;
  List<CloudFile> _files = const <CloudFile>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final files = await _repository.files(category: _category);
      if (!mounted) return;
      setState(() {
        _files = files;
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
    const categories = FileCategory.values;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (widget.showHeader) ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text('文件', style: textTheme.headlineLarge),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: <Widget>[
                QyFrost(
                  color: QyColors.frost,
                  blur: 14,
                  borderRadius: BorderRadius.circular(QyTokens.radiusPill),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (final category in categories)
                          Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: _CategoryChip(
                              label: category.label,
                              selected: category == _category,
                              onTap: () {
                                setState(() => _category = category);
                                _load();
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: QyColors.primaryDeep))
                : RefreshIndicator(
                    color: QyColors.primaryDeep,
                    onRefresh: _load,
                    child: _files.isEmpty
                        ? ListView(
                            children: <Widget>[
                              const SizedBox(height: 80),
                              QyEmptyState(
                                title: '该分类下暂无文件',
                                description: '换一个分类看看，或上传新文件',
                                actionLabel: '上传文件',
                                onAction: () => context.push(QyRoutes.transferFiles),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                            itemCount: _files.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (_, int index) {
                              final file = _files[index];
                              return QyListTile(
                                leading: QyIcon(file.category.iconName, size: 32, color: file.category.tint),
                                title: file.name,
                                subtitle: '${file.updatedLabel} · ${file.sizeLabel}',
                                trailing: const QyIcon(QyIcons.more, size: 20, color: QyColors.muted),
                                onTap: () => context.push(QyRoutes.preview),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: QyTokens.shortMotion,
      child: Material(
        color: selected ? QyColors.ink : Colors.transparent,
        borderRadius: BorderRadius.circular(QyTokens.radiusPill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(QyTokens.radiusPill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? QyColors.onDark : QyColors.sub,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
