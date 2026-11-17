import 'package:flutter/material.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

/// 分享与权限场景：生成分享链接 + 权限设置。
class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  bool _allowDownload = true;
  bool _requirePassword = false;
  bool _expireIn7Days = true;
  String? _sharedLink;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: QyColors.canvas,
      appBar: AppBar(
        title: Text('分享与权限', style: textTheme.titleLarge),
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
            QyCard(
              gradient: QyColors.primaryGradient,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const QyIcon(QyIcons.image, size: 20, color: QyColors.primaryDeep),
                      const SizedBox(width: 8),
                      Text('海边日落.JPG', style: textTheme.bodyLarge),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('图片 · 4.2 MB', style: textTheme.labelMedium),
                  const SizedBox(height: QyTokens.spaceLg),
                  QyButton(
                    '生成分享链接',
                    icon: const QyIcon(QyIcons.link, size: 20, color: QyColors.ink),
                    onPressed: () => setState(() => _sharedLink = 'https://qy.example.com/s/8f3kq2'),
                  ),
                ],
              ),
            ),
            if (_sharedLink != null) ...<Widget>[
              const SizedBox(height: QyTokens.spaceMd),
              QyCard(
                child: Row(
                  children: <Widget>[
                    Expanded(child: Text(_sharedLink!, style: textTheme.bodyMedium)),
                    IconButton(
                      icon: const QyIcon(QyIcons.edit, size: 18, color: QyColors.primaryDeep),
                      onPressed: () => showQyToast(context, '链接已复制'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: QyTokens.spaceXl),
            Text('权限设置', style: textTheme.titleLarge),
            const SizedBox(height: QyTokens.spaceMd),
            QyCard(
              child: Column(
                children: <Widget>[
                  _SwitchRow(
                    icon: QyIcons.download,
                    label: '允许下载',
                    value: _allowDownload,
                    onChanged: (value) => setState(() => _allowDownload = value),
                  ),
                  const Divider(color: QyColors.divider, height: 1),
                  _SwitchRow(
                    icon: QyIcons.lock,
                    label: '提取码保护',
                    value: _requirePassword,
                    onChanged: (value) => setState(() => _requirePassword = value),
                  ),
                  const Divider(color: QyColors.divider, height: 1),
                  _SwitchRow(
                    icon: QyIcons.clock,
                    label: '7 天后失效',
                    value: _expireIn7Days,
                    onChanged: (value) => setState(() => _expireIn7Days = value),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: <Widget>[
          QyIcon(icon, size: 20, color: QyColors.primaryDeep),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
          Switch(
            value: value,
            activeColor: QyColors.primaryDeep,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
