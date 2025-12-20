import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:transconnect/features/onboarding_tour/controllers/onboarding_tour_controller.dart';
import 'package:transconnect/features/onboarding_tour/models/onboarding_tour_models.dart';
import 'package:transconnect/features/onboarding_tour/services/tour_anchor_registry.dart';
import 'package:transconnect/features/onboarding_tour/widgets/spotlight_shroud_painter.dart';

class OnboardingTourOverlay extends StatefulWidget {
  final OnboardingTourController controller;

  const OnboardingTourOverlay({
    super.key,
    required this.controller,
  });

  @override
  State<OnboardingTourOverlay> createState() => _OnboardingTourOverlayState();
}

class _OnboardingTourOverlayState extends State<OnboardingTourOverlay> {
  Rect? _cachedRect;

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

  @override
  Widget build(BuildContext context) {
    final step = widget.controller.currentStep;
    if (!widget.controller.active || step == null) {
      return const SizedBox.shrink();
    }

    final media = MediaQuery.of(context);
    final size = media.size;

    final rect = _cachedRect;
    final center = rect != null ? rect.center : Offset(size.width / 2, size.height / 2);
    final baseRadius = rect != null ? math.max(rect.width, rect.height) / 2 : 44.0;
    final radius = baseRadius + step.spotlight.paddingPx;

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
          _StepCard(
            step: step,
            isLast: widget.controller.currentIndex >= widget.controller.totalSteps - 1,
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
  final VoidCallback onPrimary;
  final VoidCallback? onSecondary;

  const _StepCard({
    required this.step,
    required this.isLast,
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

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                      Text(
                        progress,
                        style: theme.textTheme.labelMedium,
                      ),
                    if (title.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          title,
                          style: theme.textTheme.titleLarge,
                        ),
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
