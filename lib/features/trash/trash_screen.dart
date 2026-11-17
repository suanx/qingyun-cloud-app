import 'package:flutter/material.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

import '../../core/models/cloud_models.dart';
import '../../core/network/cloud_repository.dart';

/// 回收站场景：已删除文件列表 + 恢复 / 清空。
class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  final CloudRepository _repository = CloudRepository();
  List<CloudFile> _files = MockData.trashFiles;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final files = await _repository.trashFiles();
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
    return Scaffold(
      backgroundColor: QyColors.canvas,
      appBar: AppBar(
        title: Text('回收站', style: textTheme.titleLarge),
        leading: IconButton(
          icon: const QyIcon(QyIcons.back, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: _files.isEmpty ? null : () => showQyToast(context, '已清空回收站', success: false),
            child: const Text('清空'),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: QyColors.primaryDeep))
            : _files.isEmpty
                ? const QyEmptyState(
                    icon: QyIcons.trash,
                    title: '回收站是空的',
                    description: '删除的文件会在这里保留 30 天',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _files.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, int index) {
                      final file = _files[index];
                      return QyListTile(
                        leading: QyIcon(file.category.iconName, size: 32, color: QyColors.muted),
                        title: file.name,
                        subtitle: file.updatedLabel,
                        trailing: TextButton(
                          onPressed: () => showQyToast(context, '已恢复 ${file.name}'),
                          child: const Text('恢复'),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
