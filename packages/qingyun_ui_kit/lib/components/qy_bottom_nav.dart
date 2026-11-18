import 'package:flutter/material.dart';

import '../theme/qy_colors.dart';
import '../theme/qy_tokens.dart';
import 'qy_page_transitions.dart';

/// 原型底部导航：4 个 Tab，白色 94% 底 + 顶部分割线，高 74。
/// 选中态为蓝色图标 + 蓝色加粗文字（原型没有实心圆徽标）。
class QyBottomNav extends StatelessWidget {
  const QyBottomNav({
    super.key,
    required this.currentIndex,
    required this.onChanged,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;

  static const List<IconData> _icons = <IconData>[
    Icons.cloud,
    Icons.folder_open,
    Icons.swap_vert,
    Icons.person_outline,
  ];

  static const List<String> _labels = <String>['首页', '文件', '传输', '我的'];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: QyColors.navWhite,
        border: Border(top: BorderSide(color: QyColors.border, width: 1)),
      ),
      child: SizedBox(
        height: QyTokens.navHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 18),
          child: Row(
            children: <Widget>[
              for (var i = 0; i < _labels.length; i++)
                Expanded(child: _Tab(
                  icon: _icons[i],
                  label: _labels[i],
                  active: i == currentIndex,
                  onTap: () => onChanged(i),
                )),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          AnimatedScale(
            scale: active ? 1.04 : 1,
            duration: QyTokens.shortMotion,
            curve: qyProtoCurve,
            child: Icon(
              icon,
              size: 23,
              color: active ? QyColors.primary : QyColors.muted,
            ),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: QyTokens.shortMotion,
            curve: qyProtoCurve,
            style: TextStyle(
              fontSize: 10,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? QyColors.primary : QyColors.muted,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
