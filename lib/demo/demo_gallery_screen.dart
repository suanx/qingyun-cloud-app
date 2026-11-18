import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

import '../core/router/app_router.dart';

/// 功能演示用例：分组展示，点击即可进入可运行的演示页面。
class DemoCase {
  const DemoCase({
    required this.title,
    required this.description,
    required this.route,
  });

  final String title;
  final String description;
  final String route;
}

/// 全量功能演示注册表。新增演示时在此追加一条即可。
abstract final class DemoRegistry {
  static const String groupScenes = '业务场景（设计稿 12 场景）';
  static const String groupComponents = 'UI 组件与交互';
  static const String groupNetwork = '网络层与错误处理';
  static const String groupBoundary = '边界情况与容错';

  static const List<(String, List<DemoCase>)> groups = <(String, List<DemoCase>)>[
    (
      groupScenes,
      <DemoCase>[
        DemoCase(title: '启动页', description: '暖黄渐变 + 品牌标识，停顿后自动进入首页', route: QyRoutes.splash),
        DemoCase(title: '首页', description: '功能入口（相册/文件/视频/同步/分类）、最近文件、下拉刷新', route: QyRoutes.home),
        DemoCase(title: '文件分类与列表', description: '分类 chips 过滤 + 文件列表 + 空状态', route: QyRoutes.files),
        DemoCase(title: '传输任务', description: '上传/下载任务进度、暂停/继续切换', route: QyRoutes.transfers),
        DemoCase(title: '个人中心', description: '用户卡片、常用功能、设置分组', route: QyRoutes.profile),
        DemoCase(title: '上传 / 下载', description: '发起传输并观察进度条推进', route: QyRoutes.transferFiles),
        DemoCase(title: '搜索', description: '关键词实时过滤，含无结果空状态', route: QyRoutes.search),
        DemoCase(title: '预览', description: '文件信息展示与下载入口', route: QyRoutes.preview),
        DemoCase(title: '分享与权限', description: '生成分享链接、下载/提取码/有效期开关', route: QyRoutes.share),
        DemoCase(title: '回收站', description: '已删除文件恢复与清空', route: QyRoutes.trash),
        DemoCase(title: '容量管理', description: '总容量进度与分类占用明细', route: QyRoutes.storage),
        DemoCase(title: '空状态与反馈', description: 'QyEmptyState 与成功/失败 Toast', route: QyRoutes.states),
      ],
    ),
    (
      groupComponents,
      <DemoCase>[
        DemoCase(title: '组件总览', description: 'QyButton 四态、QyCard、进度条、列表项、Toast', route: AppRouter.demoComponents),
      ],
    ),
    (
      groupNetwork,
      <DemoCase>[
        DemoCase(title: '网络层演示', description: '内置本地演示服务：envelop 解析、鉴权头、业务失败、401、超时、404', route: AppRouter.demoNetwork),
      ],
    ),
    (
      groupBoundary,
      <DemoCase>[
        DemoCase(title: '边界情况', description: '空数据、超长文本、除零、进度越界、非法枚举、token 清理', route: AppRouter.demoBoundary),
      ],
    ),
  ];
}

/// 演示总入口页面。
class DemoGalleryScreen extends StatelessWidget {
  const DemoGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: QyColors.canvas,
      appBar: AppBar(
        title: Text('功能演示', style: textTheme.titleLarge),
        leading: IconButton(
          icon: const QyIcon(QyIcons.back, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          QyCard(
            gradient: QyColors.primaryGradient,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('轻云 · 功能演示中心', style: textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  '覆盖全部业务场景、UI 组件、网络层与边界情况。'
                  '每项演示均可直接运行并观察预期结果。',
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: QyTokens.spaceLg),
          for (final (group, cases) in DemoRegistry.groups) ...<Widget>[
            Text(group, style: textTheme.titleLarge),
            const SizedBox(height: QyTokens.spaceMd),
            for (final demoCase in cases)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: QyListTile(
                  leading: const QyIcon(QyIcons.play, size: 24, color: QyColors.primaryDeep),
                  title: demoCase.title,
                  subtitle: demoCase.description,
                  trailing: const QyIcon(QyIcons.back, size: 16, color: QyColors.muted),
                  onTap: () => _open(context, demoCase),
                ),
              ),
            const SizedBox(height: QyTokens.spaceMd),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _open(BuildContext context, DemoCase demoCase) {
    // 业务场景复用真实页面路由；组件/网络/边界进入专属演示页。
    context.push(demoCase.route);
  }
}
