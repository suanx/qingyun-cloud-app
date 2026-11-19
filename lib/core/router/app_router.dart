import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

import '../../features/album/album_screen.dart';
import '../../features/files/files_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/login/login_screen.dart';
import '../../features/preview/preview_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/storage/storage_screen.dart';
import '../../features/transfers/transfers_screen.dart';
import '../config/app_config.dart';
import '../network/token_store.dart';

/// App 路由表：对齐高保真原型的 8 个页面。
///
/// 4 个 Tab（首页 / 文件 / 传输 / 我的）走 StatefulShellRoute；
/// 搜索 / 存储空间 / 文件预览 / 相册为独立推入页。
/// 原型之外的旧场景路由一律重定向，保证 App 内任何入口都只有新设计。
abstract final class AppRouter {
  /// 功能演示相关路由（历史常量，保留以兼容演示页代码；路由已重定向）。
  static const String demo = '/demo';
  static const String demoComponents = '/demo/components';
  static const String demoNetwork = '/demo/network';
  static const String demoBoundary = '/demo/boundary';

  /// 历史功能入口路由（重定向到原型对应页面）。
  static const String gallery = '/gallery';
  static const String allFiles = '/all-files';
  static const String videos = '/videos';

  /// 旧路径 -> 新页面，避免出现原型之外的旧样式页面。
  static const Map<String, String> _redirects = <String, String>{
    QyRoutes.splash: QyRoutes.home,
    QyRoutes.transferFiles: QyRoutes.transfers,
    QyRoutes.share: QyRoutes.preview,
    QyRoutes.trash: QyRoutes.files,
    QyRoutes.states: QyRoutes.files,
    gallery: QyRoutes.album,
    allFiles: QyRoutes.files,
    videos: QyRoutes.files,
    demo: QyRoutes.files,
    demoComponents: QyRoutes.files,
    demoNetwork: QyRoutes.files,
    demoBoundary: QyRoutes.files,
  };

  /// 登录页（对接 lanflare 时未登录一律先到这里）。
  static const String login = '/login';

  /// 登录态守卫：未登录跳登录页；已登录访问登录页回首页。
  /// mock 模式（useMockData = true）不强制登录。
  static String? _authGuard(BuildContext _, GoRouterState state) {
    if (AppConfig.useMockData) return null;
    final loggedIn = TokenStore.credential?.isNotEmpty ?? false;
    final atLogin = state.matchedLocation == login;
    if (!loggedIn && !atLogin) return login;
    if (loggedIn && atLogin) return QyRoutes.home;
    return null;
  }

  /// HTTP 401 全局处理：清凭证并回到登录页（main 里注册到 ApiClient）。
  static void handleUnauthorized() {
    TokenStore.clear();
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
      GoRoute(path: QyRoutes.preview, builder: (_, __) => const PreviewScreen()),
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
