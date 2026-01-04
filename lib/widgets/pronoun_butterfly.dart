import 'package:flutter/material.dart';

class PronounButterflyParts {
  const PronounButterflyParts({
    required this.frontLeft,
    required this.backLeft,
    required this.frontRight,
    required this.backRight,
    required this.center,
  });

  final String? frontLeft;
  final String? backLeft;
  final String? frontRight;
  final String? backRight;
  final String? center;

  factory PronounButterflyParts.fromPronouns(List<String> pronouns) {
    final cleaned = pronouns.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    final String? p0 = cleaned.isNotEmpty ? cleaned[0] : null;
    final String? p1 = cleaned.length > 1 ? cleaned[1] : null;
    final String? p2 = cleaned.length > 2 ? cleaned[2] : null;
    final String? p3 = cleaned.length > 3 ? cleaned[3] : null;
    final String? p4 = cleaned.length > 4 ? cleaned[4] : null;

    final frontLeft = p0;
    final frontRight = p1 ?? p0;
    final backLeft = p2 ?? p0;
    final backRight = p3 ?? (cleaned.length == 2 ? (p1 ?? p0) : p0);
    final center = p4;

    return PronounButterflyParts(
      frontLeft: frontLeft,
      backLeft: backLeft,
      frontRight: frontRight,
      backRight: backRight,
      center: center,
    );
  }
}

class PronounButterfly extends StatelessWidget {
  const PronounButterfly({
    super.key,
    required this.pronouns,
    this.size = 240,
  });

  final List<String> pronouns;
  final double size;

  @override
  Widget build(BuildContext context) {
    final parts = PronounButterflyParts.fromPronouns(pronouns);

    return SizedBox(
      width: size,
      height: size,
      child: ClipRect(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(
              _assetPath('back_left', parts.backLeft),
              fit: BoxFit.contain,
            ),
            Image.asset(
              _assetPath('back_right', parts.backRight),
              fit: BoxFit.contain,
            ),
            Image.asset(
              _assetPath('front_left', parts.frontLeft),
              fit: BoxFit.contain,
            ),
            Image.asset(
              _assetPath('front_right', parts.frontRight),
              fit: BoxFit.contain,
            ),
            if (parts.center != null)
              Image.asset(
                _assetPath('center', parts.center),
                fit: BoxFit.contain,
              ),
          ],
        ),
      ),
    );
  }
}

class ButterflyViewerWindow extends StatelessWidget {
  const ButterflyViewerWindow({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surface;
    final border = Theme.of(context).dividerColor;

    return Container(
      decoration: BoxDecoration(
        color: bg.withOpacity(0.92),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: border.withOpacity(0.6), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

String _assetPath(String section, String? pronoun) {
  final key = _assetKeyForPronoun(pronoun);
  return 'assets/butterfly_wings/$section/$key.png';
}

String _assetKeyForPronoun(String? pronoun) {
  final p = (pronoun ?? '').trim();
  if (p.isEmpty) return 'Not Listed';

  final lower = p.toLowerCase();

  if (lower.contains('any pronouns') || lower == 'any') return 'Any';
  if (lower.contains('no pronouns') || lower == 'no') return 'No';

  if (lower.contains('ask for pronouns')) return 'Not Listed';

  final firstToken = p.split('/').first.trim().toLowerCase();

  if (firstToken == 'she' || firstToken == 'her') return 'She.Her';
  if (firstToken == 'he' || firstToken == 'him' || firstToken == 'hw') return 'He.Him';
  if (firstToken == 'they' || firstToken == 'them') return 'They.Them';

  if (firstToken == 'xe' || firstToken == 'xem' || firstToken == 'xyr') return 'Xe.Xem';

  if (firstToken == 'ze' ||
      firstToken == 'zir' ||
      firstToken == 'hir' ||
      firstToken == 'zem' ||
      firstToken == 'zie') {
    return 'Ze.Zir';
  }

  if (firstToken == 'fae' || firstToken == 'faer') return 'Fae.Faer';
  if (firstToken == 'ae' || firstToken == 'aer') return 'Ae.Aer';

  return 'Not Listed';
}
