import 'package:flutter/material.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

import '../../core/models/cloud_models.dart';
import 'files_screen.dart';

/// 通用文件浏览器页：带返回栏的文件列表，供首页「相册 / 文件 / 视频」等
/// 卡片入口 push 使用，返回时可回到上一个页面。
class FilesBrowserScreen extends StatelessWidget {
  const FilesBrowserScreen({
    super.key,
    required this.title,
    this.category,
  });

  final String title;

  /// 初始选中的文件分类；为空时展示全部文件。
  final FileCategory? category;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QyColors.canvas,
      appBar: QyFrostAppBar(
        title: Text(title, style: Theme.of(context).textTheme.titleLarge),
        leading: IconButton(
          icon: const QyIcon(QyIcons.back, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: FilesScreen(initialCategory: category, showHeader: false),
    );
  }
}
