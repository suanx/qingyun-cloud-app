import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

import '../../widgets/proto_widgets.dart';

/// 08 相册（对齐 screen-album）。
class AlbumScreen extends StatelessWidget {
  const AlbumScreen({super.key});

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
            subtitle: '1,284 张 · 42.1 GB',
            leading: ProtoIconButton(
              icon: Icons.arrow_back,
              onTap: () => context.go(QyRoutes.files),
            ),
            actions: <Widget>[
              QyTapScale(
                onTap: () => showQyToast(context, '已进入多选模式'),
                child: const Text('选择', style: ProtoText.sectionMore),
              ),
            ],
          ),
          _MemoryBanner(onTap: () => showQyToast(context, '播放回忆视频')),
          const _AlbumHead(title: '今天', meta: '南京 · 6 张'),
          const _PhotoRow(big: true, items: <_PhotoSpec>[
            _PhotoSpec(<Color>[Color(0xFF4C8DFF), Color(0xFF8FC0FF)], Icons.photo_camera),
            _PhotoSpec(<Color>[QyColors.mint, Color(0xFF7FE6D6)], Icons.photo_camera),
          ]),
          const SizedBox(height: 3),
          const _PhotoRow(items: <_PhotoSpec>[
            _PhotoSpec(<Color>[QyColors.amber, Color(0xFFFFD98A)], Icons.photo_camera),
            _PhotoSpec(<Color>[Color(0xFFA78BFF), Color(0xFFCFC0FF)], Icons.photo_camera),
            _PhotoSpec(<Color>[QyColors.pink, Color(0xFFFFB6C9)], Icons.photo_camera),
          ]),
          const _AlbumHead(title: '本周', meta: '11 月 12 日 - 17 日 · 18 张'),
          const _PhotoRow(items: <_PhotoSpec>[
            _PhotoSpec(<Color>[QyColors.primary, Color(0xFF6FA8FF)], Icons.landscape),
            _PhotoSpec(<Color>[Color(0xFF12A88F), Color(0xFF5AD8C4)], Icons.landscape),
            _PhotoSpec(<Color>[Color(0xFFE08A00), Color(0xFFFFC46B)], Icons.landscape),
          ]),
          const SizedBox(height: 3),
          const _PhotoRow(items: <_PhotoSpec>[
            _PhotoSpec(<Color>[Color(0xFF7B67F0), Color(0xFFB3A6FF)], Icons.landscape),
            _PhotoSpec(<Color>[Color(0xFF3C7CFF), Color(0xFF37C9B4)], Icons.landscape),
            _PhotoSpec(<Color>[Color(0xFFE04F7C), Color(0xFFFF9DB8)], Icons.landscape),
          ]),
          const _AlbumHead(title: '2025 年 10 月', meta: '青岛 · 32 张'),
          const _PhotoRow(items: <_PhotoSpec>[
            _PhotoSpec(<Color>[Color(0xFF4C8DFF), Color(0xFF9CC8FF)], Icons.beach_access),
            _PhotoSpec(<Color>[QyColors.mint, Color(0xFF9BEBDD)], Icons.beach_access),
            _PhotoSpec(<Color>[QyColors.amber, Color(0xFFFFE3A8)], Icons.beach_access),
          ]),
          const ProtoFootNote('已开启自动备份 · 仅 Wi-Fi 上传',
              padding: EdgeInsets.fromLTRB(0, 20, 0, 6)),
        ],
      ),
    );
  }
}

class _MemoryBanner extends StatelessWidget {
  const _MemoryBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: QyTapScale(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          child: Container(
            height: 140,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-0.64, -0.77),
                end: Alignment(0.64, 0.77),
                stops: <double>[0, 0.55, 1],
                colors: <Color>[QyColors.primary, Color(0xFF5AA9FF), Color(0xFF37C9B4)],
              ),
            ),
            child: const Stack(
              children: <Widget>[
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        stops: <double>[0, 0.65],
                        colors: <Color>[Color(0x730A1932), Color(0x000A1932)],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(14),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('2026 · 我的这一年',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: QyColors.onDark)),
                        SizedBox(height: 3),
                        Text('自动生成的 1 分 24 秒回忆',
                            style: TextStyle(fontSize: 11, color: Color(0xCCFFFFFF))),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: Icon(Icons.play_circle_filled, size: 26, color: QyColors.onDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AlbumHead extends StatelessWidget {
  const _AlbumHead({required this.title, required this.meta});

  final String title;
  final String meta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: <Widget>[
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: QyColors.ink)),
          const Spacer(),
          Text(meta, style: ProtoText.label105),
        ],
      ),
    );
  }
}

class _PhotoSpec {
  const _PhotoSpec(this.colors, this.icon);

  final List<Color> colors;
  final IconData icon;
}

/// 一行照片：big 时第一张占两列，其余行等分三列。
class _PhotoRow extends StatelessWidget {
  const _PhotoRow({required this.items, this.big = false});

  final List<_PhotoSpec> items;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Row(
        children: <Widget>[
          for (var i = 0; i < items.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              flex: big && i == 0 ? 2 : 1,
              child: _Photo(spec: items[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.spec});

  final _PhotoSpec spec;

  @override
  Widget build(BuildContext context) {
    return QyTapScale(
      onTap: () => context.go(QyRoutes.preview),
      child: Container(
        height: 118,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: const Alignment(-0.77, -0.64),
            end: const Alignment(0.77, 0.64),
            colors: spec.colors,
          ),
        ),
        child: Center(
          child: Icon(spec.icon, size: 24, color: const Color(0x8CFFFFFF)),
        ),
      ),
    );
  }
}
