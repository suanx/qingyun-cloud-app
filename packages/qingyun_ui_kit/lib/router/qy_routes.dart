import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

abstract final class QyRoutes {
  static const String splash = '/';
  static const String home = '/home';
  static const String transferFiles = '/transfer-files';
  static const String files = '/files';
  static const String search = '/search';
  static const String preview = '/preview';
  static const String share = '/share';
  static const String transfers = '/transfers';
  static const String trash = '/trash';
  static const String profile = '/profile';
  static const String storage = '/storage';
  static const String states = '/states';
  static const String album = '/album';

  static const Map<String, String> titles = <String, String>{
    splash: '启动页',
    home: '首页',
    transferFiles: '上传 / 下载',
    files: '文件分类与列表',
    search: '搜索',
    preview: '预览',
    share: '分享与权限',
    transfers: '传输任务',
    trash: '回收站',
    profile: '个人中心',
    storage: '容量管理',
    states: '空状态与反馈',
    album: '相册',
  };
}

/// Minimal router skeleton. Replace QyPlaceholderScreen with your real screens.
class QyRouter {
  static GoRouter build() => GoRouter(
        initialLocation: QyRoutes.home,
        routes: <RouteBase>[
          for (final entry in QyRoutes.titles.entries)
            GoRoute(
              path: entry.key,
              builder: (_, __) => QyPlaceholderScreen(title: entry.value),
            ),
        ],
      );
}

class QyPlaceholderScreen extends StatelessWidget {
  const QyPlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title · 在此接入业务页面')),
    );
  }
}
