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

/// 底部导航：纯白玻璃面（无模糊层）+ 选中态主色圆底白图标 + 底部小圆点。
///
/// 选中项始终保留可辨识的图形：主色实心圆承载白色图标，而不是一个孤立
/// 的圆点；圆底颜色与图标缩放都带动画，切 Tab 时过渡柔和。
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
      color: QyColors.canvas,
      showBorder: false,
      child: SizedBox(
        height: QyTokens.navHeight,
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 14),
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          AnimatedScale(
            scale: active ? 1.06 : 1,
            duration: QyTokens.shortMotion,
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: QyTokens.shortMotion,
              curve: Curves.easeOutCubic,
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: active ? QyColors.primary : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: QyIcon(
                  item.icon,
                  size: active ? 19 : 24,
                  color: active ? QyColors.onDark : QyColors.muted,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          AnimatedDefaultTextStyle(
            duration: QyTokens.shortMotion,
            curve: Curves.easeOutCubic,
            style: TextStyle(
              fontSize: 11,
              height: 1,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? QyColors.ink : QyColors.muted,
            ),
            child: Text(item.label),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: QyTokens.shortMotion,
            curve: Curves.easeOutCubic,
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
