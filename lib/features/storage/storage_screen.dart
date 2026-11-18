import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

import '../../widgets/proto_widgets.dart';

/// 06 存储空间（对齐 screen-storage）。
class StorageScreen extends StatelessWidget {
  const StorageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: QyColors.canvas,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 26),
        children: <Widget>[
          ProtoNav(
            title: '存储空间',
            leading: ProtoIconButton(
              icon: Icons.arrow_back,
              onTap: () => context.go(QyRoutes.profile),
            ),
            actions: <Widget>[
              QyTapScale(
                onTap: () => showQyToast(context, '空间管理'),
                child: const Text('管理', style: ProtoText.sectionMore),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const _Donut(),
          const _LegendGrid(),
          const _CleanCard(),
          const _UpgradeCard(),
          const ProtoFootNote('空间每 5 分钟同步一次',
              padding: EdgeInsets.fromLTRB(0, 4, 0, 10)),
        ],
      ),
    );
  }
}

class _Donut extends StatelessWidget {
  const _Donut();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 172,
        height: 172,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Transform.rotate(
              angle: -math.pi / 2,
              child: Container(
                width: 172,
                height: 172,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    stops: <double>[0, 0.244, 0.244, 0.446, 0.446, 0.581, 0.581, 0.68, 0.68, 1],
                    colors: <Color>[
                      Color(0xFF4C8DFF),
                      Color(0xFF4C8DFF),
                      QyColors.mint,
                      QyColors.mint,
                      QyColors.amber,
                      QyColors.amber,
                      Color(0xFFA78BFF),
                      Color(0xFFA78BFF),
                      Color(0xFFE9EEF7),
                      Color(0xFFE9EEF7),
                    ],
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: Color(0x661F4899), blurRadius: 34, offset: Offset(0, 16), spreadRadius: -18),
                  ],
                ),
              ),
            ),
            Container(
              width: 124,
              height: 124,
              decoration: const BoxDecoration(color: QyColors.surface, shape: BoxShape.circle),
            ),
            const Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -1, color: QyColors.ink),
                    children: <TextSpan>[
                      TextSpan(text: '68'),
                      TextSpan(
                        text: '%',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: QyColors.muted),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 3),
                Text('174.2 / 256 GB', style: ProtoText.label105),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendGrid extends StatelessWidget {
  const _LegendGrid();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              _LegendItem(
                color: const Color(0xFF4C8DFF),
                name: '照片',
                value: '62.4',
                onTap: () => showQyToast(context, '照片：62.4 GB'),
              ),
              const SizedBox(width: 10),
              _LegendItem(
                color: QyColors.mint,
                name: '视频',
                value: '51.8',
                onTap: () => showQyToast(context, '视频：51.8 GB'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _LegendItem(
                color: QyColors.amber,
                name: '文档',
                value: '34.6',
                onTap: () => showQyToast(context, '文档：34.6 GB'),
              ),
              const SizedBox(width: 10),
              _LegendItem(
                color: const Color(0xFFA78BFF),
                name: '其他',
                value: '25.4',
                onTap: () => showQyToast(context, '其他：25.4 GB'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.name,
    required this.value,
    required this.onTap,
  });

  final Color color;
  final String name;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: QyTapScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
          decoration: const BoxDecoration(
            color: QyColors.surface,
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(name, style: const TextStyle(fontSize: 11.5, color: QyColors.sub)),
                ],
              ),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: QyColors.ink),
                  children: <TextSpan>[
                    TextSpan(text: value),
                    const TextSpan(
                      text: 'GB',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w400, color: QyColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CleanCard extends StatelessWidget {
  const _CleanCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: QyColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: const Color(0xFFEDF3FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.auto_awesome, size: 19, color: QyColors.mint),
              SizedBox(width: 9),
              Text('为你找到 4.6 GB 可清理',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: QyColors.ink)),
              Spacer(),
              Text('智能整理', style: ProtoText.label105),
            ],
          ),
          const SizedBox(height: 12),
          const _CleanRow(label: '重复照片 218 张', size: '1.8 GB'),
          const _CleanRow(label: '超过 100MB 的大文件', size: '2.1 GB'),
          const _CleanRow(label: '空文件夹 12 个', size: '0.7 GB'),
          const SizedBox(height: 10),
          QyTapScale(
            onTap: () => showQyToast(context, '正在清理 4.6 GB 空间…'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                gradient: LinearGradient(
                  begin: Alignment(-0.5, -0.87),
                  end: Alignment(0.5, 0.87),
                  colors: <Color>[Color(0xFF3C7CFF), QyColors.primary],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(color: Color(0xB32F6BFF), blurRadius: 18, offset: Offset(0, 8), spreadRadius: -8),
                ],
              ),
              child: const Center(
                child: Text('一键清理',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: QyColors.onDark)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CleanRow extends StatelessWidget {
  const _CleanRow({required this.label, required this.size});

  final String label;
  final String size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: QyColors.divider)),
      ),
      child: Row(
        children: <Widget>[
          Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF475467))),
          const Spacer(),
          Text(size, style: const TextStyle(fontSize: 11.5, color: QyColors.muted)),
        ],
      ),
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.all(15),
      decoration: const BoxDecoration(
        color: QyColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(QyTokens.radiusLg)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.workspace_premium, size: 19, color: QyColors.amber),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('升级至 2TB',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: QyColors.ink)),
                SizedBox(height: 3),
                Text('首年 ¥168，含不限速传输', style: ProtoText.label105),
              ],
            ),
          ),
          QyTapScale(
            onTap: () => showQyToast(context, '开通轻云会员'),
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
              child: const Text('立即开通',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: QyColors.onDark)),
            ),
          ),
        ],
      ),
    );
  }
}
