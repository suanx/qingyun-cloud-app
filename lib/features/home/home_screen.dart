import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';
import '../../core/models/cloud_models.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/cloud_repository.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/error_reporter.dart';
import '../../core/utils/upload_helper.dart';
import '../../widgets/proto_widgets.dart';
import '../../core/config/admin_gate.dart';

/// 01 首页 · 存储概览（对齐 screen-home）。容量与最近文件来自 lanflare。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CloudRepository _repo = CloudRepository();
  StorageSummary? _summary;
  List<CloudFile> _recent = <CloudFile>[];
  AccountStatus? _status;
  DailyRecall? _recall;
  bool _recallLoading = true;
  bool _recallFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final summary = await _repo.storageSummary();
      if (!mounted) return;
      setState(() => _summary = summary);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'home_screen#1');
      // 容量加载失败时保持占位展示，不打断首页。
    }
    try {
      final files = await _repo.files();
      if (!mounted) return;
      setState(() => _recent = files.take(6).toList());
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'home_screen#2');
      // 最近文件加载失败时保持空列表。
    }
    try {
      final status = await _repo.accountStatus();
      if (!mounted) return;
      setState(() => _status = status);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'home_screen#status');
      // 账户信息加载失败时头图保留中性占位。
    }
    try {
      final DailyRecall recall = await _repo.dailyRecall();
      if (!mounted) return;
      setState(() {
        _recall = recall;
        _recallLoading = false;
        _recallFailed = false;
      });
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'home_screen#recall');
      if (!mounted) return;
      setState(() {
        _recallFailed = true;
        _recallLoading = false;
      });
    }
  }

  /// 容量卡「升级」：admin 直达会员管理页，普通用户展示真实会员状态。
  /// 不接支付渠道。
  Future<void> _openMembership() async {
    final status = _status;
    if (status == null) {
      showQyToast(context, '账户状态加载中，请稍后重试', success: false);
      return;
    }
    if (status.isAdmin) {
      await context.push<bool>(AppRouter.adminVip);
      await _load();
    } else {
      showQyToast(context, status.vipSubtitle);
    }
  }

  /// 选择本地文件并上传（自动分块大文件）。
  Future<void> _upload() async {
    try {
      final CloudFile? file = await UploadHelper.pickAndUpload();
      if (file == null || !mounted) return;
      showQyToast(context, '已上传 ${file.name}', success: true);
      await _load();
    } on ApiException catch (e) {
      // 用户在传输页点了「暂停」：请求是主动取消的，不是失败，状态已由
      // 任务模型落地，这里不弹错误 toast。
      if (e.isCancelled || !mounted) return;
      showQyToast(context, '上传失败：${e.message}');
    } catch (e) {
      if (mounted) showQyToast(context, '上传失败：$e');
    }
  }

  /// 新建文件夹（lanflare POST /api/mkdir）。
  Future<void> _createFolder() async {
    final TextEditingController controller = TextEditingController();
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('新建文件夹'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入文件夹名称'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await _repo.createFolder(name);
      if (!mounted) return;
      showQyToast(context, '文件夹已创建', success: true);
      await _load();
    } catch (e) {
      if (mounted) showQyToast(context, '创建失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 头图（渐变 + 问候语 + 右上角按钮）固定不滚动，下方内容区单独滚动。
    // 滚动区从「头图内容底部」开始，渐变底层多铺 38px：容量卡的第一帧正好
    // 叠进渐变尾部 38px，与原型 margin:-38px 一致；滚动时内容被滚动区顶部
    // 边界裁掉，不会盖到固定头图上。
    return ColoredBox(
      color: QyColors.canvas,
      child: Stack(
        children: <Widget>[
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 160,
            child: _HeroBackground(),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _HeroContent(name: _status?.displayName),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: qyProtoScrollPhysics,
                    padding: const EdgeInsets.only(bottom: 96),
                    children: <Widget>[
                      _StorageCard(
                        summary: _summary,
                        onTap: () => context.go(QyRoutes.storage),
                        onUpgrade: _openMembership,
                      ),
                      _QuickGrid(
                        onUpload: _upload,
                        onCreateFolder: _createFolder,
                      ),
                      ProtoSectionHead(
                        title: '最近文件',
                        more: '全部',
                        onMore: () => context.go(QyRoutes.files),
                      ),
                      _RecentRow(
                        files: _recent,
                        onTap: (CloudFile file) =>
                            context.go(QyRoutes.preview, extra: file),
                      ),
                      const ProtoSectionHead(
                        title: '为你推荐',
                        padding: EdgeInsets.fromLTRB(18, 20, 18, 2),
                      ),
                      _MemoryCard(
                        recall: _recall,
                        loading: _recallLoading,
                        failed: _recallFailed,
                        onTap: () => context.go(QyRoutes.album),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 固定渐变背景：168deg #E4EEFF → #EFF4FF 58% → #F5F7FB，右上薄荷径向光晕。
/// 高度 160 = 头图内容约 118 + 容量卡叠入的 38 + 少量余量。
class _HeroBackground extends StatelessWidget {
  const _HeroBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned(
          right: -40,
          top: -30,
          child: Container(
            width: 190,
            height: 190,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                stops: <double>[0, 0.68],
                colors: <Color>[Color(0x2922C7AC), Color(0x0022C7AC)],
              ),
            ),
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-0.208, -0.978),
                end: Alignment(0.208, 0.978),
                stops: <double>[0, 0.58, 1],
                colors: <Color>[
                  Color(0xFFE4EEFF),
                  Color(0xFFEFF4FF),
                  QyColors.canvas,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 固定的头图内容：问候语 + 搜索 / 扫一扫 / 头像，背景透明（渐变由底层提供）。
class _HeroContent extends StatelessWidget {
  const _HeroContent({this.name});

  /// 真实用户名；未加载时为 null，显示中性占位。
  final String? name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 58, 18, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('你好', style: ProtoText.heroHi),
                const SizedBox(height: 4),
                Text(
                  name ?? '轻云用户',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ProtoText.heroName,
                ),
              ],
            ),
          ),
          ProtoIconButton(
            icon: Icons.search,
            glass: true,
            onTap: () => context.go(QyRoutes.search),
          ),
          const SizedBox(width: 8),
          // 扫码转存会写入 VFS，普通用户为只读：入口直接不渲染，避免点了拿 403。
          AdminOnly(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ProtoIconButton(
                  icon: Icons.qr_code_scanner,
                  glass: true,
                  onTap: () => context.push(AppRouter.scan),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          _Avatar(onTap: () => context.go(QyRoutes.profile)),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return QyTapScale(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment(-0.77, -0.64),
            end: Alignment(0.77, 0.64),
            colors: <Color>[Color(0xFF4C8DFF), Color(0xFF7FD9CE)],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(color: Color(0x402F6BFF), blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: const Center(
          child: Text(
            '轻',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: QyColors.onDark),
          ),
        ),
      ),
    );
  }
}

/// 容量卡：环形进度 + 分段进度条 + 升级按钮。数据来自 lanflare 容量概览。
class _StorageCard extends StatelessWidget {
  const _StorageCard({
    required this.onTap,
    required this.onUpgrade,
    this.summary,
  });

  final VoidCallback onTap;
  final VoidCallback onUpgrade;
  final StorageSummary? summary;

  @override
  Widget build(BuildContext context) {
    final summary = this.summary;
    final usedLabel =
        summary == null ? '— GB' : '${summary.usedGb.toStringAsFixed(1)} GB';
    final totalLabel =
        summary == null ? '— GB' : '${summary.totalGb.toStringAsFixed(0)} GB';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: QyTapScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: QyColors.surface,
            borderRadius: BorderRadius.all(Radius.circular(20)),
            boxShadow: <BoxShadow>[
              BoxShadow(color: Color(0x291F4899), offset: Offset(0, 10), blurRadius: 26, spreadRadius: -8),
            ],
          ),
          child: Row(
            children: <Widget>[
              _Ring(ratio: summary?.ratio ?? 0),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text('存储空间', style: ProtoText.label11),
                    const SizedBox(height: 3),
                    Text.rich(
                      TextSpan(
                        style: ProtoText.value14,
                        children: <TextSpan>[
                          TextSpan(text: '$usedLabel '),
                          TextSpan(
                            text: '/ $totalLabel',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: QyColors.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _StorageBar(summary: summary),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _UpgradeButton(
                label: '升级',
                onTap: onUpgrade,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    final clamped = ratio.clamp(0.0, 1.0);
    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Transform.rotate(
            angle: -math.pi / 2,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  stops: <double>[0, clamped, clamped, 1],
                  colors: const <Color>[
                    QyColors.primary,
                    QyColors.primary,
                    Color(0xFFE9EFF9),
                    Color(0xFFE9EFF9),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(color: QyColors.surface, shape: BoxShape.circle),
          ),
          Text(
            '${(clamped * 100).round()}%',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: QyColors.primary),
          ),
        ],
      ),
    );
  }
}

/// 容量卡分段进度条：按 `GET /api/storage/summary` 的真实 `by_category`
/// 字节数分配四段（照片 / 视频 / 文档 / 音乐+压缩包），剩余为 track。
///
/// 第 19 步：原型把五段 flex 写死为 36/20/8/4/32，是装饰用的编造占比；
/// 现在与同页容量环、数字、「存储空间」页 2×2 图例共用同一份真实数据。
/// 未取到数据时整条中性灰，**不编造任何占比**。
class _StorageBar extends StatelessWidget {
  const _StorageBar({this.summary});

  final StorageSummary? summary;

  static const double _gb = 1024 * 1024 * 1024;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(2)),
      child: SizedBox(
        height: 4,
        child: Row(children: _segments(summary)),
      ),
    );
  }

  static List<Widget> _segments(StorageSummary? data) {
    final List<Color> colors = <Color>[
      const Color(0xFF4C8DFF), // 照片
      QyColors.mint, // 视频
      QyColors.amber, // 文档
      const Color(0xFFA78BFF), // 音乐 / 压缩包
    ];
    if (data == null || data.totalGb <= 0) {
      // 加载中 / 失败：整条中性 track，与容量环 ratio=0 的表现一致。
      return <Widget>[
        const Expanded(child: ColoredBox(color: QyColors.track)),
      ];
    }
    final StorageCategoryStats c = data.byCategory;
    final int totalBytes = (data.totalGb * _gb).round();
    final List<int> bytes = <int>[
      c.image,
      c.video,
      c.doc,
      c.music + c.archive,
    ];
    final List<Widget> out = <Widget>[];
    int used = 0;
    for (int i = 0; i < bytes.length; i++) {
      final int b = bytes[i];
      if (b <= 0) continue; // 该分类为空就不画这一段，不编造 1% 假占比
      final int w = math.max(1, (b * 1000) ~/ totalBytes);
      out.add(Expanded(flex: w, child: ColoredBox(color: colors[i])));
      used += w;
    }
    // 剩余段至少留 1 份权重，保证 track 可见；超过 1000 时按相对权重分配。
    out.add(Expanded(
      flex: math.max(1, 1000 - used),
      child: const ColoredBox(color: QyColors.track),
    ));
    return out;
  }
}

/// 原型通用「升级 / 会员入口」渐变胶囊。
class _UpgradeButton extends StatelessWidget {
  const _UpgradeButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return QyTapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          gradient: LinearGradient(
            begin: Alignment(-0.7, -0.7),
            end: Alignment(0.7, 0.7),
            colors: <Color>[Color(0xFF3C7CFF), Color(0xFF6FA8FF)],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(color: Color(0x472F6BFF), blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: QyColors.onDark),
        ),
      ),
    );
  }
}

/// 四宫格快捷入口。
class _QuickGrid extends StatelessWidget {
  const _QuickGrid({
    required this.onUpload,
    required this.onCreateFolder,
  });

  final VoidCallback onUpload;
  final VoidCallback onCreateFolder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 4),
      child: Row(
        children: <Widget>[
          AdminOnly(
            child: _QuickItem(
              icon: Icons.cloud_upload,
              iconColor: QyColors.primary,
              background: QyColors.primaryLight,
              label: '上传',
              onTap: onUpload,
            ),
          ),
          AdminOnly(
            child: _QuickItem(
              icon: Icons.create_new_folder,
              iconColor: QyColors.mintDeep,
              background: QyColors.mintSoft,
              label: '新建',
              onTap: onCreateFolder,
            ),
          ),
          _QuickItem(
            icon: Icons.swap_vert,
            iconColor: QyColors.amberDeep,
            background: QyColors.amberSoft,
            label: '传输',
            onTap: () => context.go(QyRoutes.transfers),
          ),
          _QuickItem(
            icon: Icons.delete_outline,
            iconColor: QyColors.violetDeep,
            background: QyColors.violetSoft,
            label: '回收站',
            onTap: () => context.go(QyRoutes.trash),
          ),
        ],
      ),
    );
  }
}

class _QuickItem extends StatelessWidget {
  const _QuickItem({
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color background;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: QyTapScale(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: const BorderRadius.all(Radius.circular(15)),
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF475467)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 最近文件横滑卡片。数据来自 lanflare 文件列表（前 6 个）。
class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.files, required this.onTap});

  final List<CloudFile> files;
  final ValueChanged<CloudFile> onTap;

  static const List<List<Color>> _palette = <List<Color>>[
    <Color>[Color(0xFF4C8DFF), Color(0xFF7FB6FF)],
    <Color>[QyColors.mint, Color(0xFF63E0CB)],
    <Color>[QyColors.amber, Color(0xFFFFD27A)],
    <Color>[Color(0xFFA78BFF), Color(0xFFC9B8FF)],
    <Color>[QyColors.pink, Color(0xFFFFA8C2)],
    <Color>[Color(0xFF5EA2EF), Color(0xFF8FD0F2)],
  ];

  static const Map<FileCategory, IconData> _icons = <FileCategory, IconData>{
    FileCategory.image: Icons.image,
    FileCategory.doc: Icons.description,
    FileCategory.video: Icons.movie,
    FileCategory.music: Icons.library_music,
    FileCategory.zip: Icons.folder_zip,
    FileCategory.other: Icons.insert_drive_file,
    FileCategory.all: Icons.insert_drive_file,
  };

  @override
  Widget build(BuildContext context) {
    // 与胶囊行同理：用 Row 自然撑开高度，不再给横向列表写死高度，
    // 避免任何机型上把卡片底部的文件名 / 元信息裁掉。
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            if (files.isEmpty)
              _FileCard(
                colors: const <Color>[Color(0xFFE9EFF9), Color(0xFFF5F8FE)],
                icon: Icons.folder_open,
                iconColor: QyColors.muted,
                name: '暂无最近文件',
                meta: '上传后在这里展示',
                onTap: () {},
              )
            else
              for (var i = 0; i < files.length; i++)
                _FileCard(
                  colors: _palette[i % _palette.length],
                  icon: _icons[files[i].category] ?? Icons.insert_drive_file,
                  name: files[i].name,
                  meta: <String>[
                    if (files[i].updatedLabel.isNotEmpty) files[i].updatedLabel,
                    if (files[i].sizeLabel.isNotEmpty) files[i].sizeLabel,
                  ].join(' · '),
                  onTap: () => onTap(files[i]),
                ),
          ],
        ),
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({
    required this.colors,
    required this.icon,
    required this.name,
    required this.meta,
    required this.onTap,
    this.iconColor,
  });

  final List<Color> colors;
  final IconData icon;
  final Color? iconColor;
  final String name;
  final String meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: QyTapScale(
        onTap: onTap,
        child: Container(
          width: 126,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: QyColors.surface,
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            border: Border.all(color: const Color(0xFFF3F6FC)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                height: 74,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(11)),
                  gradient: LinearGradient(
                    begin: const Alignment(-0.77, -0.64),
                    end: const Alignment(0.77, 0.64),
                    colors: colors,
                  ),
                ),
                child: Center(
                  child: Icon(icon, size: 30, color: iconColor ?? const Color(0xEBFFFFFF)),
                ),
              ),
              const SizedBox(height: 9),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: QyColors.ink),
              ),
              const SizedBox(height: 3),
              // 106px 内容宽里放中文 + 数字 + 单位，真机字体略宽时会折行；
              // 用 scaleDown 保持单行完整显示（原型 .f-meta 亦为单行）。
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    meta,
                    maxLines: 1,
                    style: const TextStyle(fontSize: 10, color: QyColors.muted),
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

/// 为你推荐 · 相册回忆渐变卡。
///
/// 内容全部来自 `GET /api/recall/daily` 的真实聚合（往年今日 / 照片最多的一天），
/// 缩略图是后端签发的本人真实图片预览。加载中、失败、无数据均用中性文案，
/// 已改用真实数据，不再保留占位提示或任何编造数值 / 地点描述。
class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    required this.onTap,
    required this.recall,
    required this.loading,
    required this.failed,
  });

  final VoidCallback onTap;
  final DailyRecall? recall;
  final bool loading;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final DailyRecall? data = recall;
    final bool hasData =
        !loading && !failed && data != null && data.hasMemory;

    final String tag;
    final String headline;
    final String subtitle;
    if (loading) {
      tag = '相册回忆';
      headline = '正在整理回忆…';
      subtitle = '正在读取云端照片';
    } else if (failed) {
      tag = '相册回忆';
      headline = '回忆暂时无法加载';
      subtitle = '请稍后重新进入首页重试';
    } else if (!hasData) {
      tag = '相册回忆';
      headline = '暂无推荐内容';
      subtitle = '上传照片后会在这里生成回忆';
    } else {
      tag = data.tag;
      headline = data.title.isEmpty ? data.date : data.title;
      subtitle = data.subtitle;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: QyTapScale(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-0.82, -0.57),
                end: Alignment(0.82, 0.57),
                stops: <double>[0, 0.46, 1],
                colors: <Color>[QyColors.primary, Color(0xFF4E8BFF), Color(0xFF37C9B4)],
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(color: Color(0x8C2F6BFF), blurRadius: 30, offset: Offset(0, 14), spreadRadius: -12),
              ],
            ),
            child: Stack(
              children: <Widget>[
                Positioned(
                  right: -30,
                  bottom: -46,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: const BoxDecoration(
                      color: Color(0x21FFFFFF),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // 文字区是非 positioned 子项，决定 Stack 高度；右侧留白给缩略图。
                Padding(
                  padding: EdgeInsets.only(right: hasData ? 96 : 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        tag,
                        style: const TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.4,
                          color: Color(0xCCFFFFFF),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: QyColors.onDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xD1FFFFFF),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: const BoxDecoration(
                          color: Color(0x33FFFFFF),
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text('去看看', style: TextStyle(fontSize: 12, color: QyColors.onDark)),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward, size: 15, color: QyColors.onDark),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasData && data.photos.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 2,
                    child: _RecallThumbs(photos: data.photos),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 右上角叠放的真实照片缩略图（最多 3 张）。
///
/// URL 由后端用 `/api/preview/url` 同款 HMAC 签发，15 分钟有效；
/// 过期或 VPS 暂时取不到直链时，errorBuilder 退回半透明色块，
/// 文字区仍是真实数据，不会显示假图片或假数值。
class _RecallThumbs extends StatelessWidget {
  const _RecallThumbs({required this.photos});

  final List<RecallPhoto> photos;

  @override
  Widget build(BuildContext context) {
    final int count = photos.length > 3 ? 3 : photos.length;
    return SizedBox(
      width: 88,
      height: 64,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          for (int i = 0; i < count; i++)
            Positioned(
              left: i * 24.0,
              top: 3.0 + (i % 2) * 3,
              child: Transform.rotate(
                angle: (i - 1) * 0.10,
                child: Container(
                  width: 40,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0x33FFFFFF),
                    borderRadius: const BorderRadius.all(Radius.circular(7)),
                    border: Border.all(color: const Color(0xE6FFFFFF), width: 1.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: photos[i].hasPreview
                      ? Image.network(
                          photos[i].previewUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const _ThumbFallback(),
                        )
                      : const _ThumbFallback(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0x66FFFFFF), Color(0x22FFFFFF)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.image_outlined, size: 16, color: Color(0xCCFFFFFF)),
      ),
    );
  }
}
