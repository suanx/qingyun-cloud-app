import 'package:flutter/material.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

import '../../core/models/cloud_models.dart';
import '../../core/network/cloud_repository.dart';

/// 传输任务场景：进行中 / 已暂停 / 失败的任务列表。
class TransfersScreen extends StatefulWidget {
  const TransfersScreen({super.key});

  @override
  State<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends State<TransfersScreen> {
  final CloudRepository _repository = CloudRepository();
  List<TransferTask> _tasks = MockData.transfers;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tasks = await _repository.transfers();
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _toggleTask(TransferTask task) {
    setState(() {
      final updated = task.status == TransferStatus.running
          ? task.copyWith(status: TransferStatus.paused)
          : task.copyWith(status: TransferStatus.running);
      _tasks = <TransferTask>[
        for (final item in _tasks) if (item.id == task.id) updated else item,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ColoredBox(
      color: QyColors.canvas,
      child: SafeArea(
      child: RefreshIndicator(
        color: QyColors.primaryDeep,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            Text('传输', style: textTheme.headlineLarge),
            const SizedBox(height: 4),
            Text('共 ${_tasks.length} 个任务', style: textTheme.bodyMedium),
            const SizedBox(height: QyTokens.spaceLg),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator(color: QyColors.primaryDeep)),
              )
            else
              for (final task in _tasks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TransferCard(task: task, onToggle: () => _toggleTask(task)),
                ),
            const SizedBox(height: 96),
          ],
        ),
      ),
      ),
    );
  }
}

class _TransferCard extends StatelessWidget {
  const _TransferCard({required this.task, required this.onToggle});

  final TransferTask task;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final running = task.status == TransferStatus.running;
    final failed = task.status == TransferStatus.failed;
    final done = task.status == TransferStatus.done;

    final statusLabel = switch (task.status) {
      TransferStatus.running => '传输中',
      TransferStatus.paused => '已暂停',
      TransferStatus.done => '已完成',
      TransferStatus.failed => '失败',
    };
    final statusColor = failed ? QyColors.error : (done ? QyColors.success : QyColors.primaryDeep);

    return QyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              QyIcon(
                task.direction == TransferDirection.upload ? QyIcons.upload : QyIcons.download,
                size: 20,
                color: task.direction == TransferDirection.upload ? QyColors.sky : QyColors.mint,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(task.name, style: textTheme.bodyLarge)),
              GestureDetector(
                onTap: done ? null : onToggle,
                child: QyIcon(
                  running ? QyIcons.pause : QyIcons.play,
                  size: 20,
                  color: done ? QyColors.muted : QyColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${task.direction == TransferDirection.upload ? '上传' : '下载'} · ${task.sizeLabel}',
              style: textTheme.labelMedium),
          const SizedBox(height: 12),
          QyProgressBar(value: task.progress),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Text('${(task.progress * 100).toStringAsFixed(0)}%', style: textTheme.labelMedium),
              const Spacer(),
              Text(statusLabel, style: textTheme.labelMedium?.copyWith(color: statusColor)),
            ],
          ),
        ],
      ),
    );
  }
}
