import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/cloud_models.dart';
import '../network/cloud_repository.dart';

/// 全局「是否管理员」状态。
///
/// 服务端从第 2 步起对文件树实行「普通用户只读、仅管理员可写」，App 需要
/// 据此隐藏上传 / 新建 / 改名 / 删除 / 清理 / 转存等入口，避免普通用户点了
/// 之后只拿到 403。后端中间件仍是最终防线，这里只负责体验。
///
/// 安全默认：未加载 / 请求失败一律按普通用户处理（false），绝不放宽。
/// `main()` 在首个请求前刷新一次，登录成功后再刷新一次。
class AdminGate extends ChangeNotifier {
  AdminGate._();

  static final AdminGate instance = AdminGate._();

  bool _isAdmin = false;

  bool get isAdmin => _isAdmin;

  /// 从 `GET /api/status` 读取真实角色（后端同时返回 role / is_admin）。
  Future<void> refresh() async {
    try {
      final AccountStatus status = await CloudRepository().accountStatus();
      _isAdmin = status.isAdmin;
    } catch (_) {
      // 未登录 / 网络失败：保持安全默认，不抛到启动流程。
      _isAdmin = false;
    }
    notifyListeners();
  }

  void reset() {
    _isAdmin = false;
    notifyListeners();
  }
}

/// 把「仅管理员可用」的交互入口包一层；普通用户直接不渲染。
///
/// 用 AnimatedBuilder 监听 [AdminGate.instance]，所以登录 / 退出登录后
/// 已挂载的页面也会即时显示或隐藏，无需重建路由。
class AdminOnly extends StatelessWidget {
  const AdminOnly({super.key, required this.child, this.fallback});

  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: AdminGate.instance,
        builder: (_, __) => AdminGate.instance.isAdmin
            ? child
            : (fallback ?? const SizedBox.shrink()),
      );
}
