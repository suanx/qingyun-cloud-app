import 'package:flutter/material.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';
import '../../core/models/cloud_models.dart';
import '../../core/models/transfer_store.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/error_reporter.dart';
import '../../core/utils/upload_helper.dart';
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
    // 下方任务列表与「最近完成」单独滚动。等价原型 .nav / .transfer-sum /
    // .chip-row 的 flex-shrink:0 + .scroll flex:1。
    return ColoredBox(
      color: QyColors.canvas,
      child: ListenableBuilder(
        listenable: LocalTransferStore.instance,
        builder: (BuildContext context, _) {
          final store = LocalTransferStore.instance;
          final running = store.running;
          final paused = store.paused;
          final done = store.done;
          final failed = store.failed;
          final chips = <String>[
            '进行中',
            '已完成',
            failed.isEmpty ? '失败' : '失败 ${failed.length}',
          ];
          // 暂停后任务不能再归到 running（请求已取消），但必须仍可见，
          // 否则点「暂停」后卡片会莫名消失。
          final active = <TransferTask>[...running, ...paused];
          final visible = <List<TransferTask>>[active, done, failed][_chip];
          final subtitle = running.isEmpty
              ? (paused.isEmpty
                  ? '当前没有进行中的任务'
                  : '${paused.length} 个任务已暂停')
              : (paused.isEmpty
                  ? '${running.length} 个任务进行中'
                  : '${running.length} 个任务进行中 · ${paused.length} 个已暂停');
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ProtoNav(
                title: '传输',
                subtitle: subtitle,
                actions: <Widget>[
                  QyTapScale(
                    onTap: () {
                      for (final task in running) {
                        store.pause(task.id);
                      }
                      showQyToast(
                        context,
                        running.isEmpty
                            ? '没有进行中的任务'
                            : '已暂停全部任务（请求已取消，继续将重新开始）',
                      );
                    },
                    child: const Text('全部暂停', style: ProtoText.sectionMore),
                  ),
                ],
              ),
              _SpeedCard(active: running.isNotEmpty),
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
                          title: _chip == 0 ? '暂无进行中或已暂停的任务' : (_chip == 1 ? '还没有已完成的任务' : '没有失败的任务'),
                          description: _chip == 0
                              ? '上传或下载文件时会在这里实时显示进度；暂停会取消请求，继续将重新传输'
                              : '切换其他筛选查看对应任务',
                        ),
                      )
                    else ...<Widget>[
                      for (final task in visible) _TransferCard(task: task),
                    ],
                    if (_chip == 0 && done.isNotEmpty) ...<Widget>[
                      ProtoSectionHead(
                        // 记录已持久化，可能包含前几天的任务，不再写死「今天」。
                        title: '最近完成',
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
    // 只有本次 App 会话内发起的任务才持有真实 CancelToken 与重发闭包；
    // 重启后恢复的历史记录不能重发，只提供「移除记录」。
    final bool canRestart = store.canRestart(task.id);
    final String direction =
        task.direction == TransferDirection.upload ? '上传' : '下载';
    final statusMeta = switch (task.status) {
      TransferStatus.running => '$direction中 · ${(task.progress * 100).toStringAsFixed(0)}%',
      // 暂停后请求已被取消，显示的百分比只是取消前的历史值，
      // 明确告诉用户「继续会从头重传」，不伪装成可续传。
      TransferStatus.paused => '已暂停 · 请求已取消（继续将重新开始）',
      TransferStatus.done => '传输完成',
      TransferStatus.failed => '传输失败',
    };
    final control = switch (task.status) {
      TransferStatus.running => Icons.pause,
      TransferStatus.paused => canRestart ? Icons.play_arrow : Icons.close,
      TransferStatus.failed => canRestart ? Icons.refresh : Icons.close,
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
                    // 失败时如实展示原因（接口返回的错误消息），不再只有
                    // 「传输失败」四个字让用户盲目重试。
                    if (task.status == TransferStatus.failed &&
                        (task.errorMessage ?? '').isNotEmpty) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(
                        task.errorMessage!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 10.5, color: QyColors.error),
                      ),
                    ],
                  ],
                ),
              ),
              QyTapScale(
                onTap: () {
                  switch (task.status) {
                    case TransferStatus.running:
                      store.pause(task.id);
                      showQyToast(context, '已暂停，请求已取消');
                    case TransferStatus.paused:
                      if (!canRestart) {
                        store.remove(task.id);
                        showQyToast(context, '已移除记录');
                        return;
                      }
                      store.resume(task.id);
                      showQyToast(context, '已重新发起$direction（从头开始）');
                    case TransferStatus.failed:
                      if (!canRestart) {
                        store.remove(task.id);
                        showQyToast(context, '已移除记录');
                        return;
                      }
                      store.retry(task.id);
                      showQyToast(context, '已重新发起$direction');
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
          // 进度条：轨道 + 填充。旧实现用 FractionallySizedBox 包无子
          // DecoratedBox，实机上填充层不绘制（只剩百分比文字）；这里用
          // LayoutBuilder 取真实宽度画填充，轨道也一并画出，进度可读。
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(3)),
            child: SizedBox(
              height: 5,
              child: Stack(
                children: <Widget>[
                  const Positioned.fill(
                    child: ColoredBox(color: QyColors.primaryLight),
                  ),
                  LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                      final double fillWidth = constraints.maxWidth *
                          task.progress.clamp(0.0, 1.0);
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: fillWidth,
                          decoration: BoxDecoration(
                            borderRadius:
                                const BorderRadius.all(Radius.circular(3)),
                            color: task.status == TransferStatus.failed
                                ? QyColors.error
                                : null,
                            gradient: task.status == TransferStatus.failed
                                ? null
                                : const LinearGradient(
                                    colors: <Color>[
                                      Color(0xFF4C8DFF),
                                      QyColors.mint,
                                    ],
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          // 上传任务的源路径只在内存里；文件被删 / 想换一个文件时，
          // 用真实的文件选择器重新发起，而不是假装「重试成功」。
          if (canRestart &&
              task.direction == TransferDirection.upload &&
              (task.status == TransferStatus.failed ||
                  task.status == TransferStatus.paused))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Align(
                alignment: Alignment.centerRight,
                child: QyTapScale(
                  onTap: () => _rePickFile(context, task.id),
                  child: const Text(
                    '重新选择文件',
                    style: TextStyle(fontSize: 10, color: QyColors.primary),
                  ),
                ),
              ),
            ),
          Row(
            children: <Widget>[
              Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 10, color: QyColors.muted),
                  children: <TextSpan>[
                    TextSpan(
                      text: task.status == TransferStatus.failed
                          ? '失败'
                          : task.status == TransferStatus.paused
                              ? '已暂停'
                              : '${(task.progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: QyColors.primary),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                switch (task.status) {
                  TransferStatus.done => '已完成',
                  TransferStatus.failed => canRestart ? '可重试' : '可移除',
                  TransferStatus.paused => canRestart ? '可继续' : '可移除',
                  TransferStatus.running => '进行中',
                },
                style: const TextStyle(fontSize: 10, color: QyColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 重新选择文件并上传：选到新文件才移除旧记录，用户取消则原样保留。
  Future<void> _rePickFile(BuildContext context, String oldTaskId) async {
    try {
      final CloudFile? file = await UploadHelper.pickAndUpload(
        replaceTaskId: oldTaskId,
      );
      if (!context.mounted) return;
      if (file == null) {
        showQyToast(context, '已取消，原记录保留');
        return;
      }
      showQyToast(context, '已重新上传 ${file.name}', success: true);
    } on ApiException catch (error) {
      if (error.isCancelled || !context.mounted) return;
      showQyToast(context, '上传失败：${error.message}');
    } catch (error, stack) {
      ErrorReporter.report(error, stack,
          context: 'transfers_screen#repick');
      if (context.mounted) showQyToast(context, '上传失败，请稍后重试');
    }
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
