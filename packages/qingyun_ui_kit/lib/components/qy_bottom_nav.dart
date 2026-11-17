import 'package:flutter/material.dart';
import '../theme/qy_colors.dart';
import '../theme/qy_tokens.dart';
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
    return SizedBox(
      height: QyTokens.navHeight,
      child: Padding(
        padding: const EdgeInsets.only(top: 12, left: 21, right: 21, bottom: 21),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: QyColors.surface,
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: QyColors.border, width: 1),
            boxShadow: <BoxShadow>[QyTokens.softShadow(QyColors.warmShadow)],
          ),
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
    final color = active ? QyColors.ink : QyColors.muted;
    return AnimatedContainer(
      duration: QyTokens.shortMotion,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      decoration: BoxDecoration(
        color: active ? QyColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(26),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              QyIcon(item.icon, size: 18, color: color),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
