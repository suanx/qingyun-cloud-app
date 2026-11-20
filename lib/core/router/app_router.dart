import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';
import '../../features/admin/admin_vip_screen.dart';
import '../../features/album/album_screen.dart';
import '../../features/album/recall_album_screen.dart';
import '../../features/files/files_screen.dart';
import '../../features/help/help_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/login/login_screen.dart';
import '../../features/preview/preview_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/scan/scan_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/security/devices_screen.dart';
import '../../features/security/security_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shares/shares_screen.dart';
import '../../features/storage/storage_screen.dart';
import '../../features/transfers/transfers_screen.dart';
import '../../features/trash/trash_screen.dart';
import '../models/cloud_models.dart';
import '../network/token_store.dart';

/// App 路由表：对齐高保真原型的 8 个页面。
///
/// 4 个 Tab（首页 / 文件 / 传输 / 我的）走 StatefulShellRoute；
/// 搜索 / 存储空间 / 文件预览 / 相册为独立推入页。
/// 原型之外的旧场景路由一律重定向，保证 App 内任何入口都只有新设计。
abstract final class AppRouter {
  /// 历史功能入口路由（重定向到原型对应页面）。
  static const String gallery = '/gallery';
  static const String allFiles = '/all-files';
  static const String videos = '/videos';

  /// 旧路径 -> 新页面，避免出现原型之外的旧样式页面。
  static const Map<String, String> _redirects = <String, String>{
    QyRoutes.splash: QyRoutes.home,
    QyRoutes.transferFiles: QyRoutes.transfers,
    QyRoutes.share: QyRoutes.preview,
    QyRoutes.states: QyRoutes.files,
    gallery: QyRoutes.album,
    allFiles: QyRoutes.files,
    videos: QyRoutes.files,
  };

  /// 登录页（对接 lanflare 时未登录一律先到这里）。
  static const String login = '/login';

  /// 我的分享：后端 GET /api/my-shares + DELETE /api/shares/:id。
  static const String myShares = '/my-shares';

  /// 会员管理（仅 admin）：后端 GET /api/admin/users + POST .../vip。
  static const String adminVip = '/admin-vip';

  /// 安全中心：两步验证 + 登录设备入口。
  static const String security = '/security';

  /// 登录设备 / API 令牌管理。
  static const String devices = '/devices';

  /// 帮助与反馈：真实 FAQ + 提交 / 查看反馈（管理员可回复）。
  static const String help = '/help';

  /// 设置：服务地址、连接自检、本地数据清理、版本信息。
  static const String settings = '/settings';

  /// 扫一扫：摄像头识别分享二维码 → 解析 → 转存到指定目录。
  static const String scan = '/scan';

  /// 照片回忆轮播：后端按真实上传日期分组的图片 + 签名预览 URL，零视频生成。
  static const String recallAlbum = '/recall-album';

  /// 登录态守卫：未登录跳登录页；已登录访问登录页回首页。
  static String? _authGuard(BuildContext _, GoRouterState state) {
    final loggedIn = TokenStore.credential?.isNotEmpty ?? false;
    final atLogin = state.matchedLocation == login;
    if (!loggedIn && !atLogin) return login;
    if (loggedIn && atLogin) return QyRoutes.home;
    return null;
  }

  /// HTTP 401 全局处理：清凭证并回到登录页（main 里注册到 ApiClient）。
  static Future<void> handleUnauthorized() async {
    await TokenStore.clear();
    router.go(login);
  }

  static final GoRouter router = GoRouter(
    initialLocation: QyRoutes.home,
    redirect: _authGuard,
    routes: <RouteBase>[
      GoRoute(path: login, builder: (_, __) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, __, navigationShell) => QyTabShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(path: QyRoutes.home, builder: (_, __) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(path: QyRoutes.files, builder: (_, __) => const FilesScreen()),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(path: QyRoutes.transfers, builder: (_, __) => const TransfersScreen()),
          ]),
          StatefulShellBranch(routes: <RouteBase>[
            GoRoute(path: QyRoutes.profile, builder: (_, __) => const ProfileScreen()),
          ]),
        ],
      ),
      GoRoute(path: QyRoutes.search, builder: (_, __) => const SearchScreen()),
      GoRoute(path: QyRoutes.storage, builder: (_, __) => const StorageScreen()),
      GoRoute(path: QyRoutes.trash, builder: (_, __) => const TrashScreen()),
      GoRoute(path: myShares, builder: (_, __) => const SharesScreen()),
      GoRoute(path: adminVip, builder: (_, __) => const AdminVipScreen()),
      GoRoute(path: security, builder: (_, __) => const SecurityScreen()),
      GoRoute(path: devices, builder: (_, __) => const DevicesScreen()),
      GoRoute(path: help, builder: (_, __) => const HelpScreen()),
      GoRoute(path: settings, builder: (_, __) => const SettingsScreen()),
      GoRoute(path: scan, builder: (_, __) => const ScanScreen()),
      GoRoute(
        path: recallAlbum,
        builder: (_, __) => const RecallAlbumScreen(),
      ),
      GoRoute(
        path: QyRoutes.preview,
        // 预览必须携带文件对象；无参时回到文件页，避免旧占位页重现。
        redirect: (_, GoRouterState state) =>
            state.extra is CloudFile ? null : QyRoutes.files,
        builder: (_, GoRouterState state) =>
            PreviewScreen(file: state.extra! as CloudFile),
      ),
      GoRoute(path: QyRoutes.album, builder: (_, __) => const AlbumScreen()),
      for (final MapEntry<String, String> entry in _redirects.entries)
        GoRoute(path: entry.key, redirect: (_, __) => entry.value),
    ],
  );
}

/// 底部导航外壳：首页 / 文件 / 传输 / 我的 四个 Tab。
class QyTabShell extends StatelessWidget {
  const QyTabShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QyColors.canvas,
      // 不加 SafeArea：头图渐变需延伸到透明状态栏之下，
      // 各页面顶部自带 54~58 的 padding 避开系统状态栏图标。
      body: ColoredBox(color: QyColors.canvas, child: navigationShell),
      bottomNavigationBar: QyBottomNav(
        currentIndex: navigationShell.currentIndex,
        onChanged: (int index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
