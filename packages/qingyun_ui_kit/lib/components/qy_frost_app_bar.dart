import 'package:flutter/material.dart';
import '../theme/qy_colors.dart';
import 'qy_frost.dart';

/// 玻璃面应用栏：透明 AppBar + 半透明白玻璃面。
///
/// 仅保留细描边与半透明质感，不含真实模糊层（真磨砂已全局关闭），
/// 页面内容滚动到栏体下方时始终清晰可读。
class QyFrostAppBar extends StatelessWidget implements PreferredSizeWidget {
  const QyFrostAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.centerTitle = false,
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: centerTitle,
      title: title,
      leading: leading,
      actions: actions,
      flexibleSpace: const QyFrost(
        color: QyColors.frostStrong,
        backdrop: false,
        showBorder: false,
        child: SizedBox.expand(),
      ),
    );
  }
}
