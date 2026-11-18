import 'package:flutter/material.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

import '../../core/models/cloud_models.dart';
import '../../core/network/cloud_repository.dart';

/// 容量管理场景：总览 + 分类占用。
class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  final CloudRepository _repository = CloudRepository();
  StorageSummary _summary = MockData.storageSummary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final summary = await _repository.storageSummary();
      if (!mounted) return;
      setState(() {
        _summary = summary;
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
    const breakdowns = <(FileCategory, double)>[
      (FileCategory.image, 0.42),
      (FileCategory.video, 0.31),
      (FileCategory.doc, 0.14),
      (FileCategory.music, 0.08),
      (FileCategory.zip, 0.05),
    ];

    return Scaffold(
      backgroundColor: QyColors.canvas,
      appBar: QyFrostAppBar(
        title: Text('容量管理', style: textTheme.titleLarge),
        leading: IconButton(
          icon: const QyIcon(QyIcons.back, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: QyColors.primaryDeep))
          : RefreshIndicator(
              color: QyColors.primaryDeep,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: <Widget>[
                  QyCard(
                    color: QyColors.surfaceSoft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('已用空间', style: textTheme.bodyLarge),
                        const SizedBox(height: 8),
                        Text(_summary.label, style: textTheme.headlineLarge),
                        const SizedBox(height: 16),
                        QyProgressBar(value: _summary.ratio, height: 10),
                        const SizedBox(height: 8),
                        Text('共 ${_summary.totalGb.toStringAsFixed(0)} GB · 剩余 ${( _summary.totalGb - _summary.usedGb).toStringAsFixed(1)} GB',
                            style: textTheme.labelMedium),
                      ],
                    ),
                  ),
                  const SizedBox(height: QyTokens.spaceXl),
                  Text('分类占用', style: textTheme.titleLarge),
                  const SizedBox(height: QyTokens.spaceMd),
                  QyCard(
                    child: Column(
                      children: <Widget>[
                        for (final (category, fraction) in breakdowns)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: <Widget>[
                                QyIcon(category.iconName, size: 20, color: category.tint),
                                const SizedBox(width: 12),
                                Expanded(child: Text(category.label, style: textTheme.bodyLarge)),
                                SizedBox(
                                  width: 120,
                                  child: QyProgressBar(value: fraction),
                                ),
                                const SizedBox(width: 12),
                                Text('${(fraction * 100).toStringAsFixed(0)}%', style: textTheme.labelMedium),
                              ],
                            ),
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
