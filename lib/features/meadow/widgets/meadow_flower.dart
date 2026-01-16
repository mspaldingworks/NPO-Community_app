import 'package:flutter/material.dart';
import 'package:transconnect/features/meadow/models/meadow_chat_flower.dart';

class MeadowFlower extends StatelessWidget {
  const MeadowFlower({
    super.key,
    required this.flower,
    required this.onTap,
    this.size = 68,
  });

  final MeadowChatFlower flower;
  final VoidCallback onTap;
  final double size;

  static const _flowerAssets = [
    'assets/meadow/flowers/Red flower.png',
    'assets/meadow/flowers/Yellow Flower.png',
    'assets/meadow/flowers/Yellow flower2.png',
  ];

  @override
  Widget build(BuildContext context) {
    final asset = _flowerAssets[flower.id.hashCode.abs() % _flowerAssets.length];
    return Positioned(
      left: flower.position.dx - size / 2,
      top: flower.position.dy - size / 2,
      child: GestureDetector(
        key: ValueKey('meadow-flower-${flower.id}'),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size / 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.16),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(size / 2),
                child: Image.asset(
                  asset,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.82),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                flower.topic,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
