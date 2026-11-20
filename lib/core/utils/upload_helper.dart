import 'package:file_picker/file_picker.dart';
import '../models/cloud_models.dart';
import '../models/transfer_store.dart';
import '../network/cloud_repository.dart';

/// 上传入口共用工具：选择本地文件 → 调用仓库上传 → 进度写入传输任务。
abstract final class UploadHelper {
  /// 用户取消返回 null；上传失败抛 ApiException。
  ///
  /// [replaceTaskId] 用于传输页的「重新选择文件」：选到新文件后，先把那条
  /// 失败 / 已暂停的旧记录（含磁盘缓存）移除，再发起一次全新上传。
  /// 用户在选择器里点取消时不做任何替换，旧记录保留。
  static Future<CloudFile?> pickAndUpload({
    int pid = 0,
    String? replaceTaskId,
  }) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return null;
    final PlatformFile picked = result.files.single;
    final String? path = picked.path;
    if (path == null) return null;
    if (replaceTaskId != null) {
      LocalTransferStore.instance.remove(replaceTaskId);
    }
    return CloudRepository().uploadPath(
      path: path,
      name: picked.name,
      pid: pid,
    );
  }
}
