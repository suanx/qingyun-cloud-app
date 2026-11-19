import 'package:flutter/material.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

import '../../core/models/cloud_models.dart';
import '../../core/models/transfer_store.dart';
import '../../widgets/proto_widgets.dart';

/// 03 传输中心（对齐 screen-transfer）。任务来自 App 本地传输记录
/// （[LocalTransferStore]），上传/下载操作实时驱动进度。
class TransfersScreen extends StatefulWidget {
  const TransfersScreen({super.key});

  @override
  State<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends State<TransfersScreen> {
  int _chip = 0;

  @override
  Widget build(BuildContext context) {
    // 红框区域（标题 / 副标题 / 全部暂停 + 速度卡 + 筛选胶囊）固定不滚动，
    // 下方任务列表与「今天已完成」单独滚动。等价原型 .nav / .transfer-sum /
    // .chip-row 的 flex-shrink:0 + .scroll flex:1。
    return ColoredBox(
      color: QyColors.canvas,
      child: ListenableBuilder(
        listenable: LocalTransferStore.instance,
        builder: (BuildContext context, _) {
          final store = LocalTransferStore.instance;
          final running = store.running;
          final done = store.done;
          final failed = store.failed;
          final chips = <String>[
            '正在传输',
            '已完成',
            failed.isEmpty ? '失败' : '失败 ${failed.length}',
          ];
          final visible = <List<TransferTask>>[running, done, failed][_chip];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ProtoNav(
                title: '传输',
                subtitle: running.isEmpty ? '当前没有进行中的任务' : '${running.length} 个任务进行中',
                actions: <Widget>[
                  QyTapScale(
                    onTap: () {
                      for (final task in running) {
                        store.pause(task.id);
                      }
                      showQyToast(context, running.isEmpty ? '没有进行中的任务' : '已暂停全部任务');
                    },
                    child: const Text('全部暂停', style: ProtoText.sectionMore),
                  ),
                ],
              ),
              const _SpeedCard(active: true),
              ProtoChipRow(
                labels: chips,
                activeIndex: _chip,
                onChanged: (int i) => setState(() => _chip = i),
              ),
              Expanded(
                child: ListView(
                  physics: qyProtoScrollPhysics,
                  padding: const EdgeInsets.only(bottom: 100),
                  children: <Widget>[
                    if (visible.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                        child: QyEmptyState(
                          title: _chip == 0 ? '暂无进行中的任务' : (_chip == 1 ? '还没有已完成的任务' : '没有失败的任务'),
                          description: _chip == 0
                              ? '上传或下载文件时会在这里实时显示进度'
                              : '切换其他筛选查看对应任务',
                        ),
                      )
                    else ...<Widget>[
                      for (final task in visible) _TransferCard(task: task),
                    ],
                    if (_chip == 0 && done.isNotEmpty) ...<Widget>[
                      ProtoSectionHead(
                        title: '今天已完成',
                        more: '${done.length} 项',
                        moreIcon: Icons.chevron_right,
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                      ),
                      _DoneList(tasks: done),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SpeedCard extends StatelessWidget {
  const _SpeedCard({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        gradient: LinearGradient(
          begin: Alignment(-0.5, -0.87),
          end: Alignment(0.5, 0.87),
          colors: <Color>[Color(0xFFEAF1FF), Color(0xFFE7F8F5)],
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: QyColors.surface,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: const Icon(Icons.bolt, size: 21, color: QyColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(active ? '传输进行中' : '空闲中',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: QyColors.ink)),
                const SizedBox(height: 2),
                Text(active ? '上传 / 下载进度实时更新' : '上传或下载文件后显示实时进度',
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF6B7A93))),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 18, color: Color(0xFF8FA3BF)),
        ],
      ),
    );
  }
}

class _TransferCard extends StatelessWidget {
  const _TransferCard({required this.task});

  final TransferTask task;

  static const Map<FileCategory, IconData> _icons = <FileCategory, IconData>{
    FileCategory.image: Icons.image,
    FileCategory.doc: Icons.table_chart,
    FileCategory.video: Icons.movie,
    FileCategory.music: Icons.audio_file,
    FileCategory.zip: Icons.folder_zip,
    FileCategory.other: Icons.insert_drive_file,
    FileCategory.all: Icons.insert_drive_file,
  };

  @override
  Widget build(BuildContext context) {
    final store = LocalTransferStore.instance;
    final category = FileCategoryX.fromFileName(task.name);
    final statusMeta = switch (task.status) {
      TransferStatus.running => '${task.direction == TransferDirection.upload ? '上传中' : '下载中'} · ${(task.progress * 100).toStringAsFixed(0)}%',
      TransferStatus.paused => '已暂停 · ${(task.progress * 100).toStringAsFixed(0)}%',
      TransferStatus.done => '传输完成',
      TransferStatus.failed => '传输失败',
    };
    final control = switch (task.status) {
      TransferStatus.running => Icons.pause,
      TransferStatus.paused => Icons.play_arrow,
      TransferStatus.failed => Icons.refresh,
      TransferStatus.done => Icons.close,
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: QyColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              ProtoTypeIcon(
                icon: _icons[category] ?? Icons.insert_drive_file,
                color: QyColors.primary,
                background: QyColors.primaryLight,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(task.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ProtoText.name135),
                    const SizedBox(height: 3),
                    Text('${task.sizeLabel.isEmpty ? '' : '${task.sizeLabel} · '}$statusMeta', style: ProtoText.label105),
                  ],
                ),
              ),
              QyTapScale(
                onTap: () {
                  switch (task.status) {
                    case TransferStatus.running:
                      store.pause(task.id);
                      showQyToast(context, '已暂停');
                    case TransferStatus.paused:
                      store.resume(task.id);
                      showQyToast(context, '已继续');
                    case TransferStatus.failed:
                      store.resume(task.id);
                      showQyToast(context, '已重新排队');
                    case TransferStatus.done:
                      store.remove(task.id);
                      showQyToast(context, '已移除记录');
                  }
                },
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: QyColors.surface,
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(BorderSide(color: QyColors.border)),
                  ),
                  child: Icon(control, size: 17, color: const Color(0xFF475467)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(3)),
            child: SizedBox(
              height: 5,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: task.progress.clamp(0.0, 1.0),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(3)),
                      gradient: LinearGradient(
                        colors: <Color>[Color(0xFF4C8DFF), QyColors.mint],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 10, color: QyColors.muted),
                  children: <TextSpan>[
                    TextSpan(
                      text: task.status == TransferStatus.failed
                          ? '失败'
                          : '${(task.progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: QyColors.primary),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                task.status == TransferStatus.done
                    ? '已完成'
                    : task.status == TransferStatus.failed
                        ? '可重试'
                        : '进行中',
                style: const TextStyle(fontSize: 10, color: QyColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DoneList extends StatelessWidget {
  const _DoneList({required this.tasks});

  final List<TransferTask> tasks;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: QyColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          for (final task in tasks)
            _DoneRow(
              name: task.name,
              sub: '${task.sizeLabel.isEmpty ? '已完成' : task.sizeLabel} · ${task.direction == TransferDirection.upload ? '上传' : '下载'}完成',
            ),
        ],
      ),
    );
  }
}

class _DoneRow extends StatelessWidget {
  const _DoneRow({required this.name, required this.sub});

  final String name;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: QyColors.divider)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: <Widget>[
          const ProtoTypeIcon(
            icon: Icons.check_circle,
            color: QyColors.mintDeep,
            background: QyColors.mintSoft,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ProtoText.name135),
                const SizedBox(height: 3),
                Text(sub, style: ProtoText.label105),
              ],
            ),
          ),
          const Icon(Icons.more_vert, size: 20, color: QyColors.hint),
        ],
      ),
    );
  }
}
