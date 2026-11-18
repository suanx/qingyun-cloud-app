import 'package:flutter/material.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

import '../../widgets/proto_widgets.dart';

/// 03 传输中心（对齐 screen-transfer）。
class TransfersScreen extends StatefulWidget {
  const TransfersScreen({super.key});

  @override
  State<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends State<TransfersScreen> {
  int _chip = 0;

  static const List<String> _chips = <String>['正在传输', '已完成', '失败 1'];

  @override
  Widget build(BuildContext context) {
    // 红框区域（标题 / 副标题 / 全部暂停 + 速度卡 + 筛选胶囊）固定不滚动，
    // 下方任务列表与「今天已完成」单独滚动。等价原型 .nav / .transfer-sum /
    // .chip-row 的 flex-shrink:0 + .scroll flex:1。
    return ColoredBox(
      color: QyColors.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ProtoNav(
            title: '传输',
            subtitle: '3 个任务进行中',
            actions: <Widget>[
              QyTapScale(
                onTap: () => showQyToast(context, '已暂停全部任务'),
                child: const Text('全部暂停', style: ProtoText.sectionMore),
              ),
            ],
          ),
          const _SpeedCard(),
          ProtoChipRow(
            labels: _chips,
            activeIndex: _chip,
            onChanged: (int i) => setState(() => _chip = i),
          ),
          Expanded(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 100),
              children: const <Widget>[
                _TransferCard(
                  icon: Icons.movie,
                  iconColor: QyColors.amberDeep,
                  background: QyColors.amberSoft,
                  name: '4K 风景素材.mp4',
                  meta: '上传中 · 264 MB / 386 MB',
                  control: Icons.pause,
                  progress: 0.68,
                  footLeft: '68%',
                  footSpeed: ' · 2.4 MB/s',
                  footRight: '剩余 1 分钟',
                  toast: '已暂停',
                ),
                _TransferCard(
                  icon: Icons.audio_file,
                  iconColor: QyColors.violetDeep,
                  background: QyColors.violetSoft,
                  name: '周会录音 11-18.m4a',
                  meta: '上传中 · 9.2 MB / 28.6 MB',
                  control: Icons.pause,
                  progress: 0.32,
                  footLeft: '32%',
                  footSpeed: ' · 1.4 MB/s',
                  footRight: '剩余 1 分钟',
                  toast: '已暂停',
                ),
                _TransferCard(
                  icon: Icons.image,
                  iconColor: QyColors.primary,
                  background: QyColors.primaryLight,
                  name: '设计稿-首页.psd',
                  meta: '排队中 · 0 / 128 MB',
                  control: Icons.close,
                  progress: 0.02,
                  footLeft: '等待中',
                  footSpeed: '',
                  footRight: '—',
                  toast: '已取消',
                ),
                ProtoSectionHead(
                  title: '今天已完成',
                  more: '3 项',
                  moreIcon: Icons.chevron_right,
                  padding: EdgeInsets.fromLTRB(18, 16, 18, 10),
                ),
                _DoneList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedCard extends StatelessWidget {
  const _SpeedCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        gradient: LinearGradient(
          begin: Alignment(-0.5, -0.87),
          end: Alignment(0.5, 0.87),
          colors: <Color>[Color(0xFFEAF1FF), Color(0xFFE7F8F5)],
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: QyColors.surface,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: const Icon(Icons.bolt, size: 21, color: QyColors.primary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('当前速度 3.8 MB/s',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: QyColors.ink)),
                SizedBox(height: 2),
                Text('会员加速中 · 预计 2 分钟完成',
                    style: TextStyle(fontSize: 10.5, color: Color(0xFF6B7A93))),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 18, color: Color(0xFF8FA3BF)),
        ],
      ),
    );
  }
}

class _TransferCard extends StatelessWidget {
  const _TransferCard({
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.name,
    required this.meta,
    required this.control,
    required this.progress,
    required this.footLeft,
    required this.footSpeed,
    required this.footRight,
    required this.toast,
  });

  final IconData icon;
  final Color iconColor;
  final Color background;
  final String name;
  final String meta;
  final IconData control;
  final double progress;
  final String footLeft;
  final String footSpeed;
  final String footRight;
  final String toast;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: QyColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              ProtoTypeIcon(icon: icon, color: iconColor, background: background),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ProtoText.name135),
                    const SizedBox(height: 3),
                    Text(meta, style: ProtoText.label105),
                  ],
                ),
              ),
              QyTapScale(
                onTap: () => showQyToast(context, toast),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: QyColors.surface,
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(BorderSide(color: QyColors.border)),
                  ),
                  child: Icon(control, size: 17, color: const Color(0xFF475467)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(3)),
            child: SizedBox(
              height: 5,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progress,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(3)),
                      gradient: LinearGradient(
                        colors: <Color>[Color(0xFF4C8DFF), QyColors.mint],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 10, color: QyColors.muted),
                  children: <TextSpan>[
                    TextSpan(
                      text: footLeft,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: QyColors.primary),
                    ),
                    TextSpan(text: footSpeed),
                  ],
                ),
              ),
              const Spacer(),
              Text(footRight, style: const TextStyle(fontSize: 10, color: QyColors.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DoneList extends StatelessWidget {
  const _DoneList();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: QyColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      clipBehavior: Clip.antiAlias,
      child: const Column(
        children: <Widget>[
          _DoneRow(
            icon: Icons.check_circle,
            iconColor: QyColors.mintDeep,
            background: QyColors.mintSoft,
            name: '海边日落.jpg',
            sub: '4.2 MB · 上传完成 14:22',
          ),
          _DoneRow(
            icon: Icons.check_circle,
            iconColor: QyColors.primary,
            background: QyColors.primaryLight,
            name: 'Q4 项目方案.pptx',
            sub: '12.4 MB · 上传完成 11:05',
          ),
          _DoneRow(
            icon: Icons.check_circle,
            iconColor: QyColors.amberDeep,
            background: QyColors.amberSoft,
            name: '学习资料合集.zip',
            sub: '624 MB · 下载完成 09:12',
          ),
        ],
      ),
    );
  }
}

class _DoneRow extends StatelessWidget {
  const _DoneRow({
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.name,
    required this.sub,
  });

  final IconData icon;
  final Color iconColor;
  final Color background;
  final String name;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: QyColors.divider)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
    );
  }
}
