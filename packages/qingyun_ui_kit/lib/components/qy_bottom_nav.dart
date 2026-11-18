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

/// 底部导航：纯白玻璃面（无模糊层）+ 选中态主色实心徽标 + 底部小圆点。
///
/// 对齐高保真设计稿：背景纯白、无顶部分隔线；首页选中时以主色实心圆
/// 作为徽标，其余项保持线性图标。真磨砂已在 [QyFrost] 处全局关闭。
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
    final Color fg = active ? QyColors.primary : QyColors.muted;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (active && item.icon == QyIcons.home)
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(color: QyColors.primary, shape: BoxShape.circle),
            )
          else
            QyIcon(item.icon, size: 26, color: fg),
          const SizedBox(height: 6),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 12,
              height: 1,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? QyColors.ink : QyColors.muted,
            ),
          ),
          const SizedBox(height: 6),
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
