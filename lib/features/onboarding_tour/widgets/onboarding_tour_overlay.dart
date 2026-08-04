import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:npo_community/features/onboarding_tour/controllers/onboarding_tour_controller.dart';
import 'package:npo_community/features/onboarding_tour/models/onboarding_tour_models.dart';
import 'package:npo_community/features/onboarding_tour/services/tour_anchor_registry.dart';
import 'package:npo_community/features/onboarding_tour/widgets/spotlight_shroud_painter.dart';

class OnboardingTourOverlay extends StatefulWidget {
  final OnboardingTourController controller;

  const OnboardingTourOverlay({super.key, required this.controller});

  @override
  State<OnboardingTourOverlay> createState() => _OnboardingTourOverlayState();
}

class _OnboardingTourOverlayState extends State<OnboardingTourOverlay> {
  Rect? _cachedRect;

  static const String _pointerAssetPath = 'assets/tour/tour_butterfly.gif';
  static const Set<String> _bottomNavStepIds = <String>{
    'community-tab',
    'exchange-tab',
    'resources-tab',
    'events-tab',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleRectRecalc();
  }

  @override
  void didUpdateWidget(covariant OnboardingTourOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller.currentIndex != widget.controller.currentIndex ||
        oldWidget.controller.active != widget.controller.active) {
      _scheduleRectRecalc();
    }
  }

  void _scheduleRectRecalc() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _cachedRect = _computeTargetRect(widget.controller.currentStep);
      });
    });
  }

  Rect? _computeTargetRect(TourStep? step) {
    if (step == null) return null;
    final targetName = step.spotlight.targetElementName;
    if (targetName.trim().isEmpty) return null;

    final key = TourAnchorRegistry.instance.resolveKey(targetName);
    final ctx = key?.currentContext;
    if (ctx == null) return null;

    final renderObject = ctx.findRenderObject();
    if (renderObject is! RenderBox) return null;
    if (!renderObject.hasSize) return null;

    final offset = renderObject.localToGlobal(Offset.zero);
    return offset & renderObject.size;
  }

  Offset _choosePointerDirection(Size screenSize, Offset center) {
    final dx = center.dx > screenSize.width * 0.65 ? -1.0 : 1.0;
    final dy = center.dy > screenSize.height * 0.6 ? -1.0 : 1.0;
    final mag = math.sqrt(dx * dx + dy * dy);
    return Offset(dx / mag, dy / mag);
  }

  Offset _chooseBottomNavPointerDirection(Size screenSize, Offset center) {
    double dx;
    if (center.dx > screenSize.width * 0.75) {
      dx = -1.0;
    } else if (center.dx < screenSize.width * 0.25) {
      dx = 1.0;
    } else {
      dx = 1.0;
    }

    final raw = Offset(dx, 0.85);
    final mag = raw.distance;
    return mag == 0 ? const Offset(1, 0) : raw / mag;
  }

  Widget _buildPointer({
    required Size screenSize,
    required Offset spotlightCenter,
    required double spotlightRadius,
    required bool forBottomNav,
    required bool flipHorizontal,
    required double reservedBottom,
    required double bottomInset,
    required double bottomNavHeight,
  }) {
    Offset dir = forBottomNav
        ? _chooseBottomNavPointerDirection(screenSize, spotlightCenter)
        : _choosePointerDirection(screenSize, spotlightCenter);
    if (flipHorizontal) {
      dir = Offset(-dir.dx, dir.dy);
    }

    final pointerSize = (spotlightRadius * 0.9).clamp(56.0, 120.0);
    final signX = dir.dx >= 0 ? 1.0 : -1.0;
    final pointerCenter = forBottomNav
        ? Offset(
            spotlightCenter.dx + signX * (spotlightRadius + pointerSize * 0.35),
            screenSize.height - bottomInset - (bottomNavHeight / 2),
          )
        : () {
            final distance = spotlightRadius + (pointerSize / 2) + 8;
            return spotlightCenter +
                Offset(dir.dx * distance, dir.dy * distance);
          }();

    final left = (pointerCenter.dx - pointerSize / 2).clamp(
      0.0,
      screenSize.width - pointerSize,
    );
    final maxTop = math.max(
      0.0,
      screenSize.height - pointerSize - reservedBottom,
    );
    final top = (pointerCenter.dy - pointerSize / 2).clamp(0.0, maxTop);

    const rotation = 0.28;

    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        ignoring: true,
        child: Transform.rotate(
          angle: rotation,
          child: Image.asset(
            _pointerAssetPath,
            width: pointerSize,
            height: pointerSize,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.controller.currentStep;
    if (!widget.controller.active || step == null) {
      return const SizedBox.shrink();
    }

    final media = MediaQuery.of(context);
    final size = media.size;

    final rect = _cachedRect;
    final center = rect != null
        ? rect.center
        : Offset(size.width / 2, size.height / 2);
    final baseRadius = rect != null
        ? math.max(rect.width, rect.height) / 2
        : 44.0;
    final radius =
        (baseRadius + step.spotlight.paddingPx) *
        step.spotlight.radiusMultiplier;

    final stepId = step.id;
    final topCard = _bottomNavStepIds.contains(stepId);
    final pointerForBottomNav = _bottomNavStepIds.contains(stepId);
    final flipPointerHorizontal = stepId == 'edit-profile';
    final pointerReservedBottom = topCard ? 0.0 : 260.0;
    final bottomInset = media.padding.bottom;
    const bottomNavHeight = 72.0;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: CustomPaint(
                painter: SpotlightShroudPainter(
                  center: center,
                  radius: radius,
                  shroudOpacity: step.spotlight.shroudOpacity,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: ClipPath(
              clipper: _OutsideSpotlightClipper(center: center, radius: radius),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: const SizedBox.expand(),
              ),
            ),
          ),
          _buildPointer(
            screenSize: size,
            spotlightCenter: center,
            spotlightRadius: radius,
            forBottomNav: pointerForBottomNav,
            flipHorizontal: flipPointerHorizontal,
            reservedBottom: pointerReservedBottom,
            bottomInset: bottomInset,
            bottomNavHeight: bottomNavHeight,
          ),
          _StepCard(
            step: step,
            isLast:
                widget.controller.currentIndex >=
                widget.controller.totalSteps - 1,
            topAligned: topCard,
            onPrimary: () async {
              await widget.controller.next();
              if (mounted) {
                _scheduleRectRecalc();
              }
            },
            onSecondary: () async {
              await widget.controller.stopAndMarkSeen();
            },
          ),
        ],
      ),
    );
  }
}

class _OutsideSpotlightClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;

  const _OutsideSpotlightClipper({required this.center, required this.radius});

  @override
  Path getClip(Size size) {
    final path = Path()..fillType = PathFillType.evenOdd;
    path.addRect(Offset.zero & size);
    path.addOval(Rect.fromCircle(center: center, radius: radius));
    return path;
  }

  @override
  bool shouldReclip(covariant _OutsideSpotlightClipper oldClipper) {
    return oldClipper.center != center || oldClipper.radius != radius;
  }
}

class _StepCard extends StatelessWidget {
  final TourStep step;
  final bool isLast;
  final bool topAligned;
  final VoidCallback onPrimary;
  final VoidCallback? onSecondary;

  const _StepCard({
    required this.step,
    required this.isLast,
    required this.topAligned,
    required this.onPrimary,
    required this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final title = (step.title ?? '').trim();
    final body = (step.body ?? '').trim();
    final userAction = (step.userAction ?? '').trim();
    final progress = (step.progress ?? '').trim();

    final primaryLabel = (step.primaryButton?.label ?? '').trim().isEmpty
        ? (isLast ? 'Finish' : 'Next')
        : step.primaryButton!.label.trim();

    final secondaryLabel = (step.secondaryButton?.label ?? '').trim();

    final alignment = topAligned ? Alignment.topCenter : Alignment.bottomCenter;
    final topPadding = topAligned ? (16 + kToolbarHeight) : 16.0;

    return SafeArea(
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, topPadding, 16, 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (progress.isNotEmpty)
                      Text(progress, style: theme.textTheme.labelMedium),
                    if (title.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(title, style: theme.textTheme.titleLarge),
                      ),
                    if (body.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(body, style: theme.textTheme.bodyMedium),
                      ),
                    if (userAction.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          userAction,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (secondaryLabel.isNotEmpty && onSecondary != null)
                          TextButton(
                            onPressed: onSecondary,
                            child: Text(secondaryLabel),
                          ),
                        FilledButton(
                          onPressed: onPrimary,
                          child: Text(primaryLabel),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
