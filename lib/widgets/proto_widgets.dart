import 'package:flutter/material.dart';
import 'package:qingyun_ui_kit/qingyun_ui_kit.dart';

/// 原型文本样式常量：与 HTML 的 CSS 字号/字重一一对应。
abstract final class ProtoText {
  static const TextStyle heroHi = TextStyle(
    fontSize: 11,
    letterSpacing: 1.2,
    color: QyColors.heroLabel,
  );
  static const TextStyle heroName = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    color: QyColors.ink,
  );
  static const TextStyle navTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: QyColors.ink,
  );
  static const TextStyle navSub = TextStyle(fontSize: 11, color: QyColors.muted);
  static const TextStyle section = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: QyColors.ink,
  );
  static const TextStyle sectionMore = TextStyle(fontSize: 12, color: QyColors.muted);
  static const TextStyle label11 = TextStyle(fontSize: 11, color: QyColors.muted);
  static const TextStyle label105 = TextStyle(fontSize: 10.5, color: QyColors.muted);
  static const TextStyle label12 = TextStyle(fontSize: 12, color: QyColors.muted);
  static const TextStyle hint105 = TextStyle(fontSize: 10.5, color: QyColors.hint);
  static const TextStyle body125 = TextStyle(fontSize: 12.5, color: Color(0xFF475467));
  static const TextStyle body13 = TextStyle(fontSize: 13, color: QyColors.ink);
  static const TextStyle name135 = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w500,
    color: QyColors.ink,
  );
  static const TextStyle name13w600 = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: QyColors.ink,
  );
  static const TextStyle value14 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: QyColors.ink,
  );
}

/// 原型圆形图标按钮：34×34，可带半透明白玻璃底。
class ProtoIconButton extends StatelessWidget {
  const ProtoIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.glass = false,
    this.color = const Color(0xFF344054),
    this.size = 21,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool glass;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return QyTapScale(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: glass ? const Color(0xB8FFFFFF) : Colors.transparent,
          shape: BoxShape.circle,
          boxShadow: glass
              ? const <BoxShadow>[
                  BoxShadow(color: Color(0x1A2F6BFF), blurRadius: 8, offset: Offset(0, 2)),
                ]
              : null,
        ),
        child: Icon(icon, size: size, color: color),
      ),
    );
  }
}

/// 原型通用导航栏：padding 54/16/12，标题 + 副标题（或面包屑）+ 右侧动作。
class ProtoNav extends StatelessWidget {
  const ProtoNav({
    super.key,
    required this.title,
    this.subtitle,
    this.subIcon,
    this.leading,
    this.actions = const <Widget>[],
    this.background = QyColors.canvas,
    this.titleColor = QyColors.ink,
  });

  final String title;
  final String? subtitle;
  final IconData? subIcon;
  final Widget? leading;
  final List<Widget> actions;
  final Color background;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 54, 16, 12),
        child: Row(
          children: <Widget>[
            if (leading != null) ...<Widget>[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    style: ProtoText.navTitle.copyWith(color: titleColor),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: subIcon == null
                          ? Text(subtitle!, style: ProtoText.navSub)
                          : Row(
                              children: <Widget>[
                                Icon(subIcon, size: 13, color: QyColors.muted),
                                const SizedBox(width: 3),
                                Text(subtitle!, style: ProtoText.navSub),
                              ],
                            ),
                    ),
                ],
              ),
            ),
            for (final Widget action in actions) action,
          ],
        ),
      ),
    );
  }
}

/// 区块标题：左标题，右侧「更多 >」。
class ProtoSectionHead extends StatelessWidget {
  const ProtoSectionHead({
    super.key,
    required this.title,
    this.more,
    this.moreIcon = Icons.chevron_right,
    this.padding = const EdgeInsets.fromLTRB(18, 20, 18, 10),
    this.onMore,
  });

  final String title;
  final String? more;
  final IconData moreIcon;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          Text(title, style: ProtoText.section),
          const Spacer(),
          if (more != null)
            QyTapScale(
              onTap: onMore ?? () {},
              child: Row(
                children: <Widget>[
                  Text(more!, style: ProtoText.sectionMore),
                  Icon(moreIcon, size: 15, color: QyColors.muted),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 原型筛选胶囊。
class ProtoChip extends StatelessWidget {
  const ProtoChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: QyTapScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: QyTokens.shortMotion,
          curve: qyProtoCurve,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: active ? QyColors.primary : QyColors.surface,
            border: Border.all(color: active ? QyColors.primary : QyColors.border),
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            boxShadow: active
                ? const <BoxShadow>[
                    BoxShadow(color: Color(0x402F6BFF), blurRadius: 12, offset: Offset(0, 4)),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: active ? FontWeight.w500 : FontWeight.w400,
              color: active ? QyColors.onDark : const Color(0xFF475467),
            ),
          ),
        ),
      ),
    );
  }
}

/// 文件类型图标底：40×40 圆角 11，彩色浅底 + 同族图标。
class ProtoTypeIcon extends StatelessWidget {
  const ProtoTypeIcon({
    super.key,
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.all(Radius.circular(11)),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

/// 居中浅灰脚注。
class ProtoFootNote extends StatelessWidget {
  const ProtoFootNote(this.text, {super.key, this.padding = const EdgeInsets.symmetric(vertical: 18)});

  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Center(child: Text(text, style: ProtoText.hint105)),
    );
  }
}
