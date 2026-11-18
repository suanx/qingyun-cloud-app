import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

import '../../widgets/proto_widgets.dart';

/// 07 文件预览（对齐 screen-preview，深色屏）。
class PreviewScreen extends StatelessWidget {
  const PreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 深色预览页：状态栏与导航栏图标切换为浅色。
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: ColoredBox(
        color: QyColors.darkBg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 54, 16, 10),
              child: Row(
                children: <Widget>[
                  ProtoIconButton(
                    icon: Icons.arrow_back,
                    color: const Color(0xFFDDE3EE),
                    onTap: () => context.go(QyRoutes.files),
                  ),
                  const Expanded(
                    child: Text(
                      '海边日落.jpg',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFFE6EAF2)),
                    ),
                  ),
                  ProtoIconButton(
                    icon: Icons.more_horiz,
                    color: const Color(0xFFDDE3EE),
                    onTap: () => showQyToast(context, '文件详情'),
                  ),
                ],
              ),
            ),
            const Expanded(child: _Photo()),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '2026年11月18日 14:22 · 4032 × 3024',
                      style: TextStyle(fontSize: 11, color: Color(0xFF8D99AD)),
                    ),
                  ),
                  Text('4.2 MB', style: TextStyle(fontSize: 11, color: Color(0xFF8D99AD))),
                ],
              ),
            ),
            const _Tools(),
          ],
        ),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      child: Center(
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          child: Container(
            height: 430,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-0.5, -0.87),
                end: Alignment(0.5, 0.87),
                stops: <double>[0, 0.42, 1],
                colors: <Color>[Color(0xFF1F4FD8), Color(0xFF4C8DFF), Color(0xFF37C9B4)],
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(color: Color(0xCC000000), blurRadius: 50, offset: Offset(0, 24), spreadRadius: -18),
              ],
            ),
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: -70,
                  bottom: -90,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: const BoxDecoration(color: Color(0x1FFFFFFF), shape: BoxShape.circle),
                  ),
                ),
                Positioned(
                  right: -40,
                  top: -50,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: const BoxDecoration(color: Color(0x1AFFFFFF), shape: BoxShape.circle),
                  ),
                ),
                const Center(
                  child: Icon(Icons.photo_camera, size: 64, color: Color(0x8CFFFFFF)),
                ),
                const Positioned(
                  bottom: 14,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      _Dot(active: true),
                      _Dot(active: false),
                      _Dot(active: false),
                      _Dot(active: false),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2.5),
      width: active ? 14 : 5,
      height: 5,
      decoration: BoxDecoration(
        color: active ? QyColors.onDark : const Color(0x6BFFFFFF),
        borderRadius: const BorderRadius.all(Radius.circular(3)),
      ),
    );
  }
}

class _Tools extends StatelessWidget {
  const _Tools();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 26),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _Tool(
            icon: Icons.share,
            label: '分享',
            onTap: () => showQyToast(context, '已生成分享链接，有效期 7 天'),
          ),
          _Tool(
            icon: Icons.download,
            label: '下载',
            onTap: () => showQyToast(context, '已保存到本地相册'),
          ),
          _Tool(
            icon: Icons.edit,
            label: '重命名',
            onTap: () => showQyToast(context, '重命名'),
          ),
          _Tool(
            icon: Icons.delete_outline,
            label: '删除',
            onTap: () => showQyToast(context, '已移入回收站'),
          ),
          _Tool(
            icon: Icons.info,
            label: '详情',
            onTap: () => context.go(QyRoutes.storage),
          ),
        ],
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return QyTapScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 21, color: const Color(0xFFC6CFDE)),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFFC6CFDE))),
          ],
        ),
      ),
    );
  }
}
