import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/error_reporter.dart';
import 'cloud_models.dart';

/// 一次「真实传输尝试」的运行时句柄（**纯内存，不落盘**）。
///
/// [cancel] 真正取消底层 HTTP 请求（dio CancelToken）；[restart] 重新发起
/// 一整次传输并复用同一个任务 id。二者都由 CloudRepository 在发起请求时注册。
class _TransferRuntime {
  const _TransferRuntime({required this.cancel, required this.restart});

  final void Function() cancel;
  final Future<void> Function() restart;
}

/// 本地传输任务模型（真实任务，非演示数据）。
///
/// lanflare 的上传为同步/分块即传、下载为直链或代理流，没有服务端任务列表；
/// App 端在上传/下载开始时创建任务，进度由 dio 回调驱动，完成后落为
/// 「已完成」，失败落为「失败」。
///
/// **暂停 / 重试语义（第 17 步）**：后端**没有断点续传**，「暂停」只能是
/// 取消当前 HTTP 请求；「继续 / 重试」只能是**从头重新发起一整次传输**。
/// 因此 [pause] 会调用运行时 [cancel]，[resume] / [retry] 会调用 [restart]
/// 并把进度归零——绝不出现「状态是 running、其实没有请求在跑」的假任务。
///
/// **持久化口径**：只把已结束（done / failed）的记录写入
/// `shared_preferences` 的 [persistenceKey]，重启后在 [load] 中恢复。
/// 进行中 / 已暂停的任务**不落盘**。运行时句柄（CancelToken、源文件路径）
/// 也**只在内存**：重启后恢复的历史记录 [canRestart] 为 false，只能移除，
/// 不会显示一个点了没反应的「重试」按钮。
///
/// 写盘只发生在终态变更、移除、清空、以及从终态重置为 running 时；
/// 进度回调高频更新不触发 IO。
class LocalTransferStore extends ChangeNotifier {
  LocalTransferStore._();

  /// 全局单例（传输页与上传/下载操作共享）。
  static final LocalTransferStore instance = LocalTransferStore._();

  /// 持久化 key（与 SettingsStore 的服务地址、搜索历史 key 相互独立）。
  static const String persistenceKey = 'qingyun_transfer_history_v1';

  /// 最多保留的最新记录数，避免长期使用后 JSON 无限膨胀。
  static const int maxRecords = 100;

  final List<TransferTask> _tasks = <TransferTask>[];

  /// 任务 id → 当前这次真实请求的运行时句柄。重启后为空。
  final Map<String, _TransferRuntime> _runtime = <String, _TransferRuntime>{};

  bool _loaded = false;

  /// 串行写盘队列：保证多次快速变更不会乱序覆盖（旧快照盖掉新快照）。
  Future<void> _writeChain = Future<void>.value();

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

  /// 已暂停的任务（paused 不在 done/failed/done 三个 getter 里）。
  List<TransferTask> get paused => _tasks
      .where((t) => t.status == TransferStatus.paused)
      .toList(growable: false);

  /// 该任务是否还能真正重新发起请求（重启恢复的历史记录为 false）。
  bool canRestart(String id) => _runtime.containsKey(id);

  /// App 启动时恢复已结束的传输记录（在 `runApp` 之前 await，页面不会闪空）。
  ///
  /// 防御式解析：坏 JSON / 非列表 / 非对象 / 空 id / 重复 id / 非终态状态
  /// 一律跳过；单条异常不影响其它记录，整体异常上报但不阻断启动。
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(persistenceKey);
      if (raw == null || raw.isEmpty) return;
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return;

      final Set<String> seen = <String>{};
      final List<TransferTask> restored = <TransferTask>[];
      for (final Object? item in decoded) {
        if (restored.length >= maxRecords) break;
        if (item is! Map<String, dynamic>) continue;
        final TransferTask task = TransferTask.fromJson(item);
        if (task.id.isEmpty || seen.contains(task.id)) continue;
        // 只恢复真实已结束的记录；历史坏数据里的 running / paused 不还原。
        if (task.status != TransferStatus.done &&
            task.status != TransferStatus.failed) {
          continue;
        }
        seen.add(task.id);
        restored.add(task);
      }
      if (restored.isEmpty) return;
      _tasks
        ..clear()
        ..addAll(restored);
      notifyListeners();
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'transfer_store#load');
    }
  }

  /// 创建新任务；若传 [id] 且该任务仍存在，则**复用同一条记录**重置为
  /// running（进度归零，因为后端不支持续传，重发一定从头开始）。
  ///
  /// 复用时会写一次磁盘快照：若该任务之前是 failed（已落盘），不移除的话
  /// 重启后会「复活」成一条失败的旧记录。
  String startOrReset({
    String? id,
    required String name,
    required TransferDirection direction,
    required String sizeLabel,
  }) {
    if (id != null) {
      final int index = _indexFor(id);
      if (index >= 0) {
        _tasks[index] = TransferTask(
          id: id,
          name: name,
          direction: direction,
          status: TransferStatus.running,
          progress: 0,
          sizeLabel: sizeLabel,
        );
        notifyListeners();
        _schedulePersist();
        return id;
      }
    }
    return start(name: name, direction: direction, sizeLabel: sizeLabel);
  }

  /// 创建任务并返回 id。进行中任务不落盘，见类注释。
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
    _trim();
    notifyListeners();
    return task.id;
  }

  /// 注册本次请求的真实取消与重发能力（由 CloudRepository 调用）。
  ///
  /// 同 id 重复注册会覆盖旧句柄——重新发起时会自动换上新的 CancelToken。
  void attachRuntime({
    required String id,
    required void Function() cancel,
    required Future<void> Function() restart,
  }) {
    _runtime[id] = _TransferRuntime(cancel: cancel, restart: restart);
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

  void complete(String id) {
    _runtime.remove(id);
    _setStatus(id, TransferStatus.done, 1);
  }

  /// 失败后**保留** runtime：用户点「重试」时仍能真正重新发起请求。
  /// [message] 是给用户看的失败原因（来自接口错误），会随记录落盘。
  void fail(String id, [String? message]) =>
      _setStatus(id, TransferStatus.failed, null, message);

  /// 暂停：先把状态落地为 paused，再真正取消底层 HTTP 请求。
  ///
  /// 不落盘（paused 是中间态）；取消引发的异常由 CloudRepository 识别为
  /// `ApiException.isCancelled`，不会再覆盖成 failed。
  void pause(String id) {
    final index = _indexFor(id);
    if (index < 0) return;
    if (_tasks[index].status != TransferStatus.running) return;
    _tasks[index] = _tasks[index].copyWith(status: TransferStatus.paused);
    notifyListeners();
    _runtime[id]?.cancel();
  }

  /// 继续 / 重试：调用真正的重发闭包。
  ///
  /// 闭包内部会重新走 `startOrReset` 把状态置为 running、进度归零，
  /// 并发起一次全新的 HTTP 请求。历史记录（无 runtime）不做任何事。
  void resume(String id) => _restart(id);

  void retry(String id) => _restart(id);

  void _restart(String id) {
    final _TransferRuntime? runtime = _runtime[id];
    if (runtime == null) return;
    unawaited(_safeRestart(runtime));
  }

  /// 重发是异步触发、没有调用方 await：异常必须在此吞掉，状态已由
  /// CloudRepository 内部落地（fail / paused）。闭包本身会过滤 cancelled，
  /// 这里只兜底上报其它意外异常，避免未处理异步错误。
  static Future<void> _safeRestart(_TransferRuntime runtime) async {
    try {
      await runtime.restart();
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'transfer_store#restart');
    }
  }

  void remove(String id) {
    final int before = _tasks.length;
    _tasks.removeWhere((task) => task.id == id);
    if (_tasks.length == before) return;
    _runtime.remove(id);
    notifyListeners();
    _schedulePersist();
  }

  /// 清空全部传输记录（设置页「清除传输记录」）；返回被清除的条数。
  ///
  /// 同时清空内存与本地持久化，重启后不会「复活」。不影响云端文件与搜索历史。
  int clear() {
    final count = _tasks.length;
    for (final _TransferRuntime runtime in _runtime.values) {
      runtime.cancel();
    }
    _runtime.clear();
    if (count == 0) {
      // 即使内存为空也写一次空快照，清掉可能残留的旧 key。
      _schedulePersist();
      return 0;
    }
    _tasks.clear();
    notifyListeners();
    _schedulePersist();
    return count;
  }

  void _setStatus(String id, TransferStatus status,
      [double? progress, String? errorMessage]) {
    final index = _indexFor(id);
    if (index < 0) return;
    _tasks[index] = _tasks[index].copyWith(
        status: status, progress: progress, errorMessage: errorMessage);
    notifyListeners();
    if (status == TransferStatus.done || status == TransferStatus.failed) {
      _schedulePersist();
    }
  }

  /// 只保留最新 [maxRecords] 条；运行中的任务始终在最前，不会被裁掉。
  void _trim() {
    if (_tasks.length > maxRecords) {
      _tasks.removeRange(maxRecords, _tasks.length);
    }
  }

  /// 当前磁盘快照：仅终态记录，且按 [maxRecords] 截断。
  String _snapshot() {
    final List<Map<String, dynamic>> records = <Map<String, dynamic>>[];
    for (final TransferTask task in _tasks) {
      if (records.length >= maxRecords) break;
      if (task.status == TransferStatus.done ||
          task.status == TransferStatus.failed) {
        records.add(task.toJson());
      }
    }
    return jsonEncode(records);
  }

  /// 在调用点取快照并追加到串行写链；写失败只上报，绝不影响传输本身。
  void _schedulePersist() {
    final String payload = _snapshot();
    _writeChain = _writeChain.then((_) async {
      try {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString(persistenceKey, payload);
      } catch (error, stack) {
        ErrorReporter.report(error, stack, context: 'transfer_store#persist');
      }
    });
  }

  int _indexFor(String id) => _tasks.indexWhere((task) => task.id == id);
}
