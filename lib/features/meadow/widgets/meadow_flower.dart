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

    final scale = (1 + (flower.participantCount * 0.12)).clamp(1.0, 1.7);
    final redWindowBoost = asset.toLowerCase().contains('red flower') ? 1.18 : 1.0;
    final scaledSize = size * scale * redWindowBoost;
    return Positioned(
      left: flower.position.dx - scaledSize / 2,
      top: flower.position.dy - scaledSize / 2,
      child: GestureDetector(
        key: ValueKey('meadow-flower-${flower.id}'),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: scaledSize,
              height: scaledSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(scaledSize / 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.16),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(scaledSize / 2),
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
                '${flower.emoji} ${flower.topic}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
