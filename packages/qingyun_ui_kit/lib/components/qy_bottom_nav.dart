import 'package:flutter/material.dart';
import '../theme/qy_colors.dart';
import '../theme/qy_tokens.dart';
import 'qy_frost.dart';
import 'qy_icon.dart';

class QyBottomNavItem {
  const QyBottomNavItem({required this.label, required this.icon});

  final String label;
  final String icon;
}

const List<QyBottomNavItem> qyDefaultNavItems = <QyBottomNavItem>[
  QyBottomNavItem(label: '首页', icon: QyIcons.home),
  QyBottomNavItem(label: '文件', icon: QyIcons.folder),
  QyBottomNavItem(label: '传输', icon: QyIcons.transfer),
  QyBottomNavItem(label: '我的', icon: QyIcons.user),
];

/// 底部导航：磨砂玻璃面 + 顶部细分隔线；选中项为主色图标/文字 + 底部小圆点。
class QyBottomNav extends StatelessWidget {
  const QyBottomNav({
    super.key,
    required this.currentIndex,
    required this.onChanged,
    this.items = qyDefaultNavItems,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;
  final List<QyBottomNavItem> items;

  @override
  Widget build(BuildContext context) {
    return QyFrost(
      color: QyColors.frostStrong,
      blur: 20,
      showBorder: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: QyColors.divider, width: 1)),
        ),
        child: SizedBox(
          height: QyTokens.navHeight,
          child: Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 18),
            child: Row(
              children: <Widget>[
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _NavItem(
                      item: items[i],
                      active: i == currentIndex,
                      onTap: () => onChanged(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.item, required this.active, required this.onTap});

  final QyBottomNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? QyColors.primary : QyColors.muted;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          QyIcon(item.icon, size: 22, color: color),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 11,
              height: 1,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: QyTokens.shortMotion,
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: active ? QyColors.primary : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
