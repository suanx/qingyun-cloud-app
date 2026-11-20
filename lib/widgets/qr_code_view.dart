import 'package:flutter/material.dart';

/// 零依赖二维码绘制。
///
/// 后端 `/api/security/2fa/setup` 返回的是模块矩阵（[size] × [size]，
/// [modules] 为行优先的 '0'/'1' 字符串），而不是 SVG 或图片，
/// 因此这里用纯 Dart [CustomPainter] 画格子，不引入任何第三方包。
class QrCodeView extends StatelessWidget {
  const QrCodeView({
    super.key,
    required this.modules,
    required this.size,
    this.side = 196,
    this.quietZone = 4,
    this.dark = const Color(0xFF1F2937),
    this.light = Colors.white,
  });

  /// 行优先模块字符串，长度应为 size*size；'1' 为深色格。
  final String modules;
  final int size;

  /// 边长（逻辑像素）。
  final double side;

  /// 静区格数（QR 规范要求 ≥ 4）。
  final int quietZone;
  final Color dark;
  final Color light;

  @override
  Widget build(BuildContext context) {
    if (size <= 0 || modules.length < size * size) {
      return SizedBox(
        width: side,
        height: side,
        child: const Center(child: Icon(Icons.qr_code_2, size: 40)),
      );
    }
    return SizedBox(
      width: side,
      height: side,
      child: DecoratedBox(
        decoration: BoxDecoration(color: light),
        child: CustomPaint(
          painter: _QrPainter(
            modules: modules,
            size: size,
            quietZone: quietZone,
            dark: dark,
          ),
        ),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  const _QrPainter({
    required this.modules,
    required this.size,
    required this.quietZone,
    required this.dark,
  });

  final String modules;
  final int size;
  final int quietZone;
  final Color dark;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final total = size + quietZone * 2;
    final cell = canvasSize.width / total;
    final paint = Paint()..color = dark;
    for (int row = 0; row < size; row++) {
      for (int col = 0; col < size; col++) {
        if (modules.codeUnitAt(row * size + col) != 0x31) continue; // '1'
        final left = (col + quietZone) * cell;
        final top = (row + quietZone) * cell;
        canvas.drawRect(
          Rect.fromLTWH(left, top, cell + 0.5, cell + 0.5),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) =>
      old.modules != modules || old.size != size || old.quietZone != quietZone;
}
