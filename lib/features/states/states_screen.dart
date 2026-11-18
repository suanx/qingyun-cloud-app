import 'package:flutter/material.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

/// 空状态与反馈场景：集中展示 QyEmptyState 与 Toast 反馈。
class StatesScreen extends StatelessWidget {
  const StatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: QyColors.canvas,
      appBar: QyFrostAppBar(
        title: Text('空状态与反馈', style: textTheme.titleLarge),
        leading: IconButton(
          icon: const QyIcon(QyIcons.back, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Text('操作反馈', style: textTheme.titleLarge),
          const SizedBox(height: QyTokens.spaceMd),
          QyButton('成功 Toast', onPressed: () => showQyToast(context, '文件已上传')),
          const SizedBox(height: QyTokens.spaceMd),
          QyButton(
            '失败 Toast',
            variant: QyButtonVariant.secondary,
            onPressed: () => showQyToast(context, '网络异常，上传失败', success: false),
          ),
          const SizedBox(height: QyTokens.spaceXl),
          Text('空状态', style: textTheme.titleLarge),
          const SizedBox(height: QyTokens.spaceMd),
          QyEmptyState(
            icon: QyIcons.empty,
            title: '这里还没有文件',
            description: '上传第一份文件，开始你的轻云之旅',
            actionLabel: '上传第一个文件',
            onAction: () => showQyToast(context, '已唤起文件选择'),
          ),
          const SizedBox(height: QyTokens.spaceLg),
          QyEmptyState(
            icon: QyIcons.warning,
            title: '加载失败',
            description: '网络似乎开小差了，稍后再试试',
            actionLabel: '重新加载',
            onAction: () => showQyToast(context, '正在重新加载'),
          ),
        ],
      ),
    );
  }
}
