import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';
import '../../core/models/cloud_models.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/cloud_repository.dart';
import '../../widgets/proto_widgets.dart';
import '../../core/config/admin_gate.dart';

/// 我的分享：后端 GET /api/my-shares + DELETE /api/shares/:id。
class SharesScreen extends StatefulWidget {
  const SharesScreen({super.key});

  @override
  State<SharesScreen> createState() => _SharesScreenState();
}

class _SharesScreenState extends State<SharesScreen> {
  final CloudRepository _repo = CloudRepository();
  late Future<List<ShareItem>> _future = _repo.myShares();

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() => _future = _repo.myShares());
  }

  Future<void> _revoke(ShareItem item) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('撤销分享'),
        content: Text('确定撤销「${item.name}」的分享链接吗？'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('撤销'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.deleteShare(item.id);
      if (!mounted) return;
      showQyToast(context, '已撤销分享', success: true);
      await _reload();
    } on ApiException catch (e) {
      if (mounted) showQyToast(context, '撤销失败：${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: QyColors.canvas,
      child: ListView(
        physics: qyProtoScrollPhysics,
        padding: const EdgeInsets.only(bottom: 26),
        children: <Widget>[
          ProtoNav(
            title: '我的分享',
            subtitle: '后端 /api/my-shares',
            leading: ProtoIconButton(
              icon: Icons.arrow_back,
              onTap: () => context.go(QyRoutes.profile),
            ),
          ),
          FutureBuilder<List<ShareItem>>(
            future: _future,
            builder: (BuildContext context, AsyncSnapshot<List<ShareItem>> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: QyEmptyState(
                    icon: QyIcons.empty,
                    title: '加载失败',
                    description: '${snapshot.error}',
                    actionLabel: '重试',
                    onAction: _reload,
                  ),
                );
              }
              final List<ShareItem> items = snapshot.data ?? <ShareItem>[];
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: QyEmptyState(
                    icon: QyIcons.empty,
                    title: '还没有分享',
                    description: '在文件预览页点击「分享」即可生成链接',
                  ),
                );
              }
              return Column(
                children: <Widget>[
                  for (final ShareItem item in items)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                      decoration: const BoxDecoration(
                        color: QyColors.surface,
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                      ),
                      child: ListTile(
                        leading: Icon(
                          item.kind == 'folder' ? Icons.folder_shared : Icons.link,
                          color: QyColors.primary,
                        ),
                        title: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: QyColors.ink),
                        ),
                        subtitle: Text(
                          <String>[
                            '下载 ${item.downloads}${item.maxDownloads > 0 ? '/${item.maxDownloads}' : ''} 次',
                            if (item.expiresAt > 0)
                              '过期 ${CloudRepository.relativeTime(item.expiresAt)}',
                            if (item.hasPassword) '有密码',
                          ].join(' · '),
                          style: const TextStyle(fontSize: 11, color: QyColors.muted),
                        ),
                        trailing: AdminOnly(
                          child: TextButton(
                            onPressed: () => _revoke(item),
                            child: const Text('撤销', style: TextStyle(fontSize: 11)),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
