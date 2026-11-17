import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

import '../../features/files/files_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/preview/preview_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/share/share_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/states/states_screen.dart';
import '../../features/storage/storage_screen.dart';
import '../../features/transfers/transfers_screen.dart';
import '../../features/trash/trash_screen.dart';
import '../../features/transfer/transfer_files_screen.dart';

/// App 路由表。
///
/// 场景常量沿用 qingyun_ui_kit 的 [QyRoutes]（启动页、首页、上传下载、
/// 文件列表、搜索、预览、分享、传输任务、回收站、个人中心、容量管理、
/// 空状态与反馈，共 12 个场景）。
abstract final class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: QyRoutes.splash,
    routes: <RouteBase>[
      GoRoute(
        path: QyRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
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
      GoRoute(path: QyRoutes.transferFiles, builder: (_, __) => const TransferFilesScreen()),
      GoRoute(path: QyRoutes.search, builder: (_, __) => const SearchScreen()),
      GoRoute(path: QyRoutes.preview, builder: (_, __) => const PreviewScreen()),
      GoRoute(path: QyRoutes.share, builder: (_, __) => const ShareScreen()),
      GoRoute(path: QyRoutes.trash, builder: (_, __) => const TrashScreen()),
      GoRoute(path: QyRoutes.storage, builder: (_, __) => const StorageScreen()),
      GoRoute(path: QyRoutes.states, builder: (_, __) => const StatesScreen()),
    ],
  );
}

/// 底部胶囊导航外壳：首页 / 文件 / 传输 / 我的 四个 Tab。
class QyTabShell extends StatelessWidget {
  const QyTabShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QyColors.canvas,
      body: navigationShell,
      bottomNavigationBar: QyBottomNav(
        currentIndex: navigationShell.currentIndex,
        onChanged: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
