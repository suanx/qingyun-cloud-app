import 'package:flutter/material.dart';
import '../theme/qy_colors.dart';
import 'qy_frost.dart';

/// 磨砂玻璃应用栏：透明 AppBar + 高斯模糊半透明白背景。
///
/// 页面内容滚动到栏体下方时呈现磨砂玻璃效果。
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
        blur: 20,
        showBorder: false,
        child: SizedBox.expand(),
      ),
    );
  }
}
