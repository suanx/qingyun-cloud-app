import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/qy_colors.dart';
import '../theme/qy_tokens.dart';
import 'qy_page_transitions.dart';

/// 原型 Toast：屏幕正中、深色半透明胶囊，1.9 秒后消失。
void showQyToast(BuildContext context, String message, {bool success = true}) {
  final OverlayState overlay = Overlay.of(context);
  late final OverlayEntry entry;
  var removed = false;
  void dismiss() {
    if (removed) return;
    removed = true;
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (_) => _QyToastBody(message: message, success: success),
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
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(QyTokens.shortMotion);
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: QyTokens.shortMotion,
            curve: qyProtoCurve,
            child: AnimatedScale(
              scale: _visible ? 1 : 0.96,
              duration: QyTokens.shortMotion,
              curve: qyProtoCurve,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: QyColors.frostDark,
                  borderRadius: BorderRadius.circular(QyTokens.radiusMd),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        widget.success ? Icons.check_circle : Icons.info_outline,
                        size: 18,
                        color: QyColors.onDark,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.message,
                        style: const TextStyle(
                          color: QyColors.onDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
