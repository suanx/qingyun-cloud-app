import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

import '../../widgets/proto_widgets.dart';

/// 02 全部文件（对齐 screen-files）。
class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  int _chip = 0;

  static const List<String> _chips = <String>['全部', '文档', '图片', '视频', '音频'];

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: QyColors.canvas,
      child: Stack(
        children: <Widget>[
          ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: <Widget>[
              ProtoNav(
                title: '全部文件',
                subtitle: '我的云盘',
                subIcon: Icons.home,
                actions: <Widget>[
                  ProtoIconButton(icon: Icons.search, onTap: () => context.go(QyRoutes.search)),
                  ProtoIconButton(
                    icon: Icons.sort,
                    onTap: () => showQyToast(context, '排序：按修改时间'),
                  ),
                  ProtoIconButton(
                    icon: Icons.more_horiz,
                    onTap: () => showQyToast(context, '更多操作'),
                  ),
                ],
              ),
              ProtoChipRow(
                labels: _chips,
                activeIndex: _chip,
                onChanged: (int i) => setState(() => _chip = i),
              ),
              const _FolderGrid(),
              const ProtoSectionHead(
                title: '文件',
                more: '按修改时间',
                moreIcon: Icons.expand_more,
                padding: EdgeInsets.fromLTRB(18, 18, 18, 10),
              ),
              const _FileList(),
              const ProtoFootNote(
                '已显示全部 5 个文件',
                padding: EdgeInsets.only(top: 4, bottom: 4),
              ),
            ],
          ),
          Positioned(
            right: 18,
            bottom: 22,
            child: _Fab(onTap: () => showQyToast(context, '新建 / 上传 / 扫描')),
          ),
        ],
      ),
    );
  }
}

class _FolderGrid extends StatelessWidget {
  const _FolderGrid();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              _FolderCard(
                icon: Icons.folder,
                color: const Color(0xFF4C8DFF),
                name: '工作资料',
                meta: '24 个文件 · 8.6 GB',
                onTap: () => showQyToast(context, '进入「工作资料」'),
              ),
              const SizedBox(width: 10),
              _FolderCard(
                icon: Icons.folder,
                color: QyColors.mint,
                name: '我的照片',
                meta: '1,284 张 · 42.1 GB',
                onTap: () => context.go(QyRoutes.album),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _FolderCard(
                icon: Icons.folder,
                color: QyColors.amber,
                name: '学习资料',
                meta: '86 个文件 · 12.4 GB',
                onTap: () => showQyToast(context, '进入「学习资料」'),
              ),
              const SizedBox(width: 10),
              _FolderCard(
                icon: Icons.folder_shared,
                color: const Color(0xFFA78BFF),
                name: '家庭共享',
                meta: '3 位成员 · 6.2 GB',
                onTap: () => showQyToast(context, '进入「家庭共享」'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required this.icon,
    required this.color,
    required this.name,
    required this.meta,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String name;
  final String meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: QyTapScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: QyColors.surface,
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            border: Border.all(color: const Color(0xFFF3F6FC)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(icon, size: 28, color: color),
                  const Spacer(),
                  const Icon(Icons.more_horiz, size: 17, color: QyColors.hint),
                ],
              ),
              const SizedBox(height: 12),
              Text(name, style: ProtoText.name13w600),
              const SizedBox(height: 3),
              Text(meta, style: ProtoText.label105),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileList extends StatelessWidget {
  const _FileList();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: QyColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          _FileRow(
            icon: Icons.slideshow,
            iconColor: QyColors.primary,
            background: QyColors.primaryLight,
            name: 'Q4 项目方案.pptx',
            sub: '12.4 MB · 今天 11:05',
            onTap: () => context.go(QyRoutes.preview),
          ),
          _FileRow(
            icon: Icons.table_chart,
            iconColor: QyColors.mintDeep,
            background: QyColors.mintSoft,
            name: '家庭账单 11 月.xlsx',
            sub: '1.8 MB · 今天 09:32',
            onTap: () => context.go(QyRoutes.preview),
          ),
          _FileRow(
            icon: Icons.movie,
            iconColor: QyColors.amberDeep,
            background: QyColors.amberSoft,
            name: '4K 风景素材.mp4',
            sub: '386 MB · 昨天 20:14',
            onTap: () => context.go(QyRoutes.preview),
          ),
          _FileRow(
            icon: Icons.audio_file,
            iconColor: QyColors.violetDeep,
            background: QyColors.violetSoft,
            name: '周会录音 11-17.m4a',
            sub: '28.6 MB · 昨天 16:40',
            onTap: () => context.go(QyRoutes.preview),
          ),
          _FileRow(
            icon: Icons.picture_as_pdf,
            iconColor: QyColors.pinkDeep,
            background: QyColors.pinkSoft,
            name: '年度总结报告.pdf',
            sub: '8.6 MB · 11 月 15 日',
            onTap: () => context.go(QyRoutes.preview),
          ),
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.name,
    required this.sub,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color background;
  final String name;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return QyTapScale(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: QyColors.divider)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: <Widget>[
            ProtoTypeIcon(icon: icon, color: iconColor, background: background),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ProtoText.name135),
                  const SizedBox(height: 3),
                  Text(sub, style: ProtoText.label105),
                ],
              ),
            ),
            const Icon(Icons.more_vert, size: 20, color: QyColors.hint),
          ],
        ),
      ),
    );
  }
}

class _Fab extends StatelessWidget {
  const _Fab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return QyTapScale(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment(-0.77, -0.64),
            end: Alignment(0.77, 0.64),
            colors: <Color>[Color(0xFF3C7CFF), QyColors.primary],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(color: Color(0x992F6BFF), blurRadius: 24, offset: Offset(0, 12), spreadRadius: -6),
          ],
        ),
        child: const Icon(Icons.add, size: 26, color: QyColors.onDark),
      ),
    );
  }
}
