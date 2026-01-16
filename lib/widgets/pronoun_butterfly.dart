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

class PronounButterflyAvatar extends StatefulWidget {
  const PronounButterflyAvatar({
    super.key,
    required this.pronouns,
    this.isFlapping = true,
    this.flapSpeed = const Duration(milliseconds: 260),
    this.size = 240,
    this.centerGap = 12,
  });

  final List<String> pronouns;
  final bool isFlapping;
  final Duration flapSpeed;
  final double size;
  final double centerGap;

  @override
  State<PronounButterflyAvatar> createState() => _PronounButterflyAvatarState();
}

class _PronounButterflyAvatarState extends State<PronounButterflyAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flapController;

  @override
  void initState() {
    super.initState();
    _flapController = AnimationController(vsync: this, duration: widget.flapSpeed);
    if (widget.isFlapping) {
      _flapController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant PronounButterflyAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flapSpeed != widget.flapSpeed) {
      _flapController.duration = widget.flapSpeed;
      if (widget.isFlapping && !_flapController.isAnimating) {
        _flapController.repeat();
      }
    }
    if (oldWidget.isFlapping != widget.isFlapping) {
      if (widget.isFlapping) {
        _flapController.repeat();
      } else {
        _flapController.stop();
      }
    }
  }

  @override
  void dispose() {
    _flapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parts = PronounButterflyParts.fromPronouns(widget.pronouns);
    final halfGap = widget.centerGap / 2;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _flapController,
          builder: (context, child) {
            final showFlip = widget.isFlapping && _flapController.value >= 0.5;
            return Stack(
              alignment: Alignment.center,
              children: [
                Transform.translate(
                  key: const ValueKey('butterfly-left'),
                  offset: Offset(-halfGap, 0),
                  child: _WingStack(
                    size: widget.size,
                    back: _assetPaths('back_left', parts.backLeft),
                    front: _assetPaths('front_left', parts.frontLeft),
                    showFlip: showFlip,
                    flapSpeed: widget.flapSpeed,
                  ),
                ),
                Transform.translate(
                  key: const ValueKey('butterfly-right'),
                  offset: Offset(halfGap, 0),
                  child: _WingStack(
                    size: widget.size,
                    back: _assetPaths('back_right', parts.backRight),
                    front: _assetPaths('front_right', parts.frontRight),
                    showFlip: showFlip,
                    flapSpeed: widget.flapSpeed,
                  ),
                ),
                if (parts.center != null)
                  Image.asset(
                    _assetPaths('center', parts.center).base,
                    fit: BoxFit.contain,
                  ),
              ],
            );
          },
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

PronounWingAssetPaths _assetPaths(String section, String? pronoun) {
  final key = _assetKeyForPronoun(pronoun);
  return PronounWingAssetPaths(
    base: 'assets/butterfly_wings/$section/$key.png',
    flip: 'assets/butterfly_wings/$section/$key.flip.png',
  );
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

class PronounWingAssetPaths {
  const PronounWingAssetPaths({required this.base, required this.flip});

  final String base;
  final String flip;
}

class _WingStack extends StatelessWidget {
  const _WingStack({
    required this.size,
    required this.back,
    required this.front,
    required this.showFlip,
    required this.flapSpeed,
  });

  final double size;
  final PronounWingAssetPaths back;
  final PronounWingAssetPaths front;
  final bool showFlip;
  final Duration flapSpeed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _FlappingWing(
            assetPaths: back,
            showFlip: showFlip,
            flapSpeed: flapSpeed,
          ),
          _FlappingWing(
            assetPaths: front,
            showFlip: showFlip,
            flapSpeed: flapSpeed,
          ),
        ],
      ),
    );
  }
}

class _FlappingWing extends StatelessWidget {
  const _FlappingWing({
    required this.assetPaths,
    required this.showFlip,
    required this.flapSpeed,
  });

  final PronounWingAssetPaths assetPaths;
  final bool showFlip;
  final Duration flapSpeed;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: (flapSpeed.inMilliseconds / 2).round()),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child: Image.asset(
        showFlip ? assetPaths.flip : assetPaths.base,
        key: ValueKey(showFlip),
        fit: BoxFit.contain,
      ),
    );
  }
}
