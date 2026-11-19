import 'package:flutter/foundation.dart';

import 'cloud_models.dart';

/// 本地传输任务模型。
///
/// lanflare 的上传为同步/分块即传、下载为直链或代理流，没有服务端任务列表；
/// App 端在上传/下载开始时创建任务，进度由 dio 回调驱动，完成后落为
/// 「已完成」，失败落为「失败」。仅保存在内存中（重启即清空）。
class LocalTransferStore extends ChangeNotifier {
  LocalTransferStore._();

  /// 全局单例（传输页与上传/下载操作共享）。
  static final LocalTransferStore instance = LocalTransferStore._();

  final List<TransferTask> _tasks = <TransferTask>[];

  /// 全部任务（新的在前）。
  List<TransferTask> get tasks => List<TransferTask>.unmodifiable(_tasks);

  List<TransferTask> get running => _tasks
      .where((t) => t.status == TransferStatus.running)
      .toList(growable: false);

  List<TransferTask> get done => _tasks
      .where((t) => t.status == TransferStatus.done)
      .toList(growable: false);

  List<TransferTask> get failed => _tasks
      .where((t) => t.status == TransferStatus.failed)
      .toList(growable: false);

  /// 创建任务并返回 id。
  String start({
    required String name,
    required TransferDirection direction,
    required String sizeLabel,
    double progress = 0,
  }) {
    final task = TransferTask(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      direction: direction,
      status: TransferStatus.running,
      progress: progress.clamp(0.0, 1.0),
      sizeLabel: sizeLabel,
    );
    _tasks.insert(0, task);
    notifyListeners();
    return task.id;
  }

  void updateProgress(String id, double progress) {
    final index = _indexFor(id);
    if (index < 0) return;
    final task = _tasks[index];
    if (task.status != TransferStatus.running) return;
    _tasks[index] =
        task.copyWith(progress: progress.clamp(0.0, 0.99));
    notifyListeners();
  }

  void complete(String id) => _setStatus(id, TransferStatus.done, 1);

  void fail(String id) => _setStatus(id, TransferStatus.failed);

  void pause(String id) => _setStatus(id, TransferStatus.paused);

  void resume(String id) => _setStatus(id, TransferStatus.running);

  void remove(String id) {
    _tasks.removeWhere((task) => task.id == id);
    notifyListeners();
  }

  void _setStatus(String id, TransferStatus status, [double? progress]) {
    final index = _indexFor(id);
    if (index < 0) return;
    _tasks[index] = _tasks[index].copyWith(status: status, progress: progress);
    notifyListeners();
  }

  int _indexFor(String id) => _tasks.indexWhere((task) => task.id == id);
}
