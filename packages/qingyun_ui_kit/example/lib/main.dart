import 'package:flutter/material.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

void main() => runApp(const QyDemoApp());

class QyDemoApp extends StatelessWidget {
  const QyDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '轻云 UI Kit',
      theme: qyLightTheme(),
      home: const QyGalleryScreen(),
    );
  }
}

class QyGalleryScreen extends StatefulWidget {
  const QyGalleryScreen({super.key});

  @override
  State<QyGalleryScreen> createState() => _QyGalleryScreenState();
}

class _QyGalleryScreenState extends State<QyGalleryScreen> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('轻云 UI Kit', style: textTheme.headlineLarge),
              const SizedBox(height: 4),
              Text('纯白 · 钢青蓝灰 · 彩色图标', style: textTheme.bodyMedium),
              const SizedBox(height: 24),

              Text('按钮', style: textTheme.titleLarge),
              const SizedBox(height: 12),
              QyButton('上传文件', onPressed: () => showQyToast(context, '上传成功')),
              const SizedBox(height: 12),
              QyButton('新建文件夹', variant: QyButtonVariant.secondary, onPressed: () {}),
              const SizedBox(height: 12),
              QyButton('取消', variant: QyButtonVariant.outline, onPressed: () {}),
              const SizedBox(height: 24),

              Text('卡片与进度', style: textTheme.titleLarge),
              const SizedBox(height: 12),
              QyCard(
                color: QyColors.surfaceSoft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('云端空间', style: textTheme.bodyLarge),
                    const SizedBox(height: 8),
                    Text('47.2 / 128 GB', style: textTheme.headlineMedium),
                    const SizedBox(height: 16),
                    const QyProgressBar(value: 0.37),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text('列表项', style: textTheme.titleLarge),
              const SizedBox(height: 12),
              QyListTile(
                leading: const QyIcon(QyIcons.image, size: 32, color: QyColors.ink),
                title: '海边日落.JPG',
                subtitle: '今天 14:32 · 4.2 MB',
                trailing: const QyIcon(QyIcons.more, size: 20, color: QyColors.muted),
                onTap: () => showQyToast(context, '打开预览'),
              ),
              const SizedBox(height: 24),

              Text('空状态', style: textTheme.titleLarge),
              const SizedBox(height: 12),
              QyEmptyState(
                title: '这里还没有文件',
                description: '上传第一份文件，开始你的轻云之旅',
                actionLabel: '上传第一个文件',
                onAction: () => showQyToast(context, '已唤起文件选择'),
              ),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
      bottomNavigationBar: QyBottomNav(
        currentIndex: _navIndex,
        onChanged: (index) => setState(() => _navIndex = index),
      ),
    );
  }
}
