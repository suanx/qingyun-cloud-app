import 'package:flutter/material.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

import '../../core/models/cloud_models.dart';
import 'files_screen.dart';

/// 历史文件浏览器页：原型收敛后所有入口统一走 FilesScreen，
/// 保留本页只为兼容旧路由常量，路由表中已重定向到 /files。
class FilesBrowserScreen extends StatelessWidget {
  const FilesBrowserScreen({
    super.key,
    required this.title,
    this.category,
  });

  final String title;

  /// 保留参数以兼容历史调用（原型页面不再按分类区分）。
  final FileCategory? category;

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: QyColors.canvas,
      body: FilesScreen(),
    );
  }
}
