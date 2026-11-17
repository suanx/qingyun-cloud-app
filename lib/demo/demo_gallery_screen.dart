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
        DemoCase('启动页', '暖黄渐变 + 品牌标识，停顿后自动进入首页', QyRoutes.splash),
        DemoCase('首页', '容量卡片、快捷操作、最近文件、下拉刷新', QyRoutes.home),
        DemoCase('文件分类与列表', '分类 chips 过滤 + 文件列表 + 空状态', QyRoutes.files),
        DemoCase('传输任务', '上传/下载任务进度、暂停/继续切换', QyRoutes.transfers),
        DemoCase('个人中心', '用户卡片、常用功能、设置分组', QyRoutes.profile),
        DemoCase('上传 / 下载', '发起传输并观察进度条推进', QyRoutes.transferFiles),
        DemoCase('搜索', '关键词实时过滤，含无结果空状态', QyRoutes.search),
        DemoCase('预览', '文件信息展示与下载入口', QyRoutes.preview),
        DemoCase('分享与权限', '生成分享链接、下载/提取码/有效期开关', QyRoutes.share),
        DemoCase('回收站', '已删除文件恢复与清空', QyRoutes.trash),
        DemoCase('容量管理', '总容量进度与分类占用明细', QyRoutes.storage),
        DemoCase('空状态与反馈', 'QyEmptyState 与成功/失败 Toast', QyRoutes.states),
      ],
    ),
    (
      groupComponents,
      <DemoCase>[
        DemoCase('组件总览', 'QyButton 四态、QyCard、进度条、列表项、Toast', AppRouter.demoComponents),
      ],
    ),
    (
      groupNetwork,
      <DemoCase>[
        DemoCase('网络层演示', '内置本地演示服务：envelop 解析、鉴权头、业务失败、401、超时、404', AppRouter.demoNetwork),
      ],
    ),
    (
      groupBoundary,
      <DemoCase>[
        DemoCase('边界情况', '空数据、超长文本、除零、进度越界、非法枚举、token 清理', AppRouter.demoBoundary),
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
