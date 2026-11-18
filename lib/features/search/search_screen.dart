import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

import '../../widgets/proto_widgets.dart';

/// 05 搜索（对齐 screen-search）。
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  static const List<String> _history = <String>[
    '项目方案',
    '旅行',
    '合同',
    '家庭账单',
    '设计稿',
  ];

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: QyColors.canvas,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 26),
        children: <Widget>[
          const _SearchBar(),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
            child: Row(
              children: <Widget>[
                const Text('搜索历史',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: QyColors.heroLabel)),
                const Spacer(),
                QyTapScale(
                  onTap: () => showQyToast(context, '已清空搜索历史'),
                  child: const Icon(Icons.delete_outline, size: 17, color: QyColors.hint),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final String tag in _history)
                  _Tag(label: tag, onTap: () => showQyToast(context, '搜索：$tag')),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 22, 18, 12),
            child: Text('热门搜索',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: QyColors.heroLabel)),
          ),
          _HotRow(
            rank: '1',
            top: true,
            text: '2026 年度总结',
            badge: '热',
            badgeNew: false,
            onTap: () => showQyToast(context, '搜索：2026 年度总结'),
          ),
          _HotRow(
            rank: '2',
            top: true,
            text: '旅行照片',
            badge: '新',
            badgeNew: true,
            onTap: () => showQyToast(context, '搜索：旅行照片'),
          ),
          _HotRow(
            rank: '3',
            top: true,
            text: '项目排期表',
            onTap: () => showQyToast(context, '搜索：项目排期表'),
          ),
          _HotRow(
            rank: '4',
            top: false,
            text: '发票扫描件',
            onTap: () => showQyToast(context, '搜索：发票'),
          ),
          _HotRow(
            rank: '5',
            top: false,
            text: '证件备份',
            onTap: () => showQyToast(context, '搜索：证件'),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 20, 18, 0),
            child: Text('快捷筛选',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: QyColors.heroLabel)),
          ),
          const SizedBox(height: 12),
          _ResultHint(
            icon: Icons.image,
            prefix: '图片 · ',
            bold: '1,284',
            suffix: ' 个文件，按拍摄地点聚合',
            onTap: () => context.go(QyRoutes.album),
          ),
          _ResultHint(
            icon: Icons.description,
            prefix: '文档 · ',
            bold: '96',
            suffix: ' 个文件，最近更新于今天',
            onTap: () => context.go(QyRoutes.files),
          ),
          _ResultHint(
            icon: Icons.swap_vert,
            prefix: '传输记录 · ',
            bold: '3',
            suffix: ' 个任务进行中',
            onTap: () => context.go(QyRoutes.transfers),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 54, 16, 14),
      child: Row(
        children: <Widget>[
          ProtoIconButton(
            icon: Icons.arrow_back,
            onTap: () => context.go(QyRoutes.files),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: QyColors.surface,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                border: Border.all(color: const Color(0xFFE6EDFA)),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Color(0x0A1F4899), blurRadius: 8, offset: Offset(0, 2)),
                ],
              ),
              child: const Row(
                children: <Widget>[
                  Icon(Icons.search, size: 19, color: QyColors.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: '搜索文件名 / 内容',
                        hintStyle: TextStyle(fontSize: 14, color: Color(0xFFA9B4C6)),
                      ),
                      style: TextStyle(fontSize: 14, color: QyColors.ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          QyTapScale(
            onTap: () => context.go(QyRoutes.files),
            child: const Text('取消', style: TextStyle(fontSize: 13, color: QyColors.sub)),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return QyTapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: QyColors.surface,
          border: Border.all(color: QyColors.border),
          borderRadius: const BorderRadius.all(Radius.circular(20)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF475467)),
        ),
      ),
    );
  }
}

class _HotRow extends StatelessWidget {
  const _HotRow({
    required this.rank,
    required this.top,
    required this.text,
    required this.onTap,
    this.badge,
    this.badgeNew = false,
  });

  final String rank;
  final bool top;
  final String text;
  final String? badge;
  final bool badgeNew;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: QyTapScale(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 17,
                child: Text(
                  rank,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    color: top ? QyColors.primary : QyColors.hint,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(text, style: const TextStyle(fontSize: 13.5, color: QyColors.ink)),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeNew ? const Color(0xFFFFEDF2) : const Color(0xFFFFF1E6),
                    borderRadius: const BorderRadius.all(Radius.circular(5)),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: badgeNew ? const Color(0xFFE04F7C) : const Color(0xFFE07B18),
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

class _ResultHint extends StatelessWidget {
  const _ResultHint({
    required this.icon,
    required this.prefix,
    required this.bold,
    required this.suffix,
    required this.onTap,
  });

  final IconData icon;
  final String prefix;
  final String bold;
  final String suffix;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: QyTapScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: const BoxDecoration(
            color: QyColors.surface,
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 19, color: QyColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: ProtoText.body125,
                    children: <TextSpan>[
                      TextSpan(text: prefix),
                      TextSpan(
                        text: bold,
                        style: const TextStyle(fontWeight: FontWeight.w600, color: QyColors.primary),
                      ),
                      TextSpan(text: suffix),
                    ],
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, size: 17, color: QyColors.chevron),
            ],
          ),
        ),
      ),
    );
  }
}
