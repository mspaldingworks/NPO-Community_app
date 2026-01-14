import 'package:flutter/material.dart';

class SpotlightShroudPainter extends CustomPainter {
  final Offset center;
  final double radius;
  final double shroudOpacity;

  SpotlightShroudPainter({
    required this.center,
    required this.radius,
    required this.shroudOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final alpha = (shroudOpacity.clamp(0.0, 1.0) * 255).round();
    final shroudPaint = Paint()..color = Colors.white.withAlpha(alpha);
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, shroudPaint);

    final holePaint = Paint()..blendMode = BlendMode.clear;
    canvas.drawCircle(center, radius, holePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SpotlightShroudPainter oldDelegate) {
    return oldDelegate.center != center ||
        oldDelegate.radius != radius ||
        oldDelegate.shroudOpacity != shroudOpacity;
  }
}
