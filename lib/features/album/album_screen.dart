import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

import '../../core/models/cloud_models.dart';
import '../../core/network/cloud_repository.dart';
import '../../widgets/proto_widgets.dart';

/// 08 相册：数据来自 lanflare 图片分类文件，点击进入真实在线预览。
/// 回忆视频属于运营能力（后端无对应算法接口），保留展示但标注为示例。
class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  final CloudRepository _repo = CloudRepository();
  late final Future<List<CloudFile>> _photosFuture =
      _repo.files(category: FileCategory.image);

  static const List<List<Color>> _palette = <List<Color>>[
    <Color>[Color(0xFF4C8DFF), Color(0xFF8FC0FF)],
    <Color>[QyColors.mint, Color(0xFF7FE6D6)],
    <Color>[QyColors.amber, Color(0xFFFFD98A)],
    <Color>[Color(0xFFA78BFF), Color(0xFFCFC0FF)],
    <Color>[QyColors.pink, Color(0xFFFFB6C9)],
    <Color>[Color(0xFF5EA2EF), Color(0xFF8FD0F2)],
  ];

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: QyColors.canvas,
      child: ListView(
        physics: qyProtoScrollPhysics,
        padding: const EdgeInsets.only(bottom: 26),
        children: <Widget>[
          ProtoNav(
            title: '照片',
            subtitle: '云端图片 · 点击进入在线查看',
            leading: ProtoIconButton(
              icon: Icons.arrow_back,
              onTap: () => context.go(QyRoutes.files),
            ),
          ),
          const _MemoryBanner(),
          const _AlbumHead(title: '全部照片'),
          FutureBuilder<List<CloudFile>>(
            future: _photosFuture,
            builder: (BuildContext context, AsyncSnapshot<List<CloudFile>> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                return QyEmptyState(
                  icon: QyIcons.image,
                  title: '还没有云端照片',
                  description: snapshot.hasError
                      ? '加载失败：${snapshot.error}'
                      : '上传图片后会在这里展示',
                );
              }
              final List<CloudFile> photos = snapshot.data!;
              final List<Widget> rows = <Widget>[];
              for (int i = 0; i < photos.length; i += 3) {
                rows.add(_PhotoRow(
                  files: photos.sublist(
                    i,
                    (i + 3 > photos.length) ? photos.length : i + 3,
                  ),
                  palette: _palette,
                ));
                rows.add(const SizedBox(height: 3));
              }
              return Column(children: rows);
            },
          ),
          const ProtoFootNote(
            '图片来自云端文件列表 · 点击进入在线查看',
            padding: EdgeInsets.fromLTRB(0, 20, 0, 6),
          ),
        ],
      ),
    );
  }
}

class _MemoryBanner extends StatelessWidget {
  const _MemoryBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child: Container(
          height: 112,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-0.64, -0.77),
              end: Alignment(0.64, 0.77),
              colors: <Color>[QyColors.primary, Color(0xFF5AA9FF), Color(0xFF37C9B4)],
            ),
          ),
          child: const Stack(
            children: <Widget>[
              Positioned(
                right: 16,
                bottom: 14,
                child: Icon(Icons.play_circle_filled, size: 26, color: QyColors.onDark),
              ),
              Padding(
                padding: EdgeInsets.all(14),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '我的照片回忆',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: QyColors.onDark,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        '示例内容 · 暂未接入回忆生成服务',
                        style: TextStyle(fontSize: 11, color: Color(0xCCFFFFFF)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlbumHead extends StatelessWidget {
  const _AlbumHead({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: QyColors.ink),
      ),
    );
  }
}

class _PhotoRow extends StatelessWidget {
  const _PhotoRow({required this.files, required this.palette});

  final List<CloudFile> files;
  final List<List<Color>> palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < files.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              child: _Photo(
                file: files[i],
                colors: palette[i % palette.length],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.file, required this.colors});

  final CloudFile file;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return QyTapScale(
      onTap: () => context.go(QyRoutes.preview, extra: file),
      child: Container(
        height: 118,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: const Alignment(-0.77, -0.64),
            end: const Alignment(0.77, 0.64),
            colors: colors,
          ),
        ),
        child: Stack(
          children: <Widget>[
            const Center(child: Icon(Icons.image, size: 24, color: Color(0x8CFFFFFF))),
            Positioned(
              left: 6,
              right: 6,
              bottom: 5,
              child: Text(
                file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
