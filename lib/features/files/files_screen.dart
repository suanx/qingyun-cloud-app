import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

import '../../core/models/cloud_models.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/cloud_repository.dart';
import '../../widgets/proto_widgets.dart';

/// 02 全部文件（对齐 screen-files）。数据来自 lanflare（/api/list、/api/search）。
class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  final CloudRepository _repo = CloudRepository();

  int _chip = 0;
  bool _loading = true;
  String? _error;
  List<CloudFile> _files = <CloudFile>[];

  static const List<String> _chips = <String>['全部', '文档', '图片', '视频', '音频'];
  static const List<FileCategory> _categories = <FileCategory>[
    FileCategory.all,
    FileCategory.doc,
    FileCategory.image,
    FileCategory.video,
    FileCategory.music,
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final files = await _repo.files(category: _categories[_chip]);
      if (!mounted) return;
      setState(() {
        _files = files;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '加载失败，请检查网络后重试';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 红框区域（标题 / 面包屑 / 右上按钮 + 筛选胶囊 + 四个文件夹）固定不滚动，
    // 下方「文件」列表单独滚动；FAB 仍浮在右下角。等价原型 .nav / .chip-row /
    // .folders 的 flex-shrink:0 + .scroll flex:1。
    return ColoredBox(
      color: QyColors.canvas,
      child: Stack(
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                onChanged: (int i) {
                  setState(() => _chip = i);
                  _load();
                },
              ),
              const _FolderGrid(),
              Expanded(
                child: ListView(
                  physics: qyProtoScrollPhysics,
                  padding: const EdgeInsets.only(bottom: 100),
                  children: <Widget>[
                    const ProtoSectionHead(
                      title: '文件',
                      more: '按修改时间',
                      moreIcon: Icons.expand_more,
                      padding: EdgeInsets.fromLTRB(18, 18, 18, 10),
                    ),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null)
                      QyEmptyState(
                        title: '加载失败',
                        description: _error!,
                        actionLabel: '重新加载',
                        onAction: _load,
                      )
                    else if (_files.isEmpty)
                      const QyEmptyState(
                        title: '这里空空如也',
                        description: '当前分类下没有文件，试试上传或切换分类',
                      )
                    else ...<Widget>[
                      _FileList(files: _files),
                      ProtoFootNote(
                        '已显示全部 ${_files.length} 个文件',
                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                      ),
                    ],
                  ],
                ),
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
  const _FileList({required this.files});

  final List<CloudFile> files;

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
          for (final file in files)
            _FileRow(
              file: file,
              onTap: () => context.go(QyRoutes.preview),
            ),
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.file, required this.onTap});

  final CloudFile file;
  final VoidCallback onTap;

  static const Map<FileCategory, IconData> _icons = <FileCategory, IconData>{
    FileCategory.image: Icons.image,
    FileCategory.doc: Icons.table_chart,
    FileCategory.video: Icons.movie,
    FileCategory.music: Icons.audio_file,
    FileCategory.zip: Icons.folder_zip,
    FileCategory.other: Icons.insert_drive_file,
    FileCategory.all: Icons.insert_drive_file,
  };

  static const Map<FileCategory, Color> _tints = <FileCategory, Color>{
    FileCategory.image: QyColors.primary,
    FileCategory.doc: QyColors.mintDeep,
    FileCategory.video: QyColors.amberDeep,
    FileCategory.music: QyColors.violetDeep,
    FileCategory.zip: QyColors.pinkDeep,
    FileCategory.other: QyColors.sub,
    FileCategory.all: QyColors.sub,
  };

  static const Map<FileCategory, Color> _backgrounds = <FileCategory, Color>{
    FileCategory.image: QyColors.primaryLight,
    FileCategory.doc: QyColors.mintSoft,
    FileCategory.video: QyColors.amberSoft,
    FileCategory.music: QyColors.violetSoft,
    FileCategory.zip: QyColors.pinkSoft,
    FileCategory.other: QyColors.track,
    FileCategory.all: QyColors.track,
  };

  @override
  Widget build(BuildContext context) {
    final sub = <String>[
      if (file.sizeLabel.isNotEmpty) file.sizeLabel,
      if (file.updatedLabel.isNotEmpty) file.updatedLabel,
    ].join(' · ');
    return QyTapScale(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: QyColors.divider)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: <Widget>[
            ProtoTypeIcon(
              icon: _icons[file.category] ?? Icons.insert_drive_file,
              color: _tints[file.category] ?? QyColors.sub,
              background: _backgrounds[file.category] ?? QyColors.track,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ProtoText.name135),
                  if (sub.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(sub, style: ProtoText.label105),
                  ],
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
