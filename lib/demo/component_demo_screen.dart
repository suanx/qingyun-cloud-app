import 'package:flutter/material.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

/// UI 组件与交互演示：覆盖 qingyun_ui_kit 全部组件的典型用法。
class ComponentDemoScreen extends StatelessWidget {
  const ComponentDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: QyColors.canvas,
      appBar: QyFrostAppBar(
        title: Text('组件演示', style: textTheme.titleLarge),
        leading: IconButton(
          icon: const QyIcon(QyIcons.back, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          _section(context, 'QyButton · 四种状态'),
          const QyButton('主要按钮（未绑定事件，展示禁用保护）', onPressed: null),
          const SizedBox(height: 12),
          QyButton(
            '主要按钮（可点击）',
            icon: const QyIcon(QyIcons.upload, size: 20, color: QyColors.ink),
            onPressed: () => showQyToast(context, '主要按钮点击'),
          ),
          const SizedBox(height: 12),
          QyButton(
            '次要按钮',
            variant: QyButtonVariant.secondary,
            onPressed: () => showQyToast(context, '次要按钮点击'),
          ),
          const SizedBox(height: 12),
          QyButton(
            '轮廓按钮',
            variant: QyButtonVariant.outline,
            onPressed: () => showQyToast(context, '轮廓按钮点击'),
          ),
          const SizedBox(height: 12),
          const QyButton('禁用按钮', variant: QyButtonVariant.disabled),

          _section(context, 'QyCard · 常规与浅色'),
          QyCard(
            onTap: () => showQyToast(context, '卡片点击'),
            child: Text('磨砂玻璃卡 · 圆角 20 · 背景模糊', style: textTheme.bodyLarge),
          ),
          const SizedBox(height: 12),
          const QyCard(
            color: QyColors.surfaceSoft,
            child: Text('浅色卡片 · surfaceSoft', style: TextStyle(color: QyColors.ink)),
          ),

          _section(context, 'QyProgressBar · 边界值自动收敛'),
          const QyProgressBar(value: 0),
          const SizedBox(height: 8),
          const QyProgressBar(value: 0.5),
          const SizedBox(height: 8),
          const QyProgressBar(value: 1),
          const SizedBox(height: 8),
          // 故意传入越界值 1.5 / -0.2：组件内部 clamp 到 [0,1]
          const QyProgressBar(value: 1.5),
          const SizedBox(height: 8),
          const QyProgressBar(value: -0.2),

          _section(context, 'QyListTile · 文件条目'),
          QyListTile(
            leading: const QyIcon(QyIcons.image, size: 32, color: QyColors.coral),
            title: '海边日落.JPG',
            subtitle: '今天 14:32 · 4.2 MB',
            trailing: const QyIcon(QyIcons.more, size: 20, color: QyColors.muted),
            onTap: () => showQyToast(context, '打开预览'),
          ),
          const SizedBox(height: 12),
          const QyListTile(
            leading: QyIcon(QyIcons.doc, size: 32, color: QyColors.sky),
            title: '这是一个非常非常非常长的文件名示例用于验证单行截断省略号效果.docx',
            subtitle: '超长标题应显示省略号而不换行',
          ),

          _section(context, 'QyEmptyState · 空状态'),
          const QyEmptyState(
            icon: QyIcons.empty,
            title: '这里还没有文件',
            description: '上传第一份文件，开始你的轻云之旅',
          ),

          _section(context, 'showQyToast · 成功 / 失败'),
          QyButton('成功 Toast', onPressed: () => showQyToast(context, '文件已上传')),
          const SizedBox(height: 12),
          QyButton(
            '失败 Toast',
            variant: QyButtonVariant.secondary,
            onPressed: () => showQyToast(context, '网络异常，请稍后重试', success: false),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}
