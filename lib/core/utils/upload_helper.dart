import 'package:file_picker/file_picker.dart';

import '../models/cloud_models.dart';
import '../network/cloud_repository.dart';

/// 上传入口共用工具：选择本地文件 → 调用仓库上传 → 进度写入传输任务。
abstract final class UploadHelper {
  /// 用户取消返回 null；上传失败抛 ApiException。
  static Future<CloudFile?> pickAndUpload({int pid = 0}) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return null;
    final PlatformFile picked = result.files.single;
    final String? path = picked.path;
    if (path == null) return null;
    return CloudRepository().uploadPath(
      path: path,
      name: picked.name,
      pid: pid,
    );
  }
}
