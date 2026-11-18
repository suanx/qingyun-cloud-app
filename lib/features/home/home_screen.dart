import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

import '../../widgets/proto_widgets.dart';

/// 01 首页 · 存储概览（对齐 screen-home）。
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
              const _HeroContent(),
              Expanded(
                child: ListView(
                  physics: qyProtoScrollPhysics,
                  padding: const EdgeInsets.only(bottom: 96),
                  children: <Widget>[
                    _StorageCard(onTap: () => context.go(QyRoutes.storage)),
                    const _QuickGrid(),
                    ProtoSectionHead(
                      title: '最近文件',
                      more: '全部',
                      onMore: () => context.go(QyRoutes.files),
                    ),
                    _RecentRow(onTap: () => context.go(QyRoutes.preview)),
                    const ProtoSectionHead(
                      title: '为你推荐',
                      padding: EdgeInsets.fromLTRB(18, 20, 18, 2),
                    ),
                    _MemoryCard(onTap: () => context.go(QyRoutes.album)),
                  ],
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
  const _HeroContent();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 58, 18, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('下午好', style: ProtoText.heroHi),
                SizedBox(height: 4),
                Text('林小轻', style: ProtoText.heroName),
              ],
            ),
          ),
          ProtoIconButton(
            icon: Icons.search,
            glass: true,
            onTap: () => context.go(QyRoutes.search),
          ),
          const SizedBox(width: 8),
          ProtoIconButton(
            icon: Icons.qr_code_scanner,
            glass: true,
            onTap: () => showQyToast(context, '扫一扫：可扫描文档上传'),
          ),
          const SizedBox(width: 8),
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

/// 容量卡：环形进度 68% + 分段进度条 + 升级按钮。
class _StorageCard extends StatelessWidget {
  const _StorageCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
              const _Ring(),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text('存储空间', style: ProtoText.label11),
                    SizedBox(height: 3),
                    Text.rich(
                      TextSpan(
                        style: ProtoText.value14,
                        children: <TextSpan>[
                          TextSpan(text: '174.2 GB '),
                          TextSpan(
                            text: '/ 256 GB',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: QyColors.muted),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                    _StorageBar(),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _UpgradeButton(
                label: '升级',
                onTap: () => showQyToast(context, '升级会员，最高 2TB 空间'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring();

  @override
  Widget build(BuildContext context) {
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
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  stops: <double>[0, 0.68, 0.68, 1],
                  colors: <Color>[
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
          const Text(
            '68%',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: QyColors.primary),
          ),
        ],
      ),
    );
  }
}

class _StorageBar extends StatelessWidget {
  const _StorageBar();

  @override
  Widget build(BuildContext context) {
    return const ClipRRect(
      borderRadius: BorderRadius.all(Radius.circular(2)),
      child: SizedBox(
        height: 4,
        child: Row(
          children: <Widget>[
            Expanded(flex: 36, child: ColoredBox(color: Color(0xFF4C8DFF))),
            Expanded(flex: 20, child: ColoredBox(color: QyColors.mint)),
            Expanded(flex: 8, child: ColoredBox(color: QyColors.amber)),
            Expanded(flex: 4, child: ColoredBox(color: Color(0xFFA78BFF))),
            Expanded(flex: 32, child: ColoredBox(color: QyColors.track)),
          ],
        ),
      ),
    );
  }
}

/// 原型通用「升级 / 立即开通」渐变胶囊。
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
  const _QuickGrid();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 4),
      child: Row(
        children: <Widget>[
          _QuickItem(
            icon: Icons.cloud_upload,
            iconColor: QyColors.primary,
            background: QyColors.primaryLight,
            label: '上传',
            onTap: () => showQyToast(context, '选择文件上传中…'),
          ),
          _QuickItem(
            icon: Icons.create_new_folder,
            iconColor: QyColors.mintDeep,
            background: QyColors.mintSoft,
            label: '新建',
            onTap: () => showQyToast(context, '新建文件夹'),
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
            onTap: () => showQyToast(context, '回收站：12 个文件'),
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

/// 最近文件横滑卡片。
class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.onTap});

  final VoidCallback onTap;

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
            _FileCard(
              colors: const <Color>[Color(0xFF4C8DFF), Color(0xFF7FB6FF)],
              icon: Icons.image,
              name: '海边日落.jpg',
              meta: '今天 14:22 · 4.2 MB',
              onTap: onTap,
            ),
            _FileCard(
              colors: const <Color>[QyColors.mint, Color(0xFF63E0CB)],
              icon: Icons.description,
              name: '项目方案.pptx',
              meta: '今天 11:05 · 12.4 MB',
              onTap: onTap,
            ),
            _FileCard(
              colors: const <Color>[QyColors.amber, Color(0xFFFFD27A)],
              icon: Icons.movie,
              name: '4K 风景.mp4',
              meta: '昨天 · 386 MB',
              onTap: onTap,
            ),
            _FileCard(
              colors: const <Color>[Color(0xFFA78BFF), Color(0xFFC9B8FF)],
              icon: Icons.picture_as_pdf,
              name: '年度报告.pdf',
              meta: '昨天 · 8.6 MB',
              onTap: onTap,
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
  });

  final List<Color> colors;
  final IconData icon;
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
                  child: Icon(icon, size: 30, color: const Color(0xEBFFFFFF)),
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
class _MemoryCard extends StatelessWidget {
  const _MemoryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text(
                      '相册回忆',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.4,
                        color: Color(0xCCFFFFFF),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '去年的今天 · 32 张照片',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: QyColors.onDark),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '在青岛的那几天，海风很好',
                      style: TextStyle(fontSize: 12, color: Color(0xD1FFFFFF)),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
