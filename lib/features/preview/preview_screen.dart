import 'package:flutter/material.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

import '../../core/network/api_endpoints.dart';

/// 预览场景：文件信息 + 操作区（真实预览由后端返回文件流/链接后接入）。
class PreviewScreen extends StatelessWidget {
  const PreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: QyColors.canvas,
      appBar: AppBar(
        title: Text('预览', style: textTheme.titleLarge),
        leading: IconButton(
          icon: const QyIcon(QyIcons.back, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: <Widget>[
          IconButton(
            icon: const QyIcon(QyIcons.share, size: 20),
            onPressed: () {},
          ),
          IconButton(
            icon: const QyIcon(QyIcons.more, size: 20),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: QyColors.surface,
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[QyTokens.softShadow(QyColors.warmShadow)],
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(32),
                        child: QyIcon(QyIcons.image, size: 64, color: QyColors.coral),
                      ),
                    ),
                    const SizedBox(height: QyTokens.spaceXl),
                    Text('海边日落.JPG', style: textTheme.titleLarge),
                    const SizedBox(height: QyTokens.spaceSm),
                    Text('图片 · 4.2 MB · 今天 14:32', style: textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: QyButton(
                '下载到本机',
                icon: const QyIcon(QyIcons.download, size: 20, color: QyColors.ink),
                onPressed: () => showQyToast(
                  context,
                  '下载接口：${ApiEndpoints.fileDownload('f1')}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
