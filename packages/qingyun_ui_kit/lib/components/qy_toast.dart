import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/qy_colors.dart';
import '../theme/qy_tokens.dart';
import 'qy_frost.dart';
import 'qy_icon.dart';

void showQyToast(
  BuildContext context,
  String message, {
  bool success = true,
}) {
  final overlay = Overlay.of(context);
  late final OverlayEntry entry;
  var removed = false;
  void dismiss() {
    if (removed) return;
    removed = true;
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (_) => _QyToastBody(
      message: message,
      success: success,
    ),
  );
  overlay.insert(entry);
  Timer(QyTokens.toastDuration, dismiss);
}

class _QyToastBody extends StatefulWidget {
  const _QyToastBody({required this.message, required this.success});

  final String message;
  final bool success;

  @override
  State<_QyToastBody> createState() => _QyToastBodyState();
}

class _QyToastBodyState extends State<_QyToastBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(QyTokens.shortMotion);
      if (mounted) setState(() => _visible = true);
    });
  }

  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 88,
      left: 20,
      right: 20,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: QyTokens.shortMotion,
        child: IgnorePointer(
          child: QyFrost(
            color: QyColors.frostDark,
            blur: 16,
            showBorder: false,
            borderRadius: BorderRadius.circular(QyTokens.radiusLg),
            shadows: <BoxShadow>[QyTokens.cardShadow(const Color(0x3320262B))],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: <Widget>[
                  QyIcon(
                    widget.success ? QyIcons.check : QyIcons.info,
                    size: 22,
                    color: QyColors.onDark,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(color: QyColors.onDark, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
