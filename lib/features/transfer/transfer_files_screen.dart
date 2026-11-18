import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

/// 上传 / 下载场景：入口按钮 + 模拟任务进度。
class TransferFilesScreen extends StatefulWidget {
  const TransferFilesScreen({super.key});

  @override
  State<TransferFilesScreen> createState() => _TransferFilesScreenState();
}

class _TransferFilesScreenState extends State<TransferFilesScreen> {
  double _uploadProgress = 0;
  double _downloadProgress = 0;
  bool _uploading = false;
  bool _downloading = false;

  void _runTask({required bool isUpload}) {
    final random = math.Random();
    setState(() {
      if (isUpload) {
        _uploading = true;
        _uploadProgress = 0;
      } else {
        _downloading = true;
        _downloadProgress = 0;
      }
    });

    Future<void>.delayed(const Duration(milliseconds: 300), () async {
      for (var step = 0; step <= 20; step++) {
        if (!mounted) return;
        setState(() {
          final progress = step / 20;
          if (isUpload) {
            _uploadProgress = progress;
          } else {
            _downloadProgress = progress;
          }
        });
        await Future<void>.delayed(Duration(milliseconds: 120 + random.nextInt(120)));
      }
      if (!mounted) return;
      setState(() {
        if (isUpload) {
          _uploading = false;
        } else {
          _downloading = false;
        }
      });
      showQyToast(context, isUpload ? '上传完成' : '下载完成');
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: QyColors.canvas,
      appBar: QyFrostAppBar(
        title: Text('上传 / 下载', style: textTheme.titleLarge),
        leading: IconButton(
          icon: const QyIcon(QyIcons.back, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('选择要发起的传输', style: textTheme.bodyMedium),
            const SizedBox(height: QyTokens.spaceLg),
            QyButton(
              '上传文件',
              icon: const QyIcon(QyIcons.upload, size: 20, color: QyColors.onDark),
              onPressed: _uploading ? null : () => _runTask(isUpload: true),
            ),
            const SizedBox(height: QyTokens.spaceMd),
            QyButton(
              '下载文件',
              icon: const QyIcon(QyIcons.download, size: 20, color: QyColors.primaryDeep),
              variant: QyButtonVariant.secondary,
              onPressed: _downloading ? null : () => _runTask(isUpload: false),
            ),
            const SizedBox(height: QyTokens.spaceXxl),
            _TaskProgressCard(
              title: '海边日落.JPG',
              subtitle: '上传到 /图片',
              progress: _uploadProgress,
              running: _uploading,
            ),
            const SizedBox(height: QyTokens.spaceMd),
            _TaskProgressCard(
              title: '设计资源打包.zip',
              subtitle: '下载到本机',
              progress: _downloadProgress,
              running: _downloading,
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskProgressCard extends StatelessWidget {
  const _TaskProgressCard({
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.running,
  });

  final String title;
  final String subtitle;
  final double progress;
  final bool running;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return QyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const QyIcon(
                QyIcons.transfer,
                size: 20,
                color: QyColors.sky,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: textTheme.bodyLarge)),
              Text(
                running ? '${(progress * 100).toStringAsFixed(0)}%' : (progress >= 1 ? '已完成' : '待开始'),
                style: textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: textTheme.labelMedium),
          const SizedBox(height: 12),
          QyProgressBar(value: progress),
        ],
      ),
    );
  }
}
