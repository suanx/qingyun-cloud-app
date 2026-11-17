import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

import '../../core/models/cloud_models.dart';
import '../../core/network/cloud_repository.dart';

/// 搜索场景：输入关键词，实时过滤文件。
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final CloudRepository _repository = CloudRepository();
  final TextEditingController _controller = TextEditingController();
  List<CloudFile> _results = const <CloudFile>[];
  bool _searched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String keyword) async {
    try {
      final files = await _repository.files(keyword: keyword);
      if (!mounted) return;
      setState(() {
        _results = files;
        _searched = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _results = const <CloudFile>[]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: QyColors.canvas,
      appBar: AppBar(
        title: Text('搜索', style: textTheme.titleLarge),
        leading: IconButton(
          icon: const QyIcon(QyIcons.back, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                onSubmitted: _search,
                onChanged: _search,
                decoration: InputDecoration(
                  hintText: '搜索文件名',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(12),
                    child: QyIcon(QyIcons.search, size: 20, color: QyColors.sub),
                  ),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const QyIcon(QyIcons.close, size: 18, color: QyColors.muted),
                          onPressed: () {
                            _controller.clear();
                            _search('');
                          },
                        ),
                ),
              ),
            ),
            Expanded(
              child: !_searched
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: QyEmptyState(
                        icon: QyIcons.search,
                        title: '输入关键词',
                        description: '支持按文件名搜索云端文件',
                      ),
                    )
                  : _results.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: QyEmptyState(
                            title: '没有找到匹配的文件',
                            description: '换个关键词试试',
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                          itemCount: _results.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, int index) {
                            final file = _results[index];
                            return QyListTile(
                              leading: QyIcon(file.category.iconName, size: 32, color: file.category.tint),
                              title: file.name,
                              subtitle: '${file.updatedLabel} · ${file.sizeLabel}',
                              onTap: () => context.go(QyRoutes.preview),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
